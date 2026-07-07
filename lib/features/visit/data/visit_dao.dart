import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/security/app_mode_service.dart';
import '../domain/app_visit.dart';

class VisitDao {
  static const String tableName = 'visits';

  Future<Database> get db async => await DatabaseHelper.instance.database;

  Future<int> insert(AppVisit visit) async {
    final database = await db;

    final mode = await AppModeService.getAppMode();
    String createdBy = 'owner';
    String assignedWorkerId = '';
    String workerName = '';
    String deviceName = '';

    if (mode == AppMode.worker) {
      final settingsRes = await database.query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      final activeWorkerId = settingsRes.isNotEmpty ? settingsRes.first['value']?.toString() : null;
      if (activeWorkerId != null && activeWorkerId.isNotEmpty) {
        createdBy = activeWorkerId;
        assignedWorkerId = activeWorkerId;
        final workerRow = await database.query('workers', where: 'id = ?', whereArgs: [activeWorkerId]);
        if (workerRow.isNotEmpty) {
          workerName = workerRow.first['name']?.toString() ?? '';
        }
        deviceName = 'Worker Mobile';
      }
    }

    return await database.insert(
      tableName,
      {
        ...visit.toMap(),
        'created_by':         createdBy,
        'assigned_worker_id': assignedWorkerId,
        'worker_name':        workerName,
        'device_name':        deviceName,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(AppVisit visit) async {
    final database = await db;
    return await database.update(
      tableName,
      visit.toMap(),
      where: 'id = ?',
      whereArgs: [visit.id],
    );
  }

  Future<int> delete(String id) async {
    final database = await db;
    return await database.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<AppVisit>> getVisitsByDate(String date) async {
    final database = await db;
    final List<Map<String, dynamic>> maps = await database.query(
      tableName,
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'priority DESC, created_at ASC',
    );

    return List.generate(maps.length, (i) {
      return AppVisit.fromMap(maps[i]);
    });
  }

  Future<List<AppVisit>> getAllVisits() async {
    final database = await db;
    final List<Map<String, dynamic>> maps = await database.query(
      tableName,
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return AppVisit.fromMap(maps[i]);
    });
  }
}
