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
    'oil',
    'packaged food',
    'personal care',
    'household',
    'cleaning & household',
    'bakery & biscuits',
    'dry fruits',
    'fruits',
    'fruit',
    'fresh fruits',
  };

  /// Non-grocery categories that must NEVER appear in the groceries section
  static const Set<String> nonGroceryCategories = {
    'vegetables',
    'vegetable',
    'veggies',
    'fresh vegetables',
    'leafy greens',
    'medicines',
    'medicine',
  };

  /// Canonical static UUID-to-Category mapping directly from Supabase.
  static const Map<String, String> knownCategoryMap = {
    'b784d64b-ac8a-499c-9bcc-d157009bbe68': 'Staples & Grains',
    '244b85ae-c0c8-48a8-b05e-2cc4db621757': 'Dairy',
    '127a6476-e3e1-4f42-84c2-41e50dcd9aa0': 'Snacks & Munchies',
    'a59fc450-5cf6-433e-8cbe-347564d31a12': 'Beverages',
    '874a817f-e317-4144-a0dd-77652f65eac3': 'Spices & Masalas',
    '9a7019be-6890-4517-b044-ea7bc30854fb': 'Groceries',
    '1c90e9d0-3f04-41a0-8177-5d9369b77cd8': 'Oil',
    '10bc0964-1ffb-498a-993d-377779882d7e': 'Vegetables',
    'ed7b194c-1bf9-47a3-b1b2-e48f17fb9dd3': 'Fruits',
  };

  /// Known Supabase UUIDs that belong to Groceries & Fruits
  static const Set<String> knownGroceryCategoryIds = {
    'b784d64b-ac8a-499c-9bcc-d157009bbe68',
    '244b85ae-c0c8-48a8-b05e-2cc4db621757',
    '127a6476-e3e1-4f42-84c2-41e50dcd9aa0',
    'a59fc450-5cf6-433e-8cbe-347564d31a12',
    '874a817f-e317-4144-a0dd-77652f65eac3',
    '9a7019be-6890-4517-b044-ea7bc30854fb',
    '1c90e9d0-3f04-41a0-8177-5d9369b77cd8',
    'ed7b194c-1bf9-47a3-b1b2-e48f17fb9dd3',
  };

  /// Known Supabase UUIDs that are raw Vegetables
  static const Set<String> knownNonGroceryCategoryIds = {
    '10bc0964-1ffb-498a-993d-377779882d7e', // Vegetables
  };

  /// Packaged item units strongly associated with Groceries
  static const Set<String> packagedUnits = {
    'pack',
    'packet',
    'pkt',
    'box',
    'bottle',
    'can',
    'jar',
    'tin',
    'pouch',
    'sachet',
    'tetra',
    'brick',
    'bar',
    'tub',
  };

  /// Modifiers that turn a potential vegetable keyword into a packaged grocery product
  /// (e.g. "Chilli Powder", "Coriander Powder", "Ginger Garlic Paste", "Garlic Pickle")
  static const List<String> groceryModifiers = [
    'powder',
    'paste',
    'masala',
    'puree',
    'sauce',
    'oil',
    'pickle',
    'achar',
    'chips',
    'dried',
    'dry',
    'seed',
    'seeds',
    'mix',
    'flavour',
    'flavor',
  ];

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

  /// Common grocery keywords used for classification and fallback
  static const List<String> groceryKeywords = [
    // Staples, Grains, Pulses, Flours
    'atta', 'flour', 'maida', 'sooji', 'suji', 'besan', 'dal', 'dalll', 'chana',
    'moong', 'urad', 'toor', 'masoor', 'rajma', 'chole', 'poha', 'rice', 'basmati',
    'vermicelli', 'sewai', 'pasta', 'macaroni', 'noodles', 'maggi', 'jaggery',
    'gud', 'sugar', 'salt', 'rava', 'wheat', 'grain', 'millet', 'sattu',
    'chitra',

    // Oils & Ghee
    'oil', 'ghee', 'refined', 'mustard oil', 'sunflower', 'groundnut', 'soya oil',
    'olive oil',

    // Dairy & Breakfast
    'milk', 'butter', 'cheese', 'paneer', 'curd', 'dahi', 'yogurt', 'cream',
    'bread', 'toast', 'rusk', 'cornflakes', 'oats', 'muesli', 'corn flakes',

    // Spices & Seasonings
    'masala', 'haldi', 'turmeric', 'jeera', 'cumin', 'rai', 'mustard seeds',
    'hing', 'elaichi', 'cardamom', 'clove', 'laung', 'dalchini', 'cinnamon',
    'pepper', 'kali mirch', 'methi seeds', 'garam masala', 'coriander powder',
    'chilli powder', 'mirch powder', 'amchur', 'dhaniya powder',

    // Snacks, Munchies, Biscuits
    'biscuit', 'cookie', 'cookies', 'chips', 'wafer', 'namkeen', 'bhujia',
    'chivda', 'farsan', 'popcorn', 'snack', 'snacks', 'cracker',

    // Beverages & Drinks
    'tea', 'chai', 'coffee', 'boost', 'horlicks', 'bournvita', 'juice',
    'drink', 'squash', 'syrup', 'sharbat', 'soda', 'beverage', 'coke', 'pepsi',
    'sprite', 'thums up', 'frooti', 'maaza', 'slice',

    // Sweets, Sauces & Spreads
    'chocolate', 'candy', 'toffee', 'mithai', 'sweet', 'honey', 'jam',
    'spread', 'ketchup', 'sauce', 'mayonnaise', 'peanut butter',

    // Dry Fruits & Nuts
    'kaju', 'cashew', 'badam', 'almond', 'pista', 'pistachio', 'kishmish',
    'raisin', 'walnut', 'akhrot', 'dates', 'khajoor', 'dry fruit', 'anjeer',

    // Popular Packaged Grocery Brands
    'tata', 'sampann', 'fortune', 'aashirvaad', 'bambino', '24 mantra',
    'catch', 'everest', 'mdh', 'nestle', 'cadbury', 'parle', 'britannia',
    'sunfeast', 'lays', 'kurkure', 'amul', 'haldiram', 'saffola', 'kellogg',
    'kissan', 'lipton', 'taj mahal', 'red label', 'brooke bond', 'dabur',
    'patanjali', 'parle-g', 'good day', 'bourbon', 'oreo', 'mariegold',
    'gemini', 'dhara', 'sweekar', 'mother dairy', 'gowardhan', 'milky mist',
    'paper boat', 'real', 'tropicana', 'sting', 'red bull',

    // Cleaning & Household Care
    'soap', 'shampoo', 'detergent', 'surf', 'rin', 'wheel', 'ariel', 'tide',
    'vim', 'harpic', 'colgate', 'toothpaste', 'brush', 'dettol', 'lifebuoy',
    'dove', 'lux', 'cleaner', 'wash', 'handwash', 'sanitizer',
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
        normalized.contains('grain') ||
        normalized.contains('oil');
  }

  /// Determines if an [Item] is strictly a Grocery item.
  static bool isGroceryItem(Item item) {
    final catIdLower = item.id.toLowerCase();
    if (knownGroceryCategoryIds.contains(catIdLower)) {
      return true;
    }
    if (isGroceryCategory(item.category)) {
      return true;
    }

    final nameLower = item.name.toLowerCase().trim();
    for (final mod in groceryModifiers) {
      if (nameLower.contains(mod)) return true;
    }
    for (final kw in groceryKeywords) {
      if (nameLower.contains(kw)) return true;
    }

    final unitLower = item.unit.toLowerCase().trim();
    if (packagedUnits.contains(unitLower)) {
      bool isVeg = false;
      for (final kw in vegetableKeywords) {
        if (nameLower.contains(kw)) {
          isVeg = true;
          break;
        }
      }
      if (!isVeg) return true;
    }

    return false;
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
    final nameLower = item.name.toLowerCase().trim();
    for (final kw in vegetableKeywords) {
      if (nameLower.contains(kw)) return true;
    }
    // Default produce
    return normalized != AppConstants.catMedicines.toLowerCase() &&
        !normalized.contains('medicine');
  }

  /// Determines if an [OrderItem] is strictly a Grocery item.
  static bool isGroceryOrderItem(OrderItem item, [Item? matchedItem]) {
    if (matchedItem != null) {
      if (isGroceryItem(matchedItem)) return true;
      if (!isVegetableItem(matchedItem)) {
        if (isGroceryCategory(matchedItem.category)) return true;
      }
    }

    final nameLower = item.itemName.toLowerCase().trim();
    final unitLower = item.itemUnit.toLowerCase().trim();
    final itemIdLower = item.itemId.toLowerCase().trim();

    // 1. Check known grocery category or product UUID prefix
    if (knownGroceryCategoryIds.contains(itemIdLower)) {
      return true;
    }
    for (final catId in knownGroceryCategoryIds) {
      if (itemIdLower.startsWith(catId)) return true;
    }

    // 2. Check for grocery modifiers (e.g. powder, paste, masala, oil, pickle)
    for (final mod in groceryModifiers) {
      if (nameLower.contains(mod)) {
        return true;
      }
    }

    // 3. Keyword match for approved grocery keywords & brands
    for (final kw in groceryKeywords) {
      if (nameLower.contains(kw)) {
        return true;
      }
    }

    // 4. Packaged unit check
    if (packagedUnits.contains(unitLower)) {
      bool isExplicitVeg = false;
      for (final kw in vegetableKeywords) {
        if (nameLower.contains(kw)) {
          isExplicitVeg = true;
          break;
        }
      }
      if (!isExplicitVeg) {
        return true;
      }
    }

    // 5. Check vegetable keywords
    for (final kw in vegetableKeywords) {
      if (nameLower.contains(kw)) return false;
    }

    // 6. Check approved grocery categories
    for (final cat in groceryCategories) {
      if (nameLower.contains(cat)) return true;
    }

    return false;
  }
}
