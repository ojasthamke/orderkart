import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../core/utils/marathi_item_helper.dart';
import '../domain/item.dart';
import '../domain/stock_history.dart';
import '../../../core/services/notification_service.dart';

class ItemDao {
  final _uuid = const Uuid();
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<DatabaseExecutor> _getExecutor(DatabaseExecutor? executor) async {
    return executor ?? await _db;
  }

  Future<List<Item>> getAllItems(
      {String? category, String? searchQuery, String? sortBy}) async {
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

    if (sortBy == null ||
        sortBy.isEmpty ||
        sortBy == 'category' ||
        sortBy == 'name') {
      items.sort((a, b) {
        final aNo = a.sequenceNo;
        final bNo = b.sequenceNo;
        if (aNo == 0 && bNo == 0) {
          if (sortBy == 'category') {
            final catComp = a.category.compareTo(b.category);
            if (catComp != 0) return catComp;
            final nameComp =
                a.name.toLowerCase().compareTo(b.name.toLowerCase());
            if (nameComp != 0) return nameComp;
          } else if (sortBy == 'name') {
            final nameComp =
                a.name.toLowerCase().compareTo(b.name.toLowerCase());
            if (nameComp != 0) return nameComp;
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
        'SELECT * FROM items WHERE min_stock > 0 AND stock <= min_stock AND stock > 0 ORDER BY stock ASC');
    return maps.map(Item.fromMap).toList();
  }

  Future<String> insertItem(Item item) async {
    final db = await _db;
    final id = item.id.isEmpty ? _uuid.v4() : item.id;
    final now = DateTime.now().toIso8601String();
    final itemWithId = item.copyWith(id: id);

    await db.transaction((txn) async {
      await txn.insert(
          'items',
          {
            ...itemWithId.toMap(),
            'id': id,
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      if (itemWithId.stock > 0) {
        await insertStockHistory(
            StockHistory(
              id: _uuid.v4(),
              itemId: id,
              itemName: itemWithId.name,
              changeAmount: itemWithId.stock,
              reason: 'Initial Stock Allocation',
              orderId: '',
              createdAt: DateTime.now(),
            ),
            executor: txn);
      }

      final dateKey = now.substring(0, 10);
      await txn.rawInsert('''
        INSERT OR REPLACE INTO item_price_history (id, item_id, date, selling_price, cost_price, market_price, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [
        '${itemWithId.id}_$dateKey',
        itemWithId.id,
        dateKey,
        itemWithId.sellingPrice,
        itemWithId.costPrice,
        itemWithId.marketPrice,
        now,
      ]);
    });

    await _checkAndTriggerLowStock(id, db, previousStock: 999999);
    return id;
  }

  Future<void> updateItem(Item item) async {
    final db = await _db;
    final oldItem = await getItemById(item.id);
    await db.transaction((txn) async {
      await txn.update(
        'items',
        {...item.toMap(), 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [item.id],
      );

      if (oldItem != null) {
        final stockDiff = item.stock - oldItem.stock;
        if (stockDiff != 0) {
          await txn.insert('stock_history', {
            'id': _uuid.v4(),
            'item_id': item.id,
            'item_name': item.name,
            'change_amount': stockDiff,
            'reason': 'Manual Inventory Update (Edit)',
            'order_id': '',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    });

    await _recordDailyPriceSnapshot(item);
    await _checkAndTriggerLowStock(item.id, db);
  }

  Future<void> updateItems(List<Item> items) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final item in items) {
        final maps =
            await txn.query('items', where: 'id = ?', whereArgs: [item.id]);
        final oldItem = maps.isNotEmpty ? Item.fromMap(maps.first) : null;

        await txn.update(
          'items',
          {...item.toMap(), 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [item.id],
        );

        if (oldItem != null) {
          final stockDiff = item.stock - oldItem.stock;
          if (stockDiff != 0) {
            await txn.insert('stock_history', {
              'id': _uuid.v4(),
              'item_id': item.id,
              'item_name': item.name,
              'change_amount': stockDiff,
              'reason': 'Bulk Inventory Adjust',
              'order_id': '',
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }

        final dateKey = DateTime.now().toIso8601String().substring(0, 10);
        await txn.rawInsert('''
          INSERT OR REPLACE INTO item_price_history (id, item_id, date, selling_price, cost_price, market_price, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', [
          '${item.id}_$dateKey',
          item.id,
          dateKey,
          item.sellingPrice,
          item.costPrice,
          item.marketPrice,
          DateTime.now().toIso8601String(),
        ]);

        if (item.minStock > 0 && item.stock <= item.minStock) {
          await _checkAndTriggerLowStock(item.id, txn);
        }
      }
    });
  }

  Future<void> _recordDailyPriceSnapshot(Item item) async {
    final db = await _db;
    final dateKey = DateTime.now().toIso8601String().substring(0, 10);
    await db.rawInsert('''
      INSERT OR REPLACE INTO item_price_history (id, item_id, date, selling_price, cost_price, market_price, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      '${item.id}_$dateKey',
      item.id,
      dateKey,
      item.sellingPrice,
      item.costPrice,
      item.marketPrice,
      DateTime.now().toIso8601String(),
    ]);
  }

  Future<List<Map<String, dynamic>>> getPriceHistoryByDate(String date) async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT h.*, COALESCE(i.name, 'Archived Item') AS name, COALESCE(i.unit, '') AS unit, COALESCE(i.category, '') AS category
      FROM item_price_history h
      LEFT JOIN items i ON h.item_id = i.id
      WHERE h.date = ?
      ORDER BY name ASC
    ''', [date]);
  }

  Future<List<Map<String, dynamic>>> getPriceHistoryDateRange(
      String startDate, String endDate) async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT h.*, COALESCE(i.name, 'Archived Item') AS name, COALESCE(i.unit, '') AS unit, COALESCE(i.category, '') AS category
      FROM item_price_history h
      LEFT JOIN items i ON h.item_id = i.id
      WHERE h.date >= ? AND h.date <= ?
      ORDER BY h.date DESC, name ASC
    ''', [startDate, endDate]);
  }

  Future<List<Map<String, dynamic>>> getItemPriceHistory(String itemId) async {
    final db = await _db;
    return await db.query('item_price_history',
        where: 'item_id = ?', whereArgs: [itemId], orderBy: 'date DESC');
  }

  Future<void> deleteItem(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('stock_history', where: 'item_id = ?', whereArgs: [id]);
      await txn
          .delete('item_price_history', where: 'item_id = ?', whereArgs: [id]);
      await txn.delete('items', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> adjustStock(String itemId, double change,
      {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    await db.rawUpdate(
        'UPDATE items SET stock = stock + ?, updated_at = ? WHERE id = ?',
        [change, DateTime.now().toIso8601String(), itemId]);
    await _checkAndTriggerLowStock(itemId, db);
  }

  // Stock History
  Future<void> insertStockHistory(StockHistory sh,
      {DatabaseExecutor? executor}) async {
    final db = await _getExecutor(executor);
    await db.insert(
        'stock_history',
        {
          ...sh.toMap(),
          'id': sh.id.isEmpty ? _uuid.v4() : sh.id,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<void> _checkAndTriggerLowStock(
      String itemId, DatabaseExecutor db, {double? previousStock}) async {
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
        final prev = previousStock ?? (stock + 1);
        if (minStock > 0 && stock <= minStock && prev > minStock) {
          await NotificationService.instance.showNotification(
            id: itemId.hashCode,
            title: '⚠️ Low Stock Alert: $name',
            body:
                'Inventory for "$name" is down to $stock $unit. Reorder immediately to avoid stockouts.',
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
          {
            'sequence_no': i + 1,
            'updated_at': DateTime.now().toIso8601String()
          },
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

  Future<List<Map<String, dynamic>>> getOrderedItemStats({
    String status = 'all',
    String dateFilter = 'all',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _db;
    String whereClause =
        "(o.delivery_status IS NULL OR o.delivery_status != 'cancelled')";
    List<dynamic> args = [];
    if (status != 'all' && status.isNotEmpty) {
      whereClause += " AND o.delivery_status = ?";
      args.add(status);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    if (startDate != null && endDate != null) {
      final startStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(endDate);
      whereClause += " AND DATE(o.created_at) >= DATE(?) AND DATE(o.created_at) <= DATE(?)";
      args.add(startStr);
      args.add(endStr);
    } else if (dateFilter == 'today') {
      whereClause += " AND DATE(o.created_at) = DATE(?)";
      args.add(todayStr);
    } else if (dateFilter == 'yesterday') {
      final yest = today.subtract(const Duration(days: 1));
      final yestStr = DateFormat('yyyy-MM-dd').format(yest);
      whereClause += " AND DATE(o.created_at) = DATE(?)";
      args.add(yestStr);
    } else if (dateFilter == 'week') {
      final start = today.subtract(const Duration(days: 7));
      final startStr = DateFormat('yyyy-MM-dd').format(start);
      whereClause += " AND DATE(o.created_at) >= DATE(?) AND DATE(o.created_at) <= DATE(?)";
      args.add(startStr);
      args.add(todayStr);
    } else if (dateFilter == 'month') {
      final start = DateTime(now.year, now.month, 1);
      final startStr = DateFormat('yyyy-MM-dd').format(start);
      whereClause += " AND DATE(o.created_at) >= DATE(?) AND DATE(o.created_at) <= DATE(?)";
      args.add(startStr);
      args.add(todayStr);
    }

    final rawRows = await db.rawQuery('''
      SELECT 
        oi.id AS order_item_id,
        oi.order_id,
        oi.item_id,
        oi.item_name,
        oi.item_unit,
        oi.quantity,
        oi.unit_price,
        oi.total_price,
        i.id AS inv_id,
        i.name AS inv_name,
        i.unit AS inv_unit,
        i.cost_price AS inv_cost_price,
        i.selling_price AS inv_selling_price,
        i.weight_per_piece AS inv_weight_per_piece,
        i.category AS inv_category,
        i.stock AS inv_stock
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      LEFT JOIN items i ON (
        (oi.item_id IS NOT NULL AND oi.item_id != '' AND oi.item_id = i.id)
        OR (LOWER(TRIM(oi.item_name)) = LOWER(TRIM(i.name)))
      )
      WHERE $whereClause
      ORDER BY o.created_at DESC
    ''', args);

    // Group items accurately in Dart to prevent duplicates across orders
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final row in rawRows) {
      final rawName = (row['item_name']?.toString() ?? 'Unknown').trim();
      final invName = row['inv_name']?.toString().trim();
      final invId = row['inv_id']?.toString().trim();
      final rawItemId = row['item_id']?.toString().trim();
      final resolvedItemId = (invId != null && invId.isNotEmpty) ? invId : (rawItemId ?? '');

      // Canonical identity key: prioritize inventory ID, fallback to normalized name
      final String groupKey;
      if (invId != null && invId.isNotEmpty) {
        groupKey = 'id:$invId';
      } else if (rawItemId != null && rawItemId.isNotEmpty) {
        groupKey = 'id:$rawItemId';
      } else {
        groupKey = 'name:${rawName.toLowerCase()}';
      }

      final canonicalName = (invName != null && invName.isNotEmpty) ? invName : rawName;
      final rawUnit = (row['item_unit']?.toString() ?? 'piece').trim();
      final invUnit = row['inv_unit']?.toString().trim();
      final canonicalUnit = (invUnit != null && invUnit.isNotEmpty) ? invUnit : rawUnit;

      final double qty = (row['quantity'] as num?)?.toDouble() ?? 1.0;
      final double totalPrice = (row['total_price'] as num?)?.toDouble() ??
          (qty * ((row['unit_price'] as num?)?.toDouble() ?? 0.0));
      final double invCostPrice = (row['inv_cost_price'] as num?)?.toDouble() ?? 0.0;
      final double invStock = (row['inv_stock'] as num?)?.toDouble() ?? 0.0;
      final String orderId = row['order_id']?.toString() ?? '';

      // Convert quantity to canonical inventory unit (e.g. gram -> kg)
      final double convertedQty = UnitConverter.convert(
        quantity: qty,
        fromUnit: rawUnit,
        toUnit: canonicalUnit,
      );

      final double costForThisItem = convertedQty * invCostPrice;
      final double weightInKg = UnitConverter.toWeightInKg(qty, rawUnit);
      final bool isWeight = UnitConverter.isWeightUnit(canonicalUnit) || UnitConverter.isWeightUnit(rawUnit);

      if (!grouped.containsKey(groupKey)) {
        grouped[groupKey] = {
          'item_id': resolvedItemId,
          'item_name': canonicalName,
          'bilingual_name': MarathiItemHelper.formatBilingual(canonicalName),
          'item_unit': canonicalUnit,
          'cost_price': invCostPrice,
          'stock': invStock,
          'total_quantity': convertedQty,
          'total_cost_price': costForThisItem,
          'total_selling_price': totalPrice,
          'total_profit': totalPrice - costForThisItem,
          'total_weight_kg': weightInKg,
          'is_weight': isWeight,
          'order_ids': <String>{orderId},
          'category': row['inv_category']?.toString() ?? 'General',
        };
      } else {
        final existing = grouped[groupKey]!;
        existing['total_quantity'] = (existing['total_quantity'] as double) + convertedQty;
        existing['total_cost_price'] = (existing['total_cost_price'] as double) + costForThisItem;
        existing['total_selling_price'] = (existing['total_selling_price'] as double) + totalPrice;
        existing['total_profit'] = (existing['total_selling_price'] as double) -
            (existing['total_cost_price'] as double);
        existing['total_weight_kg'] = (existing['total_weight_kg'] as double) + weightInKg;
        (existing['order_ids'] as Set<String>).add(orderId);
      }
    }

    final List<Map<String, dynamic>> results = grouped.values.map((item) {
      final orderIds = item['order_ids'] as Set<String>;
      final totalQty = item['total_quantity'] as double;
      final totalSelling = item['total_selling_price'] as double;
      final stock = (item['stock'] as num?)?.toDouble() ?? 0.0;
      final toBuyQty = math.max(0.0, totalQty - stock);

      return {
        'item_id': item['item_id'] ?? '',
        'item_name': item['item_name'],
        'bilingual_name': item['bilingual_name'],
        'item_unit': item['item_unit'],
        'cost_price': item['cost_price'],
        'stock': stock,
        'to_buy_quantity': toBuyQty,
        'total_quantity': totalQty,
        'total_cost_price': item['total_cost_price'],
        'total_selling_price': totalSelling,
        'total_profit': item['total_profit'],
        'total_weight_kg': item['total_weight_kg'],
        'is_weight': item['is_weight'],
        'order_count': orderIds.length,
        'avg_price': totalQty > 0 ? (totalSelling / totalQty) : 0.0,
        'category': item['category'],
      };
    }).toList();

    // Sort by Total Quantity (descending) then Profit (descending)
    results.sort((a, b) {
      final profitComp = (b['total_profit'] as double).compareTo(a['total_profit'] as double);
      if (profitComp != 0) return profitComp;
      return (b['total_quantity'] as double).compareTo(a['total_quantity'] as double);
    });

    return results;
  }

  /// Quickly update cost price of an item from Market procurement view and log price history snapshot
  Future<void> quickUpdateItemCostPrice(String itemId, double newCostPrice) async {
    if (itemId.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final dateKey = now.substring(0, 10);

    await db.transaction((txn) async {
      await txn.update(
        'items',
        {
          'cost_price': newCostPrice,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [itemId],
      );

      final itemRows =
          await txn.query('items', where: 'id = ?', whereArgs: [itemId]);
      if (itemRows.isNotEmpty) {
        final itemMap = itemRows.first;
        final sellingPrice =
            (itemMap['selling_price'] as num?)?.toDouble() ?? 0.0;
        final marketPrice =
            (itemMap['market_price'] as num?)?.toDouble() ?? 0.0;

        await txn.rawInsert('''
          INSERT OR REPLACE INTO item_price_history (id, item_id, date, selling_price, cost_price, market_price, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', [
          '${itemId}_$dateKey',
          itemId,
          dateKey,
          sellingPrice,
          newCostPrice,
          marketPrice,
          now,
        ]);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getOrdersForItem({
    String? itemId,
    required String itemName,
    String status = 'all',
    String dateFilter = 'all',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _db;
    String whereClause =
        "(o.delivery_status IS NULL OR o.delivery_status != 'cancelled')";
    List<dynamic> args = [];

    if (itemId != null && itemId.isNotEmpty) {
      whereClause +=
          " AND ((oi.item_id IS NOT NULL AND oi.item_id != '' AND oi.item_id = ?) OR (LOWER(TRIM(oi.item_name)) = LOWER(TRIM(?))))";
      args.addAll([itemId, itemName]);
    } else {
      whereClause += " AND LOWER(TRIM(oi.item_name)) = LOWER(TRIM(?))";
      args.add(itemName);
    }

    if (status != 'all' && status.isNotEmpty) {
      whereClause += " AND o.delivery_status = ?";
      args.add(status);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    if (startDate != null && endDate != null) {
      final startStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(endDate);
      whereClause += " AND DATE(o.created_at) >= DATE(?) AND DATE(o.created_at) <= DATE(?)";
      args.add(startStr);
      args.add(endStr);
    } else if (dateFilter == 'today') {
      whereClause += " AND DATE(o.created_at) = DATE(?)";
      args.add(todayStr);
    } else if (dateFilter == 'yesterday') {
      final yest = today.subtract(const Duration(days: 1));
      final yestStr = DateFormat('yyyy-MM-dd').format(yest);
      whereClause += " AND DATE(o.created_at) = DATE(?)";
      args.add(yestStr);
    } else if (dateFilter == 'week') {
      final start = today.subtract(const Duration(days: 7));
      final startStr = DateFormat('yyyy-MM-dd').format(start);
      whereClause += " AND DATE(o.created_at) >= DATE(?) AND DATE(o.created_at) <= DATE(?)";
      args.add(startStr);
      args.add(todayStr);
    } else if (dateFilter == 'month') {
      final start = DateTime(now.year, now.month, 1);
      final startStr = DateFormat('yyyy-MM-dd').format(start);
      whereClause += " AND DATE(o.created_at) >= DATE(?) AND DATE(o.created_at) <= DATE(?)";
      args.add(startStr);
      args.add(todayStr);
    }

    final rows = await db.rawQuery('''
      SELECT 
        o.id AS order_id,
        o.customer_id,
        o.grand_total,
        o.delivery_status,
        o.created_at,
        c.name AS customer_name,
        c.phone1 AS customer_phone,
        c.house_number AS customer_house,
        oi.quantity,
        oi.item_unit,
        oi.unit_price,
        oi.total_price
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      LEFT JOIN customers c ON o.customer_id = c.id
      WHERE $whereClause
      ORDER BY o.created_at DESC
    ''', args);

    return rows;
  }
}
