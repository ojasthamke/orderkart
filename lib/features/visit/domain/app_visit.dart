class AppVisit {
  final String id;
  final String date;
  final String areaId;
  final String streetId;
  final String notes;
  final int priority;
  final String status;
  final DateTime createdAt;

  AppVisit({
    required this.id,
    required this.date,
    required this.areaId,
    this.streetId = '',
    this.notes = '',
    this.priority = 0,
    required this.status,
    required this.createdAt,
  });

  AppVisit copyWith({
    String? id,
    String? date,
    String? areaId,
    String? streetId,
    String? notes,
    int? priority,
    String? status,
    DateTime? createdAt,
  }) {
    return AppVisit(
      id: id ?? this.id,
      date: date ?? this.date,
      areaId: areaId ?? this.areaId,
      streetId: streetId ?? this.streetId,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'area_id': areaId,
      'street_id': streetId,
      'notes': notes,
      'priority': priority,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AppVisit.fromMap(Map<String, dynamic> map) {
    return AppVisit(
      id: map['id'] as String,
      date: map['date'] as String,
      areaId: map['area_id'] as String,
      streetId: map['street_id'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      priority: map['priority'] as int? ?? 0,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
