import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/security/app_mode_service.dart';
import '../domain/order.dart';
import '../domain/order_item.dart';
import '../domain/payment.dart';
import '../../customer/data/customer_dao.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/smart_rounding.dart';

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
      throw Exception(
          'Could not generate a unique order number after 10000 attempts');
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
    int limit = 30,
    int offset = 0,
  }) async {
    final db = await _db;

    List<String> conditions = [];
    List<dynamic> args = [];

    if (customerId != null) {
      conditions.add('o.customer_id = ?');
      args.add(customerId);
    }
    if (status != null && status != 'all') {
      if (status == 'pending') {
        conditions.add("(o.delivery_status = 'pending' OR o.delivery_status = 'confirmed' OR o.delivery_status = 'preparing' OR o.delivery_status = 'out for delivery')");
      } else {
        conditions.add('o.delivery_status = ?');
        args.add(status);
      }
    }

    // Date filters - Use effective schedule date (order_taking_date for pre-orders, created_at for normal orders)
    const effectiveDateSql = "(CASE WHEN o.order_type = 'Pre-Order' AND o.order_taking_date IS NOT NULL AND o.order_taking_date != '' THEN DATE(o.order_taking_date) ELSE DATE(o.created_at) END)";
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    if (startDate != null && endDate != null) {
      final startStr = "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      final endStr = "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
      conditions.add('$effectiveDateSql >= ? AND $effectiveDateSql <= ?');
      args.add(startStr);
      args.add(endStr);
    } else if (filter == 'today') {
      conditions.add('$effectiveDateSql = ?');
      args.add(todayStr);
    } else if (filter == 'yesterday') {
      final yesterday = today.subtract(const Duration(days: 1));
      final yestStr = "${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
      conditions.add('$effectiveDateSql = ?');
      args.add(yestStr);
    } else if (filter == 'week') {
      final weekAgo = today.subtract(const Duration(days: 7));
      final weekStr = "${weekAgo.year.toString().padLeft(4, '0')}-${weekAgo.month.toString().padLeft(2, '0')}-${weekAgo.day.toString().padLeft(2, '0')}";
      conditions.add('$effectiveDateSql >= ?');
      args.add(weekStr);
    } else if (filter == 'month') {
      final monthStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}";
      conditions.add('strftime(\'%Y-%m\', $effectiveDateSql) = ?');
      args.add(monthStr);
    }

    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    args.addAll([limit, offset]);

    final maps = await db.rawQuery('''
      SELECT
        o.*,
        o.rowid   AS order_number,
        o.order_number AS order_number_str,
        c.name    AS customer_name,
        c.address AS customer_address,
        c.phone1  AS customer_phone
      FROM orders o
      LEFT JOIN customers c ON o.customer_id = c.id
      $where
      ORDER BY o.created_at DESC
      LIMIT ? OFFSET ?
    ''', args);

    return maps.map(AppOrder.fromMap).toList();
  }

  /// Get top ordered items by a specific customer for quick-add recommendations
  Future<List<Map<String, dynamic>>> getCustomerTopOrderedItems(
      String customerId,
      {int limit = 6}) async {
    final db = await _db;
    try {
      final rows = await db.rawQuery('''
        SELECT 
          oi.item_id,
          oi.item_name,
          oi.item_unit,
          oi.unit_price,
          COUNT(oi.id) AS order_count,
          AVG(oi.quantity) AS avg_qty,
          i.stock,
          i.selling_price,
          i.cost_price,
          i.unit
        FROM order_items oi
        INNER JOIN orders o ON oi.order_id = o.id
        LEFT JOIN items i ON oi.item_id = i.id
        WHERE o.customer_id = ? AND (o.delivery_status IS NULL OR (o.delivery_status != 'cancelled' AND o.delivery_status != 'denied'))
        GROUP BY oi.item_id, oi.item_name, oi.item_unit
        ORDER BY order_count DESC
        LIMIT ?
      ''', [customerId, limit]);
      return rows;
    } catch (_) {
      return [];
    }
  }

  Future<AppOrder?> getOrderById(String id,
      {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final maps = await db.rawQuery('''
      SELECT o.*, o.rowid AS order_number, o.order_number AS order_number_str, c.name AS customer_name, c.address AS customer_address, c.phone1 AS customer_phone
      FROM orders o LEFT JOIN customers c ON o.customer_id = c.id
      WHERE o.id = ?
    ''', [id]);
    if (maps.isEmpty) return null;
    return AppOrder.fromMap(maps.first);
  }

  Future<List<OrderItem>> getOrderItems(String orderId,
      {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final maps = await db
        .query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
    return maps.map(OrderItem.fromMap).toList();
  }

  Future<List<Payment>> getOrderPayments(String orderId,
      {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final maps = await db.query('payments',
        where: 'order_id = ?',
        whereArgs: [orderId],
        orderBy: 'created_at DESC');
    return maps.map(Payment.fromMap).toList();
  }

  Future<String> insertOrder(AppOrder order,
      {DatabaseExecutor? executor, AppMode? appMode}) async {
    final db = await _getExecutor(executor);
    final id = order.id.isEmpty ? await generateUniqueOrderNo() : order.id;
    final now = DateTime.now().toIso8601String();

    String workerId = order.assignedWorkerId;
    double commRate = 0.0;
    String commType = '';

    if (workerId.isEmpty) {
      final cust = await db.query('customers',
          columns: ['assigned_worker_id'],
          where: 'id = ?',
          whereArgs: [order.customerId]);
      if (cust.isNotEmpty) {
        workerId = cust.first['assigned_worker_id'] as String? ?? '';
      }
    }

    if (workerId.isNotEmpty) {
      final w =
          await db.query('workers', where: 'id = ?', whereArgs: [workerId]);
      if (w.isNotEmpty) {
        commRate = (w.first['commission_value'] as num?)?.toDouble() ?? 5.0;
        commType = w.first['commission_type'] as String? ?? 'pct_order';
      }
    }

    // Use passed appMode to avoid deadlock when called inside a transaction
    final mode = appMode ?? await AppModeService.getAppMode();
    String createdBy = order.createdBy;
    String assignedWorkerId =
        workerId.isNotEmpty ? workerId : order.assignedWorkerId;
    String workerName = order.workerName;
    String deviceName = order.deviceName;

    if (mode == AppMode.worker) {
      final settingsRes = await db
          .query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      final activeWorkerId = settingsRes.isNotEmpty
          ? settingsRes.first['value']?.toString()
          : null;
      if (activeWorkerId != null && activeWorkerId.isNotEmpty) {
        createdBy = activeWorkerId;
        assignedWorkerId = activeWorkerId;
        final workerRow = await db
            .query('workers', where: 'id = ?', whereArgs: [activeWorkerId]);
        if (workerRow.isNotEmpty) {
          workerName = workerRow.first['name']?.toString() ?? '';
        }
        deviceName = 'Worker Mobile';
      }
    }

    final map = order.toMap();
    final String finalOrderNumber = order.orderNumberStr.isNotEmpty
        ? order.orderNumberStr
        : 'OFF-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${(DateTime.now().millisecondsSinceEpoch % 1000).toString().padLeft(3, '0')}';

    final existing = await db.query('orders',
        columns: ['id'], where: 'id = ?', whereArgs: [id]);
    if (existing.isNotEmpty) {
      await db.update(
          'orders',
          {
            ...map,
            'order_number': finalOrderNumber,
            'assigned_worker_id': assignedWorkerId,
            'created_by': createdBy,
            'worker_name': workerName,
            'device_name': deviceName,
            'commission_rate': commRate > 0 ? commRate : 5.0,
            'commission_type': commType.isNotEmpty ? commType : 'pct_order',
            'updated_at': now,
            'sync_status': 'pending_update',
          },
          where: 'id = ?',
          whereArgs: [id]);
    } else {
      await db.insert('orders', {
        ...map,
        'id': id,
        'order_number': finalOrderNumber,
        'assigned_worker_id': assignedWorkerId,
        'created_by': createdBy,
        'worker_name': workerName,
        'device_name': deviceName,
        'commission_rate': commRate > 0 ? commRate : 5.0,
        'commission_type': commType.isNotEmpty ? commType : 'pct_order',
        'created_at': order.createdAt.toIso8601String(),
        'updated_at': now,
        'sync_status': 'pending_update',
      });
    }
    return id;
  }

  Future<void> insertOrderItem(OrderItem item,
      {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final id = item.id.isEmpty ? _uuid.v4() : item.id;
    await db.insert(
        'order_items',
        {
          ...item.toMap(),
          'id': id,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteOrderItems(String orderId,
      {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    await db.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
  }

  Future<void> updateOrder(AppOrder order, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    await db.update(
      'orders',
      {
        ...order.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending_update',
      },
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  /// Update rates for all items in an order to their current selling price
  /// (or custom customer price if defined). Recalculates subtotal, grandTotal, and remaining.
  Future<Map<String, dynamic>> updateOrderRates(String orderId,
      {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);

    final orderMaps =
        await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (orderMaps.isEmpty) {
      return {
        'success': false,
        'message': 'Order not found',
        'updatedCount': 0
      };
    }
    final order = AppOrder.fromMap(orderMaps.first);

    final itemMaps = await db
        .query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
    final orderItems = itemMaps.map(OrderItem.fromMap).toList();

    if (orderItems.isEmpty) {
      return {
        'success': false,
        'message': 'No items in this order',
        'updatedCount': 0
      };
    }

    final custRes = await db.query('customers',
        where: 'id = ?', whereArgs: [order.customerId], limit: 1);
    bool isVipActive = false;
    double vipMarkupPct = 0.0;
    if (custRes.isNotEmpty) {
      final c = custRes.first;
      final isVip = (c['is_vip'] as int? ?? 0) == 1;
      final expiryStr = c['vip_expiry_date'] as String? ?? '';
      if (isVip) {
        if (expiryStr.isEmpty) {
          isVipActive = true;
        } else {
          final expiry = DateTime.tryParse(expiryStr);
          isVipActive = expiry != null && expiry.isAfter(DateTime.now());
        }
      }
      vipMarkupPct = (c['vip_markup_pct'] as num?)?.toDouble() ?? 0.0;
    }

    double newSubtotal = 0.0;
    int updatedCount = 0;

    for (final item in orderItems) {
      if (item.itemId.isEmpty) {
        newSubtotal += item.totalPrice;
        continue;
      }

      final dbItems = await db.query('items',
          columns: ['selling_price', 'unit', 'weight_per_piece'],
          where: 'id = ?',
          whereArgs: [item.itemId]);
      if (dbItems.isEmpty) {
        newSubtotal += item.totalPrice;
        continue;
      }

      final dbRow = dbItems.first;
      double basePrice = (dbRow['selling_price'] as num).toDouble();
      final String dbUnit = dbRow['unit']?.toString() ?? item.itemUnit;
      final double weightPerPiece =
          (dbRow['weight_per_piece'] as num?)?.toDouble() ?? 1.0;
      final conversion = weightPerPiece > 0 ? weightPerPiece : 1.0;
      bool hasCustomPrice = false;

      try {
        final custPrices = await db.query(
          'customer_item_prices',
          columns: ['custom_price'],
          where: 'customer_id = ? AND item_id = ?',
          whereArgs: [order.customerId, item.itemId],
        );
        if (custPrices.isNotEmpty) {
          basePrice = (custPrices.first['custom_price'] as num).toDouble();
          hasCustomPrice = true;
        }
      } catch (_) {}

      if (!hasCustomPrice && isVipActive && vipMarkupPct > 0) {
        basePrice = basePrice * (1.0 + (vipMarkupPct / 100.0));
      }

      // Convert rate to item.itemUnit if different from dbUnit
      double itemRate = basePrice;
      if (dbUnit.toLowerCase() == 'kg' &&
          (item.itemUnit.toLowerCase() == 'gram' ||
              item.itemUnit.toLowerCase() == 'g' ||
              item.itemUnit.toLowerCase() == 'gm')) {
        itemRate = basePrice / 1000.0;
      } else if (dbUnit.toLowerCase() == 'kg' &&
          (item.itemUnit.toLowerCase() == 'piece' ||
              item.itemUnit.toLowerCase() == 'pcs')) {
        itemRate = basePrice * conversion;
      } else if (dbUnit.toLowerCase() == 'piece' &&
          (item.itemUnit.toLowerCase() == 'dozen' ||
              item.itemUnit.toLowerCase() == 'dz')) {
        itemRate = basePrice * 12.0;
      } else if (dbUnit.toLowerCase() == 'piece' &&
          item.itemUnit.toLowerCase() == 'kg') {
        itemRate = basePrice / conversion;
      }

      final newTotalPrice =
          double.parse((itemRate * item.quantity).toStringAsFixed(2));

      await db.update(
        'order_items',
        {
          'unit_price': itemRate,
          'total_price': newTotalPrice,
        },
        where: 'id = ?',
        whereArgs: [item.id],
      );

      newSubtotal += newTotalPrice;
      updatedCount++;
    }

    final unroundedGrandTotal =
        math.max(0.0, newSubtotal - order.discount + order.deliveryCharge);

    final settingsMap = await db.query('settings',
        where: "key = ?", whereArgs: [AppConstants.keySmartRounding]);
    final bool isSmartRoundingEnabled = settingsMap.isNotEmpty
        ? (settingsMap.first['value'] == 'true')
        : true;

    double newGrandTotal = unroundedGrandTotal;
    double roundingDiff = 0.0;

    if (isSmartRoundingEnabled || order.smartRoundedAmount != 0) {
      newGrandTotal = SmartRounding.round(unroundedGrandTotal);
      roundingDiff = newGrandTotal - unroundedGrandTotal;
    }

    final newRemaining = newGrandTotal - order.paidAmount;

    await db.update(
      'orders',
      {
        'subtotal': newSubtotal,
        'smart_rounded_amount': roundingDiff,
        'grand_total': newGrandTotal,
        'remaining_amount': newRemaining,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending_update',
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );

    try {
      await CustomerDao().recalcCustomerTotals(order.customerId, executor: db);
    } catch (_) {}

    return {
      'success': true,
      'updatedCount': updatedCount,
      'oldSubtotal': order.subtotal,
      'newSubtotal': newSubtotal,
      'oldGrandTotal': order.grandTotal,
      'newGrandTotal': newGrandTotal,
    };
  }

  Future<void> deleteOrder(String id, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    
    final orderMaps = await db.query('orders',
        columns: ['customer_id', 'delivery_status'],
        where: 'id = ?',
        whereArgs: [id]);
    String? customerId;
    if (orderMaps.isNotEmpty) {
      customerId = orderMaps.first['customer_id'] as String?;
    }

    await db.delete('order_items', where: 'order_id = ?', whereArgs: [id]);
    await db.delete('payments', where: 'order_id = ?', whereArgs: [id]);
    await db.delete('order_question_answers',
        where: 'order_id = ?', whereArgs: [id]);
    await db.delete('stock_history', where: 'order_id = ?', whereArgs: [id]);
    await db.delete('orders', where: 'id = ?', whereArgs: [id]);

    if (customerId != null && customerId.isNotEmpty) {
      try {
        await CustomerDao().recalcCustomerTotals(customerId, executor: db);
      } catch (_) {}
    }
  }

  Future<void> updateDeliveryStatus(String orderId, String status,
      {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final orderMaps = await db.query('orders',
        columns: ['customer_id', 'delivery_status'],
        where: 'id = ?',
        whereArgs: [orderId]);
    if (orderMaps.isEmpty) return;
    final oldStatus = orderMaps.first['delivery_status'] as String?;
    final customerId = orderMaps.first['customer_id'] as String?;

    await db.update(
      'orders',
      {
        'delivery_status': status,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending_update',
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );

    // Stock adjustment is now handled in OrderRepositoryImpl to ensure proper unit conversion

    final wasInactive = oldStatus == 'cancelled' || oldStatus == 'denied';
    final isInactive = status == 'cancelled' || status == 'denied';
    if (wasInactive != isInactive) {
      if (customerId != null && customerId.isNotEmpty) {
        try {
          await CustomerDao().recalcCustomerTotals(customerId, executor: db);
        } catch (_) {}
      }
    }
  }

  Future<void> insertPayment(Payment payment,
      {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final id = payment.id.isEmpty ? _uuid.v4() : payment.id;

    final mode = await AppModeService.getAppMode();
    String createdBy = 'owner';
    String assignedWorkerId = '';
    String workerName = '';
    String deviceName = '';

    if (mode == AppMode.worker) {
      final settingsRes = await db
          .query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      final activeWorkerId = settingsRes.isNotEmpty
          ? settingsRes.first['value']?.toString()
          : null;
      if (activeWorkerId != null && activeWorkerId.isNotEmpty) {
        createdBy = activeWorkerId;
        assignedWorkerId = activeWorkerId;
        final workerRow = await db
            .query('workers', where: 'id = ?', whereArgs: [activeWorkerId]);
        if (workerRow.isNotEmpty) {
          workerName = workerRow.first['name']?.toString() ?? '';
        }
        deviceName = 'Worker Mobile';
      }
    }

    await db.insert(
        'payments',
        {
          ...payment.toMap(),
          'id': id,
          'created_by': createdBy,
          'assigned_worker_id': assignedWorkerId,
          'worker_name': workerName,
          'device_name': deviceName,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateOrderPayment(
      String orderId, double paidAmount, double remainingAmount,
      {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    await db.update(
      'orders',
      {
        'paid_amount': paidAmount,
        'remaining_amount': remainingAmount,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending_update',
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<String?> _getWorkerId() async {
    final db = await _db;
    final mode = await AppModeService.getAppMode();
    if (mode != AppMode.worker) return null;

    final settingsRes = await db
        .query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
    String? workerId =
        settingsRes.isNotEmpty ? settingsRes.first['value']?.toString() : null;
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final workerId = await _getWorkerId();
    final bool isWorker = workerId != null && workerId.isNotEmpty;

    final todaySales = await db.rawQuery(
        isWorker
            ? "SELECT COALESCE(SUM(grand_total),0) AS v FROM orders WHERE DATE(created_at) = DATE(?) AND delivery_status != 'cancelled' AND delivery_status != 'denied' AND (created_by = ? OR assigned_worker_id = ?)"
            : "SELECT COALESCE(SUM(grand_total),0) AS v FROM orders WHERE DATE(created_at) = DATE(?) AND delivery_status != 'cancelled' AND delivery_status != 'denied'",
        isWorker ? [today, workerId, workerId] : [today]);

    final todayOrders = await db.rawQuery(
        isWorker
            ? "SELECT COUNT(*) AS v FROM orders WHERE DATE(created_at) = DATE(?) AND delivery_status != 'cancelled' AND delivery_status != 'denied' AND (created_by = ? OR assigned_worker_id = ?)"
            : "SELECT COUNT(*) AS v FROM orders WHERE DATE(created_at) = DATE(?) AND delivery_status != 'cancelled' AND delivery_status != 'denied'",
        isWorker ? [today, workerId, workerId] : [today]);

    final monthlySales = await db.rawQuery(
        isWorker
            ? "SELECT COALESCE(SUM(grand_total),0) AS v FROM orders WHERE strftime('%Y-%m', created_at) = ? AND delivery_status != 'cancelled' AND delivery_status != 'denied' AND (created_by = ? OR assigned_worker_id = ?)"
            : "SELECT COALESCE(SUM(grand_total),0) AS v FROM orders WHERE strftime('%Y-%m', created_at) = ? AND delivery_status != 'cancelled' AND delivery_status != 'denied'",
        isWorker ? [month, workerId, workerId] : [month]);

    final pendingPayments = await db.rawQuery(
        isWorker
            ? "SELECT COALESCE(SUM(remaining_amount),0) AS v FROM orders WHERE remaining_amount > 0 AND delivery_status != 'cancelled' AND delivery_status != 'denied' AND (created_by = ? OR assigned_worker_id = ?)"
            : "SELECT COALESCE(SUM(remaining_amount),0) AS v FROM orders WHERE remaining_amount > 0 AND delivery_status != 'cancelled' AND delivery_status != 'denied'",
        isWorker ? [workerId, workerId] : null);

    final cashReceived = await db.rawQuery(
        isWorker
            ? "SELECT COALESCE(SUM(p.amount),0) AS v FROM payments p JOIN orders o ON p.order_id = o.id WHERE p.method = 'cash' AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied' AND (o.created_by = ? OR o.assigned_worker_id = ?)"
            : "SELECT COALESCE(SUM(p.amount),0) AS v FROM payments p JOIN orders o ON p.order_id = o.id WHERE p.method = 'cash' AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied'",
        isWorker ? [workerId, workerId] : null);

    final onlineReceived = await db.rawQuery(
        isWorker
            ? "SELECT COALESCE(SUM(p.amount),0) AS v FROM payments p JOIN orders o ON p.order_id = o.id WHERE p.method != 'cash' AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied' AND (o.created_by = ? OR o.assigned_worker_id = ?)"
            : "SELECT COALESCE(SUM(p.amount),0) AS v FROM payments p JOIN orders o ON p.order_id = o.id WHERE p.method != 'cash' AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied'",
        isWorker ? [workerId, workerId] : null);

    final totalExpenses = await db.rawQuery(
        isWorker
            ? 'SELECT COALESCE(SUM(amount),0) AS v FROM expenses WHERE (created_by = ? OR assigned_worker_id = ?)'
            : 'SELECT COALESCE(SUM(amount),0) AS v FROM expenses',
        isWorker ? [workerId, workerId] : null);

    final customerCount = await db.rawQuery(
        isWorker
            ? "SELECT COUNT(*) AS v FROM customers WHERE is_archived = 0 AND (created_by = ? OR assigned_worker_id = ? OR id IN (SELECT entity_id FROM worker_assignments WHERE worker_id = ? AND entity_type = 'customer'))"
            : 'SELECT COUNT(*) AS v FROM customers WHERE is_archived = 0',
        isWorker ? [workerId, workerId, workerId] : null);

    final orderCount = await db.rawQuery(
        isWorker
            ? "SELECT COUNT(*) AS v FROM orders WHERE delivery_status != 'cancelled' AND delivery_status != 'denied' AND (created_by = ? OR assigned_worker_id = ?)"
            : "SELECT COUNT(*) AS v FROM orders WHERE delivery_status != 'cancelled' AND delivery_status != 'denied'",
        isWorker ? [workerId, workerId] : null);

    final itemCount = await db
        .rawQuery('SELECT COUNT(*) AS v FROM items WHERE is_archived = 0');

    final vipCount = await db.rawQuery(
        isWorker
            ? "SELECT COUNT(*) AS v FROM customers WHERE is_vip = 1 AND is_archived = 0 AND (created_by = ? OR assigned_worker_id = ?)"
            : "SELECT COUNT(*) AS v FROM customers WHERE is_vip = 1 AND is_archived = 0",
        isWorker ? [workerId, workerId] : null);

    final todayExpenses = await db.rawQuery(
        isWorker
            ? 'SELECT COALESCE(SUM(amount),0) AS v FROM expenses WHERE DATE(created_at) = DATE(?) AND (created_by = ? OR assigned_worker_id = ?)'
            : 'SELECT COALESCE(SUM(amount),0) AS v FROM expenses WHERE DATE(created_at) = DATE(?)',
        isWorker ? [today, workerId, workerId] : [today]);

    const cogsScaleSql = '''
      COALESCE(SUM(
        CASE
          WHEN oi.item_id != '' AND (LOWER(COALESCE(oi.item_unit, '')) = 'gram' OR LOWER(COALESCE(oi.item_unit, '')) = 'gm') AND LOWER(COALESCE(i.unit, '')) = 'kg'
          THEN (oi.quantity / 1000.0) * COALESCE(i.cost_price, 0)
          WHEN oi.item_id != '' AND LOWER(COALESCE(oi.item_unit, '')) = 'kg' AND (LOWER(COALESCE(i.unit, '')) = 'gram' OR LOWER(COALESCE(i.unit, '')) = 'gm')
          THEN (oi.quantity * 1000.0) * COALESCE(i.cost_price, 0)
          ELSE oi.quantity * COALESCE(i.cost_price, 0)
        END
      ), 0)
    ''';

    final todayCogsRes = await db.rawQuery(
        isWorker
            ? "SELECT $cogsScaleSql AS v FROM order_items oi JOIN orders o ON oi.order_id = o.id LEFT JOIN items i ON oi.item_id = i.id WHERE DATE(o.created_at) = DATE(?) AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied' AND (o.created_by = ? OR o.assigned_worker_id = ?)"
            : "SELECT $cogsScaleSql AS v FROM order_items oi JOIN orders o ON oi.order_id = o.id LEFT JOIN items i ON oi.item_id = i.id WHERE DATE(o.created_at) = DATE(?) AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied'",
        isWorker ? [today, workerId, workerId] : [today]);

    final monthlyExpensesRes = await db.rawQuery(
        isWorker
            ? "SELECT COALESCE(SUM(amount), 0) AS v FROM expenses WHERE strftime('%Y-%m', created_at) = ? AND (created_by = ? OR assigned_worker_id = ?)"
            : "SELECT COALESCE(SUM(amount), 0) AS v FROM expenses WHERE strftime('%Y-%m', created_at) = ?",
        isWorker ? [month, workerId, workerId] : [month]);

    final monthlyCogsRes = await db.rawQuery(
        isWorker
            ? "SELECT $cogsScaleSql AS v FROM order_items oi JOIN orders o ON oi.order_id = o.id LEFT JOIN items i ON oi.item_id = i.id WHERE strftime('%Y-%m', o.created_at) = ? AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied' AND (o.created_by = ? OR o.assigned_worker_id = ?)"
            : "SELECT $cogsScaleSql AS v FROM order_items oi JOIN orders o ON oi.order_id = o.id LEFT JOIN items i ON oi.item_id = i.id WHERE strftime('%Y-%m', o.created_at) = ? AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied'",
        isWorker ? [month, workerId, workerId] : [month]);

    final double tSales = (todaySales.first['v'] as num?)?.toDouble() ?? 0.0;
    final double mSales = (monthlySales.first['v'] as num?)?.toDouble() ?? 0.0;
    final double tCogs = (todayCogsRes.first['v'] as num?)?.toDouble() ?? 0.0;
    final double mCogs = (monthlyCogsRes.first['v'] as num?)?.toDouble() ?? 0.0;
    final double tExp = (todayExpenses.first['v'] as num?)?.toDouble() ?? 0.0;
    final double mExp =
        (monthlyExpensesRes.first['v'] as num?)?.toDouble() ?? 0.0;

    final double todayNetProfit = (tSales - tCogs) - tExp;
    final double monthlyNetProfit = (mSales - mCogs) - mExp;

    // Top selling items
    final topItems = await db.rawQuery(
        isWorker
            ? '''
              SELECT item_name, SUM(total_price) AS revenue, SUM(quantity) AS qty
              FROM order_items
              WHERE order_id IN (SELECT id FROM orders WHERE delivery_status != 'cancelled' AND delivery_status != 'denied' AND (created_by = ? OR assigned_worker_id = ?))
              GROUP BY item_name
              ORDER BY revenue DESC
              LIMIT 5
              '''
            : '''
              SELECT item_name, SUM(total_price) AS revenue, SUM(quantity) AS qty
              FROM order_items
              WHERE order_id IN (SELECT id FROM orders WHERE delivery_status != 'cancelled' AND delivery_status != 'denied')
              GROUP BY item_name
              ORDER BY revenue DESC
              LIMIT 5
              ''',
        isWorker ? [workerId, workerId] : null);

    // Low stock items
    final lowStock = await db.rawQuery(
        'SELECT * FROM items WHERE min_stock > 0 AND stock <= min_stock AND is_archived = 0 ORDER BY stock ASC LIMIT 10');

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
            ? "SELECT COALESCE(SUM(grand_total),0) AS v FROM orders WHERE delivery_status != 'cancelled' AND delivery_status != 'denied' AND (created_by = ? OR assigned_worker_id = ?)"
            : "SELECT COALESCE(SUM(grand_total),0) AS v FROM orders WHERE delivery_status != 'cancelled' AND delivery_status != 'denied'",
        isWorker ? [workerId, workerId] : null);

    // Delivery fees collected
    final allTimeDelivery = await db.rawQuery(
        isWorker
            ? "SELECT COALESCE(SUM(delivery_charge),0) AS v FROM orders WHERE delivery_status != 'cancelled' AND delivery_status != 'denied' AND (created_by = ? OR assigned_worker_id = ?)"
            : "SELECT COALESCE(SUM(delivery_charge),0) AS v FROM orders WHERE delivery_status != 'cancelled' AND delivery_status != 'denied'",
        isWorker ? [workerId, workerId] : null);

    return {
      'today_sales': (todaySales.first['v'] as num?)?.toDouble() ?? 0,
      'today_orders_count': todayOrders.first['v'] ?? 0,
      'monthly_sales': (monthlySales.first['v'] as num?)?.toDouble() ?? 0,
      'pending_payments': (pendingPayments.first['v'] as num?)?.toDouble() ?? 0,
      'cash_received': (cashReceived.first['v'] as num?)?.toDouble() ?? 0,
      'online_received': (onlineReceived.first['v'] as num?)?.toDouble() ?? 0,
      'total_expenses': (totalExpenses.first['v'] as num?)?.toDouble() ?? 0,
      'customer_count': customerCount.first['v'] ?? 0,
      'order_count': orderCount.first['v'] ?? 0,
      'item_count': itemCount.first['v'] ?? 0,
      'top_items': topItems,
      'low_stock': lowStock,
      'delivered_count': deliveredOrders.first['v'] ?? 0,
      'pending_count': pendingOrders.first['v'] ?? 0,
      'cancelled_count': cancelledOrders.first['v'] ?? 0,
      'all_time_sales': (allTimeSales.first['v'] as num?)?.toDouble() ?? 0,
      'delivery_fees': (allTimeDelivery.first['v'] as num?)?.toDouble() ?? 0,
      'vip_count': vipCount.first['v'] ?? 0,
      'today_expenses': tExp,
      'today_profit': todayNetProfit,
      'monthly_profit': monthlyNetProfit,
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
            ? "SELECT COALESCE(SUM(grand_total), 0) AS v FROM orders WHERE (created_by = ? OR assigned_worker_id = ?) AND delivery_status != 'cancelled' AND delivery_status != 'denied'"
            : "SELECT COALESCE(SUM(grand_total), 0) AS v FROM orders WHERE delivery_status != 'cancelled' AND delivery_status != 'denied'",
        isWorker ? [workerId, workerId] : null);
    final totalRevenue = (revenueRes.first['v'] as num?)?.toDouble() ?? 0.0;

    // 2. Cost of Goods Sold (COGS) — with unit conversion
    const cogsSql = '''
      COALESCE(SUM(
        CASE
          WHEN oi.item_id != '' AND (LOWER(COALESCE(oi.item_unit, '')) = 'gram' OR LOWER(COALESCE(oi.item_unit, '')) = 'gm') AND LOWER(COALESCE(i.unit, '')) = 'kg'
          THEN (oi.quantity / 1000.0) * COALESCE(i.cost_price, 0)
          WHEN oi.item_id != '' AND LOWER(COALESCE(oi.item_unit, '')) = 'kg' AND (LOWER(COALESCE(i.unit, '')) = 'gram' OR LOWER(COALESCE(i.unit, '')) = 'gm')
          THEN (oi.quantity * 1000.0) * COALESCE(i.cost_price, 0)
          ELSE oi.quantity * COALESCE(i.cost_price, 0)
        END
      ), 0)
    ''';
    final cogsRes = await db.rawQuery(
        isWorker
            ? '''
              SELECT $cogsSql AS v
              FROM order_items oi
              LEFT JOIN items i ON oi.item_id = i.id
              WHERE oi.order_id IN (SELECT id FROM orders WHERE (created_by = ? OR assigned_worker_id = ?) AND delivery_status != 'cancelled' AND delivery_status != 'denied')
              '''
            : '''
              SELECT $cogsSql AS v
              FROM order_items oi
              LEFT JOIN items i ON oi.item_id = i.id
              WHERE oi.order_id IN (SELECT id FROM orders WHERE delivery_status != 'cancelled' AND delivery_status != 'denied')
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
            ? "SELECT COALESCE(SUM(discount), 0) AS v FROM orders WHERE (created_by = ? OR assigned_worker_id = ?) AND delivery_status != 'cancelled' AND delivery_status != 'denied'"
            : "SELECT COALESCE(SUM(discount), 0) AS v FROM orders WHERE delivery_status != 'cancelled' AND delivery_status != 'denied'",
        isWorker ? [workerId, workerId] : null);
    final totalDiscounts = (discountRes.first['v'] as num?)?.toDouble() ?? 0.0;

    // 5. Delivery Income
    final deliveryRes = await db.rawQuery(
        isWorker
            ? "SELECT COALESCE(SUM(delivery_charge), 0) AS v FROM orders WHERE (created_by = ? OR assigned_worker_id = ?) AND delivery_status != 'cancelled' AND delivery_status != 'denied'"
            : "SELECT COALESCE(SUM(delivery_charge), 0) AS v FROM orders WHERE delivery_status != 'cancelled' AND delivery_status != 'denied'",
        isWorker ? [workerId, workerId] : null);
    final totalDeliveryIncome =
        (deliveryRes.first['v'] as num?)?.toDouble() ?? 0.0;

    // Calculations
    final grossProfit = totalRevenue - cogs;
    final netProfit = grossProfit - totalExpenses;
    final profitMarginPct =
        totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;

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
              WHERE created_at >= datetime('now', '-7 days') AND delivery_status != 'cancelled' AND delivery_status != 'denied' AND (created_by = ? OR assigned_worker_id = ?)
              GROUP BY DATE(created_at)
              ORDER BY day ASC
              '''
            : '''
              SELECT DATE(created_at) AS day, COALESCE(SUM(grand_total), 0) AS total
              FROM orders
              WHERE created_at >= datetime('now', '-7 days') AND delivery_status != 'cancelled' AND delivery_status != 'denied'
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
              WHERE created_at >= datetime('now', '-6 months') AND delivery_status != 'cancelled' AND delivery_status != 'denied' AND (created_by = ? OR assigned_worker_id = ?)
              GROUP BY strftime('%Y-%m', created_at)
              ORDER BY month ASC
              '''
            : '''
              SELECT strftime('%Y-%m', created_at) AS month, COALESCE(SUM(grand_total), 0) AS total
              FROM orders
              WHERE created_at >= datetime('now', '-6 months') AND delivery_status != 'cancelled' AND delivery_status != 'denied'
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
              LEFT JOIN orders o ON c.id = o.customer_id AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied' AND (o.created_by = ? OR o.assigned_worker_id = ?)
              WHERE c.is_archived = 0 AND (c.assigned_worker_id = ? OR c.created_by = ? OR c.id IN (SELECT entity_id FROM worker_assignments WHERE worker_id = ? AND entity_type = 'customer'))
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
              LEFT JOIN orders o ON c.id = o.customer_id AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied'
              WHERE c.is_archived = 0
              GROUP BY c.id
              ''',
        isWorker ? [workerId, workerId, workerId, workerId, workerId] : null);
    return List<Map<String, dynamic>>.from(maps);
  }

  Future<Map<String, dynamic>> getTodaysDetailedReport() async {
    final db = await _db;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();

    final workerId = await _getWorkerId();
    final bool isWorker = workerId != null && workerId.isNotEmpty;
    const effectiveDateSql = "(CASE WHEN o.order_type = 'Pre-Order' AND o.order_taking_date IS NOT NULL AND o.order_taking_date != '' THEN DATE(o.order_taking_date) ELSE DATE(o.created_at) END)";
    const effectiveDateSubSql = "(CASE WHEN order_type = 'Pre-Order' AND order_taking_date IS NOT NULL AND order_taking_date != '' THEN DATE(order_taking_date) ELSE DATE(created_at) END)";

    // Today's orders
    final orderMaps = await db.rawQuery(
        isWorker
            ? '''
              SELECT o.*, o.rowid AS order_number, o.order_number AS order_number_str, c.name AS customer_name
              FROM orders o
              LEFT JOIN customers c ON o.customer_id = c.id
              WHERE $effectiveDateSql = DATE(?) AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied' AND (o.created_by = ? OR o.assigned_worker_id = ?)
              ORDER BY o.created_at DESC
              '''
            : '''
              SELECT o.*, o.rowid AS order_number, o.order_number AS order_number_str, c.name AS customer_name
              FROM orders o
              LEFT JOIN customers c ON o.customer_id = c.id
              WHERE $effectiveDateSql = DATE(?) AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied'
              ORDER BY o.created_at DESC
              ''',
        isWorker ? [today, workerId, workerId] : [today]);

    // Today's items sold
    final itemMaps = await db.rawQuery(
        isWorker
            ? '''
              SELECT item_name, item_unit, SUM(quantity) AS qty, SUM(total_price) AS total
              FROM order_items
              WHERE order_id IN (SELECT id FROM orders WHERE $effectiveDateSubSql = DATE(?) AND delivery_status != 'cancelled' AND delivery_status != 'denied' AND (created_by = ? OR assigned_worker_id = ?))
              GROUP BY item_name, item_unit
              ORDER BY qty DESC
              '''
            : '''
              SELECT item_name, item_unit, SUM(quantity) AS qty, SUM(total_price) AS total
              FROM order_items
              WHERE order_id IN (SELECT id FROM orders WHERE $effectiveDateSubSql = DATE(?) AND delivery_status != 'cancelled' AND delivery_status != 'denied')
              GROUP BY item_name, item_unit
              ORDER BY qty DESC
              ''',
        isWorker ? [today, workerId, workerId] : [today]);

    // Today's payment breakdown
    final cashPayments = await db.rawQuery(
        isWorker
            ? '''
              SELECT COALESCE(SUM(p.amount), 0) AS v
              FROM payments p
              JOIN orders o ON p.order_id = o.id
              WHERE $effectiveDateSql = DATE(?) AND p.method = 'cash' AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied' AND (o.created_by = ? OR o.assigned_worker_id = ?)
              '''
            : '''
              SELECT COALESCE(SUM(p.amount), 0) AS v
              FROM payments p
              JOIN orders o ON p.order_id = o.id
              WHERE $effectiveDateSql = DATE(?) AND p.method = 'cash' AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied'
              ''',
        isWorker ? [today, workerId, workerId] : [today]);

    final onlinePayments = await db.rawQuery(
        isWorker
            ? '''
              SELECT COALESCE(SUM(p.amount), 0) AS v
              FROM payments p
              JOIN orders o ON p.order_id = o.id
              WHERE $effectiveDateSql = DATE(?) AND p.method != 'cash' AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied' AND (o.created_by = ? OR o.assigned_worker_id = ?)
              '''
            : '''
              SELECT COALESCE(SUM(p.amount), 0) AS v
              FROM payments p
              JOIN orders o ON p.order_id = o.id
              WHERE $effectiveDateSql = DATE(?) AND p.method != 'cash' AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied'
              ''',
        isWorker ? [today, workerId, workerId] : [today]);

    final totalSales = await db.rawQuery(
        isWorker
            ? '''
              SELECT COALESCE(SUM(grand_total), 0) AS v
              FROM orders
              WHERE $effectiveDateSubSql = DATE(?) AND delivery_status != 'cancelled' AND delivery_status != 'denied' AND (created_by = ? OR assigned_worker_id = ?)
              '''
            : '''
              SELECT COALESCE(SUM(grand_total), 0) AS v
              FROM orders
              WHERE $effectiveDateSubSql = DATE(?) AND delivery_status != 'cancelled' AND delivery_status != 'denied'
              ''',
        isWorker ? [today, workerId, workerId] : [today]);

    final double totalSalesVal =
        (totalSales.first['v'] as num?)?.toDouble() ?? 0.0;
    final double cashReceivedVal =
        (cashPayments.first['v'] as num?)?.toDouble() ?? 0.0;
    final double onlineReceivedVal =
        (onlinePayments.first['v'] as num?)?.toDouble() ?? 0.0;
    final double pendingVal =
        totalSalesVal - (cashReceivedVal + onlineReceivedVal);

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
  /// Fixes 1-to-N join multiplication bug by calculating discounts and item market savings separately.
  Future<Map<String, double>> getCustomerSavings(String customerId) async {
    final db = await _db;
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // 1. Order discounts (all time & monthly)
    final allDiscRes = await db.rawQuery('''
      SELECT COALESCE(SUM(discount), 0) AS v
      FROM orders
      WHERE customer_id = ? AND delivery_status != 'cancelled' AND delivery_status != 'denied'
    ''', [customerId]);

    final monDiscRes = await db.rawQuery('''
      SELECT COALESCE(SUM(discount), 0) AS v
      FROM orders
      WHERE customer_id = ? AND delivery_status != 'cancelled' AND delivery_status != 'denied' AND strftime('%Y-%m', created_at) = ?
    ''', [customerId, month]);

    // 2. Market savings from line items (all time & monthly)
    final allMarketRes = await db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE
          WHEN oi.item_id != '' AND i.market_price > oi.unit_price AND (LOWER(COALESCE(oi.item_unit, '')) = LOWER(COALESCE(i.unit, '')) OR oi.item_unit IS NULL OR oi.item_unit = '')
          THEN (i.market_price - oi.unit_price) * oi.quantity
          WHEN oi.item_id != '' AND i.market_price > 0 AND (LOWER(COALESCE(oi.item_unit, '')) = 'gram' OR LOWER(COALESCE(oi.item_unit, '')) = 'gm') AND LOWER(COALESCE(i.unit, '')) = 'kg'
          THEN MAX(0, (i.market_price * (oi.quantity / 1000.0)) - oi.total_price)
          WHEN oi.item_id != '' AND i.market_price > 0 AND LOWER(COALESCE(oi.item_unit, '')) = 'kg' AND (LOWER(COALESCE(i.unit, '')) = 'gram' OR LOWER(COALESCE(i.unit, '')) = 'gm')
          THEN MAX(0, (i.market_price * (oi.quantity * 1000.0)) - oi.total_price)
          ELSE 0
        END
      ), 0) AS v
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      JOIN items i ON i.id = oi.item_id
      WHERE o.customer_id = ? AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied'
    ''', [customerId]);

    final monMarketRes = await db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE
          WHEN oi.item_id != '' AND i.market_price > oi.unit_price AND (LOWER(COALESCE(oi.item_unit, '')) = LOWER(COALESCE(i.unit, '')) OR oi.item_unit IS NULL OR oi.item_unit = '')
          THEN (i.market_price - oi.unit_price) * oi.quantity
          WHEN oi.item_id != '' AND i.market_price > 0 AND (LOWER(COALESCE(oi.item_unit, '')) = 'gram' OR LOWER(COALESCE(oi.item_unit, '')) = 'gm') AND LOWER(COALESCE(i.unit, '')) = 'kg'
          THEN MAX(0, (i.market_price * (oi.quantity / 1000.0)) - oi.total_price)
          WHEN oi.item_id != '' AND i.market_price > 0 AND LOWER(COALESCE(oi.item_unit, '')) = 'kg' AND (LOWER(COALESCE(i.unit, '')) = 'gram' OR LOWER(COALESCE(i.unit, '')) = 'gm')
          THEN MAX(0, (i.market_price * (oi.quantity * 1000.0)) - oi.total_price)
          ELSE 0
        END
      ), 0) AS v
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      JOIN items i ON i.id = oi.item_id
      WHERE o.customer_id = ? AND o.delivery_status != 'cancelled' AND o.delivery_status != 'denied' AND strftime('%Y-%m', o.created_at) = ?
    ''', [customerId, month]);

    final allDisc = (allDiscRes.first['v'] as num?)?.toDouble() ?? 0.0;
    final monDisc = (monDiscRes.first['v'] as num?)?.toDouble() ?? 0.0;
    final allMarket = (allMarketRes.first['v'] as num?)?.toDouble() ?? 0.0;
    final monMarket = (monMarketRes.first['v'] as num?)?.toDouble() ?? 0.0;

    return {
      'total': allDisc + allMarket,
      'monthly': monDisc + monMarket,
    };
  }
}
