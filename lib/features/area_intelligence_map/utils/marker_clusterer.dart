import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../domain/map_models.dart';

class ClusteredMarker {
  final String id;
  final LatLng position;
  final List<MapMarkerData> markers;
  final bool isCluster;

  const ClusteredMarker({
    required this.id,
    required this.position,
    this.markers = const [],
    this.isCluster = false,
  });
}

class MarkerClusterer {
  MarkerClusterer._();

  /// Simple grid-based clustering algorithm
  static List<ClusteredMarker> cluster({
    required List<MapMarkerData> markers,
    required double zoom,
    double gridCellSizeDegrees = 0.01, // default grid cell size
  }) {
    if (zoom >= 17.5) {
      // Zoomed in enough, never cluster
      return markers
          .map((m) => ClusteredMarker(
                id: m.id,
                position: m.position,
                markers: [m],
                isCluster: false,
              ))
          .toList();
    }

    // Adjust grid size based on zoom level
    // Zoom 13 needs larger grid cells than zoom 16
    final scale = pow(2, 17.5 - zoom).toDouble();
    final cellSize = gridCellSizeDegrees * scale;

    final Map<String, List<MapMarkerData>> grid = {};

    for (final marker in markers) {
      final int cellX = (marker.position.longitude / cellSize).floor();
      final int cellY = (marker.position.latitude / cellSize).floor();
      final key = '${cellX}_$cellY';
      grid.putIfAbsent(key, () => []).add(marker);
    }

    final result = <ClusteredMarker>[];

    grid.forEach((key, list) {
      if (list.isEmpty) return;

      if (list.length == 1 || (zoom >= 16.0 && list.length <= 2)) {
        // Individual markers
        for (final m in list) {
          result.add(ClusteredMarker(
            id: m.id,
            position: m.position,
            markers: [m],
            isCluster: false,
          ));
        }
      } else {
        // Compute average position of cluster
        double latSum = 0;
        double lngSum = 0;
        for (final m in list) {
          latSum += m.position.latitude;
          lngSum += m.position.longitude;
        }
        final center = LatLng(latSum / list.length, lngSum / list.length);

        result.add(ClusteredMarker(
          id: 'cluster_$key',
          position: center,
          markers: list,
          isCluster: true,
        ));
      }
    });

    return result;
  }
}
