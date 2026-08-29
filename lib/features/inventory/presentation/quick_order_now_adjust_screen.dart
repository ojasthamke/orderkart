import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../domain/item.dart';
import 'inventory_provider.dart';
import '../../settings/presentation/settings_provider.dart';

class QuickOrderNowAdjustScreen extends ConsumerStatefulWidget {
  const QuickOrderNowAdjustScreen({super.key});

  @override
  ConsumerState<QuickOrderNowAdjustScreen> createState() =>
      _QuickOrderNowAdjustScreenState();
}

class _QuickOrderNowAdjustScreenState
    extends ConsumerState<QuickOrderNowAdjustScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final Set<String> _selectedItemIds = {};
  final Map<String, Item> _modifiedItems = {};
  bool _isSaving = false;

  final List<String> _categories = ['All', ...AppConstants.itemCategories];

  String get _currency =>
      ref.watch(settingsProvider).valueOrNull?.currency ?? '₹';

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
            context, '✅ Order Now inventory successfully updated!');
        setState(() {
          _modifiedItems.clear();
          _selectedItemIds.clear();
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

  void _bulkMarkAvailable(List<Item> filteredItems, bool available) {
    if (_selectedItemIds.isEmpty) {
      SnackbarHelper.showInfo(context, 'Please select at least one item');
      return;
    }
    AppHaptics.selection();
    setState(() {
      for (final id in _selectedItemIds) {
        final baseItem = filteredItems.firstWhere((item) => item.id == id);
        final current = _modifiedItems[id] ?? baseItem;
        _modifiedItems[id] = current.copyWith(orderNowIsAvailable: available);
      }
    });
    SnackbarHelper.showSuccess(
        context, 'Marked ${_selectedItemIds.length} item(s) as ${available ? 'Available' : 'Unavailable'}');
  }

  void _bulkSetStock(List<Item> filteredItems) {
    if (_selectedItemIds.isEmpty) {
      SnackbarHelper.showInfo(context, 'Please select at least one item');
      return;
    }
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Bulk Stock'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'New Stock Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final double? val = double.tryParse(controller.text);
              if (val == null) {
                SnackbarHelper.showError(context, 'Please enter a valid number');
                return;
              }
              Navigator.pop(ctx);
              AppHaptics.buttonClick();
              setState(() {
                for (final id in _selectedItemIds) {
                  final baseItem = filteredItems.firstWhere((item) => item.id == id);
                  final current = _modifiedItems[id] ?? baseItem;
                  _modifiedItems[id] = current.copyWith(orderNowStock: val);
                }
              });
              SnackbarHelper.showSuccess(
                  context, 'Set stock to $val for ${_selectedItemIds.length} item(s)');
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _bulkSetPrice(List<Item> filteredItems) {
    if (_selectedItemIds.isEmpty) {
      SnackbarHelper.showInfo(context, 'Please select at least one item');
      return;
    }
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Bulk Selling Price'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'New Price (₹)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final double? val = double.tryParse(controller.text);
              if (val == null) {
                SnackbarHelper.showError(context, 'Please enter a valid number');
                return;
              }
              Navigator.pop(ctx);
              AppHaptics.buttonClick();
              setState(() {
                for (final id in _selectedItemIds) {
                  final baseItem = filteredItems.firstWhere((item) => item.id == id);
                  final current = _modifiedItems[id] ?? baseItem;
                  _modifiedItems[id] = current.copyWith(orderNowSellingPrice: val);
                }
              });
              SnackbarHelper.showSuccess(
                  context, 'Set price to $_currency$val for ${_selectedItemIds.length} item(s)');
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
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
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, Keep Editing'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: AppScaffold(
        title: 'Bulk Edit Order Now',
        actions: [
          if (_modifiedItems.isNotEmpty)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded),
              tooltip: 'Save Changes',
              onPressed: _isSaving ? null : _saveChanges,
            ),
        ],
        body: Column(
          children: [
            CustomSearchBar(
              hint: 'Search products...',
              onChanged: (q) => setState(() => _searchQuery = q),
            ),
            // Horizontal Category Selector
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final selected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat;
                        _selectedItemIds.clear();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  final filtered = items.where((item) {
                    final matchesCategory = _selectedCategory == 'All' ||
                        item.category.toLowerCase() == _selectedCategory.toLowerCase();
                    final matchesSearch = item.name
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase());
                    return matchesCategory && matchesSearch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.inventory_2_outlined,
                      title: 'No Products Found',
                      subtitle: 'Try a different category or search term',
                    );
                  }

                  final allSelected = filtered.every((it) => _selectedItemIds.contains(it.id));

                  return Column(
                    children: [
                      // Select All Header
                      CheckboxListTile(
                        title: const Text(
                          'Select All',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${_selectedItemIds.length} item(s) selected'),
                        value: allSelected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedItemIds.addAll(filtered.map((it) => it.id));
                            } else {
                              _selectedItemIds.removeAll(filtered.map((it) => it.id));
                            }
                          });
                        },
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, idx) {
                            final baseItem = filtered[idx];
                            final item = _modifiedItems[baseItem.id] ?? baseItem;
                            final isSelected = _selectedItemIds.contains(item.id);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: CheckboxListTile(
                                value: isSelected,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedItemIds.add(item.id);
                                    } else {
                                      _selectedItemIds.remove(item.id);
                                    }
                                  });
                                },
                                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Wrap(
                                  spacing: 12,
                                  children: [
                                    Text('Stock: ${item.orderNowStock} ${item.unit}'),
                                    Text('Price: $_currency${item.orderNowSellingPrice}'),
                                    Text('Status: ${item.orderNowIsAvailable ? 'Available' : 'Unavailable'}',
                                        style: TextStyle(
                                            color: item.orderNowIsAvailable ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Bulk Actions Bar
                      if (_selectedItemIds.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, -2),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                                tooltip: 'Mark Available',
                                onPressed: () => _bulkMarkAvailable(filtered, true),
                              ),
                              IconButton(
                                icon: const Icon(Icons.block_rounded, color: Colors.red),
                                tooltip: 'Mark Unavailable',
                                onPressed: () => _bulkMarkAvailable(filtered, false),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_road_rounded, color: Colors.blue),
                                tooltip: 'Set Stock',
                                onPressed: () => _bulkSetStock(filtered),
                              ),
                              IconButton(
                                icon: const Icon(Icons.attach_money_rounded, color: Colors.amber),
                                tooltip: 'Set Price',
                                onPressed: () => _bulkSetPrice(filtered),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
