import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../domain/item.dart';
import '../domain/stock_history.dart';

class ItemDao {
  final _uuid = const Uuid();
  Future<Database> get _db => DatabaseHelper.instance.database;

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

  Future<Item?> getItemById(String id) async {
    final db = await _db;
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
    await db.insert('items', {
      ...item.toMap(),
      'id':         id,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
  }

  Future<void> deleteItem(String id) async {
    final db = await _db;
    await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> adjustStock(String itemId, double change) async {
    final db = await _db;
    await db.rawUpdate(
        'UPDATE items SET stock = stock + ?, updated_at = ? WHERE id = ?',
        [change, DateTime.now().toIso8601String(), itemId]);
  }

  // Stock History
  Future<void> insertStockHistory(StockHistory sh) async {
    final db = await _db;
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
