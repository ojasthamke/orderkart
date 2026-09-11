import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/customer/data/customer_dao.dart';
import 'package:orderkart/features/customer/domain/customer.dart';
import 'package:orderkart/features/order/data/order_dao.dart';
import 'package:orderkart/features/order/domain/order.dart';
import 'package:orderkart/features/settings/data/settings_dao.dart';

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
    await db.delete('orders');
    await db.delete('customers');
    await db.delete('settings');
  });

  group('OrderKart Order Acceptance & Delivery Time Configuration Tests', () {
    test('acceptOrder updates status to Confirmed and sets estimated delivery time and timestamp', () async {
      final customerDao = CustomerDao();
      final orderDao = OrderDao();
      final now = DateTime.now();

      await customerDao.insertCustomer(Customer(
        id: 'cust_01',
        streetId: 'street_01',
        name: 'Test Customer 1',
        phone1: '9876543210',
        customerSince: now,
        createdAt: now,
        updatedAt: now,
      ));

      // Insert a pending order
      final testOrder = AppOrder(
        id: 'order_test_101',
        customerId: 'cust_01',
        subtotal: 250.0,
        grandTotal: 250.0,
        remainingAmount: 250.0,
        deliveryStatus: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      await orderDao.insertOrder(testOrder);

      // Verify initial status
      var fetched = await orderDao.getOrderById('order_test_101');
      expect(fetched, isNotNull);
      expect(fetched!.deliveryStatus, equals('pending'));
      expect(fetched.estimatedDeliveryTime, isNull);

      // Admin accepts order with 45 mins delivery time
      final targetAt = now.add(const Duration(minutes: 45));
      await orderDao.acceptOrder(
        'order_test_101',
        deliveryTimeStr: '45 mins',
        estimatedDeliveryAt: targetAt,
      );

      // Verify accepted order state
      fetched = await orderDao.getOrderById('order_test_101');
      expect(fetched, isNotNull);
      expect(fetched!.deliveryStatus, equals('confirmed'));
      expect(fetched.estimatedDeliveryTime, equals('45 mins'));
      expect(fetched.acceptedAt, isNotNull);
      expect(fetched.estimatedDeliveryAt, isNotNull);
    });

    test('updateEstimatedDeliveryTime modifies delivery time for active order without changing status', () async {
      final customerDao = CustomerDao();
      final orderDao = OrderDao();
      final now = DateTime.now();

      await customerDao.insertCustomer(Customer(
        id: 'cust_02',
        streetId: 'street_02',
        name: 'Test Customer 2',
        phone1: '9876543211',
        customerSince: now,
        createdAt: now,
        updatedAt: now,
      ));

      // Insert a confirmed order
      final testOrder = AppOrder(
        id: 'order_test_102',
        customerId: 'cust_02',
        subtotal: 400.0,
        grandTotal: 400.0,
        remainingAmount: 400.0,
        deliveryStatus: 'confirmed',
        estimatedDeliveryTime: '30 mins',
        createdAt: now,
        updatedAt: now,
      );
      await orderDao.insertOrder(testOrder);

      // Admin updates delivery time to 1 hr
      final newTargetAt = now.add(const Duration(hours: 1));
      await orderDao.updateEstimatedDeliveryTime(
        'order_test_102',
        deliveryTimeStr: '1 hr',
        estimatedDeliveryAt: newTargetAt,
      );

      final fetched = await orderDao.getOrderById('order_test_102');
      expect(fetched, isNotNull);
      expect(fetched!.deliveryStatus, equals('confirmed'));
      expect(fetched.estimatedDeliveryTime, equals('1 hr'));
      expect(fetched.estimatedDeliveryAt, isNotNull);
    });

    test('SettingsDao saves and loads default delivery time store promise', () async {
      final settingsDao = SettingsDao();

      // Default value before custom setting
      final defaultSettings = await settingsDao.loadAllSettings();
      expect(defaultSettings.defaultDeliveryTime, equals('30-45 mins'));

      // Admin configures new store delivery promise
      await settingsDao.setValue('default_delivery_time', '45-60 mins');
      final updatedSettings = await settingsDao.loadAllSettings();
      expect(updatedSettings.defaultDeliveryTime, equals('45-60 mins'));
    });
  });
}
