import 'package:flutter_test/flutter_test.dart';
import 'package:orderkart/core/utils/catalog_classifier.dart';
import 'package:orderkart/features/inventory/domain/item.dart';
import 'package:orderkart/features/order/domain/order_item.dart';

void main() {
  group('OrderKart Groceries Admin Tests', () {
    test('Groceries status toggle logic correctly maps booleans to string states', () {
      String mapStatus(bool isOpen) => isOpen ? 'open' : 'closed';
      bool parseStatus(String? status) {
        if (status == null) return true;
        return status.trim().toLowerCase() != 'closed';
      }

      expect(mapStatus(true), equals('open'));
      expect(mapStatus(false), equals('closed'));

      expect(parseStatus('open'), isTrue);
      expect(parseStatus('OPEN'), isTrue);
      expect(parseStatus(null), isTrue);
      expect(parseStatus(''), isTrue);
      expect(parseStatus('closed'), isFalse);
      expect(parseStatus('CLOSED'), isFalse);
      expect(parseStatus(' closed '), isFalse);
    });

    test('Category filtering isolates Vegetables from Grocery categories', () {
      final allCategories = [
        {'id': '1', 'name': 'Vegetables', 'is_enabled': true},
        {'id': '2', 'name': 'Dairy', 'is_enabled': true},
        {'id': '3', 'name': 'Staples & Grains', 'is_enabled': true},
        {'id': '4', 'name': 'Snacks & Munchies', 'is_enabled': false},
        {'id': '5', 'name': 'Beverages', 'is_enabled': true},
      ];

      final groceryCategories = allCategories.where((c) {
        final name = (c['name'] as String).trim().toLowerCase();
        return name != 'vegetables';
      }).toList();

      expect(groceryCategories.length, equals(4));
      expect(groceryCategories.any((c) => c['name'] == 'Vegetables'), isFalse);
      expect(groceryCategories.map((c) => c['name']), containsAll(['Dairy', 'Staples & Grains', 'Snacks & Munchies', 'Beverages']));
    });

    test('OrderKart CatalogClassifier strictly classifies Groceries and excludes Vegetables/Medicines', () {
      final now = DateTime.now();
      final vegItem = Item(
        id: 'item_1',
        name: 'Potato',
        category: 'Vegetables',
        unit: 'kg',
        createdAt: now,
        updatedAt: now,
      );
      final grocItem = Item(
        id: 'item_2',
        name: 'Basmati Rice',
        category: 'Groceries',
        unit: 'kg',
        createdAt: now,
        updatedAt: now,
      );
      final dairyItem = Item(
        id: 'item_3',
        name: 'Fresh Milk',
        category: 'Dairy',
        unit: '500ml',
        createdAt: now,
        updatedAt: now,
      );
      final medItem = Item(
        id: 'item_4',
        name: 'Paracetamol',
        category: 'Medicines',
        unit: 'strip',
        createdAt: now,
        updatedAt: now,
      );

      // Groceries Hub item filtering
      expect(CatalogClassifier.isGroceryItem(vegItem), isFalse);
      expect(CatalogClassifier.isGroceryItem(medItem), isFalse);
      expect(CatalogClassifier.isGroceryItem(grocItem), isTrue);
      expect(CatalogClassifier.isGroceryItem(dairyItem), isTrue);

      // Vegetables item filtering
      expect(CatalogClassifier.isVegetableItem(vegItem), isTrue);
      expect(CatalogClassifier.isVegetableItem(grocItem), isFalse);
      expect(CatalogClassifier.isVegetableItem(dairyItem), isFalse);
    });

    test('OrderKart OrderItem classification and order details partitioning', () {
      final now = DateTime.now();
      final potato = Item(id: 'inv_1', name: 'Fresh Potato', category: 'Vegetables', unit: 'kg', createdAt: now, updatedAt: now);
      final rice = Item(id: 'inv_2', name: 'Basmati Rice', category: 'Staples & Grains', unit: 'kg', createdAt: now, updatedAt: now);

      final orderItems = [
        const OrderItem(id: 'oi_1', orderId: 'ord_1', itemId: 'inv_1', itemName: 'Fresh Potato', itemUnit: 'kg', quantity: 2, unitPrice: 30, totalPrice: 60),
        const OrderItem(id: 'oi_2', orderId: 'ord_1', itemId: 'inv_2', itemName: 'Basmati Rice', itemUnit: 'kg', quantity: 1, unitPrice: 120, totalPrice: 120),
        const OrderItem(id: 'oi_3', orderId: 'ord_1', itemId: 'inv_3', itemName: 'Palak Spinach', itemUnit: 'bunch', quantity: 1, unitPrice: 20, totalPrice: 20),
        const OrderItem(id: 'oi_4', orderId: 'ord_1', itemId: 'inv_4', itemName: 'Amul Butter 100g', itemUnit: 'packet', quantity: 1, unitPrice: 58, totalPrice: 58),
      ];

      final itemMap = {'inv_1': potato, 'inv_2': rice};

      final produceItems = <OrderItem>[];
      final groceryItems = <OrderItem>[];

      for (final it in orderItems) {
        final matchedItem = itemMap[it.itemId];
        if (CatalogClassifier.isGroceryOrderItem(it, matchedItem)) {
          groceryItems.add(it);
        } else {
          produceItems.add(it);
        }
      }

      expect(produceItems.length, equals(2));
      expect(produceItems.map((i) => i.itemName), containsAll(['Fresh Potato', 'Palak Spinach']));

      expect(groceryItems.length, equals(2));
      expect(groceryItems.map((i) => i.itemName), containsAll(['Basmati Rice', 'Amul Butter 100g']));
    });
  });
}
