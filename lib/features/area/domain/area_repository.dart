/// AreaRepository — abstract interface (Repository Pattern)
/// Cloud-sync ready: swap impl without changing callers

import 'area.dart';

abstract class AreaRepository {
  Future<List<Area>> getAllAreas({String? searchQuery, String? sortBy});
  Future<Area?> getAreaById(String id);
  Future<String> addArea(Area area);
  Future<void> updateArea(Area area);
  Future<void> deleteArea(String id);
  Future<int> getStreetCount(String areaId);
  Future<Map<String, dynamic>> getAreaStats(String areaId);
}
