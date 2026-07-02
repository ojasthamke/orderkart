import 'package:uuid/uuid.dart';
import '../domain/inventory_repository.dart';
import '../domain/item.dart';
import '../domain/stock_history.dart';
import 'item_dao.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final ItemDao _dao;
  final _uuid = const Uuid();
  InventoryRepositoryImpl(this._dao);

  @override
  Future<List<Item>> getAllItems({String? category, String? searchQuery, String? sortBy}) =>
      _dao.getAllItems(category: category, searchQuery: searchQuery, sortBy: sortBy);

  @override
  Future<Item?> getItemById(String id) => _dao.getItemById(id);

  @override
  Future<List<Item>> getLowStockItems() => _dao.getLowStockItems();

  @override
  Future<String> addItem(Item item) => _dao.insertItem(item);

  @override
  Future<void> updateItem(Item item) => _dao.updateItem(item);

  @override
  Future<void> deleteItem(String id) => _dao.deleteItem(id);

  @override
  Future<void> adjustStock(
      String itemId, double change, String reason, {String? orderId}) async {
    final item = await _dao.getItemById(itemId);
    await _dao.adjustStock(itemId, change);
    if (item != null) {
      await _dao.insertStockHistory(StockHistory(
        id:           _uuid.v4(),
        itemId:       itemId,
        itemName:     item.name,
        changeAmount: change,
        reason:       reason,
        orderId:      orderId ?? '',
        createdAt:    DateTime.now(),
      ));
    }
  }

  @override
  Future<List<StockHistory>> getStockHistory(String itemId) =>
      _dao.getStockHistory(itemId);
}
