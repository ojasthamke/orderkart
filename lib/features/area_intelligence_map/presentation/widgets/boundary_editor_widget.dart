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
  final String? boundaryId;
  final VoidCallback onCancel;
  final VoidCallback onSaveSuccess;
  final ValueChanged<List<LatLng>>? onPointsChanged;

  const BoundaryEditorWidget({
    super.key,
    required this.areaId,
    required this.locationId,
    required this.locationName,
    required this.initialPoints,
    required this.initialGeometryType,
    this.boundaryId,
    required this.onCancel,
    required this.onSaveSuccess,
    this.onPointsChanged,
  });

  @override
  ConsumerState<BoundaryEditorWidget> createState() =>
      BoundaryEditorWidgetState();
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
    widget.onPointsChanged?.call(_points);
  }

  void undoLastPoint() {
    if (_points.isNotEmpty) {
      setState(() {
        _points.removeLast();
      });
      widget.onPointsChanged?.call(_points);
    }
  }

  void clearPoints() {
    setState(() {
      _points.clear();
    });
    widget.onPointsChanged?.call(_points);
  }

  Future<void> _autoSuggest() async {
    final mapDataAsync = ref.read(areaMapDataProvider(widget.areaId));
    mapDataAsync.whenData((data) {
      // Find all customers linked to this exact location
      final locationCustomers = data.customers
          .where((c) =>
              c.streetId == widget.locationId || c.id == widget.locationId)
          .toList();
      final points = locationCustomers
          .where((c) => c.latitude != 0.0 && c.longitude != 0.0)
          .map((c) => LatLng(c.latitude, c.longitude))
          .toList();

      if (points.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('No customer locations found to generate suggestion')),
        );
        return;
      }

      if (points.length < 3) {
        setState(() {
          _points = points;
          _geometryType = 'polyline'; // default to line if few pins
        });
        widget.onPointsChanged?.call(points);
        return;
      }

      final hull = GeoMath.generateConvexHull(points);
      setState(() {
        _points = hull;
        _geometryType = 'polygon';
      });
      widget.onPointsChanged?.call(hull);
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

    await ref
        .read(mapBoundaryNotifierProvider(widget.areaId).notifier)
        .saveBoundary(boundary);
    widget.onSaveSuccess();
  }

  Future<void> _delete() async {
    if (widget.boundaryId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Boundary'),
        content: Text(
            'Are you sure you want to delete the boundary for "${widget.locationName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref
          .read(mapBoundaryNotifierProvider(widget.areaId).notifier)
          .deleteBoundary(widget.boundaryId!);
      widget.onSaveSuccess();
    }
  }

  String get _metricsText {
    if (_points.isEmpty) return 'Tap map to place vertices';
    final length = GeoMath.calculatePathLength(_points,
        isClosed: _geometryType == 'polygon');
    final lengthStr = length >= 1000
        ? '${(length / 1000).toStringAsFixed(2)} km'
        : '${length.toStringAsFixed(0)} m';
    if (_geometryType == 'polygon' && _points.length >= 3) {
      final areaSqM = GeoMath.calculatePolygonArea(_points);
      final areaStr = areaSqM >= 10000
          ? '${(areaSqM / 1000000).toStringAsFixed(3)} sq km'
          : '${areaSqM.toStringAsFixed(0)} m²';
      return 'Area: $areaStr  •  Perimeter: $lengthStr';
    }
    return 'Length: $lengthStr';
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Draw Boundary: ${widget.locationName}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _metricsText,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.blueGrey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_points.length} Points',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Mode selector & Auto-Suggest Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
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
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      foregroundColor: Colors.blue.shade900,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    label: const Text('Auto-Suggest Boundary'),
                    onPressed: _autoSuggest,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Color & Line Weight Row
            Row(
              children: [
                Text('Stroke Color:',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.bold)),
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
                              _fillColor = c & 0x00FFFFFF | 0x26000000;
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
                const SizedBox(width: 8),
                PopupMenuButton<double>(
                  tooltip: 'Stroke Width',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.line_weight, size: 14),
                        const SizedBox(width: 4),
                        Text('${_strokeWidth.toInt()}px',
                            style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  onSelected: (w) => setState(() => _strokeWidth = w),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 2.0, child: Text('Thin (2px)')),
                    const PopupMenuItem(value: 3.0, child: Text('Medium (3px)')),
                    const PopupMenuItem(value: 5.0, child: Text('Thick (5px)')),
                    const PopupMenuItem(
                        value: 8.0, child: Text('Extra Thick (8px)')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Controls & Actions Bar
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _points.isEmpty ? null : undoLastPoint,
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: const Text('Undo'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _points.isEmpty ? null : clearPoints,
                  style:
                      OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('Clear'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Submit / Delete Row
            Row(
              children: [
                if (widget.boundaryId != null) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _delete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Save Boundary'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
