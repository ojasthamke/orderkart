import 'package:flutter_test/flutter_test.dart';
import 'package:orderkart/features/customer/domain/customer.dart';

void main() {
  final now = DateTime.now();

  group('OrderKart New Customers Segment and Badge Tests', () {
    test('TEST 1: Customer registered via Google is recognized as Google customer', () {
      final customer = Customer(
        id: 'cust-g1',
        streetId: 'street-1',
        name: 'Google Customer',
        phone1: '9876543210',
        address: '101 Rose Villa',
        customerSince: now,
        createdAt: now,
        updatedAt: now,
        authProvider: 'google',
        isNewCustomer: true,
      );

      expect(customer.isGoogleCustomer, isTrue);
      expect(customer.isBrandNewCustomer, isTrue);
    });

    test('TEST 2: Standard phone/password customer is NOT marked as Google customer', () {
      final customer = Customer(
        id: 'cust-p1',
        streetId: 'street-2',
        name: 'Standard Customer',
        phone1: '9822012345',
        address: '202 Oak Street',
        customerSince: now,
        createdAt: now,
        updatedAt: now,
        authProvider: 'phone_password',
        isNewCustomer: false,
      );

      expect(customer.isGoogleCustomer, isFalse);
      expect(customer.isBrandNewCustomer, isFalse);
    });

    test('TEST 3: New Customers list filter accurately isolates new customers', () {
      final customerList = [
        Customer(
          id: 'c1',
          streetId: 'street-1',
          name: 'Old Customer 1',
          phone1: '9822012345',
          customerSince: now,
          createdAt: now,
          updatedAt: now,
          authProvider: 'phone_password',
          isNewCustomer: false,
        ),
        Customer(
          id: 'c2',
          streetId: 'street-1',
          name: 'Google New Customer',
          phone1: '9876543210',
          customerSince: now,
          createdAt: now,
          updatedAt: now,
          authProvider: 'google',
          isNewCustomer: true,
        ),
        Customer(
          id: 'c3',
          streetId: 'street-1',
          name: 'Old Customer 2',
          phone1: '9822099999',
          customerSince: now,
          createdAt: now,
          updatedAt: now,
          authProvider: 'phone_password',
          isNewCustomer: false,
        ),
      ];

      final newCustomers = customerList.where((c) => c.isBrandNewCustomer).toList();

      expect(newCustomers.length, equals(1));
      expect(newCustomers.first.id, equals('c2'));
    });

    test('TEST 4: Customer serialization & deserialization preserves Google & new customer fields', () {
      final original = Customer(
        id: 'cust-sync',
        streetId: 'street-9',
        name: 'Sync Test Customer',
        phone1: '9988776655',
        address: 'Pune West',
        customerSince: now,
        createdAt: now,
        updatedAt: now,
        authProvider: 'google',
        googleId: 'google-sub-999',
        isNewCustomer: true,
      );

      final map = original.toMap();
      expect(map['auth_provider'], equals('google'));
      expect(map['google_id'], equals('google-sub-999'));
      expect(map['is_new_customer'], equals(1));

      final restored = Customer.fromMap(map);
      expect(restored.authProvider, equals('google'));
      expect(restored.googleId, equals('google-sub-999'));
      expect(restored.isNewCustomer, isTrue);
      expect(restored.isBrandNewCustomer, isTrue);
    });
  });
}
