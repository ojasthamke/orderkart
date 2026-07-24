class AppVisit {
  final String id;
  final String date;
  final String areaId;
  final String streetId;
  final String notes;
  final int priority;
  final String status;
  final DateTime createdAt;
  final String areaName;
  final String streetName;

  AppVisit({
    required this.id,
    required this.date,
    required this.areaId,
    this.streetId = '',
    this.notes = '',
    this.priority = 0,
    required this.status,
    required this.createdAt,
    this.areaName = '',
    this.streetName = '',
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
    String? areaName,
    String? streetName,
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
      areaName: areaName ?? this.areaName,
      streetName: streetName ?? this.streetName,
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
      id: map['id'] as String? ?? '',
      date: map['date'] as String? ?? '',
      areaId: (map['area_id'] ?? map['location_id']) as String? ?? '',
      streetId: map['street_id'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      priority: map['priority'] as int? ?? 0,
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      areaName: map['area_name'] as String? ?? '',
      streetName: map['street_name'] as String? ?? '',
    );
  }
}
