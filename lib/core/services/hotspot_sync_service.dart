import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../constants/app_constants.dart';
import 'worker_session.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';

class HotspotSyncService {
  HotspotSyncService._();

  static HttpServer? _server;
  static StreamSubscription<List<ConnectivityResult>>? _connectionSubscription;
  static bool _isSyncing = false;

  static bool get isServerRunning => _server != null;

  // ---------------------------------------------------------------------------
  // 1. OWNER SERVER OPERATIONS
  // ---------------------------------------------------------------------------

  /// Start local HTTP server on Owner device
  static Future<void> startServer({
    required Function(String status) onStatusUpdate,
    required VoidCallback onSyncSuccess,
  }) async {
    if (_server != null) return;

    try {
      // Bind to any IPv4 address on port 8292
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8292);
      onStatusUpdate('Server started on port 8292. Listening for incoming sync...');

      _server!.listen((HttpRequest request) async {
        final path = request.uri.path;
        final method = request.method;

        if (method == 'GET' && path == '/handshake') {
          // Handshake endpoint to identify as OrderKart Owner
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'app': 'orderkart',
              'role': 'owner',
              'timestamp': DateTime.now().toIso8601String(),
            }));
          await request.response.close();
        } else if (method == 'POST' && path == '/sync') {
          // Sync endpoint receiving Gzipped Base64 payload
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

            // Merge Database Records
            final stats = await DatabaseHelper.instance.mergeDatabaseFromJson(
              dataMap,
              selectedModules: ['entire_db'],
            );

            // Decode and Write Photos
            final photos = dataMap['photos'];
            if (photos is List) {
              final destDir = Directory('${AppConstants.appDocsDir}/customer_photos');
              if (!destDir.existsSync()) {
                destDir.createSync(recursive: true);
              }
              for (final photo in photos) {
                if (photo is Map) {
                  final filename = photo['filename']?.toString();
                  final base64Str = photo['base64']?.toString();
                  if (filename != null && base64Str != null) {
                    final bytes = base64Decode(base64Str);
                    final destFile = File('${destDir.path}/$filename');
                    await destFile.writeAsBytes(bytes);
                  }
                }
              }
            }

            // Log import activity
            final manifest = dataMap['manifest'] ?? {};
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
              'package_id': wId,
              'imported_at': DateTime.now().toIso8601String(),
              'worker_name': wName,
              'device_name': devName,
              'record_count': recordsCount,
              'status': 'success',
              'error_log': jsonEncode(stats),
            });

            // Respond success
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
      onStatusUpdate('Server start failed: $e');
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
  // 2. WORKER CLIENT OPERATIONS
  // ---------------------------------------------------------------------------

  /// Helper to get last sync time
  static Future<String> _getLastSyncTime() async {
    final mainDb = await DatabaseHelper.instance.database;
    final rows = await mainDb.query('settings', where: 'key = ?', whereArgs: ['last_owner_sync_timestamp']);
    return rows.isNotEmpty ? rows.first['value']?.toString() ?? '' : '';
  }

  /// Compile sync packet containing new database records & base64 photos
  static Future<String> compileSyncPayload(String workerId, String workerName) async {
    final mainDb = await DatabaseHelper.instance.database;
    final lastSyncTime = await _getLastSyncTime();

    // Query Incremental DB data
    final areasRows = await mainDb.query('areas');
    final streetsRows = await mainDb.query('streets');
    final customersRows = await mainDb.query('customers');
    final ordersRows = lastSyncTime.isNotEmpty
        ? await mainDb.query('orders', where: 'created_at >= ? OR updated_at >= ?', whereArgs: [lastSyncTime, lastSyncTime])
        : await mainDb.query('orders');

    final List<String> orderIds = ordersRows.map((e) => e['id']?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    final List<Map<String, dynamic>> orderItemsRows = orderIds.isEmpty
        ? []
        : await mainDb.query('order_items', where: 'order_id IN (${orderIds.map((e) => "'$e'").join(',')})');
    
    final List<Map<String, dynamic>> paymentsRows = orderIds.isEmpty
        ? []
        : await mainDb.query('payments', where: 'order_id IN (${orderIds.map((e) => "'$e'").join(',')})');

    final expensesRows = await mainDb.query('expenses');
    final notesRows = await mainDb.query('notes');
    final visitsRows = await mainDb.query('visits');
    final workerReportsRows = await mainDb.query('worker_reports', where: 'worker_id = ?', whereArgs: [workerId]);

    // Compile Photos modified since last sync
    final List<Map<String, String>> photosPayload = [];
    final photosDir = Directory('${AppConstants.appDocsDir}/customer_photos');
    if (photosDir.existsSync()) {
      final lastSyncDate = lastSyncTime.isNotEmpty ? DateTime.tryParse(lastSyncTime) : null;
      final files = photosDir.listSync();
      for (final f in files) {
        if (f is File) {
          final stat = f.statSync();
          if (lastSyncDate == null || stat.modified.isAfter(lastSyncDate)) {
            final bytes = await f.readAsBytes();
            photosPayload.add({
              'filename': p.basename(f.path),
              'base64': base64Encode(bytes),
            });
          }
        }
      }
    }

    final dataMap = {
      'manifest': {
        'generated_at': DateTime.now().toIso8601String(),
        'generated_by_worker_id': workerId,
        'generated_by_worker_name': workerName,
        'device_name': Platform.localHostname,
      },
      'areas': areasRows,
      'streets': streetsRows,
      'customers': customersRows,
      'orders': ordersRows,
      'order_items': orderItemsRows,
      'payments': paymentsRows,
      'expenses': expensesRows,
      'notes': notesRows,
      'visits': visitsRows,
      'worker_reports': workerReportsRows,
      'photos': photosPayload,
    };

    final jsonString = jsonEncode(dataMap);
    final jsonBytes = utf8.encode(jsonString);
    final compressedBytes = GZipEncoder().encode(jsonBytes);
    if (compressedBytes == null) throw Exception('Gzip Compression failed');
    return base64Url.encode(compressedBytes);
  }

  /// Run direct HTTP POST request to sync with hotspot host (Owner)
  static Future<bool> syncWithGateway({
    required String gatewayIp,
    required String workerId,
    required String workerName,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      // 1. Handshake
      final handshakeUri = Uri.parse('http://$gatewayIp:8292/handshake');
      final handshakeReq = await client.getUrl(handshakeUri);
      final handshakeResp = await handshakeReq.close();
      if (handshakeResp.statusCode != HttpStatus.ok) return false;

      final body = await utf8.decoder.bind(handshakeResp).join();
      final res = jsonDecode(body);
      if (res['app'] != 'orderkart' || res['role'] != 'owner') return false;

      // 2. Compile & Upload Data
      final payload = await compileSyncPayload(workerId, workerName);
      final syncUri = Uri.parse('http://$gatewayIp:8292/sync');
      final syncReq = await client.postUrl(syncUri);
      
      syncReq.headers.contentType = ContentType.json;
      syncReq.write(jsonEncode({'data': payload}));

      final syncResp = await syncReq.close();
      if (syncResp.statusCode == HttpStatus.ok) {
        // Update local sync time
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
  // 3. BACKGROUND LISTENER FOR AUTOMATIC SYNC
  // ---------------------------------------------------------------------------

  /// Listen for Wi-Fi changes and automatically trigger sync if Owner is detected
  static void startAutoSyncListener({
    required String workerId,
    required String workerName,
    required Function(String event) onSyncEvent,
  }) {
    _connectionSubscription?.cancel();

    _connectionSubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      if (_isSyncing) return;
      
      // We check if connected to Wifi
      if (results.contains(ConnectivityResult.wifi)) {
        _isSyncing = true;
        try {
          final info = NetworkInfo();
          final gateway = await info.getWifiGatewayIP();
          if (gateway != null && gateway.isNotEmpty) {
            onSyncEvent('Owner hotspot range detected. Verifying sync handshake...');
            final success = await syncWithGateway(
              gatewayIp: gateway,
              workerId: workerId,
              workerName: workerName,
            );
            if (success) {
              onSyncEvent('SUCCESS: Automatically synced all pending logs with Owner!');
            }
          }
        } catch (_) {
          // Fail silently in background
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
