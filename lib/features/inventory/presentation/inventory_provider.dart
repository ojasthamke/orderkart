import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/item_dao.dart';
import '../data/inventory_repository_impl.dart';
import '../domain/inventory_repository.dart';
import '../domain/item.dart';
import '../domain/stock_history.dart';
import '../../order/presentation/order_provider.dart';
import '../../search/presentation/search_provider.dart';

final inventoryRepositoryProvider =
    Provider<InventoryRepository>((ref) => InventoryRepositoryImpl(ItemDao()));

class InventoryNotifier extends StateNotifier<AsyncValue<List<Item>>> {
  final Ref _ref;
  final InventoryRepository _repo;
  String _category = '';
  String _search = '';
  String _sort = 'name';

  int _loadToken = 0;

  InventoryNotifier(this._ref, this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool silent = false}) async {
    final currentToken = ++_loadToken;
    if (!silent && state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }
    try {
      final items = await _repo.getAllItems(
        category: _category.isEmpty ? null : _category,
        searchQuery: _search.isEmpty ? null : _search,
        sortBy: _sort,
      );
      if (currentToken == _loadToken) {
        state = AsyncValue.data(items);
      }
    } catch (e, st) {
      if (currentToken == _loadToken) {
        state = AsyncValue<List<Item>>.error(e, st).copyWithPrevious(state);
      }
    }
  }

  void _invalidateAll() {
    _ref.invalidate(lowStockProvider);
    _ref.invalidate(outOfStockProvider);
    _ref.invalidate(stockSummaryProvider);
    _ref.invalidate(stockHistoryProvider);
    _ref.invalidate(spillageHistoryProvider);
    _ref.invalidate(analyticsSummaryProvider);
    _ref.invalidate(profitLossProvider);
    _ref.invalidate(searchProvider);
    _ref.invalidate(orderedItemStatsProvider);
    _ref.invalidate(todaysDetailedReportProvider);
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
    try {
      await _repo.addItem(item);
      await load(silent: true);
      _invalidateAll();
    } catch (e, st) {
      state = AsyncValue<List<Item>>.error(e, st).copyWithPrevious(state);
    }
  }

  Future<void> updateItem(Item item) async {
    try {
      await _repo.updateItem(item);
      await load(silent: true);
      _invalidateAll();
    } catch (e, st) {
      state = AsyncValue<List<Item>>.error(e, st).copyWithPrevious(state);
    }
  }

  Future<void> updateItems(List<Item> items) async {
    try {
      await _repo.updateItems(items);
      await load(silent: true);
      _invalidateAll();
    } catch (e, st) {
      state = AsyncValue<List<Item>>.error(e, st).copyWithPrevious(state);
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _repo.deleteItem(id);
      await load(silent: true);
      _invalidateAll();
    } catch (e, st) {
      state = AsyncValue<List<Item>>.error(e, st).copyWithPrevious(state);
    }
  }

  Future<void> adjustStock(String itemId, double change, String reason) async {
    try {
      await _repo.adjustStock(itemId, change, reason);
      await load(silent: true);
      _invalidateAll();
    } catch (e, st) {
      state = AsyncValue<List<Item>>.error(e, st).copyWithPrevious(state);
    }
  }

  Future<void> reorderItems(List<String> itemIds) async {
    try {
      await _repo.updateItemSequences(itemIds);
      await load();
      _invalidateAll();
    } catch (e, st) {
      state = AsyncValue<List<Item>>.error(e, st).copyWithPrevious(state);
    }
  }

  Future<void> syncWithServer() async {
    state = const AsyncValue.loading();
    try {
      await _repo.syncWithServer();
      await load(silent: true);
      _invalidateAll();
    } catch (e, st) {
      state = AsyncValue<List<Item>>.error(e, st).copyWithPrevious(state);
    }
  }
}

final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, AsyncValue<List<Item>>>(
        (ref) => InventoryNotifier(ref, ref.read(inventoryRepositoryProvider)));

final lowStockProvider = FutureProvider<List<Item>>(
    (ref) => ref.read(inventoryRepositoryProvider).getLowStockItems());

final outOfStockProvider = FutureProvider<List<Item>>((ref) async {
  final items = await ref.read(inventoryRepositoryProvider).getAllItems();
  return items.where((i) => i.stock < 0.001).toList();
});

final stockSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final items = await ref.read(inventoryRepositoryProvider).getAllItems();
  final totalItems = items.length;
  final outOfStock = items.where((i) => i.stock < 0.001).toList();
  final lowStock =
      items.where((i) => i.isLowStock && i.stock >= 0.001).toList();

  double totalCostValue = 0;
  double totalSellingValue = 0;
  for (final item in items) {
    if (item.stock > 0) {
      totalCostValue += item.stock * item.costPrice;
      totalSellingValue += item.stock * item.sellingPrice;
    }
  }

  return {
    'total_items': totalItems,
    'out_of_stock_count': outOfStock.length,
    'low_stock_count': lowStock.length,
    'out_of_stock_items': outOfStock,
    'low_stock_items': lowStock,
    'cost_value': totalCostValue,
    'selling_value': totalSellingValue,
    'potential_profit': totalSellingValue - totalCostValue,
  };
});

final stockHistoryProvider =
    FutureProvider.family<List<StockHistory>, String>((ref, itemId) {
  return ref.read(inventoryRepositoryProvider).getStockHistory(itemId);
});

final spillageHistoryProvider = FutureProvider<List<StockHistory>>((ref) {
  return ref.read(inventoryRepositoryProvider).getSpillageHistory();
});

final orderedItemStatsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, param) async {
  final parts = param.contains('|') ? param.split('|') : param.split(':');
  final status = parts.isNotEmpty ? parts[0] : 'all';
  final dateFilter = parts.length > 1 ? parts[1] : 'all';
  DateTime? startDate;
  DateTime? endDate;
  if (dateFilter == 'custom' && parts.length >= 4) {
    final startMs = int.tryParse(parts[2]);
    final endMs = int.tryParse(parts[3]);
    if (startMs != null && endMs != null) {
      startDate = DateTime.fromMillisecondsSinceEpoch(startMs);
      endDate = DateTime.fromMillisecondsSinceEpoch(endMs);
    } else {
      startDate = DateTime.tryParse(parts[2]);
      endDate = DateTime.tryParse(parts[3]);
    }
  }
  return await ItemDao().getOrderedItemStats(
    status: status,
    dateFilter: dateFilter,
    startDate: startDate,
    endDate: endDate,
  );
});

final orderNowStatusProvider =
    StateNotifierProvider<OrderNowStatusNotifier, AsyncValue<String>>((ref) {
  return OrderNowStatusNotifier();
});

class OrderNowStatusNotifier extends StateNotifier<AsyncValue<String>> {
  OrderNowStatusNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('settings')
          .select('value')
          .eq('key', 'order_now_status')
          .maybeSingle();
      final status = res?['value'] as String? ?? 'closed';
      state = AsyncValue.data(status);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setStatus(String status) async {
    state = const AsyncValue.loading();
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) {
        await client.auth.signInWithPassword(
          email: 'admin@aplibhaji.com',
          password: 'adminpassword',
        );
      }
      await client.from('settings').upsert({
        'key': 'order_now_status',
        'value': status,
      });
      state = AsyncValue.data(status);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

