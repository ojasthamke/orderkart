import 'package:flutter_test/flutter_test.dart';
import 'package:orderkart/core/utils/catalog_classifier.dart';
import 'package:orderkart/features/inventory/domain/item.dart';
import 'package:orderkart/features/order/domain/order_item.dart';

void main() {
  group('Order Detail Classification & Partitioning Tests', () {
    test('Order #ORD-0409 items are strictly classified as Groceries & Packaged Goods', () {
      final ord0409Items = [
        const OrderItem(
          id: 'ord_it_1',
          orderId: '40ce2e9e-c216-434b-a1f7-6503e39ebdee',
          itemId: '4e161621-8ae6-4947-8b6f-546d9dbfa4aa',
          itemName: 'Tata Sampann Rajma Chitra',
          itemUnit: 'pack',
          quantity: 1.0,
          unitPrice: 92.0,
          totalPrice: 92.0,
        ),
        const OrderItem(
          id: 'ord_it_2',
          orderId: '40ce2e9e-c216-434b-a1f7-6503e39ebdee',
          itemId: '57baee22-0945-442c-b64a-32aa6b7ffb37',
          itemName: 'Tata Sampann Chana Dal',
          itemUnit: 'pack',
          quantity: 1.0,
          unitPrice: 55.0,
          totalPrice: 55.0,
        ),
        const OrderItem(
          id: 'ord_it_3',
          orderId: '40ce2e9e-c216-434b-a1f7-6503e39ebdee',
          itemId: '6445392d-97e0-40da-b174-b12d69133869',
          itemName: 'Bambino Roasted Vermicelli',
          itemUnit: 'pack',
          quantity: 1.0,
          unitPrice: 38.0,
          totalPrice: 38.0,
        ),
        const OrderItem(
          id: 'ord_it_4',
          orderId: '40ce2e9e-c216-434b-a1f7-6503e39ebdee',
          itemId: '9cad05a9-e11a-4571-bd09-ad92f5f5ac3f',
          itemName: '24 Mantra Organic Jaggery',
          itemUnit: 'pack',
          quantity: 1.0,
          unitPrice: 65.0,
          totalPrice: 65.0,
        ),
        const OrderItem(
          id: 'ord_it_5',
          orderId: '40ce2e9e-c216-434b-a1f7-6503e39ebdee',
          itemId: 'ff4462b1-3dce-46aa-9b46-1041253e26b1',
          itemName: 'Aashirvaad Sharbati Atta',
          itemUnit: 'kg',
          quantity: 1.0,
          unitPrice: 72.0,
          totalPrice: 72.0,
        ),
      ];

      final produceItems = <OrderItem>[];
      final groceryItems = <OrderItem>[];
      double produceSubtotal = 0.0;
      double grocerySubtotal = 0.0;

      for (final it in ord0409Items) {
        // Even when matchedItem is null (e.g. fresh order before local inventory sync)
        final isGrocery = CatalogClassifier.isGroceryOrderItem(it, null);
        if (isGrocery) {
          groceryItems.add(it);
          grocerySubtotal += it.totalPrice;
        } else {
          produceItems.add(it);
          produceSubtotal += it.totalPrice;
        }
      }

      // Exactly 5 items in Groceries, 0 in Produce
      expect(produceItems.length, equals(0));
      expect(produceSubtotal, equals(0.0));
      expect(groceryItems.length, equals(5));
      expect(grocerySubtotal, equals(322.0));
    });

    test('Fresh produce items are strictly categorized into Produce', () {
      final produceList = [
        const OrderItem(
          id: 'p1',
          orderId: 'ord_1',
          itemName: 'Tomato Hybrid',
          itemUnit: 'kg',
          quantity: 2.0,
          unitPrice: 30.0,
          totalPrice: 60.0,
        ),
        const OrderItem(
          id: 'p2',
          orderId: 'ord_1',
          itemName: 'Onion Nashik',
          itemUnit: 'kg',
          quantity: 1.5,
          unitPrice: 40.0,
          totalPrice: 60.0,
        ),
        const OrderItem(
          id: 'p3',
          orderId: 'ord_1',
          itemName: 'Potato Jyoti',
          itemUnit: 'kg',
          quantity: 3.0,
          unitPrice: 25.0,
          totalPrice: 75.0,
        ),
        const OrderItem(
          id: 'p4',
          orderId: 'ord_1',
          itemName: 'Shimla Mirch (Capsicum)',
          itemUnit: 'kg',
          quantity: 0.5,
          unitPrice: 80.0,
          totalPrice: 40.0,
        ),
      ];

      for (final it in produceList) {
        expect(CatalogClassifier.isGroceryOrderItem(it), isFalse);
      }
    });

    test('Grocery modifiers prevent misclassifying spices and pastes as fresh vegetables', () {
      final modifiedGroceryItems = [
        const OrderItem(
          id: 'g1',
          orderId: 'ord_2',
          itemName: 'Catch Coriander Powder',
          itemUnit: 'pack',
          quantity: 1.0,
          unitPrice: 45.0,
          totalPrice: 45.0,
        ),
        const OrderItem(
          id: 'g2',
          orderId: 'ord_2',
          itemName: 'Everest Kashmiri Chilli Powder',
          itemUnit: 'pack',
          quantity: 1.0,
          unitPrice: 60.0,
          totalPrice: 60.0,
        ),
        const OrderItem(
          id: 'g3',
          orderId: 'ord_2',
          itemName: 'Dabur Ginger Garlic Paste',
          itemUnit: 'pouch',
          quantity: 2.0,
          unitPrice: 30.0,
          totalPrice: 60.0,
        ),
      ];

      for (final it in modifiedGroceryItems) {
        expect(CatalogClassifier.isGroceryOrderItem(it), isTrue,
            reason: '${it.itemName} must be classified as Grocery');
      }
    });

    test('Variant ID suffix does not prevent matched inventory lookup', () {
      final now = DateTime.now();
      final parentItem = Item(
        id: 'parent_uuid_123',
        name: 'Tata Tea Gold',
        category: 'Beverages',
        unit: 'pack',
        createdAt: now,
        updatedAt: now,
      );

      final itemByIdMap = {parentItem.id: parentItem};
      const orderItem = OrderItem(
        id: 'ord_item_variant',
        orderId: 'ord_3',
        itemId: 'parent_uuid_123_var_0',
        itemName: 'Tata Tea Gold 500g',
        itemUnit: 'pack',
        quantity: 1.0,
        unitPrice: 260.0,
        totalPrice: 260.0,
      );

      Item? matched = itemByIdMap[orderItem.itemId];
      if (matched == null && orderItem.itemId.contains('_var_')) {
        final baseId = orderItem.itemId.split('_var_').first;
        matched = itemByIdMap[baseId];
      }

      expect(matched, isNotNull);
      expect(matched!.id, equals('parent_uuid_123'));
      expect(CatalogClassifier.isGroceryOrderItem(orderItem, matched), isTrue);
    });
  });
}
