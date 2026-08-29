import 'dart:convert';

class Area {
  final String id;
  final String name;
  final String description;
  final int color; // stored as int (Colors.blue.value)
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
  final double latitude;
  final double longitude;

  // New fields for delivery schedule & settings
  final List<String> deliverySchedule;
  final String cutoffTime;
  final double deliveryCharge;
  final double minOrderAmount;
  final bool isActive;

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
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.streetCount = 0,
    this.customerCount = 0,
    this.orderCount = 0,
    this.totalRevenue = 0,
    this.deliverySchedule = const [],
    this.cutoffTime = '23:59',
    this.deliveryCharge = 0.0,
    this.minOrderAmount = 0.0,
    this.isActive = true,
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
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? streetCount,
    int? customerCount,
    int? orderCount,
    double? totalRevenue,
    List<String>? deliverySchedule,
    String? cutoffTime,
    double? deliveryCharge,
    double? minOrderAmount,
    bool? isActive,
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
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      streetCount: streetCount ?? this.streetCount,
      customerCount: customerCount ?? this.customerCount,
      orderCount: orderCount ?? this.orderCount,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      deliverySchedule: deliverySchedule ?? this.deliverySchedule,
      cutoffTime: cutoffTime ?? this.cutoffTime,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'color': color,
        'photo_path': photoPath,
        'maps_location': mapsLocation,
        'created_by': createdBy,
        'assigned_worker_id': assignedWorkerId,
        'worker_name': workerName,
        'device_name': deviceName,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'delivery_schedule': json.encode(deliverySchedule),
        'cutoff_time': cutoffTime,
        'delivery_charge': deliveryCharge,
        'min_order_amount': minOrderAmount,
        'is_active': isActive ? 1 : 0,
      };

  factory Area.fromMap(Map<String, dynamic> map) {
    List<String> sched = [];
    if (map['delivery_schedule'] != null) {
      try {
        final decoded = json.decode(map['delivery_schedule'] as String);
        if (decoded is List) {
          sched = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return Area(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      color: map['color'] as int? ?? 0xFF1565C0,
      photoPath: map['photo_path'] as String? ?? '',
      mapsLocation: map['maps_location'] as String? ?? '',
      createdBy: map['created_by'] as String? ?? 'owner',
      assignedWorkerId: (map['assigned_worker_id'] ?? map['worker_id']) as String? ?? '',
      workerName: map['worker_name'] as String? ?? '',
      deviceName: map['device_name'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      streetCount: map['street_count'] as int? ?? 0,
      customerCount: map['customer_count'] as int? ?? 0,
      orderCount: map['order_count'] as int? ?? 0,
      totalRevenue: (map['total_revenue'] as num?)?.toDouble() ?? 0,
      deliverySchedule: sched,
      cutoffTime: map['cutoff_time'] as String? ?? '23:59',
      deliveryCharge: (map['delivery_charge'] as num?)?.toDouble() ?? 0.0,
      minOrderAmount: (map['min_order_amount'] as num?)?.toDouble() ?? 0.0,
      isActive: (map['is_active'] == null || map['is_active'] == 1 || map['is_active'] == true),
    );
  }

  @override
  bool operator ==(Object other) => other is Area && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
