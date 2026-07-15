import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/sequence_key_helper.dart';
import '../domain/location.dart';

class LocationDao {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  /// Fetch all locations with search, sorting, and parenting filters.
  Future<List<Location>> getAllLocations({
    String? searchQuery,
    String? parentId,
    String? sortBy,
    bool showArchived = false,
  }) async {
    final db = await _db;
    
    // Base query using dynamic subqueries for computed fields to match legacy stats behavior
    String sql = '''
      SELECT l.*,
        (SELECT COUNT(*) FROM locations c WHERE c.parent_location_id = l.id AND c.is_archived = 0) AS child_count,
        (SELECT COUNT(*) FROM customers cust WHERE cust.location_id = l.id) AS customer_count,
        (SELECT COUNT(*) FROM orders o JOIN customers cust ON o.customer_id = cust.id WHERE cust.location_id = l.id) AS order_count,
        COALESCE((SELECT SUM(o.grand_total) FROM orders o JOIN customers cust ON o.customer_id = cust.id WHERE cust.location_id = l.id), 0.0) AS total_revenue
      FROM locations l
      WHERE 1=1
    ''';

    final List<dynamic> args = [];

    // Parenting filter
    if (parentId == null) {
      sql += ' AND l.parent_location_id IS NULL';
    } else {
      sql += ' AND l.parent_location_id = ?';
      args.add(parentId);
    }

    // Archived filter
    if (!showArchived) {
      sql += ' AND l.is_archived = 0';
    }

    // Search query filter
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      sql += ' AND l.name LIKE ?';
      args.add('%${searchQuery.trim()}%');
    }

    // Order By sorting
    String orderBy = 'l.sequence_key ASC';
    if (sortBy != null) {
      switch (sortBy) {
        case 'name':
          orderBy = 'l.name COLLATE NOCASE ASC';
          break;
        case 'date':
          orderBy = 'l.created_at DESC';
          break;
        case 'child_count':
          orderBy = 'child_count DESC';
          break;
        case 'customer_count':
          orderBy = 'customer_count DESC';
          break;
      }
    }
    sql += ' ORDER BY $orderBy';

    final maps = await db.rawQuery(sql, args);
    return maps.map((m) => Location.fromMap(m)).toList();
  }

  /// Get a single location by ID.
  Future<Location?> getLocationById(String id) async {
    final db = await _db;
    const sql = '''
      SELECT l.*,
        (SELECT COUNT(*) FROM locations c WHERE c.parent_location_id = l.id AND c.is_archived = 0) AS child_count,
        (SELECT COUNT(*) FROM customers cust WHERE cust.location_id = l.id) AS customer_count,
        (SELECT COUNT(*) FROM orders o JOIN customers cust ON o.customer_id = cust.id WHERE cust.location_id = l.id) AS order_count,
        COALESCE((SELECT SUM(o.grand_total) FROM orders o JOIN customers cust ON o.customer_id = cust.id WHERE cust.location_id = l.id), 0.0) AS total_revenue
      FROM locations l
      WHERE l.id = ?
    ''';
    final maps = await db.rawQuery(sql, [id]);
    if (maps.isEmpty) return null;
    return Location.fromMap(maps.first);
  }

  /// Insert a new location.
  Future<String> insertLocation(Location location) async {
    final db = await _db;
    
    // Resolve depth and path based on parent
    int depth = 0;
    String materializedPath = '/${location.id}/';

    if (location.parentLocationId != null) {
      final parent = await getLocationById(location.parentLocationId!);
      if (parent != null) {
        depth = parent.depth + 1;
        materializedPath = '${parent.materializedPath}${location.id}/';
      }
    }

    final toInsert = location.copyWith(
      depth: depth,
      materializedPath: materializedPath,
    );

    await db.insert('locations', toInsert.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    
    // For compatibility with legacy database backup/export triggers
    // and foreign key constraints on customer/visits tables,
    // we also synchronize into legacy areas/streets tables.
    try {
      if (location.parentLocationId == null) {
        await db.insert('areas', {
          'id': location.id,
          'name': location.name,
          'description': location.description,
          'photo_path': location.photoPath,
          'maps_location': location.mapsLocation,
          'color': location.color,
          'created_by': location.createdBy,
          'assigned_worker_id': location.assignedWorkerId,
          'worker_name': location.workerName,
          'device_name': location.deviceName,
          'created_at': location.createdAt.toIso8601String(),
          'updated_at': location.updatedAt.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        // Find root area ID by walking up the parent chain
        String rootAreaId = location.parentLocationId!;
        String? currentParentId = rootAreaId;
        int maxDepth = 20;
        while (currentParentId != null && maxDepth-- > 0) {
          final parentRows = await db.query('locations', columns: ['id', 'parent_location_id'], where: 'id = ?', whereArgs: [currentParentId], limit: 1);
          if (parentRows.isEmpty) break;
          final nextParent = parentRows.first['parent_location_id'] as String?;
          if (nextParent == null) {
            rootAreaId = parentRows.first['id'] as String;
            break;
          }
          currentParentId = nextParent;
        }

        await db.insert('streets', {
          'id': location.id,
          'area_id': rootAreaId,
          'name': location.name,
          'description': location.description,
          'photo_path': location.photoPath,
          'maps_location': location.mapsLocation,
          'created_by': location.createdBy,
          'assigned_worker_id': location.assignedWorkerId,
          'worker_name': location.workerName,
          'device_name': location.deviceName,
          'created_at': location.createdAt.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (_) {
      // Ignore write errors to deprecated tables (they are fallback only)
    }

    return location.id;
  }

  /// Update a location and rebuild child paths if parent changed.
  Future<void> updateLocation(Location location) async {
    final db = await _db;
    
    // Check if parent changed to rebuild materialized path
    final oldLoc = await getLocationById(location.id);
    Location updated = location;

    if (oldLoc != null && oldLoc.parentLocationId != location.parentLocationId) {
      int depth = 0;
      String path = '/${location.id}/';
      if (location.parentLocationId != null) {
        final parent = await getLocationById(location.parentLocationId!);
        if (parent != null) {
          depth = parent.depth + 1;
          path = '${parent.materializedPath}${location.id}/';
        }
      }
      updated = location.copyWith(depth: depth, materializedPath: path);
      
      // Update child materialized paths recursively
      await db.transaction((txn) async {
        await txn.update('locations', updated.toMap(), where: 'id = ?', whereArgs: [location.id]);
        
        final children = await txn.query('locations', where: 'parent_location_id = ?', whereArgs: [location.id]);
        for (final childMap in children) {
          final child = Location.fromMap(childMap);
          final newChildPath = '$path${child.id}/';
          final newChildDepth = depth + 1;
          await txn.update(
            'locations',
            {'materialized_path': newChildPath, 'depth': newChildDepth},
            where: 'id = ?',
            whereArgs: [child.id],
          );
        }
      });
    } else {
      await db.update('locations', updated.toMap(), where: 'id = ?', whereArgs: [location.id]);
    }

    // Keep legacy tables synchronized
    try {
      if (location.parentLocationId == null) {
        await db.update('areas', {
          'name': location.name,
          'description': location.description,
          'photo_path': location.photoPath,
          'maps_location': location.mapsLocation,
          'updated_at': location.updatedAt.toIso8601String(),
        }, where: 'id = ?', whereArgs: [location.id]);
      } else {
        // Find root area ID by walking up the parent chain
        String rootAreaId = location.parentLocationId!;
        String? currentParentId = rootAreaId;
        int maxDepth = 20;
        while (currentParentId != null && maxDepth-- > 0) {
          final parentRows = await db.query('locations', columns: ['id', 'parent_location_id'], where: 'id = ?', whereArgs: [currentParentId], limit: 1);
          if (parentRows.isEmpty) break;
          final nextParent = parentRows.first['parent_location_id'] as String?;
          if (nextParent == null) {
            rootAreaId = parentRows.first['id'] as String;
            break;
          }
          currentParentId = nextParent;
        }

        await db.update('streets', {
          'area_id': rootAreaId,
          'name': location.name,
          'description': location.description,
          'photo_path': location.photoPath,
          'maps_location': location.mapsLocation,
        }, where: 'id = ?', whereArgs: [location.id]);
      }
    } catch (_) {}
  }

  /// Delete a location.
  Future<void> deleteLocation(String id) async {
    final db = await _db;
    await db.delete('locations', where: 'id = ?', whereArgs: [id]);
    
    // Also delete from legacy tables if present
    try {
      await db.delete('areas', where: 'id = ?', whereArgs: [id]);
      await db.delete('streets', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  /// Fetch full hierarchical breadcrumb path for a given location ID.
  Future<List<Location>> getBreadcrumbs(String locationId) async {
    final list = <Location>[];
    String? currentId = locationId;

    while (currentId != null) {
      final loc = await getLocationById(currentId);
      if (loc == null) break;
      list.insert(0, loc);
      currentId = loc.parentLocationId;
    }

    return list;
  }

  /// Helper to get the neighboring sibling sequence key and calculate midpoint.
  Future<String> getNextSequenceKey(String? parentId, {String? afterId, String? beforeId}) async {
    final db = await _db;
    String? prevKey;
    String? nextKey;

    if (afterId != null && afterId.isNotEmpty) {
      final maps = await db.query('locations', columns: ['sequence_key'], where: 'id = ?', whereArgs: [afterId]);
      if (maps.isNotEmpty) prevKey = maps.first['sequence_key'] as String?;
    }

    if (beforeId != null && beforeId.isNotEmpty) {
      final maps = await db.query('locations', columns: ['sequence_key'], where: 'id = ?', whereArgs: [beforeId]);
      if (maps.isNotEmpty) nextKey = maps.first['sequence_key'] as String?;
    }

    // Fallback: If no neighboring sibling specified, get the last sibling's sequence key to append at the end
    if (prevKey == null && nextKey == null) {
      final List<Map<String, dynamic>> maps;
      if (parentId == null) {
        maps = await db.query('locations', columns: ['sequence_key'], where: 'parent_location_id IS NULL', orderBy: 'sequence_key DESC', limit: 1);
      } else {
        maps = await db.query('locations', columns: ['sequence_key'], where: 'parent_location_id = ?', whereArgs: [parentId], orderBy: 'sequence_key DESC', limit: 1);
      }
      if (maps.isNotEmpty) {
        prevKey = maps.first['sequence_key'] as String?;
      }
    }

    return SequenceKeyHelper.generateBetween(prevKey, nextKey);
  }

  /// Get count of customers under this location.
  Future<int> getCustomerCount(String locationId, {bool recursive = false}) async {
    final db = await _db;
    if (!recursive) {
      final res = await db.rawQuery('SELECT COUNT(*) FROM customers WHERE location_id = ?', [locationId]);
      return Sqflite.firstIntValue(res) ?? 0;
    } else {
      // Recursive: get path of this location to query matching materialized path
      final loc = await getLocationById(locationId);
      if (loc == null) return 0;
      final pathPattern = '${loc.materializedPath}%';
      final res = await db.rawQuery(
        'SELECT COUNT(*) FROM customers WHERE location_id IN ('
        'SELECT id FROM locations WHERE materialized_path LIKE ?'
        ')',
        [pathPattern],
      );
      return Sqflite.firstIntValue(res) ?? 0;
    }
  }

  /// Get stats Map.
  Future<Map<String, dynamic>> getLocationStats(String locationId) async {
    final loc = await getLocationById(locationId);
    if (loc == null) {
      return {
        'childCount': 0,
        'customerCount': 0,
        'orderCount': 0,
        'totalRevenue': 0.0,
      };
    }
    return {
      'childCount': loc.childCount,
      'customerCount': loc.customerCount,
      'orderCount': loc.orderCount,
      'totalRevenue': loc.totalRevenue,
    };
  }
}
