import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';

class OrderQuestion {
  final String id;
  final String question;
  final List<String> options;
  final String? customerId;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderQuestion({
    required this.id,
    required this.question,
    required this.options,
    this.customerId,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'question': question,
        'options': jsonEncode(options),
        'customer_id': customerId,
        'is_archived': isArchived ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory OrderQuestion.fromMap(Map<String, dynamic> map) {
    List<String> parsedOptions = [];
    try {
      final optsJson = map['options'] as String? ?? '[]';
      parsedOptions = List<String>.from(jsonDecode(optsJson));
    } catch (_) {}

    return OrderQuestion(
      id: map['id'] as String,
      question: map['question'] as String,
      options: parsedOptions,
      customerId: map['customer_id'] as String?,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class OrderQuestionDao {
  OrderQuestionDao._();
  static final OrderQuestionDao instance = OrderQuestionDao._();

  Future<void> addQuestion(String question, List<String> options, {String? customerId}) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final q = OrderQuestion(
      id: const Uuid().v4(),
      question: question,
      options: options,
      customerId: customerId,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('order_questions', q.toMap());
  }

  Future<void> updateQuestion(String id, String question, List<String> options) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    await db.update(
      'order_questions',
      {
        'question': question,
        'options': jsonEncode(options),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteQuestion(String id) async {
    final db = await DatabaseHelper.instance.database;
    // Mark as archived instead of hard delete to preserve historical integrity
    await db.update(
      'order_questions',
      {'is_archived': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<OrderQuestion>> getCommonQuestions() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'order_questions',
      where: 'is_archived = 0 AND (customer_id IS NULL OR customer_id = ?)',
      whereArgs: [''],
      orderBy: 'created_at ASC',
    );
    return res.map((r) => OrderQuestion.fromMap(r)).toList();
  }

  Future<List<OrderQuestion>> getCustomerQuestions(String customerId) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'order_questions',
      where: 'is_archived = 0 AND customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at ASC',
    );
    return res.map((r) => OrderQuestion.fromMap(r)).toList();
  }

  Future<List<OrderQuestion>> getAllQuestionsForCustomer(String customerId) async {
    final commons = await getCommonQuestions();
    final specifics = await getCustomerQuestions(customerId);
    return [...commons, ...specifics];
  }

  Future<void> saveCustomerAnswer(String customerId, String questionId, String answer) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'customer_question_answers',
      {
        'customer_id': customerId,
        'question_id': questionId,
        'selected_option': answer,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getCustomerAnswers(String customerId) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'customer_question_answers',
      where: 'customer_id = ?',
      whereArgs: [customerId],
    );
    final map = <String, String>{};
    for (final row in res) {
      final qId = row['question_id']?.toString() ?? '';
      final ans = row['selected_option']?.toString() ?? '';
      if (qId.isNotEmpty) {
        map[qId] = ans;
      }
    }
    return map;
  }

  Future<void> saveOrderAnswers(String orderId, List<Map<String, dynamic>> answers) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      // Clear any existing answers first
      await txn.delete(
        'order_question_answers',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      for (final ans in answers) {
        await txn.insert(
          'order_question_answers',
          {
            'order_id': orderId,
            'question_id': ans['question_id'],
            'question_text': ans['question_text'],
            'selected_option': ans['selected_option'],
          },
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getOrderAnswers(String orderId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query(
      'order_question_answers',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }
}
