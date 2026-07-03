import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../domain/app_visit.dart';

class VisitDao {
  static const String tableName = 'visits';

  Future<Database> get db async => await DatabaseHelper.instance.database;

  Future<int> insert(AppVisit visit) async {
    final database = await db;
    return await database.insert(
      tableName,
      visit.toMap(),
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
    final List<Map<String, dynamic>> maps = await database.query(
      tableName,
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'priority DESC, created_at ASC',
    );

    return List.generate(maps.length, (i) {
      return AppVisit.fromMap(maps[i]);
    });
  }

  Future<List<AppVisit>> getAllVisits() async {
    final database = await db;
    final List<Map<String, dynamic>> maps = await database.query(
      tableName,
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return AppVisit.fromMap(maps[i]);
    });
  }
}
