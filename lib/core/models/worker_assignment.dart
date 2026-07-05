// lib/core/models/worker_assignment.dart

/// Represents an assignment of a worker to an entity (area, street, customer, etc.)
class WorkerAssignment {
  final String id; // UUID primary key
  final String workerId;
  final String entityType; // e.g., 'area', 'street', 'customer'
  final String entityId; // ID of area, street, customer, etc.
  final DateTime createdAt;

  const WorkerAssignment({
    required this.id,
    required this.workerId,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
  });

  factory WorkerAssignment.fromMap(Map<String, dynamic> map) {
    return WorkerAssignment(
      id: map['id'] as String,
      workerId: map['worker_id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'worker_id': workerId,
        'entity_type': entityType,
        'entity_id': entityId,
        'created_at': createdAt.toIso8601String(),
      };
}
