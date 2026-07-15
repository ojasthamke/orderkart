/// CustomerDao — SQLite operations for Customers
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../../../core/database/database_helper.dart';
import '../../../core/security/app_mode_service.dart';
import '../domain/customer.dart';

class CustomerDao {
  final _uuid = const Uuid();
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    return executor ?? await _db;
  }

  Future<void> saveCustomerOrder(String streetId, List<String> orderedIds) async {
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

  Future<List<Customer>> getCustomersByStreet(String streetId, {String? searchQuery}) async {
    final db = await _db;
    String where = '';
    List<dynamic> args = [];
    if (streetId.isNotEmpty) {
      where = 'street_id = ?';
      args.add(streetId);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      if (where.isNotEmpty) where += ' AND ';
      where += '(name LIKE ? OR phone1 LIKE ? OR house_number LIKE ?)';
      final q = '%${searchQuery.trim()}%';
      args.addAll([q, q, q]);
    }


    final maps = await db.query(
      'customers',
      where: where.isEmpty ? null : where,
      whereArgs: args.isEmpty ? null : args,
    );
    final customers = maps.map(Customer.fromMap).toList();

    // Sort: customers with serial_no > 0 appear first in ascending order.
    // Customers with serial_no == 0 (unset) go to the end sorted by creation time.
    customers.sort((a, b) {
      final aNo = a.serialNo;
      final bNo = b.serialNo;
      if (aNo == 0 && bNo == 0) return a.createdAt.compareTo(b.createdAt);
      if (aNo == 0) return 1;   // a goes after b
      if (bNo == 0) return -1;  // a goes before b
      return aNo.compareTo(bNo);
    });
    return customers;
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await _db;
    final maps = await db.query(
      'customers',
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
    return customers;
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
      LEFT JOIN streets s ON c.street_id = s.id
      LEFT JOIN areas a ON s.area_id = a.id
      WHERE c.name LIKE ? OR c.phone1 LIKE ? OR c.phone2 LIKE ?
            OR c.house_number LIKE ? OR c.address LIKE ?
            OR s.name LIKE ? OR a.name LIKE ?
      LIMIT 50
    ''', [q, q, q, q, q, q, q]);
    return maps.map(Customer.fromMap).toList();
  }

  /// Fetch all customers who have an outstanding balance > 0, sorted highest first
  Future<List<Customer>> getCustomersWithDue() async {
    final db = await _db;


    final maps = await db.rawQuery('''
      SELECT * FROM customers
      WHERE outstanding_balance > 0
      ORDER BY outstanding_balance DESC
    ''');
    return maps.map(Customer.fromMap).toList();
  }

  Future<List<Customer>> getCustomersWithOverpayment() async {
    final db = await _db;

    final maps = await db.rawQuery('''
      SELECT * FROM customers
      WHERE outstanding_balance < 0
      ORDER BY outstanding_balance ASC
    ''');
    return maps.map(Customer.fromMap).toList();
  }

  Future<String> insertCustomer(Customer customer) async {
    final db = await _db;
    final id  = customer.id.isEmpty ? _uuid.v4() : customer.id;
    final now = DateTime.now().toIso8601String();

    final mode = await AppModeService.getAppMode();
    String createdBy = customer.createdBy;
    String assignedWorkerId = customer.assignedWorkerId;
    String workerName = customer.workerName;

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
        await db.insert('worker_assignments', {
          'id': const Uuid().v4(),
          'worker_id': activeWorkerId,
          'entity_type': 'customer',
          'entity_id': id,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    final map = customer.toMap();
    await db.insert('customers', {
      ...map,
      'id':         id,
      'location_id': customer.streetId,
      'created_by': createdBy,
      'assigned_worker_id': assignedWorkerId,
      'worker_name': workerName,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await _db;
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
  }

  Future<void> deleteCustomer(String id) async {
    final db = await _db;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateBalance(String customerId, {
    required double outstandingBalance,
    required double totalPaid,
    required double totalPending,
    required int    totalOrders,
    required String lastOrderDate,
  }) async {
    final db = await _db;
    await db.update(
      'customers',
      {
        'outstanding_balance': outstandingBalance,
        'total_paid':          totalPaid,
        'total_pending':       totalPending,
        'total_orders':        totalOrders,
        'last_order_date':     lastOrderDate,
        'updated_at':          DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  /// Recalculates customer totals from orders table
  Future<void> recalcCustomerTotals(String customerId, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final mode = await AppModeService.getAppMode();
    String? workerId;
    if (mode == AppMode.worker) {
      final settingsRes = await db.query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      workerId = settingsRes.isNotEmpty ? settingsRes.first['value']?.toString() : null;
      if (workerId == null || workerId.isEmpty) {
        final workerRows = await db.query('workers', limit: 1);
        if (workerRows.isNotEmpty) {
          workerId = workerRows.first['id'] as String;
        }
      }
    }

    final query = (workerId != null && workerId.isNotEmpty)
        ? '''
          SELECT
            COUNT(*)            AS total_orders,
            COALESCE(SUM(grand_total),     0) AS total_amount,
            COALESCE(SUM(paid_amount),     0) AS total_paid,
            COALESCE(SUM(remaining_amount),0) AS total_pending,
            MAX(created_at)     AS last_order
          FROM orders
          WHERE customer_id = ? AND delivery_status != 'cancelled'
            AND (created_by = ? OR assigned_worker_id = ?)
          '''
        : '''
          SELECT
            COUNT(*)            AS total_orders,
            COALESCE(SUM(grand_total),     0) AS total_amount,
            COALESCE(SUM(paid_amount),     0) AS total_paid,
            COALESCE(SUM(remaining_amount),0) AS total_pending,
            MAX(created_at)     AS last_order
          FROM orders
          WHERE customer_id = ? AND delivery_status != 'cancelled'
          ''';

    final queryArgs = (workerId != null && workerId.isNotEmpty)
        ? [customerId, workerId, workerId]
        : [customerId];

    final result = await db.rawQuery(query, queryArgs);

    if (result.isNotEmpty) {
      final row = result.first;
      await db.update(
        'customers',
        {
          'total_orders':        row['total_orders'] ?? 0,
          'total_paid':          row['total_paid']   ?? 0.0,
          'total_pending':       row['total_pending']?? 0.0,
          'outstanding_balance': row['total_pending']?? 0.0,
          'last_order_date':     row['last_order']   ?? '',
          'updated_at':          DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [customerId],
      );
    }
  }
}
