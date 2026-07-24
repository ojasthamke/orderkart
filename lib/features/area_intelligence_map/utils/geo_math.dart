import 'dart:math';
import 'package:latlong2/latlong.dart';

class GeoMath {
  GeoMath._();

  /// Ray-casting algorithm to determine if a point lies inside a polygon boundary.
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    bool isInside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      final pi = polygon[i];
      final pj = polygon[j];

      final intersect =
          ((pi.latitude > point.latitude) != (pj.latitude > point.latitude)) &&
              (point.longitude <
                  (pj.longitude - pi.longitude) *
                          (point.latitude - pi.latitude) /
                          (pj.latitude - pi.latitude) +
                      pi.longitude);
      if (intersect) {
        isInside = !isInside;
      }
      j = i;
    }
    return isInside;
  }

  /// Haversine formula to compute distance in meters between two coordinates.
  static double calculateDistance(LatLng p1, LatLng p2) {
    const double r = 6371000; // Earth radius in meters
    final double dLat = _rad(p2.latitude - p1.latitude);
    final double dLng = _rad(p2.longitude - p1.longitude);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(p1.latitude)) *
            cos(_rad(p2.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  /// Exponential Moving Average (EMA) to smooth out GPS jitter.
  static LatLng smoothGPS(LatLng newPoint, LatLng? prevPoint,
      {double alpha = 0.7}) {
    if (prevPoint == null) return newPoint;
    return LatLng(
      alpha * newPoint.latitude + (1 - alpha) * prevPoint.latitude,
      alpha * newPoint.longitude + (1 - alpha) * prevPoint.longitude,
    );
  }

  /// Andrew's monotone chain 2D convex hull algorithm.
  static List<LatLng> generateConvexHull(List<LatLng> points) {
    if (points.length < 3) return List.from(points);

    final sorted = List<LatLng>.from(points)
      ..sort((a, b) {
        final cmp = a.latitude.compareTo(b.latitude);
        if (cmp != 0) return cmp;
        return a.longitude.compareTo(b.longitude);
      });

    final lower = <LatLng>[];
    for (final p in sorted) {
      while (lower.length >= 2 &&
          _cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }

    final upper = <LatLng>[];
    for (final p in sorted.reversed) {
      while (upper.length >= 2 &&
          _cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }

    if (lower.isNotEmpty) lower.removeLast();
    if (upper.isNotEmpty) upper.removeLast();
    return lower + upper;
  }

  static double _cross(LatLng o, LatLng a, LatLng b) {
    return (a.longitude - o.longitude) * (b.latitude - o.latitude) -
        (a.latitude - o.latitude) * (b.longitude - o.longitude);
  }

  static double _rad(double deg) => deg * pi / 180.0;
}
