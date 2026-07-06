import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../domain/expense.dart';

class ExpenseDao {
  final _uuid = const Uuid();
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Expense>> getAllExpenses({
    String? searchQuery,
    String? category,
    String? month, // 'YYYY-MM'
  }) async {
    final db = await _db;
    List<String> conditions = [];
    List<dynamic> args = [];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('(name LIKE ? OR notes LIKE ?)');
      final q = '%${searchQuery.trim()}%';
      args.addAll([q, q]);
    }
    if (category != null && category.isNotEmpty) {
      conditions.add('category = ?');
      args.add(category);
    }
    if (month != null && month.isNotEmpty) {
      conditions.add("strftime('%Y-%m', date) = ?");
      args.add(month);
    }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final maps = await db.query(
      'expenses',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC',
    );
    return maps.map(Expense.fromMap).toList();
  }

  Future<Expense?> getExpenseById(String id) async {
    final db = await _db;
    final maps = await db.query('expenses', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Expense.fromMap(maps.first);
  }

  Future<List<Map<String, dynamic>>> getMonthlySummary() async {
    final db = await _db;
    final maps = await db.rawQuery('''
      SELECT strftime('%Y-%m', date) AS month,
             COALESCE(SUM(amount), 0) AS total,
             COUNT(*) AS count
      FROM expenses
      GROUP BY strftime('%Y-%m', date)
      ORDER BY month DESC
      LIMIT 12
    ''');
    return List<Map<String, dynamic>>.from(maps);
  }

  Future<String> insertExpense(Expense expense) async {
    final db = await _db;
    final id  = expense.id.isEmpty ? _uuid.v4() : expense.id;
    final now = DateTime.now().toIso8601String();
    final map = expense.toMap();

    await db.insert('expenses', {
      ...map,
      'id':         id,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<void> updateExpense(Expense expense) async {
    final db = await _db;
    await db.update(
      'expenses',
      {...expense.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<void> deleteExpense(String id) async {
    final db = await _db;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }
}
