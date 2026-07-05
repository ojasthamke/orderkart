// lib/core/services/worker_session.dart

import '../database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton managing the currently logged-in worker session persistently.
/// If [currentWorkerId] is null or empty, the session is treated as Owner (Master) mode.
class WorkerSession {
  WorkerSession._();
  static final WorkerSession instance = WorkerSession._();

  String? _currentWorkerId;
  String? get currentWorkerId => _currentWorkerId;

  bool get isWorker => _currentWorkerId != null && _currentWorkerId!.isNotEmpty;
  bool get isOwner => !isWorker;

  /// Loads the persisted worker ID from settings.
  Future<void> load() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      if (res.isNotEmpty) {
        _currentWorkerId = res.first['value'] as String?;
      }
    } catch (_) {}
  }

  /// Sets and persists the current worker ID.
  Future<void> setWorker(String? workerId) async {
    _currentWorkerId = workerId;
    try {
      final db = await DatabaseHelper.instance.database;
      if (workerId == null) {
        await db.delete('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      } else {
        await db.insert('settings', {
          'key': 'active_worker_id',
          'value': workerId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (_) {}
  }

  /// Clears the session.
  Future<void> clear() async {
    await setWorker(null);
  }
}
