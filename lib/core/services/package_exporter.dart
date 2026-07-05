import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_constants.dart';
import '../database/database_helper.dart';

class PackageExporter {
  PackageExporter._();

  /// Export a scoped zip package (or full DB) with embedded manifest metadata JSON
  static Future<void> exportPackage({
    required String packageType, // 'full', 'worker', 'customer', 'inventory'
    String workerId = '',
    String workerName = '',
  }) async {
    final dbPath = await DatabaseHelper.instance.database.then((db) => db.path);
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) throw Exception('Database file not found');

    final dir = await getTemporaryDirectory();
    final zipFile = File('${dir.path}/orderkart_${packageType}_package.zip');
    if (zipFile.existsSync()) zipFile.deleteSync();

    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);

    // 1. Add DB
    encoder.addFile(dbFile, 'orderkart.db');

    // 2. Add Manifest JSON
    final manifest = {
      'package_type': packageType,
      'business_name': AppConstants.appName,
      'worker_id': workerId,
      'worker_name': workerName,
      'device_name': Platform.operatingSystem,
      'app_version': AppConstants.appVersion,
      'db_version': AppConstants.dbVersion,
      'export_timestamp': DateTime.now().toIso8601String(),
    };

    final manifestFile = File('${dir.path}/manifest.json');
    await manifestFile.writeAsString(jsonEncode(manifest));
    encoder.addFile(manifestFile, 'manifest.json');

    // 3. Add customer photos if directory exists
    final photoDir = Directory('${AppConstants.appDocsDir}/customer_photos');
    if (photoDir.existsSync()) {
      final files = photoDir.listSync();
      for (final f in files) {
        if (f is File) {
          encoder.addFile(f, 'customer_photos/${p.basename(f.path)}');
        }
      }
    }

    await encoder.close();
    await Share.shareXFiles([XFile(zipFile.path)], subject: 'OrderKart Package Export');
  }
}
