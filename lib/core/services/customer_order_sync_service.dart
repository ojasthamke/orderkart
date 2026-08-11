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
          final String orderId = ord['id'];
          final String customerId = ord['customerId'];

          // A. Ensure customer exists in POS SQLite DB to prevent FK violation
          final custCheck = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
          if (custCheck.isEmpty) {
            await db.insert('customers', {
              'id': customerId,
              'name': 'App Customer (${ord['id']})',
              'phone': 'App-User',
              'outstanding_balance': 0.0,
              'total_orders': 0,
              'total_paid': 0.0,
              'total_pending': 0.0,
              'created_at': DateTime.now().toIso8601String(),
            });
          }

          // B. Check if order already exists in POS SQLite DB
          final orderCheck = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
          final String serverStatus = ord['status'];

          if (orderCheck.isEmpty) {
            // Write new order
            final double grandTotal = double.tryParse(ord['grandTotal'].toString()) ?? 0.0;
            final bool isPaid = ord['paymentStatus'] == 'Paid' || ord['paymentStatus'] == 'CAPTURED';

            await db.insert('orders', {
              'id': orderId,
              'customer_id': customerId,
              'subtotal': double.tryParse(ord['subtotal'].toString()) ?? 0.0,
              'discount': double.tryParse(ord['discount'].toString()) ?? 0.0,
              'delivery_charge': double.tryParse(ord['deliveryCharge'].toString()) ?? 0.0,
              'smart_rounded_amount': 0.0,
              'grand_total': grandTotal,
              'paid_amount': isPaid ? grandTotal : 0.0,
              'remaining_amount': isPaid ? 0.0 : grandTotal,
              'delivery_status': serverStatus.toLowerCase(),
              'notes': ord['customerNote'] ?? '',
              'savings': 0.0,
              'created_at': ord['createdAt'],
              'updated_at': ord['updatedAt'],
            });

            // Write order items
            final List<dynamic> items = ord['items'] ?? [];
            for (var item in items) {
              await db.insert('order_items', {
                'id': _uuid.v4(),
                'order_id': orderId,
                'item_id': item['productId'] ?? '',
                'item_name': item['productNameSnapshot'] ?? 'Item',
                'item_unit': item['unit'] ?? 'kg',
                'quantity': double.tryParse(item['quantity'].toString()) ?? 1.0,
                'unit_price': double.tryParse(item['unitPriceSnapshot'].toString()) ?? 0.0,
                'total_price': double.tryParse(item['subtotal'].toString()) ?? 0.0,
              });
            }
          } else {
            // C. Order exists locally - check for status sync (Local POS -> Backend Server)
            final String localStatus = orderCheck.first['delivery_status'] as String;
            final targetStatus = serverStatus.toLowerCase();

            if (localStatus != targetStatus) {
              // POS changed status locally! Update it on the remote server
              final mappedStatus = _mapLocalToRemoteStatus(localStatus);
              await _pushOrderStatusToServer(orderId, mappedStatus);
            }
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
