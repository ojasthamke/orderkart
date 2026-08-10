import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../domain/item.dart';
import 'inventory_provider.dart';
import '../../expense/presentation/expense_provider.dart';
import '../../settings/presentation/settings_provider.dart';

class QuickInventoryAdjustScreen extends ConsumerStatefulWidget {
  const QuickInventoryAdjustScreen({super.key});

  @override
  ConsumerState<QuickInventoryAdjustScreen> createState() =>
      _QuickInventoryAdjustScreenState();
}

class _QuickInventoryAdjustScreenState
    extends ConsumerState<QuickInventoryAdjustScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final Map<String, Item> _modifiedItems = {};
  bool _isSaving = false;

  final List<String> _categories = ['All', ...AppConstants.itemCategories];

  String get _currency =>
      ref.watch(settingsProvider).valueOrNull?.currency ?? '₹';

  void _onFieldChanged(Item baseItem, String field, String value) {
    final parsedVal = double.tryParse(value) ?? 0.0;

    // Retrieve modified item if exists, else start from baseItem
    final currentModified = _modifiedItems[baseItem.id] ?? baseItem;

    Item updatedItem;
    switch (field) {
      case 'stock':
        updatedItem = currentModified.copyWith(stock: parsedVal);
        break;
      case 'sellingPrice':
        updatedItem = currentModified.copyWith(sellingPrice: parsedVal);
        break;
      case 'costPrice':
        updatedItem = currentModified.copyWith(costPrice: parsedVal);
        break;
      case 'marketPrice':
        updatedItem = currentModified.copyWith(marketPrice: parsedVal);
        break;
      default:
        return;
    }

    // Check if the modified item matches the baseline item
    final isDifferent = updatedItem.stock != baseItem.stock ||
        updatedItem.sellingPrice != baseItem.sellingPrice ||
        updatedItem.costPrice != baseItem.costPrice ||
        updatedItem.marketPrice != baseItem.marketPrice;

    setState(() {
      if (isDifferent) {
        _modifiedItems[baseItem.id] = updatedItem;
      } else {
        _modifiedItems.remove(baseItem.id);
      }
    });
  }

  void _resetChanges() {
    AppHaptics.buttonClick();
    setState(() {
      _modifiedItems.clear();
    });
    SnackbarHelper.showSuccess(context, 'All pending changes reset');
  }

  Future<void> _saveChanges() async {
    if (_modifiedItems.isEmpty) return;
    AppHaptics.buttonClick();

    setState(() {
      _isSaving = true;
    });

    try {
      final itemsToUpdate = _modifiedItems.values.toList();
      await ref.read(inventoryProvider.notifier).updateItems(itemsToUpdate);

      if (mounted) {
        SnackbarHelper.showSuccess(
            context, '✅ Inventory successfully updated!');
        setState(() {
          _modifiedItems.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to update inventory: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_modifiedItems.isEmpty) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: Text(
            'You have ${_modifiedItems.length} unsaved updates. Do you want to discard them and exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return discard ?? false;
  }





  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryProvider);
    final expensesAsync = ref.watch(expenseProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allItems = itemsAsync.valueOrNull ?? [];
    final expenses = expensesAsync.valueOrNull ?? [];

    final now = DateTime.now();
    final currentMonthStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}";
    double monthlyExpenses = 0.0;
    for (final exp in expenses) {
      final expMonth =
          "${exp.date.year}-${exp.date.month.toString().padLeft(2, '0')}";
      if (expMonth == currentMonthStr) {
        monthlyExpenses += exp.amount;
      }
    }
    if (monthlyExpenses <= 0 && expenses.isNotEmpty) {
      monthlyExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);
    }

    double totalInventoryCost = 0.0;
    for (final item in allItems) {
      final qty = item.stock > 0 ? item.stock : 10.0;
      totalInventoryCost += (item.costPrice * qty);
    }

    double multiplier = 1.43; // default 30% margin fallback
    if (totalInventoryCost > 0) {
      final reqRevenue = (totalInventoryCost + monthlyExpenses) / 0.70;
      multiplier = reqRevenue / totalInventoryCost;
    }

    return PopScope(
      canPop: _modifiedItems.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: AppScaffold(
        title: 'Quick Adjust Inventory',
        showBack: true,
        body: Column(
          children: [
            // Search Bar & Filter Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomSearchBar(
                hint: 'Search items...',
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),



            // Category Capsules list
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (ctx, i) {
                  final cat = _categories[i];
                  final isSelected = cat == _selectedCategory;

                  return GestureDetector(
                    onTap: () {
                      AppHaptics.buttonClick();
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      alignment: Alignment.center,
                      decoration: isSelected
                          ? AppColors.tabDecoration(context)
                          : BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(20),
                            ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Item Adjustment List
            Expanded(
              child: itemsAsync.when(
                loading: () => LoadingShimmer.cardList(count: 6, height: 160),
                error: (e, st) =>
                    Center(child: Text('Error loading inventory: $e')),
                data: (items) {
                  // Apply local filters
                  final filteredItems = items.where((item) {
                    final matchesCategory = _selectedCategory == 'All' ||
                        item.category == _selectedCategory;
                    final matchesSearch = _searchQuery.isEmpty ||
                        item.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                    return matchesCategory && matchesSearch;
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'No items found matching the filters',
                          style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredItems.length,
                    padding:
                        const EdgeInsets.only(bottom: 120, left: 16, right: 16),
                    itemBuilder: (ctx, i) {
                      final item = filteredItems[i];
                      final isModified = _modifiedItems.containsKey(item.id);
                      final workingItem = _modifiedItems[item.id] ?? item;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isModified
                                ? Colors.amber.withOpacity(0.6)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                          boxShadow: isModified
                              ? [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.12),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        child: GlassContainer(
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Item header details
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Category: ${item.category} • Unit: Per ${item.unit}',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isModified)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'MODIFIED',
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ).animate().scale(duration: 200.ms),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // 2x2 grid of adjust inputs
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInputField(
                                        key: ValueKey('${item.id}_stock'),
                                        label: 'Stock',
                                        initialValue:
                                            workingItem.stock.toString(),
                                        suffix: item.unit,
                                        onChanged: (val) =>
                                            _onFieldChanged(item, 'stock', val),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildInputField(
                                        key:
                                            ValueKey('${item.id}_sellingPrice'),
                                        label: 'Selling Price (Rate)',
                                        initialValue:
                                            workingItem.sellingPrice.toString(),
                                        prefix: _currency,
                                        onChanged: (val) => _onFieldChanged(
                                            item, 'sellingPrice', val),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInputField(
                                        key: ValueKey('${item.id}_costPrice'),
                                        label: 'Cost Price',
                                        initialValue:
                                            workingItem.costPrice.toString(),
                                        prefix: _currency,
                                        onChanged: (val) => _onFieldChanged(
                                            item, 'costPrice', val),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildInputField(
                                        key: ValueKey('${item.id}_marketPrice'),
                                        label: 'MRP (Market Price)',
                                        initialValue:
                                            workingItem.marketPrice.toString(),
                                        prefix: _currency,
                                        onChanged: (val) => _onFieldChanged(
                                            item, 'marketPrice', val),
                                      ),
                                    ),
                                  ],
                                ),
                                if (workingItem.costPrice > 0) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          AppHaptics.buttonClick();
                                          final mult = (multiplier.isNaN ||
                                                  multiplier.isInfinite ||
                                                  multiplier < 1.0)
                                              ? 1.43
                                              : multiplier;
                                          final target30 =
                                              (workingItem.costPrice * mult)
                                                  .toStringAsFixed(2);
                                          _onFieldChanged(
                                              item, 'sellingPrice', target30);
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.success
                                                .withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: AppColors.success
                                                    .withOpacity(0.4)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.verified_rounded,
                                                  size: 14,
                                                  color: AppColors.success),
                                              const SizedBox(width: 6),
                                              Text(
                                                '🎯 30% Profit Target: $_currency${(workingItem.costPrice * ((multiplier.isNaN || multiplier.isInfinite || multiplier < 1.0) ? 1.43 : multiplier)).toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          AppHaptics.buttonClick();
                                          final markup65 =
                                              (workingItem.costPrice * 1.65)
                                                  .toStringAsFixed(2);
                                          _onFieldChanged(
                                              item, 'sellingPrice', markup65);
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: AppColors.primary
                                                    .withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                  Icons.trending_up_rounded,
                                                  size: 14,
                                                  color: AppColors.primary),
                                              const SizedBox(width: 6),
                                              Text(
                                                '⭐ 65% Markup: $_currency${(workingItem.costPrice * 1.65).toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Quick Price Adjustment Slider with live customer impact
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.borderColor(context)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.tune_rounded, size: 14, color: AppColors.primary),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Rate Slider: $_currency${workingItem.sellingPrice.toStringAsFixed(2)}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              workingItem.sellingPrice >= workingItem.costPrice
                                                  ? 'Margin: +${workingItem.sellingPrice > 0 ? (((workingItem.sellingPrice - workingItem.costPrice) / workingItem.sellingPrice) * 100).toStringAsFixed(1) : "0"}%'
                                                  : 'Loss: -${workingItem.costPrice > 0 ? (((workingItem.costPrice - workingItem.sellingPrice) / workingItem.costPrice) * 100).toStringAsFixed(1) : "0"}%',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                                color: workingItem.sellingPrice >= workingItem.costPrice
                                                    ? AppColors.success
                                                    : AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            trackHeight: 3,
                                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                          ),
                                          child: Slider(
                                            value: workingItem.sellingPrice.clamp(
                                              workingItem.costPrice * 0.5,
                                              workingItem.costPrice * 3.0,
                                            ),
                                            min: workingItem.costPrice * 0.5,
                                            max: workingItem.costPrice * 3.0,
                                            activeColor: AppColors.primary,
                                            onChanged: (newPrice) {
                                              AppHaptics.selection();
                                              _onFieldChanged(
                                                item,
                                                'sellingPrice',
                                                newPrice.toStringAsFixed(2),
                                              );
                                            },
                                          ),
                                        ),
                                        if (workingItem.marketPrice > workingItem.sellingPrice)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4),
                                            child: Text(
                                              '🎉 Customer Saves: $_currency${(workingItem.marketPrice - workingItem.sellingPrice).toStringAsFixed(2)} (${(((workingItem.marketPrice - workingItem.sellingPrice) / workingItem.marketPrice) * 100).toStringAsFixed(0)}% below MRP)',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.success,
                                                fontWeight: FontWeight.w600,
                                              ),
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
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),

        // Persistent bottom banner for saving
        bottomSheet: _modifiedItems.isNotEmpty
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_modifiedItems.length} item changes pending',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const Text(
                            'Save to apply rates & stock changes',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _isSaving ? null : _resetChanges,
                      child: const Text('Reset',
                          style: TextStyle(color: AppColors.error)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Save Changes',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ).animate().slide(
                begin: const Offset(0, 1),
                end: const Offset(0, 0),
                duration: 250.ms)
            : null,
      ),
    );
  }

  Widget _buildInputField({
    required Key key,
    required String label,
    required String initialValue,
    String? prefix,
    String? suffix,
    required ValueChanged<String> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          key: key,
          initialValue: initialValue,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            prefixText: prefix,
            prefixStyle: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
            suffixText: suffix,
            suffixStyle: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.black.withOpacity(0.03),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.black.withOpacity(0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
