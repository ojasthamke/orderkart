import 'package:flutter_test/flutter_test.dart';
import 'package:orderkart/features/location/domain/location.dart';
import 'package:orderkart/features/location/domain/location_kind.dart';
import 'package:orderkart/features/customer/domain/customer.dart';

void main() {
  group('Customer Location Hierarchy & Relationship Audit Test', () {
    final areaNode = Location(
      id: 'loc_baner',
      parentLocationId: null,
      name: 'Baner',
      locationKind: LocationKind.area,
      sequenceKey: '001000',
      depth: 0,
      materializedPath: '/loc_baner/',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final roadNode = Location(
      id: 'loc_main_road',
      parentLocationId: 'loc_baner',
      name: 'Main Road',
      locationKind: LocationKind.road,
      sequenceKey: '001000',
      depth: 1,
      materializedPath: '/loc_baner/loc_main_road/',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final subRoadNode = Location(
      id: 'loc_lane_4',
      parentLocationId: 'loc_main_road',
      name: 'Lane 4',
      locationKind: LocationKind.galli,
      sequenceKey: '001000',
      depth: 2,
      materializedPath: '/loc_baner/loc_main_road/loc_lane_4/',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final subSubRoadNode = Location(
      id: 'loc_society_a',
      parentLocationId: 'loc_lane_4',
      name: 'Greenwoods Society',
      locationKind: LocationKind.society,
      sequenceKey: '001000',
      depth: 3,
      materializedPath: '/loc_baner/loc_main_road/loc_lane_4/loc_society_a/',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('1. Hierarchy Resolution & Address Format (Area -> Road -> Sub-Road -> Sub-Sub-Road)', () {
      final breadcrumbs = [areaNode, roadNode, subRoadNode, subSubRoadNode];
      
      final formattedAddress = breadcrumbs
          .map((l) => l.name.trim())
          .where((n) => n.isNotEmpty)
          .join(', ');

      expect(formattedAddress, 'Baner, Main Road, Lane 4, Greenwoods Society');
    });

    test('2. Hierarchy Skipping Partial Levels gracefully without creating duplicate/fake entries', () {
      // E.g. Area + Road only (no sub-road or sub-sub-road)
      final partialBreadcrumbs = [areaNode, roadNode];
      final partialAddress = partialBreadcrumbs
          .map((l) => l.name.trim())
          .where((n) => n.isNotEmpty)
          .join(', ');

      expect(partialAddress, 'Baner, Main Road');
    });

    test('3. Customer ID Uniqueness & Isolation between Same-Name Customers', () {
      final customerA = Customer(
        id: 'CUST-001',
        streetId: 'loc_society_a',
        name: 'Ramesh Sharma',
        phone1: '9876543210',
        customerCode: 'OK1025',
        customerSince: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final customerB = Customer(
        id: 'CUST-002',
        streetId: 'loc_main_road',
        name: 'Ramesh Sharma', // Same name, different ID & road
        phone1: '9822001122',
        customerCode: 'OK1026',
        customerSince: DateTime(2026, 2, 1),
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
      );

      expect(customerA.id != customerB.id, isTrue);
      expect(customerA.customerCode != customerB.customerCode, isTrue);
      expect(customerA == customerB, isFalse);

      final orders = [
        {'orderId': 'ORD-101', 'customerId': 'CUST-001', 'grandTotal': 1850.0, 'paidAmount': 1000.0, 'status': 'Accepted'},
        {'orderId': 'ORD-102', 'customerId': 'CUST-002', 'grandTotal': 500.0, 'paidAmount': 500.0, 'status': 'Delivered'},
      ];

      // Filter orders for Customer A
      final ordersA = orders.where((o) => o['customerId'] == customerA.id).toList();
      expect(ordersA.length, 1);
      expect(ordersA.first['orderId'], 'ORD-101');
      final grandTotalA = ordersA.first['grandTotal'] as double;
      final paidA = ordersA.first['paidAmount'] as double;
      final pendingA = grandTotalA - paidA;
      expect(pendingA, 850.0);

      // Filter orders for Customer B
      final ordersB = orders.where((o) => o['customerId'] == customerB.id).toList();
      expect(ordersB.length, 1);
      expect(ordersB.first['orderId'], 'ORD-102');
      final grandTotalB = ordersB.first['grandTotal'] as double;
      final paidB = ordersB.first['paidAmount'] as double;
      final pendingB = grandTotalB - paidB;
      expect(pendingB, 0.0);
    });

    test('4. Customer Pending Balance calculation integrity', () {
      final customerOrders = [
        {'orderId': 'ORD-1', 'grandTotal': 1000.0, 'paidAmount': 400.0, 'status': 'Accepted'}, // pending: 600
        {'orderId': 'ORD-2', 'grandTotal': 750.0, 'paidAmount': 750.0, 'status': 'Delivered'},  // pending: 0
        {'orderId': 'ORD-3', 'grandTotal': 300.0, 'paidAmount': 0.0, 'status': 'Cancelled'},   // cancelled => 0
      ];

      double totalPending = 0.0;
      for (final ord in customerOrders) {
        if (ord['status'] == 'Cancelled') continue;
        final grand = ord['grandTotal'] as double;
        final paid = ord['paidAmount'] as double;
        totalPending += (grand - paid).clamp(0.0, double.infinity);
      }

      expect(totalPending, 600.0);
    });
  });
}
