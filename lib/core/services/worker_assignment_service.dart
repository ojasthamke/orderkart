// lib/core/services/worker_assignment_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/worker_assignment.dart';

class WorkerAssignmentService {
  WorkerAssignmentService._();
  static const _uuid = Uuid();

  /// Create a new assignment.
  static Future<String> assignEntity({
    required String workerId,
    required String entityType,
    required String entityId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final id = _uuid.v4();
    final assignment = WorkerAssignment(
      id: id,
      workerId: workerId,
      entityType: entityType,
      entityId: entityId,
      createdAt: DateTime.now(),
    );
    await db.insert(
      'worker_assignments',
      assignment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  /// Revoke a specific assignment by its [id].
  static Future<void> revokeAssignment(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('worker_assignments', where: 'id = ?', whereArgs: [id]);
  }

  /// Revoke assignments for a worker of a specific entity.
  static Future<void> revokeWorkerAssignment({
    required String workerId,
    required String entityType,
    required String entityId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'worker_assignments',
      where: 'worker_id = ? AND entity_type = ? AND entity_id = ?',
      whereArgs: [workerId, entityType, entityId],
    );
  }

  /// Retrieve all assignments for a worker.
  static Future<List<WorkerAssignment>> getAssignmentsForWorker(
      String workerId) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'worker_assignments',
      where: 'worker_id = ?',
      whereArgs: [workerId],
    );
    return maps.map(WorkerAssignment.fromMap).toList();
  }

  /// Get list of entity IDs assigned to a worker for a specific entity type.
  static Future<List<String>> getAssignedEntityIds(
      String workerId, String entityType) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'worker_assignments',
      columns: ['entity_id'],
      where: 'worker_id = ? AND entity_type = ?',
      whereArgs: [workerId, entityType],
    );
    return maps.map((m) => m['entity_id'] as String).toList();
  }

  /// Check if a specific entity is assigned to a worker.
  static Future<bool> isEntityAssigned(
      String workerId, String entityType, String entityId) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'worker_assignments',
      columns: ['id'],
      where: 'worker_id = ? AND entity_type = ? AND entity_id = ?',
      whereArgs: [workerId, entityType, entityId],
      limit: 1,
    );
    return maps.isNotEmpty;
  }
}
