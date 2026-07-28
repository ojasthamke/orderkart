import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/worker_permission.dart';
import '../error/failures.dart';
import 'worker_session.dart';

class WorkerPermissionService {
  WorkerPermissionService._();

  /// Retrieve the permission set for a given worker from DB.
  static Future<WorkerPermission> getPermissionsForWorker(
      String workerId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query(
        'worker_permissions',
        where: 'worker_id = ?',
        whereArgs: [workerId],
      );
      if (res.isNotEmpty) {
        return WorkerPermission.fromMap(res.first);
      }
    } catch (_) {}

    return WorkerPermission(
      workerId: workerId,
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

  /// Check if a worker has a specific permission field level.
  static Future<bool> hasPermission(String workerId, String permissionField,
      {int requiredLevel = 2}) async {
    if (WorkerSession.instance.isOwner) return true;
    final perm = await getPermissionsForWorker(workerId);
    final map = perm.toMap();
    final val = map[permissionField] as int? ?? 0;
    return val >= requiredLevel;
  }

  /// Check if a worker has a specific permission, throwing a [PermissionFailure] if they do not.
  static Future<void> checkPermissionOrThrow(
      String workerId, String permissionField, String actionName,
      {int requiredLevel = 2}) async {
    final allowed = await hasPermission(workerId, permissionField,
        requiredLevel: requiredLevel);
    if (!allowed) {
      throw PermissionFailure('You do not have permission to $actionName.');
    }
  }
}
