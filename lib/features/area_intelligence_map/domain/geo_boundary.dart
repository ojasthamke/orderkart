class GeoBoundary {
  final String id;
  final String locationId;
  final String geometryType; // 'polygon' or 'polyline'
  final int strokeColor;
  final int fillColor;
  final double strokeWidth;
  final String label;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<GeoBoundaryPoint> points;

  const GeoBoundary({
    required this.id,
    required this.locationId,
    required this.geometryType,
    this.strokeColor = 0xFF1565C0,
    this.fillColor = 0x261565C0,
    this.strokeWidth = 2.0,
    this.label = '',
    required this.createdAt,
    required this.updatedAt,
    this.points = const [],
  });

  GeoBoundary copyWith({
    String? id,
    String? locationId,
    String? geometryType,
    int? strokeColor,
    int? fillColor,
    double? strokeWidth,
    String? label,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<GeoBoundaryPoint>? points,
  }) {
    return GeoBoundary(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      geometryType: geometryType ?? this.geometryType,
      strokeColor: strokeColor ?? this.strokeColor,
      fillColor: fillColor ?? this.fillColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'location_id': locationId,
        'geometry_type': geometryType,
        'stroke_color': strokeColor,
        'fill_color': fillColor,
        'stroke_width': strokeWidth,
        'label': label,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory GeoBoundary.fromMap(Map<String, dynamic> map, [List<GeoBoundaryPoint> points = const []]) => GeoBoundary(
        id: map['id'] as String,
        locationId: map['location_id'] as String,
        geometryType: map['geometry_type'] as String,
        strokeColor: map['stroke_color'] as int? ?? 0xFF1565C0,
        fillColor: map['fill_color'] as int? ?? 0x261565C0,
        strokeWidth: (map['stroke_width'] as num?)?.toDouble() ?? 2.0,
        label: map['label'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        points: points,
      );
}

class GeoBoundaryPoint {
  final String id;
  final String boundaryId;
  final double latitude;
  final double longitude;
  final int sequence;

  const GeoBoundaryPoint({
    required this.id,
    required this.boundaryId,
    required this.latitude,
    required this.longitude,
    required this.sequence,
  });

  GeoBoundaryPoint copyWith({
    String? id,
    String? boundaryId,
    double? latitude,
    double? longitude,
    int? sequence,
  }) {
    return GeoBoundaryPoint(
      id: id ?? this.id,
      boundaryId: boundaryId ?? this.boundaryId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      sequence: sequence ?? this.sequence,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'boundary_id': boundaryId,
        'latitude': latitude,
        'longitude': longitude,
        'sequence': sequence,
      };

  factory GeoBoundaryPoint.fromMap(Map<String, dynamic> map) => GeoBoundaryPoint(
        id: map['id'] as String,
        boundaryId: map['boundary_id'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        sequence: map['sequence'] as int,
      );
}
