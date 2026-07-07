import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../constants/app_constants.dart';
import 'package_validator.dart';

class HotspotSyncService {
  HotspotSyncService._();

  static HttpServer? _server;
  static StreamSubscription<List<ConnectivityResult>>? _connectionSubscription;
  static bool _isSyncing = false;

  static bool get isServerRunning => _server != null;

  // ---------------------------------------------------------------------------
  // 1. DISCOVERY & SUBNET SCANNING
  // ---------------------------------------------------------------------------

  /// Helper to check if a specific IP responds to handshake on port 8292
  static Future<bool> _pingDevice(String ip) async {
    final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);
    try {
      final req = await client.getUrl(Uri.parse('http://$ip:8292/handshake'));
      final resp = await req.close();
      if (resp.statusCode == HttpStatus.ok) {
        final body = await utf8.decoder.bind(resp).join();
        final res = jsonDecode(body);
        return res['app'] == 'orderkart';
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Scan subnet to automatically find the other device running the receiver
  static Future<String?> discoverReceiverDevice() async {
    final info = NetworkInfo();
    final localIp = await info.getWifiIP();
    if (localIp == null || localIp.isEmpty) return null;

    final parts = localIp.split('.');
    if (parts.length != 4) return null;

    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
    final gateway = await info.getWifiGatewayIP();

    // 1. Try default gateway first (covers hotspot host configuration)
    if (gateway != null && gateway.isNotEmpty) {
      if (await _pingDevice(gateway)) return gateway;
    }

    // 2. Fallback to scanning all client IPs concurrently on subnet (covers third-phone hotspot configuration)
    final List<Future<String?>> pingFutures = [];
    final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 400);

    for (int i = 1; i <= 254; i++) {
      final targetIp = '$subnet.$i';
      if (targetIp == localIp || targetIp == gateway) continue;

      pingFutures.add(
        client.getUrl(Uri.parse('http://$targetIp:8292/handshake'))
          .then((req) => req.close())
          .then((resp) async {
            if (resp.statusCode == HttpStatus.ok) {
              final body = await utf8.decoder.bind(resp).join();
              final res = jsonDecode(body);
              if (res['app'] == 'orderkart') {
                return targetIp;
              }
            }
            return null;
          })
          .catchError((_) => null)
      );
    }

    try {
      final results = await Future.wait(pingFutures);
      for (final result in results) {
        if (result != null) return result;
      }
    } catch (_) {} finally {
      client.close();
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // 2. OWNER/WORKER SERVER OPERATIONS
  // ---------------------------------------------------------------------------

  /// Start local HTTP server on Owner/Worker device
  static Future<void> startServer({
    required Function(String status) onStatusUpdate,
    required VoidCallback onSyncSuccess,
  }) async {
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8292);
      onStatusUpdate('Server listening. Waiting for other device to sync...');

      _server!.listen((HttpRequest request) async {
        final path = request.uri.path;
        final method = request.method;

        if (method == 'GET' && path == '/handshake') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'app': 'orderkart',
              'timestamp': DateTime.now().toIso8601String(),
            }));
          await request.response.close();
        } else if (method == 'POST' && path == '/sync') {
          try {
            final body = await utf8.decoder.bind(request).join();
            final Map<String, dynamic> payload = jsonDecode(body);

            final String base64Data = payload['data']?.toString() ?? '';
            if (base64Data.isEmpty) throw Exception('Empty sync payload');

            // Decompress data
            final compressedBytes = base64Url.decode(base64Data);
            final jsonBytes = GZipDecoder().decodeBytes(compressedBytes);
            final jsonString = utf8.decode(jsonBytes);
            final Map<String, dynamic> dataMap = jsonDecode(jsonString);

            // Parse manifest metadata and validate
            final manifest = dataMap['manifest'] ?? {};

            // 1. Schema Version Check
            final schemaVer = manifest['schema_version']?.toString() ?? '';
            if (schemaVer != '4') {
              throw Exception('Incompatible database schema version: $schemaVer. Expected: 4.');
            }

            // 2. Minimum Supported Version Check
            final minSuppVer = manifest['minimum_supported_version']?.toString() ?? '1.0.0';
            if (!PackageValidator.isVersionCompatible(AppConstants.appVersion, minSuppVer)) {
              throw Exception('App version (${AppConstants.appVersion}) is too old. Expected at least $minSuppVer.');
            }

            // 3. Double Import / Package Expiry Check
            final packageId = manifest['package_id']?.toString() ?? '';
            if (packageId.isNotEmpty) {
              final mainDb = await DatabaseHelper.instance.database;
              final List<Map<String, dynamic>> existingImport = await mainDb.query(
                'import_history', 
                where: 'package_id = ?', 
                whereArgs: [packageId]
              );
              if (existingImport.isNotEmpty) {
                // Return success immediately without duplicate merging
                request.response
                  ..statusCode = HttpStatus.ok
                  ..headers.contentType = ContentType.json
                  ..write(jsonEncode({
                    'status': 'success',
                    'message': 'Package already imported previously.',
                    'merged_records': 0,
                  }));
                await request.response.close();
                return;
              }
            }

            // Merge Database Records
            final stats = await DatabaseHelper.instance.mergeDatabaseFromJson(
              dataMap,
              selectedModules: ['entire_db'],
            );

            // Decode and Write Photos
            final photos = dataMap['photos'];
            if (photos is List) {
              for (final photo in photos) {
                if (photo is Map) {
                  final filename = photo['filename']?.toString();
                  final base64Str = photo['base64']?.toString();
                  if (filename != null && base64Str != null) {
                    final bytes = base64Decode(base64Str);
                    final photoDirs = [
                      '${AppConstants.appDocsDir}/customer_photos/$filename',
                      '${AppConstants.appDocsDir}/area_photos/$filename',
                      '${AppConstants.appDocsDir}/street_photos/$filename',
                      '${AppConstants.appDocsDir}/note_photos/$filename',
                    ];
                    for (final targetPath in photoDirs) {
                      final destFile = File(targetPath);
                      await destFile.parent.create(recursive: true);
                      await destFile.writeAsBytes(bytes);
                    }
                  }
                }
              }
            }

            // Log import activity in history logs
            final wId = manifest['generated_by_worker_id']?.toString() ?? 'unknown';
            final wName = manifest['generated_by_worker_name']?.toString() ?? 'Worker';
            final devName = manifest['device_name']?.toString() ?? 'Device';

            int recordsCount = 0;
            stats.forEach((table, val) {
              recordsCount += (val['inserted'] ?? 0) + (val['updated'] ?? 0);
            });

            final mainDb = await DatabaseHelper.instance.database;
            await mainDb.insert('import_history', {
              'id': const Uuid().v4(),
              'package_id': packageId,
              'worker_id': wId,
              'imported_at': DateTime.now().toIso8601String(),
              'worker_name': wName,
              'device_name': devName,
              'record_count': recordsCount,
              'status': 'success',
              'error_log': jsonEncode(stats),
            });

            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({
                'status': 'success',
                'merged_records': recordsCount,
              }));
            await request.response.close();

            onSyncSuccess();
          } catch (e) {
            request.response
              ..statusCode = HttpStatus.internalServerError
              ..write(jsonEncode({'status': 'error', 'message': e.toString()}));
            await request.response.close();
            onStatusUpdate('Sync failed: $e');
          }
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Not Found');
          await request.response.close();
        }
      });
    } catch (e) {
      onStatusUpdate('Server failed to start: $e');
    }
  }

  /// Stop local HTTP server
  static Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }

  // ---------------------------------------------------------------------------
  // 3. WORKER/OWNER CLIENT OPERATIONS
  // ---------------------------------------------------------------------------

  /// Get last sync timestamp
  static Future<String> _getLastSyncTime() async {
    final mainDb = await DatabaseHelper.instance.database;
    final rows = await mainDb.query('settings', where: 'key = ?', whereArgs: ['last_owner_sync_timestamp']);
    return rows.isNotEmpty ? rows.first['value']?.toString() ?? '' : '';
  }

  /// Compile sync packet containing selected database modules & base64 photos
  static Future<String> compileSyncPayload({
    required String workerId,
    required String workerName,
    required List<String> modules,
  }) async {
    final mainDb = await DatabaseHelper.instance.database;
    final lastSyncTime = await _getLastSyncTime();

    final dataMap = <String, dynamic>{
      'manifest': {
        'package_id': const Uuid().v4(),
        'package_type': 'hotspot_sync',
        'schema_version': '4',
        'minimum_supported_version': '1.0.0',
        'generated_at': DateTime.now().toIso8601String(),
        'generated_by_worker_id': workerId,
        'generated_by_worker_name': workerName,
        'device_name': Platform.localHostname,
      }
    };

    // 1. Areas & Streets Route Selection
    if (modules.contains('areas_streets')) {
      dataMap['areas'] = await mainDb.query('areas');
      dataMap['streets'] = await mainDb.query('streets');
    }

    // 2. Customers catalog selection
    if (modules.contains('customers')) {
      dataMap['customers'] = await mainDb.query('customers');
      dataMap['vip_membership'] = await mainDb.query('vip_membership');
    }

    // 3. Orders & Payments selection
    if (modules.contains('orders_payments')) {
      final ordersRows = lastSyncTime.isNotEmpty
          ? await mainDb.query('orders', where: 'created_at >= ? OR updated_at >= ?', whereArgs: [lastSyncTime, lastSyncTime])
          : await mainDb.query('orders');
      dataMap['orders'] = ordersRows;

      final List<String> orderIds = ordersRows.map((e) => e['id']?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      dataMap['order_items'] = orderIds.isEmpty
          ? []
          : await mainDb.query('order_items', where: 'order_id IN (${orderIds.map((e) => "'$e'").join(',')})');
      dataMap['payments'] = orderIds.isEmpty
          ? []
          : await mainDb.query('payments', where: 'order_id IN (${orderIds.map((e) => "'$e'").join(',')})');
    }

    // 4. Products & Selling Prices selection
    if (modules.contains('products')) {
      dataMap['items'] = await mainDb.query('items');
      dataMap['item_price_history'] = await mainDb.query('item_price_history');
    }

    // 5. Expenses selection
    if (modules.contains('expenses')) {
      dataMap['expenses'] = await mainDb.query('expenses');
    }

    // 6. Base64 Photos selection
    final List<Map<String, String>> photosPayload = [];
    if (modules.contains('photos')) {
      final photoDirsToScan = [
        Directory('${AppConstants.appDocsDir}/customer_photos'),
        Directory('${AppConstants.appDocsDir}/area_photos'),
        Directory('${AppConstants.appDocsDir}/street_photos'),
        Directory('${AppConstants.appDocsDir}/note_photos'),
        Directory('${AppConstants.appDocsDir}/attachments'),
      ];
      final lastSyncDate = lastSyncTime.isNotEmpty ? DateTime.tryParse(lastSyncTime) : null;
      final Set<String> processedFilenames = {};

      for (final dir in photoDirsToScan) {
        if (dir.existsSync()) {
          final files = dir.listSync();
          for (final f in files) {
            if (f is File) {
              final filename = p.basename(f.path);
              if (processedFilenames.contains(filename)) continue;

              final stat = f.statSync();
              if (lastSyncDate == null || stat.modified.isAfter(lastSyncDate)) {
                final bytes = await f.readAsBytes();
                photosPayload.add({
                  'filename': filename,
                  'base64': base64Encode(bytes),
                });
                processedFilenames.add(filename);
              }
            }
          }
        }
      }
    }
    dataMap['photos'] = photosPayload;

    final jsonString = jsonEncode(dataMap);
    final jsonBytes = utf8.encode(jsonString);
    final compressedBytes = GZipEncoder().encode(jsonBytes);
    if (compressedBytes == null) throw Exception('Gzip compression failed');
    return base64Url.encode(compressedBytes);
  }

  /// Run direct HTTP POST request to sync with active receiver IP
  static Future<bool> syncWithGateway({
    required String gatewayIp,
    required String workerId,
    required String workerName,
    required List<String> modules,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      // 1. Handshake verification
      final handshakeUri = Uri.parse('http://$gatewayIp:8292/handshake');
      final handshakeReq = await client.getUrl(handshakeUri);
      final handshakeResp = await handshakeReq.close();
      if (handshakeResp.statusCode != HttpStatus.ok) return false;

      final body = await utf8.decoder.bind(handshakeResp).join();
      final res = jsonDecode(body);
      if (res['app'] != 'orderkart') return false;

      // 2. Compile & POST payload
      final payload = await compileSyncPayload(
        workerId: workerId,
        workerName: workerName,
        modules: modules,
      );
      
      final syncUri = Uri.parse('http://$gatewayIp:8292/sync');
      final syncReq = await client.postUrl(syncUri);
      syncReq.headers.contentType = ContentType.json;
      syncReq.write(jsonEncode({'data': payload}));

      final syncResp = await syncReq.close();
      if (syncResp.statusCode == HttpStatus.ok) {
        final mainDb = await DatabaseHelper.instance.database;
        await mainDb.insert('settings', {
          'key': 'last_owner_sync_timestamp',
          'value': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  // ---------------------------------------------------------------------------
  // 4. BACKGROUND AUTO-SYNC TRIGGER
  // ---------------------------------------------------------------------------

  /// Background Wi-Fi range auto-sync listener
  static void startAutoSyncListener({
    required String workerId,
    required String workerName,
    required Function(String event) onSyncEvent,
  }) {
    _connectionSubscription?.cancel();

    _connectionSubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      if (_isSyncing) return;
      
      if (results.contains(ConnectivityResult.wifi)) {
        _isSyncing = true;
        try {
          // Auto-discover the receiver IP on subnet
          final discoveredIp = await discoverReceiverDevice();
          if (discoveredIp != null) {
            onSyncEvent('Connected to sync partner at $discoveredIp. Auto-syncing...');
            
            // Auto sync compiles all modules in background auto-sync mode
            final success = await syncWithGateway(
              gatewayIp: discoveredIp,
              workerId: workerId,
              workerName: workerName,
              modules: ['areas_streets', 'customers', 'orders_payments', 'products', 'expenses', 'photos'],
            );
            if (success) {
              onSyncEvent('SUCCESS: Automatically synced database and photos with partner!');
            }
          }
        } catch (_) {
          // Silent catch in background
        } finally {
          _isSyncing = false;
        }
      }
    });
  }

  static void stopAutoSyncListener() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }
}
