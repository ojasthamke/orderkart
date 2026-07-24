// lib/core/services/worker_service.dart

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/worker.dart';
import '../utils/security_helper.dart';

/// Service responsible for CRUD operations on [Worker] entities.
class WorkerService {
  WorkerService._();

  /// Insert a new worker into the database and isolate its secret in the worker_security table.
  static Future<void> createWorker(Worker worker) async {
    final Database db = await DatabaseHelper.instance.database;
    final secret = SecurityHelper.generateOwnerSecret();
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 1. Insert profile into workers table
      await txn.insert('workers', worker.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      // 2. Insert secret into worker_security table
      await txn.insert(
        'worker_security',
        {
          'worker_id': worker.id,
          'worker_secret': secret,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Retrieve a worker by its [id]. Returns null if not found.
  static Future<Worker?> getWorkerById(String id) async {
    final Database db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps =
        await db.query('workers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Worker.fromMap(maps.first);
  }

  /// Retrieve all workers.
  static Future<List<Worker>> getAllWorkers() async {
    final Database db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('workers');
    return maps.map((m) => Worker.fromMap(m)).toList();
  }

  /// Update an existing worker. The worker must already exist.
  static Future<void> updateWorker(Worker worker) async {
    final Database db = await DatabaseHelper.instance.database;
    await db.update('workers', worker.toMap(),
        where: 'id = ?', whereArgs: [worker.id]);
  }

  /// Delete a worker by its [id] and clean up related data including secrets.
  static Future<void> deleteWorker(String id) async {
    final Database db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.delete('workers', where: 'id = ?', whereArgs: [id]);
      await txn
          .delete('worker_security', where: 'worker_id = ?', whereArgs: [id]);
      await txn.delete('worker_assignments',
          where: 'worker_id = ?', whereArgs: [id]);
      await txn
          .delete('worker_reports', where: 'worker_id = ?', whereArgs: [id]);
      await txn.delete('worker_permissions',
          where: 'worker_id = ?', whereArgs: [id]);
    });
  }
}
