import 'item.dart';
import 'stock_history.dart';

abstract class InventoryRepository {
  Future<List<Item>> getAllItems({String? category, String? searchQuery, String? sortBy});
  Future<Item?> getItemById(String id);
  Future<List<Item>> getLowStockItems();
  Future<String> addItem(Item item);
  Future<void> updateItem(Item item);
  Future<void> deleteItem(String id);
  Future<void> adjustStock(String itemId, double change, String reason, {String? orderId});
  Future<List<StockHistory>> getStockHistory(String itemId);
}
