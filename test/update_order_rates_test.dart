import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/order/data/order_dao.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Update Order Rates Tests', () {
    setUp(() async {
      await DatabaseHelper.instance.close();
      final dbPath = await databaseFactory.getDatabasesPath();
      final path = '$dbPath/orderkart.db';
      await databaseFactory.deleteDatabase(path);

      final db = await DatabaseHelper.instance.database;

      // Seed area and street for FK constraint
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

      // Seed customer
      await db.insert('customers', {
        'id': 'cust-1',
        'street_id': 'street-1',
        'name': 'John Doe',
        'phone1': '9876543210',
        'customer_since': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Seed item 1 (originally Rs 50, now updated to Rs 80)
      await db.insert('items', {
        'id': 'item-1',
        'name': 'Tomato',
        'category': 'Vegetables',
        'selling_price': 80.0,
        'unit': 'kg',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Seed order with old rate (unit_price = 50.0, qty = 2, total = 100.0)
      await db.insert('orders', {
        'id': 'ord-101',
        'customer_id': 'cust-1',
        'subtotal': 100.0,
        'discount': 10.0,
        'delivery_charge': 20.0,
        'grand_total': 110.0,
        'paid_amount': 0.0,
        'remaining_amount': 110.0,
        'delivery_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert('order_items', {
        'id': 'oi-1',
        'order_id': 'ord-101',
        'item_id': 'item-1',
        'item_name': 'Tomato',
        'item_unit': 'kg',
        'quantity': 2.0,
        'unit_price': 50.0,
        'total_price': 100.0,
      });
    });

    test(
        'updateOrderRates updates line item rates and recalculates order subtotal & grandTotal',
        () async {
      final orderDao = OrderDao();
      final res = await orderDao.updateOrderRates('ord-101');

      expect(res['success'], isTrue);
      expect(res['updatedCount'], equals(1));
      expect(res['oldSubtotal'], equals(100.0));
      expect(res['newSubtotal'], equals(160.0)); // 2.0 kg * 80.0
      expect(res['newGrandTotal'], equals(170.0)); // 160 - 10 + 20

      final updatedOrder = await orderDao.getOrderById('ord-101');
      expect(updatedOrder, isNotNull);
      expect(updatedOrder!.subtotal, equals(160.0));
      expect(updatedOrder.grandTotal, equals(170.0));

      final updatedItems = await orderDao.getOrderItems('ord-101');
      expect(updatedItems.length, equals(1));
      expect(updatedItems.first.unitPrice, equals(80.0));
      expect(updatedItems.first.totalPrice, equals(160.0));
    });

    test('updateOrderRates respects customer custom price if set', () async {
      // Set custom price for John Doe on Tomato to Rs 75.0
      await DatabaseHelper.instance
          .setCustomerCustomPrice('cust-1', 'item-1', 75.0);

      final orderDao = OrderDao();
      final res = await orderDao.updateOrderRates('ord-101');

      expect(res['success'], isTrue);
      expect(res['newSubtotal'], equals(150.0)); // 2.0 * 75.0
      expect(res['newGrandTotal'], equals(160.0)); // 150 - 10 + 20

      final updatedItems = await orderDao.getOrderItems('ord-101');
      expect(updatedItems.first.unitPrice, equals(75.0));
    });
  });
}
