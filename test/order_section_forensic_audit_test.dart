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

  group('OrderKart Complete Order Section Forensic Audit Test Suite', () {
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
        'id': 'area-ord-1',
        'name': 'Shivaji Nagar',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('streets', {
        'id': 'street-ord-1',
        'area_id': 'area-ord-1',
        'name': 'Station Road',
        'created_at': now.toIso8601String(),
      });

      await db.insert('locations', {
        'id': 'area-ord-1',
        'name': 'Shivaji Nagar',
        'location_kind': 'area',
        'sequence_key': 'a',
        'depth': 0,
        'materialized_path': '/area-ord-1/',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('locations', {
        'id': 'street-ord-1',
        'parent_location_id': 'area-ord-1',
        'name': 'Station Road',
        'location_kind': 'road',
        'sequence_key': 'b',
        'depth': 1,
        'materialized_path': '/area-ord-1/street-ord-1/',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Seed Customers
      await db.insert('customers', {
        'id': 'cust-vip-1',
        'street_id': 'street-ord-1',
        'location_id': 'street-ord-1',
        'name': 'Aarav Deshmukh',
        'phone1': '9822011223',
        'address': 'Plot 42, Station Road',
        'outstanding_balance': 0.0,
        'is_vip': 1,
        'vip_discount_pct': 10.0,
        'vip_free_delivery': 1,
        'is_archived': 0,
        'customer_since': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('customers', {
        'id': 'cust-regular-1',
        'street_id': 'street-ord-1',
        'location_id': 'street-ord-1',
        'name': 'Sunita Kulkarni',
        'phone1': '9822044556',
        'address': 'Flat 302, Sai Tower',
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
        'id': 'item-oil',
        'name': 'Sunflower Oil',
        'category': 'Groceries',
        'unit': 'l',
        'cost_price': 120.0,
        'selling_price': 160.0,
        'market_price': 175.0,
        'stock': 50.0,
        'min_stock': 5.0,
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('items', {
        'id': 'item-eggs',
        'name': 'Farm Fresh Eggs',
        'category': 'Dairy & Eggs',
        'unit': 'dozen',
        'cost_price': 60.0,
        'selling_price': 84.0,
        'market_price': 90.0,
        'stock': 25.0,
        'min_stock': 5.0,
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    });

    test('1. Create Order: Complete lifecycle with line items, delivery, discount, and balance updates', () async {
      final now = DateTime.now();
      const orderId = 'ORD-CREATE-1';

      // 2 kg Rice @ 100 = 200, 1 L Oil @ 160 = 160 -> Subtotal = 360
      // Discount = 20, Delivery Charge = 30 -> Grand Total = 370
      // Paid Amount = 200 (Cash) -> Remaining = 170
      final order = AppOrder(
        id: orderId,
        customerId: 'cust-regular-1',
        subtotal: 360.0,
        discount: 20.0,
        deliveryCharge: 30.0,
        grandTotal: 370.0,
        paidAmount: 200.0,
        remainingAmount: 170.0,
        deliveryStatus: 'pending',
        notes: 'Deliver before 5 PM',
        savings: 45.0,
        createdAt: now,
        updatedAt: now,
      );

      final items = [
        OrderItem(
          id: 'oi-1',
          orderId: orderId,
          itemId: 'item-rice',
          itemName: 'Basmati Rice',
          itemUnit: 'kg',
          quantity: 2.0,
          unitPrice: 100.0,
          totalPrice: 200.0,
        ),
        OrderItem(
          id: 'oi-2',
          orderId: orderId,
          itemId: 'item-oil',
          itemName: 'Sunflower Oil',
          itemUnit: 'l',
          quantity: 1.0,
          unitPrice: 160.0,
          totalPrice: 160.0,
        ),
      ];

      final createdId = await orderRepo.createOrder(order, items);
      expect(createdId, equals(orderId));

      // Record payment
      await orderRepo.addPayment(Payment(
        id: 'pay-create-1',
        orderId: orderId,
        customerId: 'cust-regular-1',
        amount: 200.0,
        method: 'cash',
        createdAt: now,
      ));

      // 1. Verify Database Order record
      final fetchedOrder = await orderRepo.getOrderById(orderId);
      expect(fetchedOrder, isNotNull);
      expect(fetchedOrder!.customerId, equals('cust-regular-1'));
      expect(fetchedOrder.subtotal, equals(360.0));
      expect(fetchedOrder.discount, equals(20.0));
      expect(fetchedOrder.deliveryCharge, equals(30.0));
      expect(fetchedOrder.grandTotal, equals(370.0));
      expect(fetchedOrder.paidAmount, equals(200.0));
      expect(fetchedOrder.remainingAmount, equals(170.0));
      expect(fetchedOrder.deliveryStatus, equals('pending'));

      // 2. Verify Order Items
      final fetchedItems = await orderRepo.getOrderItems(orderId);
      expect(fetchedItems.length, equals(2));
      expect(fetchedItems[0].totalPrice, equals(200.0));
      expect(fetchedItems[1].totalPrice, equals(160.0));

      // 3. Verify Stock Deductions (Rice 100 - 2 = 98, Oil 50 - 1 = 49)
      final riceStock = (await itemDao.getItemById('item-rice'))!.stock;
      final oilStock = (await itemDao.getItemById('item-oil'))!.stock;
      expect(riceStock, equals(98.0));
      expect(oilStock, equals(49.0));

      // 4. Verify Customer Outstanding Balance = 170.0
      final customer = await customerDao.getCustomerById('cust-regular-1');
      expect(customer!.outstandingBalance, equals(170.0));
    });

    test('2. Quantity Logic & Mathematical Precision: Stepping 1 -> 2 -> 5 -> 10 -> 1', () async {
      final now = DateTime.now();
      const orderId = 'ORD-QTY-STEP';

      // Start with qty = 1 (100 - 1 = 99)
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-regular-1',
          subtotal: 100.0,
          grandTotal: 100.0,
          paidAmount: 100.0,
          remainingAmount: 0.0,
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-qty-1',
            orderId: orderId,
            itemId: 'item-rice',
            itemName: 'Basmati Rice',
            itemUnit: 'kg',
            quantity: 1.0,
            unitPrice: 100.0,
            totalPrice: 100.0,
          )
        ],
      );
      expect((await itemDao.getItemById('item-rice'))!.stock, equals(99.0));

      // Step to qty = 2 (100 - 2 = 98)
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-regular-1',
          subtotal: 200.0,
          grandTotal: 200.0,
          paidAmount: 200.0,
          remainingAmount: 0.0,
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-qty-1',
            orderId: orderId,
            itemId: 'item-rice',
            itemName: 'Basmati Rice',
            itemUnit: 'kg',
            quantity: 2.0,
            unitPrice: 100.0,
            totalPrice: 200.0,
          )
        ],
      );
      expect((await itemDao.getItemById('item-rice'))!.stock, equals(98.0));

      // Step to qty = 5 (100 - 5 = 95)
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-regular-1',
          subtotal: 500.0,
          grandTotal: 500.0,
          paidAmount: 500.0,
          remainingAmount: 0.0,
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-qty-1',
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

      // Step to qty = 10 (100 - 10 = 90)
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-regular-1',
          subtotal: 1000.0,
          grandTotal: 1000.0,
          paidAmount: 1000.0,
          remainingAmount: 0.0,
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-qty-1',
            orderId: orderId,
            itemId: 'item-rice',
            itemName: 'Basmati Rice',
            itemUnit: 'kg',
            quantity: 10.0,
            unitPrice: 100.0,
            totalPrice: 1000.0,
          )
        ],
      );
      expect((await itemDao.getItemById('item-rice'))!.stock, equals(90.0));

      // Step back to qty = 1 (100 - 1 = 99)
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-regular-1',
          subtotal: 100.0,
          grandTotal: 100.0,
          paidAmount: 100.0,
          remainingAmount: 0.0,
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-qty-1',
            orderId: orderId,
            itemId: 'item-rice',
            itemName: 'Basmati Rice',
            itemUnit: 'kg',
            quantity: 1.0,
            unitPrice: 100.0,
            totalPrice: 100.0,
          )
        ],
      );
      expect((await itemDao.getItemById('item-rice'))!.stock, equals(99.0));
    });

    test('3. Fractional Unit Conversions: Ordering in gm / ml / pieces against kg / l / dozen inventory', () async {
      final now = DateTime.now();
      const orderId = 'ORD-UNIT-CONV';

      // 500 gm Rice (Inventory in kg) -> Deducts 0.5 kg
      // 250 ml Oil (Inventory in l) -> Deducts 0.25 l
      // 6 pcs Eggs (Inventory in dozen) -> Deducts 0.5 dozen
      final items = [
        OrderItem(
          id: 'oi-u-1',
          orderId: orderId,
          itemId: 'item-rice',
          itemName: 'Basmati Rice',
          itemUnit: 'gm',
          quantity: 500.0,
          unitPrice: 0.10, // 100 per kg = 0.10 per gm
          totalPrice: 50.0,
        ),
        OrderItem(
          id: 'oi-u-2',
          orderId: orderId,
          itemId: 'item-oil',
          itemName: 'Sunflower Oil',
          itemUnit: 'ml',
          quantity: 250.0,
          unitPrice: 0.16, // 160 per L = 0.16 per ml
          totalPrice: 40.0,
        ),
        OrderItem(
          id: 'oi-u-3',
          orderId: orderId,
          itemId: 'item-eggs',
          itemName: 'Farm Fresh Eggs',
          itemUnit: 'pcs',
          quantity: 6.0,
          unitPrice: 7.0, // 84 per dozen = 7.0 per pc
          totalPrice: 42.0,
        ),
      ];

      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-regular-1',
          subtotal: 132.0,
          grandTotal: 132.0,
          paidAmount: 132.0,
          remainingAmount: 0.0,
          createdAt: now,
          updatedAt: now,
        ),
        items,
      );

      final riceStock = (await itemDao.getItemById('item-rice'))!.stock;
      final oilStock = (await itemDao.getItemById('item-oil'))!.stock;
      final eggsStock = (await itemDao.getItemById('item-eggs'))!.stock;

      expect(riceStock, equals(99.5)); // 100 - 0.5 = 99.5 kg
      expect(oilStock, equals(49.75)); // 50 - 0.25 = 49.75 l
      expect(eggsStock, equals(24.5)); // 25 - 0.5 = 24.5 dozen
    });

    test('4. Duplicate Save Protection: Rapid duplicate save invocation produces exactly 1 order row', () async {
      final now = DateTime.now();
      const orderId = 'ORD-IDEMPOTENT';

      final order = AppOrder(
        id: orderId,
        customerId: 'cust-regular-1',
        subtotal: 200.0,
        grandTotal: 200.0,
        paidAmount: 0.0,
        remainingAmount: 200.0,
        createdAt: now,
        updatedAt: now,
      );

      final items = [
        OrderItem(
          id: 'oi-idemp-1',
          orderId: orderId,
          itemId: 'item-rice',
          itemName: 'Basmati Rice',
          itemUnit: 'kg',
          quantity: 2.0,
          unitPrice: 100.0,
          totalPrice: 200.0,
        ),
      ];

      // Save 5 times concurrently / sequentially
      await Future.wait([
        orderRepo.createOrder(order, items),
        orderRepo.createOrder(order, items),
        orderRepo.createOrder(order, items),
      ]);

      final db = await DatabaseHelper.instance.database;
      final orders = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(orders.length, equals(1)); // Exactly ONE order row

      final orderItems = await db.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      expect(orderItems.length, equals(1)); // Exactly ONE item row

      final riceStock = (await itemDao.getItemById('item-rice'))!.stock;
      expect(riceStock, equals(98.0)); // Exactly 2 kg deducted, not 6 kg!
    });

    test('5. Edit Order: Modifying line items, changing quantities, and replacing items cleanly adjusts stock', () async {
      final now = DateTime.now();
      const orderId = 'ORD-EDIT-FLOW';

      // 1. Initial Order: 4 kg Rice (100 - 4 = 96)
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-regular-1',
          subtotal: 400.0,
          grandTotal: 400.0,
          paidAmount: 400.0,
          remainingAmount: 0.0,
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-edit-1',
            orderId: orderId,
            itemId: 'item-rice',
            itemName: 'Basmati Rice',
            itemUnit: 'kg',
            quantity: 4.0,
            unitPrice: 100.0,
            totalPrice: 400.0,
          ),
        ],
      );

      expect((await itemDao.getItemById('item-rice'))!.stock, equals(96.0));

      // 2. Edit Order: Replace 4 kg Rice with 1 kg Rice + 2 L Oil (Rice: 96 + 4 - 1 = 99; Oil: 50 - 2 = 48)
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-regular-1',
          subtotal: 420.0,
          grandTotal: 420.0,
          paidAmount: 420.0,
          remainingAmount: 0.0,
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-edit-1',
            orderId: orderId,
            itemId: 'item-rice',
            itemName: 'Basmati Rice',
            itemUnit: 'kg',
            quantity: 1.0,
            unitPrice: 100.0,
            totalPrice: 100.0,
          ),
          OrderItem(
            id: 'oi-edit-2',
            orderId: orderId,
            itemId: 'item-oil',
            itemName: 'Sunflower Oil',
            itemUnit: 'l',
            quantity: 2.0,
            unitPrice: 160.0,
            totalPrice: 320.0,
          ),
        ],
      );

      expect((await itemDao.getItemById('item-rice'))!.stock, equals(99.0));
      expect((await itemDao.getItemById('item-oil'))!.stock, equals(48.0));
    });

    test('6. Delete Order: Restores stock and recalculates customer balance', () async {
      final now = DateTime.now();
      const orderId = 'ORD-DELETE-TEST';

      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-regular-1',
          subtotal: 300.0,
          grandTotal: 300.0,
          paidAmount: 100.0,
          remainingAmount: 200.0,
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-del-1',
            orderId: orderId,
            itemId: 'item-rice',
            itemName: 'Basmati Rice',
            itemUnit: 'kg',
            quantity: 3.0,
            unitPrice: 100.0,
            totalPrice: 300.0,
          ),
        ],
      );

      await orderRepo.addPayment(Payment(
        id: 'pay-del-1',
        orderId: orderId,
        customerId: 'cust-regular-1',
        amount: 100.0,
        method: 'cash',
        createdAt: now,
      ));

      expect((await itemDao.getItemById('item-rice'))!.stock, equals(97.0));
      expect((await customerDao.getCustomerById('cust-regular-1'))!.outstandingBalance, equals(200.0));

      // Delete the order
      await orderRepo.deleteOrder(orderId);

      // Verify order is gone
      final deleted = await orderRepo.getOrderById(orderId);
      expect(deleted, isNull);

      // Verify stock restored
      expect((await itemDao.getItemById('item-rice'))!.stock, equals(100.0));

      // Verify customer balance returned to 0
      expect((await customerDao.getCustomerById('cust-regular-1'))!.outstandingBalance, equals(0.0));
    });

    test('7. Delivery Status Transitions: Cancel -> Uncancel maintains correct stock and ledger state', () async {
      final now = DateTime.now();
      const orderId = 'ORD-CANCEL-TEST';

      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-regular-1',
          subtotal: 200.0,
          grandTotal: 200.0,
          paidAmount: 200.0,
          remainingAmount: 0.0,
          deliveryStatus: 'pending',
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-can-1',
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

      // 1. Cancel order -> Restores stock back to 100.0
      await orderRepo.updateDeliveryStatus(orderId, 'cancelled');
      expect((await itemDao.getItemById('item-rice'))!.stock, equals(100.0));

      final cancelledOrder = await orderRepo.getOrderById(orderId);
      expect(cancelledOrder!.deliveryStatus, equals('cancelled'));
      expect(cancelledOrder.paidAmount, equals(0.0));

      // 2. Un-cancel order (e.g. mark as delivered) -> Deducts stock again (100 - 2 = 98)
      await orderRepo.updateDeliveryStatus(orderId, 'delivered');
      expect((await itemDao.getItemById('item-rice'))!.stock, equals(98.0));

      final activeOrder = await orderRepo.getOrderById(orderId);
      expect(activeOrder!.deliveryStatus, equals('delivered'));
    });

    test('8. BillTextGenerator: Generates bilingual receipt with Marathi translation and correct math', () {
      final orderDate = DateTime(2026, 8, 17, 10, 30);
      final textBill = BillTextGenerator.generate(
        businessName: 'OrderKart Mart',
        customerName: 'Aarav Deshmukh',
        customerAddress: 'Plot 42, Station Road',
        orderNoLabel: '#ORD-0001',
        orderDate: orderDate,
        items: [
          {
            'item_name': 'Basmati Rice (तांदूळ)',
            'quantity': 2.0,
            'unit': 'kg',
            'unit_price': 100.0,
            'total_price': 200.0,
          },
          {
            'item_name': 'Sunflower Oil (तेल)',
            'quantity': 1.0,
            'unit': 'l',
            'unit_price': 160.0,
            'total_price': 160.0,
          },
        ],
        subtotal: 360.0,
        discount: 20.0,
        deliveryCharge: 30.0,
        grandTotal: 370.0,
        paidAmount: 200.0,
        remainingAmount: 170.0,
        paymentMethod: 'cash',
        ownerPhone: '9876543210',
      );

      expect(textBill.contains('*ORDERKART MART*'), isTrue);
      expect(textBill.contains('*#ORD-0001*'), isTrue);
      expect(textBill.contains('Aarav Deshmukh'), isTrue);
      expect(textBill.contains('₹360.00'), isTrue);
      expect(textBill.contains('₹370.00'), isTrue);
      expect(textBill.contains('₹200.00 (CASH)'), isTrue);
      expect(textBill.contains('Due Amount:     ₹170.00'), isTrue);
    });

    test('9. Smart Rounding: Edge cases, snaps, and nearest 5/10 logic', () {
      expect(SmartRounding.round(99.0), equals(100.0));
      expect(SmartRounding.round(100.0), equals(100.0));
      expect(SmartRounding.round(101.0), equals(105.0));
      expect(SmartRounding.round(102.5), equals(105.0));
      expect(SmartRounding.round(104.0), equals(105.0));
      expect(SmartRounding.round(105.0), equals(105.0));
      expect(SmartRounding.round(107.0), equals(110.0));
      expect(SmartRounding.round(108.5), equals(110.0));
    });
  });
}
