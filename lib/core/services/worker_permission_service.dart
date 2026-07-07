// lib/core/services/worker_permission_service.dart

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/worker_permission.dart';
import '../error/failures.dart';

class WorkerPermissionService {
  WorkerPermissionService._();

  /// Retrieve the permission set for a given worker (always returns full access).
  static Future<WorkerPermission> getPermissionsForWorker(String workerId) async {
    return WorkerPermission(
      workerId: workerId,
      customers: PermissionLevel.full,
      orders: PermissionLevel.full,
      payments: PermissionLevel.full,
      expenses: PermissionLevel.full,
      sellingPrice: PermissionLevel.full,
      costPrice: PermissionLevel.full,
      stock: PermissionLevel.full,
      items: PermissionLevel.full,
      vip: PermissionLevel.full,
      reports: PermissionLevel.full,
      notes: PermissionLevel.full,
      export: PermissionLevel.full,
      import: PermissionLevel.full,
      settings: PermissionLevel.full,
      analytics: PermissionLevel.full,
      updatedAt: DateTime.now(),
    );
  }

  /// Save or update the permission set for a worker.
  static Future<void> savePermissions(WorkerPermission permissions) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'worker_permissions',
      permissions.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Check if a worker has a specific permission (always returns true).
  static Future<bool> hasPermission(String workerId, String permissionField, {int requiredLevel = 2}) async {
    return true;
  }

  /// Check if a worker has a specific permission, throwing a [PermissionFailure] if they do not (no-op).
  static Future<void> checkPermissionOrThrow(String workerId, String permissionField, String actionName, {int requiredLevel = 2}) async {}
}
