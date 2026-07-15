import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Database migration from V9 to V10 works transactionally with strict validation', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dbPath = p.join(await getDatabasesPath(), 'migration_test.db');
    final dbFile = File(dbPath);
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }

    // 1. Create a V9 database manually
    final dbV9 = await openDatabase(
      dbPath,
      version: 9,
      onCreate: (db, version) async {
        // Create V9 areas table
        await db.execute('''
          CREATE TABLE areas (
            id           TEXT PRIMARY KEY,
            name         TEXT NOT NULL,
            description  TEXT DEFAULT '',
            color        INTEGER DEFAULT 0,
            photo_path   TEXT DEFAULT '',
            maps_location TEXT DEFAULT '',
            created_by   TEXT DEFAULT 'owner',
            assigned_worker_id TEXT DEFAULT '',
            worker_name  TEXT DEFAULT '',
            device_name  TEXT DEFAULT '',
            created_at   TEXT NOT NULL,
            updated_at   TEXT NOT NULL
          )
        ''');

        // Create V9 streets table
        await db.execute('''
          CREATE TABLE streets (
            id           TEXT PRIMARY KEY,
            area_id      TEXT NOT NULL,
            name         TEXT NOT NULL,
            description  TEXT DEFAULT '',
            photo_path   TEXT DEFAULT '',
            maps_location TEXT DEFAULT '',
            created_by   TEXT DEFAULT 'owner',
            assigned_worker_id TEXT DEFAULT '',
            worker_name  TEXT DEFAULT '',
            device_name  TEXT DEFAULT '',
            created_at   TEXT NOT NULL,
            FOREIGN KEY(area_id) REFERENCES areas(id) ON DELETE CASCADE
          )
        ''');

        // Create V9 customers table
        await db.execute('''
          CREATE TABLE customers (
            id                  TEXT PRIMARY KEY,
            street_id           TEXT NOT NULL,
            name                TEXT NOT NULL,
            phone1              TEXT NOT NULL,
            phone2              TEXT DEFAULT '',
            whatsapp            TEXT DEFAULT '',
            house_number        TEXT DEFAULT '',
            address             TEXT DEFAULT '',
            notes               TEXT DEFAULT '',
            maps_location       TEXT DEFAULT '',
            photo_path          TEXT DEFAULT '',
            serial_no           INTEGER DEFAULT 0,
            outstanding_balance REAL DEFAULT 0,
            total_orders        INTEGER DEFAULT 0,
            total_paid          REAL DEFAULT 0,
            total_pending       REAL DEFAULT 0,
            customer_since      TEXT NOT NULL,
            last_order_date     TEXT DEFAULT '',
            created_at          TEXT NOT NULL,
            updated_at          TEXT NOT NULL,
            FOREIGN KEY(street_id) REFERENCES streets(id) ON DELETE CASCADE
          )
        ''');

        // Create V9 visits table
        await db.execute('''
          CREATE TABLE visits (
            id           TEXT PRIMARY KEY,
            date         TEXT NOT NULL,
            area_id      TEXT NOT NULL,
            street_id    TEXT DEFAULT '',
            notes        TEXT DEFAULT '',
            priority     INTEGER DEFAULT 0,
            status       TEXT NOT NULL DEFAULT 'pending',
            created_at   TEXT NOT NULL
          )
        ''');
      },
    );

    // 2. Insert mock data
    final uuid = const Uuid();
    final areaId1 = uuid.v4();
    final areaId2 = uuid.v4();
    final streetId1 = uuid.v4();
    final streetId2 = uuid.v4();
    final customerId1 = uuid.v4();
    final customerId2 = uuid.v4();
    final visitId1 = uuid.v4();

    final nowStr = DateTime.now().toIso8601String();

    await dbV9.insert('areas', {
      'id': areaId1,
      'name': 'Rajapeth',
      'description': 'Rajapeth Area',
      'created_at': nowStr,
      'updated_at': nowStr,
    });
    await dbV9.insert('areas', {
      'id': areaId2,
      'name': 'Civil Lines',
      'description': 'Civil Lines Area',
      'created_at': nowStr,
      'updated_at': nowStr,
    });

    await dbV9.insert('streets', {
      'id': streetId1,
      'area_id': areaId1,
      'name': 'Main Road',
      'description': 'Main Road Street',
      'created_at': nowStr,
    });
    await dbV9.insert('streets', {
      'id': streetId2,
      'area_id': areaId2,
      'name': 'Hanuman Galli',
      'description': 'Hanuman Galli Street',
      'created_at': nowStr,
    });

    await dbV9.insert('customers', {
      'id': customerId1,
      'street_id': streetId1,
      'name': 'Suresh Kumar',
      'phone1': '9876543210',
      'customer_since': nowStr,
      'created_at': nowStr,
      'updated_at': nowStr,
    });
    await dbV9.insert('customers', {
      'id': customerId2,
      'street_id': streetId2,
      'name': 'Ramesh Singh',
      'phone1': '8765432109',
      'customer_since': nowStr,
      'created_at': nowStr,
      'updated_at': nowStr,
    });

    await dbV9.insert('visits', {
      'id': visitId1,
      'date': '2026-07-16',
      'area_id': areaId1,
      'street_id': streetId1,
      'created_at': nowStr,
    });

    await dbV9.close();

    // 3. Trigger upgrade to V10 using DatabaseHelper instance
    DatabaseHelper.dbNameOverride = 'migration_test.db';
    final dbV10 = await DatabaseHelper.instance.database;

    // 4. Verify new schema is present and old tables are STILL present (Phased compatibility!)
    final areasCount = Sqflite.firstIntValue(await dbV10.rawQuery('SELECT COUNT(*) FROM areas')) ?? 0;
    expect(areasCount, equals(2));

    final streetsCount = Sqflite.firstIntValue(await dbV10.rawQuery('SELECT COUNT(*) FROM streets')) ?? 0;
    expect(streetsCount, equals(2));

    // Verify locations table exists and has correct counts
    final locCount = Sqflite.firstIntValue(await dbV10.rawQuery('SELECT COUNT(*) FROM locations')) ?? 0;
    expect(locCount, equals(4)); // 2 areas + 2 streets

    // Verify root locations (parent_location_id = NULL)
    final rootCount = Sqflite.firstIntValue(await dbV10.rawQuery('SELECT COUNT(*) FROM locations WHERE parent_location_id IS NULL')) ?? 0;
    expect(rootCount, equals(2));

    // Verify child locations (parent_location_id = areaId)
    final childCount = Sqflite.firstIntValue(await dbV10.rawQuery('SELECT COUNT(*) FROM locations WHERE parent_location_id IS NOT NULL')) ?? 0;
    expect(childCount, equals(2));

    // Verify customer location_id backfill
    final cust1 = (await dbV10.query('customers', where: 'id = ?', whereArgs: [customerId1])).first;
    expect(cust1['location_id'], equals(streetId1));
    expect(cust1['street_id'], equals(streetId1)); // Keep street_id column intact!

    final cust2 = (await dbV10.query('customers', where: 'id = ?', whereArgs: [customerId2])).first;
    expect(cust2['location_id'], equals(streetId2));

    // Verify visit location_id backfill
    final visit1 = (await dbV10.query('visits', where: 'id = ?', whereArgs: [visitId1])).first;
    expect(visit1['location_id'], equals(streetId1));

    // Clean up
    await DatabaseHelper.instance.close();
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
  });
}
