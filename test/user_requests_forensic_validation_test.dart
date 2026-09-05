import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/core/utils/formatters.dart';
import 'package:orderkart/core/utils/bill_text_generator.dart';
import 'package:orderkart/features/order/data/order_dao.dart';
import 'package:orderkart/features/order/data/order_repository_impl.dart';
import 'package:orderkart/features/order/domain/order.dart';
import 'package:orderkart/features/order/domain/order_item.dart';
import 'package:orderkart/features/customer/data/customer_dao.dart';
import 'package:orderkart/features/customer/domain/customer.dart';
import 'package:orderkart/features/inventory/data/item_dao.dart';
import 'package:orderkart/features/inventory/domain/item.dart';
import 'package:orderkart/features/analytics/data/analytics_dao.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('User Mandates & Defect Fixes Validation Suite', () {
    final orderDao = OrderDao();
    final customerDao = CustomerDao();
    final itemDao = ItemDao();
    final analyticsDao = AnalyticsDao();
    final orderRepo = OrderRepositoryImpl(orderDao, customerDao, itemDao);

    setUp(() async {
      SharedPreferences.setMockInitialValues({'app_mode': 'owner'});
      final db = await DatabaseHelper.instance.database;
      await db.delete('order_question_answers');
      await db.delete('order_items');
      await db.delete('payments');
      await db.delete('orders');
      await db.delete('stock_history');
      await db.delete('expenses');
      await db.delete('items');
      await db.delete('customers');
      await db.delete('locations');
      await db.delete('streets');
      await db.delete('areas');

      final nowStr = DateTime.now().toIso8601String();
      await db.insert('locations', {
        'id': 'area-1',
        'name': 'Main Area',
        'location_kind': 'area',
        'sequence_key': '001',
        'depth': 0,
        'materialized_path': '/area-1/',
        'is_archived': 0,
        'created_at': nowStr,
        'updated_at': nowStr,
      });
      await db.insert('locations', {
        'id': 'street-1',
        'parent_location_id': 'area-1',
        'name': 'Main Street',
        'location_kind': 'road',
        'sequence_key': '001000',
        'depth': 1,
        'materialized_path': '/area-1/street-1/',
        'is_archived': 0,
        'created_at': nowStr,
        'updated_at': nowStr,
      });
      await db.insert('areas', {
        'id': 'area-1',
        'name': 'Main Area',
        'created_at': nowStr,
        'updated_at': nowStr,
      });
      await db.insert('streets', {
        'id': 'street-1',
        'area_id': 'area-1',
        'name': 'Main Street',
        'created_at': nowStr,
      });
    });

    test('1. Smart Weight & Quantity Formatter: 1 kg, 3 kg vs 250 g, 500 g, 670 g', () {
      // Whole kg
      expect(AppFormatters.quantity(1.0, unit: 'kg'), '1 kg');
      expect(AppFormatters.quantity(3.0, unit: 'kg'), '3 kg');
      expect(AppFormatters.quantity(5.0, unit: 'kilo'), '5 kg');

      // Fractional kg (Must be formatted in grams)
      expect(AppFormatters.quantity(0.25, unit: 'kg'), '250 g');
      expect(AppFormatters.quantity(0.5, unit: 'kg'), '500 g');
      expect(AppFormatters.quantity(0.67, unit: 'kg'), '670 g');
      expect(AppFormatters.quantity(0.1, unit: 'kg'), '100 g');
      expect(AppFormatters.quantity(0.75, unit: 'kg'), '750 g');

      // Whole kg with fraction
      expect(AppFormatters.quantity(1.5, unit: 'kg'), '1 kg 500 g');
      expect(AppFormatters.quantity(2.25, unit: 'kg'), '2 kg 250 g');

      // Explicit gram unit
      expect(AppFormatters.quantity(250, unit: 'g'), '250 g');
      expect(AppFormatters.quantity(500, unit: 'gm'), '500 g');
      expect(AppFormatters.quantity(670, unit: 'grams'), '670 g');
      expect(AppFormatters.quantity(1000, unit: 'g'), '1 kg');
      expect(AppFormatters.quantity(2500, unit: 'g'), '2 kg 500 g');

      // Other non-weight units
      expect(AppFormatters.quantity(1.0, unit: 'dozen'), '1 dozen');
      expect(AppFormatters.quantity(6.0, unit: 'piece'), '6 piece');
      expect(AppFormatters.quantity(2.0, unit: 'pkt'), '2 pkt');
    });

    test('2. Simplified WhatsApp Bill Layout with formatted quantities', () {
      final items = [
        {
          'item_name': 'Fresh Tomato (टोमॅटो)',
          'quantity': 0.5,
          'item_unit': 'kg',
          'unit_price': 40.0,
          'total_price': 20.0,
        },
        {
          'item_name': 'Potato (बटाटा)',
          'quantity': 1.0,
          'item_unit': 'kg',
          'unit_price': 30.0,
          'total_price': 30.0,
        },
        {
          'item_name': 'Onion (कांदा)',
          'quantity': 0.25,
          'item_unit': 'kg',
          'unit_price': 40.0,
          'total_price': 10.0,
        },
      ];

      final bill = BillTextGenerator.generate(
        businessName: 'OrderKart SuperMart',
        customerName: 'Suresh Patil',
        customerAddress: 'Flat 102, Shanti Heights',
        orderNoLabel: '#ORD-0042',
        orderDate: DateTime(2026, 8, 17, 10, 30),
        items: items,
        subtotal: 60.0,
        discount: 0.0,
        deliveryCharge: 0.0,
        grandTotal: 60.0,
        paidAmount: 60.0,
        remainingAmount: 0.0,
        paymentMethod: 'cash',
        ownerPhone: '9876543210',
      );

      // Verify bill contains key simplified elements
      expect(bill.contains('ORDERKART SUPERMART'), isTrue);
      expect(bill.contains('#ORD-0042'), isTrue);
      expect(bill.contains('Suresh Patil'), isTrue);
      expect(bill.contains('500 g x ₹40.00 = *₹20.00*'), isTrue);
      expect(bill.contains('1 kg x ₹30.00 = *₹30.00*'), isTrue);
      expect(bill.contains('250 g x ₹40.00 = *₹10.00*'), isTrue);
      expect(bill.contains('Grand Total:    ₹60.00'), isTrue);
      expect(bill.contains('Fully Paid'), isTrue);
      expect(bill.contains('Thank you for shopping with us!'), isTrue);
    });

    test('3. Settle Overpayment: Foreign Key Safety & Customer Totals Recalculation', () async {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();

      // Create customer
      await customerDao.insertCustomer(Customer(
        id: 'cust-overpaid-1',
        name: 'Amit Joshi',
        phone1: '9898989898',
        address: 'B-14 Ganesh Nagar',
        streetId: 'street-1',
        customerSince: now,
        createdAt: now,
        updatedAt: now,
      ));

      // Create order with total 100
      final orderId = const Uuid().v4();
      await orderDao.insertOrder(AppOrder(
        id: orderId,
        customerId: 'cust-overpaid-1',
        subtotal: 100.0,
        grandTotal: 100.0,
        paidAmount: 150.0, // Customer overpaid 150
        remainingAmount: 0.0,
        createdAt: now,
        updatedAt: now,
      ));

      // Record payment of 150
      await db.insert('payments', {
        'id': 'pay-1',
        'customer_id': 'cust-overpaid-1',
        'order_id': orderId,
        'amount': 150.0,
        'method': 'cash',
        'notes': 'Overpaid order',
        'created_at': now.toIso8601String(),
      });

      await customerDao.recalcCustomerTotals('cust-overpaid-1');
      var customer = await customerDao.getCustomerById('cust-overpaid-1');
      expect(customer, isNotNull);
      expect(customer!.totalPaid, 150.0);
      expect(customer.outstandingBalance, -50.0);
      expect(customer.advanceBalance, 50.0);

      // Now Settle Overpayment:
      // Find the customer's order for foreign key reference
      final customerOrders = await db.query(
        'orders',
        columns: ['id'],
        where: 'customer_id = ?',
        whereArgs: ['cust-overpaid-1'],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      final targetOrderId = customerOrders.first['id'] as String;
      expect(targetOrderId, orderId);

      // Insert settlement refund payment (-50)
      final settlePayId = const Uuid().v4();
      await db.insert('payments', {
        'id': settlePayId,
        'customer_id': 'cust-overpaid-1',
        'order_id': targetOrderId,
        'amount': -50.0,
        'method': 'cash',
        'notes': 'Overpayment refund settlement',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Recalculate
      await customerDao.recalcCustomerTotals('cust-overpaid-1');
      customer = await customerDao.getCustomerById('cust-overpaid-1');
      expect(customer!.totalPaid, 100.0);
      expect(customer.outstandingBalance, 0.0);
      expect(customer.advanceBalance, 0.0);
    });

    test('4. Live Customer Detail Sync: Updating customer details immediately reflects on orders', () async {
      final now = DateTime.now();

      // 1. Create initial customer
      await customerDao.insertCustomer(Customer(
        id: 'cust-sync-1',
        name: 'Ramesh Initial',
        phone1: '9111111111',
        address: 'Old Address 101',
        streetId: 'street-1',
        customerSince: now,
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Create order
      final orderId = const Uuid().v4();
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-sync-1',
          subtotal: 200.0,
          grandTotal: 200.0,
          paidAmount: 200.0,
          remainingAmount: 0.0,
          createdAt: now,
          updatedAt: now,
        ),
        [],
      );

      // 3. Verify order initially has initial customer details via JOIN
      var order = await orderDao.getOrderById(orderId);
      expect(order, isNotNull);
      expect(order!.customerName, 'Ramesh Initial');
      expect(order.customerPhone, '9111111111');
      expect(order.customerAddress, 'Old Address 101');

      // 4. Update customer details (e.g. phone number and address changed)
      await customerDao.updateCustomer(Customer(
        id: 'cust-sync-1',
        name: 'Ramesh Updated',
        phone1: '9999988888',
        address: 'New Villa 202, Green Avenue',
        streetId: 'street-1',
        customerSince: now,
        createdAt: now,
        updatedAt: DateTime.now(),
      ));

      // 5. Query order again: order dynamically displays the updated customer details!
      order = await orderDao.getOrderById(orderId);
      expect(order!.customerName, 'Ramesh Updated');
      expect(order.customerPhone, '9999988888');
      expect(order.customerAddress, 'New Villa 202, Green Avenue');
    });

    test('5. Dashboard vs Analytics Revenue, Profit & Loss Consistency', () async {
      final now = DateTime.now();

      // Create item
      await itemDao.insertItem(
        Item(
          id: 'item-tomato',
          name: 'Fresh Tomato',
          category: 'Vegetables',
          sellingPrice: 40.0,
          costPrice: 25.0, // margin = 15
          marketPrice: 50.0,
          unit: 'kg',
          stock: 100.0,
          minStock: 10.0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Create Customer
      await customerDao.insertCustomer(Customer(
        id: 'cust-prof-1',
        name: 'Pooja Desai',
        phone1: '9822012345',
        address: 'Flat 5B',
        streetId: 'street-1',
        customerSince: now,
        createdAt: now,
        updatedAt: now,
      ));

      // Create Order: 2 kg tomato = subtotal 80, discount 5, delivery 10, grandTotal 85
      final orderId = const Uuid().v4();
      await orderRepo.createOrder(
        AppOrder(
          id: orderId,
          customerId: 'cust-prof-1',
          subtotal: 80.0,
          discount: 5.0,
          deliveryCharge: 10.0,
          grandTotal: 85.0,
          paidAmount: 85.0,
          remainingAmount: 0.0,
          createdAt: now,
          updatedAt: now,
        ),
        [
          OrderItem(
            id: const Uuid().v4(),
            orderId: orderId,
            itemId: 'item-tomato',
            itemName: 'Fresh Tomato',
            itemUnit: 'kg',
            unitPrice: 40.0,
            quantity: 2.0,
            totalPrice: 80.0,
          ),
        ],
      );

      // Add operating expense of 15
      final db = await DatabaseHelper.instance.database;
      await db.insert('expenses', {
        'id': 'exp-1',
        'name': 'Transport Fuel',
        'category': 'Transport',
        'amount': 15.0,
        'date': now.toIso8601String(),
        'notes': 'Daily delivery',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Expected Values:
      // Revenue (grand_total) = 85.0
      // COGS (2 kg * 25.0) = 50.0
      // Expenses = 15.0
      // Net Profit = Revenue (85.0) - COGS (50.0) - Expenses (15.0) = 20.0

      // 1. Check Dashboard getAnalyticsSummary
      final dashMetrics = await orderDao.getAnalyticsSummary();
      expect(dashMetrics['today_sales'], 85.0);
      expect(dashMetrics['today_expenses'], 15.0);
      expect(dashMetrics['today_profit'], 20.0);

      // 2. Check Profit Loss Statement
      final pnl = await orderDao.getProfitLossStatement();
      expect(pnl['total_revenue'], 85.0);
      expect(pnl['cogs'], 50.0);
      expect(pnl['total_expenses'], 15.0);
      expect(pnl['net_profit'], 20.0);

      // 3. Check Analytics DateWiseProfitBreakdown
      final dateWise = await analyticsDao.getDateWiseProfitBreakdown(days: 1);
      expect(dateWise.isNotEmpty, isTrue);
      final todayRecord = dateWise.first;
      expect(todayRecord['revenue'], 85.0);
      expect(todayRecord['cogs'], 50.0);
      expect(todayRecord['expenses'], 15.0);
      expect(todayRecord['net_profit'], 20.0);

      // DASHBOARD AND ANALYTICS VALUES MATCH 100%!
      expect(dashMetrics['today_profit'], todayRecord['net_profit']);
      expect(dashMetrics['today_sales'], todayRecord['revenue']);
      expect(dashMetrics['today_expenses'], todayRecord['expenses']);
    });
  });
}
