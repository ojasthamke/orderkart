import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/order.dart';
import '../domain/order_item.dart';
import '../domain/payment.dart';
import '../domain/order_repository.dart';
import '../../customer/data/customer_dao.dart';
import '../../inventory/data/item_dao.dart';
import '../../inventory/domain/item.dart';
import '../../inventory/domain/stock_history.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../core/security/app_mode_service.dart';
import '../../../core/services/customer_order_sync_service.dart';
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

  double _convertQtyToBaseUnit(double qty, String itemUnit, Item dbItem) {
    if (itemUnit.isEmpty ||
        itemUnit.toLowerCase() == dbItem.unit.toLowerCase()) {
      return qty;
    }
    return UnitConverter.convert(
      quantity: qty,
      fromUnit: itemUnit,
      toUnit: dbItem.unit,
    );
  }

  @override
  Future<String> createOrder(AppOrder order, List<OrderItem> items) async {
    final db = await DatabaseHelper.instance.database;
    // Read AppMode BEFORE the transaction to avoid database deadlock
    // (AppModeService.getAppMode() may access the DB, which deadlocks inside a txn)
    final appMode = await AppModeService.getAppMode();
    final Set<String> affectedItemIds = {};
    final String orderId = await db.transaction((txn) async {
      final existing = await _orderDao.getOrderById(order.id, executor: txn);

      final bool wasNotCancelledOrDenied = existing != null &&
          existing.deliveryStatus != 'cancelled' &&
          existing.deliveryStatus != 'denied';

      final String oldOrderType = existing?.orderType ?? order.orderType;
      final bool wasQuick = oldOrderType.toLowerCase() == 'order now' || oldOrderType.toLowerCase() == 'quick';

      if (wasNotCancelledOrDenied) {
        final oldItems = await _orderDao.getOrderItems(order.id, executor: txn);
        for (final oldItem in oldItems) {
          if (oldItem.itemId.isNotEmpty && oldItem.isAvailable && oldItem.totalPrice > 0) {
            final dbItem =
                await _itemDao.getItemById(oldItem.itemId, executor: txn);
            if (dbItem != null) {
              final baseQty = _convertQtyToBaseUnit(
                  oldItem.quantity, oldItem.itemUnit, dbItem);
              if (wasQuick) {
                await _itemDao.adjustOrderNowStock(oldItem.itemId, baseQty,
                    executor: txn);
              } else {
                await _itemDao.adjustStock(oldItem.itemId, baseQty,
                    executor: txn);
              }
              affectedItemIds.add(oldItem.itemId);
              await _itemDao.insertStockHistory(
                  StockHistory(
                    id: _uuid.v4(),
                    itemId: oldItem.itemId,
                    itemName: oldItem.itemName,
                    changeAmount: baseQty,
                    reason: 'order_edit_restore',
                    orderId: order.id,
                    createdAt: DateTime.now(),
                  ),
                  executor: txn);
            }
          }
        }
        await _orderDao.deleteOrderItems(order.id, executor: txn);
      } else if (existing != null) {
        // Just clear items, no stock reversion since it was already cancelled/denied/restored
        await _orderDao.deleteOrderItems(order.id, executor: txn);
      }

      final orderId = await _orderDao.insertOrder(order,
          executor: txn, appMode: appMode);

      final bool shouldDeductStock =
          order.deliveryStatus != 'cancelled' && order.deliveryStatus != 'denied';
      final bool isNewQuick = order.orderType.toLowerCase() == 'order now' || order.orderType.toLowerCase() == 'quick';

      for (final item in items) {
        await _orderDao.insertOrderItem(item.copyWith(orderId: orderId),
            executor: txn);

        if (item.itemId.isNotEmpty && shouldDeductStock && item.isAvailable && item.totalPrice > 0) {
          final dbItem = await _itemDao.getItemById(item.itemId, executor: txn);
          if (dbItem != null) {
            final baseQty =
                _convertQtyToBaseUnit(item.quantity, item.itemUnit, dbItem);
            if (isNewQuick) {
              await _itemDao.adjustOrderNowStock(item.itemId, -baseQty,
                  executor: txn);
            } else {
              await _itemDao.adjustStock(item.itemId, -baseQty, executor: txn);
            }
            affectedItemIds.add(item.itemId);
            await _itemDao.insertStockHistory(
                StockHistory(
                  id: _uuid.v4(),
                  itemId: item.itemId,
                  itemName: item.itemName,
                  changeAmount: -baseQty,
                  reason: 'order',
                  orderId: orderId,
                  createdAt: DateTime.now(),
                ),
                executor: txn);
          }
        }
      }

      await _customerDao.recalcCustomerTotals(order.customerId, executor: txn);
      return orderId;
    });

    // Trigger instant cloud sync for newly created/edited order and updated inventory stock
    if (affectedItemIds.isNotEmpty) {
      unawaited(_syncItemsStockToSupabase(affectedItemIds));
    }
    unawaited(CustomerOrderSyncService.instance.pushModifiedOrders());
    return orderId;
  }

  @override
  Future<void> updateOrder(AppOrder order) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await _orderDao.updateOrder(order, executor: txn);
      await _customerDao.recalcCustomerTotals(order.customerId, executor: txn);
    });

    // Trigger instant cloud sync for updated order
    unawaited(CustomerOrderSyncService.instance.pushModifiedOrders());
  }


  Future<void> _syncItemsStockToSupabase(Set<String> itemIds) async {
    if (itemIds.isEmpty) return;
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) {
        await client.auth.signInWithPassword(
          email: 'admin@aplibhaji.com',
          password: 'adminpassword',
        );
      }
      for (final itemId in itemIds) {
        final dbItem = await _itemDao.getItemById(itemId);
        if (dbItem != null) {
          await client.from('products').update({
            'stock': dbItem.stock,
            'order_now_stock': dbItem.orderNowStock,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', itemId);
          debugPrint('[STOCK-SYNC] Synced stock for ${dbItem.name} (stock: ${dbItem.stock}, order_now: ${dbItem.orderNowStock}) to Supabase.');
        }
      }
    } catch (e) {
      debugPrint('[STOCK-SYNC] Failed to sync updated stock to Supabase: $e');
    }
  }

  @override
  Future<void> deleteOrder(String id) async {
    final db = await DatabaseHelper.instance.database;
    final Set<String> affectedItemIds = {};
    await db.transaction((txn) async {
      final order = await _orderDao.getOrderById(id, executor: txn);
      if (order != null && order.deliveryStatus != 'cancelled') {
        final oldItems = await _orderDao.getOrderItems(id, executor: txn);
        for (final oldItem in oldItems) {
          if (oldItem.itemId.isNotEmpty) {
            final dbItem =
                await _itemDao.getItemById(oldItem.itemId, executor: txn);
            if (dbItem != null) {
              final baseQty = _convertQtyToBaseUnit(
                  oldItem.quantity, oldItem.itemUnit, dbItem);
              final bool isQuick = order.orderType.toLowerCase() == 'order now' || order.orderType.toLowerCase() == 'quick';
              if (isQuick) {
                await _itemDao.adjustOrderNowStock(oldItem.itemId, baseQty,
                    executor: txn);
              } else {
                await _itemDao.adjustStock(oldItem.itemId, baseQty,
                    executor: txn);
              }
              affectedItemIds.add(oldItem.itemId);
              await _itemDao.insertStockHistory(
                  StockHistory(
                    id: _uuid.v4(),
                    itemId: oldItem.itemId,
                    itemName: oldItem.itemName,
                    changeAmount: baseQty,
                    reason: 'order_delete',
                    orderId: id,
                    createdAt: DateTime.now(),
                  ),
                  executor: txn);
            }
          }
        }
      }
      await txn.delete('order_question_answers',
          where: 'order_id = ?', whereArgs: [id]);
      await _orderDao.deleteOrder(id, executor: txn);
      if (order != null) {
        await _customerDao.recalcCustomerTotals(order.customerId,
            executor: txn);
      }
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final String remoteId = uuidRegex.hasMatch(id) ? id : _uuid.v5(Uuid.NAMESPACE_DNS, 'aplibhaji.customer.$id');

      // Log order deletion in SQLite deleted_orders (both local id and remoteId)
      await txn.insert('deleted_orders', {
        'id': id,
        'deleted_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (remoteId != id) {
        await txn.insert('deleted_orders', {
          'id': remoteId,
          'deleted_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    // Sync restored stock to Supabase in background
    if (affectedItemIds.isNotEmpty) {
      unawaited(_syncItemsStockToSupabase(affectedItemIds));
    }

    // Delete on Supabase using valid UUID remoteId (outside of SQLite transaction to prevent blocking DB)
    try {
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final String remoteId = uuidRegex.hasMatch(id) ? id : _uuid.v5(Uuid.NAMESPACE_DNS, 'aplibhaji.customer.$id');
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) {
        await client.auth.signInWithPassword(
          email: 'admin@aplibhaji.com',
          password: 'adminpassword',
        );
      }
      await client.from('order_items').delete().eq('order_id', remoteId);
      await client.from('orders').delete().eq('id', remoteId);
    } catch (e) {
      // Safe check for offline mode
    }
  }

  @override
  Future<void> updateDeliveryStatus(String orderId, String status) async {
    final db = await DatabaseHelper.instance.database;
    final Set<String> affectedItemIds = {};
    await db.transaction((txn) async {
      final order = await _orderDao.getOrderById(orderId, executor: txn);
      if (order == null) return;

      final isCancelling = (status == 'cancelled' || status == 'denied');
      final wasCancelled = (order.deliveryStatus == 'cancelled' || order.deliveryStatus == 'denied');
      final bool isQuick = order.orderType.toLowerCase() == 'order now' || order.orderType.toLowerCase() == 'quick';

      if (isCancelling && !wasCancelled) {
        final oldItems = await _orderDao.getOrderItems(orderId, executor: txn);
        for (final oldItem in oldItems) {
          if (oldItem.itemId.isNotEmpty) {
            final dbItem =
                await _itemDao.getItemById(oldItem.itemId, executor: txn);
            if (dbItem != null) {
              final baseQty = _convertQtyToBaseUnit(
                  oldItem.quantity, oldItem.itemUnit, dbItem);
              if (isQuick) {
                await _itemDao.adjustOrderNowStock(oldItem.itemId, baseQty,
                    executor: txn);
              } else {
                await _itemDao.adjustStock(oldItem.itemId, baseQty,
                    executor: txn);
              }
              affectedItemIds.add(oldItem.itemId);
              await _itemDao.insertStockHistory(
                  StockHistory(
                    id: _uuid.v4(),
                    itemId: oldItem.itemId,
                    itemName: oldItem.itemName,
                    changeAmount: baseQty,
                    reason: status == 'denied' ? 'order_denied' : 'order_cancelled',
                    orderId: orderId,
                    createdAt: DateTime.now(),
                  ),
                  executor: txn);
            }
          }
        }
        // Set order paid and remaining to 0 upon cancellation/denial
        await txn.update(
          'orders',
          {'paid_amount': 0.0, 'remaining_amount': 0.0},
          where: 'id = ?',
          whereArgs: [orderId],
        );
      } else if (!isCancelling && wasCancelled) {
        // Un-cancel / un-deny: deduct stock again
        final oldItems = await _orderDao.getOrderItems(orderId, executor: txn);
        for (final oldItem in oldItems) {
          if (oldItem.itemId.isNotEmpty) {
            final dbItem =
                await _itemDao.getItemById(oldItem.itemId, executor: txn);
            if (dbItem != null) {
              final baseQty = _convertQtyToBaseUnit(
                  oldItem.quantity, oldItem.itemUnit, dbItem);
              if (isQuick) {
                await _itemDao.adjustOrderNowStock(oldItem.itemId, -baseQty,
                    executor: txn);
              } else {
                await _itemDao.adjustStock(oldItem.itemId, -baseQty,
                    executor: txn);
              }
              affectedItemIds.add(oldItem.itemId);
              await _itemDao.insertStockHistory(
                  StockHistory(
                    id: _uuid.v4(),
                    itemId: oldItem.itemId,
                    itemName: oldItem.itemName,
                    changeAmount: -baseQty,
                    reason: 'order_uncancelled',
                    orderId: orderId,
                    createdAt: DateTime.now(),
                  ),
                  executor: txn);
            }
          }
        }
        // Re-calculate actual paid amount from existing payment records for this order
        final existingPayments =
            await _orderDao.getOrderPayments(orderId, executor: txn);
        final sumPaid =
            existingPayments.fold<double>(0.0, (sum, p) => sum + p.amount);
        final remaining =
            (order.grandTotal - sumPaid).clamp(0.0, double.infinity);
        await txn.update(
          'orders',
          {'paid_amount': sumPaid, 'remaining_amount': remaining},
          where: 'id = ?',
          whereArgs: [orderId],
        );
      }

      await _orderDao.updateDeliveryStatus(orderId, status, executor: txn);
      await _customerDao.recalcCustomerTotals(order.customerId, executor: txn);
    });

    // Push status change and restored/deducted stock to Supabase immediately (outside txn)
    if (affectedItemIds.isNotEmpty) {
      unawaited(_syncItemsStockToSupabase(affectedItemIds));
    }
    unawaited(CustomerOrderSyncService.instance.pushModifiedOrders());
  }


  @override
  Future<void> addPayment(Payment payment) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await _orderDao.insertPayment(payment, executor: txn);
      final allPayments =
          await _orderDao.getOrderPayments(payment.orderId, executor: txn);
      final order =
          await _orderDao.getOrderById(payment.orderId, executor: txn);
      if (order != null) {
        final totalPaid =
            allPayments.fold<double>(0, (sum, p) => sum + p.amount);
        final remaining = order.grandTotal - totalPaid;
        await _orderDao.updateOrderPayment(
            payment.orderId, totalPaid, remaining,
            executor: txn);
        await _customerDao.recalcCustomerTotals(payment.customerId,
            executor: txn);
      }
    });

    // Trigger instant cloud sync for new payment
    unawaited(CustomerOrderSyncService.instance.pushModifiedOrders());
  }

  @override
  Future<void> updateOrderPayment(
      String orderId, double paidAmount, double remainingAmount) async {
    await _orderDao.updateOrderPayment(orderId, paidAmount, remainingAmount);
    unawaited(CustomerOrderSyncService.instance.pushModifiedOrders());
  }

  @override
  Future<Map<String, dynamic>> updateOrderRates(String orderId) async {
    final result = await _orderDao.updateOrderRates(orderId);
    unawaited(CustomerOrderSyncService.instance.pushModifiedOrders());
    return result;
  }

  @override
  Future<Map<String, dynamic>> toggleOrderItemAvailability(
      String orderId, String orderItemId) async {
    final result =
        await _orderDao.toggleOrderItemAvailability(orderId, orderItemId);
    unawaited(CustomerOrderSyncService.instance.pushModifiedOrders());
    return result;
  }

  @override
  Future<Map<String, dynamic>> getAnalyticsSummary() =>
      _orderDao.getAnalyticsSummary();
}

