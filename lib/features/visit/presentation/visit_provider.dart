import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/visit_dao.dart';
import '../domain/app_visit.dart';

class VisitListNotifier extends StateNotifier<AsyncValue<List<AppVisit>>> {
  final VisitDao _dao;
  String _selectedDate = '';

  VisitListNotifier(this._dao) : super(const AsyncValue.loading()) {
    loadVisits();
  }

  void setDateFilter(String dateStr) {
    _selectedDate = dateStr;
    loadVisits();
  }

  Future<void> loadVisits({bool silent = false}) async {
    if (!silent && state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }
    try {
      final visits = _selectedDate.isEmpty
          ? await _dao.getAllVisits()
          : await _dao.getVisitsByDate(_selectedDate);
      state = AsyncValue.data(visits);
    } catch (e, st) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> addVisit(AppVisit visit) async {
    await _dao.insert(visit);
    await loadVisits(silent: true);
  }

  Future<void> updateVisit(AppVisit visit) async {
    await _dao.update(visit);
    await loadVisits(silent: true);
  }

  Future<void> deleteVisit(String id) async {
    await _dao.delete(id);
    await loadVisits(silent: true);
  }

  Future<void> markStatus(String id, String status) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;
    
    final visitIndex = currentState.indexWhere((v) => v.id == id);
    if (visitIndex == -1) return;

    final updated = currentState[visitIndex].copyWith(status: status);
    await updateVisit(updated);
  }
}

final visitDaoProvider = Provider((ref) => VisitDao());

final visitListProvider =
    StateNotifierProvider<VisitListNotifier, AsyncValue<List<AppVisit>>>((ref) {
  return VisitListNotifier(ref.read(visitDaoProvider));
});
