import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/inventory_repository.dart';
import '../domain/item.dart';
import '../domain/stock_history.dart';
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
    double costPrice = 0.0;
    double marketPrice = price; // Default to selling price
    double stock = 0.0;
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
        costPrice = (extra['cost_price'] as num?)?.toDouble() ?? 0.0;
        marketPrice = ((extra['market_price'] ?? extra['mrp']) as num?)?.toDouble() ?? price;
        stock = (extra['stock'] as num?)?.toDouble() ?? 0.0;
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
    };
    
    return {
      'name': item.name,
      'category_id': categoryId,
      'price': item.sellingPrice,
      'unit': item.unit,
      'image_path': item.photoPath,
      'description': json.encode(extra),
      'is_available': item.stock > 0,
      'is_enabled': true,
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
    final localId = _uuid.v4();
    final itemWithId = item.copyWith(id: localId);
    await _dao.insertItem(itemWithId);
    return localId;
  }

  @override
  Future<void> updateItem(Item item) async {
    await _dao.updateItem(item);
  }

  @override
  Future<void> updateItems(List<Item> items) async {
    await _dao.updateItems(items);
  }

  @override
  Future<void> deleteItem(String id) async {
    await _dao.deleteItem(id);
  }

  @override
  Future<void> adjustStock(String itemId, double change, String reason, {String? orderId}) async {
    final item = await _dao.getItemById(itemId);
    await _dao.adjustStock(itemId, change);
    if (item != null) {
      await _dao.insertStockHistory(StockHistory(
        id:           _uuid.v4(),
        itemId:       itemId,
        itemName:     item.name,
        changeAmount: change,
        reason:       reason,
        orderId:      orderId ?? '',
        createdAt:    DateTime.now(),
      ));
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

        // Update the local item to use the correct remote ID in case of name match
        if (localItem.id != remoteId) {
          await _dao.deleteItem(localItem.id);
          await _dao.insertItem(localItem.copyWith(id: remoteId));
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
        final insertedProd = await client.from('products').insert(pMap).select().single();
        final insertedId = insertedProd['id'] as String;

        // Update SQLite database with the new remote ID
        await _dao.deleteItem(localItem.id);
        await _dao.insertItem(localItem.copyWith(id: insertedId));
        syncedLocalIds.add(insertedId);
        debugPrint('[SYNC-INVENTORY] Inserted new local item ${localItem.name} to remote.');
      }
    }

    // 3. For any remote products that do not exist locally, download them
    for (final p in productsJson) {
      final remoteId = p['id'] as String;
      if (!syncedLocalIds.contains(remoteId)) {
        final item = _mapProductToItem(p);
        await _dao.insertItem(item);
      }
    }
  }
}
