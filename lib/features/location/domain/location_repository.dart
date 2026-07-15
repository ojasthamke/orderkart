import 'location.dart';

abstract class LocationRepository {
  Future<List<Location>> getAllLocations({
    String? searchQuery,
    String? parentId,
    String? sortBy,
    bool showArchived = false,
  });

  Future<Location?> getLocationById(String id);

  Future<String> addLocation(Location location);

  Future<void> updateLocation(Location location);

  Future<void> deleteLocation(String id);

  Future<List<Location>> getBreadcrumbs(String locationId);

  Future<String> getNextSequenceKey(String? parentId, {String? afterId, String? beforeId});

  Future<int> getCustomerCount(String locationId, {bool recursive = false});

  Future<Map<String, dynamic>> getLocationStats(String locationId);
}
