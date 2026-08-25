import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../../features/customer/data/customer_dao.dart';
import 'notification_service.dart';

class CustomerOrderSyncService {
  CustomerOrderSyncService._();
  static final CustomerOrderSyncService instance = CustomerOrderSyncService._();

  Timer? _syncTimer;

  Future<void> _ensureSupabaseAuth() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      try {
        await client.auth.signInWithPassword(
          email: 'admin@aplibhaji.com',
          password: 'adminpassword',
        );
        debugPrint('SyncService: Successfully authenticated Supabase client for OrderKart.');
      } catch (e) {
        debugPrint('SyncService: Supabase auto-authentication failed: $e');
      }
    }
  }

  void startSync() {
    _syncTimer?.cancel();
    // Run sync check every 10 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await syncAllExistingCustomers();
      await syncOrders();
    });
  }

  void stopSync() {
    _syncTimer?.cancel();
  }

  Future<Map<String, int>> syncAllExistingCustomers({bool forceSync = false}) async {
    int total = 0;
    int real = 0;
    int ghost = 0;
    int alreadySynced = 0;
    int uploaded = 0;
    int updated = 0;
    int failed = 0;

    try {
      await _ensureSupabaseAuth();
      final client = Supabase.instance.client;
      final db = await DatabaseHelper.instance.database;

      // Try to load locations for recursive ancestor mapping
      List<Map<String, dynamic>> allLocations = [];
      bool useLocationsTable = false;
      try {
        allLocations = await db.query('locations');
        if (allLocations.isNotEmpty) {
          useLocationsTable = true;
        }
      } catch (_) {}

      // Build hierarchy helper maps
      final Map<String, Map<String, dynamic>> locationMap = {
        for (final loc in allLocations) loc['id'] as String: loc
      };

      List<Map<String, dynamic>> getAncestors(String startId) {
        final path = <Map<String, dynamic>>[];
        String? currentId = startId;
        int maxDepth = 20;
        while (currentId != null && maxDepth-- > 0) {
          final loc = locationMap[currentId];
          if (loc == null) break;
          path.insert(0, loc);
          currentId = loc['parent_location_id'] as String?;
        }
        return path;
      }

      // Legacy pre-load mapping
      final List<Map<String, dynamic>> streets = await db.query('streets');
      final Map<String, String> streetToArea = {};
      for (final s in streets) {
        streetToArea[s['id'] as String] = s['area_id'] as String;
      }

      // Find all active customers to sync to Supabase
      List<Map<String, dynamic>> rawCustomers = [];
      try {
        rawCustomers = await db.query('customers');
      } catch (e) {
        debugPrint('[SYNC] Failed to query customers: $e');
      }

      final customers = rawCustomers.where((cust) {
        final isArch = cust['is_archived'];
        return isArch == null || isArch == 0;
      }).toList();

      total = customers.length;

      for (final cust in customers) {
        final rawId = cust['id'] as String;
        final customerId = _getValidUuid(rawId);
        final name = cust['name'] as String? ?? '';
        final phone = cust['phone1'] as String? ?? '';
        final address = cust['address'] as String? ?? '';
        final codeRaw = cust['customer_code'] as String? ?? '';

        final cleanName = name.trim();
        final cleanPhone = phone.trim();

        // Ghost house check
        final bool isGhost = cleanName.isEmpty ||
            cleanName == '[Ghost House]' ||
            cleanName.toLowerCase() == 'ghost house' ||
            cleanName.startsWith('[Ghost House]') ||
            cleanPhone == '0000000000' ||
            cleanPhone.isEmpty;

        if (isGhost) {
          ghost++;
          continue;
        }

        real++;

        // Check if already synced in settings (skip if forceSync is true)
        if (!forceSync) {
          final syncCheck = await db.query(
            'settings',
            where: "key = ?",
            whereArgs: ['customer_sync_status:$rawId'],
          );
          final bool hasSyncedBefore = syncCheck.isNotEmpty && syncCheck.first['value'] == '1';

          if (hasSyncedBefore) {
            alreadySynced++;
            continue;
          }
        }

        // Resolve route IDs for area_id, road_id, sub_road_id
        final String streetId = cust['street_id'] as String? ?? '';
        String? supabaseAreaId;
        String? supabaseRoadId;
        String? supabaseSubRoadId;

        if (useLocationsTable && streetId.isNotEmpty) {
          final ancestors = getAncestors(streetId);
          if (ancestors.isNotEmpty) {
            // Area is root (index 0)
            final areaLocalId = ancestors[0]['id'] as String;
            supabaseAreaId = const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.area.$areaLocalId');

            // Road is depth 1 (index 1)
            if (ancestors.length > 1) {
              final roadLocalId = ancestors[1]['id'] as String;
              supabaseRoadId = const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.road.$roadLocalId');
            }

            // Sub-road is depth >= 2 (use the leaf location ID)
            if (ancestors.length > 2) {
              final subRoadLocalId = ancestors.last['id'] as String;
              supabaseSubRoadId = const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.subroad.$subRoadLocalId');
            }
          }
        } else if (streetId.isNotEmpty) {
          // Legacy mapping fallback
          final localAreaId = streetToArea[streetId] ?? '';
          if (localAreaId.isNotEmpty) {
            supabaseAreaId = const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.area.$localAreaId');
          }
          supabaseRoadId = const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.road.$streetId');
        }

        // Check if server customer exists by searching by ID
        bool existsOnServer = false;
        try {
          final serverCheck = await client.from('customers').select('id').eq('id', customerId).maybeSingle();
          existsOnServer = serverCheck != null;
        } catch (_) {}

        debugPrint('[SYNC] Customer $rawId ($name) area=$supabaseAreaId road=$supabaseRoadId subroad=$supabaseSubRoadId');

        try {
          await client.rpc('sync_customer_with_code', params: {
            'p_id': customerId,
            'p_name': name,
            'p_phone': phone,
            'p_email': '',
            'p_address': address,
            'p_customer_code': codeRaw,
            'p_area_id': supabaseAreaId,
            'p_road_id': supabaseRoadId,
            'p_sub_road_id': supabaseSubRoadId,
          });

          // Mark synced in local settings
          await db.insert(
            'settings',
            {'key': 'customer_sync_status:$rawId', 'value': '1'},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          if (existsOnServer) {
            updated++;
          } else {
            uploaded++;
          }
        } catch (e) {
          failed++;
          debugPrint('[SYNC] Customer sync FAILED: $e');
        }
      }
    } catch (e) {
      debugPrint('SyncService: Error during syncAllExistingCustomers: $e');
    }

    return {
      'total': total,
      'real': real,
      'ghost': ghost,
      'alreadySynced': alreadySynced,
      'uploaded': uploaded,
      'updated': updated,
      'failed': failed,
    };
  }

  Future<void> syncCustomersToRemote() async {
    await syncAllExistingCustomers();
  }

  // =====================================================
  // SYNC AREAS & ROADS (SQLite locations/areas/streets → Supabase areas/roads/sub_roads)
  // =====================================================
  Future<Map<String, int>> syncAreasAndRoads() async {
    int areasUploaded = 0;
    int roadsUploaded = 0;
    int subRoadsUploaded = 0;
    int areasFailed = 0;
    int roadsFailed = 0;
    int subRoadsFailed = 0;

    try {
      await _ensureSupabaseAuth();
      final client = Supabase.instance.client;
      final db = await DatabaseHelper.instance.database;

      // Try to query the new hierarchical locations table
      List<Map<String, dynamic>> localLocations = [];
      List<Map<String, dynamic>> allLocations = [];
      bool useLocationsTable = false;
      try {
        localLocations = await db.query(
          'locations',
          where: "is_archived IS NULL OR is_archived = 0",
        );
        allLocations = await db.query('locations');
        if (localLocations.isNotEmpty) {
          useLocationsTable = true;
        }
      } catch (e) {
        debugPrint('[SYNC] Locations table query failed or empty, falling back to legacy: $e');
      }

      if (useLocationsTable) {
        // Group locations by depth or build hierarchies
        final rootLocations = localLocations.where((loc) => loc['parent_location_id'] == null || loc['depth'] == 0).toList();
        final depth1Locations = localLocations.where((loc) => loc['parent_location_id'] != null && loc['depth'] == 1).toList();
        final depth2OrMoreLocations = localLocations.where((loc) => loc['parent_location_id'] != null && (loc['depth'] ?? 0) >= 2).toList();

        // Build location lookup map
        final Map<String, Map<String, dynamic>> locationMap = {
          for (final loc in allLocations) loc['id'] as String: loc
        };

        // Helper to trace root-to-leaf path
        List<Map<String, dynamic>> getAncestors(String startId) {
          final path = <Map<String, dynamic>>[];
          String? currentId = startId;
          int maxDepth = 20;
          while (currentId != null && maxDepth-- > 0) {
            final loc = locationMap[currentId];
            if (loc == null) break;
            path.insert(0, loc);
            currentId = loc['parent_location_id'] as String?;
          }
          return path;
        }

        // 1. Upload Areas (depth == 0)
        for (final loc in rootLocations) {
          final localId = loc['id'] as String;
          final name = (loc['name'] as String? ?? '').trim();
          if (name.isEmpty) continue;

          final supabaseId = const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.area.$localId');
          final areaCode = 'AREA-${supabaseId.substring(0, 8).toUpperCase()}';

          try {
            await client.from('areas').upsert({
              'id': supabaseId,
              'area_code': areaCode,
              'name': name,
              'delivery_schedule': [],
            }, onConflict: 'id');
            areasUploaded++;
          } catch (e) {
            areasFailed++;
            debugPrint('[SYNC] Area "$name" FAILED: $e');
          }
        }

        // 2. Upload Roads (depth == 1)
        for (final loc in depth1Locations) {
          final localId = loc['id'] as String;
          final localAreaId = loc['parent_location_id'] as String;
          final name = (loc['name'] as String? ?? '').trim();
          if (name.isEmpty || localAreaId.isEmpty) continue;

          final supabaseId = const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.road.$localId');
          final supabaseAreaId = const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.area.$localAreaId');
          final roadCode = 'ROAD-${supabaseId.substring(0, 8).toUpperCase()}';

          try {
            await client.from('roads').upsert({
              'id': supabaseId,
              'road_code': roadCode,
              'area_id': supabaseAreaId,
              'name': name,
            }, onConflict: 'id');
            roadsUploaded++;
          } catch (e) {
            roadsFailed++;
            debugPrint('[SYNC] Road "$name" FAILED: $e');
          }
        }

        // 3. Upload Sub-Roads (depth >= 2)
        for (final loc in depth2OrMoreLocations) {
          final localId = loc['id'] as String;
          final name = (loc['name'] as String? ?? '').trim();
          if (name.isEmpty) continue;

          // Find depth 1 ancestor to act as road_id in Supabase
          final ancestors = getAncestors(localId);
          if (ancestors.length < 2) continue; // must have at least [Area, Road]

          final roadLocalId = ancestors[1]['id'] as String;

          final supabaseId = const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.subroad.$localId');
          final supabaseRoadId = const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.road.$roadLocalId');
          final subroadCode = 'SUBROAD-${supabaseId.substring(0, 8).toUpperCase()}';

          try {
            await client.from('sub_roads').upsert({
              'id': supabaseId,
              'subroad_code': subroadCode,
              'road_id': supabaseRoadId,
              'name': name,
            }, onConflict: 'id');
            subRoadsUploaded++;
          } catch (e) {
            subRoadsFailed++;
            debugPrint('[SYNC] Sub-Road "$name" FAILED: $e');
          }
        }

      } else {
        // Fallback to legacy areas and streets (treating streets as Roads under Areas)
        List<Map<String, dynamic>> rawAreas = [];
        try {
          rawAreas = await db.query('areas');
        } catch (e) {
          debugPrint('[SYNC] Failed to query areas: $e');
        }

        final localAreas = rawAreas.where((area) {
          final isArch = area['is_archived'];
          return isArch == null || isArch == 0;
        }).toList();

        for (final area in localAreas) {
          final localId = area['id'] as String;
          final name = (area['name'] as String? ?? '').trim();
          if (name.isEmpty) continue;

          final supabaseId = const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.area.$localId');
          final areaCode = 'AREA-${supabaseId.substring(0, 8).toUpperCase()}';

          try {
            await client.from('areas').upsert({
              'id': supabaseId,
              'area_code': areaCode,
              'name': name,
              'delivery_schedule': [],
            }, onConflict: 'id');
            areasUploaded++;
          } catch (e) {
            areasFailed++;
            debugPrint('[SYNC] Area "$name" FAILED: $e');
          }
        }

        List<Map<String, dynamic>> rawStreets = [];
        try {
          rawStreets = await db.query('streets');
        } catch (e) {
          debugPrint('[SYNC] Failed to query streets: $e');
        }

        final localStreets = rawStreets.where((street) {
          final isArch = street['is_archived'];
          return isArch == null || isArch == 0;
        }).toList();

        for (final street in localStreets) {
          final localId = street['id'] as String;
          final localAreaId = street['area_id'] as String? ?? '';
          final name = (street['name'] as String? ?? '').trim();
          if (name.isEmpty || localAreaId.isEmpty) continue;

          final supabaseId = const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.road.$localId');
          final supabaseAreaId = const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.area.$localAreaId');
          final roadCode = 'ROAD-${supabaseId.substring(0, 8).toUpperCase()}';

          try {
            await client.from('roads').upsert({
              'id': supabaseId,
              'road_code': roadCode,
              'area_id': supabaseAreaId,
              'name': name,
            }, onConflict: 'id');
            roadsUploaded++;
          } catch (e) {
            roadsFailed++;
            debugPrint('[SYNC] Road "$name" FAILED: $e');
          }
        }
      }

      debugPrint('[SYNC] Areas: $areasUploaded uploaded, $areasFailed failed');
      debugPrint('[SYNC] Roads: $roadsUploaded uploaded, $roadsFailed failed');
      debugPrint('[SYNC] Sub-Roads: $subRoadsUploaded uploaded, $subRoadsFailed failed');
    } catch (e) {
      debugPrint('SyncService: Error during syncAreasAndRoads: $e');
    }

    return {
      'areasUploaded': areasUploaded,
      'roadsUploaded': roadsUploaded,
      'subRoadsUploaded': subRoadsUploaded,
      'areasFailed': areasFailed,
      'roadsFailed': roadsFailed,
      'subRoadsFailed': subRoadsFailed,
    };
  }

  // =====================================================
  // SYNC INVENTORY (SQLite items → Supabase categories/products)
  // =====================================================
  Future<Map<String, int>> syncInventory() async {
    int categoriesSynced = 0;
    int productsUploaded = 0;
    int productsFailed = 0;

    try {
      await _ensureSupabaseAuth();
      final client = Supabase.instance.client;
      final db = await DatabaseHelper.instance.database;

      // 1. Collect unique categories from items
      final List<Map<String, dynamic>> items = await db.query(
        'items',
        where: "is_archived IS NULL OR is_archived = 0",
      );

      final Set<String> categoryNames = {};
      for (final item in items) {
        final cat = (item['category'] as String? ?? '').trim();
        if (cat.isNotEmpty) categoryNames.add(cat);
      }

      // 2. Upsert categories to Supabase
      final Map<String, String> categoryNameToId = {};
      for (final catName in categoryNames) {
        try {
          // Check if category exists
          final existing = await client
              .from('categories')
              .select('id')
              .eq('name', catName)
              .maybeSingle();

          if (existing != null) {
            categoryNameToId[catName] = existing['id'] as String;
          } else {
            final inserted = await client
                .from('categories')
                .insert({'name': catName, 'is_enabled': true})
                .select('id')
                .single();
            categoryNameToId[catName] = inserted['id'] as String;
          }
          categoriesSynced++;
        } catch (e) {
          debugPrint('[SYNC] Category "$catName" FAILED: $e');
        }
      }

      // 3. Upsert products
      for (final item in items) {
        final localId = item['id'] as String;
        final name = (item['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;

        final category = (item['category'] as String? ?? '').trim();
        final categoryId = categoryNameToId[category];
        final sellingPrice = (item['selling_price'] as num?)?.toDouble() ?? 0.0;
        final stock = (item['stock'] as num?)?.toDouble() ?? 0.0;
        final unit = (item['unit'] as String? ?? 'kg').trim();

        // Use the local UUID directly if it's valid, else generate deterministic one
        final productId = _getValidUuid(localId);

        try {
          await client.from('products').upsert({
            'id': productId,
            'name': name,
            'category_id': categoryId,
            'price': sellingPrice,
            'unit': unit,
            'is_available': stock > 0,
            'is_enabled': true,
          }, onConflict: 'id');
          productsUploaded++;
        } catch (e) {
          productsFailed++;
          debugPrint('[SYNC] Product "$name" FAILED: $e');
        }
      }

      debugPrint('[SYNC] Categories: $categoriesSynced, Products: $productsUploaded uploaded, $productsFailed failed');
    } catch (e) {
      debugPrint('SyncService: Error during syncInventory: $e');
    }

    return {
      'categoriesSynced': categoriesSynced,
      'productsUploaded': productsUploaded,
      'productsFailed': productsFailed,
    };
  }

  // =====================================================
  // SYNC ALL — Orchestrates full sync (areas → customers → inventory)
  // =====================================================
  Future<Map<String, dynamic>> syncAll({bool forceSync = false}) async {
    debugPrint('[SYNC] === Starting Full Sync (forceSync=$forceSync) ===');

    final routeStats = await syncAreasAndRoads();
    debugPrint('[SYNC] Areas/Roads done.');

    final customerStats = await syncAllExistingCustomers(forceSync: forceSync);
    debugPrint('[SYNC] Customers done.');

    final inventoryStats = await syncInventory();
    debugPrint('[SYNC] Inventory done.');

    debugPrint('[SYNC] === Full Sync Complete ===');

    return {
      ...routeStats,
      ...customerStats,
      ...inventoryStats,
    };
  }


  Future<void> syncOrders() async {
    try {
      await _ensureSupabaseAuth();
      final client = Supabase.instance.client;
      
      // Fetch remote orders from Supabase (confirmed, delivered, preparing, out for delivery, cancelled)
      // Since the admin accepts them, we fetch all orders where status != 'Pending'
      final List<dynamic> orders = await client
          .from('orders')
          .select('*, customers(name, phone)');

      final db = await DatabaseHelper.instance.database;

      for (var ord in orders) {
        try {
          await db.transaction((txn) async {
            final String orderId = ord['id'];
            String customerId = ord['customer_id'] ?? '';
            if (customerId.isEmpty) {
              customerId = 'generic_app_customer';
            }
            
            // Get customer details from nested customers object
            String customerName = 'App Customer';
            String customerPhone = 'Online App User';
            final cust = ord['customers'];
            if (cust is Map<String, dynamic>) {
              customerName = cust['name'] as String? ?? 'App Customer';
              customerPhone = cust['phone'] as String? ?? 'Online App User';
            } else if (ord['customer_phone'] != null) {
              customerPhone = ord['customer_phone'] as String;
            }

            // A. Ensure customer exists in POS SQLite DB to prevent FK violation
            if (customerId.isNotEmpty) {
              final custCheck = await txn.query('customers', where: 'id = ?', whereArgs: [customerId]);
              if (custCheck.isEmpty) {
                // Find a valid street_id or location_id for FK safety
                final streetCheck = await txn.query('streets', columns: ['id'], limit: 1);
                String streetId = 'default_street';
                if (streetCheck.isNotEmpty) {
                  streetId = streetCheck.first['id'] as String;
                } else {
                  final locCheck = await txn.query('locations', columns: ['id'], limit: 1);
                  if (locCheck.isNotEmpty) {
                    streetId = locCheck.first['id'] as String;
                  } else {
                    // Force insert default_area and default_street to satisfy SQLite FOREIGN KEY check
                    final areaCheck = await txn.query('areas', where: 'id = ?', whereArgs: ['default_area']);
                    if (areaCheck.isEmpty) {
                      await txn.insert('areas', {
                        'id': 'default_area',
                        'name': 'Online Area',
                        'description': 'Default area for online customers',
                        'color': 0,
                        'created_at': DateTime.now().toIso8601String(),
                        'updated_at': DateTime.now().toIso8601String(),
                      });
                    }
                    final defaultStreetCheck = await txn.query('streets', where: 'id = ?', whereArgs: ['default_street']);
                    if (defaultStreetCheck.isEmpty) {
                      await txn.insert('streets', {
                        'id': 'default_street',
                        'area_id': 'default_area',
                        'name': 'Online Street',
                        'description': 'Default street for online customers',
                        'created_at': DateTime.now().toIso8601String(),
                      });
                    }
                    // Sync fallback to locations table too
                    try {
                      final locAreaCheck = await txn.query('locations', where: 'id = ?', whereArgs: ['default_area']);
                      if (locAreaCheck.isEmpty) {
                        await txn.insert('locations', {
                          'id': 'default_area',
                          'parent_location_id': null,
                          'name': 'Online Area',
                          'description': 'Default area for online customers',
                          'location_kind': 'area',
                          'sequence_key': '000001',
                          'depth': 0,
                          'materialized_path': '/default_area/',
                          'color': 0,
                          'created_at': DateTime.now().toIso8601String(),
                          'updated_at': DateTime.now().toIso8601String(),
                        });
                      }
                      final locStreetCheck = await txn.query('locations', where: 'id = ?', whereArgs: ['default_street']);
                      if (locStreetCheck.isEmpty) {
                        await txn.insert('locations', {
                          'id': 'default_street',
                          'parent_location_id': 'default_area',
                          'name': 'Online Street',
                          'description': 'Default street for online customers',
                          'location_kind': 'road',
                          'sequence_key': '000001',
                          'depth': 1,
                          'materialized_path': '/default_area/default_street/',
                          'created_at': DateTime.now().toIso8601String(),
                          'updated_at': DateTime.now().toIso8601String(),
                        });
                      }
                    } catch (_) {}
                    streetId = 'default_street';
                  }
                }

                final nowStr = DateTime.now().toIso8601String();
                await txn.insert('customers', {
                  'id': customerId,
                  'street_id': streetId,
                  'location_id': streetId,
                  'name': customerName,
                  'phone1': customerPhone,
                  'phone2': '',
                  'whatsapp': customerPhone,
                  'house_number': ord['houseNumber'] ?? '',
                  'address': ord['delivery_address'] ?? '',
                  'outstanding_balance': 0.0,
                  'total_orders': 0,
                  'total_paid': 0.0,
                  'total_pending': 0.0,
                  'customer_since': nowStr,
                  'created_at': nowStr,
                  'updated_at': nowStr,
                });
              }
            }

            // B. Check if order already exists in POS SQLite DB
            final orderCheck = await txn.query('orders', where: 'id = ?', whereArgs: [orderId]);
            final String serverStatus = ord['status'] ?? 'Confirmed';

            if (orderCheck.isEmpty) {
              // Write new order
              final double grandTotal = (ord['total_amount'] as num?)?.toDouble() ?? 0.0;
              final nowStr = DateTime.now().toIso8601String();
              
              await txn.insert('orders', {
                'id': orderId,
                'customer_id': customerId.isNotEmpty ? customerId : 'generic_app_customer',
                'subtotal': grandTotal,
                'discount': 0.0,
                'delivery_charge': 0.0,
                'smart_rounded_amount': 0.0,
                'grand_total': grandTotal,
                'paid_amount': 0.0,
                'remaining_amount': grandTotal,
                'delivery_status': serverStatus.toLowerCase(),
                'notes': ord['notes'] ?? '',
                'savings': 0.0,
                'created_at': ord['order_date'] ?? nowStr,
                'updated_at': ord['order_date'] ?? nowStr,
              });

              // Fetch order items from Supabase
              final List<dynamic> items = await client
                  .from('order_items')
                  .select()
                  .eq('order_id', orderId);

              for (var item in items) {
                final String itemId = item['product_id'] ?? '';
                final String itemName = item['product_name'] ?? 'Item';
                final double qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
                final double unitPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
                final double subtotal = (item['total_price'] as num?)?.toDouble() ?? (qty * unitPrice);

                await txn.insert('order_items', {
                  'id': const Uuid().v4(),
                  'order_id': orderId,
                  'item_id': itemId,
                  'item_name': itemName,
                  'item_unit': item['unit'] ?? 'kg',
                  'quantity': qty,
                  'unit_price': unitPrice,
                  'total_price': subtotal,
                });

                // Deduct stock in SQLite items table & record stock history (only for active, non-cancelled/non-denied orders)
                if (itemId.isNotEmpty &&
                    serverStatus.toLowerCase() != 'cancelled' &&
                    serverStatus.toLowerCase() != 'denied') {
                  final itemCheck = await txn.query('items', columns: ['id'], where: 'id = ?', whereArgs: [itemId]);
                  if (itemCheck.isNotEmpty) {
                    await txn.rawUpdate(
                      'UPDATE items SET stock = stock - ?, updated_at = ? WHERE id = ?',
                      [qty, nowStr, itemId],
                    );
                    await txn.insert('stock_history', {
                      'id': const Uuid().v4(),
                      'item_id': itemId,
                      'item_name': itemName,
                      'change_amount': -qty,
                      'reason': 'Online App Order #$orderId',
                      'order_id': orderId,
                      'created_at': nowStr,
                    });
                  }
                }
              }

              // Recalculate customer totals
              if (customerId.isNotEmpty) {
                await CustomerDao().recalcCustomerTotals(customerId, executor: txn);
              }
              
              // Trigger local notification for the new order!
              try {
                await NotificationService.instance.showNotification(
                  id: orderId.hashCode,
                  title: 'New Online Order Received!',
                  body: 'Order #$orderId from $customerName ($customerPhone) for ₹${grandTotal.toStringAsFixed(2)}',
                  payload: 'order_$orderId',
                );
              } catch (e) {
                debugPrint('Failed to show local notification: $e');
              }
            } else {
              // C. Order exists locally - check for status sync (Remote Supabase -> Local POS)
              final String localStatus = orderCheck.first['delivery_status'] as String;
              final targetStatus = serverStatus.toLowerCase();

              if (localStatus != targetStatus) {
                 if (targetStatus == 'cancelled' || targetStatus == 'denied') {
                  // Revert stock for all items of this order in SQLite items table
                  final localItems = await txn.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
                  for (var localItem in localItems) {
                    final String itemId = localItem['item_id'] as String? ?? '';
                    final double qty = (localItem['quantity'] as num?)?.toDouble() ?? 0.0;
                    final String itemName = localItem['item_name'] as String? ?? 'Item';
                    
                    if (itemId.isNotEmpty) {
                      final itemCheck = await txn.query('items', columns: ['id'], where: 'id = ?', whereArgs: [itemId]);
                      if (itemCheck.isNotEmpty) {
                        await txn.rawUpdate(
                          'UPDATE items SET stock = stock + ?, updated_at = ? WHERE id = ?',
                          [qty, DateTime.now().toIso8601String(), itemId],
                        );
                        await txn.insert('stock_history', {
                          'id': const Uuid().v4(),
                          'item_id': itemId,
                          'item_name': itemName,
                          'change_amount': qty,
                          'reason': 'Online Order ${targetStatus == 'cancelled' ? 'Cancelled' : 'Denied'} #$orderId',
                          'order_id': orderId,
                          'created_at': DateTime.now().toIso8601String(),
                        });
                      }
                    }
                  }
                  
                  await txn.update(
                    'orders',
                    {'delivery_status': targetStatus, 'updated_at': DateTime.now().toIso8601String()},
                    where: 'id = ?',
                    whereArgs: [orderId],
                  );
                } else {
                  // Update local status to remote status
                  await txn.update(
                    'orders',
                    {'delivery_status': targetStatus, 'updated_at': DateTime.now().toIso8601String()},
                    where: 'id = ?',
                    whereArgs: [orderId],
                  );
                }
                
                // Recalculate customer totals
                if (customerId.isNotEmpty) {
                  await CustomerDao().recalcCustomerTotals(customerId, executor: txn);
                }
              }
            }
          });
        } catch (e) {
          debugPrint('CustomerOrderSyncService order $ord error: $e');
        }
      }

      // D. Clean up deleted orders: Disabled to support permanent local offline order retention history.
      // Missing remote orders are no longer synchronized as deletions.

    } catch (e) {
      debugPrint('CustomerOrderSyncService sync error: $e');
    }
  }

  String _getValidUuid(String rawId) {
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(rawId)) {
      return rawId;
    }
    return const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.customer.$rawId');
  }
}
