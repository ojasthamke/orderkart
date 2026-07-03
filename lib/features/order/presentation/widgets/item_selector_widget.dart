/// ItemSelectorWidget — Bottom sheet to pick an item from inventory with quantity

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_search_bar.dart';
import '../../../inventory/domain/item.dart';
import '../../../inventory/presentation/inventory_provider.dart';

class ItemSelectorWidget extends ConsumerStatefulWidget {
  final void Function(Item item, double qty) onItemSelected;

  const ItemSelectorWidget({super.key, required this.onItemSelected});

  @override
  ConsumerState<ItemSelectorWidget> createState() => _ItemSelectorWidgetState();
}

class _ItemSelectorWidgetState extends ConsumerState<ItemSelectorWidget>
    with SingleTickerProviderStateMixin {
  String _search   = '';
  String _category = 'All';
  final Map<String, (Item item, double qty)> _selections = {};

  final _categories = ['All', ...AppConstants.itemCategories];

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomSheetTheme.backgroundColor ??
              Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Select Items',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 8),

            // Search bar
            CustomSearchBar(
              hint: 'Search items...',
              onChanged: (q) => setState(() => _search = q),
            ),

            // Category tabs
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final selected = cat == _category;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.gray100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color:
                              selected ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Items list
            Expanded(
              child: inventoryAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (items) {
                  final filtered = items.where((item) {
                    final matchCat = _category == 'All' ||
                        item.category == _category;
                    final matchSearch = _search.isEmpty ||
                        item.name
                            .toLowerCase()
                            .contains(_search.toLowerCase());
                    return matchCat && matchSearch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                        child: Text('No items found',
                            style: TextStyle(color: AppColors.textSecondary)));
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: filtered.length,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      final selection = _selections[item.id];
                      final isSelected = selection != null;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primarySurface
                              : AppColors.gray50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.gray200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${item.sellingPrice.toStringAsFixed(item.sellingPrice == item.sellingPrice.roundToDouble() ? 0 : 2)} / ${item.unit}  •  Stock: ${AppFormatters.quantity(item.stock)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  // Fractional price hints
                                  ..._fractionalHints(context, item.sellingPrice, item.unit),
                                  if (item.stock <= 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text('❌ Out of stock',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                  color: AppColors.error,
                                                  fontWeight: FontWeight.w700)),
                                    )
                                  else if (item.isLowStock)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text('⚠️ Low stock',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                  color: AppColors.warning)),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isSelected)
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selections[item.id] = (item, 1.0);
                                  });
                                },
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Add'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_rounded, color: AppColors.error),
                                    onPressed: () {
                                      setState(() {
                                        final currentQty = selection.$2;
                                        final step = (item.unit.toLowerCase() == 'kg' ||
                                                item.unit.toLowerCase() == 'liter' ||
                                                item.unit.toLowerCase() == 'litre')
                                            ? 0.25
                                            : 1.0;
                                        if (currentQty <= step) {
                                          _selections.remove(item.id);
                                        } else {
                                          _selections[item.id] = (
                                            item,
                                            double.parse((currentQty - step).toStringAsFixed(2))
                                          );
                                        }
                                      });
                                    },
                                  ),
                                  Text(
                                    AppFormatters.quantity(selection.$2),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                                    onPressed: () {
                                      setState(() {
                                        final currentQty = selection.$2;
                                        final step = (item.unit.toLowerCase() == 'kg' ||
                                                item.unit.toLowerCase() == 'liter' ||
                                                item.unit.toLowerCase() == 'litre')
                                            ? 0.25
                                            : 1.0;
                                        _selections[item.id] = (
                                          item,
                                          double.parse((currentQty + step).toStringAsFixed(2))
                                        );
                                      });
                                    },
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
            ),

            // Confirm selection button
            if (_selections.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                decoration: BoxDecoration(
                  color: Theme.of(context).bottomSheetTheme.backgroundColor ??
                      Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, -2))
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    for (final sel in _selections.values) {
                      widget.onItemSelected(sel.$1, sel.$2);
                    }
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                      'Add ${_selections.length} Item${_selections.length > 1 ? 's' : ''} to Order'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Returns a row of small price-hint texts for common fractional quantities.
  /// Calculated purely in memory — no DB calls, no schema changes.
  List<Widget> _fractionalHints(BuildContext context, double price, String unit) {
    final hintStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          height: 1.6,
        );

    List<(String label, double fraction)> fractions;
    switch (unit.toLowerCase()) {
      case 'kg':
        fractions = [('250 gm', 0.25), ('500 gm', 0.50), ('750 gm', 0.75)];
        break;
      case 'liter':
      case 'litre':
      case 'l':
        fractions = [('250 ml', 0.25), ('500 ml', 0.50), ('750 ml', 0.75)];
        break;
      case 'dozen':
        fractions = [(' 3 pcs', 0.25), (' 6 pcs', 0.50), (' 9 pcs', 0.75)];
        break;
      default:
        return []; // Piece / Packet / custom — no sub-unit hints
    }

    final String Function(double v) fmt = (v) => v == v.roundToDouble()
        ? '\u20b9${v.toInt()}'
        : '\u20b9${v.toStringAsFixed(1)}';

    return [
      const SizedBox(height: 4),
      Wrap(
        spacing: 10,
        children: fractions
            .map((f) => Text('${f.$1} = ${fmt(price * f.$2)}', style: hintStyle))
            .toList(),
      ),
    ];
  }
}
