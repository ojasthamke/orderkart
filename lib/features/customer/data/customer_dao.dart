/// CustomerDao — SQLite operations for Customers

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../domain/customer.dart';

class CustomerDao {
  final _uuid = const Uuid();
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Customer>> getCustomersByStreet(String streetId, {String? searchQuery}) async {
    final db = await _db;
    String where = 'street_id = ?';
    List<dynamic> args = [streetId];
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      where += ' AND (name LIKE ? OR phone1 LIKE ? OR house_number LIKE ?)';
      final q = '%${searchQuery.trim()}%';
      args.addAll([q, q, q]);
    }
    final maps = await db.query(
      'customers',
      where: where,
      whereArgs: args,
      orderBy: 'name ASC',
    );
    return maps.map(Customer.fromMap).toList();
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
      WHERE c.name LIKE ? OR c.phone1 LIKE ? OR c.phone2 LIKE ?
            OR c.house_number LIKE ? OR c.address LIKE ?
      LIMIT 50
    ''', [q, q, q, q, q]);
    return maps.map(Customer.fromMap).toList();
  }

  Future<String> insertCustomer(Customer customer) async {
    final db = await _db;
    final id  = customer.id.isEmpty ? _uuid.v4() : customer.id;
    final now = DateTime.now().toIso8601String();
    await db.insert('customers', {
      ...customer.toMap(),
      'id':         id,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await _db;
    await db.update(
      'customers',
      {...customer.toMap(), 'updated_at': DateTime.now().toIso8601String()},
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
  Future<void> recalcCustomerTotals(String customerId) async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT
        COUNT(*)            AS total_orders,
        COALESCE(SUM(grand_total),     0) AS total_amount,
        COALESCE(SUM(paid_amount),     0) AS total_paid,
        COALESCE(SUM(remaining_amount),0) AS total_pending,
        MAX(created_at)     AS last_order
      FROM orders
      WHERE customer_id = ? AND delivery_status != 'cancelled'
    ''', [customerId]);

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
