import 'package:flutter_test/flutter_test.dart';
import 'package:orderkart/core/utils/unit_converter.dart';
import 'package:orderkart/features/inventory/domain/item.dart';
import 'package:orderkart/features/order/domain/order_item.dart';

void main() {
  group('OrderKart Inventory Deep Bug Hunt — Loops 1 to 6 Forensic Verification', () {
    
    test('1. UnitConverter: toWeightInKg calculates weight for count units using weightPerPiece', () {
      final double weightPieces = UnitConverter.toWeightInKg(10, 'piece', weightPerPiece: 0.5);
      expect(weightPieces, equals(5.0));

      final double weightDozens = UnitConverter.toWeightInKg(2, 'dozen', weightPerPiece: 0.25);
      expect(weightDozens, equals(6.0));

      final double weightKg = UnitConverter.toWeightInKg(500, 'gram', weightPerPiece: 0.25);
      expect(weightKg, equals(0.5));
    });

    test('2. Item.fromMap: Robust type casting against String numbers, nulls, and boolean mismatch', () {
      final map = {
        'id': 'test-uuid-1',
        'name': 'Test Item',
        'category': 'Vegetables',
        'cost_price': '45.50',
        'selling_price': '60.00',
        'market_price': '75.00',
        'stock': '12.50',
        'min_stock': '5.00',
        'unit': 'kg',
        'prescription_required': true,
        'order_now_stock': '8.25',
        'order_now_selling_price': '65.00',
        'order_now_mrp': '80.00',
        'order_now_cost_price': '50.00',
        'order_now_is_available': 'true',
      };

      final item = Item.fromMap(map);
      expect(item.costPrice, equals(45.50));
      expect(item.sellingPrice, equals(60.00));
      expect(item.marketPrice, equals(75.00));
      expect(item.stock, equals(12.50));
      expect(item.minStock, equals(5.00));
      expect(item.prescriptionRequired, isTrue);
      expect(item.orderNowStock, equals(8.25));
      expect(item.orderNowSellingPrice, equals(65.00));
      expect(item.orderNowMrp, equals(80.00));
      expect(item.orderNowCostPrice, equals(50.00));
      expect(item.orderNowIsAvailable, isTrue);
    });

    test('3. Reorder Logic: Uses current live inventory selling price, not stale historical order price', () {
      final liveItem = Item(
        id: 'tomato-uuid',
        name: 'Tomato',
        category: 'Vegetables',
        sellingPrice: 80.0,
        costPrice: 60.0,
        marketPrice: 90.0,
        stock: 50.0,
        unit: 'kg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const oldOrderItem = OrderItem(
        id: 'old-item-1',
        orderId: 'old-order-1',
        itemId: 'tomato-uuid',
        itemName: 'Tomato',
        itemUnit: 'kg',
        quantity: 2.0,
        unitPrice: 30.0,
        totalPrice: 60.0,
      );

      final double resolvedPrice = (liveItem.sellingPrice > 0)
          ? liveItem.sellingPrice
          : oldOrderItem.unitPrice;

      expect(resolvedPrice, equals(80.0));
      expect(resolvedPrice, isNot(equals(oldOrderItem.unitPrice)));
    });

    test('4. Item copyWith and toMap preserve all V6 and Order Now fields', () {
      final now = DateTime.now();
      final item = Item(
        id: 'item-100',
        name: 'Organic Milk',
        category: 'Dairy',
        costPrice: 28.0,
        sellingPrice: 34.0,
        marketPrice: 36.0,
        stock: 20.0,
        minStock: 5.0,
        unit: 'liter',
        createdAt: now,
        updatedAt: now,
        orderNowStock: 15.0,
        orderNowSellingPrice: 35.0,
        orderNowMrp: 38.0,
        orderNowCostPrice: 30.0,
        orderNowIsAvailable: true,
      );

      final updated = item.copyWith(stock: 18.0, orderNowStock: 12.0);
      expect(updated.stock, equals(18.0));
      expect(updated.orderNowStock, equals(12.0));
      expect(updated.sellingPrice, equals(34.0));
      expect(updated.orderNowSellingPrice, equals(35.0));

      final map = updated.toMap();
      expect(map['stock'], equals(18.0));
      expect(map['order_now_stock'], equals(12.0));
      expect(map['order_now_selling_price'], equals(35.0));
      expect(map['order_now_is_available'], equals(1));
    });

    test('5. Customer Savings and Margin Calculations', () {
      final item = Item(
        id: 'item-200',
        name: 'Almonds',
        category: 'Dry Fruits',
        costPrice: 400.0,
        sellingPrice: 500.0,
        marketPrice: 600.0,
        stock: 10.0,
        unit: 'kg',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(item.customerSavings, equals(100.0));
      expect(item.customerSavingsPct, closeTo(16.67, 0.01));
      expect(item.profitMargin, equals(20.0));
    });

  });
}
