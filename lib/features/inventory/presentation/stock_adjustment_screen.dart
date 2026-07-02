import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import 'inventory_provider.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  final String itemId;
  final String itemName;
  const StockAdjustmentScreen(
      {super.key, required this.itemId, required this.itemName});

  @override
  ConsumerState<StockAdjustmentScreen> createState() =>
      _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState
    extends ConsumerState<StockAdjustmentScreen> {
  final _changeCon  = TextEditingController();
  double _change    = 0;
  bool   _isAdd     = true; // true = add stock, false = remove

  @override
  void dispose() {
    _changeCon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Adjust Stock',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(widget.itemName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          )),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Add / Remove toggle
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isAdd = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _isAdd
                            ? AppColors.success
                            : AppColors.gray100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '+ Add Stock',
                          style: TextStyle(
                            color: _isAdd ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isAdd = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: !_isAdd ? AppColors.error : AppColors.gray100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '- Remove Stock',
                          style: TextStyle(
                            color: !_isAdd ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _changeCon,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Quantity',
                prefixIcon: Icon(
                  _isAdd
                      ? Icons.add_circle_outline_rounded
                      : Icons.remove_circle_outline_rounded,
                  color: _isAdd ? AppColors.success : AppColors.error,
                ),
              ),
              onChanged: (v) =>
                  setState(() => _change = double.tryParse(v) ?? 0),
            ),
            const SizedBox(height: 12),

            // Stock history
            Text('Recent Stock History',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Expanded(
              child: ref.watch(stockHistoryProvider(widget.itemId)).when(
                    loading: () => const Center(
                        child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (history) => ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (_, i) {
                        final h = history[i];
                        final isAdd = h.changeAmount > 0;
                        return ListTile(
                          leading: Icon(
                            isAdd
                                ? Icons.add_circle_rounded
                                : Icons.remove_circle_rounded,
                            color: isAdd ? AppColors.success : AppColors.error,
                          ),
                          title: Text(
                            '${isAdd ? '+' : ''}${AppFormatters.quantity(h.changeAmount)}',
                            style: TextStyle(
                                color: isAdd ? AppColors.success : AppColors.error,
                                fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(h.reason),
                          trailing: Text(
                            AppFormatters.dateFromString(h.createdAt.toIso8601String()),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textHint),
                          ),
                        );
                      },
                    ),
                  ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        color: Colors.white,
        child: ElevatedButton.icon(
          onPressed: _change > 0 ? _adjust : null,
          icon: Icon(_isAdd ? Icons.add_rounded : Icons.remove_rounded),
          label: Text(_isAdd ? 'Add Stock' : 'Remove Stock'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isAdd ? AppColors.success : AppColors.error,
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
      ),
    );
  }

  Future<void> _adjust() async {
    final change = _isAdd ? _change : -_change;
    await ref
        .read(inventoryProvider.notifier)
        .adjustStock(widget.itemId, change, 'manual');
    if (mounted) {
      SnackbarHelper.showSuccess(context, 'Stock updated');
      Navigator.of(context).pop();
    }
  }
}
