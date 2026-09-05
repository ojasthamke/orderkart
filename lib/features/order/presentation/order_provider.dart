import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../data/order_dao.dart';
import '../data/order_questions_dao.dart';
import '../data/order_repository_impl.dart';
import '../domain/order.dart';
import '../domain/order_item.dart';
import '../domain/order_repository.dart';
import '../domain/payment.dart';
import '../../customer/data/customer_dao.dart';
import '../../inventory/data/item_dao.dart';
import '../../customer/presentation/customer_provider.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../../search/presentation/search_provider.dart';
import '../../../core/services/customer_order_sync_service.dart';


final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepositoryImpl(OrderDao(), CustomerDao(), ItemDao());
});

// Order management state
class OrderManagementNotifier
    extends StateNotifier<AsyncValue<List<AppOrder>>> {
  final Ref _ref;
  final OrderRepository _repo;
  String _filter = 'all';
  final String? _customerId;

  Timer? _pollTimer;
  StreamSubscription? _syncSub;

  OrderManagementNotifier(this._ref, this._repo, {String? customerId})
      : _customerId = customerId,
        super(const AsyncValue.loading()) {
    load();
    // Instant reactive listener on real-time order events
    _syncSub = CustomerOrderSyncService.instance.onOrderChanged.listen((_) {
      if (mounted) {
        load(silent: true);
      }
    });
    // Fallback polling timer every 15 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }
    // 1. FAST OFFLINE FIRST: Query local SQLite database immediately for instant UI
    try {
      final orders = await _repo.getAllOrders(
        status: null,
        filter: _filter == 'all' ? null : _filter,
        customerId: _customerId,
      );
      state = AsyncValue.data(orders);
    } catch (e, st) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }

    // 2. BACKGROUND NON-BLOCKING SYNC: Fetch cloud updates silently
    unawaited(Future(() async {
      try {
        await CustomerOrderSyncService.instance.syncOrders();
      } catch (e) {
        debugPrint('Background non-blocking syncOrders error: $e');
      }
    }));
  }

  void _invalidateAll({String? orderId, String? customerId}) {
    if (orderId != null && orderId.isNotEmpty) {
      _ref.invalidate(orderDetailProvider(orderId));
    }
    if (customerId != null && customerId.isNotEmpty) {
      _ref.invalidate(customerOrdersProvider(customerId));
      _ref.invalidate(customerDetailProvider(customerId));
    }
    _ref.invalidate(customerOrdersProvider);
    _ref.invalidate(orderDetailProvider);
    _ref.invalidate(customerListProvider);
    _ref.invalidate(customerDetailProvider);
    _ref.invalidate(inventoryProvider);
    _ref.invalidate(lowStockProvider);
    _ref.invalidate(stockSummaryProvider);
    _ref.invalidate(outOfStockProvider);
    _ref.invalidate(stockHistoryProvider);
    _ref.invalidate(analyticsSummaryProvider);
    _ref.invalidate(weeklyChartProvider);
    _ref.invalidate(monthlyChartProvider);
    _ref.invalidate(searchProvider);
    _ref.invalidate(topCustomersProvider);
    _ref.invalidate(dashboardOrdersProvider);
    _ref.invalidate(pendingCustomersProvider);
    _ref.invalidate(overpaidCustomersProvider);
    _ref.invalidate(allCustomersProvider);
    _ref.invalidate(todaysDetailedReportProvider);
    _ref.invalidate(orderedItemStatsProvider);
    _ref.invalidate(customerSavingsProvider);
    _ref.invalidate(profitLossProvider);
    _ref.invalidate(orderAnswersProvider);
    _ref.invalidate(preOrderDateCountsProvider);
  }

  void setStatus(String status) {
    load();
  }

  void setFilter(String filter) {
    _filter = filter;
    load();
  }

  Future<void> updateDeliveryStatus(String orderId, String status) async {
    await _repo.updateDeliveryStatus(orderId, status);
    await load(silent: true);
    _invalidateAll(orderId: orderId);
  }

  Future<void> addPayment(Payment payment) async {
    await _repo.addPayment(payment);
    await load(silent: true);
    _invalidateAll(orderId: payment.orderId, customerId: payment.customerId);
  }

  Future<void> deleteOrder(String id) async {
    final order = await _repo.getOrderById(id);
    await _repo.deleteOrder(id);
    await load(silent: true);
    _invalidateAll(orderId: id, customerId: order?.customerId);
  }

  Future<void> createOrder(AppOrder order, List<OrderItem> items) async {
    await _repo.createOrder(order, items);
    await load(silent: true);
    _invalidateAll(orderId: order.id, customerId: order.customerId);
  }

  Future<void> updateOrder(AppOrder order) async {
    await _repo.updateOrder(order);
    await load(silent: true);
    _invalidateAll(orderId: order.id, customerId: order.customerId);
  }

  Future<Map<String, dynamic>> updateOrderRates(String orderId) async {
    final result = await _repo.updateOrderRates(orderId);
    await load(silent: true);
    _invalidateAll(orderId: orderId);
    return result;
  }

  Future<Map<String, dynamic>> toggleOrderItemAvailability(
      String orderId, String orderItemId) async {
    final result =
        await _repo.toggleOrderItemAvailability(orderId, orderItemId);
    await load(silent: true);
    _invalidateAll(orderId: orderId);
    return result;
  }
}

final orderManagementProvider =
    StateNotifierProvider<OrderManagementNotifier, AsyncValue<List<AppOrder>>>(
        (ref) =>
            OrderManagementNotifier(ref, ref.read(orderRepositoryProvider)));

// Per-customer orders
final customerOrdersProvider = StateNotifierProvider.family<
    OrderManagementNotifier, AsyncValue<List<AppOrder>>, String>(
  (ref, customerId) => OrderManagementNotifier(
    ref,
    ref.read(orderRepositoryProvider),
    customerId: customerId,
  ),
);

// Single order detail
final orderDetailProvider =
    FutureProvider.family<AppOrder?, String>((ref, orderId) async {
  final repo = ref.read(orderRepositoryProvider);
  final order = await repo.getOrderById(orderId);
  if (order == null) return null;
  final items = await repo.getOrderItems(orderId);
  final payments = await repo.getOrderPayments(orderId);
  return order.copyWith(items: items, payments: payments);
});

// Analytics
final analyticsSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.read(orderRepositoryProvider).getAnalyticsSummary();
});

// Weekly/Monthly chart data
final weeklyChartProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return OrderDao().getWeeklySales();
});

final monthlyChartProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return OrderDao().getMonthlySales();
});

final topCustomersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return OrderDao().getTopCustomers();
});

final todaysDetailedReportProvider =
    FutureProvider<Map<String, dynamic>>((ref) {
  return OrderDao().getTodaysDetailedReport();
});

final profitLossProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return OrderDao().getProfitLossStatement();
});

class DashboardOrdersParams {
  final String? filter;
  final DateTime? startDate;
  final DateTime? endDate;

  const DashboardOrdersParams({this.filter, this.startDate, this.endDate});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardOrdersParams &&
          runtimeType == other.runtimeType &&
          filter == other.filter &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => filter.hashCode ^ startDate.hashCode ^ endDate.hashCode;
}

final dashboardOrdersProvider =
    FutureProvider.family<List<AppOrder>, DashboardOrdersParams>((ref, params) {
  // Listen to real-time order sync events so dashboard immediately reloads when customer orders
  final sub = CustomerOrderSyncService.instance.onOrderChanged.listen((_) {
    ref.invalidateSelf();
  });
  ref.onDispose(() => sub.cancel());

  final repo = ref.read(orderRepositoryProvider);
  return repo.getAllOrders(
    filter: params.filter,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

/// Per-customer savings: discounts + market-price savings combined
/// Returns {'total': double, 'monthly': double}
final customerSavingsProvider =
    FutureProvider.family<Map<String, double>, String>((ref, customerId) {
  return OrderDao().getCustomerSavings(customerId);
});

final orderAnswersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, orderId) {
  return OrderQuestionDao.instance.getOrderAnswers(orderId);
});

final preOrderDateCountsProvider = FutureProvider<Map<String, int>>((ref) {
  return OrderDao().getPreOrderDateCounts();
});
