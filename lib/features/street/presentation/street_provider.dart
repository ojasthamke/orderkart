import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/street_dao.dart';
import '../data/street_repository_impl.dart';
import '../domain/street.dart';
import '../domain/street_repository.dart';
import '../../area/presentation/area_provider.dart';
import '../../order/presentation/order_provider.dart';

final streetRepositoryProvider = Provider<StreetRepository>(
    (ref) => StreetRepositoryImpl(StreetDao()));

class StreetNotifier extends StateNotifier<AsyncValue<List<Street>>> {
  final Ref _ref;
  final StreetRepository _repo;
  final String areaId;
  String _search = '';

  StreetNotifier(this._ref, this._repo, this.areaId) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getStreetsByArea(areaId, searchQuery: _search);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _invalidateAll() {
    _ref.invalidate(streetProviderFamily);
    _ref.invalidate(areaProvider);
    _ref.invalidate(analyticsSummaryProvider);
  }

  void search(String q) {
    _search = q;
    load();
  }

  Future<void> add(Street s) async {
    await _repo.addStreet(s);
    await load();
    _invalidateAll();
  }

  Future<void> update(Street s) async {
    await _repo.updateStreet(s);
    await load();
    _invalidateAll();
  }

  Future<void> delete(String id) async {
    await _repo.deleteStreet(id);
    await load();
    _invalidateAll();
  }
}

final streetProviderFamily = StateNotifierProvider.family<
    StreetNotifier, AsyncValue<List<Street>>, String>((ref, areaId) {
  return StreetNotifier(ref, ref.read(streetRepositoryProvider), areaId);
});
