import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../utils/unit_converter.dart';
import '../../features/customer/data/customer_dao.dart';

import '../../features/customer/domain/customer.dart';
import 'notification_service.dart';

class CustomerOrderSyncService {
  CustomerOrderSyncService._();
  static final CustomerOrderSyncService instance = CustomerOrderSyncService._();

  Timer? _syncTimer;
  bool _isSyncing = false;

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

  int _syncCycleCount = 0;

  void startSync() {
    _syncTimer?.cancel();
    
    // Immediate initial sync on startup
    Future.microtask(() async {
      try {
        await _ensureSupabaseAuth();
        await pullRemoteCustomersAndGuests();
        await pullLoginLogs();
        await syncAllExistingCustomers();
        await syncInventory();
        await syncOrders();
      } catch (e) {
        debugPrint('Initial sync error: $e');
      }
    });

    // Run fast order sync every 15 seconds, and customer/inventory sync every 2 minutes
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (_isSyncing) return; // Prevent concurrent sync cycles
      _isSyncing = true;
      _syncCycleCount++;
      try {
        await pushModifiedOrders();
        await syncOrders();
        if (_syncCycleCount % 4 == 0) {
          await pullRemoteCustomersAndGuests();
          await pullLoginLogs();
        }
        if (_syncCycleCount % 8 == 0) {
          await syncAllExistingCustomers();
          await syncInventory();
        }
      } catch (e) {
        debugPrint('Periodic sync error: $e');
      } finally {
        _isSyncing = false;
      }
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
          } catch (rpcErr) {
            debugPrint('[SYNC] RPC sync_customer_with_code error: $rpcErr. Falling back to direct upsert.');
            final Map<String, dynamic> row = {
              'id': customerId,
              'name': name,
              'phone': phone,
              'address': address,
              'customer_code': codeRaw,
            };
            if (supabaseAreaId != null) row['area_id'] = supabaseAreaId;
            if (supabaseRoadId != null) row['road_id'] = supabaseRoadId;
            if (supabaseSubRoadId != null) row['sub_road_id'] = supabaseSubRoadId;
            await client.from('customers').upsert(row, onConflict: 'id');
          }

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

  Future<void> pullRemoteCustomersAndGuests() async {
    try {
      await _ensureSupabaseAuth();
      final client = Supabase.instance.client;
      final db = await DatabaseHelper.instance.database;

      final List<dynamic> remoteCusts = await client.from('customers').select('*');
      for (final rc in remoteCusts) {
        final rawId = rc['id']?.toString() ?? '';
        if (rawId.isEmpty) continue;

        final phone = (rc['phone']?.toString() ?? '').trim();
        final name = (rc['name']?.toString() ?? '').trim();
        final address = (rc['address']?.toString() ?? '').trim();
        final codeRaw = (rc['customer_code']?.toString() ?? '').trim();
        final bool isGuest = (rc['is_guest'] == true || rc['is_guest'] == 1 || codeRaw.isEmpty);

        // Check if customer exists in SQLite
        final existing = await db.query(
          'customers',
          where: 'id = ? OR (phone1 = ? AND phone1 != "")',
          whereArgs: [rawId, phone],
        );

        if (existing.isEmpty) {
          // Insert new remote customer / guest into SQLite
          await db.insert(
            'customers',
            {
              'id': rawId,
              'name': name.isNotEmpty ? name : (isGuest ? 'Guest Customer' : 'Customer'),
              'phone1': phone,
              'phone2': '',
              'whatsapp': phone,
              'house_number': '',
              'address': address,
              'notes': '',
              'maps_location': '',
              'photo_path': '',
              'serial_no': 0,
              'outstanding_balance': 0.0,
              'total_orders': 0,
              'total_paid': 0.0,
              'total_pending': 0.0,
              'customer_since': rc['created_at']?.toString() ?? DateTime.now().toIso8601String(),
              'last_order_date': '',
              'created_at': rc['created_at']?.toString() ?? DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
              'dietary_preference': '',
              'custom_welcome_message': '',
              'device_key': '',
              'device_status': 'BOUND',
              'visit_count': 0,
              'is_guest': isGuest ? 1 : 0,
              'locality': '',
              'customer_code': codeRaw,
              'street_id': '',
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          // Update existing customer record with latest guest status / customer_code
          final existingId = existing.first['id'] as String;
          await db.update(
            'customers',
            {
              'is_guest': isGuest ? 1 : 0,
              if (codeRaw.isNotEmpty) 'customer_code': codeRaw,
              if (name.isNotEmpty) 'name': name,
              if (address.isNotEmpty) 'address': address,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [existingId],
          );
        }
      }
    } catch (e) {
      debugPrint('SyncService: Error pulling remote customers/guests: $e');
    }
  }

  Future<void> pullLoginLogs() async {
    try {
      await _ensureSupabaseAuth();
      final client = Supabase.instance.client;
      final db = await DatabaseHelper.instance.database;

      final List<dynamic> logs = await client
          .from('customer_login_logs')
          .select('*')
          .order('logged_in_at', ascending: false)
          .limit(100);

      for (final log in logs) {
        final id = log['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        await db.insert(
          'customer_login_logs',
          {
            'id': id,
            'customer_id': log['customer_id']?.toString(),
            'customer_code': log['customer_code']?.toString(),
            'customer_name': log['customer_name']?.toString(),
            'customer_phone': log['customer_phone']?.toString(),
            'login_method': log['login_method']?.toString(),
            'logged_in_at': log['logged_in_at']?.toString(),
            'device_info': log['device_info']?.toString(),
            'app_version': log['app_version']?.toString(),
            'expires_at': log['expires_at']?.toString(),
            'created_at': log['created_at']?.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Automatically prune local records older than 5 days
      final fiveDaysAgo = DateTime.now().toUtc().subtract(const Duration(days: 5)).toIso8601String();
      await db.delete(
        'customer_login_logs',
        where: "logged_in_at < ?",
        whereArgs: [fiveDaysAgo],
      );
    } catch (e) {
      debugPrint('SyncService: Error pulling login logs: $e');
    }
  }


  Future<void> syncSingleCustomer(Customer customer) async {
    final String name = customer.name.trim();
    final String phone = customer.phone1.trim();
    final bool isGhost = name.isEmpty ||
        name == '[Ghost House]' ||
        name.toLowerCase() == 'ghost house' ||
        name.startsWith('[Ghost House]') ||
        phone == '0000000000' ||
        phone.isEmpty;
    if (isGhost) return;

    try {
      await _ensureSupabaseAuth();
      final client = Supabase.instance.client;
      final uuidRegex = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final cleanId = uuidRegex.hasMatch(customer.id)
          ? customer.id
          : const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.customer.${customer.id}');

      await client.rpc('sync_customer_with_code', params: {
        'p_id': cleanId,
        'p_name': name,
        'p_phone': phone,
        'p_email': '',
        'p_address': customer.address.trim(),
        'p_customer_code': customer.customerCode.trim().toUpperCase(),
      }).timeout(const Duration(seconds: 8));
      debugPrint('SyncService: Single customer $name synced to Supabase.');
    } catch (e) {
      debugPrint('SyncService: Single customer background sync error: $e');
    }
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

          List<dynamic> sched = [];
          if (loc['delivery_schedule'] != null) {
            try {
              final decoded = json.decode(loc['delivery_schedule'] as String);
              if (decoded is List) {
                sched = decoded;
              }
            } catch (_) {}
          }
          final cutoffTime = loc['cutoff_time'] as String? ?? '23:59';
          final deliveryCharge = (loc['delivery_charge'] as num?)?.toDouble() ?? 0.0;
          final minOrderAmount = (loc['min_order_amount'] as num?)?.toDouble() ?? 0.0;
          final isActive = (loc['is_active'] == null || loc['is_active'] == 1 || loc['is_active'] == true || loc['is_active'].toString() == 'true');

          try {
            await client.from('areas').upsert({
              'id': supabaseId,
              'area_code': areaCode,
              'name': name,
              'delivery_schedule': sched,
              'cutoff_time': cutoffTime,
              'delivery_charge': deliveryCharge,
              'min_order_amount': minOrderAmount,
              'is_active': isActive,
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

          List<dynamic> sched = [];
          if (area['delivery_schedule'] != null) {
            try {
              final decoded = json.decode(area['delivery_schedule'] as String);
              if (decoded is List) {
                sched = decoded;
              }
            } catch (_) {}
          }
          final cutoffTime = area['cutoff_time'] as String? ?? '23:59';
          final deliveryCharge = (area['delivery_charge'] as num?)?.toDouble() ?? 0.0;
          final minOrderAmount = (area['min_order_amount'] as num?)?.toDouble() ?? 0.0;
          final isActive = (area['is_active'] == null || area['is_active'] == 1 || area['is_active'] == true || area['is_active'].toString() == 'true');

          try {
            await client.from('areas').upsert({
              'id': supabaseId,
              'area_code': areaCode,
              'name': name,
              'delivery_schedule': sched,
              'cutoff_time': cutoffTime,
              'delivery_charge': deliveryCharge,
              'min_order_amount': minOrderAmount,
              'is_active': isActive,
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

      // 3. Fetch remote products for conflict resolution
      List<dynamic> productsJson = [];
      try {
        productsJson = await client.from('products').select('*, categories(id, name)');
      } catch (e) {
        debugPrint('[SYNC] Failed to fetch remote products for conflict resolution: $e');
      }

      final Map<String, Map<String, dynamic>> remoteProductsById = {};
      final Map<String, Map<String, dynamic>> remoteProductsByName = {};

      for (final p in productsJson) {
        final String id = p['id'] as String? ?? '';
        final String name = p['name'] as String? ?? '';
        if (id.isNotEmpty) {
          remoteProductsById[id] = Map<String, dynamic>.from(p);
        }
        if (name.isNotEmpty) {
          remoteProductsByName[name.toLowerCase()] = Map<String, dynamic>.from(p);
        }
      }

      for (final item in items) {
        final localId = item['id'] as String;
        final name = (item['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;

        final category = (item['category'] as String? ?? '').trim();
        final categoryId = categoryNameToId[category];
        final sellingPrice = (item['selling_price'] as num?)?.toDouble() ?? 0.0;
        final stock = (item['stock'] as num?)?.toDouble() ?? 0.0;
        final unit = (item['unit'] as String? ?? 'kg').trim();
        
        final localUpdatedStr = item['updated_at']?.toString() ?? '';
        final localUpdatedAt = DateTime.tryParse(localUpdatedStr) ?? DateTime.fromMillisecondsSinceEpoch(0);

        final productId = _getValidUuid(localId);
        
        final Map<String, dynamic>? matchingRemote = remoteProductsById[productId] ?? remoteProductsByName[name.toLowerCase()];

        // Build the description JSON block containing extra properties (MRP, cost, min stock, weight per piece, sequence, etc.)
        final double costPrice = (item['cost_price'] as num?)?.toDouble() ?? 0.0;
        final double marketPrice = (item['market_price'] as num?)?.toDouble() ?? 0.0;
        final double minStock = (item['min_stock'] as num?)?.toDouble() ?? 0.0;
        final String barcode = (item['barcode'] as String? ?? '').trim();
        final String expiryDate = (item['expiry_date'] as String? ?? '').trim();
        final String batchNumber = (item['batch_number'] as String? ?? '').trim();
        final bool prescriptionRequired = (item['prescription_required'] == 1 || item['prescription_required'] == true);
        final String dosageInfo = (item['dosage_info'] as String? ?? '').trim();
        final String bestBefore = (item['best_before'] as String? ?? '').trim();
        final String packDate = (item['pack_date'] as String? ?? '').trim();
        final double weightPerPiece = (item['weight_per_piece'] as num?)?.toDouble() ?? 0.25;
        final String photoPath = (item['photo_path'] as String? ?? '').trim();
        final int sequenceNo = (item['sequence_no'] as num?)?.toInt() ?? 0;
        final String notes = (item['description'] as String? ?? '').trim();

        final extra = {
          'text': notes,
          'cost_price': costPrice,
          'market_price': marketPrice,
          'mrp': marketPrice,
          'stock': stock,
          'min_stock': minStock,
          'barcode': barcode,
          'expiry_date': expiryDate,
          'batch_number': batchNumber,
          'prescription_required': prescriptionRequired,
          'dosage_info': dosageInfo,
          'best_before': bestBefore,
          'pack_date': packDate,
          'weight_per_piece': weightPerPiece,
          'photo_path': photoPath,
          'sequence_no': sequenceNo,
        };

        final double orderNowStock = (item['order_now_stock'] as num?)?.toDouble() ?? 0.0;
        final double orderNowPrice = (item['order_now_selling_price'] as num?)?.toDouble() ?? (item['order_now_price'] as num?)?.toDouble() ?? 0.0;
        final double orderNowMrp = (item['order_now_mrp'] as num?)?.toDouble() ?? 0.0;
        final double orderNowCostPrice = (item['order_now_cost_price'] as num?)?.toDouble() ?? 0.0;
        final bool orderNowIsAvailable = item['order_now_is_available'] == null
            ? true
            : (item['order_now_is_available'] == 1 || item['order_now_is_available'] == true);

        if (matchingRemote != null) {
          final remoteUpdatedStr = matchingRemote['updated_at']?.toString() ?? matchingRemote['created_at']?.toString() ?? '';
          final remoteUpdatedAt = DateTime.tryParse(remoteUpdatedStr) ?? DateTime.fromMillisecondsSinceEpoch(0);

          // OrderKart is the absolute source of truth for pricing (price/selling_price, mrp/market_price, cost_price) and stock.
          // We always push local values of these fields to Supabase.
          // For other metadata fields (name, category_id, unit, image_path), we follow the updated_at rule.

          if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
            // Local is newer -> push/update remote product (includes metadata and prices/stock)
            try {
              await client.from('products').update({
                'name': name,
                'category_id': categoryId,
                'price': sellingPrice,
                'selling_price': sellingPrice,
                'mrp': marketPrice,
                'stock': stock,
                'unit': unit,
                'description': json.encode(extra),
                'image_path': photoPath,
                'is_available': stock > 0,
                'is_enabled': true,
                'order_now_stock': orderNowStock,
                'order_now_price': orderNowPrice,
                'order_now_mrp': orderNowMrp,
                'order_now_cost_price': orderNowCostPrice,
                'order_now_is_available': orderNowIsAvailable,
              }).eq('id', matchingRemote['id']);
              productsUploaded++;
            } catch (e) {
              productsFailed++;
              debugPrint('[SYNC] Product "$name" update FAILED: $e');
            }
          } else {
            // Remote is newer -> update local SQLite metadata, but DO NOT overwrite local prices/stock/mrp/cost.
            // Also, push local prices/stock/mrp/cost back to remote so they stay authoritative.
            final String remoteName = matchingRemote['name'] as String? ?? name;
            final String remoteUnit = matchingRemote['unit'] as String? ?? unit;
            final String remoteImage = matchingRemote['image_path'] as String? ?? photoPath;
            
            // Extract remote description JSON values for other non-price/stock metadata fields if needed
            double parsedMinStock = minStock;
            String parsedBarcode = barcode;
            String parsedExpiry = expiryDate;
            String parsedBatch = batchNumber;
            bool parsedRx = prescriptionRequired;
            String parsedDosage = dosageInfo;
            String parsedBestBefore = bestBefore;
            String parsedPackDate = packDate;
            double parsedWeight = weightPerPiece;
            int parsedSeq = sequenceNo;

            final desc = matchingRemote['description'] as String? ?? '';
            if (desc.trim().startsWith('{') && desc.trim().endsWith('}')) {
              try {
                final Map<String, dynamic> decoded = json.decode(desc);
                parsedMinStock = (decoded['min_stock'] as num?)?.toDouble() ?? parsedMinStock;
                parsedBarcode = decoded['barcode'] as String? ?? parsedBarcode;
                parsedWeight = (decoded['weight_per_piece'] as num?)?.toDouble() ?? parsedWeight;
                parsedSeq = decoded['sequence_no'] as int? ?? decoded['serial_no'] as int? ?? parsedSeq;
                parsedExpiry = decoded['expiry_date'] as String? ?? parsedExpiry;
                parsedBatch = decoded['batch_number'] as String? ?? parsedBatch;
                parsedRx = decoded['prescription_required'] as bool? ?? parsedRx;
                parsedDosage = decoded['dosage_info'] as String? ?? parsedDosage;
                parsedBestBefore = decoded['best_before'] as String? ?? parsedBestBefore;
                parsedPackDate = decoded['pack_date'] as String? ?? parsedPackDate;
              } catch (_) {}
            }

            try {
              // Update local SQLite with remote metadata (but strictly preserve local prices, stock, mrp, cost_price!)
              await db.update(
                'items',
                {
                  'name': remoteName,
                  'unit': remoteUnit,
                  'photo_path': remoteImage,
                  'min_stock': parsedMinStock,
                  'weight_per_piece': parsedWeight,
                  'sequence_no': parsedSeq,
                  'updated_at': remoteUpdatedAt.toIso8601String(),
                  // Preserve local values explicitly:
                  'selling_price': sellingPrice,
                  'stock': stock,
                  'cost_price': costPrice,
                  'market_price': marketPrice,
                },
                where: 'id = ?',
                whereArgs: [localId],
              );

              // Update optional columns inside separate try-catches in case they are missing in SQLite
              final List<String> optColumns = ['barcode', 'expiry_date', 'batch_number', 'prescription_required', 'dosage_info', 'best_before', 'pack_date'];
              final Map<String, dynamic> optUpdates = {
                'barcode': parsedBarcode,
                'expiry_date': parsedExpiry,
                'batch_number': parsedBatch,
                'prescription_required': parsedRx ? 1 : 0,
                'dosage_info': parsedDosage,
                'best_before': parsedBestBefore,
                'pack_date': parsedPackDate,
              };

              for (final col in optColumns) {
                try {
                  await db.update('items', {col: optUpdates[col]}, where: 'id = ?', whereArgs: [localId]);
                } catch (_) {}
              }

              // Since OrderKart is the authority, push local price/stock/mrp/cost and order now fields back to remote products table
              await client.from('products').update({
                'price': sellingPrice,
                'selling_price': sellingPrice,
                'mrp': marketPrice,
                'stock': stock,
                'description': json.encode(extra),
                'is_available': stock > 0,
                'order_now_stock': orderNowStock,
                'order_now_price': orderNowPrice,
                'order_now_mrp': orderNowMrp,
                'order_now_cost_price': orderNowCostPrice,
                'order_now_is_available': orderNowIsAvailable,
              }).eq('id', matchingRemote['id']);
              
              productsUploaded++;
            } catch (e) {
              debugPrint('[SYNC] Local metadata update for "$name" FAILED: $e');
            }
          }
        } else {
          // Does not exist remotely -> insert with new columns
          try {
            await client.from('products').insert({
              'id': productId,
              'name': name,
              'category_id': categoryId,
              'price': sellingPrice,
              'selling_price': sellingPrice,
              'mrp': marketPrice,
              'stock': stock,
              'unit': unit,
              'description': json.encode(extra),
              'image_path': photoPath,
              'is_available': stock > 0,
              'is_enabled': true,
              'order_now_stock': orderNowStock,
              'order_now_price': orderNowPrice,
              'order_now_mrp': orderNowMrp,
              'order_now_cost_price': orderNowCostPrice,
              'order_now_is_available': orderNowIsAvailable,
            });
            productsUploaded++;
          } catch (e) {
            productsFailed++;
            debugPrint('[SYNC] Product "$name" insert FAILED: $e');
          }
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
      // NOTE: pushModifiedOrders() is already called by startSync() before syncOrders().
      // Do NOT call it again here to avoid double-inserting order items on Supabase.
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

            // Build a map of UUID to local SQLite item ID
            final List<Map<String, dynamic>> dbItems = await txn.query('items', columns: ['id']);
            final Map<String, String> uuidToLocalId = {};
            for (final row in dbItems) {
              final String rawId = row['id'] as String? ?? '';
              if (rawId.isNotEmpty) {
                final String uuid = _getValidUuid(rawId);
                uuidToLocalId[uuid] = rawId;
              }
            }

            final deletedCheck = await txn.query('deleted_orders', columns: ['id'], where: 'id = ?', whereArgs: [orderId]);
            if (deletedCheck.isNotEmpty) {
              return;
            }

            final localCheck = await txn.query('orders', columns: ['sync_status'], where: 'id = ?', whereArgs: [orderId]);
            if (localCheck.isNotEmpty && localCheck.first['sync_status'] == 'pending_update') {
              return;
            }
            String customerId = ord['customer_id'] ?? '';
            if (customerId.isEmpty) {
              customerId = 'generic_app_customer';
            }
            
            // Get customer details from nested customers object
            String customerName = 'App Customer';
            String customerPhone = 'Online App User';
            final cust = ord['customers'];
            if (cust is Map<String, dynamic>) {
              customerName = cust['name'] as String? ?? ord['customer_name'] as String? ?? ord['name'] as String? ?? 'App Customer';
              customerPhone = cust['phone'] as String? ?? ord['customer_phone'] as String? ?? 'Online App User';
            } else {
              if (ord['customer_name'] != null && (ord['customer_name'] as String).trim().isNotEmpty) {
                customerName = (ord['customer_name'] as String).trim();
              } else if (ord['name'] != null && (ord['name'] as String).trim().isNotEmpty) {
                customerName = (ord['name'] as String).trim();
              }
              if (ord['customer_phone'] != null && (ord['customer_phone'] as String).trim().isNotEmpty) {
                customerPhone = (ord['customer_phone'] as String).trim();
              }
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
            final double grandTotal = (ord['total_amount'] as num?)?.toDouble() ?? 0.0;

            // Fetch order items from Supabase
            final List<dynamic> items = await client
                .from('order_items')
                .select()
                .eq('order_id', orderId);

            double itemsSubtotal = 0.0;
            for (var item in items) {
              final double qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
              final double unitPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
              final double subtotal = (item['total_price'] as num?)?.toDouble() ?? (qty * unitPrice);
              itemsSubtotal += subtotal;
            }

            final double calculatedDeliveryCharge = (grandTotal > itemsSubtotal + 0.05 && itemsSubtotal > 0)
                ? (grandTotal - itemsSubtotal)
                : 0.0;
            final double actualSubtotal = itemsSubtotal > 0 ? itemsSubtotal : grandTotal;

            if (orderCheck.isEmpty) {
              // Write new order
              final nowStr = DateTime.now().toIso8601String();
              
              await txn.insert('orders', {
                'id': orderId,
                'customer_id': customerId.isNotEmpty ? customerId : 'generic_app_customer',
                'subtotal': actualSubtotal,
                'discount': 0.0,
                'delivery_charge': calculatedDeliveryCharge,
                'smart_rounded_amount': 0.0,
                'grand_total': grandTotal,
                'paid_amount': 0.0,
                'remaining_amount': grandTotal,
                'delivery_status': serverStatus.toLowerCase(),
                'notes': ord['notes'] ?? '',
                'savings': 0.0,
                'created_at': ord['order_date'] ?? nowStr,
                'updated_at': ord['order_date'] ?? nowStr,
                'order_type': ord['order_type'] ?? 'Normal',
                'order_taking_date': ord['order_taking_date'],
                'delivery_date': ord['delivery_date']?.toString(),
                'sync_status': 'synced',
                'order_number': ord['order_number'],
              });

              for (var item in items) {
                final String remoteItemId = item['product_id'] ?? '';
                final String localItemId = uuidToLocalId[remoteItemId] ?? remoteItemId;
                final String itemName = item['product_name'] ?? 'Item';
                final double qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
                final double unitPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
                final double subtotal = (item['total_price'] as num?)?.toDouble() ?? (qty * unitPrice);

                await txn.insert('order_items', {
                  'id': const Uuid().v4(),
                  'order_id': orderId,
                  'item_id': localItemId,
                  'item_name': itemName,
                  'item_unit': item['unit'] ?? 'kg',
                  'quantity': qty,
                  'unit_price': unitPrice,
                  'total_price': subtotal,
                  'is_available': (subtotal == 0.0 && unitPrice > 0.001) ? 0 : 1,
                });

                // Deduct stock in SQLite items table & record stock history (only for active, non-cancelled/non-denied orders)
                if (localItemId.isNotEmpty &&
                    serverStatus.toLowerCase() != 'cancelled' &&
                    serverStatus.toLowerCase() != 'denied') {
                  final itemCheck = await txn.query('items', columns: ['id', 'unit'], where: 'id = ?', whereArgs: [localItemId]);
                  if (itemCheck.isNotEmpty) {
                    final itemUnit = itemCheck.first['unit'] as String? ?? 'kg';
                    final orderUnit = item['unit'] as String? ?? itemUnit;
                    final double baseQty = UnitConverter.convert(quantity: qty, fromUnit: orderUnit, toUnit: itemUnit);

                    await txn.rawUpdate(
                      'UPDATE items SET stock = stock - ?, updated_at = ? WHERE id = ?',
                      [baseQty, nowStr, localItemId],
                    );
                    await txn.insert('stock_history', {
                      'id': const Uuid().v4(),
                      'item_id': localItemId,
                      'item_name': itemName,
                      'change_amount': -baseQty,
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
                final isQuickOrder = (ord['order_type'] == 'Quick Order' ||
                    ord['order_type'] == 'Quick Delivery' ||
                    ord['order_type'] == 'Order Now');
                final notifTitle = isQuickOrder
                    ? '⚡ Quick Order (1-2 Hrs) Received!'
                    : 'New Online Order Received!';
                final notifBody = isQuickOrder
                    ? '⚡ 1-2 Hrs Quick Order #${ord['order_number'] ?? orderId} from $customerName for ₹${grandTotal.toStringAsFixed(2)}'
                    : 'Order #${ord['order_number'] ?? orderId} from $customerName ($customerPhone) for ₹${grandTotal.toStringAsFixed(2)}';

                await NotificationService.instance.showNotification(
                  id: orderId.hashCode,
                  title: notifTitle,
                  body: notifBody,
                  payload: 'order_$orderId',
                );
              } catch (e) {
                debugPrint('Failed to show local notification: $e');
              }
            } else {
              // C. Order exists locally - update all fields from Supabase
              final currentSyncStatus = orderCheck.first['sync_status'] as String? ?? 'synced';
              if (currentSyncStatus == 'pending_update' || currentSyncStatus == 'syncing') {
                // Local edits are pending upload -> preserve local state until pushModifiedOrders succeeds
                return;
              }


              final String localStatus = orderCheck.first['delivery_status'] as String;
              final targetStatus = serverStatus.toLowerCase();

              final double remoteTotal = (ord['total_amount'] as num?)?.toDouble() ?? 0.0;
              final String remoteNotes = ord['notes'] ?? '';
              final String? remoteOrderType = ord['order_type'];
              final String? remoteOrderTakingDate = ord['order_taking_date'];
              final String? remoteDeliveryDate = ord['delivery_date']?.toString();

              if (localStatus != targetStatus) {
                if (targetStatus == 'cancelled' || targetStatus == 'denied') {
                  // Revert stock for all items of this order in SQLite items table
                  final localItems = await txn.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
                  for (var localItem in localItems) {
                    final String itemId = localItem['item_id'] as String? ?? '';
                    final double qty = (localItem['quantity'] as num?)?.toDouble() ?? 0.0;
                    final String itemName = localItem['item_name'] as String? ?? 'Item';
                    
                    final String orderUnit = localItem['item_unit'] as String? ?? 'kg';
                    if (itemId.isNotEmpty) {
                      final itemCheck = await txn.query('items', columns: ['id', 'unit'], where: 'id = ?', whereArgs: [itemId]);
                      if (itemCheck.isNotEmpty) {
                        final itemUnit = itemCheck.first['unit'] as String? ?? 'kg';
                        final double baseQty = UnitConverter.convert(quantity: qty, fromUnit: orderUnit, toUnit: itemUnit);

                        await txn.rawUpdate(
                          'UPDATE items SET stock = stock + ?, updated_at = ? WHERE id = ?',
                          [baseQty, DateTime.now().toIso8601String(), itemId],
                        );
                        await txn.insert('stock_history', {
                          'id': const Uuid().v4(),
                          'item_id': itemId,
                          'item_name': itemName,
                          'change_amount': baseQty,
                          'reason': 'Online Order ${targetStatus == 'cancelled' ? 'Cancelled' : 'Denied'} #$orderId',
                          'order_id': orderId,
                          'created_at': DateTime.now().toIso8601String(),
                        });
                      }
                    }

                  }
                }
              }

              // Update order items from Supabase
              if (items.isNotEmpty) {
                await txn.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
                for (var item in items) {
                  final String remoteItemId = item['product_id'] ?? '';
                  final String localItemId = uuidToLocalId[remoteItemId] ?? remoteItemId;
                  final String itemName = item['product_name'] ?? 'Item';
                  final double qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
                  final double unitPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
                  final double subtotal = (item['total_price'] as num?)?.toDouble() ?? (qty * unitPrice);

                  await txn.insert('order_items', {
                    'id': const Uuid().v4(),
                    'order_id': orderId,
                    'item_id': localItemId,
                    'item_name': itemName,
                    'item_unit': item['unit'] ?? 'kg',
                    'quantity': qty,
                    'unit_price': unitPrice,
                    'total_price': subtotal,
                    'is_available': (subtotal == 0.0 && unitPrice > 0.001) ? 0 : 1,
                  });
                }
              }

              final double paidAmount = (orderCheck.first['paid_amount'] as num?)?.toDouble() ?? 0.0;
              final double existingDelivery = (orderCheck.first['delivery_charge'] as num?)?.toDouble() ?? 0.0;
              final double effectiveDelivery = existingDelivery > 0
                  ? existingDelivery
                  : ((remoteTotal > itemsSubtotal + 0.05 && itemsSubtotal > 0)
                      ? (remoteTotal - itemsSubtotal)
                      : 0.0);
              final double effectiveSubtotal = itemsSubtotal > 0
                  ? itemsSubtotal
                  : (remoteTotal - effectiveDelivery);

              await txn.update(
                'orders',
                {
                  'subtotal': effectiveSubtotal,
                  'delivery_charge': effectiveDelivery,
                  'grand_total': remoteTotal,
                  'remaining_amount': (remoteTotal - paidAmount) > 0 ? (remoteTotal - paidAmount) : 0.0,
                  'delivery_status': targetStatus,
                  'notes': remoteNotes,
                  'order_type': remoteOrderType ?? 'Normal',
                  'order_taking_date': remoteOrderTakingDate,
                  'delivery_date': remoteDeliveryDate,
                  'updated_at': ord['updated_at'] ?? DateTime.now().toIso8601String(),
                  'sync_status': 'synced',
                  'order_number': ord['order_number'],
                },
                where: 'id = ?',
                whereArgs: [orderId],
              );
            }
            // Recalculate customer totals
            if (customerId.isNotEmpty) {
              await CustomerDao().recalcCustomerTotals(customerId, executor: txn);
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

  Future<void> pushModifiedOrders() async {
    try {
      await _ensureSupabaseAuth();
      final client = Supabase.instance.client;
      final db = await DatabaseHelper.instance.database;

      final List<Map<String, dynamic>> modifiedOrders = await db.query(
        'orders',
        where: "sync_status = 'pending_update'",
      );

      if (modifiedOrders.isEmpty) return;

      // 0. Fetch products from Supabase to resolve exact product_id foreign keys reliably
      final List<dynamic> remoteProducts = await client.from('products').select('id, name, mrp, price');
      final Map<String, String> remoteProdById = {};
      final Map<String, String> remoteProdByName = {};
      final Map<String, double> remoteMrpByName = {};
      for (final p in remoteProducts) {
        final String pid = p['id'] as String;
        final String pname = (p['name'] as String? ?? '').toLowerCase().trim();
        final double pmrp = (p['mrp'] as num?)?.toDouble() ?? (p['price'] as num?)?.toDouble() ?? 0.0;
        remoteProdById[pid] = pid;
        if (pname.isNotEmpty) {
          remoteProdByName[pname] = pid;
          remoteMrpByName[pname] = pmrp;
        }
      }

      for (var ord in modifiedOrders) {
        try {
          final String orderId = ord['id'] as String;

          // Optimistic lock: mark as 'syncing' immediately to prevent
          // a concurrent push from re-processing the same order and
          // duplicating items on Supabase.
          await db.update(
            'orders',
            {'sync_status': 'syncing'},
            where: "id = ? AND sync_status = 'pending_update'",
            whereArgs: [orderId],
          );
          final double grandTotal = (ord['grand_total'] as num?)?.toDouble() ?? 0.0;
          final String localStatus = ord['delivery_status'] as String? ?? 'pending';
          
          final String? orderType = ord['order_type'] as String?;
          final String? orderTakingDate = ord['order_taking_date'] as String?;
          final String? deliveryDate = ord['delivery_date'] as String?;
          final String? localOrderNo = ord['order_number'] as String?;

          final serverStatus = _toServerStatus(localStatus);

          // 1. Check if the order exists remotely or needs to be inserted
          final existingRemote = await client
              .from('orders')
              .select('id, order_number')
              .eq('id', orderId)
              .maybeSingle();

          String canonicalOrderNo = localOrderNo ?? '';

          if (existingRemote == null) {
            // Find customer details in local DB to populate remote order fields
            final custRows = await db.query('customers', where: 'id = ?', whereArgs: [ord['customer_id']]);
            final String custPhone = custRows.isNotEmpty ? (custRows.first['phone1'] as String? ?? '') : '';
            final String custAddress = custRows.isNotEmpty ? (custRows.first['address'] as String? ?? '') : '';
            final String custName = custRows.isNotEmpty ? (custRows.first['name'] as String? ?? '') : '';

            final insertPayload = <String, dynamic>{
              'id': orderId,
              'customer_id': _getValidUuid(ord['customer_id'] as String? ?? ''),
              'customer_phone': custPhone,
              'customer_name': custName,
              'delivery_address': custAddress,
              'total_amount': grandTotal,
              'status': serverStatus,
              'notes': ord['notes'] ?? '',
              'order_type': orderType ?? 'Normal',
              if (orderTakingDate != null && orderTakingDate.isNotEmpty) 'order_taking_date': orderTakingDate,
              if (deliveryDate != null && deliveryDate.isNotEmpty) 'delivery_date': deliveryDate,
              if (localOrderNo != null && localOrderNo.isNotEmpty) 'order_number': localOrderNo,
              'order_date': ord['created_at'] ?? DateTime.now().toIso8601String(),
              'created_at': ord['created_at'] ?? DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            };

            final inserted = await client
                .from('orders')
                .insert(insertPayload)
                .select('order_number')
                .maybeSingle();
            if (inserted != null && inserted['order_number'] != null) {
              canonicalOrderNo = inserted['order_number'].toString();
            }
          } else {
            final updatePayload = <String, dynamic>{
              'total_amount': grandTotal,
              'status': serverStatus,
            };
            if (orderType != null && orderType.isNotEmpty) {
              updatePayload['order_type'] = orderType;
            }
            if (orderTakingDate != null && orderTakingDate.isNotEmpty) {
              updatePayload['order_taking_date'] = orderTakingDate;
            }
            if (deliveryDate != null && deliveryDate.isNotEmpty) {
              updatePayload['delivery_date'] = deliveryDate;
            }
            if (localOrderNo != null && localOrderNo.isNotEmpty) {
              updatePayload['order_number'] = localOrderNo;
            }

            final List<dynamic> updatedOrders = await client
                .from('orders')
                .update(updatePayload)
                .eq('id', orderId)
                .select('order_number');

            if (updatedOrders.isNotEmpty) {
              canonicalOrderNo = updatedOrders.first['order_number'] as String? ?? canonicalOrderNo;
            }
          }


          // 2. Fetch order items from SQLite
          final List<Map<String, dynamic>> localItems = await db.query(
            'order_items',
            where: 'order_id = ?',
            whereArgs: [orderId],
          );

          // 3. Clear remote order items
          await client.from('order_items').delete().eq('order_id', orderId);

          // 4. Upload updated items
          if (localItems.isNotEmpty) {
            final itemsToInsert = localItems.map((item) {
              final String rawItemId = item['item_id'] as String? ?? '';
              final String itemName = (item['item_name'] as String? ?? '').trim();
              final String targetProductId = remoteProdById[rawItemId] ??
                  remoteProdByName[itemName.toLowerCase()] ??
                  _getValidUuid(rawItemId);

              final double unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
              final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
              final double totalPrice = (item['total_price'] as num?)?.toDouble() ?? (unitPrice * qty);
              final double mrp = remoteMrpByName[itemName.toLowerCase()] ?? unitPrice;

              return {
                'id': const Uuid().v4(),
                'order_id': orderId,
                'product_id': targetProductId,
                'product_name': itemName,
                'price': unitPrice,
                'quantity': qty,
                'unit': (item['item_unit'] as String? ?? 'kg').trim(),
                'total_price': totalPrice,
                'product_name_snapshot': itemName,
                'mrp_snapshot': mrp,
                'selling_price_snapshot': unitPrice,
                'line_total': totalPrice,
              };
            }).toList();

            await client.from('order_items').insert(itemsToInsert);
          }

          // 5. Mark local order as synced & update local order_number
          await db.update(
            'orders',
            {
              'sync_status': 'synced',
              if (canonicalOrderNo.isNotEmpty) 'order_number': canonicalOrderNo,
            },
            where: 'id = ?',
            whereArgs: [orderId],
          );

          debugPrint('[SYNC-UPLOAD] Successfully pushed order $orderId to Supabase.');
        } catch (itemErr) {
          debugPrint('[SYNC-UPLOAD] Error pushing individual order: $itemErr');
          // Revert sync_status so the order is retried on the next cycle
          try {
            await db.update(
              'orders',
              {'sync_status': 'pending_update'},
              where: "id = ? AND sync_status = 'syncing'",
              whereArgs: [ord['id'] as String],
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[SYNC-UPLOAD] Error pushing modified orders: $e');
    }
  }

  String _toServerStatus(String localStatus) {
    switch (localStatus.toLowerCase().trim()) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Confirmed';
      case 'preparing': return 'Preparing';
      case 'out for delivery': return 'Out for Delivery';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return 'Confirmed';
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
