import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/security/app_mode_service.dart';
import '../domain/area.dart';

class AreaDao {
  final _uuid = const Uuid();

  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Fetch all areas with optional search and sorting from the new locations table.
  Future<List<Area>> getAllAreas({String? searchQuery, String? sortBy}) async {
    final db = await _db;

    String orderClause = 'l.name ASC';
    if (sortBy == 'date') orderClause = 'l.created_at DESC';
    if (sortBy == 'street_count') orderClause = 'street_count DESC';
    if (sortBy == 'customer_count') orderClause = 'customer_count DESC';

    List<String> whereClauses = [
      "l.location_kind = 'area'",
      "l.is_archived = 0"
    ];
    List<dynamic> args = [];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('l.name LIKE ?');
      args.add('%${searchQuery.trim()}%');
    }

    final whereClauseSection =
        whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final maps = await db.rawQuery('''
      SELECT
        l.*,
        (SELECT COUNT(*) FROM locations s WHERE s.parent_location_id = l.id AND s.is_archived = 0) AS street_count,
        (SELECT COUNT(*) FROM customers c
          JOIN locations st ON c.location_id = st.id
          WHERE st.parent_location_id = l.id) AS customer_count,
        (SELECT COUNT(*) FROM orders o
          JOIN customers cust ON o.customer_id = cust.id
          JOIN locations st ON cust.location_id = st.id
          WHERE st.parent_location_id = l.id) AS order_count,
        (SELECT COALESCE(SUM(o.grand_total), 0.0) FROM orders o
          JOIN customers cust ON o.customer_id = cust.id
          JOIN locations st ON cust.location_id = st.id
          WHERE st.parent_location_id = l.id) AS total_revenue
      FROM locations l
      $whereClauseSection
      ORDER BY $orderClause
    ''', args);

    return maps.map(Area.fromMap).toList();
  }

  Future<Area?> getAreaById(String id) async {
    final db = await _db;
    final maps = await db.rawQuery('''
      SELECT
        l.*,
        (SELECT COUNT(*) FROM locations s WHERE s.parent_location_id = l.id AND s.is_archived = 0) AS street_count,
        (SELECT COUNT(*) FROM customers c
          JOIN locations st ON c.location_id = st.id
          WHERE st.parent_location_id = l.id) AS customer_count,
        (SELECT COUNT(*) FROM orders o
          JOIN customers cust ON o.customer_id = cust.id
          JOIN locations st ON cust.location_id = st.id
          WHERE st.parent_location_id = l.id) AS order_count,
          (SELECT COALESCE(SUM(o.grand_total), 0.0) FROM orders o
          JOIN customers cust ON o.customer_id = cust.id
          JOIN locations st ON cust.location_id = st.id
          WHERE st.parent_location_id = l.id) AS total_revenue
      FROM locations l
      WHERE l.id = ?
    ''', [id]);
    if (maps.isEmpty) return null;
    return Area.fromMap(maps.first);
  }

  Future<String> insertArea(Area area) async {
    final db = await _db;
    final id = area.id.isEmpty ? _uuid.v4() : area.id;
    final now = DateTime.now().toIso8601String();

    final mode = await AppModeService.getAppMode();
    String createdBy = area.createdBy;
    String assignedWorkerId = area.assignedWorkerId;
    String workerName = area.workerName;

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
              'entity_type': 'area',
              'entity_id': id,
              'created_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    // Get next sequence key for root locations
    final seqMaps = await db.query('locations',
        columns: ['sequence_key'],
        where: 'parent_location_id IS NULL',
        orderBy: 'sequence_key DESC',
        limit: 1);
    final lastSeq =
        seqMaps.isNotEmpty ? seqMaps.first['sequence_key'] as String? : null;
    final nextSeq = (lastSeq != null && int.tryParse(lastSeq) != null)
        ? (int.parse(lastSeq) + 1000).toString().padLeft(6, '0')
        : '001000';

    // Insert into new locations table
    await db.insert(
        'locations',
        {
          'id': id,
          'parent_location_id': null,
          'name': area.name,
          'description': area.description,
          'location_kind': 'area',
          'sequence_key': nextSeq,
          'depth': 0,
          'materialized_path': '/$id/',
          'photo_path': area.photoPath,
          'maps_location': area.mapsLocation,
          'color': area.color,
          'created_by': createdBy,
          'assigned_worker_id': assignedWorkerId,
          'worker_name': workerName,
          'device_name': area.deviceName,
          'is_archived': 0,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);

    // Keep legacy table updated
    try {
      final map = area.toMap();
      await db.insert(
          'areas',
          {
            ...map,
            'id': id,
            'created_by': createdBy,
            'assigned_worker_id': assignedWorkerId,
            'worker_name': workerName,
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}

    return id;
  }

  Future<void> updateArea(Area area) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'locations',
      {
        'name': area.name,
        'description': area.description,
        'photo_path': area.photoPath,
        'maps_location': area.mapsLocation,
        'color': area.color,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [area.id],
    );

    // Keep legacy table updated
    try {
      await db.update(
        'areas',
        {...area.toMap(), 'updated_at': now},
        where: 'id = ?',
        whereArgs: [area.id],
      );
    } catch (_) {}
  }

  Future<void> deleteArea(String id) async {
    final db = await _db;

    // Find all streets belonging to this area
    final streets = await db.query('locations',
        columns: ['id'], where: 'parent_location_id = ?', whereArgs: [id]);
    final streetIds = streets.map((s) => s['id'] as String).toList();

    if (streetIds.isNotEmpty) {
      final placeholders = List.filled(streetIds.length, '?').join(',');
      await db.update(
        'customers',
        {'street_id': '', 'location_id': ''},
        where: "street_id IN ($placeholders) OR location_id IN ($placeholders)",
        whereArgs: [...streetIds, ...streetIds],
      );
    }

    // Clear area itself
    await db.update(
      'customers',
      {'street_id': '', 'location_id': ''},
      where: 'location_id = ?',
      whereArgs: [id],
    );

    await db.delete('locations', where: 'id = ?', whereArgs: [id]);

    // Also delete from legacy table
    try {
      await db.delete('areas', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }
}
