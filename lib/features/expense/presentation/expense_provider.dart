import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/expense_dao.dart';
import '../data/expense_repository_impl.dart';
import '../domain/expense.dart';
import '../domain/expense_repository.dart';
import '../../order/presentation/order_provider.dart';

final expenseRepositoryProvider =
    Provider<ExpenseRepository>((ref) => ExpenseRepositoryImpl(ExpenseDao()));

class ExpenseNotifier extends StateNotifier<AsyncValue<List<Expense>>> {
  final Ref _ref;
  final ExpenseRepository _repo;
  String _search = '';
  String _category = '';
  String _month = '';

  ExpenseNotifier(this._ref, this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }
    try {
      final list = await _repo.getAllExpenses(
        searchQuery: _search.isEmpty ? null : _search,
        category: _category.isEmpty ? null : _category,
        month: _month.isEmpty ? null : _month,
      );
      state = AsyncValue.data(list);
    } catch (e, st) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void _invalidateAll() {
    _ref.invalidate(monthlySummaryProvider);
    _ref.invalidate(analyticsSummaryProvider);
    _ref.invalidate(weeklyChartProvider);
    _ref.invalidate(monthlyChartProvider);
  }

  void search(String q) {
    _search = q;
    load();
  }

  void filterCategory(String c) {
    _category = c;
    load();
  }

  void filterMonth(String m) {
    _month = m;
    load();
  }

  Future<void> add(Expense e) async {
    await _repo.addExpense(e);
    await load(silent: true);
    _invalidateAll();
  }

  Future<void> update(Expense e) async {
    await _repo.updateExpense(e);
    await load(silent: true);
    _invalidateAll();
  }

  Future<void> delete(String id) async {
    await _repo.deleteExpense(id);
    await load(silent: true);
    _invalidateAll();
  }
}

final expenseProvider =
    StateNotifierProvider<ExpenseNotifier, AsyncValue<List<Expense>>>(
        (ref) => ExpenseNotifier(ref, ref.read(expenseRepositoryProvider)));

final monthlySummaryProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.read(expenseRepositoryProvider).getMonthlySummary());
