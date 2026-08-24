import 'package:flutter_test/flutter_test.dart';
import 'package:orderkart/core/utils/smart_rounding.dart';
import 'package:orderkart/core/utils/bill_text_generator.dart';
import 'package:orderkart/features/order/presentation/create_order_screen.dart';
import 'package:orderkart/features/inventory/domain/item.dart';

void main() {
  group('Stock Warning, Calculation & Catalog 0-Stock Filter Audit', () {
    final inStockItem = Item(
      id: 'item_apple',
      name: 'Shimla Apple (सफरचंद)',
      category: 'Fruits',
      costPrice: 80.0,
      sellingPrice: 120.0,
      marketPrice: 140.0,
      stock: 5.0, // 5 kg in stock
      minStock: 1.0,
      unit: 'kg',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final zeroStockItem = Item(
      id: 'item_mango',
      name: 'Alphonso Mango (हापूस आंबा)',
      category: 'Fruits',
      costPrice: 500.0,
      sellingPrice: 700.0,
      marketPrice: 800.0,
      stock: 0.0, // 0 kg in stock (OUT OF STOCK)
      minStock: 2.0,
      unit: 'kg',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('1. 0-Stock Item is recognized as Out of Stock', () {
      expect(zeroStockItem.stock <= 0, isTrue);
      expect(inStockItem.stock > 0, isTrue);

      final items = [inStockItem, zeroStockItem];
      final pdfItems = items.where((i) => i.stock > 0.0001).toList();

      expect(pdfItems.length, 1);
      expect(pdfItems.first.id, 'item_apple');
      expect(pdfItems.any((i) => i.id == 'item_mango'), isFalse);
    });

    test('2. Cart Line Total calculation with full decimal precision', () {
      // 250 grams of an item priced at ₹25/kg (unit price = 0.025 / gram)
      const unitPricePerGram = 25.0 / 1000.0; // 0.025
      const qtyGrams = 250.0;
      const cartItem = CartItem(
        itemId: 'item_potato',
        name: 'Potato (बटाटा)',
        unit: 'gram',
        price: unitPricePerGram,
        quantity: qtyGrams,
      );

      // Must be exactly 6.25 (not truncated to 5.00 or 7.50)
      expect(cartItem.total, 6.25);
    });

    test('3. Reorder Logic: Out of stock items are skipped and partial stock clamped', () {
      final inventory = [
        inStockItem.copyWith(stock: 1.5), // only 1.5 kg available
        zeroStockItem, // 0 stock
      ];

      final previousOrderItems = [
        {'itemId': 'item_mango', 'name': 'Alphonso Mango', 'qty': 2.0, 'unit': 'kg', 'price': 700.0},
        {'itemId': 'item_apple', 'name': 'Shimla Apple', 'qty': 4.0, 'unit': 'kg', 'price': 120.0},
      ];

      final List<CartItem> validCartItems = [];
      final List<String> skipped = [];
      final List<String> adjusted = [];

      for (final prev in previousOrderItems) {
        final dbItem = inventory.where((i) => i.id == prev['itemId']).firstOrNull;
        if (dbItem == null || dbItem.stock < 0.001) {
          skipped.add(prev['name'] as String);
          continue;
        }

        double qty = prev['qty'] as double;
        if (qty > dbItem.stock) {
          adjusted.add('${prev['name']} adjusted to ${dbItem.stock}');
          qty = dbItem.stock;
        }

        validCartItems.add(CartItem(
          itemId: dbItem.id,
          name: dbItem.name,
          unit: prev['unit'] as String,
          price: prev['price'] as double,
          quantity: qty,
        ));
      }

      expect(skipped.contains('Alphonso Mango'), isTrue);
      expect(validCartItems.length, 1);
      expect(validCartItems.first.itemId, 'item_apple');
      expect(validCartItems.first.quantity, 1.5);
      expect(validCartItems.first.total, 180.0); // 1.5 * 120 = 180.0
    });

    test('4. Manual Verification of Full Bill Math', () {
      final cart = [
        const CartItem(itemId: '1', name: 'Tomato', unit: 'kg', price: 40.0, quantity: 2.5), // 100.00
        const CartItem(itemId: '2', name: 'Onion', unit: 'kg', price: 30.0, quantity: 1.5),  // 45.00
        const CartItem(itemId: '3', name: 'Ginger', unit: 'gram', price: 0.08, quantity: 250.0), // 20.00
      ];

      final subtotal = cart.fold<double>(0.0, (s, i) => s + i.total);
      expect(subtotal, 165.00);

      const discount = 15.00;
      const delivery = 20.00;
      final afterDiscount = (subtotal - discount).clamp(0.0, double.infinity); // 150.00
      final unrounded = afterDiscount + delivery; // 170.00
      final grandTotal = SmartRounding.round(unrounded); // 170.00

      const paidAmount = 100.00;
      final remainingDue = grandTotal - paidAmount; // 70.00

      expect(afterDiscount, 150.00);
      expect(unrounded, 170.00);
      expect(grandTotal, 170.00);
      expect(remainingDue, 70.00);

      final billText = BillTextGenerator.generate(
        businessName: 'OrderKart Mart',
        customerName: 'Suresh Patil',
        customerAddress: 'Baner, Pune',
        orderNoLabel: 'OW12345',
        orderDate: DateTime(2026, 8, 24),
        items: cart.map((c) => {
          'item_name': c.name,
          'quantity': c.quantity,
          'item_unit': c.unit,
          'unit_price': c.price,
          'total_price': c.total,
        }).toList(),
        subtotal: subtotal,
        discount: discount,
        deliveryCharge: delivery,
        grandTotal: grandTotal,
        paidAmount: paidAmount,
        remainingAmount: remainingDue,
        paymentMethod: 'cash',
        ownerPhone: '9876543210',
      );

      expect(billText.contains('Subtotal:       ₹165.00'), isTrue);
      expect(billText.contains('Discount:       -₹15.00'), isTrue);
      expect(billText.contains('Delivery Fee:   +₹20.00'), isTrue);
      expect(billText.contains('Grand Total:    ₹170.00'), isTrue);
      expect(billText.contains('Due Amount:     ₹70.00'), isTrue);
    });
  });
}
