import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/area/data/area_dao.dart';
import 'package:orderkart/features/location/data/location_dao.dart';
import 'package:orderkart/features/customer/data/customer_dao.dart';
import 'package:orderkart/features/customer/domain/customer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('OrderKart Genuine Repo Area System Tests', () {
    final areaDao = AreaDao();
    final locationDao = LocationDao();
    final customerDao = CustomerDao();
    const areaId = 'area_darda_nagar';
    const road1Id = 'road_main_road';
    final now = DateTime.now().toIso8601String();

    setUp(() async {
      SharedPreferences.setMockInitialValues({'app_mode': 'owner'});
      final db = await DatabaseHelper.instance.database;

      await db.delete('customers');
      await db.delete('locations');
      await db.delete('streets');
      await db.delete('areas');
      await db.delete('settings');

      // 1. Seed Area "Darda Nagar"
      await db.insert('locations', {
        'id': areaId,
        'parent_location_id': null,
        'name': 'Darda Nagar',
        'location_kind': 'area',
        'sequence_key': '001',
        'depth': 0,
        'materialized_path': '/$areaId/',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('areas', {
        'id': areaId,
        'name': 'Darda Nagar',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('streets', {
        'id': areaId,
        'area_id': areaId,
        'name': 'Darda Nagar',
        'created_at': now,
      });

      // 2. Seed Road "Main Road" under Darda Nagar
      await db.insert('locations', {
        'id': road1Id,
        'parent_location_id': areaId,
        'name': 'Main Road',
        'location_kind': 'road',
        'sequence_key': '001001',
        'depth': 1,
        'materialized_path': '/$areaId/$road1Id/',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('streets', {
        'id': road1Id,
        'area_id': areaId,
        'name': 'Main Road',
        'created_at': now,
      });
    });

    test('1. Area is listed in AreaDao getAllAreas', () async {
      final areas = await areaDao.getAllAreas();
      expect(areas.length, 1);
      expect(areas.first.id, areaId);
      expect(areas.first.name, 'Darda Nagar');
    });

    test('2. Child locations are listed under Area in LocationDao getAllLocations', () async {
      final childLocations = await locationDao.getAllLocations(parentId: areaId);
      expect(childLocations.length, 1);
      expect(childLocations.first.id, road1Id);
      expect(childLocations.first.name, 'Main Road');
    });

    test('3. Customers registered directly at Area ID are queryable by getCustomersByStreet(areaId)', () async {
      final db = await DatabaseHelper.instance.database;
      await db.insert('customers', {
        'id': 'cust_area_1',
        'name': 'Area Customer Alpha',
        'phone1': '9876543210',
        'street_id': areaId,
        'location_id': areaId,
        'customer_code': 'CUST01',
        'customer_since': now,
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      });

      final customers = await customerDao.getCustomersByStreet(areaId);
      expect(customers.length, 1);
      expect(customers.first.id, 'cust_area_1');
      expect(customers.first.name, 'Area Customer Alpha');
    });

    test('4. Customers registered at Road ID are queryable by getCustomersByStreet(road1Id) and NOT duplicated in parent Area', () async {
      final db = await DatabaseHelper.instance.database;
      await db.insert('customers', {
        'id': 'cust_road_1',
        'name': 'Road Customer Beta',
        'phone1': '9876543211',
        'street_id': road1Id,
        'location_id': road1Id,
        'customer_code': 'CUST02',
        'customer_since': now,
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      });

      final roadCustomers = await customerDao.getCustomersByStreet(road1Id);
      expect(roadCustomers.length, 1);
      expect(roadCustomers.first.id, 'cust_road_1');
      expect(roadCustomers.first.name, 'Road Customer Beta');

      // Customers at child road must NOT be shown or duplicated when querying area directly
      final areaCustomers = await customerDao.getCustomersByStreet(areaId);
      expect(areaCustomers.isEmpty, isTrue,
          reason: 'Parent area must NOT duplicate or show child road customers');
    });

    test('5. Moving customer updates street_id and location_id directly', () async {
      final db = await DatabaseHelper.instance.database;
      await db.insert('customers', {
        'id': 'cust_move_test',
        'name': 'Move Customer',
        'phone1': '9876543212',
        'street_id': areaId,
        'location_id': areaId,
        'customer_code': 'CUST03',
        'customer_since': now,
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      });

      await customerDao.moveCustomers(['cust_move_test'], road1Id);

      final updatedCust = await customerDao.getCustomerById('cust_move_test');
      expect(updatedCust, isNotNull);
      expect(updatedCust!.streetId, road1Id);

      final rows = await db.query('customers', where: 'id = ?', whereArgs: ['cust_move_test']);
      expect(rows.first['location_id'], road1Id);
    });

    test('6. Location breadcrumbs trace root area to child road', () async {
      final crumbs = await locationDao.getBreadcrumbs(road1Id);
      expect(crumbs.length, 2);
      expect(crumbs[0].id, areaId);
      expect(crumbs[0].name, 'Darda Nagar');
      expect(crumbs[1].id, road1Id);
      expect(crumbs[1].name, 'Main Road');
    });

    test('7. Simultaneous Coexistence: Area customer and Road customer exist together without cross-leakage', () async {
      final db = await DatabaseHelper.instance.database;

      // Insert direct area customer
      await db.insert('customers', {
        'id': 'cust_simul_area',
        'name': 'Area Resident Sim',
        'phone1': '9111111111',
        'street_id': areaId,
        'location_id': areaId,
        'customer_code': 'SIM01',
        'customer_since': now,
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      });

      // Insert direct road customer
      await db.insert('customers', {
        'id': 'cust_simul_road',
        'name': 'Road Resident Sim',
        'phone1': '9222222222',
        'street_id': road1Id,
        'location_id': road1Id,
        'customer_code': 'SIM02',
        'customer_since': now,
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      });

      // Area must strictly have ONLY its 1 direct resident
      final areaCusts = await customerDao.getCustomersByStreet(areaId);
      expect(areaCusts.length, 1, reason: 'Area must only contain its direct customer');
      expect(areaCusts.first.id, 'cust_simul_area');

      // Road must strictly have ONLY its 1 direct resident
      final roadCusts = await customerDao.getCustomersByStreet(road1Id);
      expect(roadCusts.length, 1, reason: 'Road must only contain its direct customer');
      expect(roadCusts.first.id, 'cust_simul_road');
    });

    test('8. insertCustomer directly at Area ID succeeds and is isolated', () async {
      final cust = Customer(
        id: 'cust_direct_insert_area',
        streetId: areaId,
        name: 'Direct Insert Area Cust',
        phone1: '9333333333',
        customerSince: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        customerCode: 'DIR01',
      );

      final insertedId = await customerDao.insertCustomer(cust);
      expect(insertedId, 'cust_direct_insert_area');

      final custs = await customerDao.getCustomersByStreet(areaId);
      expect(custs.any((c) => c.id == 'cust_direct_insert_area'), isTrue);

      final roadCusts = await customerDao.getCustomersByStreet(road1Id);
      expect(roadCusts.any((c) => c.id == 'cust_direct_insert_area'), isFalse,
          reason: 'Area customer must not appear in child road');
    });
  });
}
