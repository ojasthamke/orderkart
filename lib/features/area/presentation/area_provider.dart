import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/area_dao.dart';
import '../data/area_repository_impl.dart';
import '../domain/area.dart';
import '../domain/area_repository.dart';
import '../../order/presentation/order_provider.dart';
import '../../customer/presentation/customer_provider.dart';

// Repository provider
final areaRepositoryProvider = Provider<AreaRepository>((ref) {
  return AreaRepositoryImpl(AreaDao());
});

// State notifier for area list
class AreaNotifier extends StateNotifier<AsyncValue<List<Area>>> {
  final Ref _ref;
  final AreaRepository _repo;
  String _search = '';
  String _sort = 'name';

  AreaNotifier(this._ref, this._repo) : super(const AsyncValue.loading()) {
    loadAreas();
  }

  Future<void> loadAreas() async {
    state = const AsyncValue.loading();
    try {
      final areas =
          await _repo.getAllAreas(searchQuery: _search, sortBy: _sort);
      state = AsyncValue.data(areas);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _invalidateAll() {
    _ref.invalidate(areaProvider);
    _ref.invalidate(analyticsSummaryProvider);
    _ref.invalidate(allCustomersProvider);
    _ref.invalidate(pendingCustomersProvider);
  }

  void search(String query) {
    _search = query;
    loadAreas();
  }

  void sort(String sortBy) {
    _sort = sortBy;
    loadAreas();
  }

  Future<void> addArea(Area area) async {
    await _repo.addArea(area);
    await loadAreas();
    _invalidateAll();
  }

  Future<void> updateArea(Area area) async {
    await _repo.updateArea(area);
    await loadAreas();
    _invalidateAll();
  }

  Future<void> deleteArea(String id) async {
    await _repo.deleteArea(id);
    await loadAreas();
    _invalidateAll();
  }
}

final areaProvider =
    StateNotifierProvider<AreaNotifier, AsyncValue<List<Area>>>((ref) {
  return AreaNotifier(ref, ref.read(areaRepositoryProvider));
});
