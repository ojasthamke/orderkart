import 'package:flutter/material.dart';

enum LocationKind {
  area,
  road,
  galli,
  society,
  building,
  unit,
  landmark,
  other;

  String get value {
    switch (this) {
      case LocationKind.area: return 'Area';
      case LocationKind.road: return 'Road';
      case LocationKind.galli: return 'Galli';
      case LocationKind.society: return 'Society';
      case LocationKind.building: return 'Building';
      case LocationKind.unit: return 'Unit';
      case LocationKind.landmark: return 'Landmark';
      case LocationKind.other: return 'Other';
    }
  }

  static LocationKind fromString(String val) {
    final lower = val.toLowerCase().trim();
    switch (lower) {
      case 'area':
      case 'territory':
        return LocationKind.area;
      case 'road':
      case 'street':
        return LocationKind.road;
      case 'galli':
      case 'lane':
        return LocationKind.galli;
      case 'society':
        return LocationKind.society;
      case 'building':
        return LocationKind.building;
      case 'unit':
      case 'flat':
        return LocationKind.unit;
      case 'landmark':
        return LocationKind.landmark;
      default:
        return LocationKind.other;
    }
  }

  IconData get icon {
    switch (this) {
      case LocationKind.area:
        return Icons.map_rounded;
      case LocationKind.road:
        return Icons.add_road_rounded;
      case LocationKind.galli:
        return Icons.turn_slight_right_rounded;
      case LocationKind.society:
        return Icons.holiday_village_rounded;
      case LocationKind.building:
        return Icons.domain_rounded;
      case LocationKind.unit:
        return Icons.door_front_door_rounded;
      case LocationKind.landmark:
        return Icons.pin_drop_rounded;
      case LocationKind.other:
        return Icons.location_on_rounded;
    }
  }
}
