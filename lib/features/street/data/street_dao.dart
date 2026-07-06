import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/worker_session.dart';
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
    final map = street.toMap();

    if (WorkerSession.instance.isWorker) {
      map['created_by'] = 'worker';
      if ((map['assigned_worker_id'] as String? ?? '').isEmpty) {
        map['assigned_worker_id'] = WorkerSession.instance.currentWorkerId ?? '';
      }
      if ((map['worker_name'] as String? ?? '').isEmpty) {
        map['worker_name'] = WorkerSession.instance.currentWorkerName ?? 'Worker';
      }
      if ((map['device_name'] as String? ?? '').isEmpty) {
        map['device_name'] = WorkerSession.instance.currentDeviceName;
      }
    }

    await db.insert('streets', {
      ...map,
      'id':         id,
      'created_at': DateTime.now().toIso8601String(),
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
