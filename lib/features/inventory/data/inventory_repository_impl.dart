import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/inventory_repository.dart';
import '../domain/item.dart';
import '../domain/stock_history.dart';
import '../../../core/database/database_helper.dart';
import 'item_dao.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final ItemDao _dao;
  final _uuid = const Uuid();
  
  InventoryRepositoryImpl(this._dao);

  Future<void> _ensureSupabaseAuth() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      try {
        await client.auth.signInWithPassword(
          email: 'admin@aplibhaji.com',
          password: 'adminpassword',
        );
        debugPrint('Successfully authenticated Supabase client for OrderKart.');
      } catch (e) {
        debugPrint('Supabase auto-authentication failed: $e');
      }
    }
  }

  Future<String?> _getOrCreateCategoryId(String categoryName) async {
    final client = Supabase.instance.client;
    try {
      final existing = await client.from('categories').select().eq('name', categoryName).maybeSingle();
      if (existing != null) {
        return existing['id'] as String;
      }
      final newCat = await client.from('categories').insert({
        'name': categoryName,
        'is_enabled': true,
      }).select().single();
      return newCat['id'] as String;
    } catch (e) {
      debugPrint('Error getting/creating category ID: $e');
      return null;
    }
  }

  Item _mapProductToItem(Map<String, dynamic> p) {
    final id = p['id'] as String;
    final name = p['name'] as String? ?? '';
    final price = (p['price'] as num?)?.toDouble() ?? 0.0;
    final unit = p['unit'] as String? ?? 'kg';
    final imagePath = p['image_path'] as String? ?? '';
    
    // Get category name
    String categoryName = 'Vegetables';
    final categories = p['categories'];
    if (categories is Map<String, dynamic>) {
      categoryName = categories['name'] as String? ?? 'Vegetables';
    } else if (p['category_name'] != null) {
      categoryName = p['category_name'] as String;
    }
    
    // Parse description for JSON extra fields
    final desc = p['description'] as String? ?? '';
    double costPrice = (p['cost_price'] as num?)?.toDouble() ?? 0.0;
    double marketPrice = (p['mrp'] as num?)?.toDouble() ?? price;
    double stock = (p['stock'] as num?)?.toDouble() ?? 0.0;
    double minStock = 0.0;
    String barcode = '';
    double weightPerPiece = 0.25;
    int seqNo = 0;
    String expiryDate = '';
    String batchNumber = '';
    bool prescriptionRequired = false;
    String dosageInfo = '';
    String bestBefore = '';
    String packDate = '';
    
    if (desc.trim().startsWith('{') && desc.trim().endsWith('}')) {
      try {
        final Map<String, dynamic> extra = json.decode(desc);
        if (costPrice == 0.0 && extra['cost_price'] != null) {
          costPrice = (extra['cost_price'] as num?)?.toDouble() ?? 0.0;
        }
        if (marketPrice == price && (extra['market_price'] != null || extra['mrp'] != null)) {
          marketPrice = ((extra['market_price'] ?? extra['mrp']) as num?)?.toDouble() ?? price;
        }
        if (stock == 0.0 && extra['stock'] != null) {
          stock = (extra['stock'] as num?)?.toDouble() ?? 0.0;
        }
        minStock = (extra['min_stock'] as num?)?.toDouble() ?? 0.0;
        barcode = extra['barcode'] as String? ?? '';
        weightPerPiece = (extra['weight_per_piece'] as num?)?.toDouble() ?? 0.25;
        seqNo = extra['sequence_no'] as int? ?? extra['serial_no'] as int? ?? 0;
        expiryDate = extra['expiry_date'] as String? ?? '';
        batchNumber = extra['batch_number'] as String? ?? '';
        prescriptionRequired = extra['prescription_required'] as bool? ?? false;
        dosageInfo = extra['dosage_info'] as String? ?? '';
        bestBefore = extra['best_before'] as String? ?? '';
        packDate = extra['pack_date'] as String? ?? '';
      } catch (e) {
        debugPrint('Error parsing item description JSON: $e');
      }
    }
    
    final remoteUpdatedStr = p['updated_at']?.toString() ?? p['created_at']?.toString() ?? '';
    final remoteUpdatedAt = DateTime.tryParse(remoteUpdatedStr) ?? DateTime.now();

    final orderNowStock = (p['order_now_stock'] as num?)?.toDouble() ?? 0.0;
    final orderNowSellingPrice = (p['order_now_price'] as num?)?.toDouble() ?? 0.0;
    final orderNowMrp = (p['order_now_mrp'] as num?)?.toDouble() ?? 0.0;
    final orderNowCostPrice = (p['order_now_cost_price'] as num?)?.toDouble() ?? 0.0;
    final orderNowIsAvailable = p['order_now_is_available'] == null
        ? true
        : (p['order_now_is_available'] is bool
            ? p['order_now_is_available'] as bool
            : (p['order_now_is_available'] as num) == 1);

    final isAvailable = p['is_available'] == null
        ? true
        : (p['is_available'] is bool
            ? p['is_available'] as bool
            : (p['is_available'] as num) == 1);

    return Item(
      id: id,
      name: name,
      category: categoryName,
      costPrice: costPrice,
      sellingPrice: price,
      marketPrice: marketPrice,
      stock: stock,
      minStock: minStock,
      unit: unit,
      barcode: barcode,
      createdAt: DateTime.tryParse(p['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: remoteUpdatedAt,
      photoPath: imagePath,
      weightPerPiece: weightPerPiece,
      sequenceNo: seqNo,
      expiryDate: expiryDate,
      batchNumber: batchNumber,
      prescriptionRequired: prescriptionRequired,
      dosageInfo: dosageInfo,
      bestBefore: bestBefore,
      packDate: packDate,
      orderNowStock: orderNowStock,
      orderNowSellingPrice: orderNowSellingPrice,
      orderNowMrp: orderNowMrp,
      orderNowCostPrice: orderNowCostPrice,
      isAvailable: isAvailable,
      orderNowIsAvailable: orderNowIsAvailable,
    );
  }

  Future<Map<String, dynamic>> _itemToProductMap(Item item, String? categoryId) async {
    final extra = {
      'cost_price': item.costPrice,
      'market_price': item.marketPrice,
      'mrp': item.marketPrice,
      'stock': item.stock,
      'min_stock': item.minStock,
      'barcode': item.barcode,
      'weight_per_piece': item.weightPerPiece,
      'sequence_no': item.sequenceNo,
      'expiry_date': item.expiryDate,
      'batch_number': item.batchNumber,
      'prescription_required': item.prescriptionRequired,
      'dosage_info': item.dosageInfo,
      'best_before': item.bestBefore,
      'pack_date': item.packDate,
      'order_now_stock': item.orderNowStock,
      'order_now_price': item.orderNowSellingPrice,
      'order_now_mrp': item.orderNowMrp,
      'order_now_cost_price': item.orderNowCostPrice,
      'order_now_is_available': item.orderNowIsAvailable,
    };
    
    return {
      'name': item.name,
      'category_id': categoryId,
      'price': item.sellingPrice,
      'selling_price': item.sellingPrice,
      'mrp': item.marketPrice,
      'cost_price': item.costPrice,
      'stock': item.stock,
      'unit': item.unit,
      'image_path': item.photoPath,
      'description': json.encode(extra),
      'is_available': item.isAvailable,
      'is_enabled': true,
      'order_now_stock': item.orderNowStock,
      'order_now_price': item.orderNowSellingPrice,
      'order_now_mrp': item.orderNowMrp,
      'order_now_cost_price': item.orderNowCostPrice,
      'order_now_is_available': item.orderNowIsAvailable,
    };
  }

  @override
  Future<List<Item>> getAllItems({String? category, String? searchQuery, String? sortBy}) async {
    return _dao.getAllItems(category: category, searchQuery: searchQuery, sortBy: sortBy);
  }

  @override
  Future<Item?> getItemById(String id) async {
    return _dao.getItemById(id);
  }

  @override
  Future<List<Item>> getLowStockItems() async {
    return _dao.getLowStockItems();
  }

  @override
  Future<String> addItem(Item item) async {
    final localId = item.id.isNotEmpty ? item.id : _uuid.v4();
    final itemWithId = item.copyWith(id: localId);
    await _dao.insertItem(itemWithId);

    // Direct push to Supabase so new items are available to customers immediately
    try {
      await _ensureSupabaseAuth();
      final client = Supabase.instance.client;
      final categoryId = await _getOrCreateCategoryId(itemWithId.category);
      final pMap = await _itemToProductMap(itemWithId, categoryId);
      pMap['id'] = localId;
      pMap['created_at'] = DateTime.now().toIso8601String();
      pMap['updated_at'] = DateTime.now().toIso8601String();
      await client.from('products').upsert(pMap);
      debugPrint('[INVENTORY-SYNC] Directly synced new item ${itemWithId.name} ($localId) to Supabase.');
    } catch (e) {
      debugPrint('[INVENTORY-SYNC] Direct Supabase insert/upsert failed (will sync later): $e');
    }

    return localId;
  }

  @override
  Future<void> updateItem(Item item) async {
    await _dao.updateItem(item);
    // Push directly to Supabase products table
    try {
      await _ensureSupabaseAuth();
      final client = Supabase.instance.client;
      final categoryId = await _getOrCreateCategoryId(item.category);
      final pMap = await _itemToProductMap(item, categoryId);
      pMap['updated_at'] = DateTime.now().toIso8601String();
      await client.from('products').update(pMap).eq('id', item.id);
      debugPrint('[INVENTORY-SYNC] Directly synced updated item ${item.name} (${item.id}) to Supabase.');
    } catch (e) {
      debugPrint('[INVENTORY-SYNC] Direct Supabase update failed (will sync later): $e');
    }
  }

  @override
  Future<void> updateItems(List<Item> items) async {
    // 1. Update SQLite locally instantly (<20ms)
    await _dao.updateItems(items);

    // 2. Trigger remote Supabase sync in the background so bulk updates never block the UI
    unawaited(() async {
      try {
        await _ensureSupabaseAuth();
        final client = Supabase.instance.client;

        // Pre-fetch categories once instead of per-item
        final List<dynamic> catRows = await client.from('categories').select('id, name');
        final Map<String, String> catMap = {};
        for (final c in catRows) {
          final name = (c['name'] as String? ?? '').toLowerCase();
          if (name.isNotEmpty) catMap[name] = c['id'] as String;
        }

        for (final item in items) {
          try {
            String? catId = catMap[item.category.toLowerCase()];
            if (catId == null) {
              catId = await _getOrCreateCategoryId(item.category);
              if (catId != null) catMap[item.category.toLowerCase()] = catId;
            }
            final pMap = await _itemToProductMap(item, catId);
            pMap['updated_at'] = DateTime.now().toIso8601String();
            await client.from('products').update(pMap).eq('id', item.id);
          } catch (e) {
            debugPrint('[INVENTORY-SYNC] Item sync failed for ${item.name}: $e');
          }
        }
        debugPrint('[INVENTORY-SYNC] Background synced ${items.length} items to Supabase.');
      } catch (e) {
        debugPrint('[INVENTORY-SYNC] Background bulk Supabase update error: $e');
      }
    }());
  }

  @override
  Future<void> deleteItem(String id) async {
    await _dao.deleteItem(id);
    // Deactivate on Supabase so customers cannot order deleted products
    try {
      await _ensureSupabaseAuth();
      final client = Supabase.instance.client;
      await client.from('products').update({
        'is_enabled': false,
        'is_available': false,
        'stock': 0,
        'order_now_is_available': false,
        'order_now_stock': 0,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      debugPrint('[INVENTORY-SYNC] Deactivated deleted product ($id) on Supabase.');
    } catch (e) {
      debugPrint('[INVENTORY-SYNC] Direct Supabase deactivation failed: $e');
    }
  }

  @override
  Future<void> adjustStock(String itemId, double change, String reason, {String? orderId}) async {
    final item = await _dao.getItemById(itemId);
    await _dao.adjustStock(itemId, change);
    if (item != null) {
      final updatedItem = await _dao.getItemById(itemId);
      await _dao.insertStockHistory(StockHistory(
        id:           _uuid.v4(),
        itemId:       itemId,
        itemName:     item.name,
        changeAmount: change,
        reason:       reason,
        orderId:      orderId ?? '',
        createdAt:    DateTime.now(),
      ));

      if (updatedItem != null) {
        // Direct push updated stock to Supabase
        try {
          await _ensureSupabaseAuth();
          final client = Supabase.instance.client;
          await client.from('products').update({
            'stock': updatedItem.stock,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', itemId);
          debugPrint('[INVENTORY-SYNC] Directly synced adjusted stock for ${item.name} (${updatedItem.stock}) to Supabase.');
        } catch (e) {
          debugPrint('[INVENTORY-SYNC] Direct Supabase stock adjust sync failed: $e');
        }
      }
    }
  }

  @override
  Future<List<StockHistory>> getStockHistory(String itemId) async {
    return _dao.getStockHistory(itemId);
  }

  @override
  Future<void> updateItemSequences(List<String> itemIds) async {
    await _dao.updateItemSequences(itemIds);
  }

  @override
  Future<List<StockHistory>> getSpillageHistory() async {
    return _dao.getSpillageHistory();
  }

  @override
  Future<void> syncWithServer() async {
    await _ensureSupabaseAuth();
    final client = Supabase.instance.client;

    // 1. Fetch remote products from Supabase
    final List<dynamic> productsJson = await client.from('products').select('*, categories(id, name)');
    final Map<String, Map<String, dynamic>> remoteProductsById = {};
    final Map<String, Map<String, dynamic>> remoteProductsByName = {};

    for (final p in productsJson) {
      final id = p['id'] as String;
      final name = p['name'] as String? ?? '';
      remoteProductsById[id] = Map<String, dynamic>.from(p);
      remoteProductsByName[name.toLowerCase()] = Map<String, dynamic>.from(p);
    }

    // 2. Fetch all local items from SQLite
    final localItems = await _dao.getAllItems();
    final Set<String> syncedLocalIds = {};

    for (final localItem in localItems) {
      // Check if local item already has a Supabase ID or name match on remote
      Map<String, dynamic>? matchingRemote = remoteProductsById[localItem.id] ?? remoteProductsByName[localItem.name.toLowerCase()];

      if (matchingRemote != null) {
        final remoteId = matchingRemote['id'] as String;
        syncedLocalIds.add(remoteId);

        // Update the local item to use the correct remote ID in case of name match, preserving history
        if (localItem.id != remoteId) {
          final db = await DatabaseHelper.instance.database;
          await db.transaction((txn) async {
            await txn.update('items', {'id': remoteId}, where: 'id = ?', whereArgs: [localItem.id]);
            await txn.update('order_items', {'item_id': remoteId}, where: 'item_id = ?', whereArgs: [localItem.id]);
            await txn.update('stock_history', {'item_id': remoteId}, where: 'item_id = ?', whereArgs: [localItem.id]);
            await txn.update('item_price_history', {'item_id': remoteId}, where: 'item_id = ?', whereArgs: [localItem.id]);
          });
        }

        final bool isRemoteEnabled = matchingRemote['is_enabled'] != false &&
            matchingRemote['is_enabled'] != 0 &&
            matchingRemote['is_enabled']?.toString() != '0' &&
            matchingRemote['is_enabled']?.toString().toLowerCase() != 'false';
        if (!isRemoteEnabled) {
          // Product was disabled/deleted remotely -> remove locally
          await _dao.deleteItem(remoteId);
          debugPrint('[SYNC-INVENTORY] Product ${localItem.name} was disabled remotely, removed from local SQLite.');
          continue;
        }

        final remoteUpdatedStr = matchingRemote['updated_at']?.toString() ?? matchingRemote['created_at']?.toString() ?? '';
        final remoteUpdatedAt = DateTime.tryParse(remoteUpdatedStr) ?? DateTime.fromMillisecondsSinceEpoch(0);

        final localItemWithId = localItem.copyWith(id: remoteId);

        if (localItem.updatedAt.isAfter(remoteUpdatedAt)) {
          // Local is newer -> push/update remote product
          final categoryId = await _getOrCreateCategoryId(localItem.category);
          
          // Preserve admin-uploaded remote image_path if local is empty
          final remoteImage = matchingRemote['image_path'] as String? ?? '';
          final itemToSync = (localItemWithId.photoPath.isEmpty && remoteImage.isNotEmpty)
              ? localItemWithId.copyWith(photoPath: remoteImage)
              : localItemWithId;

          final pMap = await _itemToProductMap(itemToSync, categoryId);
          await client.from('products').update(pMap).eq('id', remoteId);
          debugPrint('[SYNC-INVENTORY] Local item ${localItem.name} is newer, pushed to server.');
        } else {
          // Remote is newer -> update local SQLite
          final updatedItem = _mapProductToItem(matchingRemote);
          await _dao.updateItem(updatedItem);
          debugPrint('[SYNC-INVENTORY] Remote item ${localItem.name} is newer, pulled to SQLite.');
        }
      } else {
        // Does not exist on remote, insert it to Supabase
        final categoryId = await _getOrCreateCategoryId(localItem.category);
        final pMap = await _itemToProductMap(localItem, categoryId);
        pMap['id'] = localItem.id;
        pMap['created_at'] = DateTime.now().toIso8601String();
        pMap['updated_at'] = DateTime.now().toIso8601String();
        await client.from('products').upsert(pMap);
        syncedLocalIds.add(localItem.id);
        debugPrint('[SYNC-INVENTORY] Inserted new local item ${localItem.name} to remote.');
      }
    }

    // 3. For any remote products that do not exist locally, download them (if enabled)
    for (final p in productsJson) {
      final remoteId = p['id'] as String;
      final bool isEnabled = p['is_enabled'] != false &&
          p['is_enabled'] != 0 &&
          p['is_enabled']?.toString() != '0' &&
          p['is_enabled']?.toString().toLowerCase() != 'false';
      if (!isEnabled) continue; // Do not resurrect disabled products
      if (!syncedLocalIds.contains(remoteId)) {
        final item = _mapProductToItem(p);
        await _dao.insertItem(item);
      }
    }
  }
}
