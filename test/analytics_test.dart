// test/analytics_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/analytics/data/analytics_dao.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Initialize FFI for local SQLite tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('AnalyticsDao Queries Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({'app_mode': 'owner'});
      final db = await DatabaseHelper.instance.database;

      await db.delete('payments');
      await db.delete('order_items');
      await db.delete('orders');
      await db.delete('expenses');
      await db.delete('customers');
      await db.delete('locations');
      await db.delete('streets');
      await db.delete('areas');
      await db.delete('workers');

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

    test('Analytics queries exclude cancelled and denied orders', () async {
      final db = await DatabaseHelper.instance.database;

      // Insert a cancelled order for worker-1 and cust-1
      await db.insert('orders', {
        'id': 'order-cancelled',
        'customer_id': 'cust-1',
        'assigned_worker_id': 'worker-1',
        'grand_total': 500.0,
        'paid_amount': 200.0,
        'remaining_amount': 300.0,
        'delivery_status': 'cancelled',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Insert a denied order for worker-1 and cust-1
      await db.insert('orders', {
        'id': 'order-denied',
        'customer_id': 'cust-1',
        'assigned_worker_id': 'worker-1',
        'grand_total': 1000.0,
        'paid_amount': 400.0,
        'remaining_amount': 600.0,
        'delivery_status': 'denied',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final dao = AnalyticsDao();

      // Top workers should only show 150.0 sales (excluding cancelled & denied)
      final topWorkers = await dao.getTopWorkers();
      expect(topWorkers.first['total_sales'], equals(150.0));

      // Area performance should only show 150.0 sales
      final areaPerf = await dao.getAreaPerformance();
      expect(areaPerf.first['total_sales'], equals(150.0));

      // Street performance should only show 150.0 sales
      final streetPerf = await dao.getStreetPerformance();
      expect(streetPerf.first['total_sales'], equals(150.0));

      // Collection efficiency should only show 150.0 sales
      final efficiency = await dao.getCollectionEfficiency();
      expect(efficiency['total_sales'], equals(150.0));
      expect(efficiency['total_collection'], equals(100.0));
      expect(efficiency['total_outstanding'], equals(50.0));
    });
  });
}
