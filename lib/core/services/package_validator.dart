import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';

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
      final archive = ZipDecoder().decodeBytes(bytes);

      List<int>? dbData;
      List<int>? manifestData;
      String? checksumHash;

      // Map to hold references to other files inside zip
      final Map<String, List<int>> photoFiles = {};
      final Map<String, List<int>> logoFiles = {};
      final Map<String, List<int>> qrFiles = {};

      for (final f in archive) {
        if (!f.isFile) continue;
        final normName = f.name.replaceAll('\\', '/');

        if (normName == 'database.db') {
          dbData = f.content as List<int>;
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
        }
      }

      // 1. Basic Package Verification
      if (manifestData == null) {
        return _fail('Missing manifest.json file inside package.');
      }
      if (checksumHash == null) {
        return _fail('Missing signature checksum.sha256 file.');
      }
      if (dbData == null) {
        return _fail('Missing database.db file inside package.');
      }

      // 2. Validate manifest.json signature using checksum.sha256
      final actualManifestHash = sha256.convert(manifestData).toString();
      if (actualManifestHash != checksumHash) {
        return _fail('Package signature verification failed (Manifest hash mismatch). File might be corrupted or tampered.');
      }

      // 3. Parse manifest JSON
      final Map<String, dynamic> manifest = jsonDecode(utf8.decode(manifestData));

      // Validate version parameters
      final appVer = manifest['app_version']?.toString() ?? '';
      final dbVer = manifest['db_version']?.toString() ?? '';
      final schemaVer = manifest['schema_version']?.toString() ?? '';

      if (schemaVer != '4') {
        return _fail('Incompatible schema version: $schemaVer (Required: 4).');
      }
      if (dbVer != AppConstants.dbVersion.toString()) {
        return _fail('Incompatible database version: $dbVer (Expected: ${AppConstants.dbVersion}).');
      }

      // 4. Verify all individual file checksums inside manifest
      final fileHashes = manifest['file_hashes'] as Map<String, dynamic>? ?? {};

      // Verify database.db hash
      final actualDbHash = sha256.convert(dbData).toString();
      final expectedDbHash = fileHashes['database.db']?.toString() ?? '';
      if (actualDbHash != expectedDbHash) {
        return _fail('Database integrity check failed (SHA-256 mismatch). file might be corrupted.');
      }

      // Verify photos hashes
      for (final p in photoList(archive)) {
        final expectedHash = fileHashes[p] ?? '';
        final actualHash = sha256.convert(photoFiles[p]!).toString();
        if (actualHash != expectedHash) {
          return _fail('Photo file integrity check failed for $p (SHA-256 mismatch).');
        }
      }

      // Extract database.db to temp folder for the wizard preview/merge
      final tempDir = await getTemporaryDirectory();
      final tempDbFile = File('${tempDir.path}/wizard_incoming.db');
      if (tempDbFile.existsSync()) tempDbFile.deleteSync();
      await tempDbFile.writeAsBytes(dbData);

      // Extract files safely
      for (final p in photoList(archive)) {
        final filename = p.split('/').last;
        final dest = File('${AppConstants.appDocsDir}/customer_photos/$filename');
        await dest.parent.create(recursive: true);
        await dest.writeAsBytes(photoFiles[p]!);
      }

      for (final l in logoList(archive)) {
        final dest = File('${AppConstants.appDocsDir}/business_logo.png');
        await dest.writeAsBytes(logoFiles[l]!);
      }

      for (final q in qrList(archive)) {
        final dest = File('${AppConstants.appDocsDir}/payment_qr.png');
        await dest.writeAsBytes(qrFiles[q]!);
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

  static PackageValidationResult _fail(String msg) {
    return PackageValidationResult(
      isValid: false,
      errorMessage: msg,
      manifest: {},
      dbPath: '',
      photosCount: 0,
    );
  }

  static List<String> photoList(List<ArchiveFile> files) =>
      files.map((e) => e.name.replaceAll('\\', '/')).where((e) => e.startsWith('photos/')).toList();

  static List<String> logoList(List<ArchiveFile> files) =>
      files.map((e) => e.name.replaceAll('\\', '/')).where((e) => e.startsWith('logo/')).toList();

  static List<String> qrList(List<ArchiveFile> files) =>
      files.map((e) => e.name.replaceAll('\\', '/')).where((e) => e.startsWith('qr/')).toList();
}
