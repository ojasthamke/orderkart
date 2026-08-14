import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';

class CustomerOrderSyncService {
  CustomerOrderSyncService._();
  static final CustomerOrderSyncService instance = CustomerOrderSyncService._();

  static const String baseUrl = 'http://10.0.2.2:5000/api/merchant';
  final _uuid = const Uuid();
  Timer? _syncTimer;
  String? _authToken;

  void startSync() {
    _syncTimer?.cancel();
    // Run sync check every 15 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await syncOrders();
    });
  }

  void stopSync() {
    _syncTimer?.cancel();
  }

  Future<bool> _login() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': 'owner_pune',
          'password': 'orderkart_secure_2026',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _authToken = data['token'];
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('Merchant Sync Login Failed: $e');
    }
    return false;
  }

  Future<void> syncOrders() async {
    if (_authToken == null) {
      final success = await _login();
      if (!success) return;
    }

    try {
      // 1. PULL customer orders from PostgreSQL backend
      final response = await http.get(
        Uri.parse('$baseUrl/orders/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 401) {
        // Token expired, re-login next loop
        _authToken = null;
        return;
      }

      if (response.statusCode == 200) {
        final List<dynamic> orders = jsonDecode(response.body);
        final db = await DatabaseHelper.instance.database;

        for (var ord in orders) {
          try {
            await db.transaction((txn) async {
              final String orderId = ord['id'];
          final String customerId = ord['customerId'] ?? ord['customer_id'] ?? '';
          final String customerName = ord['customerName'] ?? ord['customer_name'] ?? 'App Customer';
          final String customerPhone = ord['customerPhone'] ?? ord['customer_phone'] ?? 'Online App User';

          // A. Ensure customer exists in POS SQLite DB to prevent FK violation
          if (customerId.isNotEmpty) {
            final custCheck = await txn.query('customers', where: 'id = ?', whereArgs: [customerId]);
            if (custCheck.isEmpty) {
              // Find a valid street_id or location_id for FK safety
              final streetCheck = await txn.query('streets', columns: ['id'], limit: 1);
              String streetId = 'default_street';
              if (streetCheck.isNotEmpty) {
                streetId = streetCheck.first['id'] as String;
              } else {
                final locCheck = await txn.query('locations', columns: ['id'], limit: 1);
                if (locCheck.isNotEmpty) {
                  streetId = locCheck.first['id'] as String;
                }
              }

              final nowStr = DateTime.now().toIso8601String();
              await txn.insert('customers', {
                'id': customerId,
                'street_id': streetId,
                'location_id': streetId,
                'name': customerName,
                'phone1': customerPhone,
                'phone2': '',
                'whatsapp': customerPhone,
                'house_number': ord['houseNumber'] ?? '',
                'address': ord['address'] ?? '',
                'outstanding_balance': 0.0,
                'total_orders': 0,
                'total_paid': 0.0,
                'total_pending': 0.0,
                'customer_since': nowStr,
                'created_at': nowStr,
                'updated_at': nowStr,
              });
            }
          }

          // B. Check if order already exists in POS SQLite DB
          final orderCheck = await txn.query('orders', where: 'id = ?', whereArgs: [orderId]);
          final String serverStatus = ord['status'] ?? 'PENDING';

          if (orderCheck.isEmpty) {
            // Write new order
            final double grandTotal = double.tryParse(ord['grandTotal']?.toString() ?? '') ?? 0.0;
            final String payStat = (ord['paymentStatus'] ?? '').toString().toLowerCase();
            final bool isPaid = payStat == 'paid' || payStat == 'captured';

            final nowStr = DateTime.now().toIso8601String();
            await txn.insert('orders', {
              'id': orderId,
              'customer_id': customerId,
              'subtotal': double.tryParse(ord['subtotal']?.toString() ?? '') ?? 0.0,
              'discount': double.tryParse(ord['discount']?.toString() ?? '') ?? 0.0,
              'delivery_charge': double.tryParse(ord['deliveryCharge']?.toString() ?? '') ?? 0.0,
              'smart_rounded_amount': 0.0,
              'grand_total': grandTotal,
              'paid_amount': isPaid ? grandTotal : 0.0,
              'remaining_amount': isPaid ? 0.0 : grandTotal,
              'delivery_status': serverStatus.toLowerCase(),
              'notes': ord['customerNote'] ?? '',
              'savings': 0.0,
              'created_at': ord['createdAt'] ?? nowStr,
              'updated_at': ord['updatedAt'] ?? nowStr,
            });

            // Write order items & deduct inventory stock
            final List<dynamic> items = ord['items'] ?? [];
            for (var item in items) {
              final String itemId = item['productId'] ?? item['item_id'] ?? '';
              final String itemName = item['productNameSnapshot'] ?? item['item_name'] ?? 'Item';
              final double qty = double.tryParse(item['quantity']?.toString() ?? '') ?? 1.0;
              final double unitPrice = double.tryParse(item['unitPriceSnapshot']?.toString() ?? item['unit_price']?.toString() ?? '') ?? 0.0;
              final double subtotal = double.tryParse(item['subtotal']?.toString() ?? item['total_price']?.toString() ?? '') ?? (qty * unitPrice);

              await txn.insert('order_items', {
                'id': _uuid.v4(),
                'order_id': orderId,
                'item_id': itemId,
                'item_name': itemName,
                'item_unit': item['unit'] ?? 'kg',
                'quantity': qty,
                'unit_price': unitPrice,
                'total_price': subtotal,
              });

              // Deduct stock in SQLite items table & record stock history
              if (itemId.isNotEmpty) {
                await txn.rawUpdate(
                  'UPDATE items SET stock = stock - ?, updated_at = ? WHERE id = ?',
                  [qty, nowStr, itemId],
                );
                await txn.insert('stock_history', {
                  'id': _uuid.v4(),
                  'item_id': itemId,
                  'item_name': itemName,
                  'change_amount': -qty,
                  'reason': 'Online App Order #$orderId',
                  'order_id': orderId,
                  'created_at': nowStr,
                });
              }
            }
          } else {
            // C. Order exists locally - check for status sync (Local POS -> Backend Server)
            final String localStatus = orderCheck.first['delivery_status'] as String;
            final targetStatus = serverStatus.toLowerCase();

            if (localStatus != targetStatus) {
              if (targetStatus == 'cancelled') {
                // If server status is cancelled, local POS should adopt it
                await txn.update(
                  'orders',
                  {'delivery_status': 'cancelled', 'updated_at': DateTime.now().toIso8601String()},
                  where: 'id = ?',
                  whereArgs: [orderId],
                );
              } else if (localStatus != 'pending') {
                // POS changed status locally! Update it on the remote server
                final mappedStatus = _mapLocalToRemoteStatus(localStatus);
                await _pushOrderStatusToServer(orderId, mappedStatus);
              }
            }
          }
            });
          } catch (e) {
            if (kDebugMode) print('CustomerOrderSyncService order $ord error: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('CustomerOrderSyncService sync error: $e');
    }
  }

  String _mapLocalToRemoteStatus(String localStatus) {
    switch (localStatus.toLowerCase()) {
      case 'pending':
        return 'PENDING';
      case 'accepted':
        return 'ACCEPTED';
      case 'preparing':
        return 'PREPARING';
      case 'ready':
        return 'READY';
      case 'out_for_delivery':
      case 'outfordelivery':
        return 'OUT_FOR_DELIVERY';
      case 'delivered':
        return 'DELIVERED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return 'PENDING';
    }
  }

  Future<void> _pushOrderStatusToServer(String orderId, String status) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/orders/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'orderId': orderId,
          'status': status,
        }),
      );
    } catch (e) {
      if (kDebugMode) print('Failed to push status to server: $e');
    }
  }
}
