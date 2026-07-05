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
    await writeEncryptedJson('price_list.json', priceListRows);
    await writeEncryptedJson('business_profile.json', businessProfileRow);
    await writeEncryptedJson('settings.json', settingsRows);

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
      'customers.json', 'inventory.json', 'price_list.json', 'business_profile.json', 'settings.json'
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

    // Retrieve worker credentials
    final List<Map<String, dynamic>> secRes = await mainDb.query(
      'worker_security',
      columns: ['worker_secret'],
      where: 'worker_id = ?',
      whereArgs: [workerId],
    );
    if (secRes.isEmpty) {
      throw Exception('Worker credentials not found.');
    }
    final String secretKey = secRes.first['worker_secret']?.toString() ?? '';

    // Create temporary workspace directory
    final tempDir = await getTemporaryDirectory();
    final packageDir = Directory('${tempDir.path}/OrderKartWorkerReport');
    if (packageDir.existsSync()) packageDir.deleteSync(recursive: true);
    packageDir.createSync();

    // Query Data Scoped to the Worker's field edits
    final customersRows = await mainDb.query('customers');
    final ordersRows = await mainDb.query('orders');
    
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
      'customers.json', 'orders.json', 'order_items.json', 'payments.json', 'expenses.json',
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
    final zipFile = File('${tempDir.path}/WorkerReport.orderkart');
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

    // Cleanup temp files
    if (packageDir.existsSync()) packageDir.deleteSync(recursive: true);

    await Share.shareXFiles([XFile(zipFile.path)], subject: 'OrderKart Worker Report Package');
  }
}
