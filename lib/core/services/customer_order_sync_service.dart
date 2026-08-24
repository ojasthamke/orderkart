import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../features/customer/data/customer_dao.dart';
import 'notification_service.dart';

class CustomerOrderSyncService {
  CustomerOrderSyncService._();
  static final CustomerOrderSyncService instance = CustomerOrderSyncService._();

  Timer? _syncTimer;

  void startSync() {
    _syncTimer?.cancel();
    // Run sync check every 10 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await syncOrders();
    });
  }

  void stopSync() {
    _syncTimer?.cancel();
  }

  Future<void> syncCustomersToRemote() async {
    try {
      final client = Supabase.instance.client;
      final db = await DatabaseHelper.instance.database;

      // Find all active customers to sync to Supabase
      final List<Map<String, dynamic>> customers = await db.query(
        'customers',
        where: "is_archived IS NULL OR is_archived = 0",
      );

      for (final cust in customers) {
        final rawId = cust['id'] as String;
        final customerId = _getValidUuid(rawId);
        final name = cust['name'] as String? ?? '';
        final phone = cust['phone1'] as String? ?? '';
        final address = cust['address'] as String? ?? '';
        final codeRaw = cust['customer_code'] as String? ?? '';

        try {
          await client.rpc('sync_customer_with_code', params: {
            'p_id': customerId,
            'p_name': name,
            'p_phone': phone,
            'p_email': '',
            'p_address': address,
            'p_customer_code': codeRaw,
          });
          debugPrint('SyncService: Synced customer $rawId -> $customerId ($name) to Supabase.');
        } catch (e) {
          debugPrint('SyncService: Failed to sync customer $rawId ($customerId): $e');
        }
      }
    } catch (e) {
      debugPrint('SyncService: Error in syncCustomersToRemote: $e');
    }
  }

  Future<void> syncOrders() async {
    try {
      // Sync all POS customers to Supabase
      await syncCustomersToRemote();
      
      final client = Supabase.instance.client;
      
      // Fetch remote orders from Supabase (confirmed, delivered, preparing, out for delivery, cancelled)
      // Since the admin accepts them, we fetch all orders where status != 'Pending'
      final List<dynamic> orders = await client
          .from('orders')
          .select('*, customers(name, phone)')
          .neq('status', 'Pending');

      final db = await DatabaseHelper.instance.database;

      for (var ord in orders) {
        try {
          await db.transaction((txn) async {
            final String orderId = ord['id'];
            String customerId = ord['customer_id'] ?? '';
            if (customerId.isEmpty) {
              customerId = 'generic_app_customer';
            }
            
            // Get customer details from nested customers object
            String customerName = 'App Customer';
            String customerPhone = 'Online App User';
            final cust = ord['customers'];
            if (cust is Map<String, dynamic>) {
              customerName = cust['name'] as String? ?? 'App Customer';
              customerPhone = cust['phone'] as String? ?? 'Online App User';
            } else if (ord['customer_phone'] != null) {
              customerPhone = ord['customer_phone'] as String;
            }

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
                  } else {
                    // Force insert default_area and default_street to satisfy SQLite FOREIGN KEY check
                    final areaCheck = await txn.query('areas', where: 'id = ?', whereArgs: ['default_area']);
                    if (areaCheck.isEmpty) {
                      await txn.insert('areas', {
                        'id': 'default_area',
                        'name': 'Online Area',
                        'description': 'Default area for online customers',
                        'color': 0,
                        'created_at': DateTime.now().toIso8601String(),
                        'updated_at': DateTime.now().toIso8601String(),
                      });
                    }
                    final defaultStreetCheck = await txn.query('streets', where: 'id = ?', whereArgs: ['default_street']);
                    if (defaultStreetCheck.isEmpty) {
                      await txn.insert('streets', {
                        'id': 'default_street',
                        'area_id': 'default_area',
                        'name': 'Online Street',
                        'description': 'Default street for online customers',
                        'created_at': DateTime.now().toIso8601String(),
                      });
                    }
                    streetId = 'default_street';
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
                  'address': ord['delivery_address'] ?? '',
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
            final String serverStatus = ord['status'] ?? 'Confirmed';

            if (orderCheck.isEmpty) {
              // Write new order
              final double grandTotal = (ord['total_amount'] as num?)?.toDouble() ?? 0.0;
              final nowStr = DateTime.now().toIso8601String();
              
              await txn.insert('orders', {
                'id': orderId,
                'customer_id': customerId.isNotEmpty ? customerId : 'generic_app_customer',
                'subtotal': grandTotal,
                'discount': 0.0,
                'delivery_charge': 0.0,
                'smart_rounded_amount': 0.0,
                'grand_total': grandTotal,
                'paid_amount': 0.0,
                'remaining_amount': grandTotal,
                'delivery_status': serverStatus.toLowerCase(),
                'notes': ord['notes'] ?? '',
                'savings': 0.0,
                'created_at': ord['order_date'] ?? nowStr,
                'updated_at': ord['order_date'] ?? nowStr,
              });

              // Fetch order items from Supabase
              final List<dynamic> items = await client
                  .from('order_items')
                  .select()
                  .eq('order_id', orderId);

              for (var item in items) {
                final String itemId = item['product_id'] ?? '';
                final String itemName = item['product_name'] ?? 'Item';
                final double qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
                final double unitPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
                final double subtotal = (item['total_price'] as num?)?.toDouble() ?? (qty * unitPrice);

                await txn.insert('order_items', {
                  'id': const Uuid().v4(),
                  'order_id': orderId,
                  'item_id': itemId,
                  'item_name': itemName,
                  'item_unit': item['unit'] ?? 'kg',
                  'quantity': qty,
                  'unit_price': unitPrice,
                  'total_price': subtotal,
                });

                // Deduct stock in SQLite items table & record stock history (only for active, non-cancelled/non-denied orders)
                if (itemId.isNotEmpty &&
                    serverStatus.toLowerCase() != 'cancelled' &&
                    serverStatus.toLowerCase() != 'denied') {
                  await txn.rawUpdate(
                    'UPDATE items SET stock = stock - ?, updated_at = ? WHERE id = ?',
                    [qty, nowStr, itemId],
                  );
                  await txn.insert('stock_history', {
                    'id': const Uuid().v4(),
                    'item_id': itemId,
                    'item_name': itemName,
                    'change_amount': -qty,
                    'reason': 'Online App Order #$orderId',
                    'order_id': orderId,
                    'created_at': nowStr,
                  });
                }
              }

              // Recalculate customer totals
              if (customerId.isNotEmpty) {
                await CustomerDao().recalcCustomerTotals(customerId, executor: txn);
              }
              
              // Trigger local notification for the new order!
              try {
                await NotificationService.instance.showNotification(
                  id: orderId.hashCode,
                  title: 'New Online Order Received!',
                  body: 'Order #$orderId from $customerName ($customerPhone) for ₹${grandTotal.toStringAsFixed(2)}',
                  payload: 'order_$orderId',
                );
              } catch (e) {
                debugPrint('Failed to show local notification: $e');
              }
            } else {
              // C. Order exists locally - check for status sync (Remote Supabase -> Local POS)
              final String localStatus = orderCheck.first['delivery_status'] as String;
              final targetStatus = serverStatus.toLowerCase();

              if (localStatus != targetStatus) {
                 if (targetStatus == 'cancelled' || targetStatus == 'denied') {
                  // Revert stock for all items of this order in SQLite items table
                  final localItems = await txn.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
                  for (var localItem in localItems) {
                    final String itemId = localItem['item_id'] as String? ?? '';
                    final double qty = (localItem['quantity'] as num?)?.toDouble() ?? 0.0;
                    final String itemName = localItem['item_name'] as String? ?? 'Item';
                    
                    if (itemId.isNotEmpty) {
                      await txn.rawUpdate(
                        'UPDATE items SET stock = stock + ?, updated_at = ? WHERE id = ?',
                        [qty, DateTime.now().toIso8601String(), itemId],
                      );
                      await txn.insert('stock_history', {
                        'id': const Uuid().v4(),
                        'item_id': itemId,
                        'item_name': itemName,
                        'change_amount': qty,
                        'reason': 'Online Order ${targetStatus == 'cancelled' ? 'Cancelled' : 'Denied'} #$orderId',
                        'order_id': orderId,
                        'created_at': DateTime.now().toIso8601String(),
                      });
                    }
                  }
                  
                  await txn.update(
                    'orders',
                    {'delivery_status': targetStatus, 'updated_at': DateTime.now().toIso8601String()},
                    where: 'id = ?',
                    whereArgs: [orderId],
                  );
                } else {
                  // Update local status to remote status
                  await txn.update(
                    'orders',
                    {'delivery_status': targetStatus, 'updated_at': DateTime.now().toIso8601String()},
                    where: 'id = ?',
                    whereArgs: [orderId],
                  );
                }
                
                // Recalculate customer totals
                if (customerId.isNotEmpty) {
                  await CustomerDao().recalcCustomerTotals(customerId, executor: txn);
                }
              }
            }
          });
        } catch (e) {
          debugPrint('CustomerOrderSyncService order $ord error: $e');
        }
      }

      // D. Clean up deleted orders: Disabled to support permanent local offline order retention history.
      // Missing remote orders are no longer synchronized as deletions.

    } catch (e) {
      debugPrint('CustomerOrderSyncService sync error: $e');
    }
  }

  String _getValidUuid(String rawId) {
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(rawId)) {
      return rawId;
    }
    return const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.customer.$rawId');
  }
}
