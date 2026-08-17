import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/dashboard/presentation/dashboard_screen.dart';
import 'package:orderkart/features/order/data/order_dao.dart';
import 'package:orderkart/features/order/data/order_repository_impl.dart';
import 'package:orderkart/features/order/domain/order.dart';
import 'package:orderkart/features/order/domain/order_item.dart';
import 'package:orderkart/features/order/domain/payment.dart';
import 'package:orderkart/features/customer/data/customer_dao.dart';
import 'package:orderkart/features/inventory/data/item_dao.dart';
import 'package:orderkart/features/order/presentation/order_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('OrderKart Dashboard Forensic Audit & Lifecycle Regression Tests', () {
    final orderDao = OrderDao();
    final customerDao = CustomerDao();
    final itemDao = ItemDao();
    final orderRepo = OrderRepositoryImpl(orderDao, customerDao, itemDao);

    setUp(() async {
      SharedPreferences.setMockInitialValues({'app_mode': 'owner'});
      final db = await DatabaseHelper.instance.database;
      await db.delete('order_question_answers');
      await db.delete('order_items');
      await db.delete('payments');
      await db.delete('orders');
      await db.delete('expenses');
      await db.delete('items');
      await db.delete('item_price_history');
      await db.delete('customers');
      await db.delete('locations');
      await db.delete('streets');
      await db.delete('areas');

      final now = DateTime.now();

      // Seed Area & Street & Location
      await db.insert('areas', {
        'id': 'area-f1',
        'name': 'Market Area',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('streets', {
        'id': 'street-f1',
        'area_id': 'area-f1',
        'name': 'Main Street',
        'created_at': now.toIso8601String(),
      });

      await db.insert('locations', {
        'id': 'area-f1',
        'name': 'Market Area',
        'location_kind': 'area',
        'sequence_key': 'a',
        'depth': 0,
        'materialized_path': '/area-f1/',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('locations', {
        'id': 'street-f1',
        'parent_location_id': 'area-f1',
        'name': 'Main Street',
        'location_kind': 'road',
        'sequence_key': 'b',
        'depth': 1,
        'materialized_path': '/area-f1/street-f1/',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Seed Customers
      await db.insert('customers', {
        'id': 'cust-1',
        'street_id': 'street-f1',
        'location_id': 'street-f1',
        'name': 'Rahul Sharma',
        'phone1': '9876543210',
        'outstanding_balance': 0.0,
        'is_vip': 1,
        'is_archived': 0,
        'customer_since': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('customers', {
        'id': 'cust-2',
        'street_id': 'street-f1',
        'location_id': 'street-f1',
        'name': 'Pooja Verma',
        'phone1': '9876543211',
        'outstanding_balance': 150.0,
        'is_vip': 0,
        'is_archived': 0,
        'customer_since': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Seed Item with initial stock = 100
      await db.insert('items', {
        'id': 'item-rice',
        'name': 'Basmati Rice',
        'category': 'Groceries',
        'unit': 'kg',
        'cost_price': 60.0,
        'selling_price': 100.0,
        'stock': 100.0,
        'min_stock': 10.0,
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('items', {
        'id': 'item-sugar',
        'name': 'Organic Sugar',
        'category': 'Groceries',
        'unit': 'kg',
        'cost_price': 30.0,
        'selling_price': 45.0,
        'stock': 5.0, // Low stock: 5 <= min_stock (10)
        'min_stock': 10.0,
        'is_archived': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    });

    test('1. Default Filter "Today" strictly filters Today\'s orders and excludes Yesterday/Older', () async {
      final now = DateTime.now();
      final todayMorning = DateTime(now.year, now.month, now.day, 8, 30, 0);
      final yesterday = now.subtract(const Duration(days: 1));
      final threeDaysAgo = now.subtract(const Duration(days: 3));

      // 1. Order created today
      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-TODAY',
          customerId: 'cust-1',
          subtotal: 200.0,
          discount: 0.0,
          deliveryCharge: 20.0,
          grandTotal: 220.0,
          paidAmount: 220.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: todayMorning,
          updatedAt: todayMorning,
        ),
        [
          OrderItem(
            id: 'oi-1',
            orderId: 'ORD-TODAY',
            itemId: 'item-rice',
            itemName: 'Basmati Rice',
            itemUnit: 'kg',
            quantity: 2.0,
            unitPrice: 100.0,
            totalPrice: 200.0,
          ),
        ],
      );

      // 2. Order created yesterday
      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-YESTERDAY',
          customerId: 'cust-2',
          subtotal: 100.0,
          discount: 0.0,
          deliveryCharge: 0.0,
          grandTotal: 100.0,
          paidAmount: 0.0,
          remainingAmount: 100.0,
          deliveryStatus: 'pending',
          createdAt: yesterday,
          updatedAt: yesterday,
        ),
        [
          OrderItem(
            id: 'oi-2',
            orderId: 'ORD-YESTERDAY',
            itemId: 'item-rice',
            itemName: 'Basmati Rice',
            itemUnit: 'kg',
            quantity: 1.0,
            unitPrice: 100.0,
            totalPrice: 100.0,
          ),
        ],
      );

      // 3. Order created 3 days ago
      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-PAST',
          customerId: 'cust-1',
          subtotal: 300.0,
          discount: 0.0,
          deliveryCharge: 0.0,
          grandTotal: 300.0,
          paidAmount: 300.0,
          remainingAmount: 0.0,
          deliveryStatus: 'delivered',
          createdAt: threeDaysAgo,
          updatedAt: threeDaysAgo,
        ),
        [
          OrderItem(
            id: 'oi-3',
            orderId: 'ORD-PAST',
            itemId: 'item-rice',
            itemName: 'Basmati Rice',
            itemUnit: 'kg',
            quantity: 3.0,
            unitPrice: 100.0,
            totalPrice: 300.0,
          ),
        ],
      );

      // Verify "today" filter
      final todayOrders = await orderDao.getAllOrders(filter: 'today');
      expect(todayOrders.length, equals(1));
      expect(todayOrders.first.id, equals('ORD-TODAY'));

      // Verify "yesterday" filter
      final yesterdayOrders = await orderDao.getAllOrders(filter: 'yesterday');
      expect(yesterdayOrders.length, equals(1));
      expect(yesterdayOrders.first.id, equals('ORD-YESTERDAY'));

      // Verify "all" filter
      final allOrders = await orderDao.getAllOrders(filter: 'all');
      expect(allOrders.length, equals(3));

      // Verify "week" filter
      final weekOrders = await orderDao.getAllOrders(filter: 'week');
      expect(weekOrders.length, equals(3));

      // Verify "custom" date range
      final customOrders = await orderDao.getAllOrders(
        startDate: yesterday,
        endDate: yesterday,
      );
      expect(customOrders.length, equals(1));
      expect(customOrders.first.id, equals('ORD-YESTERDAY'));
    });

    test('2. Date Boundary Testing: 00:00:00.000 to 23:59:59.999', () async {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      final yesterdayEnd = DateTime(now.year, now.month, now.day - 1, 23, 59, 59, 999);
      final tomorrowStart = DateTime(now.year, now.month, now.day + 1, 0, 0, 0, 1);

      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-START',
          customerId: 'cust-1',
          subtotal: 100.0,
          grandTotal: 100.0,
          paidAmount: 0.0,
          remainingAmount: 100.0,
          createdAt: todayStart,
          updatedAt: todayStart,
        ),
        [],
      );

      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-END',
          customerId: 'cust-1',
          subtotal: 100.0,
          grandTotal: 100.0,
          paidAmount: 0.0,
          remainingAmount: 100.0,
          createdAt: todayEnd,
          updatedAt: todayEnd,
        ),
        [],
      );

      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-YEST-BOUNDARY',
          customerId: 'cust-1',
          subtotal: 100.0,
          grandTotal: 100.0,
          paidAmount: 0.0,
          remainingAmount: 100.0,
          createdAt: yesterdayEnd,
          updatedAt: yesterdayEnd,
        ),
        [],
      );

      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-TOMORROW-BOUNDARY',
          customerId: 'cust-1',
          subtotal: 100.0,
          grandTotal: 100.0,
          paidAmount: 0.0,
          remainingAmount: 100.0,
          createdAt: tomorrowStart,
          updatedAt: tomorrowStart,
        ),
        [],
      );

      final todayOrders = await orderDao.getAllOrders(filter: 'today');
      final todayIds = todayOrders.map((o) => o.id).toSet();

      expect(todayIds.contains('ORD-START'), isTrue);
      expect(todayIds.contains('ORD-END'), isTrue);
      expect(todayIds.contains('ORD-YEST-BOUNDARY'), isFalse);
      expect(todayIds.contains('ORD-TOMORROW-BOUNDARY'), isFalse);
    });

    test('3. Mandatory Lifecycle & Stock Integrity: 100 -> 95 -> 92 -> 97 -> 100', () async {
      // Baseline stock
      final itemInitial = await itemDao.getItemById('item-rice');
      expect(itemInitial!.stock, equals(100.0));

      final now = DateTime.now();

      // Step A: Create order with 5 units (100 - 5 = 95)
      final order1 = AppOrder(
        id: 'ORD-STOCK-TEST',
        customerId: 'cust-1',
        subtotal: 500.0,
        grandTotal: 500.0,
        paidAmount: 500.0,
        remainingAmount: 0.0,
        createdAt: now,
        updatedAt: now,
      );

      final itemsA = [
        OrderItem(
          id: 'oi-stock-1',
          orderId: 'ORD-STOCK-TEST',
          itemId: 'item-rice',
          itemName: 'Basmati Rice',
          itemUnit: 'kg',
          quantity: 5.0,
          unitPrice: 100.0,
          totalPrice: 500.0,
        ),
      ];

      await orderRepo.createOrder(order1, itemsA);

      final stockAfterCreate = (await itemDao.getItemById('item-rice'))!.stock;
      expect(stockAfterCreate, equals(95.0)); // 100 - 5 = 95

      // Step B: Edit order to 8 units (100 - 8 = 92)
      final itemsB = [
        OrderItem(
          id: 'oi-stock-1',
          orderId: 'ORD-STOCK-TEST',
          itemId: 'item-rice',
          itemName: 'Basmati Rice',
          itemUnit: 'kg',
          quantity: 8.0,
          unitPrice: 100.0,
          totalPrice: 800.0,
        ),
      ];

      await orderRepo.createOrder(
        order1.copyWith(subtotal: 800.0, grandTotal: 800.0, paidAmount: 800.0),
        itemsB,
      );

      final stockAfterEdit1 = (await itemDao.getItemById('item-rice'))!.stock;
      expect(stockAfterEdit1, equals(92.0)); // 100 - 8 = 92

      // Step C: Edit order to 3 units (100 - 3 = 97)
      final itemsC = [
        OrderItem(
          id: 'oi-stock-1',
          orderId: 'ORD-STOCK-TEST',
          itemId: 'item-rice',
          itemName: 'Basmati Rice',
          itemUnit: 'kg',
          quantity: 3.0,
          unitPrice: 100.0,
          totalPrice: 300.0,
        ),
      ];

      await orderRepo.createOrder(
        order1.copyWith(subtotal: 300.0, grandTotal: 300.0, paidAmount: 300.0),
        itemsC,
      );

      final stockAfterEdit2 = (await itemDao.getItemById('item-rice'))!.stock;
      expect(stockAfterEdit2, equals(97.0)); // 100 - 3 = 97

      // Step D: Delete order (97 + 3 = 100)
      await orderRepo.deleteOrder('ORD-STOCK-TEST');

      final stockAfterDelete = (await itemDao.getItemById('item-rice'))!.stock;
      expect(stockAfterDelete, equals(100.0)); // Restored back to 100.0
    });

    test('4. Payment & Dues Calculations: Pending dues, partial payments, and settlements', () async {
      final now = DateTime.now();

      // Create order with subtotal 600, discount 50, delivery 30 -> Grand total = 580
      // Paid 200 -> Remaining amount = 380
      final order = AppOrder(
        id: 'ORD-PAY-1',
        customerId: 'cust-1',
        subtotal: 600.0,
        discount: 50.0,
        deliveryCharge: 30.0,
        grandTotal: 580.0,
        paidAmount: 200.0,
        remainingAmount: 380.0,
        deliveryStatus: 'delivered',
        createdAt: now,
        updatedAt: now,
      );

      await orderRepo.createOrder(order, [
        OrderItem(
          id: 'oi-pay-1',
          orderId: 'ORD-PAY-1',
          itemId: 'item-rice',
          itemName: 'Basmati Rice',
          itemUnit: 'kg',
          quantity: 6.0,
          unitPrice: 100.0,
          totalPrice: 600.0,
        ),
      ]);

      // Record partial payment
      await orderRepo.addPayment(Payment(
        id: 'pay-1',
        orderId: 'ORD-PAY-1',
        customerId: 'cust-1',
        amount: 200.0,
        method: 'cash',
        createdAt: now,
      ));

      await customerDao.recalcCustomerTotals('cust-1');

      final summary = await orderDao.getAnalyticsSummary();
      expect(summary['today_sales'], equals(580.0));
      expect(summary['pending_payments'], equals(380.0));
      expect(summary['cash_received'], equals(200.0));
      expect(summary['delivered_count'], equals(1));

      // Check customer outstanding balance
      final cust = await customerDao.getCustomerById('cust-1');
      expect(cust!.outstandingBalance, equals(380.0));
    });

    test('5. Cancelled Orders Exclusion: Does not inflate sales, order count, or profit', () async {
      final now = DateTime.now();

      await orderRepo.createOrder(
        AppOrder(
          id: 'ORD-CANCELLED',
          customerId: 'cust-1',
          subtotal: 1000.0,
          grandTotal: 1000.0,
          paidAmount: 0.0,
          remainingAmount: 1000.0,
          deliveryStatus: 'cancelled',
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: 'oi-c-1',
            orderId: 'ORD-CANCELLED',
            itemId: 'item-rice',
            itemName: 'Basmati Rice',
            itemUnit: 'kg',
            quantity: 10.0,
            unitPrice: 100.0,
            totalPrice: 1000.0,
          ),
        ],
      );

      final summary = await orderDao.getAnalyticsSummary();
      expect(summary['today_sales'], equals(0.0));
      expect(summary['today_orders_count'], equals(0));
      expect(summary['cancelled_count'], equals(1));
    });

    test('6. Dashboard Real-Time Live Statistics: Customer Count, VIP, Low Stock', () async {
      final summary = await orderDao.getAnalyticsSummary();
      expect(summary['customer_count'], equals(2));
      expect(summary['vip_count'], equals(1));

      final lowStockItems = await itemDao.getLowStockItems();
      expect(lowStockItems.length, equals(1));
      expect(lowStockItems.first.name, equals('Organic Sugar'));
    });

    test('7. Duplicate Save Protection: Rapid repeated order saving does not create duplicate rows', () async {
      final now = DateTime.now();
      const orderId = 'ORD-DUP-CHECK';

      final order = AppOrder(
        id: orderId,
        customerId: 'cust-1',
        subtotal: 200.0,
        grandTotal: 200.0,
        paidAmount: 200.0,
        remainingAmount: 0.0,
        createdAt: now,
        updatedAt: now,
      );

      final items = [
        OrderItem(
          id: 'oi-dup-1',
          orderId: orderId,
          itemId: 'item-rice',
          itemName: 'Basmati Rice',
          itemUnit: 'kg',
          quantity: 2.0,
          unitPrice: 100.0,
          totalPrice: 200.0,
        ),
      ];

      // Save order once
      await orderRepo.createOrder(order, items);

      // Save order again (e.g. repeated tap/network bounce)
      await orderRepo.createOrder(order, items);

      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(rows.length, equals(1)); // Exactly ONE order row created

      final itemRows = await db.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      expect(itemRows.length, equals(1)); // Exactly ONE item row

      final stock = (await itemDao.getItemById('item-rice'))!.stock;
      expect(stock, equals(98.0)); // Exactly 2 deducted, no double-deduction!
    });

    testWidgets('8. Dashboard UI Widget Test: Mounts cleanly and selects Today filter chip', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            analyticsSummaryProvider.overrideWith((ref) async => {
                  'today_sales': 0.0,
                  'today_orders_count': 0,
                  'monthly_sales': 0.0,
                  'pending_payments': 0.0,
                  'cash_received': 0.0,
                  'online_received': 0.0,
                  'total_expenses': 0.0,
                  'customer_count': 0,
                  'order_count': 0,
                  'item_count': 0,
                  'top_items': <Map<String, dynamic>>[],
                  'low_stock': <Map<String, dynamic>>[],
                  'delivered_count': 0,
                  'pending_count': 0,
                  'cancelled_count': 0,
                  'all_time_sales': 0.0,
                  'delivery_fees': 0.0,
                  'vip_count': 0,
                  'today_expenses': 0.0,
                  'today_profit': 0.0,
                }),
            dashboardOrdersProvider.overrideWith((ref, params) async => <AppOrder>[]),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DashboardScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify ChoiceChip with 'Today' is selected by default
      final todayChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Today'),
      );
      expect(todayChip.selected, isTrue);

      // Verify ChoiceChip with 'All' is not selected by default
      final allChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'All'),
      );
      expect(allChip.selected, isFalse);

      // Verify ChoiceChip with 'Yesterday' is not selected by default
      final yestChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Yesterday'),
      );
      expect(yestChip.selected, isFalse);

      // Advance past sqflite internal watchdog timers
      await tester.pump(const Duration(seconds: 15));
    });
  });
}
