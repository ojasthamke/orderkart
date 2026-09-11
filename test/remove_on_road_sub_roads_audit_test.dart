import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/customer/data/customer_dao.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Remove On-Road & Pure Sub-Roads System Forensic Audit', () {
    late Database db;

    Future<void> seedHierarchy(Database db) async {
      final now = DateTime.now().toIso8601String();
      final areas = [
        {'id': '273d3449-753b-5e54-973e-9dd269ab0349', 'name': 'Bangar Nagar'},
        {'id': '14eb72be-dfeb-5359-83da-e74c70c312c7', 'name': 'Darda Nagar'},
        {'id': '17aac4e9-9298-4774-927f-39e8d9369f9d', 'name': 'Google Account'},
        {'id': '60530399-4de5-57ca-8cc8-db2b9268f489', 'name': 'Jamankar Nagar'},
        {'id': 'default_area', 'name': 'Online Area'},
      ];

      for (final a in areas) {
        await db.insert('locations', {
          'id': a['id'],
          'name': a['name'],
          'location_kind': 'area',
          'sequence_key': '001',
          'depth': 0,
          'materialized_path': '/${a['id']}/',
          'created_at': now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await db.insert('areas', {
          'id': a['id'],
          'name': a['name'],
          'created_at': now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final roads = [
        {'id': '95a8bb6f-6f36-58dd-a1bb-5f2ec9873628', 'areaId': '273d3449-753b-5e54-973e-9dd269ab0349', 'name': 'Area A Main Road'},
        {'id': 'fba28599-5190-599c-b9f7-78c3953b3a46', 'areaId': '273d3449-753b-5e54-973e-9dd269ab0349', 'name': 'Bangar Nagar'},
        {'id': '224a271d-87bd-522f-9e3c-c709d84f5426', 'areaId': '14eb72be-dfeb-5359-83da-e74c70c312c7', 'name': '8'},
        {'id': '771c598b-23e7-5a6c-bd4e-e090b3f189f0', 'areaId': '14eb72be-dfeb-5359-83da-e74c70c312c7', 'name': 'R5'},
        {'id': '328dd402-97f0-5e23-8e53-ef6a14d1bda0', 'areaId': '14eb72be-dfeb-5359-83da-e74c70c312c7', 'name': 'R7'},
        {'id': '52c9bf59-adc5-59f9-adc1-7dd3d5c57a39', 'areaId': '14eb72be-dfeb-5359-83da-e74c70c312c7', 'name': 'Saperate'},
        {'id': 'd753890a-52a4-51a0-bb10-54ee14186df9', 'areaId': '17aac4e9-9298-4774-927f-39e8d9369f9d', 'name': 'Google Accounts'},
        {'id': '7b10aa82-e4e3-5f34-aad2-835278ca840d', 'areaId': '60530399-4de5-57ca-8cc8-db2b9268f489', 'name': 'Hh'},
        {'id': 'default_street', 'areaId': 'default_area', 'name': 'Online Street'},
      ];

      for (final r in roads) {
        await db.insert('locations', {
          'id': r['id'],
          'parent_location_id': r['areaId'],
          'name': r['name'],
          'location_kind': 'road',
          'sequence_key': '001.001',
          'depth': 1,
          'materialized_path': '/${r['areaId']}/${r['id']}/',
          'created_at': now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await db.insert('streets', {
          'id': r['id'],
          'area_id': r['areaId'],
          'name': r['name'],
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({'app_mode': 'owner'});
      db = await DatabaseHelper.instance.database;
      await db.delete('customers');
      await db.delete('locations');
      await db.delete('streets');
      await db.delete('areas');
      await seedHierarchy(db);
    });

    test('1. ensureAllRoadsHaveSubRoads populates all 8 sub-roads and migrates parent-road customers', () async {
      const roadId = 'fba28599-5190-599c-b9f7-78c3953b3a46';
      const expectedSubRoadId = 'b1b1b1b1-fba2-599c-b9f7-78c3953b3a46';

      const custId = 'cust-on-road-001';
      await db.insert('customers', {
        'id': custId,
        'name': 'Ramesh Sharma',
        'phone1': '9876543210',
        'street_id': roadId,
        'location_id': roadId,
        'house_number': '12',
        'address': 'Bangar Nagar',
        'customer_since': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await DatabaseHelper.ensureAllRoadsHaveSubRoads(db);

      final subRoadRows = await db.query('locations', where: 'id = ?', whereArgs: [expectedSubRoadId]);
      expect(subRoadRows.isNotEmpty, isTrue);
      expect(subRoadRows.first['parent_location_id'], equals(roadId));
      expect(subRoadRows.first['depth'], equals(2));

      final custRows = await db.query('customers', where: 'id = ?', whereArgs: [custId]);
      expect(custRows.first['street_id'], equals(expectedSubRoadId));
      expect(custRows.first['location_id'], equals(expectedSubRoadId));
    });

    test('2. Google Accounts road has sub-road and Google Account customer defaults to sub-road', () async {
      await DatabaseHelper.ensureAllRoadsHaveSubRoads(db);

      const googleSubRoadId = 'e853890a-52a4-51a0-bb10-54ee14186df9';
      const googleRoadId = 'd753890a-52a4-51a0-bb10-54ee14186df9';

      final googleSubRoad = await db.query('locations', where: 'id = ?', whereArgs: [googleSubRoadId]);
      expect(googleSubRoad.isNotEmpty, isTrue);
      expect(googleSubRoad.first['parent_location_id'], equals(googleRoadId));

      final dao = CustomerDao();
      const googleCustId = 'google-user-123';
      await db.insert('customers', {
        'id': googleCustId,
        'name': 'Google User',
        'phone1': '9998887776',
        'street_id': 'default_street',
        'location_id': 'default_area',
        'customer_since': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await dao.assignCustomerToRoad(googleCustId, googleSubRoadId, locationId: googleRoadId);

      final updatedCust = await db.query('customers', where: 'id = ?', whereArgs: [googleCustId]);
      expect(updatedCust.first['street_id'], equals(googleSubRoadId));
      expect(updatedCust.first['location_id'], equals(googleRoadId));
    });

    test('3. Child locations query returns sub-roads, and leaf sub-roads query returns customers', () async {
      await DatabaseHelper.ensureAllRoadsHaveSubRoads(db);
      const roadId = 'fba28599-5190-599c-b9f7-78c3953b3a46';
      const subRoadId = 'b1b1b1b1-fba2-599c-b9f7-78c3953b3a46';

      final childrenOfRoad = await db.query('locations', where: 'parent_location_id = ?', whereArgs: [roadId]);
      expect(childrenOfRoad.isNotEmpty, isTrue);
      expect(childrenOfRoad.any((l) => l['id'] == subRoadId), isTrue);

      final childrenOfSubRoad = await db.query('locations', where: 'parent_location_id = ?', whereArgs: [subRoadId]);
      expect(childrenOfSubRoad.isEmpty, isTrue);

      final dao = CustomerDao();
      final customersInSubRoad = await dao.getCustomersByStreet(subRoadId);
      expect(customersInSubRoad, isNotNull);
    });
  });
}
