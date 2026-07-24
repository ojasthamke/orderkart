import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';
import '../database/database_helper.dart';
import '../utils/security_helper.dart';
import 'package_validator.dart';

class PackageExporter {
  PackageExporter._();

  /// Helper to compute SHA-256 hash of a file
  static Future<String> calculateFileHash(File file) async {
    if (!file.existsSync()) return '';
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  /// Export a scoped zip package with selective database cloning, modular pruning, and manifest metadata
  static Future<void> exportPackage({
    required List<String>
        selectedModules, // 'entire_db', 'areas', 'streets', etc.
    DateTime? startDate,
    DateTime? endDate,
    List<String>? selectedAreaIds,
    List<String>? selectedStreetIds,
    List<String>? selectedCustomerIds,
    List<String>? selectedWorkerIds,
    List<String>? selectedItemIds,
    List<String>? selectedExpenseIds,
    List<String>? selectedNoteIds,
    String workerId = '',
    String workerName = '',
    String? customFileName,
  }) async {
    final mainDb = await DatabaseHelper.instance.database;
    await mainDb.rawQuery('PRAGMA wal_checkpoint(FULL);');
    final dbPath = mainDb.path;
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) throw Exception('Database file not found');

    final tempDir = await getTemporaryDirectory();

    // Create a temporary copy of the database to prune
    final tempDbFileName =
        'orderkart_export_${const Uuid().v4().substring(0, 8)}.db';
    final tempDbFile = File('${tempDir.path}/$tempDbFileName');
    if (tempDbFile.existsSync()) tempDbFile.deleteSync();
    await dbFile.copy(tempDbFile.path);

    // Open the cloned database to perform pruning operations
    final tempDb = await openDatabase(tempDbFile.path);

    // Disable foreign key checks during pruning so we can clean table-by-table without constraint errors
    await tempDb.execute('PRAGMA foreign_keys = OFF');

    final List<String> referencedPhotos = [];

    try {
      final isEntireDb = selectedModules.contains('entire_db');

      if (!isEntireDb) {
        // --- 1. Module-Level Pruning ---
        if (!selectedModules.contains('areas')) {
          await tempDb.delete('areas');
        }
        if (!selectedModules.contains('streets')) {
          await tempDb.delete('streets');
        }
        if (!selectedModules.contains('customers')) {
          await tempDb.delete('customers');
          await tempDb.delete('vip_membership');
        }
        if (!selectedModules.contains('items')) {
          await tempDb.delete('items');
          await tempDb.delete('item_price_history');
          await tempDb.delete('stock_history');
        }
        if (!selectedModules.contains('orders')) {
          await tempDb.delete('orders');
          await tempDb.delete('order_items');
        }
        if (!selectedModules.contains('payments')) {
          await tempDb.delete('payments');
        }
        if (!selectedModules.contains('expenses')) {
          await tempDb.delete('expenses');
        }
        if (!selectedModules.contains('notes')) {
          await tempDb.delete('notes');
        }
        if (!selectedModules.contains('visits')) {
          await tempDb.delete('visits');
        }
        if (!selectedModules.contains('notifications')) {
          await tempDb.delete('notifications');
        }
        if (!selectedModules.contains('workers')) {
          await tempDb.delete('workers');
          await tempDb.delete('worker_security');
          await tempDb.delete('worker_assignments');
          await tempDb.delete('worker_reports');
          await tempDb.delete('commission_history');
        }
        if (!selectedModules.contains('settings')) {
          await tempDb.delete('settings');
          await tempDb.delete('business_profile');
        }
      }

      // --- 2. Entity-Based Pruning ---
      final hasAreaFilter =
          selectedAreaIds != null && selectedAreaIds.isNotEmpty;
      final hasStreetFilter =
          selectedStreetIds != null && selectedStreetIds.isNotEmpty;
      final hasCustomerFilter =
          selectedCustomerIds != null && selectedCustomerIds.isNotEmpty;

      if (hasAreaFilter || hasStreetFilter || hasCustomerFilter) {
        final Set<String> keepAreaIds = {};
        final Set<String> keepStreetIds = {};
        final Set<String> keepCustomerIds = {};

        if (hasAreaFilter) keepAreaIds.addAll(selectedAreaIds);
        if (hasStreetFilter) keepStreetIds.addAll(selectedStreetIds);
        if (hasCustomerFilter) keepCustomerIds.addAll(selectedCustomerIds);

        // 1. Resolve customers to keep:
        // - Explicitly selected customers
        // - Customers on explicitly selected streets
        // - Customers in explicitly selected areas
        List<String> custConditions = [];
        List<dynamic> custArgs = [];
        if (hasCustomerFilter) {
          custConditions.add(
              'id IN (${List.filled(selectedCustomerIds.length, '?').join(',')})');
          custArgs.addAll(selectedCustomerIds);
        }
        if (hasStreetFilter) {
          custConditions.add(
              'street_id IN (${List.filled(selectedStreetIds.length, '?').join(',')})');
          custArgs.addAll(selectedStreetIds);
        }
        if (hasAreaFilter) {
          custConditions.add(
              'street_id IN (SELECT id FROM streets WHERE area_id IN (${List.filled(selectedAreaIds.length, '?').join(',')}))');
          custArgs.addAll(selectedAreaIds);
        }
        final resolvedCustomers = await tempDb.query('customers',
            where: custConditions.isEmpty ? null : custConditions.join(' OR '),
            whereArgs: custArgs.isEmpty ? null : custArgs);

        for (final c in resolvedCustomers) {
          keepCustomerIds.add(c['id'].toString());
          if (c['street_id'] != null) {
            keepStreetIds.add(c['street_id'].toString());
          }
        }

        // 2. Resolve streets to keep:
        // - Explicitly selected streets
        // - Streets in explicitly selected areas
        // - Streets of resolved customers
        List<String> streetConditions = [];
        List<dynamic> streetArgs = [];
        if (keepStreetIds.isNotEmpty) {
          streetConditions.add(
              'id IN (${List.filled(keepStreetIds.length, '?').join(',')})');
          streetArgs.addAll(keepStreetIds);
        }
        if (hasAreaFilter) {
          streetConditions.add(
              'area_id IN (${List.filled(selectedAreaIds.length, '?').join(',')})');
          streetArgs.addAll(selectedAreaIds);
        }
        final resolvedStreets = await tempDb.query('streets',
            where:
                streetConditions.isEmpty ? null : streetConditions.join(' OR '),
            whereArgs: streetArgs.isEmpty ? null : streetArgs);

        for (final s in resolvedStreets) {
          keepStreetIds.add(s['id'].toString());
          if (s['area_id'] != null) {
            keepAreaIds.add(s['area_id'].toString());
          }
        }

        // 3. Resolve areas to keep:
        // - Explicitly selected areas
        // - Areas of resolved streets
        List<String> areaConditions = [];
        List<dynamic> areaArgs = [];
        if (keepAreaIds.isNotEmpty) {
          areaConditions
              .add('id IN (${List.filled(keepAreaIds.length, '?').join(',')})');
          areaArgs.addAll(keepAreaIds);
        }
        final resolvedAreas = await tempDb.query('areas',
            where: areaConditions.isEmpty ? null : areaConditions.join(' OR '),
            whereArgs: areaArgs.isEmpty ? null : areaArgs);
        for (final a in resolvedAreas) {
          keepAreaIds.add(a['id'].toString());
        }

        // Now prune the tables by deleting anything NOT in the resolved sets!
        if (keepAreaIds.isNotEmpty) {
          final placeholders = List.filled(keepAreaIds.length, '?').join(',');
          await tempDb.delete('areas',
              where: 'id NOT IN ($placeholders)',
              whereArgs: keepAreaIds.toList());
        } else {
          await tempDb.delete('areas');
        }

        if (keepStreetIds.isNotEmpty) {
          final placeholders = List.filled(keepStreetIds.length, '?').join(',');
          await tempDb.delete('streets',
              where: 'id NOT IN ($placeholders)',
              whereArgs: keepStreetIds.toList());
        } else {
          await tempDb.delete('streets');
        }

        if (keepCustomerIds.isNotEmpty) {
          final placeholders =
              List.filled(keepCustomerIds.length, '?').join(',');
          await tempDb.delete('customers',
              where: 'id NOT IN ($placeholders)',
              whereArgs: keepCustomerIds.toList());
          await tempDb.delete('orders',
              where: 'customer_id NOT IN ($placeholders)',
              whereArgs: keepCustomerIds.toList());
        } else {
          await tempDb.delete('customers');
          await tempDb.delete('orders');
        }
      }

      if (selectedWorkerIds != null && selectedWorkerIds.isNotEmpty) {
        final placeholders =
            List.filled(selectedWorkerIds.length, '?').join(',');
        await tempDb.delete('workers',
            where: 'id NOT IN ($placeholders)', whereArgs: selectedWorkerIds);
        await tempDb.delete('worker_security',
            where: 'worker_id NOT IN ($placeholders)',
            whereArgs: selectedWorkerIds);
        await tempDb.delete('worker_assignments',
            where: 'worker_id NOT IN ($placeholders)',
            whereArgs: selectedWorkerIds);
        await tempDb.delete('worker_reports',
            where: 'worker_id NOT IN ($placeholders)',
            whereArgs: selectedWorkerIds);
        await tempDb.delete('commission_history',
            where: 'worker_id NOT IN ($placeholders)',
            whereArgs: selectedWorkerIds);
        await tempDb.delete('orders',
            where:
                'assigned_worker_id IS NOT NULL AND assigned_worker_id != "" AND assigned_worker_id NOT IN ($placeholders)',
            whereArgs: selectedWorkerIds);
        await tempDb.delete('customers',
            where:
                'assigned_worker_id IS NOT NULL AND assigned_worker_id != "" AND assigned_worker_id NOT IN ($placeholders)',
            whereArgs: selectedWorkerIds);
      }

      if (selectedItemIds != null && selectedItemIds.isNotEmpty) {
        final placeholders = List.filled(selectedItemIds.length, '?').join(',');
        await tempDb.delete('items',
            where: 'id NOT IN ($placeholders)', whereArgs: selectedItemIds);
        await tempDb.delete('item_price_history',
            where: 'item_id NOT IN ($placeholders)',
            whereArgs: selectedItemIds);
      }

      if (selectedExpenseIds != null && selectedExpenseIds.isNotEmpty) {
        final placeholders =
            List.filled(selectedExpenseIds.length, '?').join(',');
        await tempDb.delete('expenses',
            where: 'id NOT IN ($placeholders)', whereArgs: selectedExpenseIds);
      }

      if (selectedNoteIds != null && selectedNoteIds.isNotEmpty) {
        final placeholders = List.filled(selectedNoteIds.length, '?').join(',');
        await tempDb.delete('notes',
            where: 'id NOT IN ($placeholders)', whereArgs: selectedNoteIds);
      }

      // --- 3. Date Range Pruning ---
      if (startDate != null) {
        final startStr = startDate.toIso8601String();
        await tempDb
            .delete('orders', where: 'created_at < ?', whereArgs: [startStr]);
        await tempDb
            .delete('payments', where: 'created_at < ?', whereArgs: [startStr]);
        await tempDb.delete('expenses',
            where: 'date < ?', whereArgs: [startStr.substring(0, 10)]);
        await tempDb.delete('worker_reports',
            where: 'report_date < ?', whereArgs: [startStr.substring(0, 10)]);
      }

      if (endDate != null) {
        final endStr = endDate.toIso8601String();
        await tempDb
            .delete('orders', where: 'created_at > ?', whereArgs: [endStr]);
        await tempDb
            .delete('payments', where: 'created_at > ?', whereArgs: [endStr]);
        await tempDb.delete('expenses',
            where: 'date > ?', whereArgs: [endStr.substring(0, 10)]);
        await tempDb.delete('worker_reports',
            where: 'report_date > ?', whereArgs: [endStr.substring(0, 10)]);
      }

      // Always strip sensitive/internal tables from non-entire DB exports
      if (!isEntireDb) {
        for (final sensitiveTable in [
          'worker_security',
          'audit_logs',
          'sync_history',
          'pending_sync',
          'worker_devices',
          'repair_logs',
          'export_history',
          'import_history'
        ]) {
          try {
            await tempDb.delete(sensitiveTable);
          } catch (_) {}
        }
      }

      // --- 4. Post-Filter Cascading Cleanup ---
      await tempDb.delete('order_items',
          where: 'order_id NOT IN (SELECT id FROM orders)');
      await tempDb.delete('payments',
          where: 'order_id NOT IN (SELECT id FROM orders)');
      await tempDb.delete('vip_membership',
          where: 'customer_id NOT IN (SELECT id FROM customers)');
      await tempDb.delete('item_price_history',
          where: 'item_id NOT IN (SELECT id FROM items)');
      await tempDb.delete('stock_history',
          where: 'item_id NOT IN (SELECT id FROM items)');

      if (workerId.isNotEmpty) {
        await tempDb.delete('settings', where: "key LIKE 'owner_secret%'");
        await tempDb.delete('worker_security',
            where: "worker_id != ?", whereArgs: [workerId]);
      }

      // Query photo_path columns from cloned tables to scope photo exports (H17)
      try {
        final List<Map<String, dynamic>> custPhotos = await tempDb.rawQuery(
            'SELECT photo_path FROM customers WHERE photo_path IS NOT NULL AND photo_path != ""');
        final List<Map<String, dynamic>> locationPhotos = await tempDb.rawQuery(
            'SELECT photo_path FROM locations WHERE photo_path IS NOT NULL AND photo_path != ""');
        final List<Map<String, dynamic>> notePhotos = await tempDb.rawQuery(
            'SELECT photo_path FROM notes WHERE photo_path IS NOT NULL AND photo_path != ""');
        final List<Map<String, dynamic>> itemPhotos = await tempDb.rawQuery(
            'SELECT photo_path FROM items WHERE photo_path IS NOT NULL AND photo_path != ""');
        final List<Map<String, dynamic>> expensePhotos = await tempDb.rawQuery(
            'SELECT receipt_photo_path FROM expenses WHERE receipt_photo_path IS NOT NULL AND receipt_photo_path != ""');

        for (final r in custPhotos) {
          referencedPhotos.add(p.basename(r['photo_path'].toString()));
        }
        for (final r in locationPhotos) {
          referencedPhotos.add(p.basename(r['photo_path'].toString()));
        }
        for (final r in notePhotos) {
          referencedPhotos.add(p.basename(r['photo_path'].toString()));
        }
        for (final r in itemPhotos) {
          referencedPhotos.add(p.basename(r['photo_path'].toString()));
        }
        for (final r in expensePhotos) {
          referencedPhotos.add(p.basename(r['receipt_photo_path'].toString()));
        }
      } catch (_) {}
    } finally {
      // Re-enable foreign key constraints & close
      await tempDb.execute('PRAGMA foreign_keys = ON');
      await tempDb.close();
    }

    // Determine secretKey before building and encrypting the database file
    String secretKey = '';

    // Get active key version (default to '1')
    final List<Map<String, dynamic>> activeKeyVerRow = await mainDb.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['active_key_version'],
    );
    final String activeKeyVersion = activeKeyVerRow.isNotEmpty
        ? activeKeyVerRow.first['value']?.toString() ?? '1'
        : '1';

    if (selectedModules.contains('entire_db')) {
      // Full backup: always sign with owner secret key!
      final List<Map<String, dynamic>> verKeyRow = await mainDb.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['owner_secret_v$activeKeyVersion'],
      );
      if (verKeyRow.isNotEmpty) {
        secretKey = verKeyRow.first['value']?.toString() ?? '';
      }
      if (secretKey.isEmpty) {
        secretKey = await SecurityHelper.getOrInitializeOwnerSecret();
        await mainDb.insert(
          'settings',
          {
            'key': 'owner_secret_v$activeKeyVersion',
            'value': secretKey,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } else if (workerId.isNotEmpty) {
      // Owner provisioning a worker: retrieve the worker's own secret key from worker_security table
      final List<Map<String, dynamic>> res = await mainDb.query(
        'worker_security',
        columns: ['worker_secret'],
        where: 'worker_id = ?',
        whereArgs: [workerId],
      );
      if (res.isNotEmpty) {
        secretKey = res.first['worker_secret']?.toString() ?? '';
      }
      if (secretKey.isEmpty) {
        secretKey = SecurityHelper.generateOwnerSecret();
        final nowStr = DateTime.now().toIso8601String();
        await mainDb.insert(
          'worker_security',
          {
            'worker_id': workerId,
            'worker_secret': secretKey,
            'created_at': nowStr,
            'updated_at': nowStr,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    // If not set yet and not a full backup, check if this device is a worker device (meaning we sign as a worker)
    if (secretKey.isEmpty && !selectedModules.contains('entire_db')) {
      final List<Map<String, dynamic>> localWorkers =
          await mainDb.query('workers', limit: 1);
      if (localWorkers.isNotEmpty) {
        final List<Map<String, dynamic>> resSec = await mainDb.query(
          'worker_security',
          columns: ['worker_secret'],
          where: 'worker_id = ?',
          whereArgs: [localWorkers.first['id']],
        );
        if (resSec.isNotEmpty) {
          secretKey = resSec.first['worker_secret']?.toString() ?? '';
        }
        if (secretKey.isEmpty) {
          secretKey = SecurityHelper.generateOwnerSecret();
          final nowStr = DateTime.now().toIso8601String();
          await mainDb.insert(
            'worker_security',
            {
              'worker_id': localWorkers.first['id'],
              'worker_secret': secretKey,
              'created_at': nowStr,
              'updated_at': nowStr,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }

    // Fallback: Sign with owner secret key (e.g. Owner exporting backup)
    if (secretKey.isEmpty) {
      // Try to get key specific to this version, e.g. 'owner_secret_v1'
      final List<Map<String, dynamic>> verKeyRow = await mainDb.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['owner_secret_v$activeKeyVersion'],
      );
      if (verKeyRow.isNotEmpty) {
        secretKey = verKeyRow.first['value']?.toString() ?? '';
      }
      if (secretKey.isEmpty) {
        secretKey = await SecurityHelper.getOrInitializeOwnerSecret();
        await mainDb.insert(
          'settings',
          {
            'key': 'owner_secret_v$activeKeyVersion',
            'value': secretKey,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    // Now build package folder structure
    final packageDir = Directory('${tempDir.path}/OrderKartPackage');
    if (packageDir.existsSync()) packageDir.deleteSync(recursive: true);
    packageDir.createSync();

    // Encrypt and write the DB file
    final destDbEnc = File('${packageDir.path}/database.enc');
    final dbBytes = await tempDbFile.readAsBytes();
    final encryptedDbBytes = SecurityHelper.encryptBytes(dbBytes, secretKey);
    await destDbEnc.writeAsBytes(encryptedDbBytes);

    // Create directories
    final photosDir = Directory('${packageDir.path}/photos')..createSync();
    final qrDir = Directory('${packageDir.path}/qr')..createSync();
    final logoDir = Directory('${packageDir.path}/logo')..createSync();

    // 1. Export photos if selected
    final isEntireDb = selectedModules.contains('entire_db');
    if (selectedModules.contains('photos') || isEntireDb) {
      final List<String> folders = [
        'customer_photos',
        'area_photos',
        'street_photos',
        'note_photos',
        'attachments',
        'item_photos',
        'expense_receipts'
      ];
      for (final folder in folders) {
        final srcPhotoDir = Directory('${AppConstants.appDocsDir}/$folder');
        if (srcPhotoDir.existsSync()) {
          final files = srcPhotoDir.listSync();
          for (final f in files) {
            if (f is File) {
              final filename = p.basename(f.path);
              if (isEntireDb || referencedPhotos.contains(filename)) {
                final targetDir = Directory('${photosDir.path}/$folder')
                  ..createSync(recursive: true);
                await f.copy('${targetDir.path}/$filename');
              }
            }
          }
        }
      }
    }

    // 2. Export business settings logo/qr
    if (selectedModules.contains('settings') || isEntireDb) {
      final srcLogo = File('${AppConstants.appDocsDir}/business_logo.png');
      if (srcLogo.existsSync()) {
        await srcLogo.copy('${logoDir.path}/logo.png');
      }
      final srcQr = File('${AppConstants.appDocsDir}/payment_qr.png');
      if (srcQr.existsSync()) {
        await srcQr.copy('${qrDir.path}/qr.png');
      }
    }

    // Calculate file hashes for manifest
    final fileHashes = <String, String>{};
    fileHashes['database.enc'] = await calculateFileHash(destDbEnc);

    final photoList = photosDir.listSync(recursive: true);
    for (final f in photoList) {
      if (f is File) {
        final relativePath =
            p.relative(f.path, from: packageDir.path).replaceAll('\\', '/');
        fileHashes[relativePath] = await calculateFileHash(f);
      }
    }

    final logoList = logoDir.listSync();
    for (final f in logoList) {
      if (f is File) {
        fileHashes['logo/${p.basename(f.path)}'] = await calculateFileHash(f);
      }
    }

    final qrList = qrDir.listSync();
    for (final f in qrList) {
      if (f is File) {
        fileHashes['qr/${p.basename(f.path)}'] = await calculateFileHash(f);
      }
    }

    // Construct manifest JSON metadata with versioning, expiry and device binding
    final packageId = const Uuid().v4();
    final manifest = <String, dynamic>{
      'package_id': packageId,
      'package_type':
          selectedModules.contains('entire_db') ? 'backup' : 'modular',
      'package_version': '1.0.0',
      'minimum_supported_version': '1.0.0',
      'current_version': '1.0.0',
      'db_version': AppConstants.dbVersion.toString(),
      'schema_version': '5',
      'export_version': '1',
      'selected_modules': selectedModules,
      'business_name': AppConstants.appName,
      'generated_by_worker_id': workerId,
      'generated_by_worker_name': workerName,
      'is_worker_provisioning_package': workerId.isNotEmpty,
      if (workerId.isNotEmpty)
        'worker_secret': SecurityHelper.obfuscateSecret(secretKey),
      // Embed owner_secret inline (obfuscated) for full backups so restore works after reinstall
      if (workerId.isEmpty && selectedModules.contains('entire_db'))
        'owner_secret': SecurityHelper.obfuscateSecret(secretKey),
      'device_name': Platform.localHostname,
      'platform': Platform.operatingSystem,
      'device_id': 'mock_device_id_${Platform.operatingSystem.hashCode.abs()}',
      'key_version': activeKeyVersion,
      'app_version': AppConstants.appVersion,
      'export_timestamp': DateTime.now().toIso8601String(),
      'expires_at':
          DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'revoked': false,
      'file_hashes': fileHashes,
    };

    final hmacSignature = SecurityHelper.signManifest(manifest, secretKey);
    manifest['signature'] = hmacSignature;

    final manifestFile = File('${packageDir.path}/manifest.json');
    await manifestFile.writeAsString(jsonEncode(manifest));

    // Calculate master signature hash (hash of manifest.json)
    final manifestHash = await calculateFileHash(manifestFile);
    final checksumFile = File('${packageDir.path}/checksum.sha256');
    await checksumFile.writeAsString(manifestHash);

    // Create the final zip archive containing the structured folders
    final zipFilename = customFileName ??
        (selectedModules.contains('entire_db')
            ? 'BusinessBackup.orderkart'
            : 'OrderKartPackage.zip');
    final zipFile = File('${tempDir.path}/$zipFilename');
    if (zipFile.existsSync()) zipFile.deleteSync();

    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);

    // Add all files recursively maintaining directories
    encoder.addFile(manifestFile, 'manifest.json');
    encoder.addFile(checksumFile, 'checksum.sha256');
    encoder.addFile(destDbEnc, 'database.enc');

    for (final f in photoList) {
      if (f is File) {
        final relativePath =
            p.relative(f.path, from: packageDir.path).replaceAll('\\', '/');
        encoder.addFile(f, relativePath);
      }
    }
    for (final f in logoList) {
      if (f is File) encoder.addFile(f, 'logo/${p.basename(f.path)}');
    }
    for (final f in qrList) {
      if (f is File) encoder.addFile(f, 'qr/${p.basename(f.path)}');
    }

    await encoder.close();

    // Verify package using PackageValidator before sharing
    final valRes = await PackageValidator.validatePackage(zipFile.path);
    if (!valRes.isValid) {
      throw Exception(
          'Post-export verification failed: ${valRes.errorMessage}');
    }

    // Log the Export in Export History table
    final targetDbMain = await DatabaseHelper.instance.database;
    await targetDbMain.insert('export_history', {
      'id': const Uuid().v4(),
      'package_id': packageId,
      'package_type':
          selectedModules.contains('entire_db') ? 'backup' : 'modular',
      'modules': selectedModules.join(','),
      'exported_at': DateTime.now().toIso8601String(),
      'destination': 'local_share',
      'record_count': selectedModules.length,
      'status': 'success',
    });

    // Cleanup temp dirs
    if (packageDir.existsSync()) packageDir.deleteSync(recursive: true);
    if (tempDbFile.existsSync()) tempDbFile.deleteSync();

    await Share.shareXFiles([XFile(zipFile.path)],
        subject: selectedModules.contains('entire_db')
            ? 'OrderKart Full Business Backup'
            : 'OrderKart Export Package');
  }
}
