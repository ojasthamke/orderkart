import '../constants/app_constants.dart';
import '../../features/inventory/domain/item.dart';
import '../../features/order/domain/order_item.dart';

/// Centralized classifier to strictly isolate Groceries from Vegetables and other inventory items.
class CatalogClassifier {
  CatalogClassifier._();

  /// Known approved Grocery category names and identifiers
  static const Set<String> groceryCategories = {
    'groceries',
    'grocery',
    'dairy',
    'dairy & eggs',
    'staples & grains',
    'staples',
    'grains',
    'atta, rice & dal',
    'snacks & munchies',
    'snacks',
    'beverages',
    'drinks',
    'tea & coffee',
    'spices & masalas',
    'spices',
    'masalas',
    'oils & ghee',
    'packaged food',
    'personal care',
    'household',
    'cleaning & household',
    'bakery & biscuits',
    'dry fruits',
  };

  /// Non-grocery categories that must NEVER appear in the groceries section
  static const Set<String> nonGroceryCategories = {
    'vegetables',
    'vegetable',
    'veggies',
    'fresh vegetables',
    'leafy greens',
    'fruits',
    'fruit',
    'fresh fruits',
    'medicines',
    'medicine',
  };

  /// Vegetable and fresh produce keywords to strictly reject from Groceries
  static const List<String> vegetableKeywords = [
    'tomato', 'tamatar', 'onion', 'kanda', 'potato', 'batata', 'aalu',
    'mirchi', 'chilli', 'palak', 'spinach', 'methi', 'bhindi', 'okra',
    'gajar', 'carrot', 'kobi', 'cabbage', 'cauliflower',
    'shimla', 'capsicum', 'limbu', 'lemon', 'vange', 'brinjal', 'lauki',
    'bottle gourd', 'karela', 'bitter gourd', 'shepu', 'chavri', 'shenga',
    'sambar', 'coriander', 'kothimbir', 'ginger', 'adrak', 'lasun',
    'pudina', 'mint', 'apple', 'banana', 'mango', 'orange', 'fruit', 'veggie'
  ];

  /// Common grocery keywords used as fallback when category metadata is missing
  static const List<String> groceryKeywords = [
    'atta', 'oil', 'milk', 'butter', 'chips', 'tea', 'turmeric',
    'masala', 'dal', 'biscuit', 'salt', 'sugar', 'ghee',
    'paneer', 'curd', 'soap', 'shampoo', 'detergent', 'snack', 'beverage'
  ];

  /// Returns true if [categoryName] represents an approved grocery category.
  static bool isGroceryCategory(String? categoryName) {
    if (categoryName == null || categoryName.trim().isEmpty) return false;
    final normalized = categoryName.trim().toLowerCase();
    if (nonGroceryCategories.contains(normalized)) return false;

    return normalized == AppConstants.catGroceries.toLowerCase() ||
        groceryCategories.contains(normalized) ||
        normalized.contains('grocer') ||
        normalized.contains('dairy') ||
        normalized.contains('staple') ||
        normalized.contains('snack') ||
        normalized.contains('beverage') ||
        normalized.contains('spice') ||
        normalized.contains('masala') ||
        normalized.contains('packaged') ||
        normalized.contains('grain');
  }

  /// Determines if an [Item] is strictly a Grocery item.
  static bool isGroceryItem(Item item) {
    return isGroceryCategory(item.category);
  }

  /// Determines if an [Item] is a Vegetable / Fresh Produce item.
  static bool isVegetableItem(Item item) {
    if (isGroceryItem(item)) return false;
    final normalized = item.category.trim().toLowerCase();
    if (normalized == AppConstants.catVegetables.toLowerCase() ||
        normalized.contains('vegetable') ||
        normalized.contains('veggie')) {
      return true;
    }
    // Default produce
    return normalized != AppConstants.catMedicines.toLowerCase() &&
        !normalized.contains('medicine');
  }

  /// Determines if an [OrderItem] is strictly a Grocery item.
  static bool isGroceryOrderItem(OrderItem item, [Item? matchedItem]) {
    if (matchedItem != null) {
      return isGroceryItem(matchedItem);
    }
    final nameLower = item.itemName.toLowerCase();
    for (final kw in vegetableKeywords) {
      if (nameLower.contains(kw)) return false;
    }
    for (final kw in groceryKeywords) {
      if (nameLower.contains(kw)) return true;
    }
    for (final cat in groceryCategories) {
      if (nameLower.contains(cat)) return true;
    }
    return false;
  }
}
