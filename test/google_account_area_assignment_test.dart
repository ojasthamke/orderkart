import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/customer/data/customer_dao.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  const googleAreaId = '17aac4e9-9298-4774-927f-39e8d9369f9d';
  const googleRoadId = 'd753890a-52a4-51a0-bb10-54ee14186df9';
  const regularAreaId = 'f9b2e534-c643-5f9a-94a4-a02a5747ee57';
  const regularRoadId = 'road-bangar-1';

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath, version: 1,
        onCreate: (d, v) async {
      await DatabaseHelper.instance.createSchema(d);
      await DatabaseHelper.instance.createTablesForDatabase(d);
      await d.execute('CREATE TABLE IF NOT EXISTS deleted_customers (id TEXT PRIMARY KEY, deleted_at TEXT)');
      await d.execute('CREATE TABLE IF NOT EXISTS deleted_orders (id TEXT PRIMARY KEY, deleted_at TEXT)');
    });
    DatabaseHelper.instance.setDatabaseForTesting(db);
  });

  tearDown(() async {
    DatabaseHelper.instance.setDatabaseForTesting(null);
    await db.close();
  });

  group('Google Account Area Assignment & Isolation Tests', () {
    test('TEST 1: ensureGoogleAccountAreaExists seeds Google Account area and road', () async {
      await DatabaseHelper.ensureGoogleAccountAreaExists(db);

      final areaRows = await db.query('locations', where: 'id = ?', whereArgs: [googleAreaId]);
      expect(areaRows.isNotEmpty, isTrue);
      expect(areaRows.first['name'], equals('Google Account'));
      expect(areaRows.first['location_kind'], equals('area'));

      final roadRows = await db.query('locations', where: 'id = ?', whereArgs: [googleRoadId]);
      expect(roadRows.isNotEmpty, isTrue);
      expect(roadRows.first['name'], equals('Google Accounts'));
      expect(roadRows.first['parent_location_id'], equals(googleAreaId));
    });

    test('TEST 2: getCustomersByStreet returns Google customers under Google Account area', () async {
      await DatabaseHelper.ensureGoogleAccountAreaExists(db);

      // Insert Google customer assigned to Google Road under Google Area
      final nowStr = DateTime.now().toIso8601String();
      await db.insert('customers', {
        'id': 'google-cust-1',
        'name': 'Google User Alpha',
        'phone1': '9876543210',
        'auth_provider': 'google',
        'google_id': 'g-12345',
        'email': 'alpha@gmail.com',
        'is_new_customer': 1,
        'street_id': googleRoadId,
        'location_id': googleRoadId,
        'customer_since': nowStr,
        'created_at': nowStr,
        'updated_at': nowStr,
      });

      // Insert Regular customer assigned to Bangar Nagar
      await db.insert('locations', {
        'id': regularAreaId,
        'name': 'Bangar Nagar',
        'location_kind': 'area',
        'sequence_key': '002',
        'created_at': nowStr,
        'updated_at': nowStr,
      });
      await db.insert('locations', {
        'id': regularRoadId,
        'parent_location_id': regularAreaId,
        'name': 'Main Road',
        'location_kind': 'road',
        'sequence_key': '002.001',
        'created_at': nowStr,
        'updated_at': nowStr,
      });
      await db.insert('customers', {
        'id': 'regular-cust-1',
        'name': 'Standard Resident',
        'phone1': '9822000000',
        'auth_provider': 'phone_password',
        'street_id': regularRoadId,
        'location_id': regularRoadId,
        'customer_since': nowStr,
        'created_at': nowStr,
        'updated_at': nowStr,
      });

      // Query customers by Google Road ID
      final dao = CustomerDao();
      final googleRoadCustomers = await dao.getCustomersByStreet(googleRoadId);
      expect(googleRoadCustomers.length, equals(1));
      expect(googleRoadCustomers.first.id, equals('google-cust-1'));
      expect(googleRoadCustomers.first.name, equals('Google User Alpha'));

      // Query customers by Regular Road ID
      final regularRoadCustomers = await dao.getCustomersByStreet(regularRoadId);
      expect(regularRoadCustomers.length, equals(1));
      expect(regularRoadCustomers.first.id, equals('regular-cust-1'));
      expect(regularRoadCustomers.first.name, equals('Standard Resident'));

      // Verify node isolation: Querying parent areas directly does NOT leak child customers
      final googleAreaCustomers = await dao.getCustomersByStreet(googleAreaId);
      expect(googleAreaCustomers.isEmpty, isTrue);
      final regularAreaCustomers = await dao.getCustomersByStreet(regularAreaId);
      expect(regularAreaCustomers.isEmpty, isTrue);
    });

    test('TEST 3: Customer assigned directly to Google Area is returned when querying area', () async {
      await DatabaseHelper.ensureGoogleAccountAreaExists(db);
      final nowStr = DateTime.now().toIso8601String();

      await db.insert('customers', {
        'id': 'google-cust-direct',
        'name': 'Direct Google User',
        'phone1': '9111111111',
        'auth_provider': 'google',
        'street_id': googleAreaId,
        'location_id': googleAreaId,
        'customer_since': nowStr,
        'created_at': nowStr,
        'updated_at': nowStr,
      });

      final dao = CustomerDao();
      final list = await dao.getCustomersByStreet(googleAreaId);
      expect(list.any((c) => c.id == 'google-cust-direct'), isTrue);
    });
  });
}
