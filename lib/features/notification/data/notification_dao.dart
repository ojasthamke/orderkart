import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../domain/app_notification.dart';

class NotificationDao {
  static const String tableName = 'notifications';

  Future<Database> get db async => await DatabaseHelper.instance.database;

  Future<int> insert(AppNotification notification) async {
    final database = await db;
    return await database.insert(
      tableName,
      notification.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(AppNotification notification) async {
    final database = await db;
    return await database.update(
      tableName,
      notification.toMap(),
      where: 'id = ?',
      whereArgs: [notification.id],
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

  Future<int> deleteAll() async {
    final database = await db;
    return await database.delete(tableName);
  }

  Future<List<AppNotification>> getNotifications({
    int limit = 100,
    int offset = 0,
    String? category,
  }) async {
    final database = await db;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (category != null) {
      whereClause = 'category = ?';
      whereArgs = [category];
    }

    final List<Map<String, dynamic>> maps = await database.query(
      tableName,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) {
      return AppNotification.fromMap(maps[i]);
    });
  }

  Future<int> markAsRead(String id) async {
    final database = await db;
    return await database.update(
      tableName,
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markAllAsRead() async {
    final database = await db;
    return await database.update(
      tableName,
      {'is_read': 1},
    );
  }
}
