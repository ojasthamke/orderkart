import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/features/inventory/domain/item.dart';
import 'package:orderkart/features/inventory/domain/item_variant.dart';
import 'package:orderkart/features/inventory/data/item_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late ItemDao itemDao;

  setUp(() async {
    itemDao = ItemDao();
    final db = await DatabaseHelper.instance.database;
    await db.delete('item_variants');
    await db.delete('items');
  });

  group('ItemVariant Domain & DAO Tests', () {
    test('ItemVariant domain model serialization', () {
      final now = DateTime.now();
      final variant = ItemVariant(
        id: 'var-1',
        parentItemId: 'item-100',
        variantLabel: '500g Pack',
        sellingPrice: 45.0,
        costPrice: 35.0,
        marketPrice: 50.0,
        stock: 20.0,
        unit: 'g',
        barcode: '1234567890',
        isAvailable: true,
        sequenceNo: 1,
        createdAt: now,
        updatedAt: now,
      );

      final map = variant.toMap();
      expect(map['id'], 'var-1');
      expect(map['parent_item_id'], 'item-100');
      expect(map['variant_label'], '500g Pack');
      expect(map['selling_price'], 45.0);
      expect(map['cost_price'], 35.0);
      expect(map['market_price'], 50.0);
      expect(map['stock'], 20.0);
      expect(map['unit'], 'g');
      expect(map['barcode'], '1234567890');
      expect(map['is_available'], 1);

      final reconstructed = ItemVariant.fromMap(map);
      expect(reconstructed.id, variant.id);
      expect(reconstructed.parentItemId, variant.parentItemId);
      expect(reconstructed.variantLabel, variant.variantLabel);
      expect(reconstructed.sellingPrice, variant.sellingPrice);
      expect(reconstructed.costPrice, variant.costPrice);
      expect(reconstructed.stock, variant.stock);
      expect(reconstructed.unit, variant.unit);
      expect(reconstructed.isAvailable, true);
    });

    test('Insert, fetch, adjust stock, and delete variants under a parent item', () async {
      final now = DateTime.now();
      // 1. Insert parent item
      final parentItem = Item(
        id: 'grocery-rice-1',
        name: 'Basmati Rice',
        category: 'Groceries',
        sellingPrice: 120.0,
        costPrice: 100.0,
        stock: 50.0,
        unit: 'kg',
        createdAt: now,
        updatedAt: now,
      );
      await itemDao.insertItem(parentItem);

      // 2. Insert two variants under parent
      final v1 = ItemVariant(
        id: 'v-rice-1kg',
        parentItemId: parentItem.id,
        variantLabel: '1kg Pack',
        sellingPrice: 130.0,
        costPrice: 105.0,
        stock: 25.0,
        unit: 'kg',
        createdAt: now,
        updatedAt: now,
      );
      final v2 = ItemVariant(
        id: 'v-rice-5kg',
        parentItemId: parentItem.id,
        variantLabel: '5kg Family Bag',
        sellingPrice: 600.0,
        costPrice: 500.0,
        stock: 10.0,
        unit: 'kg',
        sequenceNo: 1,
        createdAt: now,
        updatedAt: now,
      );

      await itemDao.insertVariant(v1);
      await itemDao.insertVariant(v2);

      // 3. Fetch variants for parent
      final variants = await itemDao.getVariantsForItem(parentItem.id);
      expect(variants.length, 2);
      expect(variants.first.variantLabel, '1kg Pack');
      expect(variants.last.variantLabel, '5kg Family Bag');

      // 4. Batch fetch variants by parent IDs
      final batchMap = await itemDao.getVariantsByParentIds([parentItem.id]);
      expect(batchMap.containsKey(parentItem.id), true);
      expect(batchMap[parentItem.id]!.length, 2);

      // 5. Adjust variant stock
      await itemDao.adjustVariantStock(v1.id, 5.0);
      final updatedVariants = await itemDao.getVariantsForItem(parentItem.id);
      final updatedV1 = updatedVariants.firstWhere((v) => v.id == v1.id);
      expect(updatedV1.stock, 30.0);

      // 6. Delete single variant
      await itemDao.deleteVariant(v1.id);
      final afterDelete = await itemDao.getVariantsForItem(parentItem.id);
      expect(afterDelete.length, 1);
      expect(afterDelete.first.id, v2.id);

      // 7. Delete parent item cascades and removes remaining variants
      await itemDao.deleteItem(parentItem.id);
      final afterParentDelete = await itemDao.getVariantsForItem(parentItem.id);
      expect(afterParentDelete.isEmpty, true);
    });
  });
}
