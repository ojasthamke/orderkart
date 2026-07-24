import '../domain/location.dart';
import '../domain/location_repository.dart';
import 'location_dao.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocationDao _dao;
  LocationRepositoryImpl(this._dao);

  @override
  Future<List<Location>> getAllLocations({
    String? searchQuery,
    String? parentId,
    String? sortBy,
    bool showArchived = false,
  }) =>
      _dao.getAllLocations(
        searchQuery: searchQuery,
        parentId: parentId,
        sortBy: sortBy,
        showArchived: showArchived,
      );

  @override
  Future<Location?> getLocationById(String id) => _dao.getLocationById(id);

  @override
  Future<String> addLocation(Location location) =>
      _dao.insertLocation(location);

  @override
  Future<void> updateLocation(Location location) =>
      _dao.updateLocation(location);

  @override
  Future<void> deleteLocation(String id) => _dao.deleteLocation(id);

  @override
  Future<List<Location>> getBreadcrumbs(String locationId) =>
      _dao.getBreadcrumbs(locationId);

  @override
  Future<String> getNextSequenceKey(String? parentId,
          {String? afterId, String? beforeId}) =>
      _dao.getNextSequenceKey(parentId, afterId: afterId, beforeId: beforeId);

  @override
  Future<int> getCustomerCount(String locationId, {bool recursive = false}) =>
      _dao.getCustomerCount(locationId, recursive: recursive);

  @override
  Future<Map<String, dynamic>> getLocationStats(String locationId) =>
      _dao.getLocationStats(locationId);
}
