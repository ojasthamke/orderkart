import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/item_dao.dart';
import '../data/inventory_repository_impl.dart';
import '../domain/inventory_repository.dart';
import '../domain/item.dart';
import '../domain/stock_history.dart';
import '../../order/presentation/order_provider.dart';
import '../../search/presentation/search_provider.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>(
    (ref) => InventoryRepositoryImpl(ItemDao()));

class InventoryNotifier extends StateNotifier<AsyncValue<List<Item>>> {
  final Ref _ref;
  final InventoryRepository _repo;
  String _category = '';
  String _search   = '';
  String _sort     = 'name';

  InventoryNotifier(this._ref, this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repo.getAllItems(
        category:    _category.isEmpty ? null : _category,
        searchQuery: _search.isEmpty   ? null : _search,
        sortBy:      _sort,
      );
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _invalidateAll() {
    _ref.invalidate(inventoryProvider);
    _ref.invalidate(lowStockProvider);
    _ref.invalidate(stockHistoryProvider);
    _ref.invalidate(analyticsSummaryProvider);
    _ref.invalidate(searchProvider);
  }

  void filterByCategory(String category) {
    _category = category;
    load();
  }

  void search(String q) {
    _search = q;
    load();
  }

  void sort(String s) {
    _sort = s;
    load();
  }

  Future<void> addItem(Item item) async {
    await _repo.addItem(item);
    await load();
    _invalidateAll();
  }

  Future<void> updateItem(Item item) async {
    await _repo.updateItem(item);
    await load();
    _invalidateAll();
  }

  Future<void> deleteItem(String id) async {
    await _repo.deleteItem(id);
    await load();
    _invalidateAll();
  }

  Future<void> adjustStock(
      String itemId, double change, String reason) async {
    await _repo.adjustStock(itemId, change, reason);
    await load();
    _invalidateAll();
  }
}

final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, AsyncValue<List<Item>>>(
        (ref) => InventoryNotifier(ref, ref.read(inventoryRepositoryProvider)));

final lowStockProvider = FutureProvider<List<Item>>(
    (ref) => ref.read(inventoryRepositoryProvider).getLowStockItems());

final stockHistoryProvider =
    FutureProvider.family<List<StockHistory>, String>((ref, itemId) {
  return ref.read(inventoryRepositoryProvider).getStockHistory(itemId);
});
