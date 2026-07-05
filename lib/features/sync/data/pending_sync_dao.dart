import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';

class PendingSyncItem {
  final String id;
  final String entityType; // 'customer', 'order', 'payment', 'expense', 'price'
  final String entityId;
  final String actionType; // 'created', 'updated', 'deleted'
  final String payloadJson;
  final DateTime createdAt;
  final String status; // 'pending', 'synced'

  const PendingSyncItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.actionType,
    required this.payloadJson,
    required this.createdAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'entity_type': entityType,
        'entity_id': entityId,
        'action_type': actionType,
        'payload_json': payloadJson,
        'created_at': createdAt.toIso8601String(),
        'status': status,
      };

  factory PendingSyncItem.fromMap(Map<String, dynamic> map) => PendingSyncItem(
        id: map['id'] as String,
        entityType: map['entity_type'] as String,
        entityId: map['entity_id'] as String,
        actionType: map['action_type'] as String,
        payloadJson: map['payload_json'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        status: map['status'] as String? ?? 'pending',
      );
}

class PendingSyncDao {
  final _uuid = const Uuid();
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<void> logPendingAction({
    required String entityType,
    required String entityId,
    required String actionType,
    String payloadJson = '{}',
  }) async {
    final db = await _db;
    await db.insert('pending_sync', {
      'id': _uuid.v4(),
      'entity_type': entityType,
      'entity_id': entityId,
      'action_type': actionType,
      'payload_json': payloadJson,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PendingSyncItem>> getPendingItems() async {
    final db = await _db;
    final maps = await db.query('pending_sync', where: 'status = ?', whereArgs: ['pending'], orderBy: 'created_at DESC');
    return maps.map(PendingSyncItem.fromMap).toList();
  }

  Future<int> getPendingCount() async {
    final db = await _db;
    final res = await db.rawQuery('SELECT COUNT(*) as v FROM pending_sync WHERE status = "pending"');
    return (res.first['v'] as num?)?.toInt() ?? 0;
  }

  Future<void> clearPendingQueue() async {
    final db = await _db;
    await db.delete('pending_sync', where: 'status = ?', whereArgs: ['pending']);
  }
}
