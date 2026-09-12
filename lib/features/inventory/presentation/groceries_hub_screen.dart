import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/catalog_classifier.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/security/app_mode_service.dart';
import '../domain/item.dart';
import '../domain/item_variant.dart';
import '../domain/stock_history.dart';
import '../data/item_dao.dart';
import '../data/inventory_repository_impl.dart';
import 'inventory_provider.dart';
import 'widgets/variant_editor_sheet.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../expense/domain/expense.dart';
import '../../expense/data/expense_dao.dart';
import '../../../core/services/customer_order_sync_service.dart';

class GroceriesHubScreen extends ConsumerStatefulWidget {
  const GroceriesHubScreen({super.key});

  @override
  ConsumerState<GroceriesHubScreen> createState() => _GroceriesHubScreenState();
}

class _GroceriesHubScreenState extends ConsumerState<GroceriesHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _spoilageFormKey = GlobalKey<FormState>();

  Item? _selectedSpoilageItem;
  final _spoilageQtyCon = TextEditingController();
  final _spoilageRemarksCon = TextEditingController();
  bool _submittingSpoilage = false;

  String _selectedCategory = 'All';
  String _searchQuery = '';
  final _searchCon = TextEditingController();
  List<String> _dynamicGroceryCategories = ['All', ...AppConstants.groceryCategories];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGroceryCategories();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncToCloud(showFeedback: false);
    });
  }

  Future<void> _loadGroceryCategories() async {
    try {
      final res = await Supabase.instance.client
          .from('categories')
          .select('name, is_enabled, sort_order')
          .order('sort_order', ascending: true)
          .order('name', ascending: true);
      final cats = <String>['All'];
      for (final r in res as List) {
        final name = (r['name'] ?? '').toString().trim();
        final enabled = r['is_enabled'] != false;
        if (name.isNotEmpty && enabled && CatalogClassifier.isGroceryCategory(name) && !cats.contains(name)) {
          cats.add(name);
        }
      }
      for (final def in AppConstants.groceryCategories) {
        if (!cats.contains(def)) cats.add(def);
      }
      if (mounted) {
        setState(() {
          _dynamicGroceryCategories = cats;
        });
      }
    } catch (_) {}
  }

  bool _matchesGroceryCategory(Item item, String selectedCat) {
    if (selectedCat == 'All') return true;
    final catLower = item.category.trim().toLowerCase();
    final selLower = selectedCat.trim().toLowerCase();
    if (catLower == selLower) return true;

    switch (selectedCat) {
      case 'Atta, Rice & Dal':
      case 'Staples & Grains':
        return catLower.contains('atta') ||
            catLower.contains('rice') ||
            catLower.contains('dal') ||
            catLower.contains('staple') ||
            catLower.contains('grain');
      case 'Oil, Ghee & Masala':
      case 'Oil':
      case 'Spices & Masalas':
        return catLower.contains('oil') ||
            catLower.contains('ghee') ||
            catLower.contains('spice') ||
            catLower.contains('masala');
      case 'Dairy, Bread & Eggs':
      case 'Dairy':
        return catLower.contains('dairy') ||
            catLower.contains('milk') ||
            catLower.contains('egg') ||
            catLower.contains('bread');
      case 'Dry Fruits & Cereals':
      case 'Groceries':
        return catLower.contains('dry fruit') ||
            catLower.contains('cereal') ||
            catLower == 'groceries';
      case 'Chips & Namkeen':
      case 'Snacks & Munchies':
      case 'Snacks & Drinks':
        return catLower.contains('chip') ||
            catLower.contains('namkeen') ||
            catLower.contains('snack') ||
            catLower.contains('munch');
      case 'Drinks & Juices':
      case 'Beverages':
        return catLower.contains('drink') ||
            catLower.contains('juice') ||
            catLower.contains('beverage') ||
            catLower.contains('soda');
      case 'Tea & Coffee':
        return catLower.contains('tea') ||
            catLower.contains('coffee') ||
            catLower.contains('chai') ||
            (catLower.contains('beverage') &&
                (item.name.toLowerCase().contains('tea') ||
                    item.name.toLowerCase().contains('coffee')));
      case 'Instant Food':
        return catLower.contains('instant') ||
            catLower.contains('noodle') ||
            catLower.contains('pasta') ||
            catLower.contains('vermicelli');
      default:
        return catLower.contains(selLower);
    }
  }

  Future<void> _showQuickCategoryPicker(BuildContext context, Item item) async {
    AppHaptics.buttonClick();
    final categories = _dynamicGroceryCategories.where((c) => c != 'All').toList();
    if (!categories.contains('Vegetables')) categories.add('Vegetables');
    if (!categories.contains('Fruits')) categories.add('Fruits');

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.category_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assign Category',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          item.name,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (c, idx) {
                    final cat = categories[idx];
                    final isSelected = item.category.trim().toLowerCase() == cat.trim().toLowerCase();
                    final isMoveOut = cat == 'Vegetables' || cat == 'Fruits';

                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: isSelected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : null,
                      leading: Icon(
                        isMoveOut
                            ? Icons.eco_rounded
                            : Icons.shopping_bag_outlined,
                        color: isSelected
                            ? AppColors.primary
                            : (isMoveOut ? Colors.orange : AppColors.textSecondary),
                      ),
                      title: Text(
                        cat,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? AppColors.primary : null,
                        ),
                      ),
                      subtitle: isMoveOut
                          ? const Text('Move out of Groceries Hub into general produce',
                              style: TextStyle(fontSize: 10, color: Colors.orange))
                          : null,
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                          : null,
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await _updateItemCategory(item, cat);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateItemCategory(Item item, String newCategory) async {
    try {
      AppHaptics.buttonClick();
      final dao = ItemDao();
      final updatedItem = item.copyWith(category: newCategory);
      final repo = InventoryRepositoryImpl(dao);
      await repo.updateItem(updatedItem);
      ref.invalidate(inventoryProvider);
      ref.invalidate(groceryVariantsMapProvider);
      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          'Assigned "${item.name}" to "$newCategory"',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to update category: $e');
      }
    }
  }

  Future<void> _syncToCloud({bool showFeedback = true}) async {
    if (showFeedback) {
      AppHaptics.buttonClick();
      SnackbarHelper.showInfo(context, 'Syncing groceries & variants with cloud...');
    }
    try {
      final dao = ItemDao();
      await InventoryRepositoryImpl(dao).syncAllVariantsToSupabase();
      await CustomerOrderSyncService.instance.syncInventory();
      ref.invalidate(inventoryProvider);
      ref.invalidate(groceryVariantsMapProvider);
      if (mounted && showFeedback) {
        SnackbarHelper.showSuccess(context, 'Groceries & variants synced successfully!');
      }
    } catch (e) {
      if (mounted && showFeedback) {
        SnackbarHelper.showError(context, 'Sync error: $e');
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _spoilageQtyCon.dispose();
    _spoilageRemarksCon.dispose();
    _searchCon.dispose();
    super.dispose();
  }

  Future<void> _adjustStock(Item item, double change) async {
    AppHaptics.buttonClick();
    try {
      final dao = ItemDao();
      await dao.adjustStock(item.id, change);
      await dao.insertStockHistory(StockHistory(
        id: '',
        itemId: item.id,
        itemName: item.name,
        changeAmount: change,
        reason: 'manual',
        createdAt: DateTime.now(),
      ));
      ref.invalidate(inventoryProvider);
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Stock adjusted successfully');
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Failed: $e');
    }
  }

  Future<void> _logSpoilage() async {
    if (!_spoilageFormKey.currentState!.validate() ||
        _selectedSpoilageItem == null) {
      SnackbarHelper.showError(context, 'Please select an item and quantity');
      return;
    }

    setState(() => _submittingSpoilage = true);
    AppHaptics.buttonClick();

    try {
      final qty = double.tryParse(_spoilageQtyCon.text) ?? 0.0;
      final remarks = _spoilageRemarksCon.text.trim();
      final item = _selectedSpoilageItem!;
      final cost = item.costPrice > 0 ? item.costPrice : item.sellingPrice;
      final totalLoss = qty * cost;

      final dao = ItemDao();
      // 1. Deduct Stock
      await dao.adjustStock(item.id, -qty);

      // 2. Add Stock History
      await dao.insertStockHistory(StockHistory(
        id: '',
        itemId: item.id,
        itemName: item.name,
        changeAmount: -qty,
        reason: 'spoilage',
        createdAt: DateTime.now(),
      ));

      // 3. Log Spoilage Expense
      final expenseDao = ExpenseDao();
      final now = DateTime.now();
      await expenseDao.insertExpense(Expense(
        id: '',
        name: 'Spoiled Stock - ${item.name}',
        category: AppConstants.expSpoilageLoss,
        amount: totalLoss,
        date: now,
        notes: 'Deducted $qty ${item.unit} spoiled stock. Remarks: $remarks',
        paymentMethod: 'cash',
        createdAt: now,
        updatedAt: now,
      ));

      ref.invalidate(inventoryProvider);

      if (mounted) {
        final settingsVal = ref.read(settingsProvider).valueOrNull;
        final currency = settingsVal?.currency ?? '₹';
        SnackbarHelper.showSuccess(
          context,
          'Logged spoliage! Stock reduced by $qty and $currency${totalLoss.toStringAsFixed(2)} logged to Spoilage Expenses.',
        );
        setState(() {
          _selectedSpoilageItem = null;
          _spoilageQtyCon.clear();
          _spoilageRemarksCon.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed logging spoilage: $e');
      }
    } finally {
      if (mounted) setState(() => _submittingSpoilage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryProvider);
    final isWorker = ref.watch(appModeProvider).value == AppMode.worker;
    final groceriesStatusAsync = ref.watch(groceriesStatusProvider);
    final bool isGroceriesOpen = groceriesStatusAsync.valueOrNull ?? true;
    final variantsMapAsync = ref.watch(groceryVariantsMapProvider);
    final variantsMap = variantsMapAsync.valueOrNull ?? {};
    final settingsVal = ref.watch(settingsProvider).valueOrNull;
    final currency = settingsVal?.currency ?? '₹';

    return AppScaffold(
      title: 'Groceries Hub',
      actions: [
        IconButton(
          icon: const Icon(Icons.cloud_sync_rounded),
          tooltip: 'Sync Groceries & Variants to Cloud',
          onPressed: () => _syncToCloud(showFeedback: true),
        ),
        IconButton(
          icon: const Icon(Icons.category_rounded),
          tooltip: 'Manage Categories',
          onPressed: () => _showCategoryManager(context),
        ),
        if (!isWorker)
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Add Grocery Item',
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRoutes.addEditItem,
                arguments: {
                  'initialCategory': _selectedCategory != 'All'
                      ? _selectedCategory
                      : AppConstants.catAttaRiceDal,
                },
              ).then((_) {
                ref.invalidate(inventoryProvider);
                ref.invalidate(groceryVariantsMapProvider);
              });
            },
          ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.transparent,
        indicator: AppColors.tabDecoration(context),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: const [
          Tab(
              icon: Icon(Icons.shopping_basket_rounded),
              text: 'Catalog & Stock'),
          Tab(icon: Icon(Icons.timer_rounded), text: 'Freshness Radar'),
          Tab(
              icon: Icon(Icons.report_gmailerrorred_rounded),
              text: 'Spoilage Logger'),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allItems) {
          final groceries = allItems
              .where((i) => CatalogClassifier.isGroceryItem(i))
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildStockTab(groceries, isWorker, isGroceriesOpen, variantsMap, currency),
              _buildFreshnessTab(groceries),
              _buildSpoilageTab(groceries),
            ],
          );
        },
      ),
    );
  }

  void _showCategoryManager(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryManagerSheet(onUpdated: () {
        ref.invalidate(inventoryProvider);
      }),
    );
  }

  Widget _buildStockTab(List<Item> items, bool isWorker, bool isGroceriesOpen,
      Map<String, List<ItemVariant>> variantsMap, String currency) {
    final filteredItems = items.where((item) {
      if (_selectedCategory != 'All' &&
          !_matchesGroceryCategory(item, _selectedCategory)) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = item.name.toLowerCase().contains(query);
        final catMatch = item.category.toLowerCase().contains(query);
        final barcodeMatch = item.barcode.toLowerCase().contains(query);
        if (!nameMatch && !catMatch && !barcodeMatch) return false;
      }
      return true;
    }).toList();

    int getCategoryCount(String category) {
      if (category == 'All') return items.length;
      return items.where((i) => _matchesGroceryCategory(i, category)).length;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Groceries Status Card (🟢 OPEN / 🔴 CLOSED)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isGroceriesOpen
                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                : const Color(0xFFEF4444).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isGroceriesOpen
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isGroceriesOpen
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGroceriesOpen
                      ? Icons.storefront_rounded
                      : Icons.store_mall_directory_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'GROCERIES: ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isGroceriesOpen
                                ? const Color(0xFF047857)
                                : const Color(0xFFB91C1C),
                          ),
                        ),
                        Text(
                          isGroceriesOpen ? '🟢 OPEN' : '🔴 CLOSED',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isGroceriesOpen
                                ? const Color(0xFF047857)
                                : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isGroceriesOpen
                          ? 'Visible in Customer App navigation dock'
                          : 'Hidden in Customer App & checkout blocked',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isGroceriesOpen,
                activeColor: const Color(0xFF10B981),
                inactiveThumbColor: const Color(0xFFEF4444),
                onChanged: isWorker
                    ? null
                    : (val) async {
                        AppHaptics.buttonClick();
                        await ref
                            .read(settingsProvider.notifier)
                            .setGroceriesStatus(val);
                        if (context.mounted) {
                          SnackbarHelper.showSuccess(
                            context,
                            val
                                ? 'Groceries is now OPEN. Tab visible in customer app!'
                                : 'Groceries is now CLOSED. Tab hidden from customer app!',
                          );
                        }
                      },
              ),
            ],
          ),
        ),

        // 2. Search Box
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: TextField(
            controller: _searchCon,
            decoration: InputDecoration(
              hintText: 'Search groceries by name or barcode...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchCon.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
          ),
        ),

        // 3. Category Horizontal Filter Strip with Badges
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _dynamicGroceryCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final cat = _dynamicGroceryCategories[idx];
              final isSelected = _selectedCategory == cat;
              final count = getCategoryCount(cat);

              return FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                selectedColor: AppColors.primary,
                backgroundColor: Theme.of(context).cardColor,
                checkmarkColor: Colors.white,
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(context).dividerColor.withValues(alpha: 0.15),
                  ),
                ),
                onSelected: (_) {
                  AppHaptics.buttonClick();
                  setState(() {
                    _selectedCategory = cat;
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: EmptyStateWidget(
              icon: Icons.shopping_basket_outlined,
              title: 'No Groceries Listed',
              subtitle: 'Tap the + button above to add grocery items',
            ),
          )
        else if (filteredItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.filter_alt_off_rounded, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No items found in "$_selectedCategory"',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No items match "$_searchQuery"'
                      : 'Assign items to this category or add new ones',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Show All Groceries'),
                  onPressed: () {
                    setState(() {
                      _selectedCategory = 'All';
                      _searchCon.clear();
                      _searchQuery = '';
                    });
                  },
                ),
              ],
            ),
          )
        else
          ...filteredItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLow = item.isLowStock;
            final variants = variantsMap[item.id] ?? [];

            return Dismissible(
              key: ValueKey(item.id),
              direction: isWorker
                  ? DismissDirection.none
                  : DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_forever_rounded,
                    color: Colors.white, size: 28),
              ),
              confirmDismiss: (_) => _confirmDeleteItem(item),
              onDismissed: (_) => _deleteItem(item),
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: isWorker
                      ? null
                      : () {
                          Navigator.of(context)
                              .pushNamed(AppRoutes.addEditItem,
                                  arguments: {'itemId': item.id})
                              .then((_) {
                            ref.invalidate(inventoryProvider);
                            ref.invalidate(groceryVariantsMapProvider);
                          });
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Product Header Row ──
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Category Pill Badge (1-tap switcher)
                                  InkWell(
                                    onTap: isWorker
                                        ? null
                                        : () => _showQuickCategoryPicker(context, item),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.25),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.category_outlined,
                                              size: 12,
                                              color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              item.category.isNotEmpty
                                                  ? item.category
                                                  : 'Uncategorized',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (!isWorker) ...[
                                            const SizedBox(width: 3),
                                            const Icon(
                                                Icons.arrow_drop_down_rounded,
                                                size: 14,
                                                color: AppColors.primary),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  // Price row
                                  Row(
                                    children: [
                                      Text(
                                        '$currency${item.sellingPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      if (item.costPrice > 0) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          'Cost: $currency${item.costPrice.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Stock + Expiry badges
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isLow
                                              ? AppColors.errorSurface
                                              : AppColors.successSurface,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Stock: ${item.stock} ${item.unit}',
                                          style: TextStyle(
                                            color: isLow
                                                ? AppColors.error
                                                : AppColors.success,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (item.bestBefore.isNotEmpty)
                                        Flexible(
                                          child: Text(
                                            'Expiry: ${item.bestBefore}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppColors.textSecondary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // ── Actions Column ──
                            Column(
                              children: [
                                // Overflow menu
                                if (!isWorker)
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded,
                                        size: 20),
                                    padding: EdgeInsets.zero,
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        Navigator.of(context)
                                            .pushNamed(AppRoutes.addEditItem,
                                                arguments: {'itemId': item.id})
                                            .then((_) {
                                          ref.invalidate(inventoryProvider);
                                          ref.invalidate(
                                              groceryVariantsMapProvider);
                                        });
                                      } else if (val == 'category') {
                                        _showQuickCategoryPicker(context, item);
                                      } else if (val == 'delete') {
                                        _confirmDeleteItem(item).then((ok) {
                                          if (ok == true) _deleteItem(item);
                                        });
                                      } else if (val == 'variant') {
                                        _showVariantEditor(item, null);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_rounded, size: 18),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'category',
                                        child: Row(
                                          children: [
                                            Icon(Icons.category_rounded,
                                                size: 18),
                                            SizedBox(width: 8),
                                            Text('Change Category'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'variant',
                                        child: Row(
                                          children: [
                                            Icon(Icons.add_box_rounded,
                                                size: 18),
                                            SizedBox(width: 8),
                                            Text('Add Variant'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_rounded,
                                                size: 18,
                                                color: AppColors.error),
                                            SizedBox(width: 8),
                                            Text('Delete',
                                                style: TextStyle(
                                                    color: AppColors.error)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                // Stock Adjust Buttons
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton.filledTonal(
                                      icon: const Icon(Icons.remove_rounded,
                                          size: 18),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: item.stock <= 0
                                          ? null
                                          : () => _adjustStock(
                                              item,
                                              item.stock < 1
                                                  ? -item.stock
                                                  : -1),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton.filledTonal(
                                      icon: const Icon(Icons.add_rounded,
                                          size: 18),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () =>
                                          _adjustStock(item, 1),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),

                        // ── Variants Box ──
                        if (variants.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.inventory_2_rounded,
                                        size: 14,
                                        color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'VARIANTS',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${variants.length} version${variants.length > 1 ? 's' : ''}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...variants.map((v) {
                                  final hasSavings = v.marketPrice > v.sellingPrice && v.sellingPrice > 0;
                                  final savingsPct = hasSavings ? (((v.marketPrice - v.sellingPrice) / v.marketPrice) * 100).round() : 0;
                                  final bool isOutOfStock = v.stock <= 0;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: InkWell(
                                      onTap: isWorker ? null : () => _showVariantEditor(item, v),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isOutOfStock
                                                ? Colors.red.withValues(alpha: 0.3)
                                                : Colors.grey.withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            // 1. Separate Sub-Product Photo
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.grey.withValues(alpha: 0.2),
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(7),
                                                child: v.photoPath.isNotEmpty
                                                    ? (v.photoPath.startsWith('http')
                                                        ? AppCachedImage(
                                                            imageUrl: v.photoPath,
                                                            fit: BoxFit.cover,
                                                            width: 44,
                                                            height: 44,
                                                            errorWidget: const Icon(Icons.inventory_2_outlined, size: 22, color: AppColors.primary),
                                                          )
                                                        : Image.file(
                                                            File(v.photoPath),
                                                            fit: BoxFit.cover,
                                                            width: 44,
                                                            height: 44,
                                                            errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined, size: 22, color: AppColors.primary),
                                                          ))
                                                    : const Icon(Icons.inventory_2_outlined, size: 22, color: AppColors.primary),
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            // 2. Separate Name, Price, MRP, Stock & Unit
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    v.variantLabel,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '$currency${v.sellingPrice.toStringAsFixed(v.sellingPrice.truncateToDouble() == v.sellingPrice ? 0 : 2)}',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.primary,
                                                        ),
                                                      ),
                                                      if (hasSavings) ...[
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '$currency${v.marketPrice.toStringAsFixed(v.marketPrice.truncateToDouble() == v.marketPrice ? 0 : 2)}',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            decoration: TextDecoration.lineThrough,
                                                            color: Colors.grey[500],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: Colors.green.withValues(alpha: 0.12),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            '$savingsPct% off',
                                                            style: const TextStyle(
                                                              fontSize: 9.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.green,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Wrap(
                                                    spacing: 6,
                                                    children: [
                                                      Text(
                                                        'Stock: ${v.stock % 1 == 0 ? v.stock.toInt() : v.stock} ${v.unit}',
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.w600,
                                                          color: isOutOfStock ? Colors.red : Colors.grey[700],
                                                        ),
                                                      ),
                                                      if (v.costPrice > 0)
                                                        Text(
                                                          '• Cost: $currency${v.costPrice.toStringAsFixed(v.costPrice.truncateToDouble() == v.costPrice ? 0 : 2)}',
                                                          style: TextStyle(
                                                            fontSize: 10.5,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // 3. Variant stock buttons & Delete
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 28,
                                                  height: 28,
                                                  child: IconButton(
                                                    icon: const Icon(Icons.remove_rounded, size: 14),
                                                    padding: EdgeInsets.zero,
                                                    onPressed: v.stock <= 0
                                                        ? null
                                                        : () => _adjustVariantStock(v, -1),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 28,
                                                  height: 28,
                                                  child: IconButton(
                                                    icon: const Icon(Icons.add_rounded, size: 14),
                                                    padding: EdgeInsets.zero,
                                                    onPressed: () => _adjustVariantStock(v, 1),
                                                  ),
                                                ),
                                                if (!isWorker)
                                                  SizedBox(
                                                    width: 28,
                                                    height: 28,
                                                    child: IconButton(
                                                      icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.error),
                                                      padding: EdgeInsets.zero,
                                                      onPressed: () => _deleteVariant(v),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                // Add Variant button
                                if (!isWorker)
                                  InkWell(
                                    onTap: () =>
                                        _showVariantEditor(item, null),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.3),
                                          style: BorderStyle.solid,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_rounded,
                                              size: 16,
                                              color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Add Variant',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ] else if (!isWorker) ...[
                          // Show a subtle add-variant link when no variants yet
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _showVariantEditor(item, null),
                            child: Row(
                              children: [
                                Icon(Icons.add_box_outlined,
                                    size: 14,
                                    color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  'Add sub-product / variant',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: -0.05, end: 0);
          }),
      ],
    );
  }

  // ── CRUD Helpers ──────────────────────────────────────────────────────────

  Future<bool?> _confirmDeleteItem(Item item) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
            'Delete "${item.name}" and all its variants? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(Item item) async {
    try {
      final notifier = ref.read(inventoryProvider.notifier);
      await notifier.deleteItem(item.id);
      // Variants deleted via ON DELETE CASCADE
      ref.invalidate(groceryVariantsMapProvider);
      if (mounted) {
        SnackbarHelper.showSuccess(context, '${item.name} deleted');
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Delete failed: $e');
    }
  }

  void _showVariantEditor(Item parentItem, ItemVariant? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VariantEditorSheet(
        parentItemId: parentItem.id,
        parentItemName: parentItem.name,
        existingVariant: existing,
        onSaved: () {
          ref.invalidate(groceryVariantsMapProvider);
        },
      ),
    );
  }

  Future<void> _adjustVariantStock(ItemVariant v, double change) async {
    AppHaptics.buttonClick();
    try {
      final dao = ItemDao();
      await dao.adjustVariantStock(v.id, change);
      ref.invalidate(groceryVariantsMapProvider);
      // Sync to Supabase in background
      InventoryRepositoryImpl(dao).syncItemVariantsToSupabase(v.parentItemId);
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Failed: $e');
    }
  }

  Future<void> _deleteVariant(ItemVariant v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Variant'),
        content: Text('Delete variant "${v.variantLabel}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final dao = ItemDao();
      await dao.deleteVariant(v.id);
      ref.invalidate(groceryVariantsMapProvider);
      // Sync to Supabase
      await InventoryRepositoryImpl(dao).syncItemVariantsToSupabase(v.parentItemId);
      if (mounted) SnackbarHelper.showSuccess(context, 'Variant deleted');
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Failed: $e');
    }
  }

  Widget _buildFreshnessTab(List<Item> items) {
    final datedItems = items.where((i) => i.bestBefore.isNotEmpty).toList();

    if (datedItems.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.health_and_safety_outlined,
        title: 'No Dated Items',
        subtitle:
            'Configure pack/best-before dates in inventory editing screen',
      );
    }

    // Sort by best before date ascending
    datedItems.sort((a, b) => a.bestBefore.compareTo(b.bestBefore));

    final now = DateTime.now().toIso8601String().substring(0, 10);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: datedItems.length,
      itemBuilder: (context, index) {
        final item = datedItems[index];
        final isExpired = item.bestBefore.compareTo(now) < 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isExpired
                  ? AppColors.error.withOpacity(0.5)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isExpired ? AppColors.errorSurface : AppColors.successSurface,
              child: Icon(
                isExpired
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                color: isExpired ? AppColors.error : AppColors.success,
              ),
            ),
            title: Text(item.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                'Best Before: ${item.bestBefore} • Pack Date: ${item.packDate.isNotEmpty ? item.packDate : "N/A"}'),
            trailing: isExpired
                ? const Text(
                    'EXPIRED',
                    style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  )
                : const Text(
                    'FRESH',
                    style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  ),
          ),
        ).animate().fadeIn(delay: (index * 50).ms);
      },
    );
  }

  Widget _buildSpoilageTab(List<Item> items) {
    if (items.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.remove_shopping_cart_outlined,
        title: 'No Grocery Items',
        subtitle: 'Create items in inventory first',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _spoilageFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report Spoiled or Damaged Groceries',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reducing stock will automatically deduct grocery quantities and record the loss value under APMC/Spoilage expenses.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // Dropdown selection
            DropdownButtonFormField<Item>(
              value: _selectedSpoilageItem,
              decoration: const InputDecoration(
                labelText: 'Select Grocery Item',
                prefixIcon: Icon(Icons.shopping_bag_rounded),
              ),
              items: items.map((i) {
                return DropdownMenuItem<Item>(
                  value: i,
                  child: Text('${i.name} (Stock: ${i.stock} ${i.unit})'),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedSpoilageItem = val);
              },
              validator: (v) => v == null ? 'Please select an item' : null,
            ),
            const SizedBox(height: 16),

            // Quantity Field
            TextFormField(
              controller: _spoilageQtyCon,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Spoiled Quantity',
                prefixIcon: Icon(Icons.scale_rounded),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter quantity';
                final numVal = double.tryParse(v);
                if (numVal == null || numVal <= 0) {
                  return 'Enter a positive quantity';
                }
                if (_selectedSpoilageItem != null &&
                    numVal > _selectedSpoilageItem!.stock) {
                  return 'Cannot exceed current stock (${_selectedSpoilageItem!.stock})';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Remarks Field
            TextFormField(
              controller: _spoilageRemarksCon,
              decoration: const InputDecoration(
                labelText: 'Remarks / Reason (e.g. Broken package, rot)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter remarks' : null,
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submittingSpoilage ? null : _logSpoilage,
                icon: _submittingSpoilage
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Confirm Spoilage & Log Expense'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryManagerSheet extends StatefulWidget {
  final VoidCallback onUpdated;
  const _CategoryManagerSheet({required this.onUpdated});

  @override
  State<_CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<_CategoryManagerSheet> {
  final _catCon = TextEditingController();
  bool _loading = true;
  bool _adding = false;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _catCon.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await Supabase.instance.client
          .from('categories')
          .select('id, name, is_enabled')
          .order('name');
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(res as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        SnackbarHelper.showError(context, 'Failed to load categories: $e');
      }
    }
  }

  Future<void> _addCategory() async {
    final name = _catCon.text.trim();
    if (name.isEmpty) return;
    setState(() => _adding = true);
    try {
      await Supabase.instance.client.from('categories').insert({
        'name': name,
        'is_enabled': true,
      });
      _catCon.clear();
      widget.onUpdated();
      await _loadCategories();
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Category "$name" added');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to add category: $e');
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _toggleCategory(String id, bool currentStatus) async {
    try {
      await Supabase.instance.client
          .from('categories')
          .update({'is_enabled': !currentStatus})
          .eq('id', id);
      widget.onUpdated();
      await _loadCategories();
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to update category: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.category_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Manage Grocery Categories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _catCon,
                  decoration: InputDecoration(
                    hintText: 'New category name (e.g. Dairy)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _addCategory(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _adding ? null : _addCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: _adding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          Flexible(
            child: _loading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ))
                : _categories.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('No categories found', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final cat = _categories[i];
                          final id = cat['id']?.toString() ?? '';
                          final name = cat['name']?.toString() ?? '';
                          final isEnabled = cat['is_enabled'] != false;
                          final isVeg = name.toLowerCase() == 'vegetables';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primarySurface,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: isEnabled ? null : TextDecoration.lineThrough,
                                color: isEnabled ? null : AppColors.textSecondary,
                              ),
                            ),
                            subtitle: isVeg ? const Text('Default core category', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)) : null,
                            trailing: isVeg
                                ? const Chip(
                                    label: Text('System', style: TextStyle(fontSize: 11)),
                                    padding: EdgeInsets.zero,
                                  )
                                : Switch(
                                    value: isEnabled,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) => _toggleCategory(id, isEnabled),
                                  ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
