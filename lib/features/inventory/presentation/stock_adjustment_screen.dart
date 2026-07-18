import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import 'inventory_provider.dart';
import '../data/item_dao.dart';
import '../../expense/domain/expense.dart';
import '../../expense/data/expense_dao.dart';

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
  final _reasonCon  = TextEditingController();
  double _change    = 0;
  String _mode      = 'add'; // 'add', 'remove', 'wastage'
  bool   _autoLogExpense = true;

  @override
  void dispose() {
    _changeCon.dispose();
    _reasonCon.dispose();
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

            // Mode Selector Chips (Add / Remove / Wastage)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      AppHaptics.selection();
                      setState(() => _mode = 'add');
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _mode == 'add' ? AppColors.success : AppColors.gray100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '+ Add',
                          style: TextStyle(
                            color: _mode == 'add' ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      AppHaptics.selection();
                      setState(() => _mode = 'remove');
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _mode == 'remove' ? AppColors.error : AppColors.gray100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '- Remove',
                          style: TextStyle(
                            color: _mode == 'remove' ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      AppHaptics.selection();
                      setState(() => _mode = 'wastage');
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _mode == 'wastage' ? Colors.amber.shade800 : AppColors.gray100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '🍏 Wastage',
                          style: TextStyle(
                            color: _mode == 'wastage' ? Colors.white : AppColors.textSecondary,
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
                labelText: _mode == 'wastage' ? 'Wastage Quantity' : 'Quantity',
                prefixIcon: Icon(
                  _mode == 'add'
                      ? Icons.add_circle_outline_rounded
                      : (_mode == 'wastage' ? Icons.delete_outline_rounded : Icons.remove_circle_outline_rounded),
                  color: _mode == 'add' ? AppColors.success : (_mode == 'wastage' ? Colors.amber.shade800 : AppColors.error),
                ),
              ),
              onChanged: (v) =>
                  setState(() => _change = double.tryParse(v) ?? 0),
            ),
            if (_mode == 'wastage') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonCon,
                decoration: const InputDecoration(
                  labelText: 'Wastage Reason (Optional)',
                  hintText: 'e.g. Rotten mandi batch, Transport loss',
                  prefixIcon: Icon(Icons.note_alt_rounded),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-log Expense under 🍏 Spoilage & Damaged Goods', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                value: _autoLogExpense,
                onChanged: (v) => setState(() => _autoLogExpense = v ?? true),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
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
          icon: Icon(_mode == 'add' ? Icons.add_rounded : (_mode == 'wastage' ? Icons.delete_outline_rounded : Icons.remove_rounded)),
          label: Text(_mode == 'add' ? 'Add Stock' : (_mode == 'wastage' ? 'Record Wastage' : 'Remove Stock')),
          style: ElevatedButton.styleFrom(
            backgroundColor: _mode == 'add' ? AppColors.success : (_mode == 'wastage' ? Colors.amber.shade800 : AppColors.error),
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
      ),
    );
  }

  Future<void> _adjust() async {
    AppHaptics.primarySave();
    if (_mode == 'wastage') {
      final reason = _reasonCon.text.trim().isEmpty ? 'Wastage / Spoilage loss' : _reasonCon.text.trim();
      await ref.read(inventoryProvider.notifier).adjustStock(widget.itemId, -_change, 'Wastage: $reason');
      
      if (_autoLogExpense) {
        final itemObj = await ItemDao().getItemById(widget.itemId);
        final rate = (itemObj?.costPrice != null && itemObj!.costPrice > 0)
            ? itemObj.costPrice
            : (itemObj?.sellingPrice ?? 0.0);
        final costLoss = _change * rate;
        if (costLoss > 0) {
          await ExpenseDao().insertExpense(
            Expense(
              id: '',
              name: 'Wastage: ${widget.itemName} (${AppFormatters.quantity(_change)})',
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
      }
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Wastage of ${AppFormatters.quantity(_change)} recorded');
        Navigator.of(context).pop();
      }
    } else {
      final change = _mode == 'add' ? _change : -_change;
      await ref
          .read(inventoryProvider.notifier)
          .adjustStock(widget.itemId, change, _mode == 'add' ? 'Stock added' : 'Stock reduced');
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Stock updated');
        Navigator.of(context).pop();
      }
    }
  }
}
