/// CustomerDao — SQLite operations for Customers
library;

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../../../core/database/database_helper.dart';
import '../../../core/security/app_mode_service.dart';
import '../../../core/services/customer_order_sync_service.dart';
import '../domain/customer.dart';

class CustomerDao {
  final _uuid = const Uuid();
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    return executor ?? await _db;
  }

  Future<void> saveCustomerOrder(
      String streetId, List<String> orderedIds) async {
    final db = await _db;
    final val = jsonEncode(orderedIds);
    await db.insert(
      'settings',
      {'key': 'street_customers_order:$streetId', 'value': val},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.transaction((txn) async {
      for (int i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'customers',
          {'serial_no': i + 1},
          where: 'id = ?',
          whereArgs: [orderedIds[i]],
        );
      }
    });
  }

  List<Customer> _deduplicateCustomers(List<Customer> list) {
    final seenIds = <String>{};
    final seenCodes = <String>{};
    final seenPhones = <String>{};
    final result = <Customer>[];

    for (final c in list) {
      if (seenIds.contains(c.id)) continue;
      final code = c.customerCode.trim().toUpperCase();
      if (code.isNotEmpty && seenCodes.contains(code)) continue;

      final digits = c.phone1.replaceAll(RegExp(r'\D'), '');
      final normPhone = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
      if (normPhone.isNotEmpty && normPhone != '0000000000' && seenPhones.contains(normPhone)) {
        continue;
      }

      seenIds.add(c.id);
      if (code.isNotEmpty) seenCodes.add(code);
      if (normPhone.isNotEmpty && normPhone != '0000000000') seenPhones.add(normPhone);
      result.add(c);
    }
    return result;
  }

  Future<List<Customer>> getCustomersByStreet(String streetId,
      {String? searchQuery}) async {
    final db = await _db;
    String where = '(is_archived IS NULL OR is_archived = 0) AND id NOT IN (SELECT id FROM deleted_customers)';
    List<dynamic> args = [];
    if (streetId.isNotEmpty) {
      where += ' AND (street_id = ? OR location_id = ?)';
      args.addAll([streetId, streetId]);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      where += ' AND (name LIKE ? OR phone1 LIKE ? OR house_number LIKE ?)';
      final q = '%${searchQuery.trim()}%';
      args.addAll([q, q, q]);
    }

    final maps = await db.query(
      'customers',
      where: where,
      whereArgs: args,
    );
    final customers = maps.map(Customer.fromMap).toList();

    // Sort: customers with serial_no > 0 appear first in ascending order.
    // Customers with serial_no == 0 (unset) go to the end sorted by creation time.
    customers.sort((a, b) {
      final aNo = a.serialNo;
      final bNo = b.serialNo;
      if (aNo == 0 && bNo == 0) return a.createdAt.compareTo(b.createdAt);
      if (aNo == 0) return 1; // a goes after b
      if (bNo == 0) return -1; // a goes before b
      return aNo.compareTo(bNo);
    });
    return _deduplicateCustomers(customers);
  }

  Future<List<Customer>> getCustomersByArea(String areaId,
      {String? searchQuery}) async {
    final db = await _db;
    List<dynamic> args = [
      areaId,
      areaId,
      areaId,
      areaId,
      '%/$areaId/%',
      '/$areaId/%'
    ];
    String searchFilter = '';
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      searchFilter =
          ' AND (c.name LIKE ? OR c.phone1 LIKE ? OR c.house_number LIKE ?)';
      final q = '%${searchQuery.trim()}%';
      args.addAll([q, q, q]);
    }

    final maps = await db.rawQuery('''
      SELECT DISTINCT c.* FROM customers c
      LEFT JOIN locations st ON (c.location_id = st.id OR c.street_id = st.id)
      WHERE (c.is_archived IS NULL OR c.is_archived = 0)
        AND c.id NOT IN (SELECT id FROM deleted_customers)
        AND (c.street_id = ? OR c.location_id = ? OR st.id = ? OR st.parent_location_id = ? OR st.materialized_path LIKE ? OR st.materialized_path LIKE ?)
        $searchFilter
    ''', args);

    final customers = maps.map(Customer.fromMap).toList();
    customers.sort((a, b) {
      final aNo = a.serialNo;
      final bNo = b.serialNo;
      if (aNo == 0 && bNo == 0) return a.createdAt.compareTo(b.createdAt);
      if (aNo == 0) return 1;
      if (bNo == 0) return -1;
      return aNo.compareTo(bNo);
    });
    return _deduplicateCustomers(customers);
  }

  Future<List<Customer>> getCustomersInSameHouse(String houseNumber,
      {String? streetId, String? excludeCustomerId}) async {
    if (houseNumber.trim().isEmpty) return [];
    final db = await _db;
    String where =
        '(is_archived IS NULL OR is_archived = 0) AND id NOT IN (SELECT id FROM deleted_customers) AND LOWER(TRIM(house_number)) = LOWER(TRIM(?))';
    List<dynamic> args = [houseNumber];
    if (streetId != null && streetId.isNotEmpty) {
      where += ' AND (street_id = ? OR location_id = ?)';
      args.addAll([streetId, streetId]);
    }
    if (excludeCustomerId != null && excludeCustomerId.isNotEmpty) {
      where += ' AND id != ?';
      args.add(excludeCustomerId);
    }
    final maps = await db.query('customers', where: where, whereArgs: args);
    return _deduplicateCustomers(maps.map(Customer.fromMap).toList());
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await _db;
    final maps = await db.query(
      'customers',
      where: '(is_archived IS NULL OR is_archived = 0) AND id NOT IN (SELECT id FROM deleted_customers)',
      orderBy: 'serial_no ASC',
    );
    final customers = maps.map(Customer.fromMap).toList();
    customers.sort((a, b) {
      final aNo = a.serialNo;
      final bNo = b.serialNo;
      if (aNo == 0 && bNo == 0) return a.createdAt.compareTo(b.createdAt);
      if (aNo == 0) return 1;
      if (bNo == 0) return -1;
      return aNo.compareTo(bNo);
    });
    return _deduplicateCustomers(customers);
  }

  Future<Customer?> getCustomerById(String id) async {
    final db = await _db;
    final maps = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final db = await _db;
    final q = '%${query.trim()}%';

    final maps = await db.rawQuery('''
      SELECT c.* FROM customers c
      LEFT JOIN locations street ON (c.location_id = street.id OR c.street_id = street.id)
      LEFT JOIN locations area ON street.parent_location_id = area.id
      WHERE (c.is_archived IS NULL OR c.is_archived = 0)
        AND (c.name LIKE ? OR c.phone1 LIKE ? OR c.phone2 LIKE ?
             OR c.house_number LIKE ? OR c.address LIKE ?
             OR c.customer_code LIKE ?
             OR street.name LIKE ? OR area.name LIKE ?)
      LIMIT 50
    ''', [q, q, q, q, q, q, q, q]);
    return maps.map(Customer.fromMap).toList();
  }

  /// Fetch all customers who have an outstanding balance > 0, sorted highest first
  Future<List<Customer>> getCustomersWithDue() async {
    final db = await _db;

    final maps = await db.rawQuery('''
      SELECT * FROM customers
      WHERE outstanding_balance > 0 AND (is_archived IS NULL OR is_archived = 0)
      ORDER BY outstanding_balance DESC
    ''');
    return maps.map(Customer.fromMap).toList();
  }

  Future<List<Customer>> getCustomersWithOverpayment() async {
    final db = await _db;

    final maps = await db.rawQuery('''
      SELECT * FROM customers
      WHERE outstanding_balance < 0 AND (is_archived IS NULL OR is_archived = 0)
      ORDER BY outstanding_balance ASC
    ''');
    return maps.map(Customer.fromMap).toList();
  }

  Future<String> insertCustomer(Customer customer) async {
    final db = await _db;
    final id = customer.id.isEmpty ? _uuid.v4() : customer.id;

    // Remove from deleted_customers if re-creating
    try {
      await db.delete('deleted_customers', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}

    // Prevent duplicate customer insertion by customer_code or normalized phone
    final trimmedCode = customer.customerCode.trim().toUpperCase();
    final digits = customer.phone1.replaceAll(RegExp(r'\D'), '');
    final normPhone =
        digits.length >= 10 ? digits.substring(digits.length - 10) : digits;

    String? existingId;
    if (trimmedCode.isNotEmpty) {
      final rows = await db.query(
        'customers',
        columns: ['id'],
        where:
            "UPPER(TRIM(customer_code)) = ? AND (is_archived IS NULL OR is_archived = 0)",
        whereArgs: [trimmedCode],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        existingId = rows.first['id'] as String;
      }
    }
    if (existingId == null &&
        normPhone.isNotEmpty &&
        normPhone != '0000000000') {
      final rows = await db.rawQuery('''
        SELECT id FROM customers
        WHERE (is_archived IS NULL OR is_archived = 0)
          AND REPLACE(REPLACE(REPLACE(phone1, ' ', ''), '-', ''), '+91', '') LIKE ?
        LIMIT 1
      ''', ['%$normPhone']);
      if (rows.isNotEmpty) {
        existingId = rows.first['id'] as String;
      }
    }

    if (existingId != null && existingId != id) {
      await updateCustomer(customer.copyWith(id: existingId));
      return existingId;
    }

    final now = DateTime.now().toIso8601String();

    final mode = await AppModeService.getAppMode();
    String createdBy = customer.createdBy;
    String assignedWorkerId = customer.assignedWorkerId;
    String workerName = customer.workerName;

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
        await db.insert(
            'worker_assignments',
            {
              'id': const Uuid().v4(),
              'worker_id': activeWorkerId,
              'entity_type': 'customer',
              'entity_id': id,
              'created_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    final map = customer.toMap();
    if (customer.streetId.isNotEmpty) {
      await DatabaseHelper.instance
          .ensureLegacyStreetAndAreaExists(db, customer.streetId);
    }
    await db.insert(
        'customers',
        {
          ...map,
          'id': id,
          'location_id': customer.streetId,
          'created_by': createdBy,
          'assigned_worker_id': assignedWorkerId,
          'worker_name': workerName,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);

    if (customer.serialNo > 0) {
      await _adjustSequences(db, customer.streetId, id, customer.serialNo);
    }

    // Reset sync status so the sync service will push the new customer to Supabase
    try {
      await db.delete(
        'settings',
        where: "key = ? OR key = ?",
        whereArgs: [
          'customer_sync_status:$id',
          'customer_sync_time:$id',
        ],
      );
    } catch (_) {}

    return id;
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await _db;
    if (customer.streetId.isNotEmpty) {
      await DatabaseHelper.instance
          .ensureLegacyStreetAndAreaExists(db, customer.streetId);
    }
    await db.update(
      'customers',
      {
        ...customer.toMap(),
        'location_id': customer.streetId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [customer.id],
    );

    if (customer.serialNo > 0) {
      await _adjustSequences(
          db, customer.streetId, customer.id, customer.serialNo);
    }

    // Reset sync status so the sync service will push the updated customer to Supabase
    try {
      await db.delete(
        'settings',
        where: "key = ? OR key = ?",
        whereArgs: [
          'customer_sync_status:${customer.id}',
          'customer_sync_time:${customer.id}',
        ],
      );
    } catch (_) {}
  }

  Future<void> _adjustSequences(
      Database db, String streetId, String customerId, int newSerialNo) async {
    if (newSerialNo <= 0) return;

    // Get all active customers on this street
    final maps = await db.query(
      'customers',
      where: 'street_id = ? AND (is_archived IS NULL OR is_archived = 0)',
      whereArgs: [streetId],
    );

    List<Map<String, dynamic>> list = List.from(maps);
    // Sort by serial_no first, then by createdAt to keep standard ordering
    list.sort((a, b) {
      final aNo = a['serial_no'] as int? ?? 0;
      final bNo = b['serial_no'] as int? ?? 0;
      if (aNo == 0 && bNo == 0) {
        final aTime = a['created_at']?.toString() ?? '';
        final bTime = b['created_at']?.toString() ?? '';
        return aTime.compareTo(bTime);
      }
      if (aNo == 0) return 1;
      if (bNo == 0) return -1;
      return aNo.compareTo(bNo);
    });

    // Find the item matching customerId
    int currentIndex = list.indexWhere((c) => c['id'] == customerId);
    Map<String, dynamic>? item;
    if (currentIndex != -1) {
      item = list.removeAt(currentIndex);
    }

    // Insert at desired 0-based index
    int insertIndex = newSerialNo - 1;
    if (insertIndex < 0) insertIndex = 0;
    if (insertIndex > list.length) insertIndex = list.length;

    if (item != null) {
      list.insert(insertIndex, item);
    }

    // Save updated serial_no to the database in a transaction
    await db.transaction((txn) async {
      for (int i = 0; i < list.length; i++) {
        final id = list[i]['id'] as String;
        await txn.update(
          'customers',
          {'serial_no': i + 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<void> deleteCustomer(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      // 1. Delete customer's order items, payments, answers, and stock history linked to orders
      final orders = await txn.query('orders',
          columns: ['id'], where: 'customer_id = ?', whereArgs: [id]);
      for (final order in orders) {
        final orderId = order['id'] as String;
        await txn
            .delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
        await txn
            .delete('payments', where: 'order_id = ?', whereArgs: [orderId]);
        await txn.delete('order_question_answers',
            where: 'order_id = ?', whereArgs: [orderId]);
        await txn.delete('stock_history',
            where: 'order_id = ?', whereArgs: [orderId]);
      }

      // 2. Delete customer's orders
      await txn.delete('orders', where: 'customer_id = ?', whereArgs: [id]);

      // 3. Record in deleted_customers so future sync passes never resurrect them
      await txn.insert('deleted_customers', {
        'id': id,
        'deleted_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // 4. Delete the customer record completely
      await txn.delete('customers', where: 'id = ?', whereArgs: [id]);
    });

    // 5. Remotely delete from Supabase via SECURITY DEFINER RPC
    unawaited(CustomerOrderSyncService.instance.deleteCustomerRemotely(id));
  }

  Future<void> updateBalance(
    String customerId, {
    required double outstandingBalance,
    required double totalPaid,
    required double totalPending,
    required int totalOrders,
    required String lastOrderDate,
  }) async {
    final db = await _db;
    await db.update(
      'customers',
      {
        'outstanding_balance': outstandingBalance,
        'total_paid': totalPaid,
        'total_pending': totalPending,
        'total_orders': totalOrders,
        'last_order_date': lastOrderDate,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  /// Recalculates customer totals from orders and payments tables
  Future<void> recalcCustomerTotals(String customerId,
      {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);

    final ordersResult = await db.rawQuery('''
      SELECT
        COUNT(*)                       AS total_orders,
        COALESCE(SUM(grand_total), 0)  AS total_amount,
        COALESCE(MAX(created_at), '')  AS last_order
      FROM orders
      WHERE customer_id = ? AND (delivery_status IS NULL OR (delivery_status != 'cancelled' AND delivery_status != 'denied'))
    ''', [customerId]);

    final paymentsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(p.amount), 0) AS total_paid
      FROM payments p
      LEFT JOIN orders o ON p.order_id = o.id
      WHERE (p.customer_id = ? OR o.customer_id = ?)
        AND (o.delivery_status IS NULL OR (o.delivery_status != 'cancelled' AND o.delivery_status != 'denied'))
    ''', [customerId, customerId]);


    if (ordersResult.isNotEmpty) {
      final orderRow = ordersResult.first;
      final double totalAmount =
          (orderRow['total_amount'] as num?)?.toDouble() ?? 0.0;
      final int totalOrders = (orderRow['total_orders'] as num?)?.toInt() ?? 0;
      final String lastOrder = orderRow['last_order']?.toString() ?? '';

      final double totalPaid = (paymentsResult.isNotEmpty
              ? (paymentsResult.first['total_paid'] as num?)?.toDouble()
              : 0.0) ??
          0.0;
      final double outstanding =
          double.parse((totalAmount - totalPaid).toStringAsFixed(2));

      await db.update(
        'customers',
        {
          'total_orders': totalOrders,
          'total_paid': totalPaid,
          'total_pending': outstanding > 0 ? outstanding : 0.0,
          'outstanding_balance': outstanding,
          'last_order_date': lastOrder,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [customerId],
      );
    }
  }

  Future<void> moveCustomers(
      List<String> customerIds, String newStreetId) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final id in customerIds) {
        await txn.update(
          'customers',
          {
            'street_id': newStreetId,
            'location_id': newStreetId,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<void> updateCustomWelcomeMessage(
      String customerId, String message) async {
    final db = await _db;
    await db.update(
      'customers',
      {
        'custom_welcome_message': message,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  /// Fetch all Guest customers (users without customer code or is_guest = 1)
  Future<List<Customer>> getGuestCustomers({String? searchQuery}) async {
    final db = await _db;
    String where = '(is_archived IS NULL OR is_archived = 0) AND (is_guest = 1 OR customer_code IS NULL OR customer_code = "")';
    List<dynamic> args = [];
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      where += ' AND (name LIKE ? OR phone1 LIKE ? OR address LIKE ?)';
      final q = '%${searchQuery.trim()}%';
      args.addAll([q, q, q]);
    }

    final maps = await db.query(
      'customers',
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
    return maps.map(Customer.fromMap).toList();
  }

  /// Fetch Registered customers (users with customer code and is_guest = 0)
  Future<List<Customer>> getRegisteredCustomers(String streetId, {String? searchQuery}) async {
    final db = await _db;
    String where = '(is_archived IS NULL OR is_archived = 0) AND (is_guest = 0 OR is_guest IS NULL) AND (customer_code IS NOT NULL AND customer_code != "")';
    List<dynamic> args = [];
    if (streetId.isNotEmpty) {
      where += ' AND (street_id = ? OR location_id = ?)';
      args.addAll([streetId, streetId]);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      where += ' AND (name LIKE ? OR phone1 LIKE ? OR house_number LIKE ? OR customer_code LIKE ?)';
      final q = '%${searchQuery.trim()}%';
      args.addAll([q, q, q, q]);
    }

    final maps = await db.query(
      'customers',
      where: where,
      whereArgs: args,
    );
    final customers = maps.map(Customer.fromMap).toList();
    customers.sort((a, b) {
      final aNo = a.serialNo;
      final bNo = b.serialNo;
      if (aNo == 0 && bNo == 0) return a.createdAt.compareTo(b.createdAt);
      if (aNo == 0) return 1;
      if (bNo == 0) return -1;
      return aNo.compareTo(bNo);
    });
    return customers;
  }

  /// Convert a Guest to a Registered Customer by assigning a customer code
  Future<void> convertToRegisteredCustomer(String customerId, String newCustomerCode, {String? streetId}) async {
    final db = await _db;
    final cleanCode = newCustomerCode.trim().toUpperCase();
    final now = DateTime.now().toIso8601String();

    final updates = <String, dynamic>{
      'is_guest': 0,
      'customer_code': cleanCode,
      'updated_at': now,
    };
    if (streetId != null && streetId.isNotEmpty) {
      updates['street_id'] = streetId;
      updates['location_id'] = streetId;
    }

    await db.update(
      'customers',
      updates,
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  /// Fetch Login audit logs with optional filter
  Future<List<Map<String, dynamic>>> getLoginLogs({int limit = 100, String? loginMethodFilter}) async {
    final db = await _db;
    String? where;
    List<dynamic>? whereArgs;

    if (loginMethodFilter != null && loginMethodFilter.isNotEmpty && loginMethodFilter != 'All') {
      where = 'login_method LIKE ?';
      whereArgs = ['%$loginMethodFilter%'];
    }

    return await db.query(
      'customer_login_logs',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'logged_in_at DESC',
      limit: limit,
    );
  }
}

