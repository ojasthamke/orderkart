/// OrderDao — complete SQLite operations for orders

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../domain/order.dart';
import '../domain/order_item.dart';
import '../domain/payment.dart';

class OrderDao {
  final _uuid = const Uuid();
  Future<Database> get _db => DatabaseHelper.instance.database;

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
    final id  = order.id.isEmpty ? _uuid.v4() : order.id;
    final now = DateTime.now().toIso8601String();
    await db.insert('orders', {
      ...order.toMap(),
      'id':         id,
      'created_at': now,
      'updated_at': now,
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
    await db.insert('payments', {
      ...payment.toMap(),
      'id': payment.id.isEmpty ? _uuid.v4() : payment.id,
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

  /// Analytics summary query
  Future<Map<String, dynamic>> getAnalyticsSummary() async {
    final db = await _db;
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day).toIso8601String();
    final month  = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final todaySales = await db.rawQuery(
        'SELECT COALESCE(SUM(grand_total),0) AS v FROM orders WHERE DATE(created_at) = DATE(?)',
        [today]);
    final monthlySales = await db.rawQuery(
        "SELECT COALESCE(SUM(grand_total),0) AS v FROM orders WHERE strftime('%Y-%m', created_at) = ?",
        [month]);
    final pendingPayments = await db.rawQuery(
        'SELECT COALESCE(SUM(remaining_amount),0) AS v FROM orders WHERE remaining_amount > 0');
    final cashReceived = await db.rawQuery(
        "SELECT COALESCE(SUM(amount),0) AS v FROM payments WHERE method = 'cash'");
    final onlineReceived = await db.rawQuery(
        "SELECT COALESCE(SUM(amount),0) AS v FROM payments WHERE method != 'cash'");
    final totalExpenses = await db.rawQuery(
        'SELECT COALESCE(SUM(amount),0) AS v FROM expenses');
    final customerCount = await db.rawQuery(
        'SELECT COUNT(*) AS v FROM customers');
    final orderCount = await db.rawQuery(
        'SELECT COUNT(*) AS v FROM orders');
    final itemCount = await db.rawQuery(
        'SELECT COUNT(*) AS v FROM items');

    // Top selling items
    final topItems = await db.rawQuery('''
      SELECT item_name, SUM(total_price) AS revenue, SUM(quantity) AS qty
      FROM order_items
      GROUP BY item_name
      ORDER BY revenue DESC
      LIMIT 5
    ''');

    // Low stock items
    final lowStock = await db.rawQuery(
        'SELECT * FROM items WHERE min_stock > 0 AND stock <= min_stock ORDER BY stock ASC LIMIT 10');

    // Status counts
    final deliveredOrders = await db.rawQuery(
        "SELECT COUNT(*) AS v FROM orders WHERE delivery_status = 'delivered'");
    final pendingOrders = await db.rawQuery(
        "SELECT COUNT(*) AS v FROM orders WHERE delivery_status = 'pending'");
    final cancelledOrders = await db.rawQuery(
        "SELECT COUNT(*) AS v FROM orders WHERE delivery_status = 'cancelled'");

    // All-time sales
    final allTimeSales = await db.rawQuery(
        'SELECT COALESCE(SUM(grand_total),0) AS v FROM orders');

    // Delivery fees collected
    final allTimeDelivery = await db.rawQuery(
        'SELECT COALESCE(SUM(delivery_charge),0) AS v FROM orders');

    return {
      'today_sales':      (todaySales.first['v'] as num?)?.toDouble()    ?? 0,
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

  /// Weekly chart data
  Future<List<Map<String, dynamic>>> getWeeklySales() async {
    final db = await _db;
    final maps = await db.rawQuery('''
      SELECT DATE(created_at) AS day, COALESCE(SUM(grand_total), 0) AS total
      FROM orders
      WHERE created_at >= datetime('now', '-7 days')
      GROUP BY DATE(created_at)
      ORDER BY day ASC
    ''');
    return List<Map<String, dynamic>>.from(maps);
  }

  /// Monthly chart data (last 6 months)
  Future<List<Map<String, dynamic>>> getMonthlySales() async {
    final db = await _db;
    final maps = await db.rawQuery('''
      SELECT strftime('%Y-%m', created_at) AS month, COALESCE(SUM(grand_total), 0) AS total
      FROM orders
      WHERE created_at >= datetime('now', '-6 months')
      GROUP BY strftime('%Y-%m', created_at)
      ORDER BY month ASC
    ''');
    return List<Map<String, dynamic>>.from(maps);
  }

  Future<List<Map<String, dynamic>>> getTopCustomers() async {
    final db = await _db;
    final maps = await db.rawQuery('''
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
    ''');
    return List<Map<String, dynamic>>.from(maps);
  }

  Future<Map<String, dynamic>> getTodaysDetailedReport() async {
    final db = await _db;
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day).toIso8601String();

    // Today's orders
    final orderMaps = await db.rawQuery('''
      SELECT o.*, o.rowid AS order_number, c.name AS customer_name
      FROM orders o
      LEFT JOIN customers c ON o.customer_id = c.id
      WHERE DATE(o.created_at) = DATE(?)
      ORDER BY o.created_at DESC
    ''', [today]);

    // Today's items sold
    final itemMaps = await db.rawQuery('''
      SELECT item_name, item_unit, SUM(quantity) AS qty, SUM(total_price) AS total
      FROM order_items
      WHERE order_id IN (SELECT id FROM orders WHERE DATE(created_at) = DATE(?))
      GROUP BY item_name, item_unit
      ORDER BY qty DESC
    ''', [today]);

    // Today's payment breakdown
    final cashPayments = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS v
      FROM payments
      WHERE DATE(created_at) = DATE(?) AND method = 'cash'
    ''', [today]);

    final onlinePayments = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS v
      FROM payments
      WHERE DATE(created_at) = DATE(?) AND method != 'cash'
    ''', [today]);

    final totalSales = await db.rawQuery('''
      SELECT COALESCE(SUM(grand_total), 0) AS v
      FROM orders
      WHERE DATE(created_at) = DATE(?)
    ''', [today]);

    return {
      'orders': orderMaps.map(AppOrder.fromMap).toList(),
      'items': itemMaps,
      'cash_received': (cashPayments.first['v'] as num?)?.toDouble() ?? 0.0,
      'online_received': (onlinePayments.first['v'] as num?)?.toDouble() ?? 0.0,
      'total_sales': (totalSales.first['v'] as num?)?.toDouble() ?? 0.0,
    };
  }
}
