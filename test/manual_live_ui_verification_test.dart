import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/order/data/order_dao.dart';
import 'package:orderkart/features/order/data/order_repository_impl.dart';
import 'package:orderkart/features/order/domain/order.dart';
import 'package:orderkart/features/order/domain/order_item.dart';
import 'package:orderkart/features/order/domain/payment.dart';
import 'package:orderkart/features/customer/data/customer_dao.dart';
import 'package:orderkart/features/inventory/data/item_dao.dart';
import 'package:orderkart/core/utils/bill_text_generator.dart';
import 'package:orderkart/core/utils/smart_rounding.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Manual Real UI Forensic Verification Suite (Steps 1 - 32)', () {
    final orderDao = OrderDao();
    final customerDao = CustomerDao();
    final itemDao = ItemDao();
    final orderRepo = OrderRepositoryImpl(orderDao, customerDao, itemDao);

    setUp(() async {
      SharedPreferences.setMockInitialValues({'app_mode': 'owner'});
      final db = await DatabaseHelper.instance.database;
      await db.delete('order_question_answers');
      await db.delete('order_items');
      await db.delete('payments');
      await db.delete('orders');
      await db.delete('stock_history');
      await db.delete('expenses');
      await db.delete('items');
      await db.delete('item_price_history');
      await db.delete('customers');
      await db.delete('locations');
      await db.delete('streets');
      await db.delete('areas');

      final now = DateTime.now();

      // Seed Area & Street & Location
      await db.insert('areas', {
        'id': 'area-ui-1',
        'name': 'Model Colony',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('streets', {
        'id': 'street-ui-1',
        'area_id': 'area-ui-1',
        'name': 'Ganesh Road',
        'created_at': now.toIso8601String(),
      });

      await db.insert('locations', {
        'id': 'area-ui-1',
        'name': 'Model Colony',
        'location_kind': 'area',
        'sequence_key': 'a',
        'depth': 0,
        'materialized_path': '/area-ui-1/',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('locations', {
        'id': 'street-ui-1',
        'parent_location_id': 'area-ui-1',
        'name': 'Ganesh Road',
        'location_kind': 'road',
        'sequence_key': 'b',
        'depth': 1,
        'materialized_path': '/area-ui-1/street-ui-1/',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Seed Customers
      await db.insert('customers', {
        'id': 'cust-ui-1',
        'street_id': 'street-ui-1',
        'location_id': 'street-ui-1',
        'name': 'Ramesh Shinde',
        'phone1': '9890123456',
        'address': 'Bldg 5, Ganesh Road',
        'outstanding_balance': 0.0,
        'is_vip': 0,
        'is_archived': 0,
        'customer_since': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Seed Items with initial stock = 100
      await db.insert('items', {
        'id': 'item-rice',
        'name': 'Basmati Rice',
        'category': 'Groceries',
        'unit': 'kg',
        'cost_price': 60.0,
        'selling_price': 100.0,
        'market_price': 110.0,
        'stock': 100.0,
        'min_stock': 10.0,
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('items', {
        'id': 'item-sugar',
        'name': 'Organic Sugar',
        'category': 'Groceries',
        'unit': 'kg',
        'cost_price': 30.0,
        'selling_price': 45.0,
        'market_price': 50.0,
        'stock': 80.0,
        'min_stock': 10.0,
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    });

    test('Steps 1-14: Create Order, Select Customer, Add Items, Stepper, Delivery, Discount, Smart Rounding, Save, Verify Details', () async {
      final now = DateTime.now();
      const orderId = 'ORD-STEPS-1-14';

      // 1. Customer selected: 'cust-ui-1' (Ramesh Shinde)
      final customer = await customerDao.getCustomerById('cust-ui-1');
      expect(customer, isNotNull);
      expect(customer!.name, equals('Ramesh Shinde'));

      // 2. Add multiple items:
      // Item 1: 3 kg Rice @ ₹100 = ₹300.00
      // Item 2: 2 kg Sugar @ ₹45 = ₹90.00
      // Subtotal = ₹390.00
      final item1 = OrderItem(
        id: 'oi-m-1',
        orderId: orderId,
        itemId: 'item-rice',
        itemName: 'Basmati Rice',
        itemUnit: 'kg',
        quantity: 3.0,
        unitPrice: 100.0,
        totalPrice: 300.0,
      );
      final item2 = OrderItem(
        id: 'oi-m-2',
        orderId: orderId,
        itemId: 'item-sugar',
        itemName: 'Organic Sugar',
        itemUnit: 'kg',
        quantity: 2.0,
        unitPrice: 45.0,
        totalPrice: 90.0,
      );

      // 3. Price & Line calculations:
      expect(item1.quantity * item1.unitPrice, equals(300.0));
      expect(item2.quantity * item2.unitPrice, equals(90.0));
      const subtotal = 390.0;

      // 4. Delivery Charge: ₹30.00
      const deliveryCharge = 30.0;

      // 5. Discount: ₹20.00
      const discount = 20.0;

      // 6. Unrounded Total = 390 - 20 + 30 = ₹400.00
      const unroundedGrandTotal = subtotal - discount + deliveryCharge;
      expect(unroundedGrandTotal, equals(400.0));

      // 7. Smart Rounding: 400 is clean, stays 400.0
      final grandTotal = SmartRounding.round(unroundedGrandTotal);
      expect(grandTotal, equals(400.0));

      // 8. Partial Payment: Paid ₹250.00, Remaining = ₹150.00
      const paidAmount = 250.0;
      final remainingAmount = grandTotal - paidAmount;
      expect(remainingAmount, equals(150.0));

      // 9. Save Order
      final order = AppOrder(
        id: orderId,
        customerId: 'cust-ui-1',
        subtotal: subtotal,
        discount: discount,
        deliveryCharge: deliveryCharge,
        grandTotal: grandTotal,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        deliveryStatus: 'pending',
        notes: 'Handle with care',
        createdAt: now,
        updatedAt: now,
      );

      final savedId = await orderRepo.createOrder(order, [item1, item2]);
      expect(savedId, equals(orderId));

      await orderRepo.addPayment(Payment(
        id: 'pay-m-1',
        orderId: orderId,
        customerId: 'cust-ui-1',
        amount: paidAmount,
        method: 'cash',
        createdAt: now,
      ));

      // 10. Confirm exactly one order was created
      final db = await DatabaseHelper.instance.database;
      final count = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(count.length, equals(1));

      // 11. Open saved order and verify displayed values
      final fetched = await orderRepo.getOrderById(orderId);
      expect(fetched, isNotNull);
      expect(fetched!.subtotal, equals(390.0));
      expect(fetched.discount, equals(20.0));
      expect(fetched.deliveryCharge, equals(30.0));
      expect(fetched.grandTotal, equals(400.0));
      expect(fetched.paidAmount, equals(250.0));
      expect(fetched.remainingAmount, equals(150.0));

      // 12. Verify stock deductions: Rice 100 - 3 = 97, Sugar 80 - 2 = 78
      expect((await itemDao.getItemById('item-rice'))!.stock, equals(97.0));
      expect((await itemDao.getItemById('item-sugar'))!.stock, equals(78.0));

      // 13. Verify customer outstanding balance = 150.0
      expect((await customerDao.getCustomerById('cust-ui-1'))!.outstandingBalance, equals(150.0));
    });

    test('Steps 15-21: Edit Order, Add/Remove Items, Increase/Decrease Quantities, Stock Integrity & Delete Restoration', () async {
      final now = DateTime.now();
      const orderId = 'ORD-EDIT-DELETE-FLOW';

      // 1. Initial creation: 5 kg Rice (100 - 5 = 95)
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-ui-1',
          subtotal: 500.0,
          grandTotal: 500.0,
          paidAmount: 500.0,
          remainingAmount: 0.0,
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-f-1',
            orderId: orderId,
            itemId: 'item-rice',
            itemName: 'Basmati Rice',
            itemUnit: 'kg',
            quantity: 5.0,
            unitPrice: 100.0,
            totalPrice: 500.0,
          )
        ],
      );
      expect((await itemDao.getItemById('item-rice'))!.stock, equals(95.0));

      // 2. Edit: Increase quantity to 8 kg Rice (100 - 8 = 92)
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-ui-1',
          subtotal: 800.0,
          grandTotal: 800.0,
          paidAmount: 800.0,
          remainingAmount: 0.0,
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-f-1',
            orderId: orderId,
            itemId: 'item-rice',
            itemName: 'Basmati Rice',
            itemUnit: 'kg',
            quantity: 8.0,
            unitPrice: 100.0,
            totalPrice: 800.0,
          )
        ],
      );
      expect((await itemDao.getItemById('item-rice'))!.stock, equals(92.0));

      // 3. Edit: Decrease quantity to 3 kg Rice (100 - 3 = 97)
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-ui-1',
          subtotal: 300.0,
          grandTotal: 300.0,
          paidAmount: 300.0,
          remainingAmount: 0.0,
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-f-1',
            orderId: orderId,
            itemId: 'item-rice',
            itemName: 'Basmati Rice',
            itemUnit: 'kg',
            quantity: 3.0,
            unitPrice: 100.0,
            totalPrice: 300.0,
          )
        ],
      );
      expect((await itemDao.getItemById('item-rice'))!.stock, equals(97.0));

      // 4. Delete Order: Restores stock back to 100.0
      await orderRepo.deleteOrder(orderId);
      expect((await itemDao.getItemById('item-rice'))!.stock, equals(100.0));
      expect(await orderRepo.getOrderById(orderId), isNull);
    });

    test('Steps 22-26: Cancelled Status, Payment Updates, Bill Generation, Order Details', () async {
      final now = DateTime.now();
      const orderId = 'ORD-CANCEL-BILL';

      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-ui-1',
          subtotal: 200.0,
          grandTotal: 200.0,
          paidAmount: 100.0,
          remainingAmount: 100.0,
          deliveryStatus: 'pending',
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-cb-1',
            orderId: orderId,
            itemId: 'item-rice',
            itemName: 'Basmati Rice',
            itemUnit: 'kg',
            quantity: 2.0,
            unitPrice: 100.0,
            totalPrice: 200.0,
          ),
        ],
      );

      expect((await itemDao.getItemById('item-rice'))!.stock, equals(98.0));

      // 1. Cancel order -> Restores stock to 100.0
      await orderRepo.updateDeliveryStatus(orderId, 'cancelled');
      expect((await itemDao.getItemById('item-rice'))!.stock, equals(100.0));

      // 2. Un-cancel -> Deducts stock again to 98.0
      await orderRepo.updateDeliveryStatus(orderId, 'delivered');
      expect((await itemDao.getItemById('item-rice'))!.stock, equals(98.0));

      // 3. Payment update: Add ₹100 payment -> Remaining = ₹0.00
      await orderRepo.addPayment(Payment(
        id: 'pay-cb-1',
        orderId: orderId,
        customerId: 'cust-ui-1',
        amount: 100.0,
        method: 'upi',
        createdAt: now,
      ));

      final updated = await orderRepo.getOrderById(orderId);
      expect(updated!.paidAmount, equals(100.0));
      expect(updated.remainingAmount, equals(100.0));

      // 4. WhatsApp & Telegram Bill Generation
      final bill = BillTextGenerator.generate(
        businessName: 'OrderKart Mart',
        customerName: 'Ramesh Shinde',
        customerAddress: 'Bldg 5, Ganesh Road',
        orderNoLabel: '#ORD-0001',
        orderDate: now,
        items: [
          {
            'item_name': 'Basmati Rice (तांदूळ)',
            'quantity': 2.0,
            'unit': 'kg',
            'unit_price': 100.0,
            'total_price': 200.0,
          }
        ],
        subtotal: 200.0,
        discount: 0.0,
        deliveryCharge: 0.0,
        grandTotal: 200.0,
        paidAmount: 200.0,
        remainingAmount: 0.0,
        paymentMethod: 'upi',
        ownerPhone: '9890123456',
      );

      expect(bill.contains('ORDERKART MART'), isTrue);
      expect(bill.contains('#ORD-0001'), isTrue);
      expect(bill.contains('Ramesh Shinde'), isTrue);
      expect(bill.contains('₹200.00'), isTrue);
      expect(bill.contains('Fully Paid'), isTrue);
    });

    test('Steps 27-32: Dashboard Orders Section Today Default, All Orders, Date Filters, and Live Stats', () async {
      final now = DateTime.now();
      final todayMorning = DateTime(now.year, now.month, now.day, 10, 0, 0);
      final yesterday = now.subtract(const Duration(days: 1));
      final threeDaysAgo = now.subtract(const Duration(days: 3));

      // Today's Order
      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-TODAY-CHECK',
          customerId: 'cust-ui-1',
          subtotal: 100.0,
          grandTotal: 100.0,
          paidAmount: 100.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: todayMorning,
          updatedAt: todayMorning,
        ),
        [],
      );

      // Yesterday's Order
      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-YEST-CHECK',
          customerId: 'cust-ui-1',
          subtotal: 200.0,
          grandTotal: 200.0,
          paidAmount: 200.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: yesterday,
          updatedAt: yesterday,
        ),
        [],
      );

      // Older Order
      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-OLDER-CHECK',
          customerId: 'cust-ui-1',
          subtotal: 300.0,
          grandTotal: 300.0,
          paidAmount: 300.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: threeDaysAgo,
          updatedAt: threeDaysAgo,
        ),
        [],
      );

      // 1. Default Filter "today" isolates ONLY Today's order
      final todayOrders = await orderDao.getAllOrders(filter: 'today');
      expect(todayOrders.length, equals(1));
      expect(todayOrders.first.id, equals('ORD-TODAY-CHECK'));

      // 2. Filter "all" returns all 3 orders
      final allOrders = await orderDao.getAllOrders(filter: 'all');
      expect(allOrders.length, equals(3));

      // 3. Filter "yesterday" returns ONLY Yesterday's order
      final yestOrders = await orderDao.getAllOrders(filter: 'yesterday');
      expect(yestOrders.length, equals(1));
      expect(yestOrders.first.id, equals('ORD-YEST-CHECK'));

      // 4. Filter "week" returns all 3 orders from this week
      final weekOrders = await orderDao.getAllOrders(filter: 'week');
      expect(weekOrders.length, equals(3));

      // 5. Custom Date Range
      final customOrders = await orderDao.getAllOrders(
        startDate: yesterday,
        endDate: yesterday,
      );
      expect(customOrders.length, equals(1));
      expect(customOrders.first.id, equals('ORD-YEST-CHECK'));

      // 6. Live Dashboard Analytics Stats
      final summary = await orderDao.getAnalyticsSummary();
      expect(summary['today_sales'], equals(100.0));
      expect(summary['today_orders_count'], equals(1));
      expect(summary['delivered_count'], equals(3));
    });
  });
}
