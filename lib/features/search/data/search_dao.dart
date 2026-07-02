import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../domain/search_result.dart';

class SearchDao {
  Future<List<SearchResult>> globalSearch(String query) async {
    if (query.trim().isEmpty) return [];

    final db = await DatabaseHelper.instance.database;
    final q = '%${query.trim()}%';
    final List<SearchResult> results = [];

    // 1. Search Customers
    final customers = await db.query(
      'customers',
      where: 'name LIKE ? OR phone1 LIKE ? OR house_number LIKE ? OR address LIKE ?',
      whereArgs: [q, q, q, q],
      limit: 10,
    );
    for (final c in customers) {
      results.add(SearchResult(
        id:       c['id'] as String,
        title:    c['name'] as String,
        subtitle: 'Customer • ${c['phone1']}',
        type:     SearchResultType.customer,
      ));
    }

    // 2. Search Items
    final items = await db.query(
      'items',
      where: 'name LIKE ? OR category LIKE ?',
      whereArgs: [q, q],
      limit: 10,
    );
    for (final item in items) {
      results.add(SearchResult(
        id:       item['id'] as String,
        title:    item['name'] as String,
        subtitle: 'Item • Category: ${item['category']} • Rate: ₹${item['selling_price']}',
        type:     SearchResultType.item,
      ));
    }

    // 3. Search Areas
    final areas = await db.query(
      'areas',
      where: 'name LIKE ? OR description LIKE ?',
      whereArgs: [q, q],
      limit: 5,
    );
    for (final a in areas) {
      results.add(SearchResult(
        id:       a['id'] as String,
        title:    a['name'] as String,
        subtitle: 'Area • ${a['description']}',
        type:     SearchResultType.area,
      ));
    }

    // 4. Search Streets
    final streets = await db.query(
      'streets',
      where: 'name LIKE ? OR description LIKE ?',
      whereArgs: [q, q],
      limit: 5,
    );
    for (final s in streets) {
      results.add(SearchResult(
        id:       s['id'] as String,
        title:    s['name'] as String,
        subtitle: 'Street • ${s['description']}',
        type:     SearchResultType.street,
      ));
    }

    // 5. Search Orders (By customer name via JOIN, or by ID)
    final orders = await db.rawQuery('''
      SELECT o.*, c.name AS customer_name
      FROM orders o
      JOIN customers c ON o.customer_id = c.id
      WHERE c.name LIKE ? OR o.id LIKE ?
      LIMIT 10
    ''', [q, q]);
    for (final o in orders) {
      results.add(SearchResult(
        id:       o['id'] as String,
        title:    'Order #${(o['id'] as String).substring(0, 8).toUpperCase()}',
        subtitle: 'Order • Customer: ${o['customer_name']} • Total: ₹${o['grand_total']} (${o['delivery_status']})',
        type:     SearchResultType.order,
      ));
    }

    return results;
  }
}
