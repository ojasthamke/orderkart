import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum MarkerType {
  customerActive,
  customerVip,
  customerOutstanding,
  customerInactive,
  deliveryPending,
  landmark,
  gps
}

class MapMarkerData {
  final String id;
  final LatLng position;
  final MarkerType type;
  final Color color;
  final String label;
  final String description;
  final String photoPath;
  final Map<String, dynamic> rawData; // holds customer, location info

  const MapMarkerData({
    required this.id,
    required this.position,
    required this.type,
    required this.color,
    required this.label,
    this.description = '',
    this.photoPath = '',
    this.rawData = const {},
  });
}

class MapLayerVisibility {
  final bool baseTiles;
  final bool areaBoundary;
  final bool sectionBoundaries;
  final bool roads;
  final bool customerMarkers;
  final bool deliveryMarkers;
  final bool landmarks;
  final bool labels;

  const MapLayerVisibility({
    this.baseTiles = true,
    this.areaBoundary = true,
    this.sectionBoundaries = true,
    this.roads = true,
    this.customerMarkers = true,
    this.deliveryMarkers = true,
    this.landmarks = true,
    this.labels = true,
  });

  MapLayerVisibility copyWith({
    bool? baseTiles,
    bool? areaBoundary,
    bool? sectionBoundaries,
    bool? roads,
    bool? customerMarkers,
    bool? deliveryMarkers,
    bool? landmarks,
    bool? labels,
  }) {
    return MapLayerVisibility(
      baseTiles: baseTiles ?? this.baseTiles,
      areaBoundary: areaBoundary ?? this.areaBoundary,
      sectionBoundaries: sectionBoundaries ?? this.sectionBoundaries,
      roads: roads ?? this.roads,
      customerMarkers: customerMarkers ?? this.customerMarkers,
      deliveryMarkers: deliveryMarkers ?? this.deliveryMarkers,
      landmarks: landmarks ?? this.landmarks,
      labels: labels ?? this.labels,
    );
  }
}
