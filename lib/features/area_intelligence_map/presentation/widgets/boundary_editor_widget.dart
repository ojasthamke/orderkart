import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../area_map_provider.dart';
import '../../domain/geo_boundary.dart';
import '../../utils/geo_math.dart';

class BoundaryEditorWidget extends ConsumerStatefulWidget {
  final String areaId;
  final String locationId;
  final String locationName;
  final List<LatLng> initialPoints;
  final String initialGeometryType;
  final VoidCallback onCancel;
  final VoidCallback onSaveSuccess;

  const BoundaryEditorWidget({
    super.key,
    required this.areaId,
    required this.locationId,
    required this.locationName,
    required this.initialPoints,
    required this.initialGeometryType,
    required this.onCancel,
    required this.onSaveSuccess,
  });

  @override
  ConsumerState<BoundaryEditorWidget> createState() => BoundaryEditorWidgetState();
}

class BoundaryEditorWidgetState extends ConsumerState<BoundaryEditorWidget> {
  late List<LatLng> _points;
  late String _geometryType;
  int _strokeColor = 0xFF1565C0;
  int _fillColor = 0x261565C0;
  double _strokeWidth = 3.0;

  final List<int> _colors = [
    0xFF1565C0, // Blue
    0xFF2E7D32, // Green
    0xFFC62828, // Red
    0xFFE65100, // Orange
    0xFF6A1B9A, // Purple
    0xFF00838F, // Teal
    0xFF37474F, // Dark Grey
  ];

  @override
  void initState() {
    super.initState();
    _points = List.from(widget.initialPoints);
    _geometryType = widget.initialGeometryType;
  }

  // Exposed for parent view to update points list dynamically when tapping on map
  void addPoint(LatLng point) {
    setState(() {
      _points.add(point);
    });
  }

  void undoLastPoint() {
    if (_points.isNotEmpty) {
      setState(() {
        _points.removeLast();
      });
    }
  }

  void clearPoints() {
    setState(() {
      _points.clear();
    });
  }

  Future<void> _autoSuggest() async {
    final mapDataAsync = ref.read(areaMapDataProvider(widget.areaId));
    mapDataAsync.whenData((data) {
      // Find all customers linked to this exact location
      final locationCustomers = data.customers.where((c) => c.streetId == widget.locationId || c.id == widget.locationId).toList();
      final points = locationCustomers
          .where((c) => c.latitude != 0.0 && c.longitude != 0.0)
          .map((c) => LatLng(c.latitude, c.longitude))
          .toList();

      if (points.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No customer locations found to generate suggestion')),
        );
        return;
      }

      if (points.length < 3) {
        setState(() {
          _points = points;
          _geometryType = 'polyline'; // default to line if few pins
        });
        return;
      }

      final hull = GeoMath.generateConvexHull(points);
      setState(() {
        _points = hull;
        _geometryType = 'polygon';
      });
    });
  }

  Future<void> _save() async {
    if (_points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one point to save')),
      );
      return;
    }

    if (_geometryType == 'polygon' && _points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Polygons require at least 3 vertices')),
      );
      return;
    }

    final id = const Uuid().v4();
    final boundary = GeoBoundary(
      id: id,
      locationId: widget.locationId,
      geometryType: _geometryType,
      strokeColor: _strokeColor,
      fillColor: _fillColor,
      strokeWidth: _strokeWidth,
      label: widget.locationName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      points: List.generate(_points.length, (i) {
        return GeoBoundaryPoint(
          id: const Uuid().v4(),
          boundaryId: id,
          latitude: _points[i].latitude,
          longitude: _points[i].longitude,
          sequence: i,
        );
      }),
    );

    await ref.read(mapBoundaryNotifierProvider(widget.areaId).notifier).saveBoundary(boundary);
    widget.onSaveSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Draw Boundary: ${widget.locationName}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_points.length} Points',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Polygon (Zone)'),
                selected: _geometryType == 'polygon',
                onSelected: (val) {
                  if (val) setState(() => _geometryType = 'polygon');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Polyline (Road/Path)'),
                selected: _geometryType == 'polyline',
                onSelected: (val) {
                  if (val) setState(() => _geometryType = 'polyline');
                },
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('Auto-Suggest'),
                onPressed: _autoSuggest,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Stroke Color:', style: GoogleFonts.inter(fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _colors.length,
                    itemBuilder: (ctx, i) {
                      final c = _colors[i];
                      final isSelected = _strokeColor == c;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _strokeColor = c;
                            _fillColor = c & 0x00FFFFFF | 0x26000000; // opacity 15%
                          });
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.black, width: 2)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.undo_rounded),
                onPressed: _points.isEmpty ? null : undoLastPoint,
                tooltip: 'Undo point',
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
                onPressed: _points.isEmpty ? null : clearPoints,
                tooltip: 'Clear all points',
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Boundary'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
