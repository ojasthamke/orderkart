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
    required List<String> selectedModules, // 'entire_db', 'areas', 'streets', etc.
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
  }) async {
    final dbPath = await DatabaseHelper.instance.database.then((db) => db.path);
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) throw Exception('Database file not found');

    final tempDir = await getTemporaryDirectory();
    
    // Create a temporary copy of the database to prune
    final tempDbFile = File('${tempDir.path}/orderkart_export_temp.db');
    if (tempDbFile.existsSync()) tempDbFile.deleteSync();
    await dbFile.copy(tempDbFile.path);

    // Open the cloned database to perform pruning operations
    final tempDb = await openDatabase(tempDbFile.path);

    // Disable foreign key checks during pruning so we can clean table-by-table without constraint errors
    await tempDb.execute('PRAGMA foreign_keys = OFF');

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
          await tempDb.delete('worker_assignments');
          await tempDb.delete('worker_reports');
          await tempDb.delete('commission_history');
        }
        if (!selectedModules.contains('settings')) {
          await tempDb.delete('settings');
          await tempDb.delete('business_profile');
        }
      }

      // Helper to convert list of IDs into sql quote list
      String sqlInClause(List<String> ids) => ids.map((id) => "'$id'").join(',');

      // --- 2. Entity-Based Pruning ---
      if (selectedAreaIds != null && selectedAreaIds.isNotEmpty) {
        final list = sqlInClause(selectedAreaIds);
        await tempDb.delete('areas', where: 'id NOT IN ($list)');
        await tempDb.delete('streets', where: 'area_id NOT IN ($list)');
        await tempDb.delete('customers', where: 'street_id NOT IN (SELECT id FROM streets)');
        await tempDb.delete('orders', where: 'customer_id NOT IN (SELECT id FROM customers)');
      }

      if (selectedStreetIds != null && selectedStreetIds.isNotEmpty) {
        final list = sqlInClause(selectedStreetIds);
        await tempDb.delete('streets', where: 'id NOT IN ($list)');
        await tempDb.delete('customers', where: 'street_id NOT IN ($list)');
        await tempDb.delete('orders', where: 'customer_id NOT IN (SELECT id FROM customers)');
      }

      if (selectedCustomerIds != null && selectedCustomerIds.isNotEmpty) {
        final list = sqlInClause(selectedCustomerIds);
        await tempDb.delete('customers', where: 'id NOT IN ($list)');
        await tempDb.delete('orders', where: 'customer_id NOT IN ($list)');
      }

      if (selectedWorkerIds != null && selectedWorkerIds.isNotEmpty) {
        final list = sqlInClause(selectedWorkerIds);
        await tempDb.delete('workers', where: 'id NOT IN ($list)');
        await tempDb.delete('worker_assignments', where: 'worker_id NOT IN ($list)');
        await tempDb.delete('worker_reports', where: 'worker_id NOT IN ($list)');
        await tempDb.delete('commission_history', where: 'worker_id NOT IN ($list)');
        await tempDb.delete('orders', where: 'assigned_worker_id NOT IN ($list)');
        await tempDb.delete('customers', where: 'assigned_worker_id NOT IN ($list)');
      }

      if (selectedItemIds != null && selectedItemIds.isNotEmpty) {
        final list = sqlInClause(selectedItemIds);
        await tempDb.delete('items', where: 'id NOT IN ($list)');
        await tempDb.delete('item_price_history', where: 'item_id NOT IN ($list)');
      }

      if (selectedExpenseIds != null && selectedExpenseIds.isNotEmpty) {
        final list = sqlInClause(selectedExpenseIds);
        await tempDb.delete('expenses', where: 'id NOT IN ($list)');
      }

      if (selectedNoteIds != null && selectedNoteIds.isNotEmpty) {
        final list = sqlInClause(selectedNoteIds);
        await tempDb.delete('notes', where: 'id NOT IN ($list)');
      }

      // --- 3. Date Range Pruning ---
      if (startDate != null) {
        final startStr = startDate.toIso8601String();
        await tempDb.delete('orders', where: 'created_at < ?', whereArgs: [startStr]);
        await tempDb.delete('payments', where: 'created_at < ?', whereArgs: [startStr]);
        await tempDb.delete('expenses', where: 'date < ?', whereArgs: [startStr.substring(0, 10)]);
        await tempDb.delete('worker_reports', where: 'report_date < ?', whereArgs: [startStr.substring(0, 10)]);
      }

      if (endDate != null) {
        final endStr = endDate.toIso8601String();
        await tempDb.delete('orders', where: 'created_at > ?', whereArgs: [endStr]);
        await tempDb.delete('payments', where: 'created_at > ?', whereArgs: [endStr]);
        await tempDb.delete('expenses', where: 'date > ?', whereArgs: [endStr.substring(0, 10)]);
        await tempDb.delete('worker_reports', where: 'report_date > ?', whereArgs: [endStr.substring(0, 10)]);
      }

      // --- 4. Post-Filter Cascading Cleanup ---
      await tempDb.delete('order_items', where: 'order_id NOT IN (SELECT id FROM orders)');
      await tempDb.delete('payments', where: 'order_id NOT IN (SELECT id FROM orders)');

    } finally {
      // Re-enable foreign key constraints & close
      await tempDb.execute('PRAGMA foreign_keys = ON');
      await tempDb.close();
    }

    // Now build package folder structure
    final packageDir = Directory('${tempDir.path}/OrderKartPackage');
    if (packageDir.existsSync()) packageDir.deleteSync(recursive: true);
    packageDir.createSync();

    // Copy DB file
    final destDb = File('${packageDir.path}/database.db');
    await tempDbFile.copy(destDb.path);

    // Create directories
    final photosDir = Directory('${packageDir.path}/photos')..createSync();
    final qrDir = Directory('${packageDir.path}/qr')..createSync();
    final logoDir = Directory('${packageDir.path}/logo')..createSync();

    // 1. Export photos if selected
    final isEntireDb = selectedModules.contains('entire_db');
    if (selectedModules.contains('photos') || isEntireDb) {
      final srcPhotoDir = Directory('${AppConstants.appDocsDir}/customer_photos');
      if (srcPhotoDir.existsSync()) {
        final files = srcPhotoDir.listSync();
        for (final f in files) {
          if (f is File) {
            await f.copy('${photosDir.path}/${p.basename(f.path)}');
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
    fileHashes['database.db'] = await calculateFileHash(destDb);

    final photoList = photosDir.listSync();
    for (final f in photoList) {
      if (f is File) {
        fileHashes['photos/${p.basename(f.path)}'] = await calculateFileHash(f);
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

    // Construct manifest JSON metadata
    final packageId = const Uuid().v4();
    final manifest = {
      'package_id': packageId,
      'package_version': '1.0.0',
      'db_version': AppConstants.dbVersion.toString(),
      'schema_version': '4',
      'export_version': '1',
      'selected_modules': selectedModules,
      'business_name': AppConstants.appName,
      'generated_by_worker_id': workerId,
      'generated_by_worker_name': workerName,
      'is_worker_provisioning_package': workerId.isNotEmpty,
      'device_name': Platform.localHostname,
      'device_model': Platform.operatingSystem,
      'android_id': 'mock_android_id_${Platform.operatingSystem.hashCode.abs()}',
      'app_version': AppConstants.appVersion,
      'export_timestamp': DateTime.now().toIso8601String(),
      'file_hashes': fileHashes,
    };

    final manifestFile = File('${packageDir.path}/manifest.json');
    await manifestFile.writeAsString(jsonEncode(manifest));

    // Calculate master signature hash (hash of manifest.json)
    final manifestHash = await calculateFileHash(manifestFile);
    final checksumFile = File('${packageDir.path}/checksum.sha256');
    await checksumFile.writeAsString(manifestHash);

    // Create the final zip archive containing the structured folders
    final zipFile = File('${tempDir.path}/OrderKartPackage.zip');
    if (zipFile.existsSync()) zipFile.deleteSync();

    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);
    
    // Add all files recursively maintaining directories
    encoder.addFile(manifestFile, 'manifest.json');
    encoder.addFile(checksumFile, 'checksum.sha256');
    encoder.addFile(destDb, 'database.db');
    
    for (final f in photoList) {
      if (f is File) encoder.addFile(f, 'photos/${p.basename(f.path)}');
    }
    for (final f in logoList) {
      if (f is File) encoder.addFile(f, 'logo/${p.basename(f.path)}');
    }
    for (final f in qrList) {
      if (f is File) encoder.addFile(f, 'qr/${p.basename(f.path)}');
    }

    await encoder.close();

    // Log the Export in Export History table
    final targetDbMain = await DatabaseHelper.instance.database;
    await targetDbMain.insert('export_history', {
      'id': const Uuid().v4(),
      'package_id': packageId,
      'package_type': selectedModules.contains('entire_db') ? 'full' : 'modular',
      'modules': selectedModules.join(','),
      'exported_at': DateTime.now().toIso8601String(),
      'destination': 'local_share',
      'record_count': selectedModules.length,
      'status': 'success',
    });

    // Cleanup temp dirs
    if (packageDir.existsSync()) packageDir.deleteSync(recursive: true);
    if (tempDbFile.existsSync()) tempDbFile.deleteSync();

    await Share.shareXFiles([XFile(zipFile.path)], subject: 'OrderKart Export Package');
  }
}
