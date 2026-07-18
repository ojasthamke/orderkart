import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/location_dao.dart';
import '../data/location_repository_impl.dart';
import '../domain/location.dart';
import '../domain/location_repository.dart';

// Repository provider
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepositoryImpl(LocationDao());
});

// Provider for breadcrumbs of a given location
final breadcrumbsProvider = FutureProvider.family<List<Location>, String>((ref, locationId) async {
  final repo = ref.read(locationRepositoryProvider);
  return await repo.getBreadcrumbs(locationId);
});

// State notifier for child locations under a specific parent ID
class LocationListNotifier extends StateNotifier<AsyncValue<List<Location>>> {
  final Ref _ref;
  final LocationRepository _repo;
  final String? parentId;
  String _search = '';
  String _sort = 'sequence_key';

  LocationListNotifier(this._ref, this._repo, this.parentId) : super(const AsyncValue.loading()) {
    loadLocations();
  }

  Future<void> loadLocations() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getAllLocations(
        searchQuery: _search,
        parentId: parentId,
        sortBy: _sort,
      );
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void search(String query) {
    _search = query;
    loadLocations();
  }

  void sort(String sortBy) {
    _sort = sortBy;
    loadLocations();
  }

  Future<void> add(Location location) async {
    // Generate next sequence key automatically before inserting
    final nextSeq = await _repo.getNextSequenceKey(parentId);
    final toInsert = location.copyWith(sequenceKey: nextSeq);
    
    await _repo.addLocation(toInsert);
    await loadLocations();
    _invalidateAll();
  }

  Future<void> updateLocation(Location location) async {
    await _repo.updateLocation(location);
    await loadLocations();
    _invalidateAll();
  }

  Future<void> delete(String id) async {
    await _repo.deleteLocation(id);
    await loadLocations();
    _invalidateAll();
  }

  void _invalidateAll() {
    _ref.invalidate(locationListProvider(parentId));
    if (parentId != null) {
      _ref.invalidate(breadcrumbsProvider(parentId!));
    }
  }
}

// Family provider for child locations list
final locationListProvider = StateNotifierProvider.family<LocationListNotifier, AsyncValue<List<Location>>, String?>((ref, parentId) {
  return LocationListNotifier(ref, ref.read(locationRepositoryProvider), parentId);
});

final locationPathNameProvider = FutureProvider.family<String, String>((ref, locationId) async {
  return await LocationDao().getFullLocationPathName(locationId);
});
