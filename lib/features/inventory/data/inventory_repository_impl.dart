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
    
    return Item(
      id: id,
      name: name,
      category: categoryName,
      costPrice: costPrice,
      sellingPrice: price,
      marketPrice: price,
      stock: stock,
      minStock: minStock,
      unit: unit,
      barcode: barcode,
      createdAt: DateTime.tryParse(p['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.now(),
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
    try {
      await _ensureSupabaseAuth();
      final client = Supabase.instance.client;
      
      // Fetch products and categories
      final List<dynamic> productsJson = await client.from('products').select('*, categories(id, name)');
      
      // Keep track of Supabase product IDs
      final Set<String> remoteIds = {};
      
      // Update local SQLite db with remote products
      for (final p in productsJson) {
        final item = _mapProductToItem(p);
        remoteIds.add(item.id);
        await _dao.insertItem(item);
      }
      
      // Delete any items from local SQLite that are not present in Supabase anymore
      final localItems = await _dao.getAllItems();
      for (final localItem in localItems) {
        if (!remoteIds.contains(localItem.id)) {
          await _dao.deleteItem(localItem.id);
        }
      }
    } catch (e) {
      debugPrint('Supabase products fetch/sync failed (offline mode): $e');
    }
    
    // Always return local items from SQLite matching the filters
    return _dao.getAllItems(category: category, searchQuery: searchQuery, sortBy: sortBy);
  }

  @override
  Future<Item?> getItemById(String id) async {
    try {
      await _ensureSupabaseAuth();
      final client = Supabase.instance.client;
      final product = await client.from('products').select('*, categories(id, name)').eq('id', id).maybeSingle();
      if (product != null) {
        final item = _mapProductToItem(product);
        await _dao.insertItem(item);
        return item;
      }
    } catch (e) {
      debugPrint('Supabase getItemById failed (offline fallback): $e');
    }
    return _dao.getItemById(id);
  }

  @override
  Future<List<Item>> getLowStockItems() async {
    return _dao.getLowStockItems();
  }

  @override
  Future<String> addItem(Item item) async {
    await _ensureSupabaseAuth();
    final client = Supabase.instance.client;
    final categoryId = await _getOrCreateCategoryId(item.category);
    final pMap = await _itemToProductMap(item, categoryId);
    
    // Insert into Supabase
    final newProd = await client.from('products').insert(pMap).select().single();
    final newId = newProd['id'] as String;
    
    final itemWithId = item.copyWith(id: newId);
    await _dao.insertItem(itemWithId);
    return newId;
  }

  @override
  Future<void> updateItem(Item item) async {
    await _ensureSupabaseAuth();
    final client = Supabase.instance.client;
    final categoryId = await _getOrCreateCategoryId(item.category);
    
    // Handle conflict check by fetching latest remote product description JSON
    String mergedDescription = json.encode({
      'cost_price': item.costPrice,
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
    });
    
    try {
      final remoteProd = await client.from('products').select('description').eq('id', item.id).maybeSingle();
      if (remoteProd != null) {
        final remoteDesc = remoteProd['description'] as String? ?? '';
        if (remoteDesc.trim().startsWith('{') && remoteDesc.trim().endsWith('}')) {
          final Map<String, dynamic> remoteJson = json.decode(remoteDesc);
          final mergedJson = {
            ...remoteJson,
            'cost_price': item.costPrice,
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
          mergedDescription = json.encode(mergedJson);
        }
      }
    } catch (e) {
      debugPrint('Conflict check failed: $e');
    }
    
    final pMap = {
      'name': item.name,
      'category_id': categoryId,
      'price': item.sellingPrice,
      'unit': item.unit,
      'image_path': item.photoPath,
      'description': mergedDescription,
      'is_available': item.stock > 0,
      'is_enabled': true,
    };
    
    await client.from('products').update(pMap).eq('id', item.id);
    await _dao.updateItem(item);
  }

  @override
  Future<void> updateItems(List<Item> items) async {
    for (final item in items) {
      await updateItem(item);
    }
  }

  @override
  Future<void> deleteItem(String id) async {
    await _ensureSupabaseAuth();
    final client = Supabase.instance.client;
    await client.from('products').delete().eq('id', id);
    await _dao.deleteItem(id);
  }

  @override
  Future<void> adjustStock(String itemId, double change, String reason, {String? orderId}) async {
    await _ensureSupabaseAuth();
    final client = Supabase.instance.client;
    
    final remoteProd = await client.from('products').select('description').eq('id', itemId).maybeSingle();
    double currentRemoteStock = 0.0;
    Map<String, dynamic> remoteJson = {};
    
    if (remoteProd != null) {
      final remoteDesc = remoteProd['description'] as String? ?? '';
      if (remoteDesc.trim().startsWith('{') && remoteDesc.trim().endsWith('}')) {
        try {
          remoteJson = json.decode(remoteDesc);
          currentRemoteStock = (remoteJson['stock'] as num?)?.toDouble() ?? 0.0;
        } catch (_) {}
      }
    }
    
    final double updatedStock = currentRemoteStock + change;
    remoteJson['stock'] = updatedStock;
    
    await client.from('products').update({
      'description': json.encode(remoteJson),
      'is_available': updatedStock > 0,
    }).eq('id', itemId);
    
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
    await _ensureSupabaseAuth();
    final client = Supabase.instance.client;
    for (int i = 0; i < itemIds.length; i++) {
      final itemId = itemIds[i];
      final seqNo = i + 1;
      
      final remoteProd = await client.from('products').select('description').eq('id', itemId).maybeSingle();
      Map<String, dynamic> remoteJson = {};
      if (remoteProd != null) {
        final remoteDesc = remoteProd['description'] as String? ?? '';
        if (remoteDesc.trim().startsWith('{') && remoteDesc.trim().endsWith('}')) {
          try {
            remoteJson = json.decode(remoteDesc);
          } catch (_) {}
        }
      }
      remoteJson['sequence_no'] = seqNo;
      await client.from('products').update({
        'description': json.encode(remoteJson),
      }).eq('id', itemId);
    }
    await _dao.updateItemSequences(itemIds);
  }

  @override
  Future<List<StockHistory>> getSpillageHistory() async {
    return _dao.getSpillageHistory();
  }
}
