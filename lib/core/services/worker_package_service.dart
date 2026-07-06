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
import '../services/worker_permission_service.dart';
import '../utils/security_helper.dart';
import '../../features/worker/data/worker_dao.dart';

class WorkerPackageService {
  WorkerPackageService._();

  static Future<String> _calculateFileHash(File file) async {
    if (!file.existsSync()) return '';
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  /// 1. GENERATE WORKER PROVISIONING PACKAGE (WorkerPackage.orderkart)
  static Future<void> generateWorkerProvisioningPackage({
    required String workerId,
    required String workerName,
  }) async {
    final mainDb = await DatabaseHelper.instance.database;

    // Get active key version (default to '1')
    final List<Map<String, dynamic>> activeKeyVerRow = await mainDb.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['active_key_version'],
    );
    final String activeKeyVersion = activeKeyVerRow.isNotEmpty
        ? activeKeyVerRow.first['value']?.toString() ?? '1'
        : '1';

    // Retrieve the worker's own secret key from worker_security table (or initialize JIT)
    final List<Map<String, dynamic>> secRes = await mainDb.query(
      'worker_security',
      columns: ['worker_secret'],
      where: 'worker_id = ?',
      whereArgs: [workerId],
    );
    String secretKey = '';
    if (secRes.isNotEmpty) {
      secretKey = secRes.first['worker_secret']?.toString() ?? '';
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

    // Create temporary workspace directory
    final tempDir = await getTemporaryDirectory();
    final packageDir = Directory('${tempDir.path}/OrderKartWorkerProvisioning');
    if (packageDir.existsSync()) packageDir.deleteSync(recursive: true);
    packageDir.createSync();

    // Query Data Scoped to the Worker
    final workerRow = await mainDb.query('workers', where: 'id = ?', whereArgs: [workerId]);
    await WorkerPermissionService.getPermissionsForWorker(workerId);
    final permissionsRow = await mainDb.query('worker_permissions', where: 'worker_id = ?', whereArgs: [workerId]);
    final assignmentsRows = await mainDb.query('worker_assignments', where: 'worker_id = ?', whereArgs: [workerId]);

    final List<String> assignedAreaIds = assignmentsRows
        .where((e) => e['entity_type'] == 'area')
        .map((e) => e['entity_id']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    final List<Map<String, dynamic>> areasRows = assignedAreaIds.isEmpty 
        ? [] 
        : await mainDb.query('areas', where: 'id IN (${assignedAreaIds.map((e) => "'$e'").join(',')})');
    
    final List<Map<String, dynamic>> streetsRows = assignedAreaIds.isEmpty 
        ? [] 
        : await mainDb.query('streets', where: 'area_id IN (${assignedAreaIds.map((e) => "'$e'").join(',')})');

    final List<String> assignedStreetIds = streetsRows.map((e) => e['id']?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    final List<Map<String, dynamic>> customersRows = assignedStreetIds.isEmpty
        ? []
        : await mainDb.query('customers', where: 'street_id IN (${assignedStreetIds.map((e) => "'$e'").join(',')})');

    final itemsRows = await mainDb.query('items');
    final priceListRows = await mainDb.query('item_price_history');
    final businessProfileRow = await mainDb.query('business_profile');
    
    // Filter settings: avoid owner_secret
    final allSettings = await mainDb.query('settings');
    final settingsRows = allSettings.where((row) => row['key'] != AppConstants.keyOwnerSecret).toList();

    // Serialize and Encrypt JSON files helper
    Future<void> writeEncryptedJson(String filename, dynamic data) async {
      final jsonStr = jsonEncode(data);
      final encryptedBytes = SecurityHelper.encryptBytes(utf8.encode(jsonStr), secretKey);
      final file = File('${packageDir.path}/$filename');
      await file.writeAsBytes(encryptedBytes);
    }

    await writeEncryptedJson('worker.json', workerRow);
    await writeEncryptedJson('permissions.json', permissionsRow);
    await writeEncryptedJson('assignments.json', assignmentsRows);
    await writeEncryptedJson('areas.json', areasRows);
    await writeEncryptedJson('streets.json', streetsRows);
    await writeEncryptedJson('customers.json', customersRows);
    await writeEncryptedJson('inventory.json', itemsRows);
    await writeEncryptedJson('worker.json', workerRow);
    await writeEncryptedJson('permissions.json', permissionsRow);
    await writeEncryptedJson('assignments.json', assignmentsRows);
    await writeEncryptedJson('areas.json', areasRows);
    await writeEncryptedJson('streets.json', streetsRows);
    await writeEncryptedJson('customers.json', customersRows);
    await writeEncryptedJson('inventory.json', itemsRows);
    await writeEncryptedJson('price_list.json', priceListRows);
    await writeEncryptedJson('business_profile.json', businessProfileRow);
    await writeEncryptedJson('settings.json', settingsRows);

    // Create database.db for direct SQLite importers
    final dbFile = File('${packageDir.path}/database.db');
    if (dbFile.existsSync()) dbFile.deleteSync();
    final scopedDb = await openDatabase(dbFile.path);
    await DatabaseHelper.instance.createSchema(scopedDb);
    await scopedDb.execute('PRAGMA foreign_keys = OFF');

    try {
      for (final r in workerRow) { await scopedDb.insert('workers', r, conflictAlgorithm: ConflictAlgorithm.replace); }
      for (final r in permissionsRow) { await scopedDb.insert('worker_permissions', r, conflictAlgorithm: ConflictAlgorithm.replace); }
      for (final r in assignmentsRows) { await scopedDb.insert('worker_assignments', r, conflictAlgorithm: ConflictAlgorithm.replace); }
      for (final r in areasRows) { await scopedDb.insert('areas', r, conflictAlgorithm: ConflictAlgorithm.replace); }
      for (final r in streetsRows) { await scopedDb.insert('streets', r, conflictAlgorithm: ConflictAlgorithm.replace); }
      for (final r in customersRows) { await scopedDb.insert('customers', r, conflictAlgorithm: ConflictAlgorithm.replace); }
      for (final r in itemsRows) { await scopedDb.insert('items', r, conflictAlgorithm: ConflictAlgorithm.replace); }
      for (final r in priceListRows) { await scopedDb.insert('item_price_history', r, conflictAlgorithm: ConflictAlgorithm.replace); }
      for (final r in businessProfileRow) { await scopedDb.insert('business_profile', r, conflictAlgorithm: ConflictAlgorithm.replace); }
      for (final r in settingsRows) { await scopedDb.insert('settings', r, conflictAlgorithm: ConflictAlgorithm.replace); }
    } finally {
      await scopedDb.close();
    }

    // Export customer photos for only assigned customers
    final photosDir = Directory('${packageDir.path}/photos')..createSync();
    final Set<String> assignedPhotoNames = customersRows
        .map((e) => e['photo_path']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .map((e) => p.basename(e))
        .toSet();

    final srcPhotoDir = Directory('${AppConstants.appDocsDir}/customer_photos');
    if (srcPhotoDir.existsSync()) {
      final files = srcPhotoDir.listSync();
      for (final f in files) {
        if (f is File) {
          final filename = p.basename(f.path);
          if (assignedPhotoNames.contains(filename)) {
            await f.copy('${photosDir.path}/$filename');
          }
        }
      }
    }

    // Export Business logo/qr
    final logoDir = Directory('${packageDir.path}/logo')..createSync();
    final srcLogo = File('${AppConstants.appDocsDir}/business_logo.png');
    if (srcLogo.existsSync()) {
      await srcLogo.copy('${logoDir.path}/logo.png');
    }
    final qrDir = Directory('${packageDir.path}/qr')..createSync();
    final srcQr = File('${AppConstants.appDocsDir}/payment_qr.png');
    if (srcQr.existsSync()) {
      await srcQr.copy('${qrDir.path}/qr.png');
    }

    // Calculate file hashes
    final fileHashes = <String, String>{};
    final List<String> jsonFiles = [
      'worker.json', 'permissions.json', 'assignments.json', 'areas.json', 'streets.json',
      'customers.json', 'inventory.json', 'price_list.json', 'business_profile.json', 'settings.json', 'database.db'
    ];
    for (final f in jsonFiles) {
      fileHashes[f] = await _calculateFileHash(File('${packageDir.path}/$f'));
    }

    final photoList = photosDir.listSync();
    for (final f in photoList) {
      if (f is File) {
        fileHashes['photos/${p.basename(f.path)}'] = await _calculateFileHash(f);
      }
    }
    if (File('${logoDir.path}/logo.png').existsSync()) {
      fileHashes['logo/logo.png'] = await _calculateFileHash(File('${logoDir.path}/logo.png'));
    }
    if (File('${qrDir.path}/qr.png').existsSync()) {
      fileHashes['qr/qr.png'] = await _calculateFileHash(File('${qrDir.path}/qr.png'));
    }

    // Generate manifest.json
    final packageId = const Uuid().v4();
    final manifest = <String, dynamic>{
      'package_id': packageId,
      'package_type': 'provisioning',
      'package_version': '1.0.0',
      'minimum_supported_version': '1.0.0',
      'current_version': '1.0.0',
      'db_version': AppConstants.dbVersion.toString(),
      'schema_version': '4',
      'export_version': '1',
      'business_name': AppConstants.appName,
      'generated_by_worker_id': workerId,
      'generated_by_worker_name': workerName,
      'is_worker_provisioning_package': true,
      'worker_secret': secretKey,
      'device_name': Platform.localHostname,
      'platform': Platform.operatingSystem,
      'device_id': 'mock_device_id_${Platform.operatingSystem.hashCode.abs()}',
      'key_version': activeKeyVersion,
      'app_version': AppConstants.appVersion,
      'export_timestamp': DateTime.now().toIso8601String(),
      'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'revoked': false,
      'file_hashes': fileHashes,
    };

    final hmacSignature = SecurityHelper.signManifest(manifest, secretKey);
    manifest['signature'] = hmacSignature;

    final manifestFile = File('${packageDir.path}/manifest.json');
    await manifestFile.writeAsString(jsonEncode(manifest));

    // Checksum file
    final manifestHash = await _calculateFileHash(manifestFile);
    final checksumFile = File('${packageDir.path}/checksum.sha256');
    await checksumFile.writeAsString(manifestHash);

    // Create ZIP package
    final zipFile = File('${tempDir.path}/WorkerPackage.orderkart');
    if (zipFile.existsSync()) zipFile.deleteSync();

    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);
    encoder.addFile(manifestFile, 'manifest.json');
    encoder.addFile(checksumFile, 'checksum.sha256');
    for (final f in jsonFiles) {
      encoder.addFile(File('${packageDir.path}/$f'), f);
    }
    for (final f in photoList) {
      if (f is File) encoder.addFile(f, 'photos/${p.basename(f.path)}');
    }
    if (File('${logoDir.path}/logo.png').existsSync()) {
      encoder.addFile(File('${logoDir.path}/logo.png'), 'logo/logo.png');
    }
    if (File('${qrDir.path}/qr.png').existsSync()) {
      encoder.addFile(File('${qrDir.path}/qr.png'), 'qr/qr.png');
    }
    await encoder.close();

    // Log the Export in Export History table
    await mainDb.insert('export_history', {
      'id': const Uuid().v4(),
      'package_id': packageId,
      'package_type': 'provisioning',
      'modules': 'workers,settings,areas,streets,customers,items',
      'exported_at': DateTime.now().toIso8601String(),
      'destination': 'local_share',
      'record_count': jsonFiles.length,
      'status': 'success',
    });

    // Mark package generated in workers table!
    try {
      final workerDao = WorkerDao();
      await workerDao.markPackageGenerated(workerId);
    } catch (_) {}

    // Cleanup temp files
    if (packageDir.existsSync()) packageDir.deleteSync(recursive: true);

    await Share.shareXFiles([XFile(zipFile.path)], subject: 'OrderKart Worker Provisioning Package');
  }

  /// 2. GENERATE WORKER REPORT PACKAGE (WorkerReport.orderkart)
  static Future<void> generateWorkerReportPackage({
    required String workerId,
    required String workerName,
    String? customFileName,
    bool isIncremental = false,
  }) async {
    // Verify Worker Export Permission
    if (workerId.isNotEmpty) {
      final allowed = await WorkerPermissionService.hasPermission(workerId, 'export_data', requiredLevel: 1);
      if (!allowed) {
        throw Exception('Data export is disabled by the Owner for this worker profile.');
      }
    }

    final mainDb = await DatabaseHelper.instance.database;

    // Get active key version (default to '1')
    final List<Map<String, dynamic>> activeKeyVerRow = await mainDb.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['active_key_version'],
    );
    final String activeKeyVersion = activeKeyVerRow.isNotEmpty
        ? activeKeyVerRow.first['value']?.toString() ?? '1'
        : '1';

    // Retrieve worker credentials
    final List<Map<String, dynamic>> secRes = await mainDb.query(
      'worker_security',
      columns: ['worker_secret'],
      where: 'worker_id = ?',
      whereArgs: [workerId],
    );

    String secretKey = '';
    if (secRes.isNotEmpty) {
      secretKey = secRes.first['worker_secret']?.toString() ?? '';
    }
    if (secretKey.isEmpty) {
      secretKey = SecurityHelper.generateOwnerSecret();
      await mainDb.insert(
        'worker_security',
        {
          'worker_id': workerId,
          'worker_secret': secretKey,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Check last sync timestamp for incremental export
    String lastSyncTime = '';
    if (isIncremental) {
      final syncRow = await mainDb.query('settings', where: 'key = ?', whereArgs: ['last_owner_sync_timestamp']);
      if (syncRow.isNotEmpty) {
        lastSyncTime = syncRow.first['value']?.toString() ?? '';
      }
    }

    // Create temporary workspace directory
    final tempDir = await getTemporaryDirectory();
    final packageDir = Directory('${tempDir.path}/OrderKartWorkerReport');
    if (packageDir.existsSync()) packageDir.deleteSync(recursive: true);
    packageDir.createSync();

    // Query Data Scoped to the Worker's field edits
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

    // Create scoped SQLite database file for direct DB import compatibility
    final scopedDbFile = File('${packageDir.path}/database.db');
    if (scopedDbFile.existsSync()) scopedDbFile.deleteSync();
    final scopedDb = await openDatabase(scopedDbFile.path, version: AppConstants.dbVersion, onCreate: (db, v) async {
      await DatabaseHelper.instance.createTablesForDatabase(db);
    });

    for (final r in customersRows) { await scopedDb.insert('customers', r, conflictAlgorithm: ConflictAlgorithm.replace); }
    for (final r in ordersRows) { await scopedDb.insert('orders', r, conflictAlgorithm: ConflictAlgorithm.replace); }
    for (final r in orderItemsRows) { await scopedDb.insert('order_items', r, conflictAlgorithm: ConflictAlgorithm.replace); }
    for (final r in paymentsRows) { await scopedDb.insert('payments', r, conflictAlgorithm: ConflictAlgorithm.replace); }
    for (final r in expensesRows) { await scopedDb.insert('expenses', r, conflictAlgorithm: ConflictAlgorithm.replace); }
    for (final r in notesRows) { await scopedDb.insert('notes', r, conflictAlgorithm: ConflictAlgorithm.replace); }
    for (final r in visitsRows) { await scopedDb.insert('visits', r, conflictAlgorithm: ConflictAlgorithm.replace); }
    for (final r in workerReportsRows) { await scopedDb.insert('worker_reports', r, conflictAlgorithm: ConflictAlgorithm.replace); }
    await scopedDb.close();

    // Serialize and Encrypt JSON files helper
    Future<void> writeEncryptedJson(String filename, dynamic data) async {
      final jsonStr = jsonEncode(data);
      final encryptedBytes = SecurityHelper.encryptBytes(utf8.encode(jsonStr), secretKey);
      final file = File('${packageDir.path}/$filename');
      await file.writeAsBytes(encryptedBytes);
    }

    await writeEncryptedJson('customers.json', customersRows);
    await writeEncryptedJson('orders.json', ordersRows);
    await writeEncryptedJson('order_items.json', orderItemsRows);
    await writeEncryptedJson('payments.json', paymentsRows);
    await writeEncryptedJson('expenses.json', expensesRows);
    await writeEncryptedJson('notes.json', notesRows);
    await writeEncryptedJson('visits.json', visitsRows);
    await writeEncryptedJson('worker_reports.json', workerReportsRows);

    // Export customer photos for only these customers
    final photosDir = Directory('${packageDir.path}/photos')..createSync();
    final Set<String> assignedPhotoNames = customersRows
        .map((e) => e['photo_path']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .map((e) => p.basename(e))
        .toSet();

    final srcPhotoDir = Directory('${AppConstants.appDocsDir}/customer_photos');
    if (srcPhotoDir.existsSync()) {
      final files = srcPhotoDir.listSync();
      for (final f in files) {
        if (f is File) {
          final filename = p.basename(f.path);
          if (assignedPhotoNames.contains(filename)) {
            await f.copy('${photosDir.path}/$filename');
          }
        }
      }
    }

    // Calculate file hashes
    final fileHashes = <String, String>{};
    final List<String> jsonFiles = [
      'database.db', 'customers.json', 'orders.json', 'order_items.json', 'payments.json', 'expenses.json',
      'notes.json', 'visits.json', 'worker_reports.json'
    ];
    for (final f in jsonFiles) {
      fileHashes[f] = await _calculateFileHash(File('${packageDir.path}/$f'));
    }

    final photoList = photosDir.listSync();
    for (final f in photoList) {
      if (f is File) {
        fileHashes['photos/${p.basename(f.path)}'] = await _calculateFileHash(f);
      }
    }

    // Generate manifest.json
    final packageId = const Uuid().v4();
    final manifest = <String, dynamic>{
      'package_id': packageId,
      'package_type': 'report',
      'package_version': '1.0.0',
      'minimum_supported_version': '1.0.0',
      'current_version': '1.0.0',
      'db_version': AppConstants.dbVersion.toString(),
      'schema_version': '4',
      'export_version': '1',
      'business_name': AppConstants.appName,
      'generated_by_worker_id': workerId,
      'generated_by_worker_name': workerName,
      'is_worker_provisioning_package': false,
      'worker_secret': secretKey,
      'device_name': Platform.localHostname,
      'platform': Platform.operatingSystem,
      'device_id': 'mock_device_id_${Platform.operatingSystem.hashCode.abs()}',
      'key_version': activeKeyVersion,
      'app_version': AppConstants.appVersion,
      'export_timestamp': DateTime.now().toIso8601String(),
      'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'revoked': false,
      'file_hashes': fileHashes,
    };

    final hmacSignature = SecurityHelper.signManifest(manifest, secretKey);
    manifest['signature'] = hmacSignature;

    final manifestFile = File('${packageDir.path}/manifest.json');
    await manifestFile.writeAsString(jsonEncode(manifest));

    // Checksum file
    final manifestHash = await _calculateFileHash(manifestFile);
    final checksumFile = File('${packageDir.path}/checksum.sha256');
    await checksumFile.writeAsString(manifestHash);

    // Create ZIP package with custom filename
    final fileNameToUse = customFileName ?? 'WorkerReport.orderkart';
    final zipFile = File('${tempDir.path}/$fileNameToUse');
    if (zipFile.existsSync()) zipFile.deleteSync();

    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);
    encoder.addFile(manifestFile, 'manifest.json');
    encoder.addFile(checksumFile, 'checksum.sha256');
    encoder.addFile(scopedDbFile, 'database.db');
    for (final f in jsonFiles) {
      final file = File('${packageDir.path}/$f');
      if (file.existsSync()) encoder.addFile(file, f);
    }
    for (final f in photoList) {
      if (f is File) encoder.addFile(f, 'photos/${p.basename(f.path)}');
    }
    await encoder.close();

    // Log the Export in Export History table
    await mainDb.insert('export_history', {
      'id': const Uuid().v4(),
      'package_id': packageId,
      'package_type': 'report',
      'modules': 'customers,orders,order_items,payments,expenses,notes,visits',
      'exported_at': DateTime.now().toIso8601String(),
      'destination': 'local_share',
      'record_count': jsonFiles.length,
      'status': 'success',
    });

    // Update last sync timestamp if incremental
    if (isIncremental) {
      await mainDb.insert('settings', {
        'key': 'last_owner_sync_timestamp',
        'value': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Cleanup temp files
    if (packageDir.existsSync()) packageDir.deleteSync(recursive: true);

    await Share.shareXFiles([XFile(zipFile.path)], subject: 'OrderKart Worker Report Package');
  }
}
