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
      final settingsRes = await database
          .query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      final activeWorkerId = settingsRes.isNotEmpty
          ? settingsRes.first['value']?.toString()
          : null;
      if (activeWorkerId != null && activeWorkerId.isNotEmpty) {
        createdBy = activeWorkerId;
        assignedWorkerId = activeWorkerId;
        final workerRow = await database
            .query('workers', where: 'id = ?', whereArgs: [activeWorkerId]);
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
        'created_by': createdBy,
        'assigned_worker_id': assignedWorkerId,
        'worker_name': workerName,
        'device_name': deviceName,
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
    String where = 'date = ?';
    List<dynamic> args = [date];

    final mode = await AppModeService.getAppMode();
    if (mode == AppMode.worker) {
      final settingsRes = await database
          .query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      String? workerId = settingsRes.isNotEmpty
          ? settingsRes.first['value']?.toString()
          : null;
      if (workerId == null || workerId.isEmpty) {
        final workerRows = await database.query('workers', limit: 1);
        if (workerRows.isNotEmpty) {
          workerId = workerRows.first['id'] as String;
        }
      }

      if (workerId != null && workerId.isNotEmpty) {
        final assignmentRows = await database.query(
          'worker_assignments',
          where: 'worker_id = ? AND entity_type = ?',
          whereArgs: [workerId, 'area'],
        );
        final assignedAreaIds = assignmentRows
            .map((e) => e['entity_id']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();

        final placeholders = assignedAreaIds.isNotEmpty
            ? List.filled(assignedAreaIds.length, '?').join(',')
            : "''";

        where +=
            ' AND (created_by = ? OR assigned_worker_id = ? OR area_id IN ($placeholders))';
        args.addAll([workerId, workerId]);
        if (assignedAreaIds.isNotEmpty) {
          args.addAll(assignedAreaIds);
        }
      } else {
        return [];
      }
    }

    final List<Map<String, dynamic>> maps = await database.rawQuery('''
      SELECT v.*, 
             a.name AS area_name, 
             s.name AS street_name
      FROM visits v
      LEFT JOIN locations a ON v.area_id = a.id
      LEFT JOIN locations s ON v.street_id = s.id
      WHERE v.$where
      ORDER BY v.priority DESC, v.created_at ASC
    ''', args);

    return List.generate(maps.length, (i) {
      return AppVisit.fromMap(maps[i]);
    });
  }

  Future<List<AppVisit>> getAllVisits() async {
    final database = await db;
    String? where;
    List<dynamic>? args;

    final mode = await AppModeService.getAppMode();
    if (mode == AppMode.worker) {
      final settingsRes = await database
          .query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      String? workerId = settingsRes.isNotEmpty
          ? settingsRes.first['value']?.toString()
          : null;
      if (workerId == null || workerId.isEmpty) {
        final workerRows = await database.query('workers', limit: 1);
        if (workerRows.isNotEmpty) {
          workerId = workerRows.first['id'] as String;
        }
      }

      if (workerId != null && workerId.isNotEmpty) {
        final assignmentRows = await database.query(
          'worker_assignments',
          where: 'worker_id = ? AND entity_type = ?',
          whereArgs: [workerId, 'area'],
        );
        final assignedAreaIds = assignmentRows
            .map((e) => e['entity_id']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();

        final placeholders = assignedAreaIds.isNotEmpty
            ? List.filled(assignedAreaIds.length, '?').join(',')
            : "''";

        where =
            '(created_by = ? OR assigned_worker_id = ? OR area_id IN ($placeholders))';
        args = [workerId, workerId];
        if (assignedAreaIds.isNotEmpty) {
          args.addAll(assignedAreaIds);
        }
      } else {
        return [];
      }
    }

    final List<Map<String, dynamic>> maps = await database.rawQuery('''
      SELECT v.*, 
             a.name AS area_name, 
             s.name AS street_name
      FROM visits v
      LEFT JOIN locations a ON v.area_id = a.id
      LEFT JOIN locations s ON v.street_id = s.id
      ${where != null ? 'WHERE v.$where' : ''}
      ORDER BY v.date DESC
    ''', args);

    return List.generate(maps.length, (i) {
      return AppVisit.fromMap(maps[i]);
    });
  }
}
