import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/analytics/data/analytics_dao.dart';
import 'package:orderkart/features/order/data/order_dao.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Deep Analytics & Forensic Math Verification Tests', () {
    final analyticsDao = AnalyticsDao();
    final orderDao = OrderDao();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await DatabaseHelper.instance.close();
      final dbPath = await databaseFactory.getDatabasesPath();
      final path = '$dbPath/orderkart.db';
      await databaseFactory.deleteDatabase(path);

      final db = await DatabaseHelper.instance.database;

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
        'name': 'Alice Retailer',
        'phone1': '9876543210',
        'outstanding_balance': 30.0,
        'customer_since': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 2. Seed Items
      // Item A: Tomato (Kg base, Sold in Kg) - Cost 20, Selling 40, Market 50
      await db.insert('items', {
        'id': 'item-tomato',
        'name': 'Tomato Hybrid',
        'category': 'Vegetables',
        'unit': 'kg',
        'cost_price': 20.0,
        'selling_price': 40.0,
        'market_price': 50.0,
        'stock': 50.0,
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Item B: Ginger (Kg base, Sold in Grams) - Cost 100/kg, Selling 160/kg (0.16/g), Market 200/kg
      await db.insert('items', {
        'id': 'item-ginger',
        'name': 'Fresh Ginger',
        'category': 'Vegetables',
        'unit': 'kg',
        'cost_price': 100.0,
        'selling_price': 160.0,
        'market_price': 200.0,
        'stock': 10.0,
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Item C: Premium Apple (Kg base, NEVER SOLD - Dead Stock) - Cost 80, Selling 120, Stock 30
      await db.insert('items', {
        'id': 'item-apple',
        'name': 'Shimla Apple',
        'category': 'Fruits',
        'unit': 'kg',
        'cost_price': 80.0,
        'selling_price': 120.0,
        'market_price': 150.0,
        'stock': 30.0,
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 3. Seed Order 1 (Today):
      // Tomato 2kg (80 rev, 40 cogs), Ginger 250gm (40 rev, 25 cogs).
      // Subtotal 120, Discount 10, Delivery 20, Grand Total 130. Paid 100 Cash, Rem 30.
      await db.insert('orders', {
        'id': 'order-today',
        'customer_id': 'cust-1',
        'subtotal': 120.0,
        'discount': 10.0,
        'delivery_charge': 20.0,
        'smart_rounded_amount': 0.0,
        'grand_total': 130.0,
        'paid_amount': 100.0,
        'remaining_amount': 30.0,
        'delivery_status': 'delivered',
        'created_at': '$todayStr 10:30:00',
        'updated_at': '$todayStr 10:30:00',
      });

      await db.insert('order_items', {
        'id': 'oi-1',
        'order_id': 'order-today',
        'item_id': 'item-tomato',
        'item_name': 'Tomato Hybrid',
        'item_unit': 'kg',
        'quantity': 2.0,
        'unit_price': 40.0,
        'total_price': 80.0,
      });

      await db.insert('order_items', {
        'id': 'oi-2',
        'order_id': 'order-today',
        'item_id': 'item-ginger',
        'item_name': 'Fresh Ginger',
        'item_unit': 'gram',
        'quantity': 250.0,
        'unit_price': 0.16,
        'total_price': 40.0,
      });

      await db.insert('payments', {
        'id': 'pay-1',
        'order_id': 'order-today',
        'customer_id': 'cust-1',
        'amount': 100.0,
        'method': 'cash',
        'created_at': '$todayStr 10:35:00',
      });

      // 4. Seed Order 2 (Yesterday):
      // Tomato 1kg (40 rev, 20 cogs). Subtotal 40, Discount 0, Delivery 0, Grand Total 40. Paid 40 UPI.
      await db.insert('orders', {
        'id': 'order-yesterday',
        'customer_id': 'cust-1',
        'subtotal': 40.0,
        'discount': 0.0,
        'delivery_charge': 0.0,
        'smart_rounded_amount': 0.0,
        'grand_total': 40.0,
        'paid_amount': 40.0,
        'remaining_amount': 0.0,
        'delivery_status': 'delivered',
        'created_at': '$yesterdayStr 14:15:00',
        'updated_at': '$yesterdayStr 14:15:00',
      });

      await db.insert('order_items', {
        'id': 'oi-3',
        'order_id': 'order-yesterday',
        'item_id': 'item-tomato',
        'item_name': 'Tomato Hybrid',
        'item_unit': 'kg',
        'quantity': 1.0,
        'unit_price': 40.0,
        'total_price': 40.0,
      });

      await db.insert('payments', {
        'id': 'pay-2',
        'order_id': 'order-yesterday',
        'customer_id': 'cust-1',
        'amount': 40.0,
        'method': 'upi',
        'created_at': '$yesterdayStr 14:20:00',
      });

      // 5. Seed Expenses
      await db.insert('expenses', {
        'id': 'exp-today',
        'name': 'Tea & Snacks',
        'amount': 15.0,
        'date': todayStr,
        'created_at': '$todayStr 11:00:00',
        'updated_at': '$todayStr 11:00:00',
      });

      await db.insert('expenses', {
        'id': 'exp-yesterday',
        'name': 'Packaging Boxes',
        'amount': 20.0,
        'date': yesterdayStr,
        'created_at': '$yesterdayStr 15:00:00',
        'updated_at': '$yesterdayStr 15:00:00',
      });
    });

    test('1. Date-Wise Daily Profit Breakdown Math Verification', () async {
      final breakdown = await analyticsDao.getDateWiseProfitBreakdown(days: 7);
      expect(breakdown.length, 7);

      // Find Today's record
      final todayRow = breakdown.first; // sorted newest first
      expect(todayRow['orders_count'], 1);
      expect(todayRow['revenue'], 130.0);
      // COGS = 40 (Tomato) + 25 (Ginger 250g of 100/kg) = 65
      expect(todayRow['cogs'], 65.0);
      expect(todayRow['delivery_income'], 20.0);
      expect(todayRow['discounts'], 10.0);
      expect(todayRow['expenses'], 15.0);
      expect(todayRow['gross_profit'], 65.0); // 130 - 65
      // Net Profit = Gross (65) + Delivery (20) - Discount (10) - Expenses (15) = 60
      expect(todayRow['net_profit'], 60.0);
      expect(todayRow['is_profitable'], true);
      expect(todayRow['cash_collected'], 100.0);
      expect(todayRow['online_collected'], 0.0);
      expect(todayRow['pending_debt'], 30.0);

      // Find Yesterday's record
      final yesterdayRow = breakdown[1];
      expect(yesterdayRow['orders_count'], 1);
      expect(yesterdayRow['revenue'], 40.0);
      expect(yesterdayRow['cogs'], 20.0);
      expect(yesterdayRow['delivery_income'], 0.0);
      expect(yesterdayRow['discounts'], 0.0);
      expect(yesterdayRow['expenses'], 20.0);
      expect(yesterdayRow['gross_profit'], 20.0);
      // Net Profit = 20 + 0 - 0 - 20 = 0
      expect(yesterdayRow['net_profit'], 0.0);
      expect(yesterdayRow['online_collected'], 40.0);
      expect(yesterdayRow['pending_debt'], 0.0);
    });

    test('2. Profit & Loss Statement All-Time Math Verification', () async {
      final pl = await orderDao.getProfitLossStatement();
      // Total Revenue = 130 + 40 = 170
      expect(pl['total_revenue'], 170.0);
      // Total COGS = 65 + 20 = 85
      expect(pl['cogs'], 85.0);
      // Gross Profit = 170 - 85 = 85
      expect(pl['gross_profit'], 85.0);
      // Total Expenses = 15 + 20 = 35
      expect(pl['total_expenses'], 35.0);
      // Net Profit = 85 - 35 = 50
      expect(pl['net_profit'], 50.0);
      expect(pl['is_profitable'], true);
      // Margin = (50 / 170) * 100 = 29.4117%
      expect((pl['profit_margin_pct'] as double).toStringAsFixed(1), '29.4');
    });

    test('3. Item Profitability Matrix Math Verification', () async {
      final matrix = await analyticsDao.getItemProfitabilityMatrix(days: 30);
      final allItems = matrix['all_items'] as List<dynamic>;
      expect(allItems.length, 2); // Tomato & Ginger (Apple was never sold)

      final tomato = allItems.firstWhere((x) => x['name'] == 'Tomato Hybrid');
      expect(tomato['qty_sold'], 3.0); // 2kg + 1kg
      expect(tomato['revenue'], 120.0); // 80 + 40
      expect(tomato['cogs'], 60.0); // 40 + 20
      expect(tomato['profit'], 60.0); // 120 - 60
      expect(tomato['margin_pct'], 50.0); // (60 / 120) * 100

      final ginger = allItems.firstWhere((x) => x['name'] == 'Fresh Ginger');
      expect(ginger['qty_sold'], 250.0);
      expect(ginger['revenue'], 40.0);
      expect(ginger['cogs'], 25.0); // 250g * 0.10/g
      expect(ginger['profit'], 15.0); // 40 - 25
      expect(ginger['margin_pct'], 37.5); // (15 / 40) * 100
    });

    test('4. Customer Lifetime Value & Profit Contribution Verification', () async {
      final ltv = await analyticsDao.getCustomerProfitContribution(limit: 10);
      expect(ltv.length, 1);

      final c = ltv.first;
      expect(c['customer_id'], 'cust-1');
      expect(c['total_orders'], 2);
      expect(c['total_revenue'], 170.0);
      expect(c['total_paid'], 140.0);
      expect(c['outstanding_balance'], 30.0);
      expect(c['total_cogs'], 85.0);
      expect(c['profit_contribution'], 85.0); // 170 - 85
      expect(c['aov'], 85.0); // 170 / 2
    });

    test('5. Dead Stock & Capital Locked Verification', () async {
      final dead = await analyticsDao.getDeadStockAndTurnover(deadStockDays: 14);
      final deadItems = dead['dead_stock_items'] as List<dynamic>;

      // Apple has 30kg stock @ 80 cost = 2400 locked
      expect(deadItems.any((x) => x['name'] == 'Shimla Apple'), true);
      final apple = deadItems.firstWhere((x) => x['name'] == 'Shimla Apple');
      expect(apple['stock'], 30.0);
      expect(apple['cost_price'], 80.0);
      expect(apple['capital_locked'], 2400.0);
      expect(dead['capital_locked'], 2400.0);
    });

    test('6. Cash Flow & Debt Aging Verification', () async {
      final debt = await analyticsDao.getCashflowAndDebtAging();
      final splits = debt['payment_splits'] as List<dynamic>;

      final cash = splits.firstWhere((x) => x['method'] == 'CASH');
      expect(cash['amount'], 100.0);

      final upi = splits.firstWhere((x) => x['method'] == 'UPI');
      expect(upi['amount'], 40.0);

      expect(debt['total_collected'], 140.0);
      expect(debt['total_pending'], 30.0);

      final aging = debt['aging'] as Map<String, dynamic>;
      // All pending 30.0 was created today, so 0-7 days bracket
      expect(aging['0_7_days']['amount'], 30.0);
      expect(aging['0_7_days']['count'], 1);
    });

    test('7. Customer Savings Verification (Market Price vs Selling Price)', () async {
      final savings = await orderDao.getCustomerSavings('cust-1');
      // Order 1: Tomato savings = (50 - 40)*2 = 20. Ginger savings = (200*0.25) - 40 = 10. Discount = 10. Total = 40.
      // Order 2: Tomato savings = (50 - 40)*1 = 10. Total = 10.
      // Total savings = 40 + 10 = 50.
      expect(savings['total'], 50.0);
    });
  });
}
