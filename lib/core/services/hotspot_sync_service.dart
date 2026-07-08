import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import '../database/database_helper.dart';
import '../constants/app_constants.dart';
import 'package_validator.dart';
import 'worker_package_service.dart';

class HotspotSyncService {
  HotspotSyncService._();

  static HttpServer? _server;
  static StreamSubscription<List<ConnectivityResult>>? _connectionSubscription;
  static bool _isSyncing = false;
  static String? currentSyncToken;

  static final ValueNotifier<bool> isServerRunningNotifier = ValueNotifier<bool>(false);
  static bool get isServerRunning => isServerRunningNotifier.value;

  static Future<String> getSyncToken() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('settings', columns: ['value'], where: 'key = ?', whereArgs: [AppConstants.keyOwnerSecret]);
      if (res.isNotEmpty) {
        final secret = res.first['value']?.toString() ?? '';
        if (secret.isNotEmpty) {
          return hmacSha256(secret);
        }
      }
    } catch (_) {}
    return 'default_hotspot_sync_token_fallback';
  }

  static String hmacSha256(String secret) {
    final keyBytes = utf8.encode(secret);
    final messageBytes = utf8.encode('hotspot_sync_token_salt');
    final hmac = Hmac(sha256, keyBytes);
    return hmac.convert(messageBytes).toString();
  }

  static Future<List<String>?> Function(
    Map<String, dynamic> manifest,
    Map<String, int> incomingCounts,
  )? onConfirmIncomingSync;

  // ---------------------------------------------------------------------------
  // 1. DISCOVERY & SUBNET SCANNING
  // ---------------------------------------------------------------------------

  /// Helper to check if a specific IP responds to handshake on port 8292
  static Future<bool> _pingDevice(String ip) async {
    final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);
    try {
      final token = await getSyncToken();
      final req = await client.getUrl(Uri.parse('http://$ip:8292/handshake'));
      req.headers.add('x-sync-token', token);
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

    // 2. Scan all client IPs in batches of 20 to avoid exhausting file descriptors (H19)
    final List<String> ipsToPing = [];
    for (int i = 1; i <= 254; i++) {
      final targetIp = '$subnet.$i';
      if (targetIp == localIp || targetIp == gateway) continue;
      ipsToPing.add(targetIp);
    }

    final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 400);

    try {
      const batchSize = 20;
      final token = await getSyncToken();
      for (int i = 0; i < ipsToPing.length; i += batchSize) {
        final end = i + batchSize > ipsToPing.length ? ipsToPing.length : i + batchSize;
        final batch = ipsToPing.sublist(i, end);
        final results = await Future.wait(batch.map((ip) async {
          try {
            final req = await client.getUrl(Uri.parse('http://$ip:8292/handshake'));
            req.headers.add('x-sync-token', token);
            final resp = await req.close();
            if (resp.statusCode == HttpStatus.ok) {
              final body = await utf8.decoder.bind(resp).join();
              final res = jsonDecode(body);
              if (res['app'] == 'orderkart') {
                return ip;
              }
            }
          } catch (_) {}
          return null;
        }));

        for (final res in results) {
          if (res != null) return res; // Return immediately on first found device (N5)
        }
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
      currentSyncToken = 'dummy_token';

      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8292);
      isServerRunningNotifier.value = true;
      onStatusUpdate('Server listening. Waiting for other device to sync...');

      _server!.listen((HttpRequest request) async {
        final path = request.uri.path;
        final method = request.method;

        final localToken = await getSyncToken();
        final clientToken = request.headers.value('x-sync-token') ?? '';

        if (clientToken != localToken) {
          request.response
            ..statusCode = HttpStatus.unauthorized
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'status': 'unauthorized', 'message': 'Invalid sync token'}));
          await request.response.close();
          onStatusUpdate('Rejected unauthorized sync request (token mismatch).');
          return;
        }

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

            // C5: Payload size limit check
            final contentLength = request.contentLength;
            if (contentLength > 50 * 1024 * 1024) {
              throw Exception('Payload exceeds maximum size limit of 50MB');
            }

            final bytesBuilder = BytesBuilder();
            int totalBytesRead = 0;
            await for (final chunk in request) {
              totalBytesRead += chunk.length;
              if (totalBytesRead > 50 * 1024 * 1024) {
                throw Exception('Payload exceeds maximum size limit of 50MB');
              }
              bytesBuilder.add(chunk);
            }

            final body = utf8.decode(bytesBuilder.takeBytes());
            final Map<String, dynamic> payload = jsonDecode(body);

            final String base64Data = payload['data']?.toString() ?? '';
            if (base64Data.isEmpty) throw Exception('Empty sync payload');

            payload.remove('data'); // Free memory immediately

            // Decompress data
            final compressedBytes = base64Url.decode(base64Data);
            final jsonBytes = GZipDecoder().decodeBytes(compressedBytes);
            final jsonString = utf8.decode(jsonBytes);
            final Map<String, dynamic> dataMap = jsonDecode(jsonString);

            // Parse manifest metadata and validate
            final manifest = dataMap['manifest'] ?? {};

            // 1. Schema Version Check
            final schemaVer = manifest['schema_version']?.toString() ?? '';
            final schemaInt = int.tryParse(schemaVer) ?? 0;
            if (schemaInt < 1 || schemaInt > 4) {
              throw Exception('Incompatible database schema version: $schemaVer. Expected: 1-4.');
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

            final mainDb = await DatabaseHelper.instance.database;

            // Strict worker-to-worker prevention check
            final settingsRows = await mainDb.query('settings', where: 'key = ?', whereArgs: ['app_mode']);
            final currentAppModeStr = settingsRows.isNotEmpty ? settingsRows.first['value']?.toString() : '';
            final isLocalWorker = currentAppModeStr == 'worker';
            final generatedByWorkerId = manifest['generated_by_worker_id']?.toString() ?? '';

            if (isLocalWorker && generatedByWorkerId.isNotEmpty) {
              throw Exception('Worker-to-worker sync is strictly prohibited. Imports are only allowed from Owner.');
            }

            // Prepare counts of incoming elements for the confirmation dialog
            final Map<String, int> incomingCounts = {
              'areas': (dataMap['areas'] as List?)?.length ?? 0,
              'streets': (dataMap['streets'] as List?)?.length ?? 0,
              'customers': (dataMap['customers'] as List?)?.length ?? 0,
              'orders': (dataMap['orders'] as List?)?.length ?? 0,
              'items': (dataMap['items'] as List?)?.length ?? 0,
              'expenses': (dataMap['expenses'] as List?)?.length ?? 0,
              'photos': (dataMap['photos'] as List?)?.length ?? 0,
            };

            List<String> selectedModules = ['entire_db'];
            bool importPhotos = true;

            if (onConfirmIncomingSync != null) {
              final confirmedModules = await onConfirmIncomingSync!(manifest, incomingCounts);
              if (confirmedModules == null) {
                request.response
                  ..statusCode = HttpStatus.badRequest
                  ..headers.contentType = ContentType.json
                  ..write(jsonEncode({
                    'status': 'cancelled',
                    'message': 'Sync rejected by receiver.',
                  }));
                await request.response.close();
                onStatusUpdate('Sync request rejected by user.');
                return;
              }
              selectedModules = confirmedModules;
              importPhotos = confirmedModules.contains('photos');
            }

            // Merge Database Records
            final stats = await DatabaseHelper.instance.mergeDatabaseFromJson(
              dataMap,
              selectedModules: selectedModules,
            );

            // Decode and Write Photos
            final photos = dataMap['photos'];
            if (photos is List && importPhotos) {
              for (final photo in photos) {
                if (photo is Map) {
                  final filename = photo['filename']?.toString();
                  final folder = photo['folder']?.toString() ?? 'customer_photos';
                  final base64Str = photo['base64']?.toString();
                  if (filename != null && base64Str != null) {
                    final bytes = base64Decode(base64Str);
                    final targetPath = '${AppConstants.appDocsDir}/$folder/$filename';
                    final destFile = File(targetPath);
                    await destFile.parent.create(recursive: true);
                    await destFile.writeAsBytes(bytes);
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

            Map<String, dynamic>? scopedWorkerData;
            if (wId != 'unknown' && wId.isNotEmpty && !isLocalWorker) {
              try {
                scopedWorkerData = await WorkerPackageService.getScopedDataForWorker(wId);
              } catch (err) {
                debugPrint('Failed to compile scoped data for worker: $err');
              }
            }

            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({
                'status': 'success',
                'merged_records': recordsCount,
                if (scopedWorkerData != null) 'scoped_data': scopedWorkerData,
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
      isServerRunningNotifier.value = false;
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

    final assignmentsRows = workerId.isNotEmpty
        ? await mainDb.query('worker_assignments', where: 'worker_id = ?', whereArgs: [workerId])
        : [];

    final List<String> explicitAreaIds = assignmentsRows
        .where((e) => e['entity_type'] == 'area')
        .map((e) => e['entity_id']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();

    final List<String> explicitStreetIds = assignmentsRows
        .where((e) => e['entity_type'] == 'street')
        .map((e) => e['entity_id']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();

    final List<String> explicitCustomerIds = assignmentsRows
        .where((e) => e['entity_type'] == 'customer')
        .map((e) => e['entity_id']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();

    // 1. Resolve Customers
    List<Map<String, dynamic>> customersRows = [];
    if (workerId.isNotEmpty && assignmentsRows.isNotEmpty) {
      List<String> conditions = [];
      List<dynamic> args = [];
      if (explicitCustomerIds.isNotEmpty) {
        final placeholders = List.filled(explicitCustomerIds.length, '?').join(',');
        conditions.add('id IN ($placeholders)');
        args.addAll(explicitCustomerIds);
      }
      if (explicitStreetIds.isNotEmpty) {
        final placeholders = List.filled(explicitStreetIds.length, '?').join(',');
        conditions.add('street_id IN ($placeholders)');
        args.addAll(explicitStreetIds);
      }
      if (explicitAreaIds.isNotEmpty) {
        final placeholders = List.filled(explicitAreaIds.length, '?').join(',');
        conditions.add('street_id IN (SELECT id FROM streets WHERE area_id IN ($placeholders))');
        args.addAll(explicitAreaIds);
      }
      if (conditions.isNotEmpty) {
        final whereClause = conditions.join(' OR ');
        customersRows = await mainDb.query('customers', where: whereClause, whereArgs: args);
      }
    } else {
      customersRows = await mainDb.query('customers');
    }

    // 2. Resolve Streets
    final Set<String> resolvedStreetIds = {};
    resolvedStreetIds.addAll(explicitStreetIds);
    for (final c in customersRows) {
      final sId = c['street_id']?.toString() ?? '';
      if (sId.isNotEmpty) resolvedStreetIds.add(sId);
    }

    List<Map<String, dynamic>> streetsRows = [];
    if (workerId.isNotEmpty && assignmentsRows.isNotEmpty) {
      if (resolvedStreetIds.isNotEmpty || explicitAreaIds.isNotEmpty) {
        List<String> conditions = [];
        List<dynamic> args = [];
        if (resolvedStreetIds.isNotEmpty) {
          final placeholders = List.filled(resolvedStreetIds.length, '?').join(',');
          conditions.add('id IN ($placeholders)');
          args.addAll(resolvedStreetIds.toList());
        }
        if (explicitAreaIds.isNotEmpty) {
          final placeholders = List.filled(explicitAreaIds.length, '?').join(',');
          conditions.add('area_id IN ($placeholders)');
          args.addAll(explicitAreaIds);
        }
        final whereClause = conditions.join(' OR ');
        streetsRows = await mainDb.query('streets', where: whereClause, whereArgs: args);
      }
    } else {
      streetsRows = await mainDb.query('streets');
    }

    // 3. Resolve Areas
    final Set<String> resolvedAreaIds = {};
    resolvedAreaIds.addAll(explicitAreaIds);
    for (final s in streetsRows) {
      final aId = s['area_id']?.toString() ?? '';
      if (aId.isNotEmpty) resolvedAreaIds.add(aId);
    }

    List<Map<String, dynamic>> areasRows = [];
    if (workerId.isNotEmpty && assignmentsRows.isNotEmpty) {
      if (resolvedAreaIds.isNotEmpty) {
        final placeholders = List.filled(resolvedAreaIds.length, '?').join(',');
        areasRows = await mainDb.query('areas', where: 'id IN ($placeholders)', whereArgs: resolvedAreaIds.toList());
      }
    } else {
      areasRows = await mainDb.query('areas');
    }

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
      dataMap['areas'] = areasRows;
      dataMap['streets'] = streetsRows;
    }

    // 2. Customers catalog selection
    if (modules.contains('customers')) {
      dataMap['customers'] = customersRows;
      final List<String> customerIds = customersRows.map((e) => e['id']?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      if (customerIds.isNotEmpty) {
        final placeholders = List.filled(customerIds.length, '?').join(',');
        dataMap['vip_membership'] = await mainDb.query('vip_membership', where: 'customer_id IN ($placeholders)', whereArgs: customerIds);
      } else {
        dataMap['vip_membership'] = [];
      }
    }

    // 3. Orders & Payments selection
    if (modules.contains('orders_payments')) {
      final List<String> customerIds = customersRows.map((e) => e['id']?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      List<Map<String, dynamic>> ordersRows = [];
      if (workerId.isNotEmpty && assignmentsRows.isNotEmpty) {
        if (customerIds.isNotEmpty) {
          final placeholders = List.filled(customerIds.length, '?').join(',');
          final whereClause = lastSyncTime.isNotEmpty
              ? '(customer_id IN ($placeholders) OR assigned_worker_id = ? OR created_by = ?) AND (created_at >= ? OR updated_at >= ?)'
              : 'customer_id IN ($placeholders) OR assigned_worker_id = ? OR created_by = ?';
          final args = lastSyncTime.isNotEmpty
              ? [...customerIds, workerId, workerId, lastSyncTime, lastSyncTime]
              : [...customerIds, workerId, workerId];
          ordersRows = await mainDb.query('orders', where: whereClause, whereArgs: args);
        } else {
          final whereClause = lastSyncTime.isNotEmpty
              ? '(assigned_worker_id = ? OR created_by = ?) AND (created_at >= ? OR updated_at >= ?)'
              : 'assigned_worker_id = ? OR created_by = ?';
          final args = lastSyncTime.isNotEmpty
              ? [workerId, workerId, lastSyncTime, lastSyncTime]
              : [workerId, workerId];
          ordersRows = await mainDb.query('orders', where: whereClause, whereArgs: args);
        }
      } else {
        ordersRows = lastSyncTime.isNotEmpty
            ? await mainDb.query('orders', where: 'created_at >= ? OR updated_at >= ?', whereArgs: [lastSyncTime, lastSyncTime])
            : await mainDb.query('orders');
      }
      dataMap['orders'] = ordersRows;

      final List<String> orderIds = ordersRows.map((e) => e['id']?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      
      final List<Map<String, dynamic>> orderItemsRows;
      if (orderIds.isNotEmpty) {
        final placeholders = List.filled(orderIds.length, '?').join(',');
        orderItemsRows = await mainDb.query('order_items', where: 'order_id IN ($placeholders)', whereArgs: orderIds);
      } else {
        orderItemsRows = [];
      }
      dataMap['order_items'] = orderItemsRows;

      final List<Map<String, dynamic>> paymentsRows;
      if (workerId.isNotEmpty && assignmentsRows.isNotEmpty) {
        if (orderIds.isNotEmpty) {
          final placeholders = List.filled(orderIds.length, '?').join(',');
          final whereClause = lastSyncTime.isNotEmpty
              ? '(created_at >= ? OR order_id IN ($placeholders) OR customer_id IN (SELECT id FROM customers WHERE created_by = ?))'
              : 'order_id IN ($placeholders) OR customer_id IN (SELECT id FROM customers WHERE created_by = ?)';
          final args = lastSyncTime.isNotEmpty
              ? [lastSyncTime, ...orderIds, workerId]
              : [...orderIds, workerId];
          paymentsRows = await mainDb.query('payments', where: whereClause, whereArgs: args);
        } else {
          final whereClause = lastSyncTime.isNotEmpty
              ? 'created_at >= ? AND customer_id IN (SELECT id FROM customers WHERE created_by = ?)'
              : 'customer_id IN (SELECT id FROM customers WHERE created_by = ?)';
          final args = lastSyncTime.isNotEmpty
              ? [lastSyncTime, workerId]
              : [workerId];
          paymentsRows = await mainDb.query('payments', where: whereClause, whereArgs: args);
        }
      } else {
        if (lastSyncTime.isNotEmpty) {
          if (orderIds.isNotEmpty) {
            final placeholders = List.filled(orderIds.length, '?').join(',');
            paymentsRows = await mainDb.query('payments',
                where: 'created_at >= ? OR order_id IN ($placeholders)',
                whereArgs: [lastSyncTime, ...orderIds]);
          } else {
            paymentsRows = await mainDb.query('payments',
                where: 'created_at >= ?',
                whereArgs: [lastSyncTime]);
          }
        } else {
          paymentsRows = await mainDb.query('payments');
        }
      }
      dataMap['payments'] = paymentsRows;
    }

    // 4. Products & Selling Prices selection
    if (modules.contains('products')) {
      dataMap['items'] = await mainDb.query('items');
      dataMap['item_price_history'] = await mainDb.query('item_price_history');
    }

    // 5. Expenses selection
    if (modules.contains('expenses')) {
      if (workerId.isNotEmpty && assignmentsRows.isNotEmpty) {
        dataMap['expenses'] = await mainDb.query('expenses', where: 'assigned_worker_id = ? OR created_by = ?', whereArgs: [workerId, workerId]);
      } else {
        dataMap['expenses'] = await mainDb.query('expenses');
      }
    }

    // 6. Base64 Photos selection
    final List<Map<String, String>> photosPayload = [];
    if (modules.contains('photos')) {
      final Set<String> assignedPhotoNames = {};
      if (workerId.isNotEmpty && assignmentsRows.isNotEmpty) {
        for (final c in customersRows) {
          final pathStr = c['photo_path']?.toString() ?? '';
          if (pathStr.isNotEmpty) assignedPhotoNames.add(p.basename(pathStr));
        }
      }

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
          final folderName = p.basename(dir.path);
          final files = dir.listSync();
          for (final f in files) {
            if (f is File) {
              final filename = p.basename(f.path);
              if (workerId.isNotEmpty && assignmentsRows.isNotEmpty && !assignedPhotoNames.contains(filename)) {
                continue;
              }
              final uniqueKey = '$folderName/$filename';
              if (processedFilenames.contains(uniqueKey)) continue;

              final stat = f.statSync();
              if (lastSyncDate == null || stat.modified.isAfter(lastSyncDate)) {
                final bytes = await f.readAsBytes();
                photosPayload.add({
                  'folder': folderName,
                  'filename': filename,
                  'base64': base64Encode(bytes),
                });
                processedFilenames.add(uniqueKey);
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

  static Future<bool> syncWithGateway({
    required String gatewayIp,
    required String workerId,
    required String workerName,
    required List<String> modules,
    String syncToken = '',
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final token = await getSyncToken();
      // 1. Handshake verification
      final handshakeUri = Uri.parse('http://$gatewayIp:8292/handshake');
      final handshakeReq = await client.getUrl(handshakeUri).timeout(const Duration(seconds: 5));
      handshakeReq.headers.add('x-sync-token', token);
      final handshakeResp = await handshakeReq.close().timeout(const Duration(seconds: 5));
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
      final syncReq = await client.postUrl(syncUri).timeout(const Duration(seconds: 30));
      syncReq.headers.contentType = ContentType.json;
      syncReq.headers.add('x-sync-token', token);
      syncReq.write(jsonEncode({'data': payload}));

      final syncResp = await syncReq.close().timeout(const Duration(seconds: 30));
      if (syncResp.statusCode == HttpStatus.ok) {
        final responseBody = await utf8.decoder.bind(syncResp).join();
        try {
          final resMap = jsonDecode(responseBody);
          if (resMap is Map && resMap['scoped_data'] != null) {
            await DatabaseHelper.instance.mergeDatabaseFromJson(
              Map<String, dynamic>.from(resMap['scoped_data']),
            );
          }
        } catch (e) {
          debugPrint('Failed to merge updated scoped data from sync response: $e');
        }

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
