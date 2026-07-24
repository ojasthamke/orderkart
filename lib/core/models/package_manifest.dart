// lib/core/models/package_manifest.dart

import 'dart:convert';

/// Represents the JSON manifest generated for an export package.
class PackageManifest {
  final String packageId;
  final String packageVersion;
  final String dbVersion;
  final String schemaVersion;
  final String exportVersion;
  final List<String> selectedModules;
  final String businessName;
  final String generatedByWorkerId;
  final String generatedByWorkerName;
  final bool isWorkerProvisioningPackage;
  final String deviceName;
  final String deviceModel;
  final String androidId;
  final String appVersion;
  final String exportTimestamp;
  final Map<String, String> fileHashes;
  final String signature; // HMAC-SHA256 signature field

  PackageManifest({
    required this.packageId,
    required this.packageVersion,
    required this.dbVersion,
    required this.schemaVersion,
    required this.exportVersion,
    required this.selectedModules,
    required this.businessName,
    required this.generatedByWorkerId,
    required this.generatedByWorkerName,
    required this.isWorkerProvisioningPackage,
    required this.deviceName,
    required this.deviceModel,
    required this.androidId,
    required this.appVersion,
    required this.exportTimestamp,
    required this.fileHashes,
    this.signature = '',
  });

  factory PackageManifest.fromJson(String jsonStr) {
    final Map<String, dynamic> map = json.decode(jsonStr);
    return PackageManifest(
      packageId: map['package_id'] as String,
      packageVersion: map['package_version'] as String,
      dbVersion: map['db_version'] as String,
      schemaVersion: map['schema_version'] as String,
      exportVersion: map['export_version'] as String,
      selectedModules: List<String>.from(map['selected_modules'] ?? []),
      businessName: map['business_name'] as String,
      generatedByWorkerId: map['generated_by_worker_id'] as String,
      generatedByWorkerName: map['generated_by_worker_name'] as String,
      isWorkerProvisioningPackage:
          map['is_worker_provisioning_package'] as bool,
      deviceName: map['device_name'] as String,
      deviceModel: map['device_model'] as String,
      androidId: map['android_id'] as String,
      appVersion: map['app_version'] as String,
      exportTimestamp: map['export_timestamp'] as String,
      fileHashes: Map<String, String>.from(map['file_hashes'] ?? {}),
      signature: map['signature'] as String? ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  Map<String, dynamic> toMap() => {
        'package_id': packageId,
        'package_version': packageVersion,
        'db_version': dbVersion,
        'schema_version': schemaVersion,
        'export_version': exportVersion,
        'selected_modules': selectedModules,
        'business_name': businessName,
        'generated_by_worker_id': generatedByWorkerId,
        'generated_by_worker_name': generatedByWorkerName,
        'is_worker_provisioning_package': isWorkerProvisioningPackage,
        'device_name': deviceName,
        'device_model': deviceModel,
        'android_id': androidId,
        'app_version': appVersion,
        'export_timestamp': exportTimestamp,
        'file_hashes': fileHashes,
        'signature': signature,
      };

  /// Returns a map representation of the manifest excluding signature.
  /// Used for generating/verifying the HMAC-SHA256 signature itself.
  Map<String, dynamic> toMapWithoutSignature() {
    final map = toMap();
    map.remove('signature');
    return map;
  }
}
