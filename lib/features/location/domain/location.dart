import 'location_kind.dart';

class Location {
  final String id;
  final String? parentLocationId;
  final String name;
  final String description;
  final LocationKind locationKind;
  final String sequenceKey;
  final int depth;
  final String materializedPath;
  final String photoPath;
  final String mapsLocation;
  final int color;
  final String createdBy;
  final String assignedWorkerId;
  final String workerName;
  final String deviceName;
  final bool isArchived;
  final double latitude;
  final double longitude;
  final String iconName;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Aggregation/Computed attributes
  final int childCount;
  final int customerCount;
  final int orderCount;
  final double totalRevenue;

  const Location({
    required this.id,
    this.parentLocationId,
    required this.name,
    this.description = '',
    required this.locationKind,
    required this.sequenceKey,
    this.depth = 0,
    this.materializedPath = '',
    this.photoPath = '',
    this.mapsLocation = '',
    this.color = 0xFF1565C0,
    this.createdBy = 'owner',
    this.assignedWorkerId = '',
    this.workerName = '',
    this.deviceName = '',
    this.isArchived = false,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.iconName = '',
    required this.createdAt,
    required this.updatedAt,
    this.childCount = 0,
    this.customerCount = 0,
    this.orderCount = 0,
    this.totalRevenue = 0.0,
  });

  Location copyWith({
    String? id,
    String? parentLocationId,
    String? name,
    String? description,
    LocationKind? locationKind,
    String? sequenceKey,
    int? depth,
    String? materializedPath,
    String? photoPath,
    String? mapsLocation,
    int? color,
    String? createdBy,
    String? assignedWorkerId,
    String? workerName,
    String? deviceName,
    bool? isArchived,
    double? latitude,
    double? longitude,
    String? iconName,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? childCount,
    int? customerCount,
    int? orderCount,
    double? totalRevenue,
  }) {
    return Location(
      id: id ?? this.id,
      parentLocationId: parentLocationId ?? this.parentLocationId,
      name: name ?? this.name,
      description: description ?? this.description,
      locationKind: locationKind ?? this.locationKind,
      sequenceKey: sequenceKey ?? this.sequenceKey,
      depth: depth ?? this.depth,
      materializedPath: materializedPath ?? this.materializedPath,
      photoPath: photoPath ?? this.photoPath,
      mapsLocation: mapsLocation ?? this.mapsLocation,
      color: color ?? this.color,
      createdBy: createdBy ?? this.createdBy,
      assignedWorkerId: assignedWorkerId ?? this.assignedWorkerId,
      workerName: workerName ?? this.workerName,
      deviceName: deviceName ?? this.deviceName,
      isArchived: isArchived ?? this.isArchived,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      childCount: childCount ?? this.childCount,
      customerCount: customerCount ?? this.customerCount,
      orderCount: orderCount ?? this.orderCount,
      totalRevenue: totalRevenue ?? this.totalRevenue,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'parent_location_id': parentLocationId,
        'name': name,
        'description': description,
        'location_kind': locationKind.name,
        'sequence_key': sequenceKey,
        'depth': depth,
        'materialized_path': materializedPath,
        'photo_path': photoPath,
        'maps_location': mapsLocation,
        'color': color,
        'created_by': createdBy,
        'assigned_worker_id': assignedWorkerId,
        'worker_name': workerName,
        'device_name': deviceName,
        'is_archived': isArchived ? 1 : 0,
        'latitude': latitude,
        'longitude': longitude,
        'icon_name': iconName,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Location.fromMap(Map<String, dynamic> map) => Location(
        id: map['id'] as String? ?? '',
        parentLocationId: map['parent_location_id'] as String?,
        name: map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
        locationKind:
            LocationKind.fromString(map['location_kind'] as String? ?? 'area'),
        sequenceKey: map['sequence_key'] as String? ?? '',
        depth: map['depth'] as int? ?? 0,
        materializedPath: map['materialized_path'] as String? ?? '',
        photoPath: map['photo_path'] as String? ?? '',
        mapsLocation: map['maps_location'] as String? ?? '',
        color: map['color'] as int? ?? 0xFF1565C0,
        createdBy: map['created_by'] as String? ?? 'owner',
        assignedWorkerId:
            (map['assigned_worker_id'] ?? map['worker_id']) as String? ?? '',
        workerName: map['worker_name'] as String? ?? '',
        deviceName: map['device_name'] as String? ?? '',
        isArchived: (map['is_archived'] as int? ?? 0) == 1,
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
        iconName: map['icon_name'] as String? ?? '',
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
            DateTime.now(),
        childCount: map['child_count'] as int? ?? 0,
        customerCount: map['customer_count'] as int? ?? 0,
        orderCount: map['order_count'] as int? ?? 0,
        totalRevenue: (map['total_revenue'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  bool operator ==(Object other) => other is Location && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
