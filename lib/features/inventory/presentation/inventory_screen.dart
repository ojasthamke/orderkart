import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _category = 'All';
  final _categories = ['All', ...AppConstants.itemCategories];

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryProvider);

    return AppScaffold(
      title: 'Inventory',
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_item',
        onPressed: () => Navigator.of(context)
            .pushNamed(AppRoutes.addEditItem)
            .then((_) => ref.refresh(inventoryProvider)),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          CustomSearchBar(
            hint: 'Search items...',
            onChanged: (q) => ref.read(inventoryProvider.notifier).search(q),
          ),
          // Category filter
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? _catColor(cat) : AppColors.gray100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Low stock banner
          ref.watch(lowStockProvider).when(
                data: (lowItems) => lowItems.isEmpty
                    ? const SizedBox.shrink()
                    : _LowStockBanner(count: lowItems.length),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
          // List
          Expanded(
            child: itemsAsync.when(
              loading: () => const LoadingShimmer(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) => items.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.inventory_2_rounded,
                      title: 'No Items Yet',
                      subtitle: 'Add your inventory items',
                      actionLabel: 'Add Item',
                      onAction: () => Navigator.of(context)
                          .pushNamed(AppRoutes.addEditItem)
                          .then((_) => ref.refresh(inventoryProvider)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) => _ItemCard(
                        item: items[i],
                        index: i,
                        onEdit: () => Navigator.of(ctx)
                            .pushNamed(AppRoutes.addEditItem,
                                arguments: {'itemId': items[i].id})
                            .then((_) => ref.refresh(inventoryProvider)),
                        onDelete: () => _deleteItem(ctx, items[i]),
                        onAdjustStock: () => Navigator.of(ctx)
                            .pushNamed(AppRoutes.stockAdjustment,
                                arguments: {
                                  'itemId':   items[i].id,
                                  'itemName': items[i].name,
                                })
                            .then((_) => ref.refresh(inventoryProvider)),
                      ).animate(delay: (i * 30).ms).fadeIn(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Color _catColor(String cat) {
    switch (cat) {
      case AppConstants.catVegetables: return AppColors.vegetables;
      case AppConstants.catFruits:     return AppColors.fruits;
      case AppConstants.catGroceries:  return AppColors.groceries;
      case AppConstants.catMedicines:  return AppColors.medicines;
      default:                         return AppColors.primary;
    }
  }

  Future<void> _deleteItem(BuildContext context, Item item) async {
    final ok = await ConfirmDeleteDialog.show(
      context,
      title:   'Delete Item',
      message: 'Delete "${item.name}"?',
    );
    if (!ok || !mounted) return;
    await ref.read(inventoryProvider.notifier).deleteItem(item.id);
    if (mounted) SnackbarHelper.showSuccess(context, '"${item.name}" deleted');
  }
}

class _LowStockBanner extends StatelessWidget {
  final int count;
  const _LowStockBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: 8),
          Text(
            '$count item(s) running low on stock!',
            style: const TextStyle(
                color: AppColors.warning, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Item item;
  final int  index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAdjustStock;

  const _ItemCard({
    required this.item,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onAdjustStock,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = _catColor(item.category);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isLowStock ? AppColors.warning.withOpacity(0.5) : AppColors.gray200,
          width: item.isLowStock ? 1.5 : 1,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.inventory_2_rounded, color: catColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      if (item.isLowStock)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warningSurface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Low Stock',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  Text(
                    item.category,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: catColor, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('₹${item.sellingPrice.toStringAsFixed(2)}/${item.unit}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              )),
                      const Spacer(),
                      Text(
                        'Stock: ${AppFormatters.quantity(item.stock)} ${item.unit}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: item.isLowStock
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                              fontWeight:
                                  item.isLowStock ? FontWeight.w700 : FontWeight.w400,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.gray500),
              onSelected: (v) {
                if (v == 'edit')   onEdit();
                if (v == 'stock')  onAdjustStock();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit',   child: Text('Edit')),
                const PopupMenuItem(value: 'stock',  child: Text('Adjust Stock')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'Vegetables': return AppColors.vegetables;
      case 'Fruits':     return AppColors.fruits;
      case 'Groceries':  return AppColors.groceries;
      case 'Medicines':  return AppColors.medicines;
      default:           return AppColors.primary;
    }
  }
}
