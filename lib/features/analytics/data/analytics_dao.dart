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
      LEFT JOIN orders o ON o.assigned_worker_id = w.id AND o.delivery_status != 'cancelled'
      WHERE w.is_archived = 0
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
        COUNT(o.id) AS total_orders,
        COALESCE(SUM(o.grand_total), 0) AS total_sales,
        COALESCE(SUM(o.paid_amount), 0) AS total_collection,
        COALESCE(SUM(o.remaining_amount), 0) AS total_outstanding
      FROM locations a
      LEFT JOIN locations s ON s.parent_location_id = a.id AND s.location_kind = 'road' AND s.is_archived = 0
      LEFT JOIN customers c ON c.location_id = s.id
      LEFT JOIN orders o ON o.customer_id = c.id AND o.delivery_status != 'cancelled'
      WHERE a.location_kind = 'area' AND a.is_archived = 0
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
        COUNT(o.id) AS total_orders,
        COALESCE(SUM(o.grand_total), 0) AS total_sales,
        COALESCE(SUM(o.paid_amount), 0) AS total_collection,
        COALESCE(SUM(o.remaining_amount), 0) AS total_outstanding
      FROM locations s
      JOIN locations a ON s.parent_location_id = a.id AND a.location_kind = 'area' AND a.is_archived = 0
      LEFT JOIN customers c ON c.location_id = s.id
      LEFT JOIN orders o ON o.customer_id = c.id AND o.delivery_status != 'cancelled'
      WHERE s.location_kind = 'road' AND s.is_archived = 0
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
      WHERE is_archived = 0
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
        (SELECT COALESCE(SUM(grand_total), 0) FROM orders WHERE delivery_status != 'cancelled') AS total_sales,
        (SELECT COALESCE(SUM(oi.quantity * i.cost_price), 0) 
         FROM order_items oi
         JOIN orders o ON oi.order_id = o.id
         LEFT JOIN items i ON oi.item_id = i.id
         WHERE o.delivery_status != 'cancelled') AS total_cost
    ''');
    
    final double sales = (salesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final double cost = (salesRes.first['total_cost'] as num?)?.toDouble() ?? 0.0;

    // Sum of expenses
    final expRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total_expenses FROM expenses
    ''');
    final double expenses = (expRes.first['total_expenses'] as num?)?.toDouble() ?? 0.0;

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
      WHERE delivery_status != 'cancelled'
    ''');

    final double sales = (res.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final double collection = (res.first['total_collection'] as num?)?.toDouble() ?? 0.0;
    final double outstanding = (res.first['total_outstanding'] as num?)?.toDouble() ?? 0.0;

    final double efficiency = sales > 0 ? (collection / sales) * 100.0 : 100.0;

    return {
      'total_sales': sales,
      'total_collection': collection,
      'total_outstanding': outstanding,
      'collection_efficiency_pct': efficiency,
    };
  }
}
