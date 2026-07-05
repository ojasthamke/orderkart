// lib/core/services/worker_permission_service.dart

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/worker_permission.dart';
import '../error/failures.dart';

class WorkerPermissionService {
  WorkerPermissionService._();

  /// Retrieve the permission set for a given worker.
  /// If no permission row exists, a default active one is returned/created.
  static Future<WorkerPermission> getPermissionsForWorker(String workerId) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'worker_permissions',
      where: 'worker_id = ?',
      whereArgs: [workerId],
    );

    if (maps.isEmpty) {
      final defaultPerm = WorkerPermission(
        workerId: workerId,
        customers: PermissionLevel.full,
        orders: PermissionLevel.full,
        payments: PermissionLevel.full,
        expenses: PermissionLevel.full,
        sellingPrice: PermissionLevel.full,
        costPrice: PermissionLevel.hidden,
        stock: PermissionLevel.full,
        items: PermissionLevel.view,
        vip: PermissionLevel.hidden,
        reports: PermissionLevel.view,
        notes: PermissionLevel.full,
        export: PermissionLevel.full,
        import: PermissionLevel.hidden,
        settings: PermissionLevel.hidden,
        analytics: PermissionLevel.view,
        updatedAt: DateTime.now(),
      );
      await savePermissions(defaultPerm);
      return defaultPerm;
    }

    return WorkerPermission.fromMap(maps.first);
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

  /// Check if a worker has a specific permission at or above the [requiredLevel].
  /// [requiredLevel]: 1 for View, 2 for Edit, 3 for Full.
  static Future<bool> hasPermission(String workerId, String permissionField, {int requiredLevel = 2}) async {
    final permissions = await getPermissionsForWorker(workerId);
    final map = permissions.toMap();
    
    if (map.containsKey(permissionField)) {
      final actualVal = map[permissionField] as int? ?? 0;
      return actualVal >= requiredLevel;
    }
    return false;
  }

  /// Check if a worker has a specific permission, throwing a [PermissionFailure] if they do not.
  static Future<void> checkPermissionOrThrow(String workerId, String permissionField, String actionName, {int requiredLevel = 2}) async {
    final allowed = await hasPermission(workerId, permissionField, requiredLevel: requiredLevel);
    if (!allowed) {
      throw PermissionFailure('Worker is not authorized to perform action: $actionName');
    }
  }
}
