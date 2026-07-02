import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/order_dao.dart';
import '../data/order_repository_impl.dart';
import '../domain/order.dart';
import '../domain/order_item.dart';
import '../domain/order_repository.dart';
import '../domain/payment.dart';
import '../../customer/data/customer_dao.dart';
import '../../inventory/data/item_dao.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepositoryImpl(OrderDao(), CustomerDao(), ItemDao());
});

// Order management state
class OrderManagementNotifier extends StateNotifier<AsyncValue<List<AppOrder>>> {
  final OrderRepository _repo;
  String _status = 'all';
  String _filter = 'all';
  String? _customerId;

  OrderManagementNotifier(this._repo, {String? customerId})
      : _customerId = customerId,
        super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final orders = await _repo.getAllOrders(
        status:     _status == 'all' ? null : _status,
        filter:     _filter == 'all' ? null : _filter,
        customerId: _customerId,
      );
      state = AsyncValue.data(orders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void setStatus(String status) {
    _status = status;
    load();
  }

  void setFilter(String filter) {
    _filter = filter;
    load();
  }

  Future<void> updateDeliveryStatus(String orderId, String status) async {
    await _repo.updateDeliveryStatus(orderId, status);
    await load();
  }

  Future<void> addPayment(Payment payment) async {
    await _repo.addPayment(payment);
    await load();
  }

  Future<void> deleteOrder(String id) async {
    await _repo.deleteOrder(id);
    await load();
  }

  Future<void> createOrder(AppOrder order, List<OrderItem> items) async {
    await _repo.createOrder(order, items);
    await load();
  }
}

final orderManagementProvider =
    StateNotifierProvider<OrderManagementNotifier, AsyncValue<List<AppOrder>>>(
        (ref) => OrderManagementNotifier(ref.read(orderRepositoryProvider)));

// Per-customer orders
final customerOrdersProvider = StateNotifierProvider.family<
    OrderManagementNotifier, AsyncValue<List<AppOrder>>, String>(
  (ref, customerId) => OrderManagementNotifier(
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
  final items    = await repo.getOrderItems(orderId);
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
