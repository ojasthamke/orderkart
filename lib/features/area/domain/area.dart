/// Area Model — top-level geographic grouping

class Area {
  final String id;
  final String name;
  final String description;
  final int color;           // stored as int (Colors.blue.value)
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed fields (from JOINs / aggregation)
  final int streetCount;
  final int customerCount;
  final int orderCount;
  final double totalRevenue;

  final String photoPath;
  final String mapsLocation;
  final String createdBy;
  final String assignedWorkerId;
  final String workerName;
  final String deviceName;

  const Area({
    required this.id,
    required this.name,
    this.description = '',
    this.color = 0xFF1565C0,
    this.photoPath = '',
    this.mapsLocation = '',
    this.createdBy = 'owner',
    this.assignedWorkerId = '',
    this.workerName = '',
    this.deviceName = '',
    required this.createdAt,
    required this.updatedAt,
    this.streetCount = 0,
    this.customerCount = 0,
    this.orderCount = 0,
    this.totalRevenue = 0,
  });

  Area copyWith({
    String? id,
    String? name,
    String? description,
    int? color,
    String? photoPath,
    String? mapsLocation,
    String? createdBy,
    String? assignedWorkerId,
    String? workerName,
    String? deviceName,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? streetCount,
    int? customerCount,
    int? orderCount,
    double? totalRevenue,
  }) {
    return Area(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      photoPath: photoPath ?? this.photoPath,
      mapsLocation: mapsLocation ?? this.mapsLocation,
      createdBy: createdBy ?? this.createdBy,
      assignedWorkerId: assignedWorkerId ?? this.assignedWorkerId,
      workerName: workerName ?? this.workerName,
      deviceName: deviceName ?? this.deviceName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      streetCount: streetCount ?? this.streetCount,
      customerCount: customerCount ?? this.customerCount,
      orderCount: orderCount ?? this.orderCount,
      totalRevenue: totalRevenue ?? this.totalRevenue,
    );
  }

  Map<String, dynamic> toMap() => {
        'id':                 id,
        'name':               name,
        'description':        description,
        'color':              color,
        'photo_path':         photoPath,
        'maps_location':      mapsLocation,
        'created_by':         createdBy,
        'assigned_worker_id': assignedWorkerId,
        'worker_name':        workerName,
        'device_name':        deviceName,
        'created_at':         createdAt.toIso8601String(),
        'updated_at':         updatedAt.toIso8601String(),
      };

  factory Area.fromMap(Map<String, dynamic> map) => Area(
        id:               map['id'] as String,
        name:             map['name'] as String,
        description:      map['description'] as String? ?? '',
        color:            map['color'] as int? ?? 0xFF1565C0,
        photoPath:        map['photo_path'] as String? ?? '',
        mapsLocation:     map['maps_location'] as String? ?? '',
        createdBy:        map['created_by'] as String? ?? 'owner',
        assignedWorkerId: (map['assigned_worker_id'] ?? map['worker_id']) as String? ?? '',
        workerName:       map['worker_name'] as String? ?? '',
        deviceName:       map['device_name'] as String? ?? '',
        createdAt:        DateTime.parse(map['created_at'] as String),
        updatedAt:        DateTime.parse(map['updated_at'] as String),
        streetCount:      map['street_count']   as int?    ?? 0,
        customerCount:    map['customer_count'] as int?    ?? 0,
        orderCount:       map['order_count']    as int?    ?? 0,
        totalRevenue:     (map['total_revenue'] as num?)?.toDouble() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is Area && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
