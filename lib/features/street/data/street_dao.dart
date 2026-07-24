import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/security/app_mode_service.dart';
import '../domain/street.dart';

class StreetDao {
  final _uuid = const Uuid();
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Street>> getStreetsByArea(String areaId,
      {String? searchQuery}) async {
    final db = await _db;
    String where =
        's.parent_location_id = ? AND s.location_kind = \'road\' AND s.is_archived = 0';
    List<dynamic> args = [areaId];
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      where += ' AND s.name LIKE ?';
      args.add('%${searchQuery.trim()}%');
    }

    final maps = await db.rawQuery('''
      SELECT s.*,
        s.parent_location_id AS area_id,
        (SELECT COUNT(*) FROM customers c WHERE c.location_id = s.id) AS customer_count
      FROM locations s
      WHERE $where
      ORDER BY s.sequence_key ASC
    ''', args);
    return maps.map(Street.fromMap).toList();
  }

  Future<Street?> getStreetById(String id) async {
    final db = await _db;
    final maps = await db.rawQuery('''
      SELECT *, parent_location_id AS area_id,
        (SELECT COUNT(*) FROM customers c WHERE c.location_id = id) AS customer_count
      FROM locations
      WHERE id = ?
    ''', [id]);
    if (maps.isEmpty) return null;
    return Street.fromMap(maps.first);
  }

  Future<String> insertStreet(Street street) async {
    final db = await _db;
    final id = street.id.isEmpty ? _uuid.v4() : street.id;
    final now = DateTime.now().toIso8601String();

    final mode = await AppModeService.getAppMode();
    String createdBy = street.createdBy;
    String assignedWorkerId = street.assignedWorkerId;
    String workerName = street.workerName;

    if (mode == AppMode.worker) {
      final settingsRes = await db
          .query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      final activeWorkerId = settingsRes.isNotEmpty
          ? settingsRes.first['value']?.toString()
          : null;
      if (activeWorkerId != null && activeWorkerId.isNotEmpty) {
        createdBy = activeWorkerId;
        assignedWorkerId = activeWorkerId;
        final workerRow = await db
            .query('workers', where: 'id = ?', whereArgs: [activeWorkerId]);
        if (workerRow.isNotEmpty) {
          workerName = workerRow.first['name']?.toString() ?? '';
        }
        await db.insert(
            'worker_assignments',
            {
              'id': const Uuid().v4(),
              'worker_id': activeWorkerId,
              'entity_type': 'street',
              'entity_id': id,
              'created_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    // Resolve sequence key under parent location (area_id)
    final seqMaps = await db.query('locations',
        columns: ['sequence_key'],
        where: 'parent_location_id = ?',
        whereArgs: [street.areaId],
        orderBy: 'sequence_key DESC',
        limit: 1);
    final lastSeq =
        seqMaps.isNotEmpty ? seqMaps.first['sequence_key'] as String? : null;
    final nextSeq = (lastSeq != null && int.tryParse(lastSeq) != null)
        ? (int.parse(lastSeq) + 1000).toString().padLeft(6, '0')
        : '001000';

    // Insert into locations table
    await db.insert(
        'locations',
        {
          'id': id,
          'parent_location_id': street.areaId,
          'name': street.name,
          'description': street.description,
          'location_kind': 'road',
          'sequence_key': nextSeq,
          'depth': 1,
          'materialized_path': '/${street.areaId}/$id/',
          'photo_path': street.photoPath,
          'maps_location': street.mapsLocation,
          'created_by': createdBy,
          'assigned_worker_id': assignedWorkerId,
          'worker_name': workerName,
          'device_name': street.deviceName,
          'is_archived': 0,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);

    // Keep legacy table updated
    try {
      final map = street.toMap();
      await db.insert(
          'streets',
          {
            ...map,
            'id': id,
            'created_by': createdBy,
            'assigned_worker_id': assignedWorkerId,
            'worker_name': workerName,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}

    return id;
  }

  Future<void> updateStreet(Street street) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'locations',
      {
        'name': street.name,
        'description': street.description,
        'photo_path': street.photoPath,
        'maps_location': street.mapsLocation,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [street.id],
    );

    // Keep legacy table updated
    try {
      await db.update('streets', street.toMap(),
          where: 'id = ?', whereArgs: [street.id]);
    } catch (_) {}
  }

  Future<void> deleteStreet(String id) async {
    final db = await _db;

    // Clear street and location references for all customers in this street
    await db.update(
      'customers',
      {'street_id': '', 'location_id': ''},
      where: 'street_id = ? OR location_id = ?',
      whereArgs: [id, id],
    );

    await db.delete('locations', where: 'id = ?', whereArgs: [id]);

    // Keep legacy table updated
    try {
      await db.delete('streets', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }
}
