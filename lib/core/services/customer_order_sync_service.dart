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
  bool _isSyncingOrders = false;
  bool _pendingSyncOrdersRequested = false;
  RealtimeChannel? _realtimeOrdersChannel;
  final StreamController<void> _orderChangesController = StreamController<void>.broadcast();
  Stream<void> get onOrderChanged => _orderChangesController.stream;

  void notifyOrderChanged() {
    if (!_orderChangesController.isClosed) {
      _orderChangesController.add(null);
    }
  }

  Future<void> ensureSupabaseAuth() async => _ensureSupabaseAuth();

  Future<void> _ensureSupabaseAuth() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      try {
        await client.auth.signInWithPassword(
          email: 'admin@aplibhaji.com',
          password: 'adminpassword',
        );
        debugPrint('SyncService: Successfully authenticated Supabase client for OrderKart.');
        unawaited(NotificationService.instance.registerAdminFCMToken());
      } catch (e) {
        debugPrint('SyncService: Supabase auto-authentication failed: $e');
      }
    }
  }

  void setupRealtimeSubscription() {
    try {
      final client = Supabase.instance.client;
      _realtimeOrdersChannel?.unsubscribe();
      _realtimeOrdersChannel = client
          .channel('public:orders:admin_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) async {
              debugPrint('SyncService: Realtime orders change event received: ${payload.eventType}');
              try {
                await syncOrders();
                notifyOrderChanged();
              } catch (e) {
                debugPrint('SyncService: Error during realtime syncOrders: $e');
              }
            },
          )
          .subscribe();
      debugPrint('SyncService: Supabase Realtime channel subscribed on public:orders.');
    } catch (e) {
      debugPrint('SyncService: Error setting up Realtime orders channel: $e');
    }
  }

  int _syncCycleCount = 0;

  void startSync() {
    _syncTimer?.cancel();
    
    // Immediate initial sync on startup + setup Realtime channel
    Future.microtask(() async {
      try {
        await _ensureSupabaseAuth();
        setupRealtimeSubscription();
        
        // 1. FAST PATH: Fetch orders immediately and notify UI so dashboard loads in <1s
        await syncOrders();
        notifyOrderChanged();

        // 2. BACKGROUND PATH: Run heavy customer/inventory syncs in background without blocking UI
        Future(() async {
          try {
            await pullRemoteCustomersAndGuests();
            await pullLoginLogs();
            await syncInventory();
          } catch (e) {
            debugPrint('Background initial sync error: $e');
          }
        });
      } catch (e) {
        debugPrint('Initial sync error: $e');
      }
    });

    // Run fast order sync every 45 seconds, and customer/inventory sync every 3 minutes
    _syncTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
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
        if (_syncCycleCount % 2 == 0) {
          await syncAllExistingCustomers();
        }
        if (_syncCycleCount % 8 == 0) {
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
    _realtimeOrdersChannel?.unsubscribe();
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
      final Map<String, Map<String, dynamic>> streetMap = {};
      for (final s in streets) {
        streetToArea[s['id'] as String] = s['area_id'] as String;
        streetMap[s['id'] as String] = s;
      }

      List<Map<String, dynamic>> rawAreas = [];
      try {
        rawAreas = await db.query('areas');
      } catch (_) {}
      final Map<String, Map<String, dynamic>> areaMap = {
        for (final a in rawAreas) a['id'] as String: a
      };

      // Fetch remote areas and roads from Supabase to resolve dedicated IDs
      final Map<String, String> remoteAreasByName = {};
      final Map<String, String> remoteRoadsByName = {};
      final Map<String, String> remoteSubRoadsByName = {};
      try {
        final List<dynamic> rAreas = await client.from('areas').select('id, name');
        for (final a in rAreas) {
          final n = (a['name'] as String? ?? '').trim().toLowerCase();
          if (n.isNotEmpty) remoteAreasByName[n] = a['id'].toString();
        }
        final List<dynamic> rRoads = await client.from('roads').select('id, name');
        for (final r in rRoads) {
          final n = (r['name'] as String? ?? '').trim().toLowerCase();
          if (n.isNotEmpty) remoteRoadsByName[n] = r['id'].toString();
        }
        final List<dynamic> rSubRoads = await client.from('sub_roads').select('id, name');
        for (final sr in rSubRoads) {
          final n = (sr['name'] as String? ?? '').trim().toLowerCase();
          if (n.isNotEmpty) remoteSubRoadsByName[n] = sr['id'].toString();
        }
      } catch (e) {
        debugPrint('[SYNC] Failed to fetch remote areas/roads for customer sync: $e');
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

        // Check if already synced in settings (skip if forceSync is false and record hasn't changed)
        if (!forceSync) {
          final syncTimeCheck = await db.query(
            'settings',
            where: "key = ?",
            whereArgs: ['customer_sync_time:$rawId'],
          );
          if (syncTimeCheck.isNotEmpty) {
            final lastSyncMillis = int.tryParse(syncTimeCheck.first['value']?.toString() ?? '') ?? 0;
            final custUpdatedAtStr = cust['updated_at']?.toString() ?? '';
            final custUpdatedMillis = DateTime.tryParse(custUpdatedAtStr)?.millisecondsSinceEpoch ?? 0;
            if (lastSyncMillis > 0 && custUpdatedMillis > 0 && lastSyncMillis >= custUpdatedMillis) {
              alreadySynced++;
              continue;
            }
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
            final areaName = (ancestors[0]['name'] as String? ?? '').trim();
            supabaseAreaId = remoteAreasByName[areaName.toLowerCase()] ?? (areaName.isNotEmpty ? areaName : null);

            // Road is depth 1 (index 1)
            if (ancestors.length > 1) {
              final roadName = (ancestors[1]['name'] as String? ?? '').trim();
              supabaseRoadId = remoteRoadsByName[roadName.toLowerCase()] ?? (roadName.isNotEmpty ? roadName : null);
            }

            // Sub-road is depth >= 2 (use the leaf location)
            if (ancestors.length > 2) {
              final subRoadName = (ancestors.last['name'] as String? ?? '').trim();
              supabaseSubRoadId = remoteSubRoadsByName[subRoadName.toLowerCase()] ?? (subRoadName.isNotEmpty ? subRoadName : null);
            }
          }
        } else if (streetId.isNotEmpty) {
          // Legacy mapping fallback
          final streetRow = streetMap[streetId];
          final localAreaId = streetToArea[streetId] ?? '';
          final aRow = areaMap[localAreaId];
          final areaName = (aRow?['name'] as String? ?? '').trim();
          final roadName = (streetRow?['name'] as String? ?? '').trim();

          if (areaName.isNotEmpty) {
            supabaseAreaId = remoteAreasByName[areaName.toLowerCase()] ?? areaName;
          }
          if (roadName.isNotEmpty) {
            supabaseRoadId = remoteRoadsByName[roadName.toLowerCase()] ?? roadName;
          }
        }

        // Auto-compose readable address if blank
        String resolvedAddress = address.trim();
        if (resolvedAddress.isEmpty) {
          final houseNo = (cust['house_number'] as String? ?? '').trim();
          final parts = <String>[];
          if (houseNo.isNotEmpty) parts.add(houseNo);
          if (useLocationsTable && streetId.isNotEmpty) {
            final ancestors = getAncestors(streetId);
            for (final anc in ancestors.reversed) {
              final aName = (anc['name'] as String? ?? '').trim();
              if (aName.isNotEmpty && !parts.contains(aName)) parts.add(aName);
            }
          } else if (streetId.isNotEmpty) {
            final streetRow = streetMap[streetId];
            if (streetRow != null) {
              final sName = (streetRow['name'] as String? ?? '').trim();
              if (sName.isNotEmpty) parts.add(sName);
              final aId = streetRow['area_id'] as String? ?? '';
              final aRow = areaMap[aId];
              if (aRow != null) {
                final aName = (aRow['name'] as String? ?? '').trim();
                if (aName.isNotEmpty) parts.add(aName);
              }
            }
          }
          resolvedAddress = parts.join(', ');
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
              'p_address': resolvedAddress,
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
              'address': resolvedAddress,
              'customer_code': codeRaw,
            };
            if (supabaseAreaId != null) row['area_id'] = supabaseAreaId;
            if (supabaseRoadId != null) row['road_id'] = supabaseRoadId;
            if (supabaseSubRoadId != null) row['sub_road_id'] = supabaseSubRoadId;
            await client.from('customers').upsert(row, onConflict: 'id');
          }

          // Mark synced in local settings
          final syncNowMillis = DateTime.now().millisecondsSinceEpoch.toString();
          await db.insert(
            'settings',
            {'key': 'customer_sync_time:$rawId', 'value': syncNowMillis},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
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

  Future<String> _ensureValidStreetId(DatabaseExecutor db, String? streetIdCandidate, {String? areaOrStreetName}) async {
    final candidate = (streetIdCandidate ?? '').trim();
    if (candidate.isNotEmpty) {
      final sCheck = await db.query('streets', columns: ['id'], where: 'id = ?', whereArgs: [candidate]);
      if (sCheck.isNotEmpty) return candidate;
      final locCheck = await db.query('locations', columns: ['id'], where: 'id = ?', whereArgs: [candidate]);
      if (locCheck.isNotEmpty) return candidate;
    }

    // Try name matching if candidate was not a UUID (e.g. customer entered "Bangar Nagar" or "Shivaji Nagar")
    final name = (areaOrStreetName ?? '').trim();
    if (name.isNotEmpty) {
      final locMatch = await db.rawQuery('SELECT id FROM locations WHERE LOWER(name) = LOWER(?) LIMIT 1', [name]);
      if (locMatch.isNotEmpty) return locMatch.first['id'] as String;
      final streetMatch = await db.rawQuery('SELECT id FROM streets WHERE LOWER(name) = LOWER(?) LIMIT 1', [name]);
      if (streetMatch.isNotEmpty) return streetMatch.first['id'] as String;
      final areaMatch = await db.rawQuery('SELECT id FROM areas WHERE LOWER(name) = LOWER(?) LIMIT 1', [name]);
      if (areaMatch.isNotEmpty) return areaMatch.first['id'] as String;
    }

    // Ensure default_area and default_street exist for foreign key safety
    final defaultAreaCheck = await db.query('areas', where: 'id = ?', whereArgs: ['default_area']);
    if (defaultAreaCheck.isEmpty) {
      await db.insert('areas', {
        'id': 'default_area',
        'name': 'Online Area',
        'description': 'Default area for online customers',
        'color': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
    final defaultStreetCheck = await db.query('streets', where: 'id = ?', whereArgs: ['default_street']);
    if (defaultStreetCheck.isEmpty) {
      await db.insert('streets', {
        'id': 'default_street',
        'area_id': 'default_area',
        'name': 'Online Street',
        'description': 'Default street for online customers',
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    return 'default_street';
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

        // Skip any customer that was deleted locally
        try {
          final isDel = await db.query('deleted_customers',
              where: 'id = ?', whereArgs: [rawId], limit: 1);
          if (isDel.isNotEmpty) {
            unawaited(deleteCustomerRemotely(rawId));
            continue;
          }
        } catch (_) {}

        final phone = (rc['phone']?.toString() ?? '').trim();
        final name = (rc['name']?.toString() ?? '').trim();
        final address = (rc['address']?.toString() ?? '').trim();
        final codeRaw = (rc['customer_code']?.toString() ?? '').trim();
        final remoteStreetId = (rc['street_id']?.toString() ?? rc['location_id']?.toString() ?? rc['delivery_area_id']?.toString() ?? '').trim();
        final remoteHouseNo = (rc['house_number']?.toString() ?? rc['house_no']?.toString() ?? '').trim();
        final remoteLocality = (rc['locality']?.toString() ?? rc['area_name']?.toString() ?? rc['delivery_area']?.toString() ?? '').trim();
        final bool isGuest = (rc['is_guest'] == true || rc['is_guest'] == 1 || codeRaw.isEmpty);

        // Deduplicated check: query by ID, by code, by phone, or by name + house
        List<Map<String, dynamic>> existing = await db.query(
          'customers',
          where: 'id = ?',
          whereArgs: [rawId],
          limit: 1,
        );

        if (existing.isEmpty && codeRaw.isNotEmpty) {
          existing = await db.query(
            'customers',
            where: 'UPPER(TRIM(customer_code)) = ?',
            whereArgs: [codeRaw.toUpperCase()],
            limit: 1,
          );
        }

        final digitsPhone = phone.replaceAll(RegExp(r'\D'), '');
        final normPhone = digitsPhone.length >= 10
            ? digitsPhone.substring(digitsPhone.length - 10)
            : digitsPhone;

        if (existing.isEmpty && normPhone.isNotEmpty && normPhone != '0000000000') {
          existing = await db.query(
            'customers',
            where: 'phone1 = ? OR whatsapp = ?',
            whereArgs: [phone, phone],
            limit: 1,
          );
          if (existing.isEmpty && normPhone.length == 10) {
            existing = await db.rawQuery(
              'SELECT * FROM customers WHERE phone1 LIKE ? OR whatsapp LIKE ? LIMIT 1',
              ['%$normPhone', '%$normPhone'],
            );
          }
        }

        if (existing.isEmpty && name.isNotEmpty && remoteHouseNo.isNotEmpty) {
          existing = await db.rawQuery(
            'SELECT * FROM customers WHERE LOWER(TRIM(name)) = ? AND house_number = ? LIMIT 1',
            [name.toLowerCase(), remoteHouseNo],
          );
        }

        final validStreetId = await _ensureValidStreetId(
          db,
          remoteStreetId,
          areaOrStreetName: remoteLocality.isNotEmpty ? remoteLocality : (rc['delivery_area']?.toString() ?? ''),
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
              'house_number': remoteHouseNo,
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
              'locality': remoteLocality,
              'customer_code': codeRaw,
              'auth_provider': rc['auth_provider'] ?? 'phone_password',
              'google_id': rc['google_id']?.toString() ?? '',
              'is_new_customer': (rc['is_new_customer'] == true || rc['is_new_customer'] == 1) ? 1 : 0,
              'street_id': validStreetId,
              'location_id': validStreetId,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          // Update existing customer record and harmonize ID to rawId if different
          final existingId = existing.first['id'] as String;
          if (existingId != rawId) {
            await db.rawUpdate("UPDATE orders SET customer_id = ? WHERE customer_id = ?", [rawId, existingId]);
            await db.rawUpdate("UPDATE payments SET customer_id = ? WHERE customer_id = ?", [rawId, existingId]);
            await db.rawUpdate("UPDATE visits SET customer_id = ? WHERE customer_id = ?", [rawId, existingId]);
            await db.rawUpdate("UPDATE customers SET id = ? WHERE id = ?", [rawId, existingId]);
          }

          final targetId = (existingId != rawId) ? rawId : existingId;
          final existingLocalCode = (existing.first['customer_code'] as String? ?? '').trim();
          final existingLocalStreet = (existing.first['street_id'] as String? ?? '').trim();

          await db.update(
            'customers',
            {
              'is_guest': isGuest ? 1 : 0,
              if (existingLocalCode.isEmpty && codeRaw.isNotEmpty) 'customer_code': codeRaw,
              if ((existingLocalStreet.isEmpty || existingLocalStreet == 'default_street') && remoteStreetId.isNotEmpty) ...{
                'street_id': validStreetId,
                'location_id': validStreetId,
              },
              if (rc['auth_provider'] != null) 'auth_provider': rc['auth_provider'],
              if (rc['google_id'] != null) 'google_id': rc['google_id'],
              if (rc['is_new_customer'] != null) 'is_new_customer': (rc['is_new_customer'] == true || rc['is_new_customer'] == 1) ? 1 : 0,
              if (name.isNotEmpty) 'name': name,
              if (address.isNotEmpty) 'address': address,
              if (remoteHouseNo.isNotEmpty) 'house_number': remoteHouseNo,
              if (remoteLocality.isNotEmpty) 'locality': remoteLocality,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [targetId],
          );
        }
      }
    } catch (e) {
      debugPrint('SyncService: Error pulling remote customers/guests: $e');
    }
  }

  Future<bool> deleteCustomerRemotely(String customerId) async {
    try {
      await _ensureSupabaseAuth();
      final client = Supabase.instance.client;
      final cleanId = _getValidUuid(customerId);
      debugPrint('SyncService: Deleting customer remotely via delete_customer_secure ($cleanId)');
      final res = await client.rpc('delete_customer_secure', params: {
        'p_id': cleanId,
      }).timeout(const Duration(seconds: 10));
      debugPrint('SyncService: delete_customer_secure response: $res');
      return true;
    } catch (e) {
      debugPrint('SyncService: Remote customer deletion failed: $e. Queueing to pending_sync.');
      try {
        final db = await DatabaseHelper.instance.database;
        await db.insert('pending_sync', {
          'id': const Uuid().v4(),
          'entity_type': 'customer',
          'entity_id': customerId,
          'action_type': 'deleted',
          'payload_json': jsonEncode({'id': customerId}),
          'created_at': DateTime.now().toIso8601String(),
          'status': 'pending',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
      return false;
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

      String resolvedAddress = customer.address.trim();
      String? supabaseAreaId;
      String? supabaseRoadId;
      String? supabaseSubRoadId;

      final db = await DatabaseHelper.instance.database;

      if (customer.streetId.isNotEmpty) {
        try {
          final list = <Map<String, dynamic>>[];
          String? currentId = customer.streetId;
          int maxDepth = 10;
          while (currentId != null && maxDepth-- > 0) {
            final rows = await db.query('locations',
                columns: ['id', 'parent_location_id', 'name', 'location_kind'],
                where: 'id = ?',
                whereArgs: [currentId],
                limit: 1);
            if (rows.isEmpty) break;
            list.insert(0, rows.first);
            currentId = rows.first['parent_location_id'] as String?;
          }

          String areaName = '';
          String roadName = '';
          String subRoadName = '';

          if (list.isNotEmpty) {
            areaName = (list[0]['name'] as String? ?? '').trim();
            if (list.length > 1) {
              roadName = (list[1]['name'] as String? ?? '').trim();
            }
            if (list.length > 2) {
              subRoadName = (list.last['name'] as String? ?? '').trim();
            }
          } else {
            final streetRows = await db.query('streets',
                where: 'id = ?', whereArgs: [customer.streetId], limit: 1);
            if (streetRows.isNotEmpty) {
              roadName = (streetRows.first['name'] as String? ?? '').trim();
              final aId = streetRows.first['area_id'] as String? ?? '';
              if (aId.isNotEmpty) {
                final areaRows = await db.query('areas',
                    where: 'id = ?', whereArgs: [aId], limit: 1);
                if (areaRows.isNotEmpty) {
                  areaName = (areaRows.first['name'] as String? ?? '').trim();
                }
              }
            }
          }

          if (areaName.isNotEmpty) {
            try {
              final aRes = await client
                  .from('areas')
                  .select('id')
                  .ilike('name', areaName)
                  .limit(1)
                  .maybeSingle();
              if (aRes != null && aRes['id'] != null) {
                supabaseAreaId = aRes['id'].toString();
              }
            } catch (_) {}
            if (supabaseAreaId == null || supabaseAreaId.isEmpty) {
              supabaseAreaId = areaName;
            }
          }

          if (roadName.isNotEmpty) {
            try {
              var rQuery = client
                  .from('roads')
                  .select('id')
                  .ilike('name', roadName);
              if (supabaseAreaId != null && !supabaseAreaId.contains(' ')) {
                rQuery = rQuery.eq('area_id', supabaseAreaId);
              }
              final rRes = await rQuery.limit(1).maybeSingle();
              if (rRes != null && rRes['id'] != null) {
                supabaseRoadId = rRes['id'].toString();
              }
            } catch (_) {}
            if (supabaseRoadId == null || supabaseRoadId.isEmpty) {
              supabaseRoadId = roadName;
            }
          }

          if (subRoadName.isNotEmpty) {
            try {
              var srQuery = client
                  .from('sub_roads')
                  .select('id')
                  .ilike('name', subRoadName);
              if (supabaseRoadId != null && !supabaseRoadId.contains(' ')) {
                srQuery = srQuery.eq('road_id', supabaseRoadId);
              }
              final srRes = await srQuery.limit(1).maybeSingle();
              if (srRes != null && srRes['id'] != null) {
                supabaseSubRoadId = srRes['id'].toString();
              }
            } catch (_) {}
            if (supabaseSubRoadId == null || supabaseSubRoadId.isEmpty) {
              supabaseSubRoadId = subRoadName;
            }
          }
        } catch (_) {}
      }

      if (resolvedAddress.isEmpty) {
        final parts = <String>[];
        if (customer.houseNumber.trim().isNotEmpty) parts.add(customer.houseNumber.trim());
        if (customer.streetId.isNotEmpty) {
          try {
            final locs = await db.query('locations', where: 'id = ?', whereArgs: [customer.streetId]);
            if (locs.isNotEmpty) {
              final lName = (locs.first['name'] as String? ?? '').trim();
              if (lName.isNotEmpty) parts.add(lName);
            } else {
              final sts = await db.query('streets', where: 'id = ?', whereArgs: [customer.streetId]);
              if (sts.isNotEmpty) {
                final sName = (sts.first['name'] as String? ?? '').trim();
                if (sName.isNotEmpty) parts.add(sName);
              }
            }
          } catch (_) {}
        }
        if (customer.locality.trim().isNotEmpty && !parts.contains(customer.locality.trim())) {
          parts.add(customer.locality.trim());
        }
        resolvedAddress = parts.join(', ');
      }

      try {
        await client.rpc('sync_customer_with_code', params: {
          'p_id': cleanId,
          'p_name': name,
          'p_phone': phone,
          'p_email': '',
          'p_address': resolvedAddress,
          'p_customer_code': customer.customerCode.trim().toUpperCase(),
          'p_area_id': supabaseAreaId,
          'p_road_id': supabaseRoadId,
          'p_sub_road_id': supabaseSubRoadId,
        }).timeout(const Duration(seconds: 8));
        debugPrint('SyncService: Single customer $name synced to Supabase via RPC (area: $supabaseAreaId, road: $supabaseRoadId).');
      } catch (rpcErr) {
        debugPrint('SyncService: Single customer RPC failed: $rpcErr. Falling back to direct upsert.');
        final row = <String, dynamic>{
          'id': cleanId,
          'name': name,
          'phone': phone,
          'address': resolvedAddress,
          if (customer.customerCode.trim().isNotEmpty)
            'customer_code': customer.customerCode.trim().toUpperCase(),
          if (supabaseAreaId != null && supabaseAreaId.isNotEmpty)
            'area_id': supabaseAreaId,
          if (supabaseRoadId != null && supabaseRoadId.isNotEmpty)
            'road_id': supabaseRoadId,
          if (supabaseSubRoadId != null && supabaseSubRoadId.isNotEmpty)
            'sub_road_id': supabaseSubRoadId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        await client.from('customers').upsert(row, onConflict: 'id');
        debugPrint('SyncService: Single customer $name synced to Supabase via direct upsert.');
      }
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

      // 0. Pre-fetch existing remote areas, roads, and sub-roads to preserve existing Supabase IDs
      // and prevent unique constraint violations on (name) and (area_id, name).
      final Map<String, Map<String, dynamic>> remoteAreasByName = {};
      List<dynamic> existingAreas = [];
      try {
        existingAreas = await client.from('areas').select('id, name, area_code');
        for (final ea in existingAreas) {
          final aName = (ea['name'] as String? ?? '').trim().toLowerCase();
          if (aName.isNotEmpty) {
            remoteAreasByName[aName] = Map<String, dynamic>.from(ea as Map);
          }
        }
      } catch (e) {
        debugPrint('[SYNC] Failed to fetch remote areas: $e');
      }

      final Map<String, Map<String, dynamic>> remoteRoadsByAreaAndName = {};
      List<dynamic> existingRoads = [];
      try {
        existingRoads = await client.from('roads').select('id, name, area_id, road_code');
        for (final er in existingRoads) {
          final rName = (er['name'] as String? ?? '').trim().toLowerCase();
          final aId = (er['area_id'] as String? ?? '').trim();
          if (rName.isNotEmpty && aId.isNotEmpty) {
            remoteRoadsByAreaAndName['${aId}_$rName'] = Map<String, dynamic>.from(er as Map);
          }
        }
      } catch (e) {
        debugPrint('[SYNC] Failed to fetch remote roads: $e');
      }

      final Map<String, Map<String, dynamic>> remoteSubRoadsByRoadAndName = {};
      List<dynamic> existingSubRoads = [];
      try {
        existingSubRoads = await client.from('sub_roads').select('id, name, road_id, subroad_code');
        for (final esr in existingSubRoads) {
          final srName = (esr['name'] as String? ?? '').trim().toLowerCase();
          final rId = (esr['road_id'] as String? ?? '').trim();
          if (srName.isNotEmpty && rId.isNotEmpty) {
            remoteSubRoadsByRoadAndName['${rId}_$srName'] = Map<String, dynamic>.from(esr as Map);
          }
        }
      } catch (e) {
        debugPrint('[SYNC] Failed to fetch remote sub-roads: $e');
      }

      // Populate / harmonize local SQLite locations with any remote areas and roads from Supabase
      try {
        final nowIso = DateTime.now().toIso8601String();
        for (final ea in existingAreas) {
          final areaId = ea['id'] as String;
          final areaName = (ea['name'] as String? ?? '').trim();
          if (areaName.isEmpty) continue;

          // Match by ID OR by name
          final existingLoc = await db.query(
            'locations',
            where: "id = ? OR (location_kind = 'area' AND LOWER(TRIM(name)) = ?)",
            whereArgs: [areaId, areaName.toLowerCase()],
            limit: 1,
          );

          if (existingLoc.isNotEmpty) {
            final oldId = existingLoc.first['id'] as String;
            if (oldId != areaId) {
              await db.rawUpdate("UPDATE locations SET id = ?, name = ? WHERE id = ?", [areaId, areaName, oldId]);
              await db.rawUpdate("UPDATE areas SET id = ?, name = ? WHERE id = ?", [areaId, areaName, oldId]);
              await db.rawUpdate("UPDATE locations SET parent_location_id = ? WHERE parent_location_id = ?", [areaId, oldId]);
              await db.rawUpdate("UPDATE locations SET materialized_path = REPLACE(materialized_path, ?, ?) WHERE materialized_path LIKE ?", ['/$oldId/', '/$areaId/', '%/$oldId/%']);
              await db.rawUpdate("UPDATE streets SET area_id = ? WHERE area_id = ?", [areaId, oldId]);
              await db.rawUpdate("UPDATE customers SET street_id = ? WHERE street_id = ?", [areaId, oldId]);
              await db.rawUpdate("UPDATE customers SET location_id = ? WHERE location_id = ?", [areaId, oldId]);
            } else {
              await db.update('locations', {'name': areaName, 'updated_at': nowIso}, where: 'id = ?', whereArgs: [areaId]);
              try {
                await db.update('areas', {'name': areaName, 'updated_at': nowIso}, where: 'id = ?', whereArgs: [areaId]);
              } catch (_) {}
            }
          } else {
            await db.insert('locations', {
              'id': areaId,
              'name': areaName,
              'location_kind': 'area',
              'sequence_key': '001',
              'depth': 0,
              'materialized_path': '/$areaId/',
              'is_archived': 0,
              'created_at': nowIso,
              'updated_at': nowIso,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            try {
              await db.insert('areas', {
                'id': areaId,
                'name': areaName,
                'created_at': nowIso,
                'updated_at': nowIso,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            } catch (_) {}
            try {
              await db.insert('streets', {
                'id': areaId,
                'area_id': areaId,
                'name': areaName,
                'created_at': nowIso,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            } catch (_) {}
          }
        }

        for (final er in existingRoads) {
          final roadId = er['id'] as String;
          final roadName = (er['name'] as String? ?? '').trim();
          final areaId = (er['area_id'] as String? ?? '').trim();
          if (roadName.isEmpty || areaId.isEmpty) continue;

          final existingLoc = await db.query(
            'locations',
            where: "id = ? OR (parent_location_id = ? AND LOWER(TRIM(name)) = ?)",
            whereArgs: [roadId, areaId, roadName.toLowerCase()],
            limit: 1,
          );

          if (existingLoc.isNotEmpty) {
            final oldId = existingLoc.first['id'] as String;
            if (oldId != roadId) {
              await db.rawUpdate("UPDATE locations SET id = ?, parent_location_id = ?, name = ? WHERE id = ?", [roadId, areaId, roadName, oldId]);
              await db.rawUpdate("UPDATE streets SET id = ?, area_id = ?, name = ? WHERE id = ?", [roadId, areaId, roadName, oldId]);
              await db.rawUpdate("UPDATE locations SET parent_location_id = ? WHERE parent_location_id = ?", [roadId, oldId]);
              await db.rawUpdate("UPDATE locations SET materialized_path = REPLACE(materialized_path, ?, ?) WHERE materialized_path LIKE ?", ['/$oldId/', '/$roadId/', '%/$oldId/%']);
              await db.rawUpdate("UPDATE customers SET street_id = ? WHERE street_id = ?", [roadId, oldId]);
              await db.rawUpdate("UPDATE customers SET location_id = ? WHERE location_id = ?", [roadId, oldId]);
            } else {
              await db.update('locations', {'name': roadName, 'parent_location_id': areaId, 'updated_at': nowIso}, where: 'id = ?', whereArgs: [roadId]);
              try {
                await db.update('streets', {'name': roadName, 'area_id': areaId}, where: 'id = ?', whereArgs: [roadId]);
              } catch (_) {}
            }
          } else {
            await db.insert('locations', {
              'id': roadId,
              'parent_location_id': areaId,
              'name': roadName,
              'location_kind': 'road',
              'sequence_key': '001',
              'depth': 1,
              'materialized_path': '/$areaId/$roadId/',
              'is_archived': 0,
              'created_at': nowIso,
              'updated_at': nowIso,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            try {
              await db.insert('streets', {
                'id': roadId,
                'area_id': areaId,
                'name': roadName,
                'created_at': nowIso,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('[SYNC] Error caching remote areas/roads to local SQLite: $e');
      }

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
        final rootLocations = localLocations.where((loc) => loc['parent_location_id'] == null || loc['depth'] == 0 || loc['location_kind'] == 'area').toList();
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

          final existingRemote = remoteAreasByName[name.toLowerCase()];
          final supabaseId = existingRemote?['id'] as String? ??
              (Uuid.isValidUUID(fromString: localId) ? localId : const Uuid().v4());
          final areaCode = existingRemote?['area_code'] as String? ??
              'AREA-${supabaseId.replaceAll('-', '').substring(0, 8).toUpperCase()}';

          List<dynamic> sched = [];
          if (loc['delivery_schedule'] != null) {
            try {
              final decoded = json.decode(loc['delivery_schedule'] as String);
              if (decoded is List) {
                sched = decoded;
              }
            } catch (_) {}
          }
          final cutoffTime = loc['cutoff_time'] as String? ?? '23:59:00';
          final isActive = (loc['is_active'] == null || loc['is_active'] == 1 || loc['is_active'] == true || loc['is_active'].toString() == 'true');

          try {
            await client.from('areas').upsert({
              'id': supabaseId,
              'area_code': areaCode,
              'name': name,
              'delivery_schedule': sched,
              'cutoff_time': cutoffTime,
              'is_active_override': isActive,
            }, onConflict: 'name');
            remoteAreasByName[name.toLowerCase()] = {
              'id': supabaseId,
              'name': name,
              'area_code': areaCode,
            };
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

          final parentAreaLoc = locationMap[localAreaId];
          final parentAreaName = (parentAreaLoc?['name'] as String? ?? '').trim().toLowerCase();
          final existingRemoteArea = remoteAreasByName[parentAreaName];
          final supabaseAreaId = existingRemoteArea?['id'] as String? ??
              const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.area.$localAreaId');

          final existingRemoteRoad = remoteRoadsByAreaAndName['${supabaseAreaId}_${name.toLowerCase()}'];
          final supabaseId = existingRemoteRoad?['id'] as String? ??
              const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.road.$localId');
          final roadCode = existingRemoteRoad?['road_code'] as String? ??
              'ROAD-${supabaseId.substring(0, 8).toUpperCase()}';

          try {
            await client.from('roads').upsert({
              'id': supabaseId,
              'road_code': roadCode,
              'area_id': supabaseAreaId,
              'name': name,
            }, onConflict: 'id');
            remoteRoadsByAreaAndName['${supabaseAreaId}_${name.toLowerCase()}'] = {
              'id': supabaseId,
              'name': name,
              'area_id': supabaseAreaId,
              'road_code': roadCode,
            };
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

          final areaLocalId = ancestors[0]['id'] as String;
          final roadLocalId = ancestors[1]['id'] as String;
          final areaName = (ancestors[0]['name'] as String? ?? '').trim().toLowerCase();
          final roadName = (ancestors[1]['name'] as String? ?? '').trim().toLowerCase();

          final existingRemoteArea = remoteAreasByName[areaName];
          final supabaseAreaId = existingRemoteArea?['id'] as String? ??
              const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.area.$areaLocalId');

          final existingRemoteRoad = remoteRoadsByAreaAndName['${supabaseAreaId}_$roadName'];
          final supabaseRoadId = existingRemoteRoad?['id'] as String? ??
              const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.road.$roadLocalId');

          final existingRemoteSubRoad = remoteSubRoadsByRoadAndName['${supabaseRoadId}_${name.toLowerCase()}'];
          final supabaseId = existingRemoteSubRoad?['id'] as String? ??
              const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.subroad.$localId');
          final subroadCode = existingRemoteSubRoad?['subroad_code'] as String? ??
              'SUBROAD-${supabaseId.substring(0, 8).toUpperCase()}';

          try {
            await client.from('sub_roads').upsert({
              'id': supabaseId,
              'subroad_code': subroadCode,
              'road_id': supabaseRoadId,
              'name': name,
            }, onConflict: 'id');
            remoteSubRoadsByRoadAndName['${supabaseRoadId}_${name.toLowerCase()}'] = {
              'id': supabaseId,
              'name': name,
              'road_id': supabaseRoadId,
              'subroad_code': subroadCode,
            };
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

          final existingRemote = remoteAreasByName[name.toLowerCase()];
          final supabaseId = existingRemote?['id'] as String? ??
              const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.area.$localId');
          final areaCode = existingRemote?['area_code'] as String? ??
              'AREA-${supabaseId.substring(0, 8).toUpperCase()}';

          List<dynamic> sched = [];
          if (area['delivery_schedule'] != null) {
            try {
              final decoded = json.decode(area['delivery_schedule'] as String);
              if (decoded is List) {
                sched = decoded;
              }
            } catch (_) {}
          }
          final cutoffTime = area['cutoff_time'] as String? ?? '23:59:00';
          final isActive = (area['is_active'] == null || area['is_active'] == 1 || area['is_active'] == true || area['is_active'].toString() == 'true');

          try {
            await client.from('areas').upsert({
              'id': supabaseId,
              'area_code': areaCode,
              'name': name,
              'delivery_schedule': sched,
              'cutoff_time': cutoffTime,
              'is_active_override': isActive,
            }, onConflict: 'id');
            remoteAreasByName[name.toLowerCase()] = {
              'id': supabaseId,
              'name': name,
              'area_code': areaCode,
            };
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

        // Build local area id to name map
        final Map<String, String> localAreaNames = {
          for (final a in localAreas) a['id'] as String: (a['name'] as String? ?? '').trim().toLowerCase()
        };

        for (final street in localStreets) {
          final localId = street['id'] as String;
          final localAreaId = street['area_id'] as String? ?? '';
          final name = (street['name'] as String? ?? '').trim();
          if (name.isEmpty || localAreaId.isEmpty) continue;

          final areaName = localAreaNames[localAreaId] ?? '';
          final existingRemoteArea = remoteAreasByName[areaName];
          final supabaseAreaId = existingRemoteArea?['id'] as String? ??
              const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.area.$localAreaId');

          final existingRemoteRoad = remoteRoadsByAreaAndName['${supabaseAreaId}_${name.toLowerCase()}'];
          final supabaseId = existingRemoteRoad?['id'] as String? ??
              const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.road.$localId');
          final roadCode = existingRemoteRoad?['road_code'] as String? ??
              'ROAD-${supabaseId.substring(0, 8).toUpperCase()}';

          try {
            await client.from('roads').upsert({
              'id': supabaseId,
              'road_code': roadCode,
              'area_id': supabaseAreaId,
              'name': name,
            }, onConflict: 'id');
            remoteRoadsByAreaAndName['${supabaseAreaId}_${name.toLowerCase()}'] = {
              'id': supabaseId,
              'name': name,
              'area_id': supabaseAreaId,
              'road_code': roadCode,
            };
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
            ? false
            : (item['order_now_is_available'] == 1 ||
                item['order_now_is_available'] == true ||
                item['order_now_is_available']?.toString() == '1' ||
                item['order_now_is_available']?.toString().toLowerCase() == 'true');
        final bool isAvailable = item['is_available'] == null
            ? true
            : (item['is_available'] == 1 || item['is_available'] == true || item['is_available']?.toString() == '1' || item['is_available']?.toString().toLowerCase() == 'true');

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
                'is_available': isAvailable,
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
                'is_available': isAvailable,
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
              'is_available': isAvailable,
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
  // SYNC ALL — Orchestrates full server sync (orders → customers → inventory → routes)
  // =====================================================
  Future<Map<String, dynamic>> syncAll({bool forceSync = false}) async {
    debugPrint('[SYNC] === Starting Full Server Sync (forceSync=$forceSync) ===');
    await _ensureSupabaseAuth();

    try {
      await pushModifiedOrders();
    } catch (e) {
      debugPrint('[SYNC] pushModifiedOrders error: $e');
    }

    try {
      await syncOrders();
      debugPrint('[SYNC] Orders done.');
    } catch (e) {
      debugPrint('[SYNC] syncOrders error: $e');
    }

    try {
      await pullRemoteCustomersAndGuests();
      await pullLoginLogs();
      debugPrint('[SYNC] Remote customers & login logs done.');
    } catch (e) {
      debugPrint('[SYNC] pullRemoteCustomers error: $e');
    }

    final routeStats = await syncAreasAndRoads();
    debugPrint('[SYNC] Areas/Roads done.');

    final customerStats = await syncAllExistingCustomers(forceSync: forceSync);
    debugPrint('[SYNC] Customers done.');

    final inventoryStats = await syncInventory();
    debugPrint('[SYNC] Inventory done.');

    notifyOrderChanged();
    debugPrint('[SYNC] === Full Server Sync Complete ===');

    return {
      ...routeStats,
      ...customerStats,
      ...inventoryStats,
    };
  }


  Future<void> syncOrders() async {
    if (_isSyncingOrders) {
      _pendingSyncOrdersRequested = true;
      return;
    }
    _isSyncingOrders = true;
    try {
      do {
        _pendingSyncOrdersRequested = false;
        await _performSyncOrders();
      } while (_pendingSyncOrdersRequested);
    } finally {
      _isSyncingOrders = false;
    }
  }

  Future<void> _performSyncOrders() async {
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

      // Build a map of UUID to local SQLite item ID once outside the loop for high performance
      final List<Map<String, dynamic>> dbItems = await db.query('items', columns: ['id']);
      final Map<String, String> uuidToLocalId = {};
      for (final row in dbItems) {
        final String rawId = row['id'] as String? ?? '';
        if (rawId.isNotEmpty) {
          final String uuid = _getValidUuid(rawId);
          uuidToLocalId[uuid] = rawId;
        }
      }

      for (var ord in orders) {
        try {
          final String orderId = ord['id'];

          // 1. Fetch order items from Supabase OUTSIDE the SQLite transaction to avoid DB locks
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

          // 2. NOW execute instantaneous SQLite transaction (<1ms)
          final Set<String> restoredItemIds = {};
          await db.transaction((txn) async {
            final String? ordNo = ord['order_number']?.toString();
            final deletedCheck = await txn.query(
              'deleted_orders',
              columns: ['id'],
              where: 'id = ? OR id = ?',
              whereArgs: [orderId, ordNo ?? ''],
            );
            if (deletedCheck.isNotEmpty) {
              return;
            }
            final localCheck = await txn.query(
              'orders',
              columns: ['id', 'sync_status'],
              where: 'id = ? OR (order_number IS NOT NULL AND order_number != "" AND order_number = ?)',
              whereArgs: [orderId, ordNo ?? ''],
            );
            if (localCheck.isNotEmpty && (localCheck.first['sync_status'] == 'pending_update' || localCheck.first['sync_status'] == 'syncing')) {
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

            // B. Check if order already exists in POS SQLite DB (match by ID or order_number)
            final orderCheck = await txn.query(
              'orders',
              where: 'id = ? OR (order_number IS NOT NULL AND order_number != "" AND order_number = ?)',
              whereArgs: [orderId, ordNo ?? ''],
            );
            final String serverStatus = ord['status'] ?? 'Confirmed';
            final double grandTotal = (ord['total_amount'] as num?)?.toDouble() ?? 0.0;

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
                final rawIsAvail = item['is_available'];
                final bool isItemAvailable = rawIsAvail != null
                    ? (rawIsAvail == 1 || rawIsAvail == true || rawIsAvail.toString() == '1' || rawIsAvail.toString().toLowerCase() == 'true')
                    : (subtotal > 0.001 || unitPrice <= 0.001);

                await txn.insert('order_items', {
                  'id': const Uuid().v4(),
                  'order_id': orderId,
                  'item_id': localItemId,
                  'item_name': itemName,
                  'item_unit': item['unit'] ?? 'kg',
                  'quantity': qty,
                  'unit_price': unitPrice,
                  'total_price': isItemAvailable ? subtotal : 0.0,
                  'is_available': isItemAvailable ? 1 : 0,
                });

                // Deduct stock in SQLite items table & record stock history (only for active, available items in non-cancelled/non-denied orders)
                if (localItemId.isNotEmpty &&
                    isItemAvailable &&
                    subtotal > 0.001 &&
                    serverStatus.toLowerCase() != 'cancelled' &&
                    serverStatus.toLowerCase() != 'denied') {
                  final itemCheck = await txn.query('items', columns: ['id', 'unit'], where: 'id = ?', whereArgs: [localItemId]);
                  if (itemCheck.isNotEmpty) {
                    final itemUnit = itemCheck.first['unit'] as String? ?? 'kg';
                    final orderUnit = item['unit'] as String? ?? itemUnit;
                    final double baseQty = UnitConverter.convert(quantity: qty, fromUnit: orderUnit, toUnit: itemUnit);

                    final String ordType = (ord['order_type'] ?? 'Normal').toString();
                    final bool isQuick = ordType.toLowerCase() == 'order now' || ordType.toLowerCase() == 'quick';

                    if (isQuick) {
                      await txn.rawUpdate(
                        'UPDATE items SET order_now_stock = MAX(0.0, order_now_stock - ?), updated_at = ? WHERE id = ?',
                        [baseQty, nowStr, localItemId],
                      );
                    } else {
                      await txn.rawUpdate(
                        'UPDATE items SET stock = MAX(0.0, stock - ?), updated_at = ? WHERE id = ?',
                        [baseQty, nowStr, localItemId],
                      );
                    }
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
                const notifTitle = 'New Online Order Received!';
                final notifBody = 'Order #${ord['order_number'] ?? orderId} from $customerName ($customerPhone) for ₹${grandTotal.toStringAsFixed(2)}';

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
              // C. Order exists locally - reconcile ID if legacy/local format
              final existingOrder = orderCheck.first;
              final String existingLocalId = existingOrder['id'] as String;
              if (existingLocalId != orderId) {
                await txn.execute('PRAGMA defer_foreign_keys = ON;');
                await txn.update('orders', {'id': orderId}, where: 'id = ?', whereArgs: [existingLocalId]);
                await txn.update('order_items', {'order_id': orderId}, where: 'order_id = ?', whereArgs: [existingLocalId]);
                await txn.update('payments', {'order_id': orderId}, where: 'order_id = ?', whereArgs: [existingLocalId]);
              }

              final currentSyncStatus = existingOrder['sync_status'] as String? ?? 'synced';
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

                        final String ordType = (remoteOrderType ?? orderCheck.first['order_type'] ?? 'Normal').toString();
                        final bool isQuick = ordType.toLowerCase() == 'order now' || ordType.toLowerCase() == 'quick';

                        if (isQuick) {
                          await txn.rawUpdate(
                            'UPDATE items SET order_now_stock = order_now_stock + ?, updated_at = ? WHERE id = ?',
                            [baseQty, DateTime.now().toIso8601String(), itemId],
                          );
                        } else {
                          await txn.rawUpdate(
                            'UPDATE items SET stock = stock + ?, updated_at = ? WHERE id = ?',
                            [baseQty, DateTime.now().toIso8601String(), itemId],
                          );
                        }
                        restoredItemIds.add(itemId);
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
                  final rawIsAvail = item['is_available'];
                  final bool isItemAvailable = rawIsAvail != null
                      ? (rawIsAvail == 1 || rawIsAvail == true || rawIsAvail.toString() == '1' || rawIsAvail.toString().toLowerCase() == 'true')
                      : (subtotal > 0.001 || unitPrice <= 0.001);

                  await txn.insert('order_items', {
                    'id': const Uuid().v4(),
                    'order_id': orderId,
                    'item_id': localItemId,
                    'item_name': itemName,
                    'item_unit': item['unit'] ?? 'kg',
                    'quantity': qty,
                    'unit_price': unitPrice,
                    'total_price': isItemAvailable ? subtotal : 0.0,
                    'is_available': isItemAvailable ? 1 : 0,
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

          // Push restored stock to Supabase in background
          if (restoredItemIds.isNotEmpty) {
            unawaited(() async {
              try {
                for (final rItemId in restoredItemIds) {
                  final itemRows = await db.query('items', where: 'id = ?', whereArgs: [rItemId]);
                  if (itemRows.isNotEmpty) {
                    final item = itemRows.first;
                    final stock = (item['stock'] as num?)?.toDouble() ?? 0.0;
                    final orderNowStock = (item['order_now_stock'] as num?)?.toDouble() ?? 0.0;
                    await client.from('products').update({
                      'stock': stock,
                      'order_now_stock': orderNowStock,
                      'updated_at': DateTime.now().toIso8601String(),
                    }).eq('id', rItemId);
                    debugPrint('[ORDER-SYNC] Pushed restored stock for item $rItemId to Supabase');
                  }
                }
              } catch (e) {
                debugPrint('[ORDER-SYNC] Failed to push restored stock to Supabase: $e');
              }
            }());
          }
        } catch (e) {
          debugPrint('CustomerOrderSyncService order $ord error: $e');
        }
      }

      // Notify all reactive UI providers that local SQLite orders were updated
      notifyOrderChanged();
    } catch (e) {
      debugPrint('CustomerOrderSyncService sync error: $e');
    }
  }

  Future<void> pushModifiedOrders() async {
    try {
      await _ensureSupabaseAuth();
      final client = Supabase.instance.client;
      final db = await DatabaseHelper.instance.database;

      // Recover any orphaned 'syncing' orders from previous app crashes/kills
      await db.update(
        'orders',
        {'sync_status': 'pending_update'},
        where: "sync_status = 'syncing'",
      );

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
          final String remoteOrderId = _getValidUuid(orderId);

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
              .eq('id', remoteOrderId)
              .maybeSingle();

          String canonicalOrderNo = localOrderNo ?? '';

          if (existingRemote == null) {
            // Find customer details in local DB to populate remote order fields
            final custRows = await db.query('customers', where: 'id = ?', whereArgs: [ord['customer_id']]);
            final String custPhone = custRows.isNotEmpty ? (custRows.first['phone1'] as String? ?? '') : '';
            final String custAddress = custRows.isNotEmpty ? (custRows.first['address'] as String? ?? '') : '';
            final String custName = custRows.isNotEmpty ? (custRows.first['name'] as String? ?? '') : '';

            String resolvedCustAddress = custAddress.trim();
            if (resolvedCustAddress.isEmpty && custRows.isNotEmpty) {
              final hNo = (custRows.first['house_number'] as String? ?? '').trim();
              final sId = (custRows.first['street_id'] as String? ?? '').trim();
              final parts = <String>[];
              if (hNo.isNotEmpty) parts.add(hNo);
              if (sId.isNotEmpty) {
                try {
                  final locRows = await db.query('locations', where: 'id = ?', whereArgs: [sId]);
                  if (locRows.isNotEmpty) {
                    final lName = (locRows.first['name'] as String? ?? '').trim();
                    if (lName.isNotEmpty) parts.add(lName);
                  } else {
                    final strRows = await db.query('streets', where: 'id = ?', whereArgs: [sId]);
                    if (strRows.isNotEmpty) {
                      final strName = (strRows.first['name'] as String? ?? '').trim();
                      if (strName.isNotEmpty) parts.add(strName);
                    }
                  }
                } catch (_) {}
              }
              resolvedCustAddress = parts.join(', ');
            }

            final insertPayload = <String, dynamic>{
              'id': remoteOrderId,
              'customer_id': _getValidUuid(ord['customer_id'] as String? ?? ''),
              'customer_phone': custPhone,
              'customer_name': custName,
              'delivery_address': resolvedCustAddress,
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
                .eq('id', remoteOrderId)
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
          await client.from('order_items').delete().eq('order_id', remoteOrderId);

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
              final rawIsAvail = item['is_available'];
              final bool isAvail = rawIsAvail != null
                  ? (rawIsAvail == 1 || rawIsAvail == true || rawIsAvail.toString() == '1' || rawIsAvail.toString().toLowerCase() == 'true')
                  : (totalPrice > 0.001);

              return {
                'id': const Uuid().v4(),
                'order_id': remoteOrderId,
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
                'is_available': isAvail,
              };
            }).toList();

            await client.from('order_items').insert(itemsToInsert);
          }

          // 5. Mark local order as synced & cascade remoteOrderId to SQLite if it differed
          await db.transaction((txn) async {
            if (orderId != remoteOrderId) {
              await txn.execute('PRAGMA defer_foreign_keys = ON;');
              await txn.update('orders', {'id': remoteOrderId}, where: 'id = ?', whereArgs: [orderId]);
              await txn.update('order_items', {'order_id': remoteOrderId}, where: 'order_id = ?', whereArgs: [orderId]);
              await txn.update('payments', {'order_id': remoteOrderId}, where: 'order_id = ?', whereArgs: [orderId]);
            }
            await txn.update(
              'orders',
              {
                'sync_status': 'synced',
                if (canonicalOrderNo.isNotEmpty) 'order_number': canonicalOrderNo,
              },
              where: 'id = ?',
              whereArgs: [remoteOrderId],
            );
          });

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
