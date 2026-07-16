// test/seed_database_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/core/database/database_seeder.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Seed 30 Vegetables, 10 Fruits, 10 Areas, 50 Streets, 500 Customers, 200 VIPs', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    DatabaseHelper.dbNameOverride = 'orderkart_seeded.db';

    // Clear any existing cached test database
    await DatabaseHelper.instance.close();
    final dbPath = await databaseFactory.getDatabasesPath();
    final path = '$dbPath/orderkart_seeded.db';
    await databaseFactory.deleteDatabase(path);

    final db = await DatabaseHelper.instance.database;

    final results = await DatabaseSeeder.seedAll(clearExisting: true);

    expect(results['areas'], equals(10));
    expect(results['streets'], equals(50));
    expect(results['customers'], equals(500));
    expect(results['vip'], equals(200));
    expect(results['vegetables'], equals(30));
    expect(results['fruits'], equals(10));
    expect(results['total_items'], equals(40));

    final vegRes = await db.query('items', where: 'category = ?', whereArgs: ['Vegetables']);
    expect(vegRes.length, equals(30));

    final fruitRes = await db.query('items', where: 'category = ?', whereArgs: ['Fruits']);
    expect(fruitRes.length, equals(10));

    final areaRes = await db.query('areas');
    expect(areaRes.length, equals(10));

    final streetRes = await db.query('streets');
    expect(streetRes.length, equals(50));

    final custRes = await db.query('customers');
    expect(custRes.length, equals(500));

    final vipRes = await db.query('vip_membership');
    expect(vipRes.length, equals(200));
  });
}
