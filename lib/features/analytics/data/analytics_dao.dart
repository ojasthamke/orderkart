// lib/features/analytics/data/analytics_dao.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';

class AnalyticsDao {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// 1. Top Workers: returns list of workers ordered by sales performance.
  Future<List<Map<String, dynamic>>> getTopWorkers() async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT 
        w.id AS worker_id,
        w.name AS worker_name,
        COUNT(o.id) AS total_orders,
        COALESCE(SUM(o.grand_total), 0) AS total_sales,
        COALESCE(SUM(o.paid_amount), 0) AS total_collection,
        COALESCE(SUM(o.grand_total - o.paid_amount), 0) AS total_outstanding
      FROM workers w
      LEFT JOIN orders o ON o.assigned_worker_id = w.id AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      GROUP BY w.id
      ORDER BY total_sales DESC
    ''');
  }

  /// 2. Area Performance: returns metrics aggregated by geographic Area.
  Future<List<Map<String, dynamic>>> getAreaPerformance() async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT 
        a.id AS area_id,
        a.name AS area_name,
        COUNT(DISTINCT o.id) AS total_orders,
        COALESCE(SUM(o.grand_total), 0) AS total_sales,
        COALESCE(SUM(o.paid_amount), 0) AS total_collection,
        COALESCE(SUM(o.remaining_amount), 0) AS total_outstanding
      FROM locations a
      LEFT JOIN customers c ON (c.location_id = a.id OR c.location_id IN (SELECT id FROM locations WHERE parent_location_id = a.id)) AND (c.is_archived IS NULL OR c.is_archived = 0)
      LEFT JOIN orders o ON o.customer_id = c.id AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      WHERE a.location_kind = 'area' AND (a.is_archived IS NULL OR a.is_archived = 0)
      GROUP BY a.id
      ORDER BY total_sales DESC
    ''');
  }

  /// 3. Street Performance: returns metrics aggregated by Street.
  Future<List<Map<String, dynamic>>> getStreetPerformance() async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT 
        s.id AS street_id,
        s.name AS street_name,
        a.name AS area_name,
        COUNT(DISTINCT o.id) AS total_orders,
        COALESCE(SUM(o.grand_total), 0) AS total_sales,
        COALESCE(SUM(o.paid_amount), 0) AS total_collection,
        COALESCE(SUM(o.remaining_amount), 0) AS total_outstanding
      FROM locations s
      LEFT JOIN locations a ON s.parent_location_id = a.id AND (a.is_archived IS NULL OR a.is_archived = 0)
      LEFT JOIN customers c ON c.location_id = s.id AND (c.is_archived IS NULL OR c.is_archived = 0)
      LEFT JOIN orders o ON o.customer_id = c.id AND (o.delivery_status IS NULL OR o.delivery_status != 'cancelled')
      WHERE (s.location_kind = 'road' OR s.location_kind = 'street') AND (s.is_archived IS NULL OR s.is_archived = 0)
      GROUP BY s.id
      ORDER BY total_sales DESC
    ''');
  }

  /// 4. Customer Growth: returns count of new customer sign-ups over time.
  Future<List<Map<String, dynamic>>> getCustomerGrowth() async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT 
        DATE(created_at) AS date,
        COUNT(id) AS new_customers_count
      FROM customers
      WHERE (is_archived IS NULL OR is_archived = 0)
      GROUP BY DATE(created_at)
      ORDER BY date ASC
    ''');
  }

  /// 5. Profit Summary: returns total sales, product cost, expenses, and calculated net profit.
  Future<Map<String, dynamic>> getProfitSummary() async {
    final db = await _db;

    // Sum of sales and item costs
    final salesRes = await db.rawQuery('''
      SELECT 
        (SELECT COALESCE(SUM(o.grand_total), 0)
         FROM orders o
         LEFT JOIN customers c ON o.customer_id = c.id
         WHERE (o.delivery_status IS NULL OR o.delivery_status != 'cancelled') AND (c.is_archived IS NULL OR c.is_archived = 0)) AS total_sales,
        (SELECT COALESCE(SUM(oi.quantity * COALESCE(NULLIF(oi.cost_price, 0.0), i.cost_price, 0.0)), 0) 
         FROM order_items oi
         JOIN orders o ON oi.order_id = o.id
         LEFT JOIN customers c ON o.customer_id = c.id
         LEFT JOIN items i ON oi.item_id = i.id
         WHERE (o.delivery_status IS NULL OR o.delivery_status != 'cancelled') AND (c.is_archived IS NULL OR c.is_archived = 0)) AS total_cost
    ''');

    final double sales =
        (salesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final double cost =
        (salesRes.first['total_cost'] as num?)?.toDouble() ?? 0.0;

    // Sum of expenses
    final expRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total_expenses FROM expenses
    ''');
    final double expenses =
        (expRes.first['total_expenses'] as num?)?.toDouble() ?? 0.0;

    final double grossProfit = sales - cost;
    final double netProfit = grossProfit - expenses;

    return {
      'total_sales': sales,
      'total_cost': cost,
      'gross_profit': grossProfit,
      'total_expenses': expenses,
      'net_profit': netProfit,
    };
  }

  /// 6. Outstanding Summary: total outstanding amount and collection efficiency metrics.
  Future<Map<String, dynamic>> getCollectionEfficiency() async {
    final db = await _db;
    final res = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(grand_total), 0) AS total_sales,
        COALESCE(SUM(paid_amount), 0) AS total_collection,
        COALESCE(SUM(remaining_amount), 0) AS total_outstanding
      FROM orders
      WHERE (delivery_status IS NULL OR delivery_status != 'cancelled')
    ''');

    final double sales = (res.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final double collection =
        (res.first['total_collection'] as num?)?.toDouble() ?? 0.0;
    final double outstanding =
        (res.first['total_outstanding'] as num?)?.toDouble() ?? 0.0;

    final double efficiency = sales > 0 ? (collection / sales) * 100.0 : 100.0;

    return {
      'total_sales': sales,
      'total_collection': collection,
      'total_outstanding': outstanding,
      'collection_efficiency_pct': efficiency,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEEP BUSINESS INTELLIGENCE & FORENSIC STATISTICS
  // ─────────────────────────────────────────────────────────────────────────

  /// 7. Date-Wise Daily Profit & Financial Breakdown
  Future<List<Map<String, dynamic>>> getDateWiseProfitBreakdown({
    int days = 7,
    String? startDate,
    String? endDate,
  }) async {
    final db = await _db;
    final now = DateTime.now();

    final DateTime end = endDate != null
        ? (DateTime.tryParse(endDate) ?? now)
        : now;
    final DateTime start = startDate != null
        ? (DateTime.tryParse(startDate) ?? now.subtract(Duration(days: days - 1)))
        : now.subtract(Duration(days: days - 1));

    final String startStr =
        "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
    final String endStr =
        "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";

    // 1. Fetch daily order aggregates
    final orderRows = await db.rawQuery('''
      SELECT 
        DATE(created_at) AS date,
        COUNT(id) AS orders_count,
        COALESCE(SUM(subtotal), 0) AS subtotal,
        COALESCE(SUM(grand_total), 0) AS revenue,
        COALESCE(SUM(delivery_charge), 0) AS delivery_income,
        COALESCE(SUM(discount), 0) AS discounts,
        COALESCE(SUM(paid_amount), 0) AS total_collected,
        COALESCE(SUM(remaining_amount), 0) AS pending_debt
      FROM orders
      WHERE DATE(created_at) >= DATE(?) AND DATE(created_at) <= DATE(?) AND delivery_status != 'cancelled'
      GROUP BY DATE(created_at)
    ''', [startStr, endStr]);

    // 2. Fetch daily COGS with unit scaling
    final cogsRows = await db.rawQuery('''
      SELECT 
        DATE(o.created_at) AS date,
        COALESCE(SUM(
          CASE
            WHEN oi.item_id != '' AND (LOWER(COALESCE(oi.item_unit, '')) = 'gram' OR LOWER(COALESCE(oi.item_unit, '')) = 'gm') AND LOWER(COALESCE(i.unit, '')) = 'kg'
            THEN (oi.quantity / 1000.0) * COALESCE(i.cost_price, 0)
            WHEN oi.item_id != '' AND LOWER(COALESCE(oi.item_unit, '')) = 'kg' AND (LOWER(COALESCE(i.unit, '')) = 'gram' OR LOWER(COALESCE(i.unit, '')) = 'gm')
            THEN (oi.quantity * 1000.0) * COALESCE(i.cost_price, 0)
            ELSE oi.quantity * COALESCE(i.cost_price, 0)
          END
        ), 0) AS cogs
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      LEFT JOIN items i ON oi.item_id = i.id
      WHERE DATE(o.created_at) >= DATE(?) AND DATE(o.created_at) <= DATE(?) AND o.delivery_status != 'cancelled'
      GROUP BY DATE(o.created_at)
    ''', [startStr, endStr]);

    // 3. Fetch daily expenses
    final expRows = await db.rawQuery('''
      SELECT 
        DATE(created_at) AS date,
        COALESCE(SUM(amount), 0) AS expenses
      FROM expenses
      WHERE DATE(created_at) >= DATE(?) AND DATE(created_at) <= DATE(?)
      GROUP BY DATE(created_at)
    ''', [startStr, endStr]);

    // 4. Fetch daily cash vs online collections from payments table
    final payRows = await db.rawQuery('''
      SELECT 
        DATE(p.created_at) AS date,
        COALESCE(SUM(CASE WHEN LOWER(p.method) = 'cash' THEN p.amount ELSE 0 END), 0) AS cash_collected,
        COALESCE(SUM(CASE WHEN LOWER(p.method) != 'cash' THEN p.amount ELSE 0 END), 0) AS online_collected
      FROM payments p
      JOIN orders o ON p.order_id = o.id
      WHERE DATE(p.created_at) >= DATE(?) AND DATE(p.created_at) <= DATE(?) AND o.delivery_status != 'cancelled'
      GROUP BY DATE(p.created_at)
    ''', [startStr, endStr]);

    final Map<String, Map<String, dynamic>> orderMap = {
      for (final r in orderRows) r['date'].toString(): r
    };
    final Map<String, double> cogsMap = {
      for (final r in cogsRows)
        r['date'].toString(): (r['cogs'] as num?)?.toDouble() ?? 0.0
    };
    final Map<String, double> expMap = {
      for (final r in expRows)
        r['date'].toString(): (r['expenses'] as num?)?.toDouble() ?? 0.0
    };
    final Map<String, Map<String, double>> payMap = {
      for (final r in payRows)
        r['date'].toString(): {
          'cash': (r['cash_collected'] as num?)?.toDouble() ?? 0.0,
          'online': (r['online_collected'] as num?)?.toDouble() ?? 0.0,
        }
    };

    final int totalDays = end.difference(start).inDays + 1;
    const List<String> dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Build chronological list first to calculate running accumulated profit
    final List<Map<String, dynamic>> chronologicalList = [];
    double runningAccumulatedProfit = 0.0;

    for (int i = 0; i < totalDays; i++) {
      final curDate = start.add(Duration(days: i));
      final dateKey =
          "${curDate.year}-${curDate.month.toString().padLeft(2, '0')}-${curDate.day.toString().padLeft(2, '0')}";
      final dayName = dayNames[curDate.weekday - 1];

      final ord = orderMap[dateKey];
      final int ordersCount = (ord?['orders_count'] as num?)?.toInt() ?? 0;
      final double revenue = (ord?['revenue'] as num?)?.toDouble() ?? 0.0;
      final double subtotal = (ord?['subtotal'] as num?)?.toDouble() ?? 0.0;
      final double deliveryIncome =
          (ord?['delivery_income'] as num?)?.toDouble() ?? 0.0;
      final double discounts = (ord?['discounts'] as num?)?.toDouble() ?? 0.0;
      final double pendingDebt =
          (ord?['pending_debt'] as num?)?.toDouble() ?? 0.0;

      final double cogs = cogsMap[dateKey] ?? 0.0;
      final double expenses = expMap[dateKey] ?? 0.0;

      final double grossProfit = revenue - cogs;
      final double netProfit = grossProfit - expenses;
      final double marginPct =
          revenue > 0 ? (netProfit / revenue) * 100.0 : 0.0;

      final double cashCollected = payMap[dateKey]?['cash'] ?? 0.0;
      final double onlineCollected = payMap[dateKey]?['online'] ?? 0.0;

      // Pure Profit = subtotal - discounts - cogs (no expenses, no delivery charges)
      final double pureProfit = subtotal - discounts - cogs;
      final double pureProfitPerOrder = ordersCount > 0 ? pureProfit / ordersCount : 0.0;

      runningAccumulatedProfit += netProfit;

      chronologicalList.add({
        'date': dateKey,
        'day_name': dayName,
        'display_date': "${curDate.day} ${_monthName(curDate.month)} ($dayName)",
        'orders_count': ordersCount,
        'revenue': revenue,
        'subtotal': subtotal,
        'cogs': cogs,
        'delivery_income': deliveryIncome,
        'discounts': discounts,
        'expenses': expenses,
        'gross_profit': grossProfit,
        'net_profit': netProfit,
        'accumulated_profit': runningAccumulatedProfit,
        'profit_margin_pct': marginPct,
        'is_profitable': netProfit >= 0,
        'cash_collected': cashCollected,
        'online_collected': onlineCollected,
        'pending_debt': pendingDebt,
        'pure_profit': pureProfit,
        'pure_profit_per_order': pureProfitPerOrder,
      });
    }

    // Return in reverse chronological order (newest first for UI listing)
    return chronologicalList.reversed.toList();
  }

  /// 7B. Today vs Yesterday Profit & Executive Comparison Summary
  Future<Map<String, dynamic>> getTodayVsYesterdayProfitSummary() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final yesterdayStr =
        "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

    final rows = await getDateWiseProfitBreakdown(
      startDate: yesterdayStr,
      endDate: todayStr,
      days: 2,
    );

    final Map<String, dynamic> todayData = rows.firstWhere(
      (r) => r['date'] == todayStr,
      orElse: () => {
        'date': todayStr,
        'day_name': 'Today',
        'display_date': 'Today',
        'orders_count': 0,
        'revenue': 0.0,
        'subtotal': 0.0,
        'cogs': 0.0,
        'delivery_income': 0.0,
        'discounts': 0.0,
        'expenses': 0.0,
        'gross_profit': 0.0,
        'net_profit': 0.0,
        'accumulated_profit': 0.0,
        'profit_margin_pct': 0.0,
        'is_profitable': true,
        'cash_collected': 0.0,
        'online_collected': 0.0,
        'pending_debt': 0.0,
        'pure_profit': 0.0,
        'pure_profit_per_order': 0.0,
      },
    );

    final Map<String, dynamic> yesterdayData = rows.firstWhere(
      (r) => r['date'] == yesterdayStr,
      orElse: () => {
        'date': yesterdayStr,
        'day_name': 'Yesterday',
        'display_date': 'Yesterday',
        'orders_count': 0,
        'revenue': 0.0,
        'subtotal': 0.0,
        'cogs': 0.0,
        'delivery_income': 0.0,
        'discounts': 0.0,
        'expenses': 0.0,
        'gross_profit': 0.0,
        'net_profit': 0.0,
        'accumulated_profit': 0.0,
        'profit_margin_pct': 0.0,
        'is_profitable': true,
        'cash_collected': 0.0,
        'online_collected': 0.0,
        'pending_debt': 0.0,
        'pure_profit': 0.0,
        'pure_profit_per_order': 0.0,
      },
    );

    final double todayProfit = (todayData['net_profit'] as num?)?.toDouble() ?? 0.0;
    final double yesterdayProfit = (yesterdayData['net_profit'] as num?)?.toDouble() ?? 0.0;
    final double profitDiff = todayProfit - yesterdayProfit;
    final double profitGrowthPct = yesterdayProfit != 0
        ? ((profitDiff / yesterdayProfit.abs()) * 100.0)
        : (todayProfit > 0 ? 100.0 : (todayProfit < 0 ? -100.0 : 0.0));

    final double todayPureProfit = (todayData['pure_profit'] as num?)?.toDouble() ?? 0.0;
    final double yesterdayPureProfit = (yesterdayData['pure_profit'] as num?)?.toDouble() ?? 0.0;
    final double pureProfitDiff = todayPureProfit - yesterdayPureProfit;

    final double todayRevenue = (todayData['revenue'] as num?)?.toDouble() ?? 0.0;
    final double yesterdayRevenue = (yesterdayData['revenue'] as num?)?.toDouble() ?? 0.0;
    final double revenueDiff = todayRevenue - yesterdayRevenue;

    final int todayOrders = (todayData['orders_count'] as num?)?.toInt() ?? 0;
    final int yesterdayOrders = (yesterdayData['orders_count'] as num?)?.toInt() ?? 0;
    final int ordersDiff = todayOrders - yesterdayOrders;

    return {
      'today': todayData,
      'yesterday': yesterdayData,
      'profit_diff': profitDiff,
      'profit_growth_pct': profitGrowthPct,
      'pure_profit_diff': pureProfitDiff,
      'revenue_diff': revenueDiff,
      'orders_diff': ordersDiff,
      'is_growth': profitDiff >= 0,
    };
  }

  /// 8. Item Profitability & Margin Ranking Matrix
  Future<Map<String, dynamic>> getItemProfitabilityMatrix({int days = 30}) async {
    final db = await _db;
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    final startStr =
        "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";

    final rows = await db.rawQuery('''
      SELECT 
        oi.item_name,
        COALESCE(i.id, '') AS item_id,
        COALESCE(i.category, 'General') AS category,
        COALESCE(i.unit, oi.item_unit) AS unit,
        COALESCE(i.cost_price, 0) AS current_cost_price,
        COALESCE(i.selling_price, 0) AS current_selling_price,
        COALESCE(SUM(oi.quantity), 0) AS total_qty_sold,
        COALESCE(SUM(oi.total_price), 0) AS total_revenue,
        COALESCE(SUM(
          CASE
            WHEN oi.item_id != '' AND (LOWER(COALESCE(oi.item_unit, '')) = 'gram' OR LOWER(COALESCE(oi.item_unit, '')) = 'gm') AND LOWER(COALESCE(i.unit, '')) = 'kg'
            THEN (oi.quantity / 1000.0) * COALESCE(i.cost_price, 0)
            WHEN oi.item_id != '' AND LOWER(COALESCE(oi.item_unit, '')) = 'kg' AND (LOWER(COALESCE(i.unit, '')) = 'gram' OR LOWER(COALESCE(i.unit, '')) = 'gm')
            THEN (oi.quantity * 1000.0) * COALESCE(i.cost_price, 0)
            ELSE oi.quantity * COALESCE(i.cost_price, 0)
          END
        ), 0) AS total_cogs
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      LEFT JOIN items i ON oi.item_id = i.id
      WHERE DATE(o.created_at) >= DATE(?) AND o.delivery_status != 'cancelled'
      GROUP BY oi.item_name
      HAVING total_revenue > 0
      ORDER BY (total_revenue - total_cogs) DESC
    ''', [startStr]);

    final List<Map<String, dynamic>> allItems = [];
    final List<Map<String, dynamic>> cashCows = [];
    final List<Map<String, dynamic>> highMargin = [];
    final List<Map<String, dynamic>> lowMarginRisk = [];

    double overallRevenue = 0;
    double overallCogs = 0;

    for (final r in rows) {
      final String name = r['item_name']?.toString() ?? 'Unnamed';
      final String cat = r['category']?.toString() ?? 'General';
      final String unit = r['unit']?.toString() ?? '';
      final double qty = (r['total_qty_sold'] as num?)?.toDouble() ?? 0.0;
      final double rev = (r['total_revenue'] as num?)?.toDouble() ?? 0.0;
      final double cogs = (r['total_cogs'] as num?)?.toDouble() ?? 0.0;
      final double currentCost =
          (r['current_cost_price'] as num?)?.toDouble() ?? 0.0;
      final double currentSelling =
          (r['current_selling_price'] as num?)?.toDouble() ?? 0.0;

      final double profit = rev - cogs;
      final double marginPct = rev > 0 ? (profit / rev) * 100.0 : 0.0;
      final double currentMarginPct = currentSelling > 0
          ? ((currentSelling - currentCost) / currentSelling) * 100.0
          : 0.0;

      overallRevenue += rev;
      overallCogs += cogs;

      final itemData = {
        'name': name,
        'category': cat,
        'unit': unit,
        'qty_sold': qty,
        'revenue': rev,
        'cogs': cogs,
        'profit': profit,
        'margin_pct': marginPct,
        'current_cost': currentCost,
        'current_selling': currentSelling,
        'current_margin_pct': currentMarginPct,
      };

      allItems.add(itemData);

      if (profit > 0 && marginPct >= 20.0) {
        cashCows.add(itemData);
      }
      if (marginPct >= 40.0) {
        highMargin.add(itemData);
      }
      if (marginPct < 12.0 || currentMarginPct < 12.0 || profit < 0) {
        lowMarginRisk.add(itemData);
      }
    }

    // Sort subsets
    cashCows.sort((a, b) => (b['profit'] as double).compareTo(a['profit'] as double));
    highMargin.sort((a, b) => (b['margin_pct'] as double).compareTo(a['margin_pct'] as double));
    lowMarginRisk.sort((a, b) => (a['margin_pct'] as double).compareTo(b['margin_pct'] as double));

    final double totalProfit = overallRevenue - overallCogs;
    final double overallMargin =
        overallRevenue > 0 ? (totalProfit / overallRevenue) * 100.0 : 0.0;

    return {
      'all_items': allItems,
      'cash_cows': cashCows.take(10).toList(),
      'high_margin_stars': highMargin.take(10).toList(),
      'low_margin_alerts': lowMarginRisk,
      'overall_revenue': overallRevenue,
      'overall_cogs': overallCogs,
      'overall_profit': totalProfit,
      'overall_margin_pct': overallMargin,
    };
  }

  /// 9. Customer Lifetime Value (CLV) & Profit Contribution Ranking
  Future<List<Map<String, dynamic>>> getCustomerProfitContribution({int limit = 50}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT 
        c.id AS customer_id,
        c.name,
        c.phone1,
        c.photo_path,
        c.outstanding_balance,
        c.is_vip,
        ord.total_orders,
        ord.total_revenue,
        ord.total_paid,
        COALESCE(cogs_sub.total_cogs, 0) AS total_cogs,
        ord.first_order_date,
        ord.last_order_date
      FROM customers c
      JOIN (
        SELECT 
          customer_id,
          COUNT(id) AS total_orders,
          COALESCE(SUM(grand_total), 0) AS total_revenue,
          COALESCE(SUM(paid_amount), 0) AS total_paid,
          MIN(created_at) AS first_order_date,
          MAX(created_at) AS last_order_date
        FROM orders
        WHERE delivery_status != 'cancelled'
        GROUP BY customer_id
      ) ord ON c.id = ord.customer_id
      LEFT JOIN (
        SELECT 
          o.customer_id,
          COALESCE(SUM(
            CASE
              WHEN oi.item_id != '' AND (LOWER(COALESCE(oi.item_unit, '')) = 'gram' OR LOWER(COALESCE(oi.item_unit, '')) = 'gm') AND LOWER(COALESCE(i.unit, '')) = 'kg'
              THEN (oi.quantity / 1000.0) * COALESCE(i.cost_price, 0)
              WHEN oi.item_id != '' AND LOWER(COALESCE(oi.item_unit, '')) = 'kg' AND (LOWER(COALESCE(i.unit, '')) = 'gram' OR LOWER(COALESCE(i.unit, '')) = 'gm')
              THEN (oi.quantity * 1000.0) * COALESCE(i.cost_price, 0)
              ELSE oi.quantity * COALESCE(i.cost_price, 0)
            END
          ), 0) AS total_cogs
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.id
        LEFT JOIN items i ON oi.item_id = i.id
        WHERE o.delivery_status != 'cancelled'
        GROUP BY o.customer_id
      ) cogs_sub ON c.id = cogs_sub.customer_id
      WHERE (c.is_archived IS NULL OR c.is_archived = 0)
      ORDER BY (ord.total_revenue - COALESCE(cogs_sub.total_cogs, 0)) DESC
      LIMIT ?
    ''', [limit]);

    return rows.map((r) {
      final double rev = (r['total_revenue'] as num?)?.toDouble() ?? 0.0;
      final double cogs = (r['total_cogs'] as num?)?.toDouble() ?? 0.0;
      final int count = (r['total_orders'] as num?)?.toInt() ?? 0;
      final double profit = rev - cogs;
      final double aov = count > 0 ? rev / count : 0.0;
      final double margin = rev > 0 ? (profit / rev) * 100.0 : 0.0;

      return {
        'customer_id': r['customer_id'],
        'name': r['name'] ?? 'Unknown',
        'phone': r['phone1'] ?? '',
        'photo_path': r['photo_path'] ?? '',
        'is_vip': (r['is_vip'] as num?)?.toInt() == 1,
        'outstanding_balance':
            (r['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
        'total_orders': count,
        'total_revenue': rev,
        'total_paid': (r['total_paid'] as num?)?.toDouble() ?? 0.0,
        'total_cogs': cogs,
        'profit_contribution': profit,
        'profit_margin_pct': margin,
        'aov': aov,
        'first_order_date': r['first_order_date'] ?? '',
        'last_order_date': r['last_order_date'] ?? '',
      };
    }).toList();
  }

  /// 10. Peak Sales Hours & Day-of-Week Distribution
  Future<Map<String, dynamic>> getPeakSalesHourlyAndDayOfWeek() async {
    final db = await _db;

    // 24 Hour Distribution
    final hourlyRows = await db.rawQuery('''
      SELECT 
        CAST(strftime('%H', created_at) AS INTEGER) AS hour,
        COUNT(id) AS orders_count,
        COALESCE(SUM(grand_total), 0) AS revenue
      FROM orders
      WHERE delivery_status != 'cancelled'
      GROUP BY hour
      ORDER BY hour ASC
    ''');

    final Map<int, Map<String, dynamic>> hourlyMap = {
      for (final r in hourlyRows)
        (r['hour'] as num).toInt(): {
          'count': (r['orders_count'] as num).toInt(),
          'revenue': (r['revenue'] as num).toDouble(),
        }
    };

    final List<Map<String, dynamic>> hourlyList = List.generate(24, (h) {
      final hourData = hourlyMap[h];
      final int cnt = hourData?['count'] ?? 0;
      final double rev = hourData?['revenue'] ?? 0.0;
      final String label = h == 0
          ? '12 AM'
          : (h < 12 ? '$h AM' : (h == 12 ? '12 PM' : '${h - 12} PM'));

      return {
        'hour': h,
        'label': label,
        'orders_count': cnt,
        'revenue': rev,
      };
    });

    int maxHour = 0;
    int maxHourOrders = 0;
    for (final h in hourlyList) {
      if ((h['orders_count'] as int) > maxHourOrders) {
        maxHourOrders = h['orders_count'] as int;
        maxHour = h['hour'] as int;
      }
    }

    // Day of Week Distribution (0 = Sunday, 1 = Monday ... 6 = Saturday)
    final dayRows = await db.rawQuery('''
      SELECT 
        CAST(strftime('%w', created_at) AS INTEGER) AS dow,
        COUNT(id) AS orders_count,
        COALESCE(SUM(grand_total), 0) AS revenue
      FROM orders
      WHERE delivery_status != 'cancelled'
      GROUP BY dow
      ORDER BY dow ASC
    ''');

    const List<String> dowLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final Map<int, Map<String, dynamic>> dowMap = {
      for (final r in dayRows)
        (r['dow'] as num).toInt(): {
          'count': (r['orders_count'] as num).toInt(),
          'revenue': (r['revenue'] as num).toDouble(),
        }
    };

    final List<Map<String, dynamic>> dowList = List.generate(7, (d) {
      final dData = dowMap[d];
      final int cnt = dData?['count'] ?? 0;
      final double rev = dData?['revenue'] ?? 0.0;
      return {
        'dow': d,
        'name': dowLabels[d],
        'orders_count': cnt,
        'revenue': rev,
      };
    });

    String bestDay = 'Sunday';
    double bestDayRevenue = 0;
    for (final d in dowList) {
      if ((d['revenue'] as double) > bestDayRevenue) {
        bestDayRevenue = d['revenue'] as double;
        bestDay = d['name'] as String;
      }
    }

    return {
      'hourly': hourlyList,
      'peak_hour': hourlyList[maxHour]['label'],
      'peak_hour_orders': maxHourOrders,
      'days_of_week': dowList,
      'best_day': bestDay,
      'best_day_revenue': bestDayRevenue,
    };
  }

  /// 11. Dead Stock, Stockout Risk & Spoilage Loss Intelligence
  Future<Map<String, dynamic>> getDeadStockAndTurnover({int deadStockDays = 14}) async {
    final db = await _db;
    final now = DateTime.now();
    final threshold = now.subtract(Duration(days: deadStockDays)).toIso8601String();

    // Dead Stock: stock > 0, but no orders since threshold
    final deadRows = await db.rawQuery('''
      SELECT 
        i.id,
        i.name,
        i.category,
        i.stock,
        i.unit,
        i.cost_price,
        i.selling_price,
        MAX(o.created_at) AS last_sold_date
      FROM items i
      LEFT JOIN order_items oi ON i.id = oi.item_id
      LEFT JOIN orders o ON oi.order_id = o.id AND o.delivery_status != 'cancelled'
      WHERE i.is_archived = 0 AND i.stock > 0
      GROUP BY i.id
      HAVING last_sold_date IS NULL OR last_sold_date < ?
      ORDER BY (i.stock * i.cost_price) DESC
    ''', [threshold]);

    double totalCapitalLocked = 0;
    final List<Map<String, dynamic>> deadItems = [];

    for (final r in deadRows) {
      final double stock = (r['stock'] as num?)?.toDouble() ?? 0.0;
      final double cost = (r['cost_price'] as num?)?.toDouble() ?? 0.0;
      final double locked = stock * cost;
      totalCapitalLocked += locked;

      final String lastSold = r['last_sold_date']?.toString() ?? '';
      int daysSince = 999;
      if (lastSold.isNotEmpty) {
        final dt = DateTime.tryParse(lastSold);
        if (dt != null) {
          daysSince = now.difference(dt).inDays;
        }
      }

      deadItems.add({
        'name': r['name'] ?? 'Unnamed',
        'category': r['category'] ?? 'General',
        'stock': stock,
        'unit': r['unit'] ?? '',
        'cost_price': cost,
        'selling_price': (r['selling_price'] as num?)?.toDouble() ?? 0.0,
        'capital_locked': locked,
        'days_since_sold': daysSince >= 900 ? 'Never Sold' : '$daysSince days ago',
      });
    }

    // Spoilage / Wastage Loss
    final spillageRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(ABS(sh.change_amount) * COALESCE(i.cost_price, 0)), 0) AS total_loss,
        COUNT(sh.id) AS log_count
      FROM stock_history sh
      LEFT JOIN items i ON sh.item_id = i.id
      WHERE (LOWER(sh.reason) LIKE '%spill%' OR LOWER(sh.reason) LIKE '%damage%' OR LOWER(sh.reason) LIKE '%waste%' OR LOWER(sh.reason) LIKE '%rot%')
    ''');
    final double spillageLoss =
        (spillageRes.first['total_loss'] as num?)?.toDouble() ?? 0.0;
    final int spillageCount =
        (spillageRes.first['log_count'] as num?)?.toInt() ?? 0;

    return {
      'dead_stock_items': deadItems,
      'dead_stock_count': deadItems.length,
      'capital_locked': totalCapitalLocked,
      'spillage_loss': spillageLoss,
      'spillage_count': spillageCount,
    };
  }

  /// 12. Cashflow & Debt Aging Intelligence
  Future<Map<String, dynamic>> getCashflowAndDebtAging() async {
    final db = await _db;
    final now = DateTime.now();

    // 1. Payment Methods split
    final payRes = await db.rawQuery('''
      SELECT 
        p.method,
        COALESCE(SUM(p.amount), 0) AS total_amount,
        COUNT(p.id) AS tx_count
      FROM payments p
      JOIN orders o ON p.order_id = o.id
      WHERE o.delivery_status != 'cancelled'
      GROUP BY p.method
      ORDER BY total_amount DESC
    ''');

    double totalCollected = 0;
    for (final r in payRes) {
      totalCollected += (r['total_amount'] as num?)?.toDouble() ?? 0.0;
    }

    final List<Map<String, dynamic>> paymentSplits = payRes.map((r) {
      final double amt = (r['total_amount'] as num?)?.toDouble() ?? 0.0;
      final double pct = totalCollected > 0 ? (amt / totalCollected) * 100.0 : 0.0;
      return {
        'method': r['method']?.toString().toUpperCase() ?? 'OTHER',
        'amount': amt,
        'count': (r['tx_count'] as num?)?.toInt() ?? 0,
        'percentage': pct,
      };
    }).toList();

    // 2. Debt Aging (0-7d, 8-14d, 15-30d, 30+d)
    final ordersWithDebt = await db.rawQuery('''
      SELECT 
        o.id,
        o.remaining_amount,
        o.created_at,
        c.name AS customer_name,
        c.phone1 AS phone
      FROM orders o
      JOIN customers c ON o.customer_id = c.id
      WHERE o.remaining_amount > 0 AND o.delivery_status != 'cancelled'
      ORDER BY o.created_at ASC
    ''');

    double age0to7 = 0;
    int count0to7 = 0;
    double age8to14 = 0;
    int count8to14 = 0;
    double age15to30 = 0;
    int count15to30 = 0;
    double age30Plus = 0;
    int count30Plus = 0;

    final List<Map<String, dynamic>> overdueOrders = [];

    for (final r in ordersWithDebt) {
      final double rem = (r['remaining_amount'] as num?)?.toDouble() ?? 0.0;
      final String created = r['created_at']?.toString() ?? '';
      final dt = DateTime.tryParse(created) ?? now;
      final int age = now.difference(dt).inDays;

      if (age <= 7) {
        age0to7 += rem;
        count0to7++;
      } else if (age <= 14) {
        age8to14 += rem;
        count8to14++;
      } else if (age <= 30) {
        age15to30 += rem;
        count15to30++;
      } else {
        age30Plus += rem;
        count30Plus++;
      }

      if (age > 7) {
        overdueOrders.add({
          'order_id': r['id'],
          'customer_name': r['customer_name'] ?? 'Unknown',
          'phone': r['phone'] ?? '',
          'amount': rem,
          'age_days': age,
        });
      }
    }

    final double totalPending = age0to7 + age8to14 + age15to30 + age30Plus;

    return {
      'payment_splits': paymentSplits,
      'total_collected': totalCollected,
      'total_pending': totalPending,
      'aging': {
        '0_7_days': {'amount': age0to7, 'count': count0to7},
        '8_14_days': {'amount': age8to14, 'count': count8to14},
        '15_30_days': {'amount': age15to30, 'count': count15to30},
        '30_plus_days': {'amount': age30Plus, 'count': count30Plus},
      },
      'overdue_orders': overdueOrders,
    };
  }

  static String _monthName(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (m >= 1 && m <= 12) return months[m - 1];
    return '';
  }
}

