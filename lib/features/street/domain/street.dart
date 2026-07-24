/// Street Model — belongs to an Area
library;

class Street {
  final String id;
  final String areaId;
  final String name;
  final String description;
  final DateTime createdAt;

  // Computed
  final int customerCount;

  final String photoPath;
  final String mapsLocation;
  final String createdBy;
  final String assignedWorkerId;
  final String workerName;
  final String deviceName;

  const Street({
    required this.id,
    required this.areaId,
    required this.name,
    this.description = '',
    this.photoPath = '',
    this.mapsLocation = '',
    this.createdBy = 'owner',
    this.assignedWorkerId = '',
    this.workerName = '',
    this.deviceName = '',
    required this.createdAt,
    this.customerCount = 0,
  });

  Street copyWith({
    String? id,
    String? areaId,
    String? name,
    String? description,
    String? photoPath,
    String? mapsLocation,
    String? createdBy,
    String? assignedWorkerId,
    String? workerName,
    String? deviceName,
    DateTime? createdAt,
    int? customerCount,
  }) {
    return Street(
      id: id ?? this.id,
      areaId: areaId ?? this.areaId,
      name: name ?? this.name,
      description: description ?? this.description,
      photoPath: photoPath ?? this.photoPath,
      mapsLocation: mapsLocation ?? this.mapsLocation,
      createdBy: createdBy ?? this.createdBy,
      assignedWorkerId: assignedWorkerId ?? this.assignedWorkerId,
      workerName: workerName ?? this.workerName,
      deviceName: deviceName ?? this.deviceName,
      createdAt: createdAt ?? this.createdAt,
      customerCount: customerCount ?? this.customerCount,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'area_id': areaId,
        'name': name,
        'description': description,
        'photo_path': photoPath,
        'maps_location': mapsLocation,
        'created_by': createdBy,
        'assigned_worker_id': assignedWorkerId,
        'worker_name': workerName,
        'device_name': deviceName,
        'created_at': createdAt.toIso8601String(),
      };

  factory Street.fromMap(Map<String, dynamic> map) => Street(
        id: map['id'] as String,
        areaId: map['area_id'] as String,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        photoPath: map['photo_path'] as String? ?? '',
        mapsLocation: map['maps_location'] as String? ?? '',
        createdBy: map['created_by'] as String? ?? 'owner',
        assignedWorkerId:
            (map['assigned_worker_id'] ?? map['worker_id']) as String? ?? '',
        workerName: map['worker_name'] as String? ?? '',
        deviceName: map['device_name'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
        customerCount: map['customer_count'] as int? ?? 0,
      );

  @override
  bool operator ==(Object other) => other is Street && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
