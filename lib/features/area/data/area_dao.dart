/// AreaDao — SQLite operations for Areas table
/// Includes statistics aggregation via JOINs
library;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/security/app_mode_service.dart';
import '../domain/area.dart';

class AreaDao {
  final _uuid = const Uuid();

  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Fetch all areas with optional search and sorting.
  /// Includes aggregated street_count, customer_count, order_count via subqueries.
  Future<List<Area>> getAllAreas({String? searchQuery, String? sortBy}) async {
    final db = await _db;

    String orderClause = 'a.name ASC';
    if (sortBy == 'date')          orderClause = 'a.created_at DESC';
    if (sortBy == 'street_count')  orderClause = 'street_count DESC';
    if (sortBy == 'customer_count')orderClause = 'customer_count DESC';

    List<String> whereClauses = ['a.is_archived = 0'];
    List<dynamic> args = [];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('a.name LIKE ?');
      args.add('%${searchQuery.trim()}%');
    }

    final mode = await AppModeService.getAppMode();
    if (mode == AppMode.worker) {
      final settingsRes = await db.query('settings', where: 'key = ?', whereArgs: ['active_worker_id']);
      String? workerId = settingsRes.isNotEmpty ? settingsRes.first['value']?.toString() : null;
      if (workerId == null || workerId.isEmpty) {
        final workerRows = await db.query('workers', limit: 1);
        if (workerRows.isNotEmpty) {
          workerId = workerRows.first['id'] as String;
        }
      }

      if (workerId != null && workerId.isNotEmpty) {
        final assignmentRows = await db.query(
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
        whereClauses.add('(a.id IN ($placeholders) OR a.created_by = ? OR a.assigned_worker_id = ?)');
        if (assignedAreaIds.isNotEmpty) {
          args.addAll(assignedAreaIds);
        }
        args.addAll([workerId, workerId]);
      } else {
        return [];
      }
    }

    final whereClauseSection = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    final maps = await db.rawQuery('''
      SELECT
        a.*,
        (SELECT COUNT(*) FROM streets s WHERE s.area_id = a.id) AS street_count,
        (SELECT COUNT(*) FROM customers c
          JOIN streets st ON c.street_id = st.id
          WHERE st.area_id = a.id) AS customer_count,
        (SELECT COUNT(*) FROM orders o
          JOIN customers cust ON o.customer_id = cust.id
          JOIN streets st ON cust.street_id = st.id
          WHERE st.area_id = a.id) AS order_count,
        (SELECT COALESCE(SUM(o.grand_total), 0) FROM orders o
          JOIN customers cust ON o.customer_id = cust.id
          JOIN streets st ON cust.street_id = st.id
          WHERE st.area_id = a.id) AS total_revenue
      FROM areas a
      $whereClauseSection
      ORDER BY $orderClause
    ''', args);

    return maps.map(Area.fromMap).toList();
  }

  Future<Area?> getAreaById(String id) async {
    final db = await _db;
    final maps = await db.query('areas', where: 'id = ?', whereArgs: [id]);
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
          'entity_type': 'area',
          'entity_id': id,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    final map = area.toMap();
    await db.insert('areas', {
      ...map,
      'id':         id,
      'created_by': createdBy,
      'assigned_worker_id': assignedWorkerId,
      'worker_name': workerName,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<void> updateArea(Area area) async {
    final db = await _db;
    await db.update(
      'areas',
      {...area.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [area.id],
    );
  }

  Future<void> deleteArea(String id) async {
    final db = await _db;
    // CASCADE on streets → customers → orders ensures clean deletion
    await db.delete('areas', where: 'id = ?', whereArgs: [id]);
  }
}
