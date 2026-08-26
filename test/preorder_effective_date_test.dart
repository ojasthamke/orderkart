import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/order/data/order_dao.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Pre-Order Effective Date and Section Isolation Tests', () {
    setUp(() async {
      await DatabaseHelper.instance.close();
      final dbPath = await databaseFactory.getDatabasesPath();
      final path = '$dbPath/orderkart.db';
      await databaseFactory.deleteDatabase(path);

      final db = await DatabaseHelper.instance.database;

      // Seed area & customer
      await db.insert('areas', {
        'id': 'area-1',
        'name': 'Area 1',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await db.insert('streets', {
        'id': 'street-1',
        'area_id': 'area-1',
        'name': 'Street 1',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('customers', {
        'id': 'cust-1',
        'street_id': 'street-1',
        'name': 'Test Customer',
        'phone1': '9999999999',
        'customer_since': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final now = DateTime.now();
      final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final futureDate = now.add(const Duration(days: 5));
      final futureDateStr = "${futureDate.year.toString().padLeft(4, '0')}-${futureDate.month.toString().padLeft(2, '0')}-${futureDate.day.toString().padLeft(2, '0')}";

      // 1. Normal order placed today
      await db.insert('orders', {
        'id': 'ord-normal-today',
        'customer_id': 'cust-1',
        'subtotal': 100.0,
        'grand_total': 100.0,
        'paid_amount': 0.0,
        'remaining_amount': 100.0,
        'delivery_status': 'pending',
        'order_type': 'Normal',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 2. Pre-order placed today, but scheduled for future order_taking_date (5 days later)
      await db.insert('orders', {
        'id': 'ord-preorder-future',
        'customer_id': 'cust-1',
        'subtotal': 150.0,
        'grand_total': 150.0,
        'paid_amount': 0.0,
        'remaining_amount': 150.0,
        'delivery_status': 'pending',
        'order_type': 'Pre-Order',
        'order_taking_date': futureDateStr,
        'delivery_date': "${futureDate.year}-09-10",
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 3. Pre-order scheduled for TODAY's order_taking_date
      await db.insert('orders', {
        'id': 'ord-preorder-today',
        'customer_id': 'cust-1',
        'subtotal': 200.0,
        'grand_total': 200.0,
        'paid_amount': 0.0,
        'remaining_amount': 200.0,
        'delivery_status': 'pending',
        'order_type': 'Pre-Order',
        'order_taking_date': todayStr,
        'delivery_date': todayStr,
        'created_at': now.subtract(const Duration(days: 3)).toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    });

    test('getAllOrders with filter=today excludes future pre-orders and includes today scheduled pre-orders', () async {
      final orderDao = OrderDao();
      final todayOrders = await orderDao.getAllOrders(filter: 'today');

      final ids = todayOrders.map((o) => o.id).toList();
      expect(ids.contains('ord-normal-today'), isTrue, reason: 'Normal order placed today should appear in today filter');
      expect(ids.contains('ord-preorder-today'), isTrue, reason: 'Pre-order with order_taking_date=today should appear in today filter');
      expect(ids.contains('ord-preorder-future'), isFalse, reason: 'Pre-order scheduled for future should NOT appear in today filter');
    });

    test('getAllOrders without date filter returns all orders for tab segregation', () async {
      final orderDao = OrderDao();
      final allOrders = await orderDao.getAllOrders();

      expect(allOrders.length, equals(3));
      final futurePreorders = allOrders.where((o) => o.orderType == 'Pre-Order' && o.id == 'ord-preorder-future').toList();
      expect(futurePreorders.length, equals(1));
    });
  });
}
