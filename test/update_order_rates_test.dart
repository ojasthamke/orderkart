import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/core/utils/smart_rounding.dart';
import 'package:orderkart/features/order/data/order_dao.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Calculate Item Rate Tests', () {
    test('Weight to Weight conversion (kg -> grams / gms)', () {
      // 1 kg of Potato = Rs 40
      // 1 gram should be Rs 0.04
      final rateGrams = OrderDao.calculateItemRate(
        basePrice: 40.0,
        dbUnit: 'kg',
        orderUnit: 'grams',
      );
      expect(rateGrams, closeTo(0.04, 0.0001));

      final rateGms = OrderDao.calculateItemRate(
        basePrice: 40.0,
        dbUnit: 'kg',
        orderUnit: 'gms',
      );
      expect(rateGms, closeTo(0.04, 0.0001));

      final rateG = OrderDao.calculateItemRate(
        basePrice: 40.0,
        dbUnit: 'kg',
        orderUnit: 'g',
      );
      expect(rateG, closeTo(0.04, 0.0001));
    });

    test('Count to Count conversion (dozen <-> piece)', () {
      // 1 dozen Bananas = Rs 60 -> 1 piece should be Rs 5.0
      final ratePiece = OrderDao.calculateItemRate(
        basePrice: 60.0,
        dbUnit: 'dozen',
        orderUnit: 'piece',
      );
      expect(ratePiece, equals(5.0));

      final ratePcs = OrderDao.calculateItemRate(
        basePrice: 60.0,
        dbUnit: 'dz',
        orderUnit: 'pcs',
      );
      expect(ratePcs, equals(5.0));

      // 1 piece Egg = Rs 6 -> 1 dozen should be Rs 72.0
      final rateDozen = OrderDao.calculateItemRate(
        basePrice: 6.0,
        dbUnit: 'piece',
        orderUnit: 'dozen',
      );
      expect(rateDozen, equals(72.0));
    });

    test('Cross Weight to Count conversion with weightPerPiece in grams', () {
      // Cauliflower sold at Rs 40/kg, weight_per_piece = 250 (grams) -> 0.25 kg
      // Rate per piece should be 40 * 0.25 = Rs 10.0
      final ratePiece = OrderDao.calculateItemRate(
        basePrice: 40.0,
        dbUnit: 'kg',
        orderUnit: 'piece',
        weightPerPiece: 250.0,
      );
      expect(ratePiece, equals(10.0));
    });
  });

  group('Update Order Rates Tests', () {
    setUp(() async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('order_items');
      await db.delete('orders');
      await db.delete('customer_item_prices');
      await db.delete('items');
      await db.delete('customers');
      await db.delete('streets');
      await db.delete('areas');

      // Seed area and street for FK constraint
      await db.insert('areas', {
        'id': 'area-1',
        'name': 'Area 1',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('streets', {
        'id': 'street-1',
        'area_id': 'area-1',
        'name': 'Street 1',
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Seed customer
      await db.insert('customers', {
        'id': 'cust-1',
        'street_id': 'street-1',
        'name': 'John Doe',
        'phone1': '9876543210',
        'customer_since': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Seed item 1 (originally Rs 50, now updated to Rs 80)
      await db.insert('items', {
        'id': 'item-1',
        'name': 'Tomato',
        'category': 'Vegetables',
        'selling_price': 80.0,
        'unit': 'kg',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Seed item 2: Potato sold by kg at Rs 40
      await db.insert('items', {
        'id': 'item-potato',
        'name': 'Potato',
        'category': 'Vegetables',
        'selling_price': 40.0,
        'unit': 'kg',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Seed item 3: Banana sold by dozen at Rs 60
      await db.insert('items', {
        'id': 'item-banana',
        'name': 'Banana',
        'category': 'Fruits',
        'selling_price': 60.0,
        'unit': 'dozen',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

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

      final db = await DatabaseHelper.instance.database;
      final rawOrder = await db.query('orders', columns: ['sync_status'], where: 'id = ?', whereArgs: ['ord-101']);
      expect(rawOrder.first['sync_status'], equals('pending_update'));

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

    test('updateOrderRates converts grams accurately without 1000x inflation', () async {
      final db = await DatabaseHelper.instance.database;
      // Customer ordered 500 grams of Potato (Potato is Rs 40/kg)
      await db.insert('orders', {
        'id': 'ord-grams',
        'customer_id': 'cust-1',
        'subtotal': 15.0,
        'discount': 0.0,
        'delivery_charge': 0.0,
        'grand_total': 15.0,
        'paid_amount': 0.0,
        'remaining_amount': 15.0,
        'delivery_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert('order_items', {
        'id': 'oi-grams',
        'order_id': 'ord-grams',
        'item_id': 'item-potato',
        'item_name': 'Potato',
        'item_unit': 'grams',
        'quantity': 500.0,
        'unit_price': 0.03,
        'total_price': 15.0,
      });

      final orderDao = OrderDao();
      final res = await orderDao.updateOrderRates('ord-grams');

      expect(res['success'], isTrue);
      // 500 grams * 0.04 = Rs 20.0 (NOT Rs 20,000!)
      expect(res['newSubtotal'], equals(20.0));
      expect(res['newGrandTotal'], equals(20.0));

      final items = await orderDao.getOrderItems('ord-grams');
      expect(items.first.unitPrice, equals(0.04));
      expect(items.first.totalPrice, equals(20.0));
    });

    test('updateOrderRates converts dozen to pieces accurately without 12x inflation', () async {
      final db = await DatabaseHelper.instance.database;
      // Customer ordered 6 pieces of Banana (Banana is Rs 60/dozen)
      await db.insert('orders', {
        'id': 'ord-banana',
        'customer_id': 'cust-1',
        'subtotal': 25.0,
        'discount': 0.0,
        'delivery_charge': 0.0,
        'grand_total': 25.0,
        'paid_amount': 0.0,
        'remaining_amount': 25.0,
        'delivery_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert('order_items', {
        'id': 'oi-banana',
        'order_id': 'ord-banana',
        'item_id': 'item-banana',
        'item_name': 'Banana',
        'item_unit': 'piece',
        'quantity': 6.0,
        'unit_price': 4.16,
        'total_price': 25.0,
      });

      final orderDao = OrderDao();
      final res = await orderDao.updateOrderRates('ord-banana');

      expect(res['success'], isTrue);
      // 6 pieces * Rs 5 = Rs 30.0 (NOT Rs 360!)
      expect(res['newSubtotal'], equals(30.0));
      expect(res['newGrandTotal'], equals(30.0));

      final items = await orderDao.getOrderItems('ord-banana');
      expect(items.first.unitPrice, equals(5.0));
      expect(items.first.totalPrice, equals(30.0));
    });

    test('updateOrderRates resolves item by name fallback when remote product UUID does not match local item id', () async {
      final db = await DatabaseHelper.instance.database;
      await db.insert('orders', {
        'id': 'ord-fallback',
        'customer_id': 'cust-1',
        'subtotal': 30.0,
        'discount': 0.0,
        'delivery_charge': 0.0,
        'grand_total': 30.0,
        'paid_amount': 0.0,
        'remaining_amount': 30.0,
        'delivery_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // item_id is a remote UUID that doesn't match 'item-potato', but name is 'Potato'
      await db.insert('order_items', {
        'id': 'oi-remote-uuid',
        'order_id': 'ord-fallback',
        'item_id': '99999999-9999-9999-9999-999999999999',
        'item_name': 'Potato',
        'item_unit': 'kg',
        'quantity': 2.0,
        'unit_price': 15.0,
        'total_price': 30.0,
      });

      final orderDao = OrderDao();
      final res = await orderDao.updateOrderRates('ord-fallback');

      expect(res['success'], isTrue);
      // Fallback matched 'Potato' with selling_price 40.0 -> 2.0 * 40 = 80.0
      expect(res['newSubtotal'], equals(80.0));
      expect(res['newGrandTotal'], equals(80.0));
    });

    test('Repeated tapping idempotency: calling updateOrderRates 5 times produces identical subtotal and deduplicates items', () async {
      final orderDao = OrderDao();
      final db = await DatabaseHelper.instance.database;

      // Simulate a duplicated line item created by previous race condition
      await db.insert('order_items', {
        'id': 'oi-duplicate',
        'order_id': 'ord-101',
        'item_id': 'item-1',
        'item_name': 'Tomato',
        'item_unit': 'kg',
        'quantity': 2.0,
        'unit_price': 50.0,
        'total_price': 100.0,
      });

      // Now call updateOrderRates repeatedly 5 times
      Map<String, dynamic> firstRes = {};
      for (int i = 0; i < 5; i++) {
        final res = await orderDao.updateOrderRates('ord-101');
        expect(res['success'], isTrue);
        if (i == 0) {
          firstRes = res;
          // Duplicate row dropped without duplicating customer's quantity: 2.0 kg * 80.0 = Rs 160.0
          expect(res['newSubtotal'], equals(160.0));
          expect(res['newGrandTotal'], equals(170.0)); // 160 - 10 + 20
        } else {
          // On all subsequent repeated calls, total remains EXACTLY the same (idempotent)
          expect(res['newSubtotal'], equals(firstRes['newSubtotal']));
          expect(res['newGrandTotal'], equals(firstRes['newGrandTotal']));
        }
      }

      final items = await orderDao.getOrderItems('ord-101');
      // Duplicate row was removed/consolidated, only 1 unique row remains
      expect(items.length, equals(1));
      expect(items.first.quantity, equals(2.0));
      expect(items.first.unitPrice, equals(80.0));
      expect(items.first.totalPrice, equals(160.0));
    });

    test('SmartRounding does not inflate 50.00000000000001 to 55.0', () {
      expect(SmartRounding.round(50.00000000000001), equals(50.0));
      expect(SmartRounding.round(20.000000000000004), equals(20.0));
      expect(SmartRounding.round(15.0), equals(15.0));
      expect(SmartRounding.round(15.01), equals(20.0));
      expect(SmartRounding.round(17.45), equals(20.0));
    });

    test('updateOrderRates updates available items that originally had 0 price', () async {
      final db = await DatabaseHelper.instance.database;
      await db.insert('orders', {
        'id': 'ord-zero-price',
        'customer_id': 'cust-1',
        'subtotal': 0.0,
        'discount': 0.0,
        'delivery_charge': 0.0,
        'grand_total': 0.0,
        'paid_amount': 0.0,
        'remaining_amount': 0.0,
        'delivery_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Item was added with 0 price (e.g. pending rate from admin)
      await db.insert('order_items', {
        'id': 'oi-zero',
        'order_id': 'ord-zero-price',
        'item_id': 'item-1',
        'item_name': 'Tomato',
        'item_unit': 'kg',
        'quantity': 3.0,
        'unit_price': 0.0,
        'total_price': 0.0,
        'is_available': 1,
      });

      final orderDao = OrderDao();
      final res = await orderDao.updateOrderRates('ord-zero-price');

      expect(res['success'], isTrue);
      // Rate should update to Rs 80 * 3 = Rs 240.0, NOT remain 0.0
      expect(res['newSubtotal'], equals(240.0));
      expect(res['newGrandTotal'], equals(240.0));

      final items = await orderDao.getOrderItems('ord-zero-price');
      expect(items.first.isAvailable, isTrue);
      expect(items.first.unitPrice, equals(80.0));
      expect(items.first.totalPrice, equals(240.0));
    });

    test('calculateItemRate handles retail packaging units (bunch, packet, bundle)', () {
      // Coriander sold at Rs 15/bunch, ordered as piece
      final ratePiece = OrderDao.calculateItemRate(
        basePrice: 15.0,
        dbUnit: 'bunch',
        orderUnit: 'piece',
      );
      expect(ratePiece, equals(15.0));

      // Fenugreek sold at Rs 20/bundle, ordered as bunch
      final rateBunch = OrderDao.calculateItemRate(
        basePrice: 20.0,
        dbUnit: 'bundle',
        orderUnit: 'bunch',
      );
      expect(rateBunch, equals(20.0));
    });
  });
}
