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
import 'package:orderkart/features/inventory/domain/item.dart';
import 'package:orderkart/core/utils/unit_converter.dart';
import 'package:orderkart/core/utils/smart_rounding.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('OrderKart Deep System & Order Creation Invariant Audit Suite', () {
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

      // Seed Area & Street
      await db.insert('locations', {
        'id': 'area-test-1',
        'name': 'Main Market Area',
        'location_kind': 'area',
        'sequence_key': '001',
        'depth': 0,
        'materialized_path': '/area-test-1/',
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      await db.insert('locations', {
        'id': 'street-test-1',
        'parent_location_id': 'area-test-1',
        'name': 'Market Street 1',
        'location_kind': 'road',
        'sequence_key': '001000',
        'depth': 1,
        'materialized_path': '/area-test-1/street-test-1/',
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      await db.insert('areas', {
        'id': 'area-test-1',
        'name': 'Main Market Area',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('streets', {
        'id': 'street-test-1',
        'area_id': 'area-test-1',
        'name': 'Market Street 1',
        'created_at': now.toIso8601String(),
      });

      // Seed Inventory Items
      await itemDao.insertItem(Item(
        id: 'item-tomato',
        name: 'Fresh Red Tomato',
        category: 'Vegetables',
        unit: 'kg',
        costPrice: 20.0,
        sellingPrice: 40.0,
        marketPrice: 50.0,
        stock: 50.0,
        minStock: 5.0,
        weightPerPiece: 0.1,
        createdAt: now,
        updatedAt: now,
      ));

      await itemDao.insertItem(Item(
        id: 'item-apple',
        name: 'Kashmir Apple',
        category: 'Fruits',
        unit: 'piece',
        costPrice: 15.0,
        sellingPrice: 25.0,
        marketPrice: 30.0,
        stock: 100.0,
        minStock: 10.0,
        weightPerPiece: 0.2,
        createdAt: now,
        updatedAt: now,
      ));

      // Seed Customer
      await db.insert('customers', {
        'id': 'cust-regular-1',
        'street_id': 'street-test-1',
        'location_id': 'street-test-1',
        'name': 'Ramesh Patil',
        'phone1': '9876543210',
        'address': 'House 12, Market Street',
        'outstanding_balance': 0.0,
        'total_orders': 0,
        'total_paid': 0.0,
        'total_pending': 0.0,
        'is_vip': 0,
        'customer_since': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    });

    test('1. Normal Order Creation & Stock Deduction with Grams to Kg Conversion', () async {
      final now = DateTime.now();

      // Ordering 500g Tomato (@ Rs 40/kg -> Rs 20.00)
      final items = [
        OrderItem(
          id: 'oi-1',
          orderId: 'ORD-1001',
          itemId: 'item-tomato',
          itemName: 'Fresh Red Tomato',
          itemUnit: 'gram',
          quantity: 500.0,
          unitPrice: 0.04,
          totalPrice: 20.0,
          isAvailable: true,
        ),
      ];

      final order = AppOrder(
        id: 'ORD-1001',
        customerId: 'cust-regular-1',
        subtotal: 20.0,
        discount: 0.0,
        deliveryCharge: 0.0,
        smartRoundedAmount: 0.0,
        grandTotal: 20.0,
        paidAmount: 20.0,
        remainingAmount: 0.0,
        deliveryStatus: 'pending',
        notes: 'Test order',
        savings: 5.0,
        createdAt: now,
        updatedAt: now,
        orderType: 'Normal',
      );

      await orderRepo.createOrder(order, items);

      // Verify Order In SQLite
      final dbOrder = await orderDao.getOrderById('ORD-1001');
      expect(dbOrder, isNotNull);
      expect(dbOrder!.grandTotal, 20.0);
      expect(dbOrder.paidAmount, 20.0);
      expect(dbOrder.remainingAmount, 0.0);

      // Verify Stock: 50.0 kg - 0.5 kg = 49.5 kg
      final dbTomato = await itemDao.getItemById('item-tomato');
      expect(dbTomato!.stock, closeTo(49.5, 0.001));
    });

    test('2. Customer Overpayment & Advance Credit Settlement Flow', () async {
      final now = DateTime.now();

      // Order 1: Total Rs 40, Customer pays Rs 100 (Advance Overpayment of Rs 60)
      final items1 = [
        OrderItem(
          id: 'oi-101',
          orderId: 'ORD-2001',
          itemId: 'item-tomato',
          itemName: 'Fresh Red Tomato',
          itemUnit: 'kg',
          quantity: 1.0,
          unitPrice: 40.0,
          totalPrice: 40.0,
          isAvailable: true,
        ),
      ];

      final order1 = AppOrder(
        id: 'ORD-2001',
        customerId: 'cust-regular-1',
        subtotal: 40.0,
        discount: 0.0,
        deliveryCharge: 0.0,
        smartRoundedAmount: 0.0,
        grandTotal: 40.0,
        paidAmount: 100.0,
        remainingAmount: -60.0, // Advance credit
        deliveryStatus: 'delivered',
        createdAt: now,
        updatedAt: now,
      );

      await orderRepo.createOrder(order1, items1);
      await orderRepo.addPayment(Payment(
        id: 'pay-2001',
        orderId: 'ORD-2001',
        customerId: 'cust-regular-1',
        amount: 100.0,
        method: 'Cash',
        createdAt: now,
      ));

      // Customer should have negative balance (Rs -60.00 advance credit)
      final custAfterOrder1 = await customerDao.getCustomerById('cust-regular-1');
      expect(custAfterOrder1!.outstandingBalance, -60.0);
      expect(custAfterOrder1.totalPending, 0.0);

      // Order 2: New order of Rs 50. Customer settles from advance credit!
      final items2 = [
        OrderItem(
          id: 'oi-102',
          orderId: 'ORD-2002',
          itemId: 'item-apple',
          itemName: 'Kashmir Apple',
          itemUnit: 'piece',
          quantity: 2.0,
          unitPrice: 25.0,
          totalPrice: 50.0,
          isAvailable: true,
        ),
      ];

      final order2 = AppOrder(
        id: 'ORD-2002',
        customerId: 'cust-regular-1',
        subtotal: 50.0,
        discount: 0.0,
        deliveryCharge: 0.0,
        smartRoundedAmount: 0.0,
        grandTotal: 50.0,
        paidAmount: 50.0, // Settled from Rs 60 advance
        remainingAmount: 0.0,
        deliveryStatus: 'delivered',
        createdAt: now.add(const Duration(minutes: 5)),
        updatedAt: now.add(const Duration(minutes: 5)),
      );

      await orderRepo.createOrder(order2, items2);

      // Total orders = 40 + 50 = 90. Total paid = 100. Outstanding balance = 90 - 100 = -10.0 (still Rs 10 advance left)
      final custAfterOrder2 = await customerDao.getCustomerById('cust-regular-1');
      expect(custAfterOrder2!.outstandingBalance, -10.0);
      expect(custAfterOrder2.totalOrders, 2);
    });

    test('3. Denied and Cancelled Order Stock Restoration and Tab Filtering', () async {
      final now = DateTime.now();

      final items = [
        OrderItem(
          id: 'oi-301',
          orderId: 'ORD-3001',
          itemId: 'item-tomato',
          itemName: 'Fresh Red Tomato',
          itemUnit: 'kg',
          quantity: 10.0,
          unitPrice: 40.0,
          totalPrice: 400.0,
          isAvailable: true,
        ),
      ];

      final order = AppOrder(
        id: 'ORD-3001',
        customerId: 'cust-regular-1',
        subtotal: 400.0,
        discount: 0.0,
        deliveryCharge: 0.0,
        smartRoundedAmount: 0.0,
        grandTotal: 400.0,
        paidAmount: 0.0,
        remainingAmount: 400.0,
        deliveryStatus: 'pending',
        createdAt: now,
        updatedAt: now,
        orderType: 'Pre-Order',
      );

      await orderRepo.createOrder(order, items);

      // Stock deducted: 50 - 10 = 40 kg
      var tomato = await itemDao.getItemById('item-tomato');
      expect(tomato!.stock, 40.0);

      // Verify Pre-Order tab returns this order
      final preOrders = await orderDao.getAllOrders(status: 'preorder');
      expect(preOrders.any((o) => o.id == 'ORD-3001'), isTrue);

      // Admin Denies the order
      await orderRepo.updateDeliveryStatus('ORD-3001', 'denied');

      // Stock should be restored back to 50 kg!
      tomato = await itemDao.getItemById('item-tomato');
      expect(tomato!.stock, 50.0);

      // Cancelled/Denied tab should show this order
      final cancelledOrders = await orderDao.getAllOrders(status: 'cancelled');
      expect(cancelledOrders.any((o) => o.id == 'ORD-3001'), isTrue);

      // Customer due should be Rs 0
      final cust = await customerDao.getCustomerById('cust-regular-1');
      expect(cust!.outstandingBalance, 0.0);
    });

    test('4. Unit Converter Mathematical Precision for All Commercial Units', () {
      expect(UnitConverter.toBase(500, 'gram'), 0.5);
      expect(UnitConverter.toBase(250, 'g'), 0.25);
      expect(UnitConverter.toBase(100, 'gm'), 0.1);
      expect(UnitConverter.toBase(1000, 'gms'), 1.0);
      expect(UnitConverter.toBase(2, 'dozen'), 24.0);
      expect(UnitConverter.toBase(6, 'dz'), 72.0);
      expect(UnitConverter.toBase(500, 'ml'), 0.5);
      expect(UnitConverter.toBase(2, 'quintal'), 200.0);

      expect(UnitConverter.convert(quantity: 1.5, fromUnit: 'kg', toUnit: 'gram'), 1500.0);
      expect(UnitConverter.convert(quantity: 24, fromUnit: 'piece', toUnit: 'dozen'), 2.0);
    });

    test('5. Smart Rounding Ceiling 5-Rupee Precision', () {
      expect(SmartRounding.round(100.0), 100.0);
      expect(SmartRounding.round(101.0), 105.0);
      expect(SmartRounding.round(104.5), 105.0);
      expect(SmartRounding.round(105.0), 105.0);
      expect(SmartRounding.round(106.0), 110.0);
    });
  });
}
