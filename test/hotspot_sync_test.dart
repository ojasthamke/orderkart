// test/hotspot_sync_test.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:archive/archive.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/core/services/hotspot_sync_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Hotspot Sync Service Tests', () {
    setUpAll(() async {
      DatabaseHelper.dbNameOverride = 'orderkart_test_hotspot.db';
      final db = await DatabaseHelper.instance.database;
      
      // Clean and seed a simple area
      await db.delete('areas');
      await db.insert('areas', {
        'id': 'test-area-1',
        'name': 'Test Area Hotspot',
        'description': 'Description',
        'color': 0xFF1565C0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    });

    test('Payload Compilation works correctly', () async {
      final payload = await HotspotSyncService.compileSyncPayload('worker-1', 'Worker One');
      expect(payload, isNotEmpty);

      // Verify Gzip decompression
      final compressedBytes = base64Url.decode(payload);
      final jsonBytes = GZipDecoder().decodeBytes(compressedBytes);
      final jsonString = utf8.decode(jsonBytes!);
      final Map<String, dynamic> data = jsonDecode(jsonString);

      expect(data['manifest']['generated_by_worker_id'], equals('worker-1'));
      expect(data['areas'], isNotEmpty);
      expect(data['areas'].first['id'], equals('test-area-1'));
    });

    test('Local HTTP Server Handshake and Sync works', () async {
      String statusMsg = '';
      bool successTriggered = false;

      // Start server
      await HotspotSyncService.startServer(
        onStatusUpdate: (msg) => statusMsg = msg,
        onSyncSuccess: () => successTriggered = true,
      );

      expect(HotspotSyncService.isServerRunning, isTrue);

      final client = HttpClient();
      
      // Test GET /handshake
      final handshakeReq = await client.get('127.0.0.1', 8292, '/handshake');
      final handshakeResp = await handshakeReq.close();
      expect(handshakeResp.statusCode, equals(HttpStatus.ok));
      final handshakeBody = await utf8.decoder.bind(handshakeResp).join();
      final handshakeData = jsonDecode(handshakeBody);
      expect(handshakeData['app'], equals('orderkart'));
      expect(handshakeData['role'], equals('owner'));

      // Test POST /sync
      final payload = await HotspotSyncService.compileSyncPayload('worker-1', 'Worker One');
      final syncReq = await client.post('127.0.0.1', 8292, '/sync');
      syncReq.headers.contentType = ContentType.json;
      syncReq.write(jsonEncode({'data': payload}));
      final syncResp = await syncReq.close();
      final syncBody = await utf8.decoder.bind(syncResp).join();
      print('SYNC RESPONSE BODY: $syncBody');
      expect(syncResp.statusCode, equals(HttpStatus.ok));

      final syncData = jsonDecode(syncBody);
      expect(syncData['status'], equals('success'));

      await Future.delayed(const Duration(milliseconds: 50));
      expect(successTriggered, isTrue);

      // Clean up server
      await HotspotSyncService.stopServer();
      expect(HotspotSyncService.isServerRunning, isFalse);
    });
  });
}
