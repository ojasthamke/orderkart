import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/geo_boundary_dao.dart';
import '../data/map_data_dao.dart';
import '../domain/geo_boundary.dart';
import '../domain/map_models.dart';
import '../../customer/domain/customer.dart';
import '../../location/domain/location.dart';
import '../utils/geo_math.dart';

// DAO Providers
final mapDataDaoProvider = Provider((ref) => MapDataDao());
final geoBoundaryDaoProvider = Provider((ref) => GeoBoundaryDao());

// Map Data Bundle
class AreaMapData {
  final Location areaLocation;
  final List<Location> subLocations;
  final List<Customer> customers;
  final List<GeoBoundary> boundaries;
  final List<MapMarkerData> customerMarkers;
  final List<MapMarkerData> deliveryMarkers;
  final List<MapMarkerData> landmarkMarkers;

  const AreaMapData({
    required this.areaLocation,
    required this.subLocations,
    required this.customers,
    required this.boundaries,
    required this.customerMarkers,
    required this.deliveryMarkers,
    required this.landmarkMarkers,
  });
}

// Combined Map Data FutureProvider
final areaMapDataProvider =
    FutureProvider.family<AreaMapData, String>((ref, areaId) async {
  final mapDao = ref.read(mapDataDaoProvider);
  final boundaryDao = ref.read(geoBoundaryDaoProvider);

  // 1. Fetch data from DB
  final locations = await mapDao.getSubLocations(areaId);
  final rootArea = locations.firstWhere((l) => l.id == areaId, orElse: () {
    return Location(
      id: areaId,
      name: 'Unmapped Area',
      locationKind: Location.fromMap({'location_kind': 'area'}).locationKind,
      sequenceKey: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  });

  final customerMaps = await mapDao.getCustomersWithPendingCount(areaId);
  final customers = customerMaps.map((m) => Customer.fromMap(m)).toList();
  final boundaries = await boundaryDao.getBoundariesForAreaSubtree(areaId);

  // 2. Map to markers
  final List<MapMarkerData> customerMarkers = [];
  final List<MapMarkerData> deliveryMarkers = [];
  final List<MapMarkerData> landmarkMarkers = [];

  // Build customer and delivery markers
  for (int i = 0; i < customers.length; i++) {
    final c = customers[i];
    final mapRow = customerMaps[i];
    final int pendingCount = mapRow['pending_delivery_count'] as int? ?? 0;

    if (c.latitude == 0.0 && c.longitude == 0.0) continue;

    final pos = LatLng(c.latitude, c.longitude);

    // Determine type by priority
    MarkerType type = MarkerType.customerActive;
    Color color = const Color(0xFF2E7D32); // Green

    if (pendingCount > 0) {
      type = MarkerType.deliveryPending;
      color = const Color(0xFFF57C00); // Orange
    } else if (c.outstandingBalance > 500.0) {
      type = MarkerType.customerOutstanding;
      color = const Color(0xFFC62828); // Red
    } else if (c.isVip) {
      type = MarkerType.customerVip;
      color = const Color(0xFFFFA000); // Gold
    } else if (c.tag == 'Inactive') {
      type = MarkerType.customerInactive;
      color = const Color(0xFF9E9E9E); // Gray
    }

    final marker = MapMarkerData(
      id: c.id,
      position: pos,
      type: type,
      color: color,
      label: c.name,
      description: c.address,
      photoPath: c.photoPath,
      rawData: c.toMap(),
    );

    customerMarkers.add(marker);

    // If it has pending delivery, add to dedicated deliveries list too
    if (pendingCount > 0) {
      deliveryMarkers.add(marker);
    }
  }

  // Build landmark markers
  for (final loc in locations) {
    if (loc.locationKind.name == 'landmark' &&
        loc.latitude != 0.0 &&
        loc.longitude != 0.0) {
      landmarkMarkers.add(MapMarkerData(
        id: loc.id,
        position: LatLng(loc.latitude, loc.longitude),
        type: MarkerType.landmark,
        color: Color(loc.color),
        label: loc.name,
        description: loc.description,
        photoPath: loc.photoPath,
        rawData: loc.toMap(),
      ));
    }
  }

  return AreaMapData(
    areaLocation: rootArea,
    subLocations: locations,
    customers: customers,
    boundaries: boundaries,
    customerMarkers: customerMarkers,
    deliveryMarkers: deliveryMarkers,
    landmarkMarkers: landmarkMarkers,
  );
});

// GPS Stream Provider with EMA smoothing
final currentLocationProvider = StreamProvider<LatLng>((ref) {
  final controller = StreamController<LatLng>();
  StreamSubscription<Position>? positionSubscription;
  StreamSubscription<ServiceStatus>? serviceStatusSubscription;

  Future<void> startTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        controller.addError('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          controller.addError('Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        controller.addError('Location permissions are permanently denied.');
        return;
      }

      serviceStatusSubscription =
          Geolocator.getServiceStatusStream().listen((status) {
        if (status == ServiceStatus.disabled) {
          controller.addError('Location services disabled');
        }
      });

      LatLng? prevPoint;

      // Fetch initial position immediately upon opening the map
      try {
        final initialPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );
        final initialPoint = LatLng(initialPos.latitude, initialPos.longitude);
        prevPoint = initialPoint;
        controller.add(initialPoint);
      } catch (_) {
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            final initialPoint =
                LatLng(lastKnown.latitude, lastKnown.longitude);
            prevPoint = initialPoint;
            controller.add(initialPoint);
          }
        } catch (_) {}
      }

      positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        (position) {
          final rawPoint = LatLng(position.latitude, position.longitude);
          final smoothed = GeoMath.smoothGPS(rawPoint, prevPoint);
          prevPoint = smoothed;
          controller.add(smoothed);
        },
        onError: (err) => controller.addError(err),
      );
    } catch (e) {
      controller.addError(e);
    }
  }

  startTracking();

  ref.onDispose(() {
    positionSubscription?.cancel();
    serviceStatusSubscription?.cancel();
    controller.close();
  });

  return controller.stream;
});

// Context Information Panel Provider (You are in: X)
class CurrentSectionState {
  final Location? currentLocation;
  final List<Location> breadcrumbs;
  final int pendingDeliveries;
  final int customerCount;

  const CurrentSectionState({
    this.currentLocation,
    this.breadcrumbs = const [],
    this.pendingDeliveries = 0,
    this.customerCount = 0,
  });
}

final currentSectionProvider =
    Provider.family<CurrentSectionState, String>((ref, areaId) {
  final gpsAsync = ref.watch(currentLocationProvider);
  final mapDataAsync = ref.watch(areaMapDataProvider(areaId));

  return gpsAsync.maybeWhen(
    data: (gpsPoint) {
      return mapDataAsync.maybeWhen(
        data: (data) {
          // Find matching polygon boundary
          Location? foundLocation;
          List<LatLng> polygonPoints = [];

          // Sort boundaries by depth DESC so we match most specific child first
          final sortedBoundaries = List<GeoBoundary>.from(data.boundaries)
            ..sort((a, b) {
              final locA = data.subLocations.firstWhere(
                  (l) => l.id == a.locationId,
                  orElse: () => data.areaLocation);
              final locB = data.subLocations.firstWhere(
                  (l) => l.id == b.locationId,
                  orElse: () => data.areaLocation);
              return locB.depth.compareTo(locA.depth);
            });

          for (final boundary in sortedBoundaries) {
            if (boundary.geometryType == 'polygon') {
              final pts = boundary.points
                  .map((p) => LatLng(p.latitude, p.longitude))
                  .toList();
              if (GeoMath.isPointInPolygon(gpsPoint, pts)) {
                foundLocation = data.subLocations.firstWhere(
                    (l) => l.id == boundary.locationId,
                    orElse: () => data.areaLocation);
                polygonPoints = pts;
                break;
              }
            }
          }

          if (foundLocation != null) {
            // Find breadcrumbs
            final breadcrumbs = <Location>[];
            String? currentId = foundLocation.id;
            while (currentId != null) {
              final loc = data.subLocations.firstWhere((l) => l.id == currentId,
                  orElse: () => data.areaLocation);
              breadcrumbs.insert(0, loc);
              currentId = loc.parentLocationId;
            }

            // Find count of pending deliveries in this specific polygon
            final customersInPolygon = data.customers.where((c) {
              if (c.latitude == 0.0 || c.longitude == 0.0) return false;
              return GeoMath.isPointInPolygon(
                  LatLng(c.latitude, c.longitude), polygonPoints);
            }).toList();

            final pendingCount = data.deliveryMarkers.where((m) {
              return GeoMath.isPointInPolygon(m.position, polygonPoints);
            }).length;

            return CurrentSectionState(
              currentLocation: foundLocation,
              breadcrumbs: breadcrumbs,
              pendingDeliveries: pendingCount,
              customerCount: customersInPolygon.length,
            );
          }

          return const CurrentSectionState();
        },
        orElse: () => const CurrentSectionState(),
      );
    },
    orElse: () => const CurrentSectionState(),
  );
});

// Layer Toggles Manager
class MapLayerVisibilityNotifier extends StateNotifier<MapLayerVisibility> {
  final String _areaId;
  SharedPreferences? _prefs;

  MapLayerVisibilityNotifier(this._areaId) : super(const MapLayerVisibility()) {
    _loadVisibility();
  }

  Future<void> _loadVisibility() async {
    _prefs = await SharedPreferences.getInstance();
    if (_prefs != null) {
      state = MapLayerVisibility(
        baseTiles: _prefs!.getBool('map_vis_${_areaId}_base') ?? true,
        areaBoundary: _prefs!.getBool('map_vis_${_areaId}_area') ?? true,
        sectionBoundaries:
            _prefs!.getBool('map_vis_${_areaId}_section') ?? true,
        roads: _prefs!.getBool('map_vis_${_areaId}_roads') ?? true,
        customerMarkers:
            _prefs!.getBool('map_vis_${_areaId}_customers') ?? true,
        deliveryMarkers:
            _prefs!.getBool('map_vis_${_areaId}_deliveries') ?? true,
        landmarks: _prefs!.getBool('map_vis_${_areaId}_landmarks') ?? true,
        labels: _prefs!.getBool('map_vis_${_areaId}_labels') ?? true,
      );
    }
  }

  void toggleBaseTiles() {
    state = state.copyWith(baseTiles: !state.baseTiles);
    _prefs?.setBool('map_vis_${_areaId}_base', state.baseTiles);
  }

  void toggleAreaBoundary() {
    state = state.copyWith(areaBoundary: !state.areaBoundary);
    _prefs?.setBool('map_vis_${_areaId}_area', state.areaBoundary);
  }

  void toggleSectionBoundaries() {
    state = state.copyWith(sectionBoundaries: !state.sectionBoundaries);
    _prefs?.setBool('map_vis_${_areaId}_section', state.sectionBoundaries);
  }

  void toggleRoads() {
    state = state.copyWith(roads: !state.roads);
    _prefs?.setBool('map_vis_${_areaId}_roads', state.roads);
  }

  void toggleCustomerMarkers() {
    state = state.copyWith(customerMarkers: !state.customerMarkers);
    _prefs?.setBool('map_vis_${_areaId}_customers', state.customerMarkers);
  }

  void toggleDeliveryMarkers() {
    state = state.copyWith(deliveryMarkers: !state.deliveryMarkers);
    _prefs?.setBool('map_vis_${_areaId}_deliveries', state.deliveryMarkers);
  }

  void toggleLandmarks() {
    state = state.copyWith(landmarks: !state.landmarks);
    _prefs?.setBool('map_vis_${_areaId}_landmarks', state.landmarks);
  }

  void toggleLabels() {
    state = state.copyWith(labels: !state.labels);
    _prefs?.setBool('map_vis_${_areaId}_labels', state.labels);
  }
}

final mapLayerVisibilityProvider = StateNotifierProvider.family<
    MapLayerVisibilityNotifier, MapLayerVisibility, String>((ref, areaId) {
  return MapLayerVisibilityNotifier(areaId);
});

// Boundary State management (Drawn/Edited boundaries)
class MapBoundaryNotifier extends StateNotifier<List<GeoBoundary>> {
  final Ref _ref;
  final String _areaId;

  MapBoundaryNotifier(this._ref, this._areaId) : super([]) {
    _loadBoundaries();
  }

  Future<void> _loadBoundaries() async {
    final dao = _ref.read(geoBoundaryDaoProvider);
    state = await dao.getBoundariesForAreaSubtree(_areaId);
  }

  Future<void> saveBoundary(GeoBoundary boundary) async {
    final dao = _ref.read(geoBoundaryDaoProvider);
    await dao.insertBoundary(boundary);
    await _loadBoundaries();
    _ref.invalidate(areaMapDataProvider(_areaId));
  }

  Future<void> deleteBoundary(String boundaryId) async {
    final dao = _ref.read(geoBoundaryDaoProvider);
    await dao.deleteBoundary(boundaryId);
    await _loadBoundaries();
    _ref.invalidate(areaMapDataProvider(_areaId));
  }
}

final mapBoundaryNotifierProvider = StateNotifierProvider.family<
    MapBoundaryNotifier, List<GeoBoundary>, String>((ref, areaId) {
  return MapBoundaryNotifier(ref, areaId);
});
