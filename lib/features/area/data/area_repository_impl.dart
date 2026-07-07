/// AreaRepositoryImpl — concrete implementation of AreaRepository
library;

import '../domain/area.dart';
import '../domain/area_repository.dart';
import 'area_dao.dart';

class AreaRepositoryImpl implements AreaRepository {
  final AreaDao _dao;
  AreaRepositoryImpl(this._dao);

  @override
  Future<List<Area>> getAllAreas({String? searchQuery, String? sortBy}) =>
      _dao.getAllAreas(searchQuery: searchQuery, sortBy: sortBy);

  @override
  Future<Area?> getAreaById(String id) => _dao.getAreaById(id);

  @override
  Future<String> addArea(Area area) => _dao.insertArea(area);

  @override
  Future<void> updateArea(Area area) => _dao.updateArea(area);

  @override
  Future<void> deleteArea(String id) => _dao.deleteArea(id);

  @override
  Future<int> getStreetCount(String areaId) async {
    final area = await _dao.getAreaById(areaId);
    return area?.streetCount ?? 0;
  }

  @override
  Future<Map<String, dynamic>> getAreaStats(String areaId) async {
    final area = await _dao.getAreaById(areaId);
    return {
      'streetCount':   area?.streetCount   ?? 0,
      'customerCount': area?.customerCount ?? 0,
      'orderCount':    area?.orderCount    ?? 0,
      'totalRevenue':  area?.totalRevenue  ?? 0.0,
    };
  }
}
