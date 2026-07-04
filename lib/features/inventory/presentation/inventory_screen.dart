import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../domain/item.dart';
import 'inventory_provider.dart';
import '../data/item_dao.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  final bool showBack;
  const InventoryScreen({super.key, this.showBack = true});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _category = 'All';
  final _categories = ['All', ...AppConstants.itemCategories];
  DateTime _selectedHistoryDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryProvider);

    return AppScaffold(
      title: 'Inventory & Prices',
      showBack: widget.showBack,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort_rounded),
          onSelected: (v) => ref.read(inventoryProvider.notifier).sort(v),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'name',       child: Text('Sort by Name')),
            const PopupMenuItem(value: 'stock_asc',  child: Text('Sort by Stock (Low first)')),
            const PopupMenuItem(value: 'price_desc', child: Text('Sort by Price')),
            const PopupMenuItem(value: 'category',   child: Text('Sort by Category')),
          ],
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: const [
          Tab(icon: Icon(Icons.inventory_2_rounded), text: 'Stock Items'),
          Tab(icon: Icon(Icons.price_change_rounded), text: 'Market Savings'),
          Tab(icon: Icon(Icons.history_rounded), text: 'Price History'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_item',
        onPressed: () => Navigator.of(context)
            .pushNamed(AppRoutes.addEditItem)
            .then((_) => ref.refresh(inventoryProvider)),
        child: const Icon(Icons.add_rounded),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TAB 1: Stock Items List ────────────────────────────────────────
          _buildStockTab(context, itemsAsync),

          // ── TAB 2: Market Price & Customer Savings Calculator ──────────────
          _buildMarketSavingsTab(context, itemsAsync),

          // ── TAB 3: Daily Price History Tracker (Date-to-Date) ─────────────
          _buildPriceHistoryTab(context),
        ],
      ),
    );
  }

  // ── TAB 1: Stock List ──────────────────────────────────────────────────────
  Widget _buildStockTab(BuildContext context, AsyncValue<List<Item>> itemsAsync) {
    return Column(
      children: [
        CustomSearchBar(
          hint: 'Search items...',
          onChanged: (q) => ref.read(inventoryProvider.notifier).search(q),
        ),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final selected = cat == _category;
              return GestureDetector(
                onTap: () {
                  setState(() => _category = cat);
                  ref.read(inventoryProvider.notifier)
                      .filterByCategory(cat == 'All' ? '' : cat);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.gray100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimary,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: itemsAsync.when(
            loading: () => const LoadingShimmer(),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) {
              if (items.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.inventory_2_outlined,
                  title: 'No Items Found',
                  subtitle: 'Tap + to add your first inventory item',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.refresh(inventoryProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _ItemTile(
                    item: items[i],
                    onEdit: () => Navigator.of(context)
                        .pushNamed(AppRoutes.addEditItem, arguments: {'itemId': items[i].id})
                        .then((_) => ref.refresh(inventoryProvider)),
                    onAdjustStock: () => _showStockAdjustDialog(context, items[i]),
                    onDelete: () => _confirmDelete(context, items[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── TAB 2: Market Price & Customer Savings Calculator ──────────────────────
  Widget _buildMarketSavingsTab(BuildContext context, AsyncValue<List<Item>> itemsAsync) {
    return itemsAsync.when(
      loading: () => const LoadingShimmer(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        double totalMarketVal = 0;
        double totalOurVal = 0;
        int itemsWithSavings = 0;

        for (final item in items) {
          if (item.marketPrice > 0) {
            totalMarketVal += item.marketPrice;
            totalOurVal += item.sellingPrice;
            if (item.customerSavings > 0) itemsWithSavings++;
          }
        }

        final totalSavings = totalMarketVal - totalOurVal;
        final overallSavingsPct = totalMarketVal > 0 ? (totalSavings / totalMarketVal) * 100 : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Savings Summary Executive Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.savings_rounded, color: Colors.white, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'CUSTOMER SAVINGS CALCULATOR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Customers Save ~${overallSavingsPct.toStringAsFixed(1)}% vs Market',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Based on $itemsWithSavings items with comparison market rates set.',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Text(
                'Market Price vs Our Store Price',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  final savings = item.customerSavings;
                  final hasSavings = savings > 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: hasSavings ? Colors.green.withOpacity(0.3) : AppColors.gray200),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'MRP: ${AppFormatters.currency(item.marketPrice > 0 ? item.marketPrice : item.sellingPrice)}/${item.unit}',
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Our Price: ${AppFormatters.currency(item.sellingPrice)}/${item.unit}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (hasSavings)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'SAVE ${AppFormatters.currency(savings)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '(${item.customerSavingsPct.toStringAsFixed(0)}% OFF)',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── TAB 3: Daily Price History Tracker (Date-to-Date) ──────────────────────
  Widget _buildPriceHistoryTab(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedHistoryDate);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Selector Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gray200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HISTORICAL PRICE TRACKER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      AppFormatters.date(_selectedHistoryDate),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedHistoryDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _selectedHistoryDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text('Pick Date'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Fetch historical price log for selected date
          FutureBuilder<List<Map<String, dynamic>>>(
            future: ItemDao().getPriceHistoryByDate(dateStr),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingShimmer(count: 3);
              }
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(Icons.history_toggle_off_rounded, size: 48, color: AppColors.gray400),
                        const SizedBox(height: 8),
                        Text(
                          'No Price Snapshot on ${AppFormatters.date(_selectedHistoryDate)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Daily prices are recorded automatically whenever items or rates are updated.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final row = list[i];
                  final name = row['name'] as String? ?? 'Item';
                  final unit = row['unit'] as String? ?? '';
                  final sellPrice = (row['selling_price'] as num?)?.toDouble() ?? 0.0;
                  final mktPrice = (row['market_price'] as num?)?.toDouble() ?? 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Row(
                          children: [
                            if (mktPrice > 0)
                              Text(
                                'MRP: ${AppFormatters.currency(mktPrice)} ',
                                style: const TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: AppColors.textSecondary),
                              ),
                            Text(
                              '${AppFormatters.currency(sellPrice)} / $unit',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showStockAdjustDialog(BuildContext context, Item item) {
    final qtyCon = TextEditingController();
    bool isAdd = true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('Adjust Stock — ${item.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current stock: ${AppFormatters.quantity(item.stock, unit: item.unit)}'),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('+ Add Stock')),
                  ButtonSegment(value: false, label: Text('- Reduce Stock')),
                ],
                selected: {isAdd},
                onSelectionChanged: (s) => setStateDialog(() => isAdd = s.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyCon,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Quantity'),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCon.text.trim());
                if (qty == null || qty <= 0) return;
                final change = isAdd ? qty : -qty;
                await ref.read(inventoryProvider.notifier).adjustStock(
                  item.id,
                  change,
                  isAdd ? 'Stock added' : 'Stock reduced',
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Item item) {
    ConfirmDeleteDialog.show(
      context,
      title: 'Delete Item',
      message: 'Are you sure you want to delete "${item.name}"?',
    ).then((confirmed) {
      if (confirmed) {
        ref.read(inventoryProvider.notifier).deleteItem(item.id);
        SnackbarHelper.showSuccess(context, 'Item deleted');
      }
    });
  }
}

class _ItemTile extends StatelessWidget {
  final Item item;
  final VoidCallback onEdit;
  final VoidCallback onAdjustStock;
  final VoidCallback onDelete;

  const _ItemTile({
    required this.item,
    required this.onEdit,
    required this.onAdjustStock,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isLowStock ? AppColors.error : AppColors.gray200,
          width: item.isLowStock ? 1.5 : 1,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            if (item.isLowStock)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'LOW STOCK',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Price: ${AppFormatters.currency(item.sellingPrice)} / ${item.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
                if (item.marketPrice > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    'MRP: ${AppFormatters.currency(item.marketPrice)}',
                    style: const TextStyle(
                      fontSize: 11,
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            Text(
              'Stock: ${AppFormatters.quantity(item.stock, unit: item.unit)}',
              style: TextStyle(
                color: item.isLowStock ? AppColors.error : AppColors.textSecondary,
                fontWeight: item.isLowStock ? FontWeight.w800 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'stock') onAdjustStock();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Edit Item')])),
            const PopupMenuItem(value: 'stock', child: Row(children: [Icon(Icons.swap_vert_rounded, size: 18), SizedBox(width: 8), Text('Adjust Stock')])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppColors.error))])),
          ],
        ),
      ),
    );
  }
}
