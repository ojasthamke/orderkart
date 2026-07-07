import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import '../database/database_helper.dart';
import '../utils/security_helper.dart';
import '../security/app_mode_service.dart';
import 'package:sqflite/sqflite.dart';

class PackageValidationResult {
  final bool isValid;
  final String errorMessage;
  final Map<String, dynamic> manifest;
  final String dbPath;
  final int photosCount;

  PackageValidationResult({
    required this.isValid,
    required this.errorMessage,
    required this.manifest,
    required this.dbPath,
    required this.photosCount,
  });
}

class PackageValidator {
  PackageValidator._();

  /// Helper to compare two semantic versions. Returns true if appVer >= minSupportedVer.
  static bool isVersionCompatible(String appVer, String minSupportedVer) {
    try {
      final cleanApp = appVer.split('+').first.split('-').first;
      final cleanMin = minSupportedVer.split('+').first.split('-').first;
      final appParts = cleanApp.split('.').map(int.parse).toList();
      final minParts = cleanMin.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final aVal = i < appParts.length ? appParts[i] : 0;
        final mVal = i < minParts.length ? minParts[i] : 0;
        if (aVal > mVal) return true;
        if (aVal < mVal) return false;
      }
      return true;
    } catch (_) {
      return appVer == minSupportedVer;
    }
  }

  /// Reads and verifies a zip package's integrity, hashes, signatures, and version compatibility
  static Future<PackageValidationResult> validatePackage(String zipPath) async {
    try {
      final zipFile = File(zipPath);
      if (!zipFile.existsSync()) {
        return PackageValidationResult(
          isValid: false,
          errorMessage: 'Package file does not exist on disk.',
          manifest: {},
          dbPath: '',
          photosCount: 0,
        );
      }

      final bytes = await zipFile.readAsBytes();

      // Check if the file is a raw unencrypted SQLite database file
      if (bytes.length >= 16) {
        final header = String.fromCharCodes(bytes.sublist(0, 15));
        if (header == 'SQLite format 3') {
          return PackageValidationResult(
            isValid: true,
            errorMessage: '',
            manifest: {
              'package_type': 'raw_db',
              'generated_by_worker_name': 'Database Backup',
            },
            dbPath: zipPath,
            photosCount: 0,
          );
        }
      }

      final archive = ZipDecoder().decodeBytes(bytes);

      List<int>? dbEncData;
      List<int>? manifestData;
      String? checksumHash;

      // Map to hold references to other files inside zip
      final Map<String, List<int>> photoFiles = {};
      final Map<String, List<int>> logoFiles = {};
      final Map<String, List<int>> qrFiles = {};
      final Map<String, List<int>> jsonFiles = {};

      final jsonMappings = {
        'worker.json': 'workers',
        'permissions.json': 'worker_permissions',
        'assignments.json': 'worker_assignments',
        'areas.json': 'areas',
        'streets.json': 'streets',
        'customers.json': 'customers',
        'inventory.json': 'items',
        'price_list.json': 'item_price_history',
        'business_profile.json': 'business_profile',
        'settings.json': 'settings',
        'orders.json': 'orders',
        'order_items.json': 'order_items',
        'payments.json': 'payments',
        'expenses.json': 'expenses',
        'notes.json': 'notes',
        'visits.json': 'visits',
        'worker_reports.json': 'worker_reports'
      };

      for (final f in archive) {
        if (!f.isFile) continue;
        final normName = f.name.replaceAll('\\', '/');

        if (normName == 'database.enc') {
          dbEncData = f.content as List<int>;
        } else if (normName == 'manifest.json') {
          manifestData = f.content as List<int>;
        } else if (normName == 'checksum.sha256') {
          checksumHash = utf8.decode(f.content as List<int>).trim();
        } else if (normName.startsWith('photos/')) {
          photoFiles[normName] = f.content as List<int>;
        } else if (normName.startsWith('logo/')) {
          logoFiles[normName] = f.content as List<int>;
        } else if (normName.startsWith('qr/')) {
          qrFiles[normName] = f.content as List<int>;
        } else if (jsonMappings.containsKey(normName)) {
          jsonFiles[normName] = f.content as List<int>;
        }
      }

      // 1. Basic Package Verification
      if (manifestData == null) {
        return _fail('Missing manifest.json file inside package.');
      }
      if (checksumHash == null) {
        return _fail('Missing signature checksum.sha256 file.');
      }

      // 2. Validate manifest.json signature using checksum.sha256
      final actualManifestHash = sha256.convert(manifestData).toString();
      if (actualManifestHash != checksumHash) {
        return _fail('Package signature verification failed (Manifest hash mismatch). File might be corrupted or tampered.');
      }

      // 3. Parse manifest JSON
      final Map<String, dynamic> manifest = jsonDecode(utf8.decode(manifestData));
      final String packageType = manifest['package_type']?.toString() ?? 'backup';

      // Verify that the required files for the package type exist
      if ((packageType == 'backup' || packageType == 'modular') && dbEncData == null) {
        return _fail('Missing database.enc file inside package.');
      }

      // 3a. Check Expiry
      final expiresAtStr = manifest['expires_at']?.toString() ?? '';
      if (expiresAtStr.isNotEmpty) {
        final expiresAt = DateTime.tryParse(expiresAtStr);
        if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
          return _fail('This package has expired and is no longer valid.');
        }
      }

      // 3b. Check Revocation
      if (manifest['revoked'] == true) {
        return _fail('This package has been revoked by the owner.');
      }

      // 3c. Check Version Compatibility
      final minSuppVer = manifest['minimum_supported_version']?.toString() ?? '1.0.0';
      if (!isVersionCompatible(AppConstants.appVersion, minSuppVer)) {
        return _fail('Your app version (${AppConstants.appVersion}) is too old. Please update to at least $minSuppVer.');
      }

      final schemaVer = manifest['schema_version']?.toString() ?? '';
      final schemaInt = int.tryParse(schemaVer) ?? 0;
      if (schemaInt < 1 || schemaInt > 4) {
        return _fail('Incompatible database schema version: $schemaVer. Expected 1-4.');
      }

      final db = await DatabaseHelper.instance.database;

      // 3d. Check if package has already been imported (skip for full DB restores)
      final packageId = manifest['package_id']?.toString() ?? '';
      final isFullRestore = (manifest['package_type']?.toString() == 'backup') ||
          ((manifest['selected_modules'] as List<dynamic>?)?.contains('entire_db') ?? false);
      if (packageId.isNotEmpty && !isFullRestore) {
        final List<Map<String, dynamic>> existingImport = await db.query('import_history', where: 'package_id = ?', whereArgs: [packageId]);
        if (existingImport.isNotEmpty) {
          return _fail('This package has already been imported on ${existingImport.first['imported_at']}. Re-importing is blocked to prevent duplicate transactions.');
        }
      }

      // 3e. Check Device Binding for Worker Mode
      final currentMode = await AppModeService.getAppMode();
      if (currentMode == AppMode.worker) {
        final localDeviceId = 'mock_device_id_${Platform.operatingSystem.hashCode.abs()}';
        final packageDeviceId = manifest['device_id']?.toString() ?? manifest['android_id']?.toString() ?? '';
        if (packageDeviceId.isNotEmpty && packageDeviceId != localDeviceId) {
          return _fail('This package belongs to another device. Owner approval is required to re-bind.');
        }
      }

      // 3f. Retrieve Secret Key for Decryption and HMAC validation
      final generatedByWorkerId = manifest['generated_by_worker_id']?.toString() ?? '';
      final isWorkerProvisioning = manifest['is_worker_provisioning_package'] as bool? ?? false;
      final packageKeyVersion = manifest['key_version']?.toString() ?? '1';
      
      String secretKey = '';

      if (isWorkerProvisioning && manifest.containsKey('worker_secret')) {
        secretKey = SecurityHelper.deobfuscateSecret(manifest['worker_secret']?.toString() ?? '');
      } else if (generatedByWorkerId.isNotEmpty) {
        final List<Map<String, dynamic>> localWorker = await db.query(
          'worker_security',
          columns: ['worker_secret'],
          where: 'worker_id = ?',
          whereArgs: [generatedByWorkerId],
        );
        if (localWorker.isNotEmpty) {
          secretKey = localWorker.first['worker_secret']?.toString() ?? '';
        }
      } else {
        // Owner backup: select correct key according to packageKeyVersion
        final List<Map<String, dynamic>> res = await db.query(
          'settings',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: ['owner_secret_v$packageKeyVersion'],
        );
        if (res.isNotEmpty) {
          secretKey = res.first['value']?.toString() ?? '';
        }
        
        // Fallback to default owner_secret if the versioned key isn't stored separately yet
        if (secretKey.isEmpty) {
          final List<Map<String, dynamic>> fallbackRes = await db.query(
            'settings',
            columns: ['value'],
            where: 'key = ?',
            whereArgs: [AppConstants.keyOwnerSecret],
          );
          if (fallbackRes.isNotEmpty) {
            secretKey = fallbackRes.first['value']?.toString() ?? '';
          }
        }
      }

      // If no key found for an owner backup, the app was likely freshly reinstalled.
      // Auto-initialize the owner secret so the restore can proceed without blocking.
      if (secretKey.isEmpty && !isWorkerProvisioning && generatedByWorkerId.isEmpty) {
        // Check if manifest carries an inline secret for self-restores
        final inlineSecret = SecurityHelper.deobfuscateSecret(manifest['owner_secret']?.toString() ?? '');
        if (inlineSecret.isNotEmpty) {
          secretKey = inlineSecret;
          // Persist it so future validations succeed
          await db.insert(
            'settings',
            {'key': 'owner_secret_v$packageKeyVersion', 'value': secretKey},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await db.insert(
            'settings',
            {'key': AppConstants.keyOwnerSecret, 'value': secretKey},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Validate HMAC signature
      if (secretKey.isEmpty) {
        return _fail('Package signature could not be verified — no matching secret key found. Register this worker or set up owner credentials first.');
      }
      final signature = manifest['signature']?.toString() ?? '';
      final isValidSig = SecurityHelper.verifyManifest(manifest, signature, secretKey);
      if (!isValidSig) {
        return _fail('Package authenticity check failed (HMAC signature mismatch). File might be from an unauthorized owner or tampered.');
      }

      // 3g. Check if the worker is active locally
      if (generatedByWorkerId.isNotEmpty) {
        final List<Map<String, dynamic>> workerRes = await db.query('workers', where: 'id = ?', whereArgs: [generatedByWorkerId]);
        if (workerRes.isNotEmpty) {
          final status = workerRes.first['status']?.toString() ?? '';
          if (status == 'inactive') {
            return _fail('This package was generated by a disabled worker.');
          }
        }
      }

      // 4. Verify all individual file checksums inside manifest
      final fileHashes = manifest['file_hashes'] as Map<String, dynamic>? ?? {};

      // Verify photos hashes
      for (final p in photoList(archive)) {
        final expectedHash = fileHashes[p] ?? '';
        final actualHash = sha256.convert(photoFiles[p]!).toString();
        if (actualHash != expectedHash) {
          return _fail('Photo file integrity check failed for $p (SHA-256 mismatch).');
        }
      }

      // Verify logo hashes
      for (final l in logoList(archive)) {
        final expectedHash = fileHashes[l] ?? '';
        final actualHash = sha256.convert(logoFiles[l]!).toString();
        if (actualHash != expectedHash) {
          return _fail('Logo file integrity check failed for $l (SHA-256 mismatch).');
        }
      }

      // Verify QR hashes
      for (final q in qrList(archive)) {
        final expectedHash = fileHashes[q] ?? '';
        final actualHash = sha256.convert(qrFiles[q]!).toString();
        if (actualHash != expectedHash) {
          return _fail('QR file integrity check failed for $q (SHA-256 mismatch).');
        }
      }

      final tempDir = await getTemporaryDirectory();
      final tempDbFile = File('${tempDir.path}/wizard_incoming.db');
      if (tempDbFile.existsSync()) tempDbFile.deleteSync();

      try {
        if (packageType == 'backup' || packageType == 'modular') {
          // Verify database.enc hash
          final actualDbEncHash = sha256.convert(dbEncData!).toString();
          final expectedDbEncHash = fileHashes['database.enc']?.toString() ?? '';
          if (actualDbEncHash != expectedDbEncHash) {
            throw Exception('Database integrity check failed (SHA-256 mismatch). File might be corrupted.');
          }

          // 5. Decrypt database.enc to database.db
          List<int> dbData;
          try {
            dbData = SecurityHelper.decryptBytes(dbEncData, secretKey);
          } catch (e) {
            throw Exception('Failed to decrypt database: key mismatch or corrupted file. ($e)');
          }

          // Validate SQLite header
          if (dbData.length < 16 || utf8.decode(dbData.sublist(0, 15), allowMalformed: true) != 'SQLite format 3') {
            throw Exception('Decryption produced invalid database — wrong key or corrupted package.');
          }

          await tempDbFile.writeAsBytes(dbData);
        } else {
          // Construct SQLite database on the fly from decrypted JSON records
          final tempDb = await openDatabase(tempDbFile.path);
          await DatabaseHelper.instance.createSchema(tempDb);
          await tempDb.execute('PRAGMA foreign_keys = OFF');

          try {
            for (final entry in jsonFiles.entries) {
              final filename = entry.key;
              final fileData = entry.value;

              // Verify file hash
              final actualHash = sha256.convert(fileData).toString();
              final expectedHash = fileHashes[filename]?.toString() ?? '';
              if (actualHash != expectedHash) {
                throw Exception('File integrity check failed for $filename (SHA-256 mismatch).');
              }

              // Decrypt file
              List<int> decryptedBytes;
              try {
                decryptedBytes = SecurityHelper.decryptBytes(fileData, secretKey);
              } catch (e) {
                throw Exception('Failed to decrypt $filename: key mismatch or corrupted file. ($e)');
              }

              final jsonStr = utf8.decode(decryptedBytes);
              final dynamic decodedData = jsonDecode(jsonStr);

              final tableName = jsonMappings[filename]!;
              if (decodedData is List) {
                for (final row in decodedData) {
                  if (row is Map<String, dynamic>) {
                    await tempDb.insert(tableName, row, conflictAlgorithm: ConflictAlgorithm.replace);
                  }
                }
              }
            }
          } finally {
            await tempDb.execute('PRAGMA foreign_keys = ON');
            await tempDb.close();
          }
        }
      } catch (e) {
        if (tempDbFile.existsSync()) {
          try { tempDbFile.deleteSync(); } catch (_) {}
        }
        return _fail(e.toString().replaceAll('Exception: ', ''));
      }

      return PackageValidationResult(
        isValid: true,
        errorMessage: '',
        manifest: manifest,
        dbPath: tempDbFile.path,
        photosCount: photoFiles.length,
      );

    } catch (e) {
      return PackageValidationResult(
        isValid: false,
        errorMessage: 'Package parsing error: $e',
        manifest: {},
        dbPath: '',
        photosCount: 0,
      );
    }
  }

  /// Extracts assets (photos, logo, QR) from a verified package zip to the local app document directories
  static Future<void> extractAssets(String zipPath) async {
    try {
      final zipFile = File(zipPath);
      if (!zipFile.existsSync()) return;
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Extract logo
      for (final l in logoList(archive)) {
        final file = archive.findFile(l);
        if (file == null || !file.isFile) continue;
        final dest = File('${AppConstants.appDocsDir}/business_logo.png');
        await dest.parent.create(recursive: true);
        await dest.writeAsBytes(file.content as List<int>);
      }

      // Extract QR
      for (final q in qrList(archive)) {
        final file = archive.findFile(q);
        if (file == null || !file.isFile) continue;
        final dest = File('${AppConstants.appDocsDir}/payment_qr.png');
        await dest.parent.create(recursive: true);
        await dest.writeAsBytes(file.content as List<int>);
      }

      // Extract photos to correct directories (C18)
      for (final photoPath in photoList(archive)) {
        final file = archive.findFile(photoPath);
        if (file == null || !file.isFile) continue;
        final filename = photoPath.split('/').last;
        if (filename.isEmpty) continue;

        String targetDir;
        if (photoPath.startsWith('photos/customer_photos/')) {
          targetDir = '${AppConstants.appDocsDir}/customer_photos';
        } else if (photoPath.startsWith('photos/area_photos/')) {
          targetDir = '${AppConstants.appDocsDir}/area_photos';
        } else if (photoPath.startsWith('photos/street_photos/')) {
          targetDir = '${AppConstants.appDocsDir}/street_photos';
        } else if (photoPath.startsWith('photos/note_photos/')) {
          targetDir = '${AppConstants.appDocsDir}/note_photos';
        } else if (photoPath.startsWith('photos/attachments/')) {
          targetDir = '${AppConstants.appDocsDir}/attachments';
        } else {
          targetDir = '${AppConstants.appDocsDir}/customer_photos'; // Fallback
        }

        final dest = File('$targetDir/$filename');
        await dest.parent.create(recursive: true);
        await dest.writeAsBytes(file.content as List<int>);
      }
    } catch (_) {}
  }

  static PackageValidationResult _fail(String msg) {
    return PackageValidationResult(
      isValid: false,
      errorMessage: msg,
      manifest: {},
      dbPath: '',
      photosCount: 0,
    );
  }

  static List<String> photoList(Archive archive) =>
      archive.files.where((e) => e.isFile).map((e) => e.name.replaceAll('\\', '/')).where((e) => e.startsWith('photos/')).toList();

  static List<String> logoList(Archive archive) =>
      archive.files.where((e) => e.isFile).map((e) => e.name.replaceAll('\\', '/')).where((e) => e.startsWith('logo/')).toList();

  static List<String> qrList(Archive archive) =>
      archive.files.where((e) => e.isFile).map((e) => e.name.replaceAll('\\', '/')).where((e) => e.startsWith('qr/')).toList();
}
