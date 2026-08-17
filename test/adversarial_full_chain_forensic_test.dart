import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/area/data/area_dao.dart';
import 'package:orderkart/features/location/data/location_dao.dart';
import 'package:orderkart/features/location/domain/location.dart';
import 'package:orderkart/features/location/domain/location_kind.dart';
import 'package:orderkart/features/analytics/data/analytics_dao.dart';
import 'package:orderkart/features/order/data/order_dao.dart';
import 'package:orderkart/features/order/data/order_repository_impl.dart';
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

  group('Adversarial Forensic Bug Hunt & Full Chain Audit Test Suite', () {
    final areaDao = AreaDao();
    final locationDao = LocationDao();
    final analyticsDao = AnalyticsDao();
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

      // Seed Area A (Shivaji Nagar)
      await db.insert('areas', {
        'id': 'area-A',
        'name': 'Area A (Shivaji Nagar)',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      await db.insert('locations', {
        'id': 'area-A',
        'name': 'Area A (Shivaji Nagar)',
        'location_kind': 'area',
        'sequence_key': 'a',
        'depth': 0,
        'materialized_path': '/area-A/',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Seed Area B (Kothrud)
      await db.insert('areas', {
        'id': 'area-B',
        'name': 'Area B (Kothrud)',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      await db.insert('locations', {
        'id': 'area-B',
        'name': 'Area B (Kothrud)',
        'location_kind': 'area',
        'sequence_key': 'b',
        'depth': 0,
        'materialized_path': '/area-B/',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Seed Streets for Area A
      await db.insert('streets', {
        'id': 'street-A1',
        'area_id': 'area-A',
        'name': 'FC Road A1',
        'created_at': now.toIso8601String(),
      });
      await db.insert('locations', {
        'id': 'street-A1',
        'parent_location_id': 'area-A',
        'name': 'FC Road A1',
        'location_kind': 'road',
        'sequence_key': 'a.1',
        'depth': 1,
        'materialized_path': '/area-A/street-A1/',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Seed Streets for Area B
      await db.insert('streets', {
        'id': 'street-B1',
        'area_id': 'area-B',
        'name': 'Paud Road B1',
        'created_at': now.toIso8601String(),
      });
      await db.insert('locations', {
        'id': 'street-B1',
        'parent_location_id': 'area-B',
        'name': 'Paud Road B1',
        'location_kind': 'road',
        'sequence_key': 'b.1',
        'depth': 1,
        'materialized_path': '/area-B/street-B1/',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Seed Customers
      await db.insert('customers', {
        'id': 'cust-A1',
        'street_id': 'street-A1',
        'location_id': 'street-A1',
        'name': 'Anil Sharma (A1)',
        'phone1': '9800000001',
        'outstanding_balance': 0.0,
        'is_vip': 0,
        'is_archived': 0,
        'customer_since': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('customers', {
        'id': 'cust-A2',
        'street_id': 'street-A1',
        'location_id': 'street-A1',
        'name': 'Amit Patil (A2)',
        'phone1': '9800000002',
        'outstanding_balance': 0.0,
        'is_vip': 0,
        'is_archived': 0,
        'customer_since': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('customers', {
        'id': 'cust-B1',
        'street_id': 'street-B1',
        'location_id': 'street-B1',
        'name': 'Bhavin Joshi (B1)',
        'phone1': '9800000003',
        'outstanding_balance': 0.0,
        'is_vip': 0,
        'is_archived': 0,
        'customer_since': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Seed Items
      await db.insert('items', {
        'id': 'item-X',
        'name': 'Item X (Basmati Rice)',
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
        'id': 'item-Y',
        'name': 'Item Y (Sunflower Oil)',
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
        'id': 'item-Z',
        'name': 'Item Z (Farm Eggs)',
        'category': 'Groceries',
        'unit': 'dozen',
        'cost_price': 60.0,
        'selling_price': 84.0,
        'market_price': 90.0,
        'stock': 20.0,
        'min_stock': 2.0,
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    });

    test('1. Controlled Lifecycle Test: 5 -> 8 -> 3 -> Delete with stock & area isolation', () async {
      final now = DateTime.now();
      const orderId = 'ORD-ADV-CTRL';
      final db = await DatabaseHelper.instance.database;

      // 1. Initial Stock = 100
      expect((await itemDao.getItemById('item-X'))!.stock, equals(100.0));

      // 2. Create Order Qty = 5
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-A1',
          subtotal: 500.0,
          grandTotal: 500.0,
          paidAmount: 500.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-c-1',
            orderId: orderId,
            itemId: 'item-X',
            itemName: 'Item X (Basmati Rice)',
            itemUnit: 'kg',
            quantity: 5.0,
            unitPrice: 100.0,
            totalPrice: 500.0,
          )
        ],
      );

      // Area A Ordered Qty = 5, Stock = 95
      var qRes = await db.rawQuery('''
        SELECT SUM(oi.quantity) as q FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        JOIN customers c ON o.customer_id = c.id
        LEFT JOIN locations st ON (c.location_id = st.id OR c.street_id = st.id)
        WHERE (c.location_id = 'area-A' OR c.street_id = 'area-A' OR st.id = 'area-A' OR st.parent_location_id = 'area-A' OR st.materialized_path LIKE '%/area-A/%')
          AND oi.item_id = 'item-X' AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      ''');
      expect((qRes.first['q'] as num).toDouble(), equals(5.0));
      expect((await itemDao.getItemById('item-X'))!.stock, equals(95.0));

      // 3. Edit Order Qty 5 -> 8
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-A1',
          subtotal: 800.0,
          grandTotal: 800.0,
          paidAmount: 800.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-c-1',
            orderId: orderId,
            itemId: 'item-X',
            itemName: 'Item X (Basmati Rice)',
            itemUnit: 'kg',
            quantity: 8.0,
            unitPrice: 100.0,
            totalPrice: 800.0,
          )
        ],
      );

      // Area A Ordered Qty = 8 (NOT 13), Stock = 92
      qRes = await db.rawQuery('''
        SELECT SUM(oi.quantity) as q FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        JOIN customers c ON o.customer_id = c.id
        LEFT JOIN locations st ON (c.location_id = st.id OR c.street_id = st.id)
        WHERE (c.location_id = 'area-A' OR c.street_id = 'area-A' OR st.id = 'area-A' OR st.parent_location_id = 'area-A' OR st.materialized_path LIKE '%/area-A/%')
          AND oi.item_id = 'item-X' AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      ''');
      expect((qRes.first['q'] as num).toDouble(), equals(8.0));
      expect((await itemDao.getItemById('item-X'))!.stock, equals(92.0));

      // 4. Edit Order Qty 8 -> 3
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-A1',
          subtotal: 300.0,
          grandTotal: 300.0,
          paidAmount: 300.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-c-1',
            orderId: orderId,
            itemId: 'item-X',
            itemName: 'Item X (Basmati Rice)',
            itemUnit: 'kg',
            quantity: 3.0,
            unitPrice: 100.0,
            totalPrice: 300.0,
          )
        ],
      );

      // Area A Ordered Qty = 3, Stock = 97
      qRes = await db.rawQuery('''
        SELECT SUM(oi.quantity) as q FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        JOIN customers c ON o.customer_id = c.id
        LEFT JOIN locations st ON (c.location_id = st.id OR c.street_id = st.id)
        WHERE (c.location_id = 'area-A' OR c.street_id = 'area-A' OR st.id = 'area-A' OR st.parent_location_id = 'area-A' OR st.materialized_path LIKE '%/area-A/%')
          AND oi.item_id = 'item-X' AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      ''');
      expect((qRes.first['q'] as num).toDouble(), equals(3.0));
      expect((await itemDao.getItemById('item-X'))!.stock, equals(97.0));

      // 5. Delete Order
      await orderRepo.deleteOrder(orderId);

      // Area A Ordered Qty = 0, Stock = 100
      qRes = await db.rawQuery('''
        SELECT SUM(oi.quantity) as q FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        JOIN customers c ON o.customer_id = c.id
        LEFT JOIN locations st ON (c.location_id = st.id OR c.street_id = st.id)
        WHERE (c.location_id = 'area-A' OR c.street_id = 'area-A' OR st.id = 'area-A' OR st.parent_location_id = 'area-A' OR st.materialized_path LIKE '%/area-A/%')
          AND oi.item_id = 'item-X' AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      ''');
      expect(qRes.first['q'], isNull);
      expect((await itemDao.getItemById('item-X'))!.stock, equals(100.0));

      // 6. Verify Area B has ZERO trace of Area A orders
      final areaBPerf = (await analyticsDao.getAreaPerformance()).firstWhere((p) => p['area_id'] == 'area-B');
      expect(areaBPerf['total_orders'], equals(0));
      expect(areaBPerf['total_sales'], equals(0.0));
    });

    test('2. Multi-Customer & Multi-Item Test: A1 (5 X + 3 Y), A2 (7 X) -> Item X = 12, Item Y = 3, Total = 15', () async {
      final now = DateTime.now();
      final db = await DatabaseHelper.instance.database;

      // A1 Order: 5 kg Item X + 3 L Item Y
      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-A1-MULTI',
          customerId: 'cust-A1',
          subtotal: 5 * 100.0 + 3 * 160.0,
          grandTotal: 5 * 100.0 + 3 * 160.0,
          paidAmount: 980.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-a1-1',
            orderId: 'ORD-A1-MULTI',
            itemId: 'item-X',
            itemName: 'Item X',
            itemUnit: 'kg',
            quantity: 5.0,
            unitPrice: 100.0,
            totalPrice: 500.0,
          ),
          OrderItem(
            id: 'oi-a1-2',
            orderId: 'ORD-A1-MULTI',
            itemId: 'item-Y',
            itemName: 'Item Y',
            itemUnit: 'l',
            quantity: 3.0,
            unitPrice: 160.0,
            totalPrice: 480.0,
          ),
        ],
      );

      // A2 Order: 7 kg Item X
      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-A2-MULTI',
          customerId: 'cust-A2',
          subtotal: 7 * 100.0,
          grandTotal: 7 * 100.0,
          paidAmount: 700.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-a2-1',
            orderId: 'ORD-A2-MULTI',
            itemId: 'item-X',
            itemName: 'Item X',
            itemUnit: 'kg',
            quantity: 7.0,
            unitPrice: 100.0,
            totalPrice: 700.0,
          ),
        ],
      );

      // Verify Area A Total Item X = 12
      final qX = await db.rawQuery('''
        SELECT SUM(oi.quantity) as q FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        JOIN customers c ON o.customer_id = c.id
        LEFT JOIN locations st ON (c.location_id = st.id OR c.street_id = st.id)
        WHERE (c.location_id = 'area-A' OR c.street_id = 'area-A' OR st.id = 'area-A' OR st.parent_location_id = 'area-A' OR st.materialized_path LIKE '%/area-A/%')
          AND oi.item_id = 'item-X' AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      ''');
      expect((qX.first['q'] as num).toDouble(), equals(12.0));

      // Verify Area A Total Item Y = 3
      final qY = await db.rawQuery('''
        SELECT SUM(oi.quantity) as q FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        JOIN customers c ON o.customer_id = c.id
        LEFT JOIN locations st ON (c.location_id = st.id OR c.street_id = st.id)
        WHERE (c.location_id = 'area-A' OR c.street_id = 'area-A' OR st.id = 'area-A' OR st.parent_location_id = 'area-A' OR st.materialized_path LIKE '%/area-A/%')
          AND oi.item_id = 'item-Y' AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      ''');
      expect((qY.first['q'] as num).toDouble(), equals(3.0));

      // Verify Area A Total Items = 15
      final qTotal = await db.rawQuery('''
        SELECT SUM(oi.quantity) as q FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        JOIN customers c ON o.customer_id = c.id
        LEFT JOIN locations st ON (c.location_id = st.id OR c.street_id = st.id)
        WHERE (c.location_id = 'area-A' OR c.street_id = 'area-A' OR st.id = 'area-A' OR st.parent_location_id = 'area-A' OR st.materialized_path LIKE '%/area-A/%')
          AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      ''');
      expect((qTotal.first['q'] as num).toDouble(), equals(15.0));

      // Stock remaining: Item X = 100 - 12 = 88 kg, Item Y = 50 - 3 = 47 L
      expect((await itemDao.getItemById('item-X'))!.stock, equals(88.0));
      expect((await itemDao.getItemById('item-Y'))!.stock, equals(47.0));
    });

    test('3. Multi-Depth Location Hierarchy (Root -> Sector -> Road -> Building)', () async {
      final now = DateTime.now();

      // Insert Society (Depth 1) under Area A
      await locationDao.insertLocation(
        Location(
          id: 'loc-sec-1',
          parentLocationId: 'area-A',
          name: 'Green Society',
          locationKind: LocationKind.society,
          sequenceKey: 'a.2',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Insert Road (Depth 2) under Sector 1
      await locationDao.insertLocation(
        Location(
          id: 'loc-road-2',
          parentLocationId: 'loc-sec-1',
          name: 'Lane 4',
          locationKind: LocationKind.road,
          sequenceKey: 'a.2.1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Insert Building (Depth 3) under Lane 4
      await locationDao.insertLocation(
        Location(
          id: 'loc-bldg-3',
          parentLocationId: 'loc-road-2',
          name: 'Sunshine Apartments',
          locationKind: LocationKind.building,
          sequenceKey: 'a.2.1.1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Add customer at Depth 3 (Sunshine Apartments)
      final db = await DatabaseHelper.instance.database;
      await db.insert('customers', {
        'id': 'cust-depth-3',
        'street_id': 'loc-bldg-3',
        'location_id': 'loc-bldg-3',
        'name': 'Deep Customer (Sunshine Apts)',
        'phone1': '9800000099',
        'outstanding_balance': 0.0,
        'is_vip': 0,
        'is_archived': 0,
        'customer_since': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Customer at Depth 3 orders 10 kg Item X
      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-DEPTH-3',
          customerId: 'cust-depth-3',
          subtotal: 1000.0,
          grandTotal: 1000.0,
          paidAmount: 1000.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-d-1',
            orderId: 'ORD-DEPTH-3',
            itemId: 'item-X',
            itemName: 'Item X',
            itemUnit: 'kg',
            quantity: 10.0,
            unitPrice: 100.0,
            totalPrice: 1000.0,
          ),
        ],
      );

      // Root Area A customer count must include this depth-3 customer (Anil + Amit + Deep = 3 customers)
      final areaA = await areaDao.getAreaById('area-A');
      expect(areaA!.customerCount, equals(3));
      expect(areaA.orderCount, equals(1));
      expect(areaA.totalRevenue, equals(1000.0));
    });

    test('4. Customer Relocation: Moving Customer from Area A to Area B adjusts statistics accurately', () async {
      // Customer A1 moves to Area B (street-B1)
      final custA1 = await customerDao.getCustomerById('cust-A1');
      await customerDao.updateCustomer(
        custA1!.copyWith(
          streetId: 'street-B1',
        ),
      );

      // Also update locations/customers table if needed
      final db = await DatabaseHelper.instance.database;
      await db.update('customers', {'location_id': 'street-B1'}, where: 'id = ?', whereArgs: ['cust-A1']);

      // Verify Area A customer count decremented (now 1: cust-A2)
      final areaA = await areaDao.getAreaById('area-A');
      expect(areaA!.customerCount, equals(1));

      // Verify Area B customer count incremented (now 2: cust-B1 + cust-A1)
      final areaB = await areaDao.getAreaById('area-B');
      expect(areaB!.customerCount, equals(2));
    });

    test('5. Fractional Unit Conversions: Ordering in gm / ml / pieces against kg / l / dozen inventory', () async {
      final now = DateTime.now();

      // 1. Order 500 gm Basmati Rice (inventory is kg) -> 0.5 kg deducted
      // 2. Order 250 ml Sunflower Oil (inventory is l) -> 0.25 L deducted
      // 3. Order 6 pieces Eggs (inventory is dozen) -> 0.5 dozen deducted
      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-FRAC-ADV',
          customerId: 'cust-A1',
          subtotal: 50.0 + 40.0 + 42.0,
          grandTotal: 132.0,
          paidAmount: 132.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-f-1',
            orderId: 'ORD-FRAC-ADV',
            itemId: 'item-X',
            itemName: 'Item X (Basmati Rice)',
            itemUnit: 'gm',
            quantity: 500.0,
            unitPrice: 0.10,
            totalPrice: 50.0,
          ),
          OrderItem(
            id: 'oi-f-2',
            orderId: 'ORD-FRAC-ADV',
            itemId: 'item-Y',
            itemName: 'Item Y (Sunflower Oil)',
            itemUnit: 'ml',
            quantity: 250.0,
            unitPrice: 0.16,
            totalPrice: 40.0,
          ),
          OrderItem(
            id: 'oi-f-3',
            orderId: 'ORD-FRAC-ADV',
            itemId: 'item-Z',
            itemName: 'Item Z (Farm Eggs)',
            itemUnit: 'piece',
            quantity: 6.0,
            unitPrice: 7.0,
            totalPrice: 42.0,
          ),
        ],
      );

      // Verify stock deductions
      expect((await itemDao.getItemById('item-X'))!.stock, equals(99.5)); // 100 - 0.5
      expect((await itemDao.getItemById('item-Y'))!.stock, equals(49.75)); // 50 - 0.25
      expect((await itemDao.getItemById('item-Z'))!.stock, equals(19.5)); // 20 - 0.5
    });

    test('6. Cartesian Product Prevention: Multi-item + Multi-payment order does NOT multiply sums', () async {
      final now = DateTime.now();
      const orderId = 'ORD-CARTESIAN-TEST';

      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-A1',
          subtotal: 600.0,
          grandTotal: 600.0,
          paidAmount: 600.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-cp-1',
            orderId: orderId,
            itemId: 'item-X',
            itemName: 'Item X',
            itemUnit: 'kg',
            quantity: 2.0,
            unitPrice: 100.0,
            totalPrice: 200.0,
          ),
          OrderItem(
            id: 'oi-cp-2',
            orderId: orderId,
            itemId: 'item-Y',
            itemName: 'Item Y',
            itemUnit: 'l',
            quantity: 2.5,
            unitPrice: 160.0,
            totalPrice: 400.0,
          ),
        ],
      );

      // Add 3 separate split payments
      await orderRepo.addPayment(Payment(
        id: 'pay-split-1',
        orderId: orderId,
        customerId: 'cust-A1',
        amount: 200.0,
        method: 'cash',
        createdAt: now,
      ));
      await orderRepo.addPayment(Payment(
        id: 'pay-split-2',
        orderId: orderId,
        customerId: 'cust-A1',
        amount: 200.0,
        method: 'upi',
        createdAt: now,
      ));
      await orderRepo.addPayment(Payment(
        id: 'pay-split-3',
        orderId: orderId,
        customerId: 'cust-A1',
        amount: 200.0,
        method: 'card',
        createdAt: now,
      ));

      // Area A stats must report EXACTLY 1 order and EXACTLY ₹600.00 revenue
      final areaA = await areaDao.getAreaById('area-A');
      expect(areaA!.orderCount, equals(1));
      expect(areaA.totalRevenue, equals(600.0));

      final areaPerf = (await analyticsDao.getAreaPerformance()).firstWhere((p) => p['area_id'] == 'area-A');
      expect(areaPerf['total_orders'], equals(1));
      expect(areaPerf['total_sales'], equals(600.0));
      expect(areaPerf['total_collection'], equals(600.0));
      expect(areaPerf['total_outstanding'], equals(0.0));
    });
  });
}
