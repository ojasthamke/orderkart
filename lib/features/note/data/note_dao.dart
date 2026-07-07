import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/security/app_mode_service.dart';
import '../domain/app_note.dart';

class NoteDao {
  static const String tableName = 'notes';

  Future<Database> get db async => await DatabaseHelper.instance.database;

  Future<int> insert(AppNote note) async {
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
        ...note.toMap(),
        'created_by':         createdBy,
        'assigned_worker_id': assignedWorkerId,
        'worker_name':        workerName,
        'device_name':        deviceName,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(AppNote note) async {
    final database = await db;
    return await database.update(
      tableName,
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
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

  Future<List<AppNote>> getNotes({bool includeArchived = false}) async {
    final database = await db;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (!includeArchived) {
      whereClause = 'is_archived = ?';
      whereArgs = [0];
    }

    final List<Map<String, dynamic>> maps = await database.query(
      tableName,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'is_pinned DESC, created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return AppNote.fromMap(maps[i]);
    });
  }
}
