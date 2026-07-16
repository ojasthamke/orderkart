import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/package_exporter.dart';
import '../../../core/services/package_validator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/security/app_mode_service.dart';
import '../domain/item.dart';
import 'inventory_provider.dart';
import '../data/item_dao.dart';
import '../../expense/domain/expense.dart';
import '../../expense/data/expense_dao.dart';

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
  final DateTime _selectedHistoryDate = DateTime.now();
  DateTimeRange? _priceHistoryRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleEditItem(Item item) async {
    if (mounted) {
      Navigator.of(context)
          .pushNamed(AppRoutes.addEditItem, arguments: {'itemId': item.id})
          .then((_) => ref.refresh(inventoryProvider));
    }
  }

  void _handleStockAdjust(Item item) {
    if (mounted) _showStockAdjustDialog(context, item);
  }

  Future<void> _exportPriceList() async {
    AppHaptics.buttonClick();
    try {
      await PackageExporter.exportPackage(
        selectedModules: ['items', 'prices', 'entire_db'],
      );
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Official Stock & Price List exported successfully!');
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Export failed: $e');
    }
  }

  Future<void> _importOwnerPriceList() async {
    AppHaptics.buttonClick();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result == null) return;
      final filePath = result.files.single.path;
      if (filePath == null) return;
      final validation = await PackageValidator.validatePackage(filePath);
      if (!validation.isValid) {
        if (mounted) SnackbarHelper.showError(context, 'Invalid Package: ${validation.errorMessage}');
        return;
      }

      final extractedDbPath = validation.dbPath;
      if (extractedDbPath.isEmpty || !File(extractedDbPath).existsSync()) {
        if (mounted) SnackbarHelper.showError(context, 'No database found in package');
        return;
      }

      await DatabaseHelper.instance.mergeDatabaseFromPath(
        extractedDbPath,
        selectedModules: ['items', 'prices'],
      );

      ref.invalidate(inventoryProvider);
      if (mounted) {
        SnackbarHelper.showSuccess(context, '✅ Official Owner Stock & Price List updated!');
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Price List import failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryProvider);
    final isWorker = ref.watch(appModeProvider).value == AppMode.worker;

    return AppScaffold(
      title: 'Inventory & Prices',
      showBack: widget.showBack,
      actions: [
        if (!isWorker)
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Export Stock & Price List (Owner)',
            onPressed: _exportPriceList,
          ),
        IconButton(
          icon: const Icon(Icons.download_rounded),
          tooltip: 'Import Stock & Price List (Worker)',
          onPressed: _importOwnerPriceList,
        ),
        IconButton(
          icon: const Icon(Icons.shuffle_rounded),
          tooltip: 'Shuffle Items',
          onPressed: () {
            AppHaptics.buttonClick();
            ref.read(inventoryProvider.notifier).sort('shuffle');
            SnackbarHelper.showSuccess(context, 'Inventory items shuffled!');
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort_rounded),
          onSelected: (v) => ref.read(inventoryProvider.notifier).sort(v),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'name',       child: Text('Sort by Name')),
            const PopupMenuItem(value: 'stock_asc',  child: Text('Sort by Stock (Low first)')),
            const PopupMenuItem(value: 'price_desc', child: Text('Sort by Price')),
            const PopupMenuItem(value: 'category',   child: Text('Sort by Category')),
            const PopupMenuItem(value: 'shuffle',    child: Text('Shuffle / Randomize')),
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
          Tab(icon: Icon(Icons.delete_sweep_rounded), text: 'Spillage History'),
        ],
      ),
      floatingActionButton: isWorker
          ? null
          : FloatingActionButton(
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
          _buildStockTab(context, itemsAsync, isWorker),

          // ── TAB 2: Market Price & Customer Savings Calculator ──────────────
          _buildMarketSavingsTab(context, itemsAsync),

          // ── TAB 3: Daily Price History Tracker (Date-to-Date) ─────────────
          _buildPriceHistoryTab(context),

          // ── TAB 4: Spillage History Tracker ────────────────────────────────
          _buildSpillageHistoryTab(context),
        ],
      ),
    );
  }

  // ── TAB 1: Stock List ──────────────────────────────────────────────────────
  Widget _buildStockTab(BuildContext context, AsyncValue<List<Item>> itemsAsync, bool isWorker) {
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
                    color: selected
                        ? AppColors.primary
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white10
                            : Colors.black.withOpacity(0.04)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white12
                              : Colors.black12),
                    ),
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
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final list = List<Item>.from(items);
                    final dragged = list.removeAt(oldIndex);
                    list.insert(newIndex, dragged);
                    final ids = list.map((item) => item.id).toList();
                    await ref.read(inventoryProvider.notifier).reorderItems(ids);
                  },
                  itemBuilder: (_, i) => _ItemTile(
                    key: ValueKey(items[i].id),
                    item: items[i],
                    isWorker: isWorker,
                    onEdit: () => _handleEditItem(items[i]),
                    onAdjustStock: () => _handleStockAdjust(items[i]),
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
              GlassContainer(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFF059669).withOpacity(0.85),
                borderColor: const Color(0xFF10B981).withOpacity(0.4),
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

                  return GlassContainer(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    borderRadius: BorderRadius.circular(16),
                    borderColor: hasSavings ? Colors.green.withOpacity(0.5) : null,
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
    final hasRange = _priceHistoryRange != null;
    final startDateStr = hasRange
        ? DateFormat('yyyy-MM-dd').format(_priceHistoryRange!.start)
        : DateFormat('yyyy-MM-dd').format(_selectedHistoryDate);
    final endDateStr = hasRange
        ? DateFormat('yyyy-MM-dd').format(_priceHistoryRange!.end)
        : DateFormat('yyyy-MM-dd').format(_selectedHistoryDate);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Range & Single Date Selector Header Card
          GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('HISTORICAL PRICE LOG & REPORT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          hasRange
                              ? '${AppFormatters.date(_priceHistoryRange!.start)} - ${AppFormatters.date(_priceHistoryRange!.end)}'
                              : AppFormatters.date(_selectedHistoryDate),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        AppHaptics.buttonClick();
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: _priceHistoryRange ??
                              DateTimeRange(
                                start: DateTime.now().subtract(const Duration(days: 7)),
                                end: DateTime.now(),
                              ),
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _priceHistoryRange = picked);
                        }
                      },
                      icon: const Icon(Icons.date_range_rounded, size: 18),
                      label: Text(hasRange ? 'Change Range' : 'Pick Range'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (hasRange) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        AppHaptics.selection();
                        setState(() => _priceHistoryRange = null);
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset to Single Date'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Fetch historical price log & generate report
          FutureBuilder<List<Map<String, dynamic>>>(
            future: ItemDao().getPriceHistoryDateRange(startDateStr, endDateStr),
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
                          hasRange
                              ? 'No Price Snapshots in selected range (${AppFormatters.date(_priceHistoryRange!.start)} - ${AppFormatters.date(_priceHistoryRange!.end)})'
                              : 'No Price Snapshot on ${AppFormatters.date(_selectedHistoryDate)}',
                          textAlign: TextAlign.center,
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

              // On-Page Report Calculations
              double avgSelling = 0;
              double avgMarket = 0;
              final datesSet = <String>{};
              for (final row in list) {
                avgSelling += (row['selling_price'] as num?)?.toDouble() ?? 0;
                avgMarket += (row['market_price'] as num?)?.toDouble() ?? 0;
                datesSet.add(row['date'] as String? ?? '');
              }
              avgSelling = list.isNotEmpty ? avgSelling / list.length : 0;
              avgMarket = list.isNotEmpty ? avgMarket / list.length : 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // On-Page Price History Summary Report Panel
                  GlassContainer(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.primary.withOpacity(0.85),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'PRICE HISTORY REPORT (${datesSet.length} DAYS LOGGED)',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Avg Store Rate', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                Text(AppFormatters.currency(avgSelling), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Avg Market Rate', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                Text(AppFormatters.currency(avgMarket), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Snapshots', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                Text('${list.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Price Logs & History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final row = list[i];
                      final name = row['name'] as String? ?? 'Item';
                      final unit = row['unit'] as String? ?? '';
                      final dateVal = row['date'] as String? ?? '';
                      final sellPrice = (row['selling_price'] as num?)?.toDouble() ?? 0.0;
                      final mktPrice = (row['market_price'] as num?)?.toDouble() ?? 0.0;

                      return GlassContainer(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        borderRadius: BorderRadius.circular(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                Text(
                                  AppFormatters.dateFromString(dateVal),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
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
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showStockAdjustDialog(BuildContext context, Item item) {
    final qtyCon = TextEditingController();
    final reasonCon = TextEditingController();
    String mode = 'add'; // 'add', 'reduce', 'wastage'
    bool autoLogExpense = true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          final qtyVal = double.tryParse(qtyCon.text.trim()) ?? 0;
          final costLoss = qtyVal * item.sellingPrice;

          return AlertDialog(
            title: Text('Adjust Stock — ${item.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Stock: ${AppFormatters.quantity(item.stock, unit: item.unit)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  
                  // Mode Selector Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('+ Add Stock'),
                        selected: mode == 'add',
                        selectedColor: AppColors.success.withOpacity(0.2),
                        onSelected: (s) => setStateDialog(() => mode = 'add'),
                      ),
                      ChoiceChip(
                        label: const Text('- Reduce Stock'),
                        selected: mode == 'reduce',
                        selectedColor: AppColors.error.withOpacity(0.2),
                        onSelected: (s) => setStateDialog(() => mode = 'reduce'),
                      ),
                      ChoiceChip(
                        label: const Text('🍏 Wastage / Spoilage'),
                        selected: mode == 'wastage',
                        selectedColor: Colors.amber.withOpacity(0.3),
                        onSelected: (s) => setStateDialog(() => mode = 'wastage'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: qtyCon,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: mode == 'wastage' ? 'Wastage Quantity (${item.unit})' : 'Quantity (${item.unit})',
                      prefixIcon: Icon(
                        mode == 'add'
                            ? Icons.add_circle_outline_rounded
                            : (mode == 'wastage' ? Icons.delete_outline_rounded : Icons.remove_circle_outline_rounded),
                        color: mode == 'add' ? AppColors.success : (mode == 'wastage' ? Colors.amber.shade800 : AppColors.error),
                      ),
                    ),
                    autofocus: true,
                    onChanged: (_) => setStateDialog(() {}),
                  ),

                  if (mode == 'wastage') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonCon,
                      decoration: const InputDecoration(
                        labelText: 'Wastage Reason (Optional)',
                        hintText: 'e.g. Rotten mandi batch, Transport damage',
                        prefixIcon: Icon(Icons.note_alt_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Wastage Loss Summary Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Estimated Loss Value: ${AppFormatters.currency(costLoss)}',
                              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.amber.shade900, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-log Expense under 🍏 Spoilage & Damaged Goods', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      value: autoLogExpense,
                      onChanged: (v) => setStateDialog(() => autoLogExpense = v ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ],
              ),
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

                  AppHaptics.primarySave();

                  if (mode == 'wastage') {
                    final reason = reasonCon.text.trim().isEmpty ? 'Wastage / Spoilage loss' : reasonCon.text.trim();
                    await ref.read(inventoryProvider.notifier).adjustStock(
                      item.id,
                      -qty,
                      'Wastage: $reason',
                    );

                    if (autoLogExpense && costLoss > 0) {
                      await ExpenseDao().insertExpense(
                        Expense(
                          id: '',
                          name: 'Wastage: ${item.name} (${AppFormatters.quantity(qty, unit: item.unit)})',
                          category: AppConstants.expSpoilageLoss,
                          amount: costLoss,
                          date: DateTime.now(),
                          notes: 'Item wastage recorded: $reason',
                          paymentMethod: 'cash',
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                      );
                    }
                    if (ctx.mounted) {
                      SnackbarHelper.showSuccess(context, 'Recorded ${AppFormatters.quantity(qty, unit: item.unit)} wastage for ${item.name}');
                      Navigator.pop(ctx);
                    }
                  } else {
                    final isAddMode = mode == 'add';
                    final change = isAddMode ? qty : -qty;
                    await ref.read(inventoryProvider.notifier).adjustStock(
                      item.id,
                      change,
                      isAddMode ? 'Stock added' : 'Stock reduced',
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
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

  Widget _buildSpillageHistoryTab(BuildContext context) {
    final spillageAsync = ref.watch(spillageHistoryProvider);

    return spillageAsync.when(
      loading: () => const LoadingShimmer(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (logs) {
        if (logs.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.delete_sweep_outlined,
            title: 'No Spillage Logged',
            subtitle: 'Wastage logs will appear here after recording',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(spillageHistoryProvider),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final formattedDate = AppFormatters.dateTime(log.createdAt);
              final amt = log.changeAmount.abs();

              String cleanReason = log.reason;
              if (cleanReason.startsWith('Wastage: ')) {
                cleanReason = cleanReason.replaceFirst('Wastage: ', '');
              }

              return GlassContainer(
                margin: const EdgeInsets.only(bottom: 8),
                borderRadius: BorderRadius.circular(12),
                borderColor: Colors.amber.withOpacity(0.4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.amber.withOpacity(0.2),
                    child: Icon(Icons.delete_outline_rounded, color: Colors.amber.shade800),
                  ),
                  title: Text(
                    log.itemName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        cleanReason,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedDate,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                      ),
                    ],
                  ),
                  trailing: Text(
                    '-${AppFormatters.quantity(amt)}',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Item item;
  final bool isWorker;
  final VoidCallback onEdit;
  final VoidCallback onAdjustStock;
  final VoidCallback onDelete;

  const _ItemTile({
    super.key,
    required this.item,
    required this.isWorker,
    required this.onEdit,
    required this.onAdjustStock,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 8),
      borderRadius: BorderRadius.circular(14),
      borderColor: item.isLowStock ? AppColors.error : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
            image: (item.photoPath.isNotEmpty && (item.photoPath.startsWith('http') || AppConstants.resolveFile(item.photoPath).existsSync()))
                ? DecorationImage(
                    image: item.photoPath.startsWith('http')
                        ? NetworkImage(item.photoPath) as ImageProvider
                        : FileImage(AppConstants.resolveFile(item.photoPath)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: (item.photoPath.isEmpty || (!item.photoPath.startsWith('http') && !AppConstants.resolveFile(item.photoPath).existsSync()))
              ? const Icon(Icons.image_outlined, color: AppColors.primary)
              : null,
        ),
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
        trailing: isWorker
            ? null
            : PopupMenuButton<String>(
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
