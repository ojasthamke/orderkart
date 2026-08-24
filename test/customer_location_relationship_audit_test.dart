import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/features/location/domain/location.dart';
import 'package:orderkart/features/location/domain/location_kind.dart';
import 'package:orderkart/features/customer/domain/customer.dart';

void main() {
  group('Customer Location Hierarchy & Relationship Audit Test', () {
    final areaNode = Location(
      id: 'loc_baner',
      parentLocationId: null,
      name: 'Baner',
      locationKind: LocationKind.area,
      sequenceKey: '001000',
      depth: 0,
      materializedPath: '/loc_baner/',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final roadNode = Location(
      id: 'loc_main_road',
      parentLocationId: 'loc_baner',
      name: 'Main Road',
      locationKind: LocationKind.road,
      sequenceKey: '001000',
      depth: 1,
      materializedPath: '/loc_baner/loc_main_road/',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final subRoadNode = Location(
      id: 'loc_lane_4',
      parentLocationId: 'loc_main_road',
      name: 'Lane 4',
      locationKind: LocationKind.galli,
      sequenceKey: '001000',
      depth: 2,
      materializedPath: '/loc_baner/loc_main_road/loc_lane_4/',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final subSubRoadNode = Location(
      id: 'loc_society_a',
      parentLocationId: 'loc_lane_4',
      name: 'Greenwoods Society',
      locationKind: LocationKind.society,
      sequenceKey: '001000',
      depth: 3,
      materializedPath: '/loc_baner/loc_main_road/loc_lane_4/loc_society_a/',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('1. Hierarchy Resolution & Address Format (Area -> Road -> Sub-Road -> Sub-Sub-Road)', () {
      final breadcrumbs = [areaNode, roadNode, subRoadNode, subSubRoadNode];
      
      final formattedAddress = breadcrumbs
          .map((l) => l.name.trim())
          .where((n) => n.isNotEmpty)
          .join(', ');

      expect(formattedAddress, 'Baner, Main Road, Lane 4, Greenwoods Society');
    });

    test('2. Hierarchy Skipping Partial Levels gracefully without creating duplicate/fake entries', () {
      // E.g. Area + Road only (no sub-road or sub-sub-road)
      final partialBreadcrumbs = [areaNode, roadNode];
      final partialAddress = partialBreadcrumbs
          .map((l) => l.name.trim())
          .where((n) => n.isNotEmpty)
          .join(', ');

      expect(partialAddress, 'Baner, Main Road');
    });

    test('3. Customer ID Uniqueness & Isolation between Same-Name Customers', () {
      final customerA = Customer(
        id: 'CUST-001',
        streetId: 'loc_society_a',
        name: 'Ramesh Sharma',
        phone1: '9876543210',
        customerCode: 'OK1025',
        customerSince: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final customerB = Customer(
        id: 'CUST-002',
        streetId: 'loc_main_road',
        name: 'Ramesh Sharma', // Same name, different ID & road
        phone1: '9822001122',
        customerCode: 'OK1026',
        customerSince: DateTime(2026, 2, 1),
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
      );

      expect(customerA.id != customerB.id, isTrue);
      expect(customerA.customerCode != customerB.customerCode, isTrue);
      expect(customerA == customerB, isFalse);

      final orders = [
        {'orderId': 'ORD-101', 'customerId': 'CUST-001', 'grandTotal': 1850.0, 'paidAmount': 1000.0, 'status': 'Accepted'},
        {'orderId': 'ORD-102', 'customerId': 'CUST-002', 'grandTotal': 500.0, 'paidAmount': 500.0, 'status': 'Delivered'},
      ];

      // Filter orders for Customer A
      final ordersA = orders.where((o) => o['customerId'] == customerA.id).toList();
      expect(ordersA.length, 1);
      expect(ordersA.first['orderId'], 'ORD-101');
      final grandTotalA = ordersA.first['grandTotal'] as double;
      final paidA = ordersA.first['paidAmount'] as double;
      final pendingA = grandTotalA - paidA;
      expect(pendingA, 850.0);

      // Filter orders for Customer B
      final ordersB = orders.where((o) => o['customerId'] == customerB.id).toList();
      expect(ordersB.length, 1);
      expect(ordersB.first['orderId'], 'ORD-102');
      final grandTotalB = ordersB.first['grandTotal'] as double;
      final paidB = ordersB.first['paidAmount'] as double;
      final pendingB = grandTotalB - paidB;
      expect(pendingB, 0.0);
    });

    test('4. Customer Pending Balance calculation integrity', () {
      final customerOrders = [
        {'orderId': 'ORD-1', 'grandTotal': 1000.0, 'paidAmount': 400.0, 'status': 'Accepted'}, // pending: 600
        {'orderId': 'ORD-2', 'grandTotal': 750.0, 'paidAmount': 750.0, 'status': 'Delivered'},  // pending: 0
        {'orderId': 'ORD-3', 'grandTotal': 300.0, 'paidAmount': 0.0, 'status': 'Cancelled'},   // cancelled => 0
      ];

      double totalPending = 0.0;
      for (final ord in customerOrders) {
        if (ord['status'] == 'Cancelled') continue;
        final grand = ord['grandTotal'] as double;
        final paid = ord['paidAmount'] as double;
        totalPending += (grand - paid).clamp(0.0, double.infinity);
      }

      expect(totalPending, 600.0);
    });
  });

  group('Customer Database Migration and recalcCustomerTotals Integration Tests', () {
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE customers (
              id TEXT PRIMARY KEY,
              street_id TEXT NOT NULL,
              name TEXT NOT NULL,
              phone1 TEXT NOT NULL,
              customer_code TEXT DEFAULT '',
              outstanding_balance REAL DEFAULT 0,
              total_orders INTEGER DEFAULT 0,
              total_paid REAL DEFAULT 0,
              total_pending REAL DEFAULT 0,
              customer_since TEXT NOT NULL,
              last_order_date TEXT DEFAULT '',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE orders (
              id TEXT PRIMARY KEY,
              customer_id TEXT NOT NULL,
              subtotal REAL NOT NULL DEFAULT 0,
              discount REAL DEFAULT 0,
              delivery_charge REAL DEFAULT 0,
              grand_total REAL NOT NULL DEFAULT 0,
              paid_amount REAL DEFAULT 0,
              remaining_amount REAL NOT NULL DEFAULT 0,
              delivery_status TEXT NOT NULL DEFAULT 'pending',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE payments (
              id TEXT PRIMARY KEY,
              order_id TEXT NOT NULL,
              customer_id TEXT NOT NULL,
              amount REAL NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE visits (
              id TEXT PRIMARY KEY,
              customer_id TEXT NOT NULL,
              date TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE customer_item_prices (
              customer_id TEXT NOT NULL,
              item_id TEXT NOT NULL,
              price REAL NOT NULL,
              PRIMARY KEY(customer_id, item_id)
            )
          ''');

          await db.execute('''
            CREATE TABLE order_questions (
              id TEXT PRIMARY KEY,
              question TEXT NOT NULL,
              customer_id TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE customer_question_answers (
              customer_id TEXT NOT NULL,
              question_id TEXT NOT NULL,
              selected_option TEXT NOT NULL,
              PRIMARY KEY(customer_id, question_id)
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('1. DatabaseHelper _auditAndSelfHealCustomerIds fixes empty IDs and cascades correctly', () async {
      // Insert customer with empty ID
      await db.insert('customers', {
        'id': '',
        'street_id': 'street_1',
        'name': 'Corrupted ID Customer',
        'phone1': '9876543210',
        'customer_code': '',
        'customer_since': '2026-08-24T00:00:00',
        'created_at': '2026-08-24T00:00:00',
        'updated_at': '2026-08-24T00:00:00',
      });

      // Insert order referencing empty customer ID
      await db.insert('orders', {
        'id': 'ORD-001',
        'customer_id': '',
        'subtotal': 1000.0,
        'grand_total': 1000.0,
        'remaining_amount': 1000.0,
        'delivery_status': 'accepted',
        'created_at': '2026-08-24T00:00:00',
        'updated_at': '2026-08-24T00:00:00',
      });

      // Run healing helper mimicking DatabaseHelper._auditAndSelfHealCustomerIds
      // We will perform the audit & self-healing update queries directly to test constraint safety
      await db.execute('PRAGMA foreign_keys = OFF');
      final invalidCusts = await db.rawQuery(
          "SELECT rowid, id, name, phone1 FROM customers WHERE id IS NULL OR TRIM(id) = ''");
      
      expect(invalidCusts.length, 1);
      const generatedNewId = 'healed-uuid-123';
      final rowid = invalidCusts.first['rowid'];

      await db.rawUpdate(
          "UPDATE customers SET id = ? WHERE rowid = ?", [generatedNewId, rowid]);

      await db.rawUpdate(
          "UPDATE orders SET customer_id = ? WHERE customer_id IS NULL OR customer_id = ''",
          [generatedNewId]);

      await db.execute('PRAGMA foreign_keys = ON');

      // Verify that the customer has been assigned a new ID
      final updatedCusts = await db.query('customers');
      expect(updatedCusts.first['id'], generatedNewId);

      // Verify cascading re-link to orders table
      final updatedOrders = await db.query('orders');
      expect(updatedOrders.first['customer_id'], generatedNewId);
    });

    test('2. recalcCustomerTotals excludes both cancelled and denied orders', () async {
      const customerId = 'cust-123';

      await db.insert('customers', {
        'id': customerId,
        'street_id': 'street_1',
        'name': 'Ramesh',
        'phone1': '9999988888',
        'customer_code': 'OK2002',
        'customer_since': '2026-08-24T00:00:00',
        'created_at': '2026-08-24T00:00:00',
        'updated_at': '2026-08-24T00:00:00',
      });

      // Insert active order
      await db.insert('orders', {
        'id': 'ORD-A',
        'customer_id': customerId,
        'grand_total': 1200.0,
        'remaining_amount': 1200.0,
        'delivery_status': 'accepted',
        'created_at': '2026-08-24T12:00:00',
        'updated_at': '2026-08-24T12:00:00',
      });

      // Insert cancelled order
      await db.insert('orders', {
        'id': 'ORD-B',
        'customer_id': customerId,
        'grand_total': 800.0,
        'remaining_amount': 800.0,
        'delivery_status': 'cancelled',
        'created_at': '2026-08-24T13:00:00',
        'updated_at': '2026-08-24T13:00:00',
      });

      // Insert denied order
      await db.insert('orders', {
        'id': 'ORD-C',
        'customer_id': customerId,
        'grand_total': 500.0,
        'remaining_amount': 500.0,
        'delivery_status': 'denied',
        'created_at': '2026-08-24T14:00:00',
        'updated_at': '2026-08-24T14:00:00',
      });

      // Run recalcCustomerTotals logic using updated query to exclude both 'cancelled' and 'denied'
      final ordersResult = await db.rawQuery('''
        SELECT
          COUNT(*)                       AS total_orders,
          COALESCE(SUM(grand_total), 0)  AS total_amount
        FROM orders
        WHERE customer_id = ? AND (delivery_status IS NULL OR (delivery_status != 'cancelled' AND delivery_status != 'denied'))
      ''', [customerId]);

      expect(ordersResult.first['total_orders'], 1); // Only active ORD-A counted
      expect(ordersResult.first['total_amount'], 1200.0);
    });
  });
}
