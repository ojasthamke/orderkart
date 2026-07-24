import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../location/domain/location.dart';

class MapDataDao {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<List<Location>> getSubLocations(String areaId) async {
    final db = await _db;
    final res = await db.rawQuery(
      '''
      SELECT l.*,
        (SELECT COUNT(*) FROM locations c WHERE c.parent_location_id = l.id AND c.is_archived = 0) AS child_count,
        (SELECT COUNT(*) FROM customers cust WHERE cust.location_id = l.id) AS customer_count,
        (SELECT COUNT(*) FROM orders o JOIN customers cust ON o.customer_id = cust.id WHERE cust.location_id = l.id) AS order_count,
        COALESCE((SELECT SUM(o.grand_total) FROM orders o JOIN customers cust ON o.customer_id = cust.id WHERE cust.location_id = l.id), 0.0) AS total_revenue
      FROM locations l
      WHERE l.id = ? OR l.materialized_path LIKE ?
      ''',
      [areaId, '/$areaId/%'],
    );
    return res.map((m) => Location.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> getCustomersWithPendingCount(
      String areaId) async {
    final db = await _db;
    final res = await db.rawQuery(
      '''
      SELECT c.*,
        (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.id AND o.delivery_status = 'pending') AS pending_delivery_count
      FROM customers c
      JOIN locations l ON c.location_id = l.id
      WHERE l.id = ? OR l.materialized_path LIKE ?
      ''',
      [areaId, '/$areaId/%'],
    );
    return res;
  }
}
