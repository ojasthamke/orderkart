import 'package:uuid/uuid.dart';
import '../domain/order.dart';
import '../domain/order_item.dart';
import '../domain/payment.dart';
import '../domain/order_repository.dart';
import '../../customer/data/customer_dao.dart';
import '../../inventory/data/item_dao.dart';
import '../../inventory/domain/stock_history.dart';
import 'order_dao.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderDao _orderDao;
  final CustomerDao _customerDao;
  final ItemDao _itemDao;
  final _uuid = const Uuid();

  OrderRepositoryImpl(this._orderDao, this._customerDao, this._itemDao);

  @override
  Future<List<AppOrder>> getAllOrders(
      {String? status, String? filter, String? customerId}) =>
      _orderDao.getAllOrders(
          status: status, filter: filter, customerId: customerId);

  @override
  Future<AppOrder?> getOrderById(String id) => _orderDao.getOrderById(id);

  @override
  Future<List<OrderItem>> getOrderItems(String orderId) =>
      _orderDao.getOrderItems(orderId);

  @override
  Future<List<Payment>> getOrderPayments(String orderId) =>
      _orderDao.getOrderPayments(orderId);

  @override
  Future<String> createOrder(AppOrder order, List<OrderItem> items) async {
    final orderId = await _orderDao.insertOrder(order);

    // Insert all line items with the real order ID
    for (final item in items) {
      await _orderDao.insertOrderItem(item.copyWith(orderId: orderId));

      // Decrease stock if item has a valid item_id
      if (item.itemId.isNotEmpty) {
        await _itemDao.adjustStock(item.itemId, -item.quantity);
        final dbItem = await _itemDao.getItemById(item.itemId);
        if (dbItem != null) {
          await _itemDao.insertStockHistory(StockHistory(
            id:           _uuid.v4(),
            itemId:       item.itemId,
            itemName:     item.itemName,
            changeAmount: -item.quantity,
            reason:       'order',
            orderId:      orderId,
            createdAt:    DateTime.now(),
          ));
        }
      }
    }

    // Recalculate customer totals
    await _customerDao.recalcCustomerTotals(order.customerId);

    return orderId;
  }

  @override
  Future<void> updateOrder(AppOrder order) async {
    await _orderDao.updateOrder(order);
    await _customerDao.recalcCustomerTotals(order.customerId);
  }

  @override
  Future<void> deleteOrder(String id) async {
    final order = await _orderDao.getOrderById(id);
    await _orderDao.deleteOrder(id);
    if (order != null) {
      await _customerDao.recalcCustomerTotals(order.customerId);
    }
  }

  @override
  Future<void> updateDeliveryStatus(String orderId, String status) =>
      _orderDao.updateDeliveryStatus(orderId, status);

  @override
  Future<void> addPayment(Payment payment) async {
    await _orderDao.insertPayment(payment);
    // Recalculate order totals
    final allPayments = await _orderDao.getOrderPayments(payment.orderId);
    final order = await _orderDao.getOrderById(payment.orderId);
    if (order != null) {
      final totalPaid = allPayments.fold<double>(0, (sum, p) => sum + p.amount);
      final remaining = (order.grandTotal - totalPaid).clamp(0, double.infinity);
      await _orderDao.updateOrderPayment(
          payment.orderId, totalPaid, remaining.toDouble());
      await _customerDao.recalcCustomerTotals(payment.customerId);
    }
  }

  @override
  Future<void> updateOrderPayment(
      String orderId, double paidAmount, double remainingAmount) =>
      _orderDao.updateOrderPayment(orderId, paidAmount, remainingAmount);

  @override
  Future<Map<String, dynamic>> getAnalyticsSummary() =>
      _orderDao.getAnalyticsSummary();
}
