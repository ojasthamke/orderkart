import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'area_map_provider.dart';
import 'widgets/location_context_banner.dart';
import 'widgets/map_layer_controls.dart';
import 'widgets/customer_marker_popup.dart';
import 'widgets/boundary_editor_widget.dart';
import 'widgets/map_view_widget.dart';
import '../../customer/domain/customer.dart';

class AreaIntelligenceMapScreen extends ConsumerStatefulWidget {
  final String areaId;
  final String areaName;

  const AreaIntelligenceMapScreen({
    super.key,
    required this.areaId,
    required this.areaName,
  });

  @override
  ConsumerState<AreaIntelligenceMapScreen> createState() => _AreaIntelligenceMapScreenState();
}

class _AreaIntelligenceMapScreenState extends ConsumerState<AreaIntelligenceMapScreen> {
  final MapController _mapController = MapController();
  
  // Selection and edit states
  Customer? _selectedCustomer;
  bool _isEditMode = false;
  String? _editLocationId;
  String? _editLocationName;
  final List<LatLng> _editPoints = [];
  String _editGeometryType = 'polygon';

  final GlobalKey<BoundaryEditorWidgetState> _editorKey = GlobalKey<BoundaryEditorWidgetState>();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _recenterOnGps() {
    final gpsAsync = ref.read(currentLocationProvider);
    gpsAsync.when(
      data: (pos) {
        _mapController.move(pos, 17.0);
      },
      error: (err, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPS Error: ${err.toString()}'),
            backgroundColor: Colors.red[800],
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ),
        );
      },
      loading: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Determining location...')),
        );
      },
    );
  }

  void _startEditing(String locId, String name, [List<LatLng>? pts, String? type]) {
    setState(() {
      _selectedCustomer = null;
      _isEditMode = true;
      _editLocationId = locId;
      _editLocationName = name;
      _editPoints.clear();
      if (pts != null) _editPoints.addAll(pts);
      _editGeometryType = type ?? 'polygon';
    });
  }

  void _exitEditing() {
    setState(() {
      _isEditMode = false;
      _editLocationId = null;
      _editLocationName = null;
      _editPoints.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapDataAsync = ref.watch(areaMapDataProvider(widget.areaId));
    final vis = ref.watch(mapLayerVisibilityProvider(widget.areaId));
    final gpsAsync = ref.watch(currentLocationProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
        title: Text(
          widget.areaName,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (!_isEditMode)
            mapDataAsync.maybeWhen(
              data: (data) {
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.edit_road_rounded),
                  tooltip: 'Draw Boundary',
                  onSelected: (locId) {
                    final loc = data.subLocations.firstWhere((l) => l.id == locId);
                    final existing = data.boundaries.where((b) => b.locationId == locId);
                    if (existing.isNotEmpty) {
                      final b = existing.first;
                      final pts = b.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
                      _startEditing(locId, loc.name, pts, b.geometryType);
                    } else {
                      _startEditing(locId, loc.name);
                    }
                  },
                  itemBuilder: (ctx) {
                    return data.subLocations.map((l) {
                      return PopupMenuItem(
                        value: l.id,
                        child: Row(
                          children: [
                            Icon(l.locationKind.icon, size: 18),
                            const SizedBox(width: 8),
                            Text(l.name),
                          ],
                        ),
                      );
                    }).toList();
                  },
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Map Canvas View
          mapDataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (data) {
              return MapViewWidget(
                mapController: _mapController,
                areaId: widget.areaId,
                mapData: data,
                visibility: vis,
                isEditMode: _isEditMode,
                editPoints: _editPoints,
                editGeometryType: _editGeometryType,
                selectedCustomer: _selectedCustomer,
                onMapTap: (tapPos) {
                  if (_isEditMode) {
                    _editorKey.currentState?.addPoint(tapPos);
                  } else {
                    setState(() {
                      _selectedCustomer = null;
                    });
                  }
                },
                onCustomerTap: (Customer cust) {
                  setState(() {
                    _selectedCustomer = cust;
                  });
                  _mapController.move(LatLng(cust.latitude, cust.longitude), 18.0);
                },
              );
            },
          ),

          // 2. Glassmorphism Position HUD at top OR GPS Error Banner
          if (!_isEditMode)
            gpsAsync.when(
              data: (_) => Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 16,
                right: 16,
                child: LocationContextBanner(areaId: widget.areaId),
              ),
              loading: () => const SizedBox.shrink(),
              error: (error, _) => Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red[900]!.withOpacity(0.85),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gpp_maybe_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'GPS Tracking Disabled',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  error.toString(),
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              backgroundColor: Colors.white24,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => Geolocator.openAppSettings(),
                            child: Text(
                              'Enable',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 3. Layer toggle buttons on the right
          if (!_isEditMode)
            Positioned(
              right: 16,
              bottom: _selectedCustomer != null ? 320 : 120,
              child: MapLayerControls(
                areaId: widget.areaId,
                onRecenterGps: _recenterOnGps,
              ),
            ),

          // 4. Compact customer marker popup overlay
          if (_selectedCustomer != null && !_isEditMode)
            Positioned(
              left: 16,
              right: 16,
              bottom: 40,
              child: CustomerMarkerPopup(
                customer: _selectedCustomer!,
                onClose: () => setState(() => _selectedCustomer = null),
              ),
            ),

          // 5. Drawing Editor Widget at bottom
          if (_isEditMode && _editLocationId != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BoundaryEditorWidget(
                key: _editorKey,
                areaId: widget.areaId,
                locationId: _editLocationId!,
                locationName: _editLocationName!,
                initialPoints: _editPoints,
                initialGeometryType: _editGeometryType,
                onCancel: _exitEditing,
                onPointsChanged: (pts) {
                  setState(() {
                    _editPoints.clear();
                    _editPoints.addAll(pts);
                  });
                },
                onSaveSuccess: () {
                  _exitEditing();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Boundary saved successfully')),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
