import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/analytics/data/analytics_dao.dart';
import 'package:orderkart/features/inventory/data/item_dao.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Accumulated Profit & Mandi Market Checklist Tests', () {
    final analyticsDao = AnalyticsDao();
    final itemDao = ItemDao();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final db = await DatabaseHelper.instance.database;
      await db.delete('order_items');
      await db.delete('orders');
      await db.delete('payments');
      await db.delete('expenses');
      await db.delete('items');
      await db.delete('item_price_history');
      await db.delete('customers');
      await db.delete('locations');
      await db.delete('streets');
      await db.delete('areas');

      final now = DateTime.now();
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr =
          "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

      // 1. Seed Locations & Customer
      await db.insert('areas', {
        'id': 'area-1',
        'name': 'Main Market',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('streets', {
        'id': 'street-1',
        'area_id': 'area-1',
        'name': 'Shop Lane',
        'created_at': now.toIso8601String(),
      });

      await db.insert('locations', {
        'id': 'area-1',
        'name': 'Main Market',
        'location_kind': 'area',
        'sequence_key': 'a',
        'depth': 0,
        'materialized_path': '/area-1/',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('locations', {
        'id': 'street-1',
        'parent_location_id': 'area-1',
        'name': 'Shop Lane',
        'location_kind': 'road',
        'sequence_key': 'b',
        'depth': 1,
        'materialized_path': '/area-1/street-1/',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('customers', {
        'id': 'cust-1',
        'street_id': 'street-1',
        'location_id': 'street-1',
        'name': 'Ramesh Kumar',
        'phone1': '9876543210',
        'outstanding_balance': 0.0,
        'customer_since': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 2. Seed Items
      await db.insert('items', {
        'id': 'item-potato',
        'name': 'Potato (Batata)',
        'category': 'Vegetables',
        'unit': 'kg',
        'cost_price': 20.0,
        'selling_price': 30.0,
        'stock': 5.0,
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('items', {
        'id': 'item-onion',
        'name': 'Onion (Kanda)',
        'category': 'Vegetables',
        'unit': 'kg',
        'cost_price': 25.0,
        'selling_price': 40.0,
        'stock': 2.0,
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 3. Yesterday's Order: 10kg Potato (Cost 200, Sell 300 -> Profit 100)
      await db.insert('orders', {
        'id': 'ord-yest',
        'customer_id': 'cust-1',
        'subtotal': 300.0,
        'discount': 0.0,
        'delivery_charge': 0.0,
        'smart_rounded_amount': 0.0,
        'grand_total': 300.0,
        'paid_amount': 300.0,
        'remaining_amount': 0.0,
        'delivery_status': 'delivered',
        'created_at': '$yesterdayStr 10:00:00',
        'updated_at': '$yesterdayStr 10:00:00',
      });

      await db.insert('order_items', {
        'id': 'oi-1',
        'order_id': 'ord-yest',
        'item_id': 'item-potato',
        'item_name': 'Potato (Batata)',
        'item_unit': 'kg',
        'quantity': 10.0,
        'unit_price': 30.0,
        'total_price': 300.0,
      });

      // 4. Today's Order: 20kg Potato + 10kg Onion (Cost: 400 + 250 = 650, Sell: 600 + 400 = 1000 -> Profit 350)
      await db.insert('orders', {
        'id': 'ord-today',
        'customer_id': 'cust-1',
        'subtotal': 1000.0,
        'discount': 0.0,
        'delivery_charge': 20.0,
        'smart_rounded_amount': 0.0,
        'grand_total': 1020.0,
        'paid_amount': 1020.0,
        'remaining_amount': 0.0,
        'delivery_status': 'delivered',
        'created_at': '$todayStr 12:00:00',
        'updated_at': '$todayStr 12:00:00',
      });

      await db.insert('order_items', {
        'id': 'oi-2',
        'order_id': 'ord-today',
        'item_id': 'item-potato',
        'item_name': 'Potato (Batata)',
        'item_unit': 'kg',
        'quantity': 20.0,
        'unit_price': 30.0,
        'total_price': 600.0,
      });

      await db.insert('order_items', {
        'id': 'oi-3',
        'order_id': 'ord-today',
        'item_id': 'item-onion',
        'item_name': 'Onion (Kanda)',
        'item_unit': 'kg',
        'quantity': 10.0,
        'unit_price': 40.0,
        'total_price': 400.0,
      });

      // 5. Today's store expense: ₹50
      await db.insert('expenses', {
        'id': 'exp-1',
        'name': 'Tea & Transport',
        'amount': 50.0,
        'date': todayStr,
        'created_at': '$todayStr 13:00:00',
        'updated_at': '$todayStr 13:00:00',
      });
    });

    test('Accumulated Profit as per day accumulates chronologically', () async {
      final rows = await analyticsDao.getDateWiseProfitBreakdown(days: 7);
      expect(rows, isNotEmpty);

      // Verify that newest date is first, and accumulated_profit is tracked
      final newest = rows.first;
      expect(newest.containsKey('accumulated_profit'), isTrue);

      // Yesterday's net profit = 300 - 200 = 100
      // Today's net profit = (1000 - 650) + 20 (delivery) - 50 (expense) = 320
      // Cumulative accumulated profit = 100 + 320 = 420
      expect(newest['accumulated_profit'], closeTo(420.0, 0.01));
    });

    test('Today vs Yesterday Profit Comparison returns accurate growth metrics', () async {
      final summary = await analyticsDao.getTodayVsYesterdayProfitSummary();

      final today = summary['today'] as Map<String, dynamic>;
      final yesterday = summary['yesterday'] as Map<String, dynamic>;

      expect(yesterday['net_profit'], closeTo(100.0, 0.01));
      expect(today['net_profit'], closeTo(320.0, 0.01));

      // Profit difference = 320 - 100 = 220
      expect(summary['profit_diff'], closeTo(220.0, 0.01));
      // Growth % = (220 / 100) * 100 = 220%
      expect(summary['profit_growth_pct'], closeTo(220.0, 0.01));
      expect(summary['is_growth'], isTrue);
    });

    test('Ordered Item Stats calculates stock vs to_buy_quantity correctly', () async {
      final stats = await itemDao.getOrderedItemStats(dateFilter: 'today');
      expect(stats, isNotEmpty);

      final potato = stats.firstWhere((s) => s['item_name'] == 'Potato (Batata)');
      // Today demand = 20 kg, current stock in store = 5 kg
      expect(potato['total_quantity'], equals(20.0));
      expect(potato['stock'], equals(5.0));
      // To Buy deficit = 20 - 5 = 15 kg
      expect(potato['to_buy_quantity'], equals(15.0));
      expect(potato['cost_price'], equals(20.0));

      final onion = stats.firstWhere((s) => s['item_name'] == 'Onion (Kanda)');
      // Today demand = 10 kg, current stock in store = 2 kg
      expect(onion['total_quantity'], equals(10.0));
      expect(onion['stock'], equals(2.0));
      // To Buy deficit = 10 - 2 = 8 kg
      expect(onion['to_buy_quantity'], equals(8.0));
    });

    test('quickUpdateItemCostPrice updates item cost rate and logs price history snapshot', () async {
      // Update Potato cost price from Mandi from ₹20 to ₹22.50
      await itemDao.quickUpdateItemCostPrice('item-potato', 22.50);

      final db = await DatabaseHelper.instance.database;
      final updatedItem = await db.query('items', where: 'id = ?', whereArgs: ['item-potato']);
      expect(updatedItem.first['cost_price'], equals(22.50));

      final history = await db.query('item_price_history', where: 'item_id = ?', whereArgs: ['item-potato']);
      expect(history, isNotEmpty);
      expect(history.first['cost_price'], equals(22.50));
    });
  });
}
