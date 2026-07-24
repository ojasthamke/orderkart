import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/security/app_mode_service.dart';
import '../domain/item.dart';
import '../domain/stock_history.dart';
import '../data/item_dao.dart';
import 'inventory_provider.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../expense/domain/expense.dart';
import '../../expense/data/expense_dao.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _spoilageQtyCon.dispose();
    _spoilageRemarksCon.dispose();
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
      if (mounted)
        SnackbarHelper.showError(context, 'Failed logging spoilage: $e');
    } finally {
      if (mounted) setState(() => _submittingSpoilage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryProvider);
    final isWorker = ref.watch(appModeProvider).value == AppMode.worker;

    return AppScaffold(
      title: 'Groceries Hub',
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.transparent,
        indicator: AppColors.tabDecoration(context),
        labelColor: AppColors.primary,
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
              .where((i) => i.category == AppConstants.catGroceries)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildStockTab(groceries, isWorker),
              _buildFreshnessTab(groceries),
              _buildSpoilageTab(groceries),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStockTab(List<Item> items, bool isWorker) {
    if (items.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.shopping_basket_outlined,
        title: 'No Groceries Listed',
        subtitle: 'Add grocery items in the main Inventory screen',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isLow = item.isLowStock;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLow
                                  ? AppColors.errorSurface
                                  : AppColors.successSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Stock: ${item.stock} ${item.unit}',
                              style: TextStyle(
                                color:
                                    isLow ? AppColors.error : AppColors.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (item.bestBefore.isNotEmpty)
                            Text(
                              'Expiry: ${item.bestBefore}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Stock Adjust Actions
                Row(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.remove_rounded),
                      onPressed: item.stock < 0.001
                          ? null
                          : () => _adjustStock(item, -1),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => _adjustStock(item, 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: -0.05, end: 0);
      },
    );
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
                if (numVal == null || numVal <= 0)
                  return 'Enter a positive quantity';
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
