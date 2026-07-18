import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../domain/item.dart';
import '../domain/stock_history.dart';
import '../../../core/services/notification_service.dart';

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

    final maps = await db.query('items',
        where: where, whereArgs: args.isEmpty ? null : args);
    final items = maps.map(Item.fromMap).toList();

    if (sortBy == null || sortBy.isEmpty || sortBy == 'category') {
      items.sort((a, b) {
        final aNo = a.sequenceNo;
        final bNo = b.sequenceNo;
        if (aNo == 0 && bNo == 0) {
          if (sortBy == 'category') {
            final catComp = a.category.compareTo(b.category);
            if (catComp != 0) return catComp;
          }
          return a.createdAt.compareTo(b.createdAt);
        }
        if (aNo == 0) return 1;
        if (bNo == 0) return -1;
        return aNo.compareTo(bNo);
      });
    } else {
      if (sortBy == 'stock_asc') {
        items.sort((a, b) => a.stock.compareTo(b.stock));
      } else if (sortBy == 'price_desc') {
        items.sort((a, b) => b.sellingPrice.compareTo(a.sellingPrice));
      } else if (sortBy == 'shuffle') {
        items.shuffle();
      }
    }
    return items;
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
    await _checkAndTriggerLowStock(id, db);
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
    await _checkAndTriggerLowStock(item.id, db);
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

  Future<List<Map<String, dynamic>>> getPriceHistoryDateRange(String startDate, String endDate) async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT h.*, i.name, i.unit, i.category
      FROM item_price_history h
      JOIN items i ON h.item_id = i.id
      WHERE h.date >= ? AND h.date <= ?
      ORDER BY h.date DESC, i.name ASC
    ''', [startDate, endDate]);
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
    await _checkAndTriggerLowStock(itemId, db);
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
  Future<void> _checkAndTriggerLowStock(String itemId, DatabaseExecutor db) async {
    try {
      final itemRes = await db.query(
        'items',
        columns: ['name', 'stock', 'min_stock', 'unit'],
        where: 'id = ?',
        whereArgs: [itemId],
      );
      if (itemRes.isNotEmpty) {
        final item = itemRes.first;
        final name = item['name'] as String? ?? '';
        final stock = (item['stock'] as num?)?.toDouble() ?? 0.0;
        final minStock = (item['min_stock'] as num?)?.toDouble() ?? 0.0;
        final unit = item['unit'] as String? ?? 'pcs';
        if (minStock > 0 && stock <= minStock) {
          await NotificationService.instance.showNotification(
            id: itemId.hashCode,
            title: '⚠️ Low Stock Alert: $name',
            body: 'Inventory for "$name" is down to $stock $unit. Reorder immediately to avoid stockouts.',
            payload: 'low_stock',
          );
        }
      }
    } catch (_) {}
  }

  Future<void> updateItemSequences(List<String> itemIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (int i = 0; i < itemIds.length; i++) {
        await txn.update(
          'items',
          {'sequence_no': i + 1, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [itemIds[i]],
        );
      }
    });
  }

  Future<List<StockHistory>> getSpillageHistory() async {
    final db = await _db;
    final maps = await db.query(
      'stock_history',
      where: "reason LIKE 'Wastage%'",
      orderBy: 'created_at DESC',
    );
    return maps.map(StockHistory.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> getOrderedItemStats() async {
    final db = await _db;
    return await db.rawQuery(
      '''
      SELECT 
        i.name AS item_name,
        i.unit AS item_unit,
        i.cost_price AS cost_price,
        SUM(oi.quantity) AS total_quantity,
        SUM(oi.quantity) * i.cost_price AS total_cost_price,
        SUM(oi.total_price) AS total_selling_price,
        SUM(oi.total_price) - (SUM(oi.quantity) * i.cost_price) AS total_profit
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      JOIN items i ON oi.item_id = i.id
      WHERE o.delivery_status != 'cancelled'
      GROUP BY oi.item_id, i.name, i.unit, i.cost_price
      ORDER BY total_profit DESC, total_quantity DESC
      '''
    );
  }
}
