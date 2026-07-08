import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/security/app_mode_service.dart';
import '../domain/order.dart';
import '../domain/order_item.dart';
import '../domain/payment.dart';

class OrderDao {
  final _uuid = const Uuid();
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Generate a unique order ID that is exactly 2 alphabets and 5 digits long.
  /// Owner orders start with 'OW', Worker orders start with 'WK'.
  /// Collisions automatically append suffixes 1, 2, 3, 4, 5...
  static Future<String> generateUniqueOrderNo() async {
    final mode = await AppModeService.getAppMode();
    final prefix = (mode == AppMode.owner) ? 'OW' : 'WK';
    final randDigits = (math.Random().nextInt(90000) + 10000).toString();
    final baseNo = '$prefix$randDigits';

    final db = await DatabaseHelper.instance.database;
    String candidate = baseNo;
    int suffix = 1;

    while (suffix < 10000) {
      final List<Map<String, dynamic>> res = await db.query(
        'orders',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [candidate],
      );
      if (res.isEmpty) {
        break;
      }
      candidate = '$baseNo$suffix';
      suffix++;
    }
    if (suffix >= 10000) {
      throw Exception('Could not generate a unique order number after 10000 attempts');
    }
    return candidate;
  }

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    return executor ?? await _db;
  }

  /// Get all orders with optional filters and customer info via JOIN
  Future<List<AppOrder>> getAllOrders({
    String? status,
    String? filter,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    int limit   = 30,
    int offset  = 0,
  }) async {
    final db = await _db;

    List<String> conditions = [];
    List<dynamic> args = [];

    if (customerId != null) {
      conditions.add('o.customer_id = ?');
      args.add(customerId);
    }
    if (status != null && status != 'all') {
      conditions.add('o.delivery_status = ?');
      args.add(status);
    }

    // Date filters
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (startDate != null && endDate != null) {
      conditions.add('o.created_at >= ? AND o.created_at <= ?');
      args.add(DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0).toIso8601String());
      args.add(DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999).toIso8601String());
    } else if (filter == 'today') {
      conditions.add('DATE(o.created_at) = DATE(?)');
      args.add(today.toIso8601String());
    } else if (filter == 'yesterday') {
      final yesterday = today.subtract(const Duration(days: 1));
      conditions.add('DATE(o.created_at) = DATE(?)');
      args.add(yesterday.toIso8601String());
    } else if (filter == 'week') {
      conditions.add('o.created_at >= ?');
      args.add(today.subtract(const Duration(days: 7)).toIso8601String());
    } else if (filter == 'month') {
      conditions.add('strftime(\'%Y-%m\', o.created_at) = strftime(\'%Y-%m\', ?)');
      args.add(now.toIso8601String());
    }


    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final maps = await db.rawQuery('''
      SELECT
        o.*,
        o.rowid   AS order_number,
        c.name    AS customer_name,
        c.address AS customer_address,
        c.phone1  AS customer_phone
      FROM orders o
      LEFT JOIN customers c ON o.customer_id = c.id
      $where
      ORDER BY o.created_at DESC
      LIMIT $limit OFFSET $offset
    ''', args);

    return maps.map(AppOrder.fromMap).toList();
  }

  Future<AppOrder?> getOrderById(String id, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final maps = await db.rawQuery('''
      SELECT o.*, o.rowid AS order_number, c.name AS customer_name, c.address AS customer_address, c.phone1 AS customer_phone
      FROM orders o LEFT JOIN customers c ON o.customer_id = c.id
      WHERE o.id = ?
    ''', [id]);
    if (maps.isEmpty) return null;
    return AppOrder.fromMap(maps.first);
  }

  Future<List<OrderItem>> getOrderItems(String orderId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final maps = await db.query('order_items',
        where: 'order_id = ?', whereArgs: [orderId]);
    return maps.map(OrderItem.fromMap).toList();
  }

  Future<List<Payment>> getOrderPayments(String orderId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final maps = await db.query('payments',
        where: 'order_id = ?',
        whereArgs: [orderId],
        orderBy: 'created_at DESC');
    return maps.map(Payment.fromMap).toList();
  }

  Future<String> insertOrder(AppOrder order, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final id  = order.id.isEmpty ? await generateUniqueOrderNo() : order.id;
    final now = DateTime.now().toIso8601String();

    String workerId = order.assignedWorkerId;
    double commRate = 0.0;
    String commType = '';

    if (workerId.isEmpty) {
      final cust = await db.query('customers', columns: ['assigned_worker_id'], where: 'id = ?', whereArgs: [order.customerId]);
      if (cust.isNotEmpty) {
        workerId = cust.first['assigned_worker_id'] as String? ?? '';
      }
    }

    if (workerId.isNotEmpty) {
      final w = await db.query('workers', where: 'id = ?', whereArgs: [workerId]);
      if (w.isNotEmpty) {
        commRate = (w.first['commission_value'] as num?)?.toDouble() ?? 5.0;
        commType = w.first['commission_type'] as String? ?? 'pct_order';
      }
    }

    final mode = await AppModeService.getAppMode();
    String createdBy = order.createdBy;
    String assignedWorkerId = workerId.isNotEmpty ? workerId : order.assignedWorkerId;
    String workerName = order.workerName;
    String deviceName = order.deviceName;

    if (mode == AppMode.worker) {
      final settingsRes = await db.query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      final activeWorkerId = settingsRes.isNotEmpty ? settingsRes.first['value']?.toString() : null;
      if (activeWorkerId != null && activeWorkerId.isNotEmpty) {
        createdBy = activeWorkerId;
        assignedWorkerId = activeWorkerId;
        final workerRow = await db.query('workers', where: 'id = ?', whereArgs: [activeWorkerId]);
        if (workerRow.isNotEmpty) {
          workerName = workerRow.first['name']?.toString() ?? '';
        }
        deviceName = 'Worker Mobile';
      }
    }

    final map = order.toMap();

    await db.insert('orders', {
      ...map,
      'id':                 id,
      'assigned_worker_id': assignedWorkerId,
      'created_by':         createdBy,
      'worker_name':        workerName,
      'device_name':        deviceName,
      'commission_rate':    commRate > 0 ? commRate : 5.0,
      'commission_type':    commType.isNotEmpty ? commType : 'pct_order',
      'created_at':         order.createdAt.toIso8601String(),
      'updated_at':         now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<void> insertOrderItem(OrderItem item, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final id = item.id.isEmpty ? _uuid.v4() : item.id;
    await db.insert('order_items', {
      ...item.toMap(),
      'id': id,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteOrderItems(String orderId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    await db.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
  }

  Future<void> updateOrder(AppOrder order, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    await db.update(
      'orders',
      {...order.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  Future<void> deleteOrder(String id, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    await db.delete('orders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateDeliveryStatus(String orderId, String status, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    await db.update(
      'orders',
      {'delivery_status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> insertPayment(Payment payment, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final id = payment.id.isEmpty ? _uuid.v4() : payment.id;

    final mode = await AppModeService.getAppMode();
    String createdBy = 'owner';
    String assignedWorkerId = '';
    String workerName = '';
    String deviceName = '';

    if (mode == AppMode.worker) {
      final settingsRes = await db.query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      final activeWorkerId = settingsRes.isNotEmpty ? settingsRes.first['value']?.toString() : null;
      if (activeWorkerId != null && activeWorkerId.isNotEmpty) {
        createdBy = activeWorkerId;
        assignedWorkerId = activeWorkerId;
        final workerRow = await db.query('workers', where: 'id = ?', whereArgs: [activeWorkerId]);
        if (workerRow.isNotEmpty) {
          workerName = workerRow.first['name']?.toString() ?? '';
        }
        deviceName = 'Worker Mobile';
      }
    }

    await db.insert('payments', {
      ...payment.toMap(),
      'id':                 id,
      'created_by':         createdBy,
      'assigned_worker_id': assignedWorkerId,
      'worker_name':        workerName,
      'device_name':        deviceName,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateOrderPayment(
      String orderId, double paidAmount, double remainingAmount, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    await db.update(
      'orders',
      {
        'paid_amount':      paidAmount,
        'remaining_amount': remainingAmount,
        'updated_at':       DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<String?> _getWorkerId() async {
    final db = await _db;
    final mode = await AppModeService.getAppMode();
    if (mode != AppMode.worker) return null;
    
    final settingsRes = await db.query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
    String? workerId = settingsRes.isNotEmpty ? settingsRes.first['value']?.toString() : null;
    if (workerId == null || workerId.isEmpty) {
      final workerRows = await db.query('workers', limit: 1);
      if (workerRows.isNotEmpty) {
        workerId = workerRows.first['id']?.toString();
      }
    }
    return workerId;
  }

  /// Analytics summary query
  Future<Map<String, dynamic>> getAnalyticsSummary() async {
    final db = await _db;
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day).toIso8601String();
    final month  = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final workerId = await _getWorkerId();
    final bool isWorker = workerId != null && workerId.isNotEmpty;

    final todaySales = await db.rawQuery(
        isWorker
            ? 'SELECT COALESCE(SUM(grand_total),0) AS v FROM orders WHERE DATE(created_at) = DATE(?) AND (created_by = ? OR assigned_worker_id = ?)'
            : 'SELECT COALESCE(SUM(grand_total),0) AS v FROM orders WHERE DATE(created_at) = DATE(?)',
        isWorker ? [today, workerId, workerId] : [today]);

    final todayOrders = await db.rawQuery(
        isWorker
            ? 'SELECT COUNT(*) AS v FROM orders WHERE DATE(created_at) = DATE(?) AND (created_by = ? OR assigned_worker_id = ?)'
            : 'SELECT COUNT(*) AS v FROM orders WHERE DATE(created_at) = DATE(?)',
        isWorker ? [today, workerId, workerId] : [today]);

    final monthlySales = await db.rawQuery(
        isWorker
            ? "SELECT COALESCE(SUM(grand_total),0) AS v FROM orders WHERE strftime('%Y-%m', created_at) = ? AND (created_by = ? OR assigned_worker_id = ?)"
            : "SELECT COALESCE(SUM(grand_total),0) AS v FROM orders WHERE strftime('%Y-%m', created_at) = ?",
        isWorker ? [month, workerId, workerId] : [month]);

    final pendingPayments = await db.rawQuery(
        isWorker
            ? 'SELECT COALESCE(SUM(remaining_amount),0) AS v FROM orders WHERE remaining_amount > 0 AND (created_by = ? OR assigned_worker_id = ?)'
            : 'SELECT COALESCE(SUM(remaining_amount),0) AS v FROM orders WHERE remaining_amount > 0',
        isWorker ? [workerId, workerId] : null);

    final cashReceived = await db.rawQuery(
        isWorker
            ? "SELECT COALESCE(SUM(amount),0) AS v FROM payments WHERE method = 'cash' AND (created_by = ? OR assigned_worker_id = ?)"
            : "SELECT COALESCE(SUM(amount),0) AS v FROM payments WHERE method = 'cash'",
        isWorker ? [workerId, workerId] : null);

    final onlineReceived = await db.rawQuery(
        isWorker
            ? "SELECT COALESCE(SUM(amount),0) AS v FROM payments WHERE method != 'cash' AND (created_by = ? OR assigned_worker_id = ?)"
            : "SELECT COALESCE(SUM(amount),0) AS v FROM payments WHERE method != 'cash'",
        isWorker ? [workerId, workerId] : null);

    final totalExpenses = await db.rawQuery(
        isWorker
            ? 'SELECT COALESCE(SUM(amount),0) AS v FROM expenses WHERE (created_by = ? OR assigned_worker_id = ?)'
            : 'SELECT COALESCE(SUM(amount),0) AS v FROM expenses',
        isWorker ? [workerId, workerId] : null);

    final customerCount = await db.rawQuery(
        isWorker
            ? "SELECT COUNT(*) AS v FROM customers WHERE (created_by = ? OR assigned_worker_id = ? OR id IN (SELECT entity_id FROM worker_assignments WHERE worker_id = ? AND entity_type = 'customer'))"
            : 'SELECT COUNT(*) AS v FROM customers',
        isWorker ? [workerId, workerId, workerId] : null);

    final orderCount = await db.rawQuery(
        isWorker
            ? 'SELECT COUNT(*) AS v FROM orders WHERE (created_by = ? OR assigned_worker_id = ?)'
            : 'SELECT COUNT(*) AS v FROM orders',
        isWorker ? [workerId, workerId] : null);

    final itemCount = await db.rawQuery(
        'SELECT COUNT(*) AS v FROM items');

    // Top selling items
    final topItems = await db.rawQuery(
        isWorker
            ? '''
              SELECT item_name, SUM(total_price) AS revenue, SUM(quantity) AS qty
              FROM order_items
              WHERE order_id IN (SELECT id FROM orders WHERE created_by = ? OR assigned_worker_id = ?)
              GROUP BY item_name
              ORDER BY revenue DESC
              LIMIT 5
              '''
            : '''
              SELECT item_name, SUM(total_price) AS revenue, SUM(quantity) AS qty
              FROM order_items
              GROUP BY item_name
              ORDER BY revenue DESC
              LIMIT 5
              ''',
        isWorker ? [workerId, workerId] : null);

    // Low stock items
    final lowStock = await db.rawQuery(
        'SELECT * FROM items WHERE min_stock > 0 AND stock <= min_stock ORDER BY stock ASC LIMIT 10');

    // Status counts
    final deliveredOrders = await db.rawQuery(
        isWorker
            ? "SELECT COUNT(*) AS v FROM orders WHERE delivery_status = 'delivered' AND (created_by = ? OR assigned_worker_id = ?)"
            : "SELECT COUNT(*) AS v FROM orders WHERE delivery_status = 'delivered'",
        isWorker ? [workerId, workerId] : null);
    final pendingOrders = await db.rawQuery(
        isWorker
            ? "SELECT COUNT(*) AS v FROM orders WHERE delivery_status = 'pending' AND (created_by = ? OR assigned_worker_id = ?)"
            : "SELECT COUNT(*) AS v FROM orders WHERE delivery_status = 'pending'",
        isWorker ? [workerId, workerId] : null);
    final cancelledOrders = await db.rawQuery(
        isWorker
            ? "SELECT COUNT(*) AS v FROM orders WHERE delivery_status = 'cancelled' AND (created_by = ? OR assigned_worker_id = ?)"
            : "SELECT COUNT(*) AS v FROM orders WHERE delivery_status = 'cancelled'",
        isWorker ? [workerId, workerId] : null);

    // All-time sales
    final allTimeSales = await db.rawQuery(
        isWorker
            ? 'SELECT COALESCE(SUM(grand_total),0) AS v FROM orders WHERE (created_by = ? OR assigned_worker_id = ?)'
            : 'SELECT COALESCE(SUM(grand_total),0) AS v FROM orders',
        isWorker ? [workerId, workerId] : null);

    // Delivery fees collected
    final allTimeDelivery = await db.rawQuery(
        isWorker
            ? 'SELECT COALESCE(SUM(delivery_charge),0) AS v FROM orders WHERE (created_by = ? OR assigned_worker_id = ?)'
            : 'SELECT COALESCE(SUM(delivery_charge),0) AS v FROM orders',
        isWorker ? [workerId, workerId] : null);

    return {
      'today_sales':      (todaySales.first['v'] as num?)?.toDouble()    ?? 0,
      'today_orders_count': todayOrders.first['v'] ?? 0,
      'monthly_sales':    (monthlySales.first['v'] as num?)?.toDouble()  ?? 0,
      'pending_payments': (pendingPayments.first['v'] as num?)?.toDouble()?? 0,
      'cash_received':    (cashReceived.first['v'] as num?)?.toDouble()  ?? 0,
      'online_received':  (onlineReceived.first['v'] as num?)?.toDouble()?? 0,
      'total_expenses':   (totalExpenses.first['v'] as num?)?.toDouble() ?? 0,
      'customer_count':   customerCount.first['v'] ?? 0,
      'order_count':      orderCount.first['v']    ?? 0,
      'item_count':       itemCount.first['v']     ?? 0,
      'top_items':        topItems,
      'low_stock':        lowStock,
      'delivered_count':  deliveredOrders.first['v'] ?? 0,
      'pending_count':    pendingOrders.first['v'] ?? 0,
      'cancelled_count':  cancelledOrders.first['v'] ?? 0,
      'all_time_sales':   (allTimeSales.first['v'] as num?)?.toDouble() ?? 0,
      'delivery_fees':    (allTimeDelivery.first['v'] as num?)?.toDouble() ?? 0,
    };
  }

  /// Comprehensive Profit & Loss Statement calculation
  Future<Map<String, dynamic>> getProfitLossStatement() async {
    final db = await _db;
    final workerId = await _getWorkerId();
    final bool isWorker = workerId != null && workerId.isNotEmpty;
    
    // 1. Gross Revenue
    final revenueRes = await db.rawQuery(
        isWorker
            ? 'SELECT COALESCE(SUM(grand_total), 0) AS v FROM orders WHERE (created_by = ? OR assigned_worker_id = ?)'
            : 'SELECT COALESCE(SUM(grand_total), 0) AS v FROM orders',
        isWorker ? [workerId, workerId] : null);
    final totalRevenue = (revenueRes.first['v'] as num?)?.toDouble() ?? 0.0;

    // 2. Cost of Goods Sold (COGS)
    final cogsRes = await db.rawQuery(
        isWorker
            ? '''
              SELECT COALESCE(SUM(oi.quantity * COALESCE(i.cost_price, 0)), 0) AS v
              FROM order_items oi
              LEFT JOIN items i ON oi.item_id = i.id
              WHERE oi.order_id IN (SELECT id FROM orders WHERE created_by = ? OR assigned_worker_id = ?)
              '''
            : '''
              SELECT COALESCE(SUM(oi.quantity * COALESCE(i.cost_price, 0)), 0) AS v
              FROM order_items oi
              LEFT JOIN items i ON oi.item_id = i.id
              ''',
        isWorker ? [workerId, workerId] : null);
    final cogs = (cogsRes.first['v'] as num?)?.toDouble() ?? 0.0;

    // 3. Operating Expenses
    final expensesRes = await db.rawQuery(
        isWorker
            ? 'SELECT COALESCE(SUM(amount), 0) AS v FROM expenses WHERE (created_by = ? OR assigned_worker_id = ?)'
            : 'SELECT COALESCE(SUM(amount), 0) AS v FROM expenses',
        isWorker ? [workerId, workerId] : null);
    final totalExpenses = (expensesRes.first['v'] as num?)?.toDouble() ?? 0.0;

    // 4. Discounts Given
    final discountRes = await db.rawQuery(
        isWorker
            ? 'SELECT COALESCE(SUM(discount), 0) AS v FROM orders WHERE (created_by = ? OR assigned_worker_id = ?)'
            : 'SELECT COALESCE(SUM(discount), 0) AS v FROM orders',
        isWorker ? [workerId, workerId] : null);
    final totalDiscounts = (discountRes.first['v'] as num?)?.toDouble() ?? 0.0;

    // 5. Delivery Income
    final deliveryRes = await db.rawQuery(
        isWorker
            ? 'SELECT COALESCE(SUM(delivery_charge), 0) AS v FROM orders WHERE (created_by = ? OR assigned_worker_id = ?)'
            : 'SELECT COALESCE(SUM(delivery_charge), 0) AS v FROM orders',
        isWorker ? [workerId, workerId] : null);
    final totalDeliveryIncome = (deliveryRes.first['v'] as num?)?.toDouble() ?? 0.0;

    // Calculations
    final grossProfit = totalRevenue - cogs;
    final netProfit = grossProfit - totalExpenses;
    final profitMarginPct = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;

    return {
      'total_revenue': totalRevenue,
      'cogs': cogs,
      'gross_profit': grossProfit,
      'total_expenses': totalExpenses,
      'total_discounts': totalDiscounts,
      'delivery_income': totalDeliveryIncome,
      'net_profit': netProfit,
      'profit_margin_pct': profitMarginPct,
      'is_profitable': netProfit >= 0,
    };
  }

  /// Weekly chart data
  Future<List<Map<String, dynamic>>> getWeeklySales() async {
    final db = await _db;
    final workerId = await _getWorkerId();
    final bool isWorker = workerId != null && workerId.isNotEmpty;

    final maps = await db.rawQuery(
        isWorker
            ? '''
              SELECT DATE(created_at) AS day, COALESCE(SUM(grand_total), 0) AS total
              FROM orders
              WHERE created_at >= datetime('now', '-7 days') AND (created_by = ? OR assigned_worker_id = ?)
              GROUP BY DATE(created_at)
              ORDER BY day ASC
              '''
            : '''
              SELECT DATE(created_at) AS day, COALESCE(SUM(grand_total), 0) AS total
              FROM orders
              WHERE created_at >= datetime('now', '-7 days')
              GROUP BY DATE(created_at)
              ORDER BY day ASC
              ''',
        isWorker ? [workerId, workerId] : null);
    return List<Map<String, dynamic>>.from(maps);
  }

  /// Monthly chart data (last 6 months)
  Future<List<Map<String, dynamic>>> getMonthlySales() async {
    final db = await _db;
    final workerId = await _getWorkerId();
    final bool isWorker = workerId != null && workerId.isNotEmpty;

    final maps = await db.rawQuery(
        isWorker
            ? '''
              SELECT strftime('%Y-%m', created_at) AS month, COALESCE(SUM(grand_total), 0) AS total
              FROM orders
              WHERE created_at >= datetime('now', '-6 months') AND (created_by = ? OR assigned_worker_id = ?)
              GROUP BY strftime('%Y-%m', created_at)
              ORDER BY month ASC
              '''
            : '''
              SELECT strftime('%Y-%m', created_at) AS month, COALESCE(SUM(grand_total), 0) AS total
              FROM orders
              WHERE created_at >= datetime('now', '-6 months')
              GROUP BY strftime('%Y-%m', created_at)
              ORDER BY month ASC
              ''',
        isWorker ? [workerId, workerId] : null);
    return List<Map<String, dynamic>>.from(maps);
  }

  Future<List<Map<String, dynamic>>> getTopCustomers() async {
    final db = await _db;
    final workerId = await _getWorkerId();
    final bool isWorker = workerId != null && workerId.isNotEmpty;

    final maps = await db.rawQuery(
        isWorker
            ? '''
              SELECT
                c.id,
                c.name,
                c.photo_path,
                c.outstanding_balance,
                COUNT(o.id) AS total_orders,
                COALESCE(SUM(o.grand_total), 0) AS total_purchase,
                COALESCE(SUM(o.paid_amount), 0) AS total_paid,
                COALESCE(SUM(o.remaining_amount), 0) AS pending_amount,
                MAX(o.created_at) AS last_order_date
              FROM customers c
              LEFT JOIN orders o ON c.id = o.customer_id AND o.delivery_status != 'cancelled' AND (o.created_by = ? OR o.assigned_worker_id = ?)
              WHERE (c.assigned_worker_id = ? OR c.created_by = ? OR c.id IN (SELECT entity_id FROM worker_assignments WHERE worker_id = ? AND entity_type = 'customer'))
              GROUP BY c.id
              '''
            : '''
              SELECT
                c.id,
                c.name,
                c.photo_path,
                c.outstanding_balance,
                COUNT(o.id) AS total_orders,
                COALESCE(SUM(o.grand_total), 0) AS total_purchase,
                COALESCE(SUM(o.paid_amount), 0) AS total_paid,
                COALESCE(SUM(o.remaining_amount), 0) AS pending_amount,
                MAX(o.created_at) AS last_order_date
              FROM customers c
              LEFT JOIN orders o ON c.id = o.customer_id AND o.delivery_status != 'cancelled'
              GROUP BY c.id
              ''',
        isWorker ? [workerId, workerId, workerId, workerId, workerId] : null);
    return List<Map<String, dynamic>>.from(maps);
  }

  Future<Map<String, dynamic>> getTodaysDetailedReport() async {
    final db = await _db;
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day).toIso8601String();

    final workerId = await _getWorkerId();
    final bool isWorker = workerId != null && workerId.isNotEmpty;

    // Today's orders
    final orderMaps = await db.rawQuery(
        isWorker
            ? '''
              SELECT o.*, o.rowid AS order_number, c.name AS customer_name
              FROM orders o
              LEFT JOIN customers c ON o.customer_id = c.id
              WHERE DATE(o.created_at) = DATE(?) AND (o.created_by = ? OR o.assigned_worker_id = ?)
              ORDER BY o.created_at DESC
              '''
            : '''
              SELECT o.*, o.rowid AS order_number, c.name AS customer_name
              FROM orders o
              LEFT JOIN customers c ON o.customer_id = c.id
              WHERE DATE(o.created_at) = DATE(?)
              ORDER BY o.created_at DESC
              ''',
        isWorker ? [today, workerId, workerId] : [today]);

    // Today's items sold
    final itemMaps = await db.rawQuery(
        isWorker
            ? '''
              SELECT item_name, item_unit, SUM(quantity) AS qty, SUM(total_price) AS total
              FROM order_items
              WHERE order_id IN (SELECT id FROM orders WHERE DATE(created_at) = DATE(?) AND (created_by = ? OR assigned_worker_id = ?))
              GROUP BY item_name, item_unit
              ORDER BY qty DESC
              '''
            : '''
              SELECT item_name, item_unit, SUM(quantity) AS qty, SUM(total_price) AS total
              FROM order_items
              WHERE order_id IN (SELECT id FROM orders WHERE DATE(created_at) = DATE(?))
              GROUP BY item_name, item_unit
              ORDER BY qty DESC
              ''',
        isWorker ? [today, workerId, workerId] : [today]);

    // Today's payment breakdown
    final cashPayments = await db.rawQuery(
        isWorker
            ? '''
              SELECT COALESCE(SUM(amount), 0) AS v
              FROM payments
              WHERE DATE(created_at) = DATE(?) AND method = 'cash' AND (created_by = ? OR assigned_worker_id = ?)
              '''
            : '''
              SELECT COALESCE(SUM(amount), 0) AS v
              FROM payments
              WHERE DATE(created_at) = DATE(?) AND method = 'cash'
              ''',
        isWorker ? [today, workerId, workerId] : [today]);

    final onlinePayments = await db.rawQuery(
        isWorker
            ? '''
              SELECT COALESCE(SUM(amount), 0) AS v
              FROM payments
              WHERE DATE(created_at) = DATE(?) AND method != 'cash' AND (created_by = ? OR assigned_worker_id = ?)
              '''
            : '''
              SELECT COALESCE(SUM(amount), 0) AS v
              FROM payments
              WHERE DATE(created_at) = DATE(?) AND method != 'cash'
              ''',
        isWorker ? [today, workerId, workerId] : [today]);

    final totalSales = await db.rawQuery(
        isWorker
            ? '''
              SELECT COALESCE(SUM(grand_total), 0) AS v
              FROM orders
              WHERE DATE(created_at) = DATE(?) AND (created_by = ? OR assigned_worker_id = ?)
              '''
            : '''
              SELECT COALESCE(SUM(grand_total), 0) AS v
              FROM orders
              WHERE DATE(created_at) = DATE(?)
              ''',
        isWorker ? [today, workerId, workerId] : [today]);

    final double totalSalesVal = (totalSales.first['v'] as num?)?.toDouble() ?? 0.0;
    final double cashReceivedVal = (cashPayments.first['v'] as num?)?.toDouble() ?? 0.0;
    final double onlineReceivedVal = (onlinePayments.first['v'] as num?)?.toDouble() ?? 0.0;
    final double pendingVal = totalSalesVal - (cashReceivedVal + onlineReceivedVal);

    return {
      'orders': orderMaps.map(AppOrder.fromMap).toList(),
      'items': itemMaps,
      'cash_received': cashReceivedVal,
      'online_received': onlineReceivedVal,
      'total_sales': totalSalesVal,
      'pending_amount': pendingVal,
    };
  }

  /// Compute customer savings: order-level discounts + market-price savings
  /// Returns {'total': double, 'monthly': double, 'order_count': int}
  Future<Map<String, double>> getCustomerSavings(String customerId) async {
    final db   = await _db;
    final now  = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // ── All-time: sum of discounts + (market_price - unit_price) × qty ─────
    final allTimeResult = await db.rawQuery('''
      SELECT
        COALESCE(SUM(o.discount), 0) AS discount_savings,
        COALESCE(SUM(
          CASE
            WHEN oi.item_id != '' AND i.market_price > oi.unit_price
            THEN (i.market_price - oi.unit_price) * oi.quantity
            ELSE 0
          END
        ), 0) AS market_savings
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      LEFT JOIN items i ON i.id = oi.item_id
      WHERE o.customer_id = ?
        AND o.delivery_status != 'cancelled'
    ''', [customerId]);

    // ── This month ──────────────────────────────────────────────────────────
    final monthlyResult = await db.rawQuery('''
      SELECT
        COALESCE(SUM(o.discount), 0) AS discount_savings,
        COALESCE(SUM(
          CASE
            WHEN oi.item_id != '' AND i.market_price > oi.unit_price
            THEN (i.market_price - oi.unit_price) * oi.quantity
            ELSE 0
          END
        ), 0) AS market_savings
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      LEFT JOIN items i ON i.id = oi.item_id
      WHERE o.customer_id = ?
        AND o.delivery_status != 'cancelled'
        AND strftime('%Y-%m', o.created_at) = ?
    ''', [customerId, month]);

    final allDisc   = (allTimeResult.first['discount_savings'] as num?)?.toDouble() ?? 0;
    final allMarket = (allTimeResult.first['market_savings']   as num?)?.toDouble() ?? 0;
    final monDisc   = (monthlyResult.first['discount_savings'] as num?)?.toDouble() ?? 0;
    final monMarket = (monthlyResult.first['market_savings']   as num?)?.toDouble() ?? 0;

    return {
      'total':   allDisc + allMarket,
      'monthly': monDisc + monMarket,
    };
  }
}
