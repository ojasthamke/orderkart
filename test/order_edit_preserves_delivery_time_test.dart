import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/customer/data/customer_dao.dart';
import 'package:orderkart/features/customer/domain/customer.dart';
import 'package:orderkart/features/order/data/order_dao.dart';
import 'package:orderkart/features/order/domain/order.dart';
import 'package:orderkart/features/order/domain/order_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    await db.insert('areas', {
      'id': 'area_01',
      'name': 'Main Area',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('streets', {
      'id': 'street_01',
      'area_id': 'area_01',
      'name': 'Main Street',
      'created_at': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('locations', {
      'id': 'area_01',
      'name': 'Main Area',
      'location_kind': 'area',
      'sequence_key': 'a',
      'depth': 0,
      'materialized_path': '/area_01/',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('locations', {
      'id': 'street_01',
      'parent_location_id': 'area_01',
      'name': 'Main Street',
      'location_kind': 'road',
      'sequence_key': 'a0',
      'depth': 1,
      'materialized_path': '/area_01/street_01/',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  tearDown(() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('order_items');
    await db.delete('items');
    await db.delete('orders');
    await db.delete('customers');
  });

  group('Order Edit Preserves Estimated Delivery Time & Timestamps', () {
    test('Editing an order via insertOrder preserves delivery time and timestamps if omitted', () async {
      final customerDao = CustomerDao();
      final orderDao = OrderDao();
      final now = DateTime.now();

      await customerDao.insertCustomer(Customer(
        id: 'cust_edit_01',
        streetId: 'street_01',
        name: 'John Doe',
        phone1: '9876543210',
        address: 'Flat 101, Green Apts',
        customerSince: now,
        createdAt: now,
        updatedAt: now,
      ));

      final initialEstAt = now.add(const Duration(minutes: 30)).toIso8601String();
      final initialAcceptedAt = now.toIso8601String();

      final initialOrder = AppOrder(
        id: 'order_edit_01',
        customerId: 'cust_edit_01',
        customerName: 'John Doe',
        customerPhone: '9876543210',
        customerAddress: 'Flat 101, Green Apts',
        subtotal: 500.0,
        grandTotal: 500.0,
        remainingAmount: 500.0,
        deliveryStatus: 'confirmed',
        estimatedDeliveryTime: '30 mins',
        estimatedDeliveryAt: initialEstAt,
        acceptedAt: initialAcceptedAt,
        createdAt: now,
        updatedAt: now,
      );
      await orderDao.insertOrder(initialOrder);

      var fetched = await orderDao.getOrderById('order_edit_01');
      expect(fetched, isNotNull);
      expect(fetched!.estimatedDeliveryTime, equals('30 mins'));
      expect(fetched.estimatedDeliveryAt, equals(initialEstAt));
      expect(fetched.acceptedAt, equals(initialAcceptedAt));

      final editedOrderWithoutTiming = AppOrder(
        id: 'order_edit_01',
        customerId: 'cust_edit_01',
        subtotal: 650.0,
        grandTotal: 650.0,
        remainingAmount: 650.0,
        deliveryStatus: 'confirmed',
        estimatedDeliveryTime: null,
        estimatedDeliveryAt: null,
        acceptedAt: null,
        createdAt: now,
        updatedAt: DateTime.now(),
      );

      await orderDao.insertOrder(editedOrderWithoutTiming);

      fetched = await orderDao.getOrderById('order_edit_01');
      expect(fetched, isNotNull);
      expect(fetched!.subtotal, equals(650.0));
      expect(fetched.estimatedDeliveryTime, equals('30 mins'),
          reason: 'Delivery time must be preserved when edited without providing new time');
      expect(fetched.estimatedDeliveryAt, equals(initialEstAt));
      expect(fetched.acceptedAt, equals(initialAcceptedAt));
      expect(fetched.customerName, equals('John Doe'));
      expect(fetched.customerPhone, equals('9876543210'));
      expect(fetched.customerAddress, equals('Flat 101, Green Apts'));
    });

    test('Incoming null or empty string does not overwrite existing delivery time', () async {
      final customerDao = CustomerDao();
      final orderDao = OrderDao();
      final now = DateTime.now();

      await customerDao.insertCustomer(Customer(
        id: 'cust_edit_02',
        streetId: 'street_01',
        name: 'Jane Smith',
        phone1: '9876543211',
        customerSince: now,
        createdAt: now,
        updatedAt: now,
      ));

      final initialEstAt = now.add(const Duration(minutes: 45)).toIso8601String();
      final initialAcceptedAt = now.toIso8601String();

      final initialOrder = AppOrder(
        id: 'order_edit_02',
        customerId: 'cust_edit_02',
        subtotal: 300.0,
        grandTotal: 300.0,
        remainingAmount: 300.0,
        deliveryStatus: 'confirmed',
        estimatedDeliveryTime: '45 mins',
        estimatedDeliveryAt: initialEstAt,
        acceptedAt: initialAcceptedAt,
        createdAt: now,
        updatedAt: now,
      );
      await orderDao.insertOrder(initialOrder);

      final corruptMap = {
        ...initialOrder.toMap(),
        'subtotal': 350.0,
        'grand_total': 350.0,
        'remaining_amount': 350.0,
        'estimated_delivery_time': 'null',
        'estimated_delivery_at': '',
        'accepted_at': '   ',
      };
      final orderFromCorruptMap = AppOrder.fromMap(corruptMap);
      expect(orderFromCorruptMap.estimatedDeliveryTime, isNull);
      expect(orderFromCorruptMap.estimatedDeliveryAt, isNull);
      expect(orderFromCorruptMap.acceptedAt, isNull);

      await orderDao.updateOrder(orderFromCorruptMap);

      final fetched = await orderDao.getOrderById('order_edit_02');
      expect(fetched, isNotNull);
      expect(fetched!.subtotal, equals(350.0));
      expect(fetched.estimatedDeliveryTime, equals('45 mins'));
      expect(fetched.estimatedDeliveryAt, equals(initialEstAt));
      expect(fetched.acceptedAt, equals(initialAcceptedAt));
    });

    test('Updating delivery time explicitly replaces the old delivery time', () async {
      final customerDao = CustomerDao();
      final orderDao = OrderDao();
      final now = DateTime.now();

      await customerDao.insertCustomer(Customer(
        id: 'cust_edit_03',
        streetId: 'street_01',
        name: 'Alice Wonder',
        phone1: '9876543212',
        customerSince: now,
        createdAt: now,
        updatedAt: now,
      ));

      final initialOrder = AppOrder(
        id: 'order_edit_03',
        customerId: 'cust_edit_03',
        subtotal: 200.0,
        grandTotal: 200.0,
        remainingAmount: 200.0,
        deliveryStatus: 'confirmed',
        estimatedDeliveryTime: '30 mins',
        createdAt: now,
        updatedAt: now,
      );
      await orderDao.insertOrder(initialOrder);

      final newEstAt = now.add(const Duration(hours: 1)).toIso8601String();
      final updatedOrder = initialOrder.copyWith(
        estimatedDeliveryTime: '1 hr',
        estimatedDeliveryAt: newEstAt,
      );
      await orderDao.insertOrder(updatedOrder);

      final fetched = await orderDao.getOrderById('order_edit_03');
      expect(fetched, isNotNull);
      expect(fetched!.estimatedDeliveryTime, equals('1 hr'));
      expect(fetched.estimatedDeliveryAt, equals(newEstAt));
    });

    test('updateOrderRates preserves estimated delivery time and timestamps', () async {
      final customerDao = CustomerDao();
      final orderDao = OrderDao();
      final now = DateTime.now();
      final db = await DatabaseHelper.instance.database;

      await customerDao.insertCustomer(Customer(
        id: 'cust_edit_04',
        streetId: 'street_01',
        name: 'Bob Builder',
        phone1: '9876543213',
        customerSince: now,
        createdAt: now,
        updatedAt: now,
      ));

      await db.insert('items', {
        'id': 'item_apple_01',
        'name': 'Fresh Apples',
        'category': 'Fruits',
        'selling_price': 120.0,
        'cost_price': 80.0,
        'unit': 'kg',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final initialEstAt = now.add(const Duration(minutes: 30)).toIso8601String();
      final initialAcceptedAt = now.toIso8601String();

      final initialOrder = AppOrder(
        id: 'order_edit_04',
        customerId: 'cust_edit_04',
        subtotal: 100.0,
        grandTotal: 100.0,
        remainingAmount: 100.0,
        deliveryStatus: 'confirmed',
        estimatedDeliveryTime: '30 mins',
        estimatedDeliveryAt: initialEstAt,
        acceptedAt: initialAcceptedAt,
        createdAt: now,
        updatedAt: now,
      );
      await orderDao.insertOrder(initialOrder);

      await orderDao.insertOrderItem(OrderItem(
        id: 'oi_01',
        orderId: 'order_edit_04',
        itemId: 'item_apple_01',
        itemName: 'Fresh Apples',
        itemUnit: 'kg',
        quantity: 1.0,
        unitPrice: 100.0,
        totalPrice: 100.0,
      ));

      final result = await orderDao.updateOrderRates('order_edit_04');
      expect(result['success'], isTrue);

      final fetched = await orderDao.getOrderById('order_edit_04');
      expect(fetched, isNotNull);
      expect(fetched!.subtotal, equals(120.0));
      expect(fetched.estimatedDeliveryTime, equals('30 mins'));
      expect(fetched.estimatedDeliveryAt, equals(initialEstAt));
      expect(fetched.acceptedAt, equals(initialAcceptedAt));
    });
  });
}