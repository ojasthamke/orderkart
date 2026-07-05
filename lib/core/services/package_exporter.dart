import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';
import '../database/database_helper.dart';

class PackageExporter {
  PackageExporter._();

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
      // Ensure order_items and payments match existing orders remaining in db
      await tempDb.delete('order_items', where: 'order_id NOT IN (SELECT id FROM orders)');
      await tempDb.delete('payments', where: 'order_id NOT IN (SELECT id FROM orders)');

    } finally {
      // Re-enable foreign key constraints & close
      await tempDb.execute('PRAGMA foreign_keys = ON');
      await tempDb.close();
    }

    // Now construct zip archive from the filtered temporary database
    final zipFile = File('${tempDir.path}/orderkart_modular_package.zip');
    if (zipFile.existsSync()) zipFile.deleteSync();

    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);

    // 1. Add Filtered DB File
    encoder.addFile(tempDbFile, 'orderkart.db');

    // 2. Add Manifest JSON
    final manifest = {
      'package_type': selectedModules.contains('entire_db') ? 'full' : 'modular',
      'selected_modules': selectedModules,
      'business_name': AppConstants.appName,
      'worker_id': workerId,
      'worker_name': workerName,
      'device_name': Platform.operatingSystem,
      'app_version': AppConstants.appVersion,
      'db_version': AppConstants.dbVersion,
      'export_timestamp': DateTime.now().toIso8601String(),
    };

    final manifestFile = File('${tempDir.path}/manifest.json');
    await manifestFile.writeAsString(jsonEncode(manifest));
    encoder.addFile(manifestFile, 'manifest.json');

    // 3. Add customer photos if selected & directory exists
    if (selectedModules.contains('photos') || isEntireDb) {
      final photoDir = Directory('${AppConstants.appDocsDir}/customer_photos');
      if (photoDir.existsSync()) {
        final files = photoDir.listSync();
        for (final f in files) {
          if (f is File) {
            encoder.addFile(f, 'customer_photos/${p.basename(f.path)}');
          }
        }
      }
    }

    await encoder.close();
    
    // Cleanup manifest and temporary db from disk
    if (manifestFile.existsSync()) manifestFile.deleteSync();
    if (tempDbFile.existsSync()) tempDbFile.deleteSync();

    await Share.shareXFiles([XFile(zipFile.path)], subject: 'OrderKart Export Package');
  }
}
