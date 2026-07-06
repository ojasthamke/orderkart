// lib/core/services/worker_session.dart

import 'dart:io';
import '../database/database_helper.dart';
import '../security/app_mode_service.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton managing the currently logged-in worker session persistently.
/// If [currentWorkerId] is null or empty, the session is treated as Owner (Master) mode.
class WorkerSession {
  WorkerSession._();
  static final WorkerSession instance = WorkerSession._();

  String? _currentWorkerId;
  String? _currentWorkerName;
  AppMode _appMode = AppMode.owner;

  String? get currentWorkerId => _currentWorkerId;
  String? get currentWorkerName => _currentWorkerName;

  String get currentDeviceName {
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iPhone/iPad';
    if (Platform.isWindows) return 'Windows PC';
    return 'Mobile Device';
  }

  bool get isWorker => _appMode == AppMode.worker || (_currentWorkerId != null && _currentWorkerId!.isNotEmpty);
  bool get isOwner => !isWorker;

  /// Loads the persisted worker ID and mode from settings.
  Future<void> load() async {
    try {
      _appMode = await AppModeService.getAppMode();
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      if (res.isNotEmpty) {
        _currentWorkerId = res.first['value'] as String?;
      }
      if (_currentWorkerId != null && _currentWorkerId!.isNotEmpty) {
        final w = await db.query('workers', where: 'id = ?', whereArgs: [_currentWorkerId]);
        if (w.isNotEmpty) {
          _currentWorkerName = w.first['name'] as String?;
        }
      }
    } catch (_) {}
  }

  /// Sets and persists the current worker ID.
  Future<void> setWorker(String? workerId, {String? workerName}) async {
    _currentWorkerId = workerId;
    _currentWorkerName = workerName;
    try {
      final db = await DatabaseHelper.instance.database;
      if (workerId == null) {
        await db.delete('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      } else {
        await db.insert('settings', {
          'key': 'active_worker_id',
          'value': workerId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        if (workerName == null || workerName.isEmpty) {
          final w = await db.query('workers', where: 'id = ?', whereArgs: [workerId]);
          if (w.isNotEmpty) {
            _currentWorkerName = w.first['name'] as String?;
          }
        }
      }
    } catch (_) {}
  }

  /// Clears the session.
  Future<void> clear() async {
    await setWorker(null);
  }
}
