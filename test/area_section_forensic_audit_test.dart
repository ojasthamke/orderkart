import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/area/data/area_dao.dart';
import 'package:orderkart/features/analytics/data/analytics_dao.dart';
import 'package:orderkart/features/order/data/order_dao.dart';
import 'package:orderkart/features/order/data/order_repository_impl.dart';
import 'package:orderkart/features/order/domain/order.dart';
import 'package:orderkart/features/order/domain/order_item.dart';
import 'package:orderkart/features/customer/data/customer_dao.dart';
import 'package:orderkart/features/inventory/data/item_dao.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Area Section Forensic Audit — Stock Items & Ordered Statistics', () {
    final areaDao = AreaDao();
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

      // Seed 2 Areas: Area A (Shivaji Nagar) & Area B (Kothrud)
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

      // Seed Streets for Area A & Area B
      await db.insert('streets', {
        'id': 'street-A1',
        'area_id': 'area-A',
        'name': 'Station Road A1',
        'created_at': now.toIso8601String(),
      });
      await db.insert('locations', {
        'id': 'street-A1',
        'parent_location_id': 'area-A',
        'name': 'Station Road A1',
        'location_kind': 'road',
        'sequence_key': 'a.1',
        'depth': 1,
        'materialized_path': '/area-A/street-A1/',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

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

      // Seed Customers: Cust 1 in Area A, Cust 2 in Area B
      await db.insert('customers', {
        'id': 'cust-1-A',
        'street_id': 'street-A1',
        'location_id': 'street-A1',
        'name': 'Customer 1 (Area A)',
        'phone1': '9822011111',
        'outstanding_balance': 0.0,
        'is_vip': 0,
        'is_archived': 0,
        'customer_since': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('customers', {
        'id': 'cust-2-B',
        'street_id': 'street-B1',
        'location_id': 'street-B1',
        'name': 'Customer 2 (Area B)',
        'phone1': '9822022222',
        'outstanding_balance': 0.0,
        'is_vip': 0,
        'is_archived': 0,
        'customer_since': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Seed Items with initial stock = 100
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
    });

    test('1. Baseline: 0 orders for Area A -> customer count = 1, order count = 0, revenue = 0', () async {
      final areaA = await areaDao.getAreaById('area-A');
      expect(areaA, isNotNull);
      expect(areaA!.customerCount, equals(1));
      expect(areaA.orderCount, equals(0));
      expect(areaA.totalRevenue, equals(0.0));
      expect(areaA.streetCount, equals(1));
    });

    test('2. Critical Accuracy Test: Area A -> Cust 1 -> Item X (Qty = 5) -> updates accurately to 8 -> restores on delete', () async {
      final now = DateTime.now();
      const orderId = 'ORD-AREA-CRITICAL';

      // 1. Create order for Customer 1 (Area A) with Quantity = 5 of Item X
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-1-A',
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
            id: 'oi-crit-1',
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

      // Verify Area A ordered quantity for Item X = 5
      final db = await DatabaseHelper.instance.database;
      final areaAItemsOrdered = await db.rawQuery('''
        SELECT SUM(oi.quantity) as total_qty, COUNT(DISTINCT o.id) as order_count, SUM(o.grand_total) as total_sales
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        JOIN customers c ON o.customer_id = c.id
        LEFT JOIN locations st ON (c.location_id = st.id OR c.street_id = st.id)
        WHERE (c.location_id = 'area-A' OR c.street_id = 'area-A' OR st.id = 'area-A' OR st.parent_location_id = 'area-A' OR st.materialized_path LIKE '%/area-A/%')
          AND oi.item_id = 'item-X'
          AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      ''');

      expect(areaAItemsOrdered.first['total_qty'], equals(5.0));
      expect(areaAItemsOrdered.first['order_count'], equals(1));
      expect(areaAItemsOrdered.first['total_sales'], equals(500.0));

      // Verify Inventory Stock for Item X = 95.0 (100 - 5)
      expect((await itemDao.getItemById('item-X'))!.stock, equals(95.0));

      // 2. Edit order: Quantity 5 -> 8
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-1-A',
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
            id: 'oi-crit-1',
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

      // Verify Area A ordered quantity for Item X is EXACTLY 8.0 (NOT 13.0!)
      final areaAItemsEdited = await db.rawQuery('''
        SELECT SUM(oi.quantity) as total_qty, COUNT(DISTINCT o.id) as order_count, SUM(o.grand_total) as total_sales
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        JOIN customers c ON o.customer_id = c.id
        LEFT JOIN locations st ON (c.location_id = st.id OR c.street_id = st.id)
        WHERE (c.location_id = 'area-A' OR c.street_id = 'area-A' OR st.id = 'area-A' OR st.parent_location_id = 'area-A' OR st.materialized_path LIKE '%/area-A/%')
          AND oi.item_id = 'item-X'
          AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      ''');

      expect(areaAItemsEdited.first['total_qty'], equals(8.0));
      expect(areaAItemsEdited.first['order_count'], equals(1));
      expect(areaAItemsEdited.first['total_sales'], equals(800.0));

      // Verify Inventory Stock for Item X = 92.0 (100 - 8)
      expect((await itemDao.getItemById('item-X'))!.stock, equals(92.0));

      // 3. Delete order
      await orderRepo.deleteOrder(orderId);

      // Verify Area A ordered quantity returns to 0 / null
      final areaAItemsDeleted = await db.rawQuery('''
        SELECT SUM(oi.quantity) as total_qty, COUNT(DISTINCT o.id) as order_count, SUM(o.grand_total) as total_sales
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        JOIN customers c ON o.customer_id = c.id
        LEFT JOIN locations st ON (c.location_id = st.id OR c.street_id = st.id)
        WHERE (c.location_id = 'area-A' OR c.street_id = 'area-A' OR st.id = 'area-A' OR st.parent_location_id = 'area-A' OR st.materialized_path LIKE '%/area-A/%')
          AND oi.item_id = 'item-X'
          AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      ''');

      expect(areaAItemsDeleted.first['total_qty'], isNull);
      expect(areaAItemsDeleted.first['order_count'], equals(0));

      // Verify Inventory Stock for Item X is fully restored to 100.0
      expect((await itemDao.getItemById('item-X'))!.stock, equals(100.0));
    });

    test('3. Multi-Area Isolation: Orders in Area A do NOT bleed into Area B', () async {
      final now = DateTime.now();

      // Order in Area A: 2 kg Item X (₹200)
      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-A-1',
          customerId: 'cust-1-A',
          subtotal: 200.0,
          grandTotal: 200.0,
          paidAmount: 200.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-a-1',
            orderId: 'ORD-A-1',
            itemId: 'item-X',
            itemName: 'Item X (Basmati Rice)',
            itemUnit: 'kg',
            quantity: 2.0,
            unitPrice: 100.0,
            totalPrice: 200.0,
          )
        ],
      );

      // Order in Area B: 3 L Item Y (₹480)
      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-B-1',
          customerId: 'cust-2-B',
          subtotal: 480.0,
          grandTotal: 480.0,
          paidAmount: 480.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-b-1',
            orderId: 'ORD-B-1',
            itemId: 'item-Y',
            itemName: 'Item Y (Sunflower Oil)',
            itemUnit: 'l',
            quantity: 3.0,
            unitPrice: 160.0,
            totalPrice: 480.0,
          )
        ],
      );

      final performance = await analyticsDao.getAreaPerformance();
      final areaAPerf = performance.firstWhere((p) => p['area_id'] == 'area-A');
      final areaBPerf = performance.firstWhere((p) => p['area_id'] == 'area-B');

      expect(areaAPerf['total_orders'], equals(1));
      expect(areaAPerf['total_sales'], equals(200.0));

      expect(areaBPerf['total_orders'], equals(1));
      expect(areaBPerf['total_sales'], equals(480.0));
    });

    test('4. Stock Integrity vs Ordered Statistics: Clear distinction between Inventory Stock and Area Ordered Quantity', () async {
      final now = DateTime.now();

      // Initial Inventory Stock: Item X = 100 kg
      expect((await itemDao.getItemById('item-X'))!.stock, equals(100.0));

      // Area A customer orders 10 kg of Item X
      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-STOCK-TEST',
          customerId: 'cust-1-A',
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
            id: 'oi-st-1',
            orderId: 'ORD-STOCK-TEST',
            itemId: 'item-X',
            itemName: 'Item X (Basmati Rice)',
            itemUnit: 'kg',
            quantity: 10.0,
            unitPrice: 100.0,
            totalPrice: 1000.0,
          )
        ],
      );

      // 1. Current Remaining Inventory Stock = 90.0 kg
      final currentRemainingStock = (await itemDao.getItemById('item-X'))!.stock;
      expect(currentRemainingStock, equals(90.0));

      // 2. Area A Ordered Quantity = 10.0 kg
      final db = await DatabaseHelper.instance.database;
      final areaOrderedRes = await db.rawQuery('''
        SELECT SUM(oi.quantity) as ordered_qty
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        JOIN customers c ON o.customer_id = c.id
        LEFT JOIN locations st ON (c.location_id = st.id OR c.street_id = st.id)
        WHERE (c.location_id = 'area-A' OR c.street_id = 'area-A' OR st.id = 'area-A' OR st.parent_location_id = 'area-A' OR st.materialized_path LIKE '%/area-A/%')
          AND oi.item_id = 'item-X'
          AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      ''');
      final orderedQty = (areaOrderedRes.first['ordered_qty'] as num?)?.toDouble() ?? 0.0;
      expect(orderedQty, equals(10.0));

      // 3. Confirm these are distinct metrics: Ordered Qty (10) != Remaining Stock (90)
      expect(orderedQty, isNot(equals(currentRemainingStock)));
      expect(orderedQty + currentRemainingStock, equals(100.0));
    });

    test('5. Cancelled Orders in Area: Stock is restored and cancelled sales do NOT inflate active area sales', () async {
      final now = DateTime.now();
      const orderId = 'ORD-CANCEL-AREA';

      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-1-A',
          subtotal: 600.0,
          grandTotal: 600.0,
          paidAmount: 600.0,
          remainingAmount: 0.0,
          deliveryStatus: 'pending',
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-can-1',
            orderId: orderId,
            itemId: 'item-X',
            itemName: 'Item X (Basmati Rice)',
            itemUnit: 'kg',
            quantity: 6.0,
            unitPrice: 100.0,
            totalPrice: 600.0,
          )
        ],
      );

      // Verify stock was deducted (100 - 6 = 94)
      expect((await itemDao.getItemById('item-X'))!.stock, equals(94.0));

      // Cancel the order
      await orderRepo.updateDeliveryStatus(orderId, 'cancelled');

      // Verify stock is restored to 100
      expect((await itemDao.getItemById('item-X'))!.stock, equals(100.0));

      // Verify Area Performance excludes cancelled order
      final performance = await analyticsDao.getAreaPerformance();
      final areaAPerf = performance.firstWhere((p) => p['area_id'] == 'area-A');
      expect(areaAPerf['total_sales'], equals(0.0));
      expect(areaAPerf['total_orders'], equals(0));
    });

    test('6. Multiple Customers and Multiple Items in Area A: Aggregation of line items and sales', () async {
      final now = DateTime.now();
      final db = await DatabaseHelper.instance.database;

      // Add a 2nd customer in Area A on street-A1
      await db.insert('customers', {
        'id': 'cust-3-A',
        'street_id': 'street-A1',
        'location_id': 'street-A1',
        'name': 'Customer 3 (Area A)',
        'phone1': '9822033333',
        'outstanding_balance': 0.0,
        'is_vip': 0,
        'is_archived': 0,
        'customer_since': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Customer 1 Order: 4 kg Item X (₹400) + 2 L Item Y (₹320) = ₹720
      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-MULTI-1',
          customerId: 'cust-1-A',
          subtotal: 720.0,
          grandTotal: 720.0,
          paidAmount: 720.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-m1-1',
            orderId: 'ORD-MULTI-1',
            itemId: 'item-X',
            itemName: 'Item X (Basmati Rice)',
            itemUnit: 'kg',
            quantity: 4.0,
            unitPrice: 100.0,
            totalPrice: 400.0,
          ),
          OrderItem(
            id: 'oi-m1-2',
            orderId: 'ORD-MULTI-1',
            itemId: 'item-Y',
            itemName: 'Item Y (Sunflower Oil)',
            itemUnit: 'l',
            quantity: 2.0,
            unitPrice: 160.0,
            totalPrice: 320.0,
          ),
        ],
      );

      // Customer 3 Order: 6 kg Item X (₹600) = ₹600
      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-MULTI-2',
          customerId: 'cust-3-A',
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
            id: 'oi-m2-1',
            orderId: 'ORD-MULTI-2',
            itemId: 'item-X',
            itemName: 'Item X (Basmati Rice)',
            itemUnit: 'kg',
            quantity: 6.0,
            unitPrice: 100.0,
            totalPrice: 600.0,
          ),
        ],
      );

      // Verify Area A Total Customers = 2
      final areaA = await areaDao.getAreaById('area-A');
      expect(areaA!.customerCount, equals(2));
      expect(areaA.orderCount, equals(2));
      expect(areaA.totalRevenue, equals(1320.0));

      // Verify Total Item X ordered in Area A = 4 + 6 = 10 kg
      final itemXOrdered = await db.rawQuery('''
        SELECT SUM(oi.quantity) as total_qty
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        JOIN customers c ON o.customer_id = c.id
        LEFT JOIN locations st ON (c.location_id = st.id OR c.street_id = st.id)
        WHERE (c.location_id = 'area-A' OR c.street_id = 'area-A' OR st.id = 'area-A' OR st.parent_location_id = 'area-A' OR st.materialized_path LIKE '%/area-A/%')
          AND oi.item_id = 'item-X'
          AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      ''');
      expect((itemXOrdered.first['total_qty'] as num).toDouble(), equals(10.0));

      // Verify Total Item Y ordered in Area A = 2 L
      final itemYOrdered = await db.rawQuery('''
        SELECT SUM(oi.quantity) as total_qty
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        JOIN customers c ON o.customer_id = c.id
        LEFT JOIN locations st ON (c.location_id = st.id OR c.street_id = st.id)
        WHERE (c.location_id = 'area-A' OR c.street_id = 'area-A' OR st.id = 'area-A' OR st.parent_location_id = 'area-A' OR st.materialized_path LIKE '%/area-A/%')
          AND oi.item_id = 'item-Y'
          AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      ''');
      expect((itemYOrdered.first['total_qty'] as num).toDouble(), equals(2.0));
    });

    test('7. Area Search and Sorting: By Name, Date, Streets, and Customers', () async {
      // 1. Search by name "Shivaji" -> Area A
      final searchResult = await areaDao.getAllAreas(searchQuery: 'Shivaji');
      expect(searchResult.length, equals(1));
      expect(searchResult.first.id, equals('area-A'));

      // 2. Sort by Name ASC
      final sortByName = await areaDao.getAllAreas(sortBy: 'name');
      expect(sortByName.first.id, equals('area-A'));
      expect(sortByName.last.id, equals('area-B'));

      // 3. Sort by Customers DESC (Area A has 1, Area B has 1)
      final sortByCust = await areaDao.getAllAreas(sortBy: 'customer_count');
      expect(sortByCust.length, equals(2));
    });

    test('8. Area Deletion: Unassigns customers and cascades location hierarchy cleanly', () async {
      // Delete Area B
      await areaDao.deleteArea('area-B');

      // Verify Area B is deleted
      final areaB = await areaDao.getAreaById('area-B');
      expect(areaB, isNull);

      // Verify customer 2 unassigned or location reset
      final cust2 = await customerDao.getCustomerById('cust-2-B');
      expect(cust2, isNotNull);
      expect(cust2!.streetId, equals('unassigned'));
    });
  });
}
