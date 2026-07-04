import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../domain/item.dart';
import '../domain/stock_history.dart';

class ItemDao {
  final _uuid = const Uuid();
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    return executor ?? await _db;
  }

  Future<List<Item>> getAllItems({String? category, String? searchQuery, String? sortBy}) async {
    final db = await _db;
    List<String> conditions = [];
    List<dynamic> args = [];
    if (category != null && category.isNotEmpty) {
      conditions.add('category = ?');
      args.add(category);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('name LIKE ?');
      args.add('%${searchQuery.trim()}%');
    }
    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    String orderBy = 'name ASC';
    if (sortBy == 'stock_asc') orderBy = 'stock ASC';
    if (sortBy == 'price_desc') orderBy = 'selling_price DESC';
    if (sortBy == 'category') orderBy = 'category ASC, name ASC';

    final maps = await db.query('items',
        where: where, whereArgs: args.isEmpty ? null : args, orderBy: orderBy);
    return maps.map(Item.fromMap).toList();
  }

  Future<Item?> getItemById(String id, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    final maps = await db.query('items', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Item.fromMap(maps.first);
  }

  Future<List<Item>> getLowStockItems() async {
    final db = await _db;
    final maps = await db.rawQuery(
        'SELECT * FROM items WHERE min_stock > 0 AND stock <= min_stock ORDER BY stock ASC');
    return maps.map(Item.fromMap).toList();
  }

  Future<String> insertItem(Item item) async {
    final db = await _db;
    final id  = item.id.isEmpty ? _uuid.v4() : item.id;
    final now = DateTime.now().toIso8601String();
    final itemWithId = item.copyWith(id: id);
    await db.insert('items', {
      ...itemWithId.toMap(),
      'id':         id,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _recordDailyPriceSnapshot(itemWithId);
    return id;
  }

  Future<void> updateItem(Item item) async {
    final db = await _db;
    await db.update(
      'items',
      {...item.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [item.id],
    );

    await _recordDailyPriceSnapshot(item);
  }

  Future<void> _recordDailyPriceSnapshot(Item item) async {
    final db = await _db;
    final dateKey = DateTime.now().toIso8601String().substring(0, 10);
    await db.rawInsert('''
      INSERT OR REPLACE INTO item_price_history (id, item_id, date, selling_price, market_price, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      '${item.id}_$dateKey',
      item.id,
      dateKey,
      item.sellingPrice,
      item.marketPrice,
      DateTime.now().toIso8601String(),
    ]);
  }

  Future<List<Map<String, dynamic>>> getPriceHistoryByDate(String date) async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT h.*, i.name, i.unit, i.category
      FROM item_price_history h
      JOIN items i ON h.item_id = i.id
      WHERE h.date = ?
      ORDER BY i.name ASC
    ''', [date]);
  }

  Future<List<Map<String, dynamic>>> getItemPriceHistory(String itemId) async {
    final db = await _db;
    return await db.query('item_price_history',
        where: 'item_id = ?', whereArgs: [itemId], orderBy: 'date DESC');
  }

  Future<void> deleteItem(String id) async {
    final db = await _db;
    await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> adjustStock(String itemId, double change, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    await db.rawUpdate(
        'UPDATE items SET stock = stock + ?, updated_at = ? WHERE id = ?',
        [change, DateTime.now().toIso8601String(), itemId]);
  }

  // Stock History
  Future<void> insertStockHistory(StockHistory sh, {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    await db.insert('stock_history', {
      ...sh.toMap(),
      'id': sh.id.isEmpty ? _uuid.v4() : sh.id,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<StockHistory>> getStockHistory(String itemId) async {
    final db = await _db;
    final maps = await db.query('stock_history',
        where: 'item_id = ?',
        whereArgs: [itemId],
        orderBy: 'created_at DESC',
        limit: 50);
    return maps.map(StockHistory.fromMap).toList();
  }
}
