import 'package:uuid/uuid.dart';
import '../domain/order.dart';
import '../domain/order_item.dart';
import '../domain/payment.dart';
import '../domain/order_repository.dart';
import '../../customer/data/customer_dao.dart';
import '../../inventory/data/item_dao.dart';
import '../../inventory/domain/stock_history.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import 'order_dao.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderDao _orderDao;
  final CustomerDao _customerDao;
  final ItemDao _itemDao;
  final _uuid = const Uuid();

  OrderRepositoryImpl(this._orderDao, this._customerDao, this._itemDao);

  @override
  Future<List<AppOrder>> getAllOrders({
    String? status,
    String? filter,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _orderDao.getAllOrders(
        status: status,
        filter: filter,
        customerId: customerId,
        startDate: startDate,
        endDate: endDate,
      );

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
    final db = await DatabaseHelper.instance.database;
    return await db.transaction((txn) async {
      final existing = await _orderDao.getOrderById(order.id);
      if (existing != null) {
        final oldItems = await _orderDao.getOrderItems(order.id);
        for (final oldItem in oldItems) {
          if (oldItem.itemId.isNotEmpty) {
            await _itemDao.adjustStock(oldItem.itemId, oldItem.quantity, executor: txn);
            await _itemDao.insertStockHistory(StockHistory(
              id:           _uuid.v4(),
              itemId:       oldItem.itemId,
              itemName:     oldItem.itemName,
              changeAmount: oldItem.quantity,
              reason:       'order_edit_restore',
              orderId:      order.id,
              createdAt:    DateTime.now(),
            ), executor: txn);
          }
        }
        await _orderDao.deleteOrderItems(order.id, executor: txn);
      }

      final orderId = await _orderDao.insertOrder(order, executor: txn);

      for (final item in items) {
        await _orderDao.insertOrderItem(item.copyWith(orderId: orderId), executor: txn);

        if (item.itemId.isNotEmpty) {
          await _itemDao.adjustStock(item.itemId, -item.quantity, executor: txn);
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
            ), executor: txn);
          }
        }
      }

      await _customerDao.recalcCustomerTotals(order.customerId, executor: txn);
      return orderId;
    });
  }

  @override
  Future<void> updateOrder(AppOrder order) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await _orderDao.updateOrder(order, executor: txn);
      await _customerDao.recalcCustomerTotals(order.customerId, executor: txn);
    });
  }

  @override
  Future<void> deleteOrder(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final order = await _orderDao.getOrderById(id);
      if (order != null) {
        final oldItems = await _orderDao.getOrderItems(id);
        for (final oldItem in oldItems) {
          if (oldItem.itemId.isNotEmpty) {
            await _itemDao.adjustStock(oldItem.itemId, oldItem.quantity, executor: txn);
            await _itemDao.insertStockHistory(StockHistory(
              id:           _uuid.v4(),
              itemId:       oldItem.itemId,
              itemName:     oldItem.itemName,
              changeAmount: oldItem.quantity,
              reason:       'order_delete',
              orderId:      id,
              createdAt:    DateTime.now(),
            ), executor: txn);
          }
        }
      }
      await _orderDao.deleteOrder(id, executor: txn);
      if (order != null) {
        await _customerDao.recalcCustomerTotals(order.customerId, executor: txn);
      }
    });
  }

  @override
  Future<void> updateDeliveryStatus(String orderId, String status) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final order = await _orderDao.getOrderById(orderId);
      if (order == null) return;

      if (status == 'cancelled' && order.deliveryStatus != 'cancelled') {
        final oldItems = await _orderDao.getOrderItems(orderId);
        for (final oldItem in oldItems) {
          if (oldItem.itemId.isNotEmpty) {
            await _itemDao.adjustStock(oldItem.itemId, oldItem.quantity, executor: txn);
            await _itemDao.insertStockHistory(StockHistory(
              id:           _uuid.v4(),
              itemId:       oldItem.itemId,
              itemName:     oldItem.itemName,
              changeAmount: oldItem.quantity,
              reason:       'order_cancelled',
              orderId:      orderId,
              createdAt:    DateTime.now(),
            ), executor: txn);
          }
        }
      }

      await _orderDao.updateDeliveryStatus(orderId, status, executor: txn);
      await _customerDao.recalcCustomerTotals(order.customerId, executor: txn);
    });
  }

  @override
  Future<void> addPayment(Payment payment) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await _orderDao.insertPayment(payment, executor: txn);
      final allPayments = await _orderDao.getOrderPayments(payment.orderId);
      final order = await _orderDao.getOrderById(payment.orderId);
      if (order != null) {
        final totalPaid = allPayments.fold<double>(0, (sum, p) => sum + p.amount);
        final remaining = (order.grandTotal - totalPaid).clamp(0, double.infinity);
        await _orderDao.updateOrderPayment(
            payment.orderId, totalPaid, remaining.toDouble(), executor: txn);
        await _customerDao.recalcCustomerTotals(payment.customerId, executor: txn);
      }
    });
  }

  @override
  Future<void> updateOrderPayment(
      String orderId, double paidAmount, double remainingAmount) =>
      _orderDao.updateOrderPayment(orderId, paidAmount, remainingAmount);

  @override
  Future<Map<String, dynamic>> getAnalyticsSummary() =>
      _orderDao.getAnalyticsSummary();
}
