import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/security/app_mode_service.dart';
import '../domain/street.dart';

class StreetDao {
  final _uuid = const Uuid();
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Street>> getStreetsByArea(String areaId, {String? searchQuery}) async {
    final db = await _db;
    String where = 's.area_id = ?';
    List<dynamic> args = [areaId];
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      where += ' AND s.name LIKE ?';
      args.add('%${searchQuery.trim()}%');
    }


    final maps = await db.rawQuery('''
      SELECT s.*,
        (SELECT COUNT(*) FROM customers c WHERE c.street_id = s.id) AS customer_count
      FROM streets s
      WHERE $where
      ORDER BY s.name ASC
    ''', args);
    return maps.map(Street.fromMap).toList();
  }

  Future<Street?> getStreetById(String id) async {
    final db = await _db;
    final maps = await db.query('streets', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Street.fromMap(maps.first);
  }

  Future<String> insertStreet(Street street) async {
    final db = await _db;
    final id  = street.id.isEmpty ? _uuid.v4() : street.id;
    final now = DateTime.now().toIso8601String();

    final mode = await AppModeService.getAppMode();
    String createdBy = street.createdBy;
    String assignedWorkerId = street.assignedWorkerId;
    String workerName = street.workerName;

    if (mode == AppMode.worker) {
      final settingsRes = await db.query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      final activeWorkerId = settingsRes.isNotEmpty ? settingsRes.first['value']?.toString() : null;
      if (activeWorkerId != null && activeWorkerId.isNotEmpty) {
        createdBy = activeWorkerId;
        assignedWorkerId = activeWorkerId;
        final workerRow = await db.query('workers', where: 'id = ?', whereArgs: [activeWorkerId]);
        if (workerRow.isNotEmpty) {
          workerName = workerRow.first['name']?.toString() ?? '';
        }
        await db.insert('worker_assignments', {
          'id': const Uuid().v4(),
          'worker_id': activeWorkerId,
          'entity_type': 'street',
          'entity_id': id,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    final map = street.toMap();
    await db.insert('streets', {
      ...map,
      'id':         id,
      'created_by': createdBy,
      'assigned_worker_id': assignedWorkerId,
      'worker_name': workerName,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<void> updateStreet(Street street) async {
    final db = await _db;
    await db.update('streets', street.toMap(),
        where: 'id = ?', whereArgs: [street.id]);
  }

  Future<void> deleteStreet(String id) async {
    final db = await _db;
    await db.delete('streets', where: 'id = ?', whereArgs: [id]);
  }
}
