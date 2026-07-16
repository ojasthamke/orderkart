// test/analytics_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/analytics/data/analytics_dao.dart';

void main() {
  // Initialize FFI for local SQLite tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('AnalyticsDao Queries Tests', () {
    setUp(() async {
      await DatabaseHelper.instance.close();
      final dbPath = await databaseFactory.getDatabasesPath();
      final path = '$dbPath/orderkart.db';
      await databaseFactory.deleteDatabase(path);

      final db = await DatabaseHelper.instance.database;
      // Seed mock data for verification
      await db.insert('workers', {
        'id': 'worker-1',
        'name': 'Worker Alice',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Seed legacy areas and streets
      await db.insert('areas', {
        'id': 'area-1',
        'name': 'North Area',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert('streets', {
        'id': 'street-1',
        'area_id': 'area-1',
        'name': 'Green Street',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Seed unified locations table
      await db.insert('locations', {
        'id': 'area-1',
        'name': 'North Area',
        'location_kind': 'area',
        'sequence_key': 'a',
        'depth': 0,
        'materialized_path': '/area-1/',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert('locations', {
        'id': 'street-1',
        'parent_location_id': 'area-1',
        'name': 'Green Street',
        'location_kind': 'road',
        'sequence_key': 'b',
        'depth': 1,
        'materialized_path': '/area-1/street-1/',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert('customers', {
        'id': 'cust-1',
        'street_id': 'street-1',
        'location_id': 'street-1',
        'name': 'Customer Bob',
        'phone1': '1234567890',
        'customer_since': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert('orders', {
        'id': 'order-1',
        'customer_id': 'cust-1',
        'assigned_worker_id': 'worker-1',
        'grand_total': 150.0,
        'paid_amount': 100.0,
        'remaining_amount': 50.0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert('expenses', {
        'id': 'exp-1',
        'name': 'Fuel',
        'amount': 25.0,
        'date': '2026-07-05',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    });

    test('getTopWorkers retrieves correct sales metrics', () async {
      final dao = AnalyticsDao();
      final stats = await dao.getTopWorkers();
      expect(stats, isNotEmpty);
      expect(stats.first['worker_name'], equals('Worker Alice'));
      expect(stats.first['total_sales'], equals(150.0));
      expect(stats.first['total_collection'], equals(100.0));
    });

    test('getAreaPerformance retrieves correct metrics', () async {
      final dao = AnalyticsDao();
      final stats = await dao.getAreaPerformance();
      expect(stats, isNotEmpty);
      expect(stats.first['area_name'], equals('North Area'));
      expect(stats.first['total_sales'], equals(150.0));
      expect(stats.first['total_outstanding'], equals(50.0));
    });

    test('getStreetPerformance retrieves correct metrics', () async {
      final dao = AnalyticsDao();
      final stats = await dao.getStreetPerformance();
      expect(stats, isNotEmpty);
      expect(stats.first['street_name'], equals('Green Street'));
      expect(stats.first['area_name'], equals('North Area'));
      expect(stats.first['total_sales'], equals(150.0));
    });

    test('getCustomerGrowth retrieves correct growth counts', () async {
      final dao = AnalyticsDao();
      final growth = await dao.getCustomerGrowth();
      expect(growth, isNotEmpty);
      expect(growth.first['new_customers_count'], equals(1));
    });

    test('getCollectionEfficiency calculates efficiency correctly', () async {
      final dao = AnalyticsDao();
      final stats = await dao.getCollectionEfficiency();
      expect(stats['total_sales'], equals(150.0));
      expect(stats['total_collection'], equals(100.0));
      expect(stats['total_outstanding'], equals(50.0));
      expect(stats['collection_efficiency_pct'], closeTo(66.67, 0.1));
    });
  });
}
