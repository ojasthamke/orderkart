/// ItemSelectorWidget — Bottom sheet to pick an item from inventory with quantity
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/custom_search_bar.dart';
import '../../../inventory/domain/item.dart';
import '../../../inventory/presentation/inventory_provider.dart';
import '../../../settings/presentation/settings_provider.dart';
import '../../../../core/widgets/glass_container.dart';

class ItemSelectorWidget extends ConsumerStatefulWidget {
  final String customerId;
  final void Function(Item item, double qty, double price) onItemSelected;

  const ItemSelectorWidget({
    super.key,
    required this.customerId,
    required this.onItemSelected,
  });

  @override
  ConsumerState<ItemSelectorWidget> createState() => _ItemSelectorWidgetState();
}

class _ItemSelectorWidgetState extends ConsumerState<ItemSelectorWidget>
    with SingleTickerProviderStateMixin {
  String _search   = '';
  String _category = 'All';
  double _qty = 0.25;
  final _qtyController = TextEditingController(text: '0.25');
  final _priceController = TextEditingController();
  double _customUnitPrice = 0.0;
  Item?  _selected;

  final _categories = ['All', ...AppConstants.itemCategories];

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final settingsVal = ref.watch(settingsProvider).valueOrNull;
    final currency = settingsVal?.currency ?? '₹';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      builder: (_, scrollController) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return AnimatedPadding(
          padding: EdgeInsets.only(bottom: bottomInset),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Container(
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select Items',
                      style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
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
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withOpacity(0.3)
                            : (isDark ? Colors.white.withOpacity(0.08) : AppColors.gray100),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : (isDark ? Colors.white.withOpacity(0.1) : Colors.transparent),
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : (isDark ? Colors.white70 : AppColors.textSecondary),
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

                  // Push out-of-stock items to the bottom of the list
                  filtered.sort((a, b) {
                    final aOut = a.stock < 0.001;
                    final bOut = b.stock < 0.001;
                    if (aOut && !bOut) return 1;
                    if (!aOut && bOut) return -1;
                    return 0;
                  });

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
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      final isSelected = _selected?.id == item.id;
                      final isDark = Theme.of(context).brightness == Brightness.dark;

                      return GestureDetector(
                        onTap: () {
                          if (item.stock < 0.001) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ "${item.name}" is out of stock! Cannot add to order.'),
                                backgroundColor: AppColors.error,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          setState(() {
                            _selected = item;
                            _qty = 0.25.clamp(0.01, item.stock);
                            _qtyController.text = AppFormatters.quantity(_qty);
                          });
                          _loadCustomPrice(item.id, item.sellingPrice);
                        },
                        child: GlassContainer(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.20)
                              : (item.stock < 0.001
                                  ? Colors.red.withOpacity(0.06)
                                  : (isDark ? const Color(0xFF1E293B).withOpacity(0.4) : AppColors.gray50)),
                          borderColor: isSelected
                              ? AppColors.primary
                              : (item.stock < 0.001
                                  ? AppColors.error.withOpacity(0.25)
                                  : (isDark ? Colors.white.withOpacity(0.12) : AppColors.gray200)),
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
                                                fontWeight: FontWeight.w700,
                                                color: item.stock < 0.001 ? AppColors.textSecondary : (isDark ? Colors.white : AppColors.textPrimary))),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$currency${item.sellingPrice.toStringAsFixed(item.sellingPrice == item.sellingPrice.roundToDouble() ? 0 : 2)} / ${item.unit}  •  Cost: $currency${item.costPrice.toStringAsFixed(item.costPrice == item.costPrice.roundToDouble() ? 0 : 2)}  •  Stock: ${AppFormatters.quantity(item.stock)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: item.stock < 0.001 ? AppColors.error : (isDark ? Colors.white70 : AppColors.primary),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    // Fractional price hints
                                    ..._fractionalHints(context, item.sellingPrice, item.unit),
                                    if (item.stock < 0.001)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text('❌ OUT OF STOCK — Cannot add to order',
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
                                        child: Text('⚠️ Low stock (Only ${AppFormatters.quantity(item.stock)} available)',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                    color: AppColors.warning)),
                                      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                                       .fadeIn(begin: 0.40, duration: 1000.ms),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.primary)
                              else if (item.stock < 0.001)
                                const Icon(Icons.block_rounded,
                                    color: AppColors.error, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Quantity picker + confirm
            if (_selected != null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                decoration: BoxDecoration(
                  color: Theme.of(context).bottomSheetTheme.backgroundColor ??
                      Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, -2))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Quantity (${_selected!.unit})',
                            style: Theme.of(context).textTheme.labelMedium),
                        Text(
                          'Max Available: ${AppFormatters.quantity(_selected!.stock)} ${_selected!.unit}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _qty > _selected!.stock ? AppColors.error : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Preset chips
                    Wrap(
                      spacing: 8,
                      children: AppConstants.getPresetsForUnit(_selected!.unit).map((q) {
                        final disabled = q > _selected!.stock;
                        return ChoiceChip(
                          label: Text(AppFormatters.quantity(q)),
                          selected: _qty == q,
                          onSelected: disabled
                              ? null
                              : (_) {
                                  AppHaptics.selection();
                                  setState(() {
                                    _qty = q;
                                    _qtyController.text = AppFormatters.quantity(q);
                                    final calcPrice = _customUnitPrice * _qty;
                                    _priceController.text = calcPrice.toStringAsFixed(calcPrice == calcPrice.roundToDouble() ? 0 : 2);
                                  });
                                },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qtyController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Qty',
                              isDense: true,
                              errorText: _qty > _selected!.stock ? 'Exceeds stock (${_selected!.stock})' : null,
                            ),
                            onChanged: (v) {
                              final p = double.tryParse(v) ?? 0.0;
                              if (p > _selected!.stock) {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Cannot exceed available stock (${_selected!.stock} ${_selected!.unit})'),
                                    backgroundColor: AppColors.error,
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                              setState(() {
                                _qty = p;
                                final calcPrice = _customUnitPrice * _qty;
                                _priceController.text = calcPrice.toStringAsFixed(calcPrice == calcPrice.roundToDouble() ? 0 : 2);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                               labelText: 'Price ($currency)',
                               isDense: true,
                             ),
                            onChanged: (v) {
                              final p = double.tryParse(v);
                              if (p != null && p >= 0 && _qty > 0) {
                                _customUnitPrice = p / _qty;
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: (_qty <= 0 || _qty > _selected!.stock || _selected!.stock < 0.001)
                              ? () {
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_qty <= 0
                                          ? 'Quantity must be greater than 0'
                                          : 'Quantity ($_qty) exceeds available stock (${_selected!.stock})'),
                                      backgroundColor: AppColors.error,
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              : () async {
                                  AppHaptics.itemAdded();

                                  final double enteredPriceForQty = double.tryParse(_priceController.text) ?? (_customUnitPrice * _qty);
                                  final double finalUnitPriceToUse = _qty > 0 ? (enteredPriceForQty / _qty) : enteredPriceForQty;

                                  // Check if the user changed the price from the loaded custom price
                                  final customPrice = await DatabaseHelper.instance.getCustomerCustomPrice(widget.customerId, _selected!.id);
                                  final currentPriceToCompare = customPrice ?? _selected!.sellingPrice;

                                  if ((finalUnitPriceToUse - currentPriceToCompare).abs() > 0.01) {
                                    if (context.mounted) {
                                      final choice = await _showPriceScopeDialog(context, _selected!.name);
                                      if (choice == null) return; // user cancelled

                                      if (choice == 1) {
                                        // This Customer Only
                                        await DatabaseHelper.instance.setCustomerCustomPrice(widget.customerId, _selected!.id, finalUnitPriceToUse);
                                        ref.invalidate(inventoryProvider);
                                      } else if (choice == 2) {
                                        // General
                                        await DatabaseHelper.instance.updateItemSellingPrice(_selected!.id, finalUnitPriceToUse);
                                        ref.invalidate(inventoryProvider);
                                      }
                                    }
                                  }

                                  widget.onItemSelected(_selected!, _qty, finalUnitPriceToUse);

                                  // Success SnackBar
                                  final addedItemName = _selected!.name;
                                  final addedQty = _qty;
                                  final addedUnit = _selected!.unit;
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).clearSnackBars();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added $addedQty $addedUnit of $addedItemName to order'),
                                        duration: const Duration(seconds: 1),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }

                                  setState(() {
                                    _selected = null;
                                    _qty = 0.25;
                                    _qtyController.text = '0.25';
                                    _priceController.clear();
                                  });
                                },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _qty > _selected!.stock || _selected!.stock < 0.001
                                ? Colors.grey
                                : AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  },
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

    fmt(v) => v == v.roundToDouble()
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

  Future<void> _loadCustomPrice(String itemId, double defaultPrice) async {
    final customPrice = await DatabaseHelper.instance.getCustomerCustomPrice(widget.customerId, itemId);
    if (mounted) {
      setState(() {
        _customUnitPrice = customPrice ?? defaultPrice;
        final calcPrice = _customUnitPrice * _qty;
        _priceController.text = calcPrice.toStringAsFixed(calcPrice == calcPrice.roundToDouble() ? 0 : 2);
      });
    }
  }

  Future<int?> _showPriceScopeDialog(BuildContext context, String itemName) async {
    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Price Scope'),
        content: Text('You changed the price of "$itemName". How should this new price be saved?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 3),
            child: const Text('Just this Order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 1),
            child: const Text('This Customer Only'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 2),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('For General (All)'),
          ),
        ],
      ),
    );
  }
}
