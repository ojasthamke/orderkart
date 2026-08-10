import 'package:flutter_test/flutter_test.dart';
import 'package:orderkart/core/utils/unit_converter.dart';
import 'package:orderkart/features/order/presentation/create_order_screen.dart';
import 'package:orderkart/features/inventory/domain/item.dart';

void main() {
  group('Real-Time In-Stock & Cart Calculations', () {
    final testItem = Item(
      id: 'item_101',
      name: 'Tomato (टोमॅटो)',
      category: 'Vegetables',
      costPrice: 20.0,
      sellingPrice: 30.0,
      marketPrice: 35.0,
      stock: 10.0, // 10 kg in stock
      minStock: 2.0,
      unit: 'kg',
      barcode: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      expiryDate: '',
      batchNumber: '',
      prescriptionRequired: false,
      dosageInfo: '',
      bestBefore: '',
      packDate: '',
      weightPerPiece: 0.0,
      photoPath: '',
      sequenceNo: 1,
    );

    test('Computes available stock correctly with empty cart', () {
      final cart = <CartItem>[];
      final inCart = cart.where((c) => c.itemId == testItem.id).fold<double>(0.0, (s, c) => s + c.quantity);
      final avail = (testItem.stock - inCart).clamp(0.0, double.infinity);

      expect(avail, 10.0);
      expect(avail > 0.001, isTrue);
    });

    test('Computes available stock and in-cart quantity in real time when items added', () {
      final cart = <CartItem>[
        const CartItem(itemId: 'item_101', name: 'Tomato (टोमॅटो)', unit: 'kg', price: 30.0, quantity: 4.0),
      ];

      final inCart = cart.where((c) => c.itemId == testItem.id).fold<double>(0.0, (s, c) => s + c.quantity);
      final avail = (testItem.stock - inCart).clamp(0.0, double.infinity);

      expect(inCart, 4.0);
      expect(avail, 6.0);
      expect(avail <= testItem.minStock, isFalse);
    });

    test('Recognizes low stock threshold when cart reaches near max stock', () {
      final cart = <CartItem>[
        const CartItem(itemId: 'item_101', name: 'Tomato (टोमॅटो)', unit: 'kg', price: 30.0, quantity: 8.5),
      ];

      final inCart = cart.where((c) => c.itemId == testItem.id).fold<double>(0.0, (s, c) => s + c.quantity);
      final avail = (testItem.stock - inCart).clamp(0.0, double.infinity);

      expect(avail, 1.5);
      final isLow = avail > 0 && avail <= (testItem.minStock > 0 ? testItem.minStock : 2.0);
      expect(isLow, isTrue);
    });

    test('Recognizes out of stock / all in cart state when all stock is added', () {
      final cart = <CartItem>[
        const CartItem(itemId: 'item_101', name: 'Tomato (टोमॅटो)', unit: 'kg', price: 30.0, quantity: 10.0),
      ];

      final inCart = cart.where((c) => c.itemId == testItem.id).fold<double>(0.0, (s, c) => s + c.quantity);
      final avail = (testItem.stock - inCart).clamp(0.0, double.infinity);
      final isOutOfStock = avail < 0.001;
      final allInCart = inCart > 0 && isOutOfStock;

      expect(avail, 0.0);
      expect(isOutOfStock, isTrue);
      expect(allInCart, isTrue);
    });

    test('Unit conversion handles gram to kg in-cart aggregation', () {
      final cart = <CartItem>[
        const CartItem(itemId: 'item_101', name: 'Tomato (टोमॅटो)', unit: 'gram', price: 0.03, quantity: 500.0),
      ];

      final inCartInKg = cart.where((c) => c.itemId == testItem.id).fold<double>(
        0.0,
        (s, c) => s + UnitConverter.convert(quantity: c.quantity, fromUnit: c.unit, toUnit: testItem.unit),
      );
      final avail = (testItem.stock - inCartInKg).clamp(0.0, double.infinity);

      expect(inCartInKg, 0.5);
      expect(avail, 9.5);
    });
  });
}
