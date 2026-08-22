import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/package_exporter.dart';
import '../../../core/services/package_validator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/unit_converter.dart';
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
import '../../order/presentation/order_provider.dart';
import '../../analytics/presentation/analytics_provider.dart';

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
  String _selectedOrderStatus = 'all';
  String _selectedOrderDateFilter = 'all';
  String _orderedStatsSubView = 'analytics'; // 'analytics' vs 'mandi'
  final Set<String> _marketCheckedItems = {};
  final _categories = ['All', ...AppConstants.itemCategories];
  final DateTime _selectedHistoryDate = DateTime.now();
  DateTimeRange? _priceHistoryRange;
  DateTimeRange? _selectedOrderDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleEditItem(Item item) async {
    if (mounted) {
      Navigator.of(context).pushNamed(AppRoutes.addEditItem, arguments: {
        'itemId': item.id
      }).then((_) => ref.refresh(inventoryProvider));
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
        SnackbarHelper.showSuccess(
            context, 'Official Stock & Price List exported successfully!');
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
        if (mounted) {
          SnackbarHelper.showError(
              context, 'Invalid Package: ${validation.errorMessage}');
        }
        return;
      }

      final extractedDbPath = validation.dbPath;
      if (extractedDbPath.isEmpty || !File(extractedDbPath).existsSync()) {
        if (mounted) {
          SnackbarHelper.showError(context, 'No database found in package');
        }
        return;
      }

      await DatabaseHelper.instance.mergeDatabaseFromPath(
        extractedDbPath,
        selectedModules: ['items', 'prices'],
      );

      ref.invalidate(inventoryProvider);
      if (mounted) {
        SnackbarHelper.showSuccess(
            context, '✅ Official Owner Stock & Price List updated!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Price List import failed: $e');
      }
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
        if (!isWorker) ...[
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync with Server',
            onPressed: () async {
              AppHaptics.buttonClick();
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 16),
                        Text('Syncing with database server...'),
                      ],
                    ),
                    duration: Duration(seconds: 15),
                  ),
                );
                await ref.read(inventoryProvider.notifier).syncWithServer();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  SnackbarHelper.showSuccess(context, '✅ Synchronized with database server successfully!');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  SnackbarHelper.showError(context, 'Sync failed: $e');
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: 'Quick Adjust Inventory',
            onPressed: () {
              AppHaptics.buttonClick();
              Navigator.of(context).pushNamed(AppRoutes.quickInventoryAdjust);
            },
          ),
        ],
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (v) {
            if (v == 'export') {
              _exportPriceList();
            } else if (v == 'import') {
              _importOwnerPriceList();
            } else {
              ref.read(inventoryProvider.notifier).sort(v);
              if (v == 'shuffle') {
                SnackbarHelper.showSuccess(context, 'Inventory items shuffled!');
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
            const PopupMenuItem(
                value: 'stock_asc', child: Text('Sort by Stock (Low first)')),
            const PopupMenuItem(
                value: 'price_desc', child: Text('Sort by Price')),
            const PopupMenuItem(
                value: 'category', child: Text('Sort by Category')),
            const PopupMenuItem(
                value: 'shuffle', child: Text('Shuffle / Randomize')),
            if (!isWorker)
              const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.share_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Export Price List'),
                    ],
                  )),
            const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Import Price List'),
                  ],
                )),
          ],
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        labelColor: Colors.white,
        unselectedLabelColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white70
            : AppColors.textSecondary,
        indicatorColor: Colors.transparent,
        indicator: AppColors.tabDecoration(context),
        tabs: const [
          Tab(icon: Icon(Icons.inventory_2_rounded), text: 'Stock Items'),
          Tab(icon: Icon(Icons.price_change_rounded), text: 'Market Savings'),
          Tab(icon: Icon(Icons.history_rounded), text: 'Price History'),
          Tab(icon: Icon(Icons.delete_sweep_rounded), text: 'Spillage History'),
          Tab(icon: Icon(Icons.analytics_rounded), text: 'Ordered Stats'),
        ],
      ),
      floatingActionButton: isWorker
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: widget.showBack ? 0 : 100),
              child: FloatingActionButton(
                heroTag: 'add_item',
                onPressed: () => Navigator.of(context)
                    .pushNamed(AppRoutes.addEditItem)
                    .then((_) => ref.refresh(inventoryProvider)),
                child: const Icon(Icons.add_rounded),
              ),
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

          // ── TAB 5: Ordered Items Cost & Profit Stats ────────────────────────
          _buildOrderedStatsTab(context, isWorker),
        ],
      ),
    );
  }

  // ── TAB 1: Stock List ──────────────────────────────────────────────────────
  Widget _buildStockTab(
      BuildContext context, AsyncValue<List<Item>> itemsAsync, bool isWorker) {
    return Column(
      children: [
        CustomSearchBar(
          hint: 'Search items...',
          onChanged: (q) => ref.read(inventoryProvider.notifier).search(q),
        ),
        if (!isWorker) () {
          final stockSummary = ref.watch(stockSummaryProvider).valueOrNull;
          if (stockSummary == null) return const SizedBox.shrink();

          final double sellingVal =
              (stockSummary['selling_value'] as num?)?.toDouble() ?? 0.0;
          final double costVal =
              (stockSummary['cost_value'] as num?)?.toDouble() ?? 0.0;
          final double profitVal =
              (stockSummary['potential_profit'] as num?)?.toDouble() ?? 0.0;
          final int lowStockCount =
              (stockSummary['low_stock_count'] as int?) ?? 0;
          final int outOfStockCount =
              (stockSummary['out_of_stock_count'] as int?) ?? 0;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // 1. Stock Selling Valuation
                SizedBox(
                  width: 155,
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded,
                                size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'STOCK VALUATION',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppFormatters.currency(sellingVal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const Text(
                          'Total Selling Value',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 2. Cost Valuation
                if (!isWorker) ...[
                  SizedBox(
                    width: 155,
                    child: GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long_rounded,
                                  size: 13, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text(
                                'ESTIMATED COST',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.orange.shade800,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              AppFormatters.currency(costVal),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                          const Text(
                            'Cost Price Total',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 3. Potential Margin
                  SizedBox(
                    width: 155,
                    child: GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.trending_up_rounded,
                                  size: 13, color: profitVal >= 0 ? AppColors.success : AppColors.error),
                              const SizedBox(width: 4),
                              Text(
                                'POTENTIAL MARGIN',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: profitVal >= 0 ? AppColors.success : AppColors.error,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              AppFormatters.currency(profitVal),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: profitVal >= 0 ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                          Text(
                            sellingVal > 0
                                ? '${((profitVal / sellingVal) * 100).toStringAsFixed(1)}% margin'
                                : '0% margin',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // 4. Alerts Card
                SizedBox(
                  width: 155,
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 13, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              'STOCK ALERTS',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.orange.shade800,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '$lowStockCount Low',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$outOfStockCount Out',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Items requiring action',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }(),
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
                  ref
                      .read(inventoryProvider.notifier)
                      .filterByCategory(cat == 'All' ? '' : cat);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary
                        : (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E293B)
                            : AppColors.gray100),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.12)
                              : AppColors.gray300),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : AppColors.textPrimary),
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.normal,
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
                  buildDefaultDragHandles: false,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (_category != 'All') {
                      SnackbarHelper.showInfo(context,
                          'Clear category filter to reorder items');
                      return;
                    }
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final list = List<Item>.from(items);
                    final dragged = list.removeAt(oldIndex);
                    list.insert(newIndex, dragged);
                    final ids = list.map((item) => item.id).toList();
                    await ref
                        .read(inventoryProvider.notifier)
                        .reorderItems(ids);
                  },
                  itemBuilder: (_, i) => _ItemTile(
                    key: ValueKey(items[i].id),
                    index: i,
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
  Widget _buildMarketSavingsTab(
      BuildContext context, AsyncValue<List<Item>> itemsAsync) {
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
        final overallSavingsPct =
            totalMarketVal > 0 ? (totalSavings / totalMarketVal) * 100 : 0.0;

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
                        Icon(Icons.savings_rounded,
                            color: Colors.white, size: 28),
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
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Text(
                'Market Price vs Our Store Price',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
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
                    borderColor:
                        hasSavings ? Colors.green.withOpacity(0.5) : null,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'MRP: ${AppFormatters.currency(item.marketPrice > 0 ? item.marketPrice : item.sellingPrice)}/${item.unit}',
                                      style: const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      'Our Price: ${AppFormatters.currency(item.sellingPrice)}/${item.unit}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (hasSavings)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('HISTORICAL PRICE LOG & REPORT',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(
                            hasRange
                                ? '${AppFormatters.date(_priceHistoryRange!.start)} - ${AppFormatters.date(_priceHistoryRange!.end)}'
                                : AppFormatters.date(_selectedHistoryDate),
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        AppHaptics.buttonClick();
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: _priceHistoryRange ??
                              DateTimeRange(
                                start: DateTime.now()
                                    .subtract(const Duration(days: 7)),
                                end: DateTime.now(),
                              ),
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          if (!mounted) return;
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
            future:
                ItemDao().getPriceHistoryDateRange(startDateStr, endDateStr),
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
                        const Icon(Icons.history_toggle_off_rounded,
                            size: 48, color: AppColors.gray400),
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
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
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
                            const Icon(Icons.analytics_rounded,
                                color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'PRICE HISTORY REPORT (${datesSet.length} DAYS LOGGED)',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8),
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
                                const Text('Avg Store Rate',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 11)),
                                Text(AppFormatters.currency(avgSelling),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Avg Market Rate',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 11)),
                                Text(AppFormatters.currency(avgMarket),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Snapshots',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 11)),
                                Text('${list.length}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Price Logs & History',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
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
                      final sellPrice =
                          (row['selling_price'] as num?)?.toDouble() ?? 0.0;
                      final mktPrice =
                          (row['market_price'] as num?)?.toDouble() ?? 0.0;

                      return GlassContainer(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        borderRadius: BorderRadius.circular(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text(
                                    AppFormatters.dateFromString(dateVal),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                if (mktPrice > 0)
                                  Text(
                                    'MRP: ${AppFormatters.currency(mktPrice)} ',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        decoration: TextDecoration.lineThrough,
                                        color: AppColors.textSecondary),
                                  ),
                                Text(
                                  '${AppFormatters.currency(sellPrice)} / $unit',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                      fontSize: 14),
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
          final cost = item.costPrice > 0 ? item.costPrice : item.sellingPrice;
          final costLoss = qtyVal * cost;

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
                        onSelected: (s) =>
                            setStateDialog(() => mode = 'reduce'),
                      ),
                      ChoiceChip(
                        label: const Text('🍏 Wastage / Spoilage'),
                        selected: mode == 'wastage',
                        selectedColor: Colors.amber.withOpacity(0.3),
                        onSelected: (s) =>
                            setStateDialog(() => mode = 'wastage'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: qtyCon,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: mode == 'wastage'
                          ? 'Wastage Quantity (${item.unit})'
                          : 'Quantity (${item.unit})',
                      prefixIcon: Icon(
                        mode == 'add'
                            ? Icons.add_circle_outline_rounded
                            : (mode == 'wastage'
                                ? Icons.delete_outline_rounded
                                : Icons.remove_circle_outline_rounded),
                        color: mode == 'add'
                            ? AppColors.success
                            : (mode == 'wastage'
                                ? Colors.amber.shade800
                                : AppColors.error),
                      ),
                    ),
                    autofocus: true,
                    onChanged: (_) => setStateDialog(() {}),
                  ),

                  if (mode == 'wastage') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonCon,
                      maxLines: 3,
                      minLines: 1,
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
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.amber.shade900, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Estimated Loss Value: ${AppFormatters.currency(costLoss)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber.shade900,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                          'Auto-log Expense under 🍏 Spoilage & Damaged Goods',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      value: autoLogExpense,
                      onChanged: (v) =>
                          setStateDialog(() => autoLogExpense = v ?? true),
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

                  if ((mode == 'reduce' || mode == 'wastage') &&
                      qty > item.stock) {
                    SnackbarHelper.showError(context,
                        'Cannot reduce stock below 0. Current stock is ${AppFormatters.quantity(item.stock, unit: item.unit)}');
                    return;
                  }

                  AppHaptics.primarySave();

                  if (mode == 'wastage') {
                    final reason = reasonCon.text.trim().isEmpty
                        ? 'Wastage / Spoilage loss'
                        : reasonCon.text.trim();
                    await ref.read(inventoryProvider.notifier).adjustStock(
                          item.id,
                          -qty,
                          'Wastage: $reason',
                        );

                    if (autoLogExpense && costLoss > 0) {
                      await ExpenseDao().insertExpense(
                        Expense(
                          id: '',
                          name:
                              'Wastage: ${item.name} (${AppFormatters.quantity(qty, unit: item.unit)})',
                          category: AppConstants.expSpoilageLoss,
                          amount: costLoss,
                          date: DateTime.now(),
                          notes: 'Item wastage recorded: $reason',
                          paymentMethod: 'cash',
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                      );
                      ref.invalidate(analyticsSummaryProvider);
                    }
                    if (ctx.mounted) {
                      SnackbarHelper.showSuccess(context,
                          'Recorded ${AppFormatters.quantity(qty, unit: item.unit)} wastage for ${item.name}');
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
                    child: Icon(Icons.delete_outline_rounded,
                        color: Colors.amber.shade800),
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
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedDate,
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 11),
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

  Widget _buildOrderedStatsTab(BuildContext context, bool isWorker) {
    String paramKey = '$_selectedOrderStatus|$_selectedOrderDateFilter';
    if (_selectedOrderDateFilter == 'custom' && _selectedOrderDateRange != null) {
      paramKey =
          '$_selectedOrderStatus|custom|${_selectedOrderDateRange!.start.millisecondsSinceEpoch}|${_selectedOrderDateRange!.end.millisecondsSinceEpoch}';
    }

    final statsAsync = ref.watch(orderedItemStatsProvider(paramKey));

    final statusFilters = [
      {'label': 'All Orders', 'value': 'all'},
      {'label': 'Delivered', 'value': 'delivered'},
      {'label': 'Pending', 'value': 'pending'},
    ];

    String customRangeLabel = 'Custom Range 📅';
    if (_selectedOrderDateRange != null && _selectedOrderDateFilter == 'custom') {
      final startStr = DateFormat('dd MMM').format(_selectedOrderDateRange!.start);
      final endStr = DateFormat('dd MMM').format(_selectedOrderDateRange!.end);
      customRangeLabel = '$startStr - $endStr 📅';
    }

    final dateFilters = [
      {'label': 'All Time', 'value': 'all'},
      {'label': 'Today', 'value': 'today'},
      {'label': 'Yesterday', 'value': 'yesterday'},
      {'label': 'This Week', 'value': 'week'},
      {'label': 'This Month', 'value': 'month'},
      {'label': customRangeLabel, 'value': 'custom'},
    ];

    return Column(
      children: [
        const SizedBox(height: 8),
        // Status Filter Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: statusFilters.map((f) {
              final isSelected = _selectedOrderStatus == f['value'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    f['label']!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  onSelected: (selected) {
                    if (selected) {
                      AppHaptics.selection();
                      setState(() {
                        _selectedOrderStatus = f['value']!;
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        // Date Filter Row with Custom Range Picker
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: dateFilters.map((f) {
              final isCustom = f['value'] == 'custom';
              final isSelected = _selectedOrderDateFilter == f['value'];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCustom) const Icon(Icons.date_range_rounded, size: 14),
                      if (isCustom) const SizedBox(width: 4),
                      Text(
                        f['label']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : null,
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  checkmarkColor: AppColors.primary,
                  onSelected: (selected) async {
                    if (isCustom) {
                      AppHaptics.buttonClick();
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: _selectedOrderDateRange ??
                            DateTimeRange(
                              start: DateTime.now().subtract(const Duration(days: 7)),
                              end: DateTime.now(),
                            ),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedOrderDateFilter = 'custom';
                          _selectedOrderDateRange = picked;
                        });
                      }
                    } else if (selected) {
                      AppHaptics.selection();
                      setState(() {
                        _selectedOrderDateFilter = f['value']!;
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Subview Switcher: Analytics Breakdown vs Market Buying Checklist
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    AppHaptics.selection();
                    setState(() => _orderedStatsSubView = 'analytics');
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _orderedStatsSubView == 'analytics'
                          ? AppColors.primary
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bar_chart_rounded,
                          size: 15,
                          color: _orderedStatsSubView == 'analytics'
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Analytics Breakdown',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _orderedStatsSubView == 'analytics'
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    AppHaptics.selection();
                    setState(() => _orderedStatsSubView = 'mandi');
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _orderedStatsSubView == 'mandi'
                          ? Colors.orange.shade700
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_checkout_rounded,
                          size: 15,
                          color: _orderedStatsSubView == 'mandi'
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '🛒 Market Buying List',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _orderedStatsSubView == 'mandi'
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        Expanded(
          child: statsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading stats: $err')),
            data: (stats) {
              if (stats.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.analytics_outlined,
                  title:
                      'No Ordered Items (${_selectedOrderStatus.toUpperCase()})',
                  subtitle:
                      'No items found for status "$_selectedOrderStatus" and date filter "$_selectedOrderDateFilter".',
                );
              }

              if (_orderedStatsSubView == 'mandi') {
                return _buildMarketProcurementView(
                    context, stats, isWorker, paramKey);
              }

              double overallCost = 0;
              double overallRevenue = 0;
              double overallProfit = 0;
              double overallWeightKg = 0;
              double overallPieceCount = 0;

              for (final row in stats) {
                overallCost +=
                    (row['total_cost_price'] as num?)?.toDouble() ?? 0.0;
                overallRevenue +=
                    (row['total_selling_price'] as num?)?.toDouble() ?? 0.0;
                overallProfit +=
                    (row['total_profit'] as num?)?.toDouble() ?? 0.0;
                overallWeightKg +=
                    (row['total_weight_kg'] as num?)?.toDouble() ?? 0.0;
                if (row['is_weight'] != true) {
                  overallPieceCount +=
                      (row['total_quantity'] as num?)?.toDouble() ?? 0.0;
                }
              }

              return RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(orderedItemStatsProvider(paramKey).future),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          // 1. Total Weight KPI
                          SizedBox(
                            width: 155,
                            child: GlassContainer(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.scale_rounded, size: 14, color: Colors.teal.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'TOTAL WEIGHT',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: Colors.teal.shade800,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 9.5,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      UnitConverter.formatWeight(overallWeightKg),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: Colors.teal.shade900,
                                          ),
                                    ),
                                  ),
                                  if (overallPieceCount > 0)
                                    Text(
                                      '+ ${AppFormatters.quantity(overallPieceCount)} pcs',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 2. Total Sales Revenue KPI
                          SizedBox(
                            width: 155,
                            child: GlassContainer(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.shopping_bag_rounded, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'TOTAL SALES',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 9.5,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      AppFormatters.currency(overallRevenue),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    '${stats.length} items sold',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!isWorker) ...[
                            // 3. Total Profit KPI (Owner only)
                            SizedBox(
                              width: 155,
                              child: GlassContainer(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.trending_up_rounded,
                                            size: 14,
                                            color: overallProfit >= 0 ? AppColors.success : AppColors.error),
                                        const SizedBox(width: 4),
                                        Text(
                                          'TOTAL PROFIT',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: overallProfit >= 0 ? AppColors.success : AppColors.error,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 9.5,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        AppFormatters.currency(overallProfit),
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: overallProfit >= 0 ? AppColors.success : AppColors.error,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      overallRevenue > 0
                                          ? '${((overallProfit / overallRevenue) * 100).toStringAsFixed(1)}% margin'
                                          : '0% margin',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 4. Total Cost KPI (Owner only)
                            SizedBox(
                              width: 155,
                              child: GlassContainer(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.receipt_long_rounded, size: 14, color: Colors.orange),
                                        const SizedBox(width: 4),
                                        Text(
                                          'TOTAL COST',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: Colors.orange.shade800,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 9.5,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        AppFormatters.currency(overallCost),
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: Colors.orange.shade900,
                                            ),
                                      ),
                                    ),
                                    const Text(
                                      'Inventory cost',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            // 3. Total Products (Worker safe)
                            SizedBox(
                              width: 155,
                              child: GlassContainer(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.inventory_2_rounded, size: 14, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          'TOTAL PRODUCTS',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 9.5,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '${stats.length}',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                      ),
                                    ),
                                    const Text(
                                      'Unique line items',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ORDERED ITEMS BREAKDOWN',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                          ),
                          Text(
                            '${stats.length} Products',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        itemCount: stats.length,
                        itemBuilder: (ctx, i) {
                          final row = stats[i];
                          final displayName = row['bilingual_name'] ?? row['item_name'] ?? '';
                          final unit = row['item_unit'] ?? '';
                          final qty =
                              (row['total_quantity'] as num?)?.toDouble() ?? 0.0;
                          final cost =
                              (row['total_cost_price'] as num?)?.toDouble() ?? 0.0;
                          final revenue =
                              (row['total_selling_price'] as num?)?.toDouble() ?? 0.0;
                          final profit =
                              (row['total_profit'] as num?)?.toDouble() ?? 0.0;
                          final orderCount = row['order_count'] ?? 1;
                          final isWeight = row['is_weight'] == true;
                          final double weightKg =
                              (row['total_weight_kg'] as num?)?.toDouble() ?? 0.0;

                          return GlassContainer(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  _showOrdersForItemBottomSheet(context, row),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color: AppColors.primary
                                                        .withOpacity(0.25)),
                                              ),
                                              child: Text(
                                                'Total Qty: ${AppFormatters.quantity(qty)} $unit',
                                                style: const TextStyle(
                                                  color: AppColors.primary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            if (isWeight && weightKg > 0)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.teal
                                                      .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                      color: Colors.teal
                                                          .withOpacity(0.25)),
                                                ),
                                                child: Text(
                                                  'Weight: ${UnitConverter.formatWeight(weightKg)}',
                                                  style: TextStyle(
                                                    color: Colors.teal.shade800,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              onTap: () =>
                                                  _showOrdersForItemBottomSheet(
                                                      context, row),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.indigo
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                      color: Colors.indigo
                                                          .withOpacity(0.3)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '$orderCount ${orderCount == 1 ? 'order' : 'orders'}',
                                                      style: const TextStyle(
                                                        color: Colors.indigo,
                                                        fontSize: 10.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    const Icon(
                                                        Icons
                                                            .arrow_forward_ios_rounded,
                                                        size: 9,
                                                        color: Colors.indigo),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          Text(
                                            'Cost: ${AppFormatters.currency(cost)}',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (!isWorker) ...[
                                      Text(
                                        AppFormatters.currency(profit),
                                        style: TextStyle(
                                          color: profit >= 0
                                              ? AppColors.success
                                              : AppColors.error,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    Text(
                                      'Sales: ${AppFormatters.currency(revenue)}',
                                      style: TextStyle(
                                        color: isWorker ? AppColors.primary : AppColors.textSecondary,
                                        fontWeight: isWorker ? FontWeight.bold : FontWeight.normal,
                                        fontSize: isWorker ? 13 : 10,
                                      ),
                                    ),
                                    if (!isWorker && revenue > 0)
                                      Text(
                                        '${((profit / revenue) * 100).toStringAsFixed(0)}% profit',
                                        style: TextStyle(
                                          color: profit >= 0
                                              ? AppColors.success
                                              : AppColors.error,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
    );
  }

  Widget _buildMarketProcurementView(
    BuildContext context,
    List<Map<String, dynamic>> stats,
    bool isWorker,
    String paramKey,
  ) {
    final totalItems = stats.length;
    final boughtCount = stats
        .where((s) =>
            _marketCheckedItems.contains(s['item_name']?.toString() ?? ''))
        .length;
    final progress = totalItems > 0 ? (boughtCount / totalItems) : 0.0;

    double totalProcurementBudget = 0;
    double totalRequiredKg = 0;
    double totalRequiredPcs = 0;

    for (final row in stats) {
      final toBuy = (row['to_buy_quantity'] as num?)?.toDouble() ?? 0.0;
      final cost = (row['cost_price'] as num?)?.toDouble() ?? 0.0;
      totalProcurementBudget += (toBuy * cost);

      final isWeight = row['is_weight'] == true;
      if (isWeight) {
        totalRequiredKg += UnitConverter.toWeightInKg(
            toBuy, row['item_unit']?.toString() ?? 'kg');
      } else {
        totalRequiredPcs += toBuy;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(orderedItemStatsProvider(paramKey).future),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Market Procurement Header Summary Card ──
          GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(20),
            color: Colors.orange.withOpacity(isDark ? 0.18 : 0.08),
            borderColor: Colors.orange.withOpacity(0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storefront_rounded,
                            size: 18, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'MANDI / MARKET BUYING CHECKLIST',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$boughtCount / $totalItems Bought',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.orange.withOpacity(0.15),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Est. Procurement Budget',
                          style: TextStyle(
                              fontSize: 10.5, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.currency(totalProcurementBudget),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Total Deficit to Buy',
                          style: TextStyle(
                              fontSize: 10.5, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          totalRequiredKg > 0
                              ? '${UnitConverter.formatWeight(totalRequiredKg)}${totalRequiredPcs > 0 ? " + ${totalRequiredPcs.toInt()} pcs" : ""}'
                              : '${totalRequiredPcs.toInt()} pcs',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        AppHaptics.selection();
                        setState(() {
                          if (_marketCheckedItems.length == stats.length) {
                            _marketCheckedItems.clear();
                          } else {
                            _marketCheckedItems.addAll(
                              stats.map(
                                  (s) => s['item_name']?.toString() ?? ''),
                            );
                          }
                        });
                      },
                      icon: Icon(
                        _marketCheckedItems.length == stats.length
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 16,
                        color: Colors.orange,
                      ),
                      label: Text(
                        _marketCheckedItems.length == stats.length
                            ? 'Clear Checks'
                            : 'Select All',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _shareMarketBuyingList(stats),
                      icon: const Icon(Icons.share_rounded, size: 14),
                      label: const Text(
                        'Share WhatsApp',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ITEMS TO PROCURE (TAP TO EDIT COST)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '$totalItems items',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ── List of Procurement Items with Checkboxes and Inline Cost Pricing ──
          ...stats.map((row) {
            final itemName = row['item_name']?.toString() ?? 'Item';
            final displayName = row['bilingual_name'] ?? itemName;
            final itemId = row['item_id']?.toString() ?? '';
            final unit = row['item_unit']?.toString() ?? 'kg';
            final totalOrdered =
                (row['total_quantity'] as num?)?.toDouble() ?? 0.0;
            final stock = (row['stock'] as num?)?.toDouble() ?? 0.0;
            final toBuy =
                (row['to_buy_quantity'] as num?)?.toDouble() ?? 0.0;
            final costPrice =
                (row['cost_price'] as num?)?.toDouble() ?? 0.0;
            final isChecked = _marketCheckedItems.contains(itemName);

            return GlassContainer(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              borderRadius: BorderRadius.circular(14),
              color: isChecked
                  ? (isDark
                      ? Colors.green.withOpacity(0.08)
                      : Colors.green.shade50.withOpacity(0.5))
                  : null,
              borderColor: isChecked
                  ? Colors.green.withOpacity(0.35)
                  : (toBuy > 0 ? Colors.orange.withOpacity(0.3) : null),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Checkbox
                  InkWell(
                    onTap: () {
                      AppHaptics.selection();
                      setState(() {
                        if (isChecked) {
                          _marketCheckedItems.remove(itemName);
                        } else {
                          _marketCheckedItems.add(itemName);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        isChecked
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isChecked ? AppColors.success : Colors.grey,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Name and quantities
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            decoration:
                                isChecked ? TextDecoration.lineThrough : null,
                            color: isChecked ? AppColors.textSecondary : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // Total Demand Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Demand: ${AppFormatters.quantity(totalOrdered)} $unit',
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary),
                              ),
                            ),
                            // In-store Stock Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Stock: ${AppFormatters.quantity(stock)} $unit',
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                            // Net to Buy Badge
                            if (toBuy > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: Colors.orange.withOpacity(0.4)),
                                ),
                                child: Text(
                                  '🛒 To Buy: ${AppFormatters.quantity(toBuy)} $unit',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.orange),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '✓ Stock Sufficient',
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Cost Price interactive editor button
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () => _showQuickCostPriceDialog(
                          context,
                          itemId,
                          itemName,
                          costPrice,
                          unit,
                          paramKey,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                costPrice > 0
                                    ? '₹${costPrice.toStringAsFixed(1)}/$unit'
                                    : 'Set Cost',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.edit_rounded,
                                  size: 11, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                      if (toBuy > 0 && costPrice > 0) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Est: ${AppFormatters.currency(toBuy * costPrice)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _showQuickCostPriceDialog(
    BuildContext context,
    String itemId,
    String itemName,
    double currentCostPrice,
    String unit,
    String paramKey,
  ) async {
    final con = TextEditingController(
      text: currentCostPrice > 0 ? currentCostPrice.toStringAsFixed(2) : '',
    );

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Set Market Cost: $itemName',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter actual wholesale rate paid per $unit:',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: con,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Cost Price (₹ per $unit)',
                prefixText: '₹ ',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final val = double.tryParse(con.text.trim());
              if (val != null && val >= 0) {
                if (itemId.isNotEmpty) {
                  await ItemDao().quickUpdateItemCostPrice(itemId, val);
                }
                Navigator.pop(ctx, true);
              } else {
                SnackbarHelper.showError(ctx, 'Please enter a valid price');
              }
            },
            child: const Text('Save Rate'),
          ),
        ],
      ),
    );

    if (updated == true) {
      AppHaptics.primarySave();
      ref.invalidate(orderedItemStatsProvider);
      ref.invalidate(inventoryProvider);
      ref.invalidate(profitLossProvider);
      ref.invalidate(dateWiseProfitProvider);
      ref.invalidate(todayVsYesterdayProfitProvider);
      if (mounted) {
        SnackbarHelper.showSuccess(
            context, 'Updated purchase cost for $itemName');
      }
    }
  }

  Future<void> _shareMarketBuyingList(
      List<Map<String, dynamic>> stats) async {
    AppHaptics.buttonClick();
    if (stats.isEmpty) return;

    final now = DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);

    final sb = StringBuffer();
    sb.writeln('🛒 *ORDERKART MARKET BUYING LIST (MANDI PROCUREMENT)*');
    sb.writeln('📅 Date: $dateStr');
    sb.writeln(
        '📋 Filter: ${_selectedOrderStatus.toUpperCase()} Orders (${_selectedOrderDateFilter.toUpperCase()})');
    sb.writeln('═══════════════════════════════════');

    double totalEstCost = 0.0;
    int index = 1;

    for (final row in stats) {
      final name = row['bilingual_name'] ?? row['item_name'] ?? 'Item';
      final unit = row['item_unit'] ?? '';
      final totalQty = (row['total_quantity'] as num?)?.toDouble() ?? 0.0;
      final stock = (row['stock'] as num?)?.toDouble() ?? 0.0;
      final toBuyQty = (row['to_buy_quantity'] as num?)?.toDouble() ??
          (totalQty - stock).clamp(0, double.infinity);
      final costPrice = (row['cost_price'] as num?)?.toDouble() ?? 0.0;
      final estItemCost = toBuyQty * costPrice;
      totalEstCost += estItemCost;

      final isChecked =
          _marketCheckedItems.contains(row['item_name']?.toString() ?? '');
      final checkMark = isChecked ? '✅ [DONE]' : '⬜ [TO BUY]';

      sb.writeln('$checkMark $index. *$name*');
      sb.writeln(
          '   • *Required To Buy: ${AppFormatters.quantity(toBuyQty)} $unit*');
      sb.writeln(
          '   • Total Demand: ${AppFormatters.quantity(totalQty)} $unit | Store Stock: ${AppFormatters.quantity(stock)} $unit');
      if (costPrice > 0) {
        sb.writeln(
            '   • Rate: ₹${costPrice.toStringAsFixed(2)}/$unit | Est Cost: ₹${estItemCost.toStringAsFixed(2)}');
      }
      sb.writeln('-----------------------------------');
      index++;
    }

    sb.writeln('═══════════════════════════════════');
    sb.writeln('📦 Total Distinct Items: ${stats.length}');
    sb.writeln('💰 Total Estimated Budget: ₹${totalEstCost.toStringAsFixed(2)}');
    sb.writeln('⚡ Generated by OrderKart FreshFlow POS');

    final text = sb.toString();
    try {
      await Share.share(text, subject: 'OrderKart Mandi Procurement List');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Copied buying list to clipboard!');
      }
    }
  }

  void _showOrdersForItemBottomSheet(
      BuildContext context, Map<String, dynamic> itemRow) {
    AppHaptics.selection();
    final displayName =
        itemRow['bilingual_name'] ?? itemRow['item_name'] ?? 'Item';
    final itemId = itemRow['item_id'] as String?;
    final rawName = itemRow['item_name'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Orders for $displayName',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Status: ${_selectedOrderStatus.toUpperCase()} • Filter: ${_selectedOrderDateFilter.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(height: 20),

              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: ItemDao().getOrdersForItem(
                    itemId: itemId,
                    itemName: rawName,
                    status: _selectedOrderStatus,
                    dateFilter: _selectedOrderDateFilter,
                    startDate: _selectedOrderDateRange?.start,
                    endDate: _selectedOrderDateRange?.end,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final orders = snapshot.data ?? [];
                    if (orders.isEmpty) {
                      return const Center(
                        child: Text(
                          'No orders found for this item.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final o = orders[index];
                        final orderId = o['order_id'] as String? ?? '';
                        final custName = o['customer_name'] as String? ??
                            'Walk-in / App Customer';
                        final custHouse =
                            o['customer_house'] as String? ?? '';
                        final statusStr =
                            o['delivery_status'] as String? ?? 'pending';
                        final createdAt = o['created_at'] != null
                            ? DateTime.tryParse(o['created_at'].toString())
                            : null;
                        final qty =
                            (o['quantity'] as num?)?.toDouble() ?? 0.0;
                        final unit = o['item_unit'] as String? ?? '';
                        final itemTotal =
                            (o['total_price'] as num?)?.toDouble() ?? 0.0;

                        Color statusBg = Colors.amber.withOpacity(0.15);
                        Color statusColor = Colors.amber.shade900;
                        if (statusStr == 'delivered' ||
                            statusStr == 'completed') {
                          statusBg = AppColors.success.withOpacity(0.15);
                          statusColor = AppColors.success;
                        } else if (statusStr == 'cancelled') {
                          statusBg = AppColors.error.withOpacity(0.15);
                          statusColor = AppColors.error;
                        }

                        return GlassContainer(
                          padding: const EdgeInsets.all(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              AppHaptics.buttonClick();
                              Navigator.pop(ctx);
                              Navigator.pushNamed(
                                context,
                                AppRoutes.orderDetail,
                                arguments: orderId,
                              );
                            },
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              custName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusBg,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              statusStr.toUpperCase(),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Item Qty: ${AppFormatters.quantity(qty)} $unit  •  Total: ${AppFormatters.currency(itemTotal)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          if (custHouse.isNotEmpty) ...[
                                            Text(
                                              '🏠 $custHouse',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const Text('  •  ',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors
                                                        .textSecondary)),
                                          ],
                                          if (createdAt != null)
                                            Text(
                                              AppFormatters.dateTime(createdAt),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        );
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
}

class _ItemTile extends StatelessWidget {
  final int index;
  final Item item;
  final bool isWorker;
  final VoidCallback onEdit;
  final VoidCallback onAdjustStock;
  final VoidCallback onDelete;

  const _ItemTile({
    super.key,
    required this.index,
    required this.item,
    required this.isWorker,
    required this.onEdit,
    required this.onAdjustStock,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tile = GlassContainer(
      margin: const EdgeInsets.only(bottom: 8),
      borderRadius: BorderRadius.circular(14),
      borderColor: item.isLowStock ? Colors.amber.shade600 : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isWorker)
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.drag_indicator_rounded,
                      color: AppColors.gray400, size: 20),
                ),
              ),
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${item.sequenceNo > 0 ? "#${item.sequenceNo} " : ""}${item.name}',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Price: ${AppFormatters.currency(item.sellingPrice)} / ${item.unit}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 13),
                ),
                if (item.marketPrice > 0)
                  Text(
                    'MRP: ${AppFormatters.currency(item.marketPrice)}',
                    style: TextStyle(
                      fontSize: 11,
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.textSecondaryColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Cost: ${AppFormatters.currency(item.costPrice)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF80CBC4)
                        : Colors.teal,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Stock: ${AppFormatters.quantity(item.stock, unit: item.unit)}',
                  style: TextStyle(
                    color: item.isLowStock
                        ? AppColors.error
                        : AppColors.textSecondaryColor(context),
                    fontWeight:
                        item.isLowStock ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
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
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Edit Item')
                      ])),
                  const PopupMenuItem(
                      value: 'stock',
                      child: Row(children: [
                        Icon(Icons.swap_vert_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Adjust Stock')
                      ])),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppColors.error))
                      ])),
                ],
              ),
      ),
    );

    if (item.isLowStock) {
      return tile.animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
            duration: const Duration(milliseconds: 1500),
            color: Colors.amber.shade200.withOpacity(0.35),
          );
    }
    return tile;
  }
}
