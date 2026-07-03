import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../domain/app_note.dart';

class NoteDao {
  static const String tableName = 'notes';

  Future<Database> get db async => await DatabaseHelper.instance.database;

  Future<int> insert(AppNote note) async {
    final database = await db;
    return await database.insert(
      tableName,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(AppNote note) async {
    final database = await db;
    return await database.update(
      tableName,
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
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

  Future<List<AppNote>> getNotes({bool includeArchived = false}) async {
    final database = await db;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (!includeArchived) {
      whereClause = 'is_archived = ?';
      whereArgs = [0];
    }

    final List<Map<String, dynamic>> maps = await database.query(
      tableName,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'is_pinned DESC, created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return AppNote.fromMap(maps[i]);
    });
  }
}
