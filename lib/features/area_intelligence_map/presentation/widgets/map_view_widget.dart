import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/map_models.dart';
import '../../domain/geo_boundary.dart';
import '../area_map_provider.dart';
import '../../../customer/domain/customer.dart';
import '../../../location/domain/location.dart';
import '../../utils/marker_clusterer.dart';

class MapViewWidget extends ConsumerStatefulWidget {
  final MapController mapController;
  final String areaId;
  final AreaMapData mapData;
  final MapLayerVisibility visibility;
  final bool isEditMode;
  final List<LatLng> editPoints;
  final String editGeometryType;
  final Customer? selectedCustomer;
  final Function(LatLng) onMapTap;
  final Function(Customer) onCustomerTap;

  const MapViewWidget({
    super.key,
    required this.mapController,
    required this.areaId,
    required this.mapData,
    required this.visibility,
    required this.isEditMode,
    required this.editPoints,
    required this.editGeometryType,
    required this.selectedCustomer,
    required this.onMapTap,
    required this.onCustomerTap,
  });

  @override
  ConsumerState<MapViewWidget> createState() => _MapViewWidgetState();
}

class _MapViewWidgetState extends ConsumerState<MapViewWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late final TileProvider _tileProvider;
  double _currentZoom = 16.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _tileProvider = _initTileProvider();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  TileProvider _initTileProvider() {
    try {
      return FMTCTileProvider(
        stores: const {
          'osmMapStore': BrowseStoreStrategy.readUpdateCreate,
        },
      );
    } catch (_) {
      return NetworkTileProvider();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gpsAsync = ref.watch(currentLocationProvider);
    final gpsPoint = gpsAsync.valueOrNull;

    // 1. Prepare Polygon layers
    final List<Polygon> polygons = [];
    final List<Polyline> polylines = [];
    final List<Marker> markers = [];

    // Fit area boundary polygons
    if (widget.visibility.areaBoundary) {
      final areaBoundaries = widget.mapData.boundaries.where(
        (b) => b.locationId == widget.areaId && b.geometryType == 'polygon',
      );
      for (final b in areaBoundaries) {
        polygons.add(Polygon(
          points: b.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
          color: Color(b.fillColor),
          borderColor: Color(b.strokeColor),
          borderStrokeWidth: b.strokeWidth,
          isFilled: true,
        ));
      }
    }

    // Fit sub-sections boundary polygons & polylines
    if (widget.visibility.sectionBoundaries || widget.visibility.roads) {
      final subBoundaries = widget.mapData.boundaries.where((b) => b.locationId != widget.areaId);
      for (final b in subBoundaries) {
        if (b.geometryType == 'polygon' && widget.visibility.sectionBoundaries) {
          polygons.add(Polygon(
            points: b.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
            color: Color(b.fillColor),
            borderColor: Color(b.strokeColor),
            borderStrokeWidth: b.strokeWidth,
            isFilled: true,
          ));
        } else if (b.geometryType == 'polyline' && widget.visibility.roads) {
          polylines.add(Polyline(
            points: b.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
            color: Color(b.strokeColor),
            strokeWidth: b.strokeWidth,
          ));
        }
      }
    }

    // 2. Prepare Drawing preview overlays
    if (widget.isEditMode && widget.editPoints.isNotEmpty) {
      if (widget.editGeometryType == 'polygon') {
        polygons.add(Polygon(
          points: widget.editPoints,
          color: const Color(0x331E88E5), // Blue 15%
          borderColor: const Color(0xFF1E88E5),
          borderStrokeWidth: 3.0,
          isFilled: true,
        ));
      } else {
        polylines.add(Polyline(
          points: widget.editPoints,
          color: const Color(0xFF1E88E5),
          strokeWidth: 3.0,
        ));
      }

      // Draw handles for editable vertices
      for (int idx = 0; idx < widget.editPoints.length; idx++) {
        final pt = widget.editPoints[idx];
        markers.add(Marker(
          point: pt,
          width: 14,
          height: 14,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1E88E5), width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            child: Center(
              child: Text(
                '${idx + 1}',
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ));
      }
    }

    // 3. Prepare Customer Markers (with clustering)
    if (widget.visibility.customerMarkers && !widget.isEditMode) {
      final clustered = MarkerClusterer.cluster(
        markers: widget.mapData.customerMarkers,
        zoom: _currentZoom,
      );

      for (final cluster in clustered) {
        if (cluster.isCluster) {
          markers.add(Marker(
            point: cluster.position,
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () {
                widget.mapController.move(cluster.position, _currentZoom + 1.5);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.9),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${cluster.markers.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ));
        } else {
          final m = cluster.markers.first;
          final isSelected = widget.selectedCustomer?.id == m.id;
          final c = Customer.fromMap(m.rawData);

          markers.add(Marker(
            point: m.position,
            width: isSelected ? 48 : 36,
            height: isSelected ? 48 : 36,
            child: GestureDetector(
              onTap: () => widget.onCustomerTap(c),
              child: _buildCustomerMarkerWidget(m, isSelected),
            ),
          ));
        }
      }
    }

    // 4. Prepare Landmark Markers
    if (widget.visibility.landmarks && !widget.isEditMode) {
      for (final m in widget.mapData.landmarkMarkers) {
        final loc = Location.fromMap(m.rawData);
        markers.add(Marker(
          point: m.position,
          width: 32,
          height: 32,
          child: Tooltip(
            message: loc.name,
            child: Container(
              decoration: BoxDecoration(
                color: Color(loc.color),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: Icon(
                loc.locationKind.icon,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ));
      }
    }

    // 5. Prepare floating street labels
    if (widget.visibility.labels && !widget.isEditMode) {
      for (final b in widget.mapData.boundaries) {
        if (b.points.isNotEmpty && b.label.isNotEmpty) {
          // Average position for center placement
          double latSum = 0;
          double lngSum = 0;
          for (final p in b.points) {
            latSum += p.latitude;
            lngSum += p.longitude;
          }
          final center = LatLng(latSum / b.points.length, lngSum / b.points.length);
          markers.add(Marker(
            point: center,
            width: 120,
            height: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  b.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ));
        }
      }
    }

    // 6. Renders GPS Location overlay with accuracy indicator
    if (gpsPoint != null) {
      markers.add(Marker(
        point: gpsPoint,
        width: 32,
        height: 32,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 14 + (18 * _pulseController.value),
                    height: 14 + (18 * _pulseController.value),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.4 * (1.0 - _pulseController.value)),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ));
    }

    // Center on area centroid, average customer pins, area coord, or fallback to GPS/Mumbai
    final LatLng initialCenter;
    final areaBoundary = widget.mapData.boundaries.firstWhere(
      (b) => b.locationId == widget.areaId && b.points.isNotEmpty,
      orElse: () => widget.mapData.boundaries.firstWhere(
        (b) => b.points.isNotEmpty,
        orElse: () => GeoBoundary(
          id: '',
          locationId: '',
          points: [],
          geometryType: '',
          label: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ),
    );

    if (areaBoundary.points.isNotEmpty) {
      double latSum = 0;
      double lngSum = 0;
      for (final p in areaBoundary.points) {
        latSum += p.latitude;
        lngSum += p.longitude;
      }
      initialCenter = LatLng(latSum / areaBoundary.points.length, lngSum / areaBoundary.points.length);
    } else if (widget.mapData.customerMarkers.isNotEmpty) {
      double latSum = 0;
      double lngSum = 0;
      for (final m in widget.mapData.customerMarkers) {
        latSum += m.position.latitude;
        lngSum += m.position.longitude;
      }
      initialCenter = LatLng(latSum / widget.mapData.customerMarkers.length, lngSum / widget.mapData.customerMarkers.length);
    } else if (widget.mapData.areaLocation.latitude != 0.0 && widget.mapData.areaLocation.longitude != 0.0) {
      initialCenter = LatLng(widget.mapData.areaLocation.latitude, widget.mapData.areaLocation.longitude);
    } else if (gpsPoint != null) {
      initialCenter = gpsPoint;
    } else {
      initialCenter = const LatLng(19.076, 72.877); // Default fallback Mumbai
    }

    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 16.0,
        minZoom: 11.0,
        maxZoom: 19.0,
        onTap: (tapCtx, point) => widget.onMapTap(point),
        onPositionChanged: (camera, hasGesture) {
          setState(() {
            _currentZoom = camera.zoom;
          });
        },
      ),
      children: [
        // Base Layer
        if (widget.visibility.baseTiles)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.orderkart.app',
            tileProvider: _tileProvider,
          ),

        // Polygons (Area & Sections)
        PolygonLayer(polygons: polygons),

        // Polylines (Roads)
        PolylineLayer(polylines: polylines),

        // Markers & Handles
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildCustomerMarkerWidget(MapMarkerData data, bool isSelected) {
    IconData iconData = Icons.person_rounded;
    if (data.type == MarkerType.customerVip) {
      iconData = Icons.stars_rounded;
    } else if (data.type == MarkerType.deliveryPending) {
      iconData = Icons.shopping_bag_rounded;
    } else if (data.type == MarkerType.customerOutstanding) {
      iconData = Icons.warning_rounded;
    }

    Widget markerIcon = Container(
      decoration: BoxDecoration(
        color: data.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Icon(
          iconData,
          color: Colors.white,
          size: isSelected ? 24 : 18,
        ),
      ),
    );

    // If delivery is pending, add a pulsing scale effect around the marker
    if (data.type == MarkerType.deliveryPending) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: isSelected ? 48 : 36,
                height: isSelected ? 48 : 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.orangeAccent.withOpacity(0.6 * (1.0 - _pulseController.value)),
                    width: 4 * _pulseController.value,
                  ),
                ),
              ),
              markerIcon,
            ],
          );
        },
      );
    }

    return markerIcon;
  }
}
