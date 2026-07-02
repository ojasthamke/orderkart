import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/search_dao.dart';
import '../domain/search_result.dart';

class SearchNotifier extends StateNotifier<AsyncValue<List<SearchResult>>> {
  final SearchDao _dao;
  SearchNotifier(this._dao) : super(const AsyncValue.data([]));

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final results = await _dao.globalSearch(query);
      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, AsyncValue<List<SearchResult>>>(
        (ref) => SearchNotifier(SearchDao()));
