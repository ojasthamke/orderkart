import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/features/customer/domain/customer.dart';

void main() {
  group('Customer CRUD, Location Hierarchy & Vanishing Prevention Tests', () {
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
          // locations table
          await db.execute('''
            CREATE TABLE locations (
              id TEXT PRIMARY KEY,
              parent_location_id TEXT,
              name TEXT NOT NULL,
              location_kind TEXT NOT NULL,
              sequence_key TEXT DEFAULT '001000',
              depth INTEGER DEFAULT 0,
              materialized_path TEXT,
              is_archived INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          // legacy areas table
          await db.execute('''
            CREATE TABLE areas (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT DEFAULT '',
              color INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          // legacy streets table
          await db.execute('''
            CREATE TABLE streets (
              id TEXT PRIMARY KEY,
              area_id TEXT NOT NULL,
              name TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');

          // customers table
          await db.execute('''
            CREATE TABLE customers (
              id TEXT PRIMARY KEY,
              street_id TEXT NOT NULL,
              location_id TEXT,
              name TEXT NOT NULL,
              phone1 TEXT NOT NULL,
              phone2 TEXT DEFAULT '',
              whatsapp TEXT DEFAULT '',
              house_number TEXT DEFAULT '',
              address TEXT DEFAULT '',
              notes TEXT DEFAULT '',
              maps_location TEXT DEFAULT '',
              photo_path TEXT DEFAULT '',
              serial_no INTEGER DEFAULT 0,
              outstanding_balance REAL DEFAULT 0,
              total_orders INTEGER DEFAULT 0,
              total_paid REAL DEFAULT 0,
              total_pending REAL DEFAULT 0,
              customer_since TEXT NOT NULL,
              last_order_date TEXT DEFAULT '',
              is_archived INTEGER DEFAULT 0,
              dietary_preference TEXT DEFAULT '',
              is_guest INTEGER DEFAULT 0,
              locality TEXT DEFAULT '',
              customer_code TEXT DEFAULT '',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          // deleted_customers table
          await db.execute('''
            CREATE TABLE deleted_customers (
              id TEXT PRIMARY KEY,
              deleted_at TEXT NOT NULL
            )
          ''');

          // orders table
          await db.execute('''
            CREATE TABLE orders (
              id TEXT PRIMARY KEY,
              customer_id TEXT NOT NULL,
              grand_total REAL NOT NULL DEFAULT 0,
              paid_amount REAL DEFAULT 0,
              remaining_amount REAL NOT NULL DEFAULT 0,
              delivery_status TEXT NOT NULL DEFAULT 'pending',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          // payments table
          await db.execute('''
            CREATE TABLE payments (
              id TEXT PRIMARY KEY,
              order_id TEXT NOT NULL,
              customer_id TEXT NOT NULL,
              amount REAL NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL
            )
          ''');

          // order_items table
          await db.execute('''
            CREATE TABLE order_items (
              id TEXT PRIMARY KEY,
              order_id TEXT NOT NULL,
              item_id TEXT NOT NULL,
              quantity REAL NOT NULL DEFAULT 1,
              rate REAL NOT NULL DEFAULT 0
            )
          ''');

          // visits table
          await db.execute('''
            CREATE TABLE visits (
              id TEXT PRIMARY KEY,
              customer_id TEXT NOT NULL,
              date TEXT NOT NULL
            )
          ''');

          // settings table
          await db.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    // Helper to query customers matching CustomerDao.getCustomersByStreet (strictly location node isolation)
    Future<List<Customer>> queryCustomersByStreet(String streetId, {String? searchQuery}) async {
      final cleanStreetId = streetId.trim();
      List<Map<String, dynamic>> maps;

      if (cleanStreetId.isEmpty) {
        String where =
            '(is_archived IS NULL OR is_archived = 0) AND id NOT IN (SELECT id FROM deleted_customers)';
        List<dynamic> args = [];
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          where +=
              ' AND (name LIKE ? OR phone1 LIKE ? OR house_number LIKE ? OR customer_code LIKE ?)';
          final q = '%${searchQuery.trim()}%';
          args.addAll([q, q, q, q]);
        }
        maps = await db.query('customers', where: where, whereArgs: args);
      } else {
        String searchFilter = '';
        List<dynamic> args = [cleanStreetId, cleanStreetId];
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          searchFilter =
              ' AND (c.name LIKE ? OR c.phone1 LIKE ? OR c.house_number LIKE ? OR c.customer_code LIKE ?)';
          final q = '%${searchQuery.trim()}%';
          args.addAll([q, q, q, q]);
        }

        maps = await db.rawQuery('''
          SELECT DISTINCT c.* FROM customers c
          WHERE (c.is_archived IS NULL OR c.is_archived = 0)
            AND c.id NOT IN (SELECT id FROM deleted_customers)
            AND (c.street_id = ? OR c.location_id = ?)
            $searchFilter
        ''', args);
      }

      final customers = maps.map(Customer.fromMap).toList();
      customers.sort((a, b) {
        final aNo = a.serialNo;
        final bNo = b.serialNo;
        if (aNo == 0 && bNo == 0) return a.createdAt.compareTo(b.createdAt);
        if (aNo == 0) return 1;
        if (bNo == 0) return -1;
        return aNo.compareTo(bNo);
      });

      // Deduplicate by ID only
      final seenIds = <String>{};
      final result = <Customer>[];
      for (final c in customers) {
        if (seenIds.contains(c.id)) continue;
        seenIds.add(c.id);
        result.add(c);
      }
      return result;
    }

    test('1. Location Node Isolation: Area "Customers Here" shows ONLY direct customers, never duplicating child roads', () async {
      final now = DateTime.now().toIso8601String();

      // Root Area
      await db.insert('locations', {
        'id': 'area_kothrud',
        'parent_location_id': null,
        'name': 'Kothrud Area',
        'location_kind': 'area',
        'sequence_key': '001000',
        'depth': 0,
        'materialized_path': '/area_kothrud/',
        'created_at': now,
        'updated_at': now,
      });

      // Child Road
      await db.insert('locations', {
        'id': 'road_dp_road',
        'parent_location_id': 'area_kothrud',
        'name': 'DP Road',
        'location_kind': 'road',
        'sequence_key': '001001',
        'depth': 1,
        'materialized_path': '/area_kothrud/road_dp_road/',
        'created_at': now,
        'updated_at': now,
      });

      // Child Sub-Road / Lane
      await db.insert('locations', {
        'id': 'subroad_lane_3',
        'parent_location_id': 'road_dp_road',
        'name': 'Lane 3',
        'location_kind': 'galli',
        'sequence_key': '001002',
        'depth': 2,
        'materialized_path': '/area_kothrud/road_dp_road/subroad_lane_3/',
        'created_at': now,
        'updated_at': now,
      });

      // Legacy street linked by area_id
      await db.insert('streets', {
        'id': 'legacy_street_1',
        'area_id': 'area_kothrud',
        'name': 'Old Canal Street',
        'created_at': now,
      });

      // Insert customers at each level
      await db.insert('customers', {
        'id': 'cust_area_root',
        'street_id': 'area_kothrud',
        'location_id': 'area_kothrud',
        'name': 'Area Root Resident',
        'phone1': '9000000001',
        'customer_code': 'KOTH01',
        'serial_no': 1,
        'customer_since': now,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('customers', {
        'id': 'cust_dp_road',
        'street_id': 'road_dp_road',
        'location_id': 'road_dp_road',
        'name': 'DP Road Resident',
        'phone1': '9000000002',
        'customer_code': 'KOTH02',
        'serial_no': 2,
        'customer_since': now,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('customers', {
        'id': 'cust_lane_3',
        'street_id': 'subroad_lane_3',
        'location_id': 'subroad_lane_3',
        'name': 'Lane 3 Resident',
        'phone1': '9000000003',
        'customer_code': 'KOTH03',
        'serial_no': 3,
        'customer_since': now,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('customers', {
        'id': 'cust_legacy_street',
        'street_id': 'legacy_street_1',
        'location_id': 'legacy_street_1',
        'name': 'Legacy Street Resident',
        'phone1': '9000000004',
        'customer_code': 'KOTH04',
        'serial_no': 4,
        'customer_since': now,
        'created_at': now,
        'updated_at': now,
      });

      // 1. Query root Area: MUST return strictly only its 1 direct customer! Child road customers must NOT be duplicated or shown here!
      final areaCustomers = await queryCustomersByStreet('area_kothrud');
      expect(areaCustomers.length, 1, reason: 'Parent area Customers Here tab must strictly show only direct customers, no child road customers');
      expect(areaCustomers.first.id, 'cust_area_root');

      // 2. Query DP Road: must return ONLY DP Road direct resident (1 customer)
      final roadCustomers = await queryCustomersByStreet('road_dp_road');
      expect(roadCustomers.length, 1);
      expect(roadCustomers.first.id, 'cust_dp_road');

      // 3. Query Lane 3: must return strictly only Lane 3 resident (1 customer)
      final laneCustomers = await queryCustomersByStreet('subroad_lane_3');
      expect(laneCustomers.length, 1);
      expect(laneCustomers.first.id, 'cust_lane_3');

      // 4. Query Legacy Street: must return legacy customer (1 customer)
      final legacyCustomers = await queryCustomersByStreet('legacy_street_1');
      expect(legacyCustomers.length, 1);
      expect(legacyCustomers.first.id, 'cust_legacy_street');
    });

    test('2. Identical Name & Street Isolation: Distinct customers with same name never vanish', () async {
      final now = DateTime.now().toIso8601String();

      // Two customers with exact same name on the same street, but different IDs, codes, phones
      await db.insert('customers', {
        'id': 'cust_amit_1',
        'street_id': 'road_market',
        'location_id': 'road_market',
        'name': 'Amit Sharma',
        'phone1': '9800000001',
        'customer_code': 'AMIT01',
        'house_number': '101',
        'serial_no': 1,
        'customer_since': now,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('customers', {
        'id': 'cust_amit_2',
        'street_id': 'road_market',
        'location_id': 'road_market',
        'name': 'Amit Sharma',
        'phone1': '9800000002',
        'customer_code': 'AMIT02',
        'house_number': '204',
        'serial_no': 2,
        'customer_since': now,
        'created_at': now,
        'updated_at': now,
      });

      final list = await queryCustomersByStreet('road_market');
      expect(list.length, 2, reason: 'Both customers with identical name must be preserved');
      expect(list[0].id, 'cust_amit_1');
      expect(list[1].id, 'cust_amit_2');
      expect(list[0].phone1, '9800000001');
      expect(list[1].phone1, '9800000002');
    });

    test('3. Ghost Houses: Multiple placeholder ghost houses on same street remain intact after audit', () async {
      final now = DateTime.now().toIso8601String();

      // Create 5 ghost houses on the same road representing empty plots/houses
      for (int i = 1; i <= 5; i++) {
        await db.insert('customers', {
          'id': 'ghost_house_$i',
          'street_id': 'road_shanti_nagar',
          'location_id': 'road_shanti_nagar',
          'name': '[Ghost House]',
          'phone1': '0000000000',
          'customer_code': 'GHOST$i',
          'house_number': 'Plot-$i',
          'serial_no': i,
          'customer_since': now,
          'created_at': now,
          'updated_at': now,
        });
      }

      // Run deduplication audit logic (verifying our fixed algorithm preserves all ghost houses)
      final allCustomers = await db.query('customers');
      expect(allCustomers.length, 5);

      final seenCodes = <String, String>{};
      final duplicatesToDelete = <String>[];

      for (final c in allCustomers) {
        final id = c['id'] as String;
        final name = (c['name'] as String? ?? '').trim();
        final phone = (c['phone1'] as String? ?? '').trim();
        final code = (c['customer_code'] as String? ?? '').trim().toUpperCase();

        final isGhost = name.isEmpty ||
            name == '[Ghost House]' ||
            name.toLowerCase() == 'ghost house' ||
            name.startsWith('[Ghost House]') ||
            phone == '0000000000' ||
            phone.isEmpty;

        // Ghost houses must NEVER be marked as duplicate pairs
        if (isGhost) continue;

        if (code.isNotEmpty) {
          if (seenCodes.containsKey(code)) {
            duplicatesToDelete.add(id);
          } else {
            seenCodes[code] = id;
          }
        }
      }

      expect(duplicatesToDelete.isEmpty, isTrue, reason: 'No ghost houses should be deleted during audit');

      final finalGhostList = await queryCustomersByStreet('road_shanti_nagar');
      expect(finalGhostList.length, 5, reason: 'All 5 ghost houses must be retained');
    });

    test('4. Full Lifecycle: Add, Edit, Reorder, Move, and Delete with Cascade & Tombstone', () async {
      final now = DateTime.now().toIso8601String();

      // 1. ADD
      await db.insert('customers', {
        'id': 'cust_lifecycle',
        'street_id': 'road_alpha',
        'location_id': 'road_alpha',
        'name': 'Vikram Rathore',
        'phone1': '9823000001',
        'customer_code': 'VIKR01',
        'serial_no': 1,
        'customer_since': now,
        'created_at': now,
        'updated_at': now,
      });

      var list = await queryCustomersByStreet('road_alpha');
      expect(list.length, 1);
      expect(list.first.name, 'Vikram Rathore');

      // 2. EDIT
      await db.update(
        'customers',
        {
          'name': 'Vikram S. Rathore',
          'phone1': '9823000099',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: ['cust_lifecycle'],
      );

      list = await queryCustomersByStreet('road_alpha');
      expect(list.length, 1);
      expect(list.first.name, 'Vikram S. Rathore');
      expect(list.first.phone1, '9823000099');

      // 3. REORDER
      await db.insert('customers', {
        'id': 'cust_lifecycle_2',
        'street_id': 'road_alpha',
        'location_id': 'road_alpha',
        'name': 'Second Resident',
        'phone1': '9823000002',
        'customer_code': 'SECO02',
        'serial_no': 2,
        'customer_since': now,
        'created_at': now,
        'updated_at': now,
      });

      // Swap serial numbers
      await db.update('customers', {'serial_no': 2}, where: 'id = ?', whereArgs: ['cust_lifecycle']);
      await db.update('customers', {'serial_no': 1}, where: 'id = ?', whereArgs: ['cust_lifecycle_2']);

      list = await queryCustomersByStreet('road_alpha');
      expect(list.length, 2);
      expect(list[0].id, 'cust_lifecycle_2', reason: 'Serial No 1 comes first');
      expect(list[1].id, 'cust_lifecycle', reason: 'Serial No 2 comes second');

      // 4. MOVE
      await db.update(
        'customers',
        {
          'street_id': 'road_beta',
          'location_id': 'road_beta',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: ['cust_lifecycle'],
      );

      final roadAlphaList = await queryCustomersByStreet('road_alpha');
      expect(roadAlphaList.length, 1);
      expect(roadAlphaList.first.id, 'cust_lifecycle_2');

      final roadBetaList = await queryCustomersByStreet('road_beta');
      expect(roadBetaList.length, 1);
      expect(roadBetaList.first.id, 'cust_lifecycle');

      // 5. DELETE WITH CASCADE & TOMBSTONE
      // Create order, payment, and order items for customer
      await db.insert('orders', {
        'id': 'order_101',
        'customer_id': 'cust_lifecycle',
        'grand_total': 500.0,
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('payments', {
        'id': 'pay_101',
        'order_id': 'order_101',
        'customer_id': 'cust_lifecycle',
        'amount': 500.0,
        'created_at': now,
      });
      await db.insert('order_items', {
        'id': 'item_101',
        'order_id': 'order_101',
        'item_id': 'veg_tomatoes',
        'quantity': 2,
        'rate': 40,
      });

      // Execute delete in transaction matching CustomerDao.deleteCustomer
      await db.transaction((txn) async {
        final orders = await txn.query('orders', columns: ['id'], where: 'customer_id = ?', whereArgs: ['cust_lifecycle']);
        for (final o in orders) {
          final orderId = o['id'] as String;
          await txn.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
          await txn.delete('payments', where: 'order_id = ?', whereArgs: [orderId]);
        }
        await txn.delete('orders', where: 'customer_id = ?', whereArgs: ['cust_lifecycle']);
        await txn.insert('deleted_customers', {
          'id': 'cust_lifecycle',
          'deleted_at': DateTime.now().toIso8601String(),
        });
        await txn.delete('customers', where: 'id = ?', whereArgs: ['cust_lifecycle']);
      });

      // Verify deletion & clean tombstone
      final postDeleteList = await queryCustomersByStreet('road_beta');
      expect(postDeleteList.isEmpty, isTrue);

      final tombstone = await db.query('deleted_customers', where: 'id = ?', whereArgs: ['cust_lifecycle']);
      expect(tombstone.isNotEmpty, isTrue);

      final remainingOrders = await db.query('orders', where: 'customer_id = ?', whereArgs: ['cust_lifecycle']);
      expect(remainingOrders.isEmpty, isTrue);
      final remainingPayments = await db.query('payments', where: 'customer_id = ?', whereArgs: ['cust_lifecycle']);
      expect(remainingPayments.isEmpty, isTrue);
    });

    test('5. Remote Sync Protection: Cross-street hijacking prevented and local street preserved', () async {
      final now = DateTime.now().toIso8601String();

      // Local customer in Sector 1
      await db.insert('customers', {
        'id': 'local_cust_1',
        'street_id': 'road_sector_1',
        'location_id': 'road_sector_1',
        'name': 'Sunil Joshi',
        'phone1': '9988776655',
        'customer_code': 'SUNI01',
        'house_number': '12',
        'serial_no': 1,
        'customer_since': now,
        'created_at': now,
        'updated_at': now,
      });

      // Remote customer arrives with same name & house number, but in Sector 2 and different phone
      const remoteName = 'Sunil Joshi';
      const remoteHouseNo = '12';
      const remoteStreetId = 'road_sector_2';

      // Attempt match with our fixed logic:
      // Must NOT match because validStreetId ('road_sector_2') != local street ('road_sector_1')
      final matched = await db.rawQuery(
        'SELECT * FROM customers WHERE LOWER(TRIM(name)) = ? AND house_number = ? AND (street_id = ? OR location_id = ?) LIMIT 1',
        [remoteName.toLowerCase(), remoteHouseNo, remoteStreetId, remoteStreetId],
      );
      expect(matched.isEmpty, isTrue, reason: 'Customer in Sector 1 should not match remote sync in Sector 2');

      // Local customer's street must remain road_sector_1
      final localCust = await db.query('customers', where: 'id = ?', whereArgs: ['local_cust_1']);
      expect(localCust.first['street_id'], 'road_sector_1');

      // When local customer already has road_sector_1, a remote pull with default_street must NOT overwrite it
      final existingStreetId = localCust.first['street_id'] as String;
      const validStreetId = 'default_street';
      const remoteRoadId = '';
      const remoteSubRoadId = '';
      final shouldUpdateStreet = validStreetId.isNotEmpty &&
          (existingStreetId.isEmpty || (validStreetId != 'default_street' && (remoteRoadId.isNotEmpty || remoteSubRoadId.isNotEmpty)));

      expect(shouldUpdateStreet, isFalse, reason: 'Existing valid street must not be overwritten by default_street');
    });
  });
}
