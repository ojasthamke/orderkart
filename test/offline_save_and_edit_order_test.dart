import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/order/data/order_dao.dart';
import 'package:orderkart/features/order/data/order_repository_impl.dart';
import 'package:orderkart/features/order/data/order_questions_dao.dart';
import 'package:orderkart/features/order/domain/order.dart';
import 'package:orderkart/features/order/domain/order_item.dart';
import 'package:orderkart/features/order/domain/payment.dart';
import 'package:orderkart/features/customer/data/customer_dao.dart';
import 'package:orderkart/features/inventory/data/item_dao.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Offline Save & Edit Order Comprehensive Verification Tests', () {
    final orderDao = OrderDao();
    final itemDao = ItemDao();
    final customerDao = CustomerDao();
    final orderRepo = OrderRepositoryImpl(orderDao, customerDao, itemDao);

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'app_mode': 'owner',
      });
      await DatabaseHelper.instance.close();
      final db = await DatabaseHelper.instance.database;

      await db.delete('order_question_answers');
      await db.delete('customer_question_answers');
      await db.delete('order_questions');
      await db.delete('stock_history');
      await db.delete('payments');
      await db.delete('order_items');
      await db.delete('orders');
      await db.delete('items');
      await db.delete('customers');
      await db.delete('locations');
      await db.delete('streets');
      await db.delete('areas');

      final now = DateTime.now();

      // 1. Seed Area, Street & Customer
      await db.insert('areas', {
        'id': 'area-1',
        'name': 'Ganesh Nagar',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('streets', {
        'id': 'street-1',
        'area_id': 'area-1',
        'name': 'Market Street',
        'created_at': now.toIso8601String(),
      });

      await db.insert('locations', {
        'id': 'area-1',
        'name': 'Ganesh Nagar',
        'location_kind': 'area',
        'sequence_key': 'a',
        'depth': 0,
        'materialized_path': '/area-1/',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('locations', {
        'id': 'street-1',
        'parent_location_id': 'area-1',
        'name': 'Market Street',
        'location_kind': 'road',
        'sequence_key': 'b',
        'depth': 1,
        'materialized_path': '/area-1/street-1/',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('customers', {
        'id': 'cust-test',
        'street_id': 'street-1',
        'location_id': 'street-1',
        'name': 'Amit Patil',
        'phone1': '9890012345',
        'outstanding_balance': 0.0,
        'customer_since': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 2. Seed Items with known stock
      await db.insert('items', {
        'id': 'item-apple',
        'name': 'Shimla Apple',
        'category': 'Fruits',
        'unit': 'kg',
        'cost_price': 80.0,
        'selling_price': 120.0,
        'stock': 50.0,
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('items', {
        'id': 'item-banana',
        'name': 'Fresh Banana',
        'category': 'Fruits',
        'unit': 'dozen',
        'cost_price': 30.0,
        'selling_price': 50.0,
        'stock': 30.0,
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 3. Seed Order Question
      await db.insert('order_questions', {
        'id': 'q-pack',
        'question': 'Packing Preference',
        'options': 'Paper Bag,Cardboard Box,Plastic Bag',
        'customer_id': 'cust-test',
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    });

    test('1. SAVE ORDER: Successfully creates order offline with stock deduction & customer balance update', () async {
      final now = DateTime.now();
      final orderId = await OrderDao.generateUniqueOrderNo();
      expect(orderId.startsWith('OW') || orderId.startsWith('WK'), isTrue);

      final items = [
        OrderItem(
          id: 'oi-apple',
          orderId: orderId,
          itemId: 'item-apple',
          itemName: 'Shimla Apple',
          itemUnit: 'kg',
          quantity: 5.0,
          unitPrice: 120.0,
          totalPrice: 600.0,
        ),
        OrderItem(
          id: 'oi-banana',
          orderId: orderId,
          itemId: 'item-banana',
          itemName: 'Fresh Banana',
          itemUnit: 'dozen',
          quantity: 2.0,
          unitPrice: 50.0,
          totalPrice: 100.0,
        ),
      ];

      final order = AppOrder(
        id: orderId,
        customerId: 'cust-test',
        subtotal: 700.0,
        discount: 50.0,
        deliveryCharge: 20.0,
        smartRoundedAmount: 0.0,
        grandTotal: 670.0, // 700 - 50 + 20
        paidAmount: 500.0,
        remainingAmount: 170.0, // 670 - 500
        deliveryStatus: 'pending',
        notes: 'Deliver before 5 PM',
        savings: 50.0,
        createdAt: now,
        updatedAt: now,
      );

      // Save Order offline
      final savedId = await orderRepo.createOrder(order, items);
      expect(savedId, equals(orderId));

      // Save question answer
      await OrderQuestionDao.instance.saveOrderAnswers(orderId, [
        {
          'question_id': 'q-pack',
          'question_text': 'Packing Preference',
          'selected_option': 'Paper Bag',
        }
      ]);

      // Record payment
      await orderRepo.addPayment(Payment(
        id: 'pay-1',
        orderId: orderId,
        customerId: 'cust-test',
        amount: 500.0,
        method: 'cash',
        notes: 'Initial deposit',
        createdAt: now,
      ));

      // ── VERIFY IN SQLITE DATABASE ──
      final db = await DatabaseHelper.instance.database;

      // 1. Orders table verification
      final orderRows = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(orderRows.length, equals(1));
      expect(orderRows.first['subtotal'], equals(700.0));
      expect(orderRows.first['discount'], equals(50.0));
      expect(orderRows.first['delivery_charge'], equals(20.0));
      expect(orderRows.first['grand_total'], equals(670.0));
      expect(orderRows.first['paid_amount'], equals(500.0));
      expect(orderRows.first['remaining_amount'], equals(170.0));
      expect(orderRows.first['delivery_status'], equals('pending'));

      // 2. Order Items verification
      final itemRows = await db.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      expect(itemRows.length, equals(2));

      // 3. Stock deduction verification
      final apple = (await db.query('items', where: 'id = ?', whereArgs: ['item-apple'])).first;
      expect(apple['stock'], equals(45.0)); // Initial 50.0 - 5.0 = 45.0

      final banana = (await db.query('items', where: 'id = ?', whereArgs: ['item-banana'])).first;
      expect(banana['stock'], equals(28.0)); // Initial 30.0 - 2.0 = 28.0

      // 4. Stock history logs verification
      final stockHist = await db.query('stock_history', where: 'order_id = ?', whereArgs: [orderId]);
      expect(stockHist.length, equals(2));

      // 5. Customer outstanding balance verification
      final cust = (await db.query('customers', where: 'id = ?', whereArgs: ['cust-test'])).first;
      expect(cust['outstanding_balance'], equals(170.0));

      // 6. Question answers verification
      final ansRows = await OrderQuestionDao.instance.getOrderAnswers(orderId);
      expect(ansRows.length, equals(1));
      expect(ansRows.first['selected_option'], equals('Paper Bag'));
    });

    test('2. EDIT ORDER: Successfully modifies order items, recalculates totals, restores/adjusts stock, and syncs customer balance offline', () async {
      final now = DateTime.now();
      const orderId = 'OW99999';

      // ── Step A: Create initial order (3 Apple = 360, Grand Total 360, Paid 360, Remaining 0) ──
      final initialItems = [
        OrderItem(
          id: 'oi-apple-1',
          orderId: orderId,
          itemId: 'item-apple',
          itemName: 'Shimla Apple',
          itemUnit: 'kg',
          quantity: 3.0,
          unitPrice: 120.0,
          totalPrice: 360.0,
        ),
      ];

      final initialOrder = AppOrder(
        id: orderId,
        customerId: 'cust-test',
        subtotal: 360.0,
        discount: 0.0,
        deliveryCharge: 0.0,
        smartRoundedAmount: 0.0,
        grandTotal: 360.0,
        paidAmount: 360.0,
        remainingAmount: 0.0,
        deliveryStatus: 'pending',
        notes: 'Original note',
        savings: 0.0,
        createdAt: now,
        updatedAt: now,
      );

      await orderRepo.createOrder(initialOrder, initialItems);
      await orderRepo.addPayment(Payment(
        id: 'pay-init-2',
        orderId: orderId,
        customerId: 'cust-test',
        amount: 360.0,
        method: 'cash',
        notes: 'Initial payment',
        createdAt: now,
      ));

      final db = await DatabaseHelper.instance.database;
      var appleItem = (await db.query('items', where: 'id = ?', whereArgs: ['item-apple'])).first;
      expect(appleItem['stock'], equals(47.0)); // 50 - 3 = 47

      // ── Step B: EDIT ORDER ──
      // User changes: Apple quantity changed from 3kg to 1kg, Added 4 dozen Banana.
      // Subtotal = (1 * 120) + (4 * 50) = 120 + 200 = 320.
      // Discount = 20, Delivery = 10 -> GrandTotal = 320 - 20 + 10 = 310.
      // Paid Amount remained 360 -> Remaining Amount = 310 - 360 = -50 (Advance/Credit).
      final editedItems = [
        OrderItem(
          id: 'oi-apple-edited',
          orderId: orderId,
          itemId: 'item-apple',
          itemName: 'Shimla Apple',
          itemUnit: 'kg',
          quantity: 1.0,
          unitPrice: 120.0,
          totalPrice: 120.0,
        ),
        OrderItem(
          id: 'oi-banana-edited',
          orderId: orderId,
          itemId: 'item-banana',
          itemName: 'Fresh Banana',
          itemUnit: 'dozen',
          quantity: 4.0,
          unitPrice: 50.0,
          totalPrice: 200.0,
        ),
      ];

      final editedOrder = AppOrder(
        id: orderId,
        customerId: 'cust-test',
        subtotal: 320.0,
        discount: 20.0,
        deliveryCharge: 10.0,
        smartRoundedAmount: 0.0,
        grandTotal: 310.0,
        paidAmount: 360.0,
        remainingAmount: -50.0,
        deliveryStatus: 'pending',
        notes: 'Updated note: Added bananas',
        savings: 20.0,
        createdAt: now,
        updatedAt: DateTime.now(),
      );

      // Execute Edit Order
      await orderRepo.createOrder(editedOrder, editedItems);

      // ── VERIFY EDITED ORDER STATE IN SQLITE ──

      // 1. Verify Orders table is updated with new values
      final editedOrderRows = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(editedOrderRows.length, equals(1));
      expect(editedOrderRows.first['subtotal'], equals(320.0));
      expect(editedOrderRows.first['discount'], equals(20.0));
      expect(editedOrderRows.first['delivery_charge'], equals(10.0));
      expect(editedOrderRows.first['grand_total'], equals(310.0));
      expect(editedOrderRows.first['paid_amount'], equals(360.0));
      expect(editedOrderRows.first['remaining_amount'], equals(-50.0));
      expect(editedOrderRows.first['notes'], equals('Updated note: Added bananas'));

      // 2. Verify Order Items in database
      final currentOrderItems = await db.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      expect(currentOrderItems.length, equals(2));
      final appleInDb = currentOrderItems.firstWhere((i) => i['item_id'] == 'item-apple');
      expect(appleInDb['quantity'], equals(1.0));
      expect(appleInDb['total_price'], equals(120.0));

      final bananaInDb = currentOrderItems.firstWhere((i) => i['item_id'] == 'item-banana');
      expect(bananaInDb['quantity'], equals(4.0));
      expect(bananaInDb['total_price'], equals(200.0));

      // 3. Verify Accurate Stock Adjustments
      // Apple: Started at 50, first order took 3 (down to 47), edit restored 3 (back to 50) and deducted 1 -> Stock must be 49.0!
      appleItem = (await db.query('items', where: 'id = ?', whereArgs: ['item-apple'])).first;
      expect(appleItem['stock'], equals(49.0));

      // Banana: Started at 30, edit took 4 -> Stock must be 26.0!
      var bananaItem = (await db.query('items', where: 'id = ?', whereArgs: ['item-banana'])).first;
      expect(bananaItem['stock'], equals(26.0));

      // 4. Verify Stock History Log has 'order_edit_restore' and new 'order' entries
      final restoreHist = await db.query('stock_history',
          where: 'order_id = ? AND reason = ?',
          whereArgs: [orderId, 'order_edit_restore']);
      expect(restoreHist.isNotEmpty, isTrue);
      expect(restoreHist.first['change_amount'], equals(3.0));

      // 5. Verify Customer outstanding balance recalculation
      final updatedCust = (await db.query('customers', where: 'id = ?', whereArgs: ['cust-test'])).first;
      expect(updatedCust['outstanding_balance'], equals(-50.0));
    });
  });
}
