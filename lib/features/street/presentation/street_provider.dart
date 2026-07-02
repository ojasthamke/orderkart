import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/street_dao.dart';
import '../data/street_repository_impl.dart';
import '../domain/street.dart';
import '../domain/street_repository.dart';

final streetRepositoryProvider = Provider<StreetRepository>(
    (ref) => StreetRepositoryImpl(StreetDao()));

class StreetNotifier extends StateNotifier<AsyncValue<List<Street>>> {
  final StreetRepository _repo;
  final String areaId;
  String _search = '';

  StreetNotifier(this._repo, this.areaId) : super(const AsyncValue.loading()) {
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

  void search(String q) {
    _search = q;
    load();
  }

  Future<void> add(Street s) async {
    await _repo.addStreet(s);
    await load();
  }

  Future<void> update(Street s) async {
    await _repo.updateStreet(s);
    await load();
  }

  Future<void> delete(String id) async {
    await _repo.deleteStreet(id);
    await load();
  }
}

final streetProviderFamily = StateNotifierProvider.family<
    StreetNotifier, AsyncValue<List<Street>>, String>((ref, areaId) {
  return StreetNotifier(ref.read(streetRepositoryProvider), areaId);
});
