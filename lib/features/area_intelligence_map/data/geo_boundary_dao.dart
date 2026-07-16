import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../domain/geo_boundary.dart';

class GeoBoundaryDao {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<List<GeoBoundary>> getBoundariesForLocation(String locationId) async {
    final db = await _db;
    final boundaryMaps = await db.query(
      'geo_boundaries',
      where: 'location_id = ?',
      whereArgs: [locationId],
    );

    final list = <GeoBoundary>[];
    for (final map in boundaryMaps) {
      final boundaryId = map['id'] as String;
      final pointMaps = await db.query(
        'geo_boundary_points',
        where: 'boundary_id = ?',
        whereArgs: [boundaryId],
        orderBy: 'sequence ASC',
      );
      final points = pointMaps.map((p) => GeoBoundaryPoint.fromMap(p)).toList();
      list.add(GeoBoundary.fromMap(map, points));
    }
    return list;
  }

  Future<List<GeoBoundary>> getBoundariesForAreaSubtree(String areaId) async {
    final db = await _db;
    // Get all boundaries for locations in the area subtree or the area itself
    final locations = await db.rawQuery(
      '''
      SELECT id FROM locations 
      WHERE id = ? OR materialized_path LIKE ?
      ''',
      [areaId, '/$areaId/%'],
    );
    final ids = locations.map((l) => l['id'] as String).toList();
    if (ids.isEmpty) return [];

    final placeholders = List.filled(ids.length, '?').join(',');
    final boundaryMaps = await db.query(
      'geo_boundaries',
      where: 'location_id IN ($placeholders)',
      whereArgs: ids,
    );

    final list = <GeoBoundary>[];
    for (final map in boundaryMaps) {
      final boundaryId = map['id'] as String;
      final pointMaps = await db.query(
        'geo_boundary_points',
        where: 'boundary_id = ?',
        whereArgs: [boundaryId],
        orderBy: 'sequence ASC',
      );
      final points = pointMaps.map((p) => GeoBoundaryPoint.fromMap(p)).toList();
      list.add(GeoBoundary.fromMap(map, points));
    }
    return list;
  }

  Future<void> insertBoundary(GeoBoundary boundary) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(
        'geo_boundaries',
        boundary.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // delete old points if any
      await txn.delete(
        'geo_boundary_points',
        where: 'boundary_id = ?',
        whereArgs: [boundary.id],
      );

      for (int i = 0; i < boundary.points.length; i++) {
        final pt = boundary.points[i].copyWith(
          boundaryId: boundary.id,
          sequence: i,
        );
        await txn.insert('geo_boundary_points', pt.toMap());
      }
    });
  }

  Future<void> updateBoundary(GeoBoundary boundary) async {
    await insertBoundary(boundary);
  }

  Future<void> deleteBoundary(String id) async {
    final db = await _db;
    await db.delete('geo_boundaries', where: 'id = ?', whereArgs: [id]);
  }
}
