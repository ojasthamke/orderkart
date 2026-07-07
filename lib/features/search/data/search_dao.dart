import '../../../core/database/database_helper.dart';
import '../domain/search_result.dart';

class SearchDao {
  Future<List<SearchResult>> globalSearch(String query) async {
    if (query.trim().isEmpty) return [];

    final db = await DatabaseHelper.instance.database;
    final q = '%${query.trim()}%';
    
    // Support parsing order numbers like #007 or 007 or 7
    String cleanNumStr = query.trim();
    if (cleanNumStr.startsWith('#')) {
      cleanNumStr = cleanNumStr.substring(1);
    }
    cleanNumStr = cleanNumStr.replaceFirst(RegExp(r'^0+'), '');
    final int? searchInt = int.tryParse(cleanNumStr.isNotEmpty ? cleanNumStr : query.trim());

    final List<SearchResult> results = [];

    // 1. Search Customers (including phone2, whatsapp, street name, area name)
    final customers = await db.rawQuery('''
      SELECT c.*, s.name AS street_name, a.name AS area_name
      FROM customers c
      LEFT JOIN streets s ON c.street_id = s.id
      LEFT JOIN areas a ON s.area_id = a.id
      WHERE c.name LIKE ? OR c.phone1 LIKE ? OR c.phone2 LIKE ? OR c.whatsapp LIKE ?
         OR c.house_number LIKE ? OR c.address LIKE ? OR s.name LIKE ? OR a.name LIKE ?
      LIMIT 15
    ''', [q, q, q, q, q, q, q, q]);

    for (final c in customers) {
      final street = c['street_name'] as String? ?? '';
      final area = c['area_name'] as String? ?? '';
      final loc = [if (street.isNotEmpty) street, if (area.isNotEmpty) area].join(', ');
      results.add(SearchResult(
        id:       c['id'] as String,
        title:    c['name'] as String,
        subtitle: 'Customer • ${c['phone1']} ${loc.isNotEmpty ? "($loc)" : ""}',
        type:     SearchResultType.customer,
      ));
    }

    // 2. Search Items
    final items = await db.query(
      'items',
      where: 'name LIKE ? OR category LIKE ? OR barcode LIKE ?',
      whereArgs: [q, q, q],
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

    // 5. Search Orders (By customer name/phone via JOIN, or by sequential number/rowid)
    final orders = await db.rawQuery('''
      SELECT o.*, o.rowid AS order_number, c.name AS customer_name
      FROM orders o
      LEFT JOIN customers c ON o.customer_id = c.id
      WHERE c.name LIKE ? OR o.id LIKE ? OR c.phone1 LIKE ? OR c.phone2 LIKE ? ${searchInt != null ? 'OR o.rowid = ?' : ''}
      LIMIT 15
    ''', [q, q, q, q, if (searchInt != null) searchInt]);
    for (final o in orders) {
      final orderId = o['id'] as String;
      results.add(SearchResult(
        id:       orderId,
        title:    'Order $orderId',
        subtitle: 'Order • Customer: ${o['customer_name']} • Total: ₹${o['grand_total']} (${o['delivery_status']})',
        type:     SearchResultType.order,
      ));
    }

    return results;
  }
}
