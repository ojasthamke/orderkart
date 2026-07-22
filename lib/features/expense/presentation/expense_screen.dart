import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/scale_on_tap.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../domain/expense.dart';
import 'expense_provider.dart';
import '../../settings/presentation/settings_provider.dart';

class ExpenseScreen extends ConsumerWidget {
  final bool showBack;
  const ExpenseScreen({super.key, this.showBack = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expenseProvider);
    final summaryAsync  = ref.watch(monthlySummaryProvider);
    final settingsVal   = ref.watch(settingsProvider).valueOrNull;
    final currency      = settingsVal?.currency ?? '₹';

    return AppScaffold(
      title: 'Expenses',
      showBack: showBack,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: showBack ? 0 : 100),
        child: FloatingActionButton(
          heroTag: 'add_expense',
          onPressed: () => Navigator.of(context)
              .pushNamed(AppRoutes.addEditExpense)
              .then((_) {
            ref.invalidate(expenseProvider);
            ref.invalidate(monthlySummaryProvider);
          }),
          child: const Icon(Icons.add_rounded),
        ),
      ),
      body: Column(
        children: [
          CustomSearchBar(
            hint: 'Search expenses...',
            onChanged: (q) => ref.read(expenseProvider.notifier).search(q),
          ),
          // Monthly summary card
          summaryAsync.when(
            data: (summary) => summary.isEmpty
                ? const SizedBox.shrink()
                : _MonthlySummaryCard(summary: summary, currency: currency),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: expensesAsync.when(
              loading: () => const LoadingShimmer(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (expenses) => expenses.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.receipt_long_rounded,
                      title: 'No Expenses Yet',
                      subtitle: 'Track your business expenses here',
                      actionLabel: 'Add Expense',
                      onAction: () => Navigator.of(context)
                          .pushNamed(AppRoutes.addEditExpense)
                          .then((_) => ref.invalidate(expenseProvider)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: expenses.length,
                      itemBuilder: (ctx, i) => _ExpenseCard(
                        expense: expenses[i],
                        currency: currency,
                        onEdit: () => Navigator.of(ctx)
                            .pushNamed(AppRoutes.addEditExpense,
                                arguments: {'expenseId': expenses[i].id})
                            .then((_) {
                          ref.invalidate(expenseProvider);
                          ref.invalidate(monthlySummaryProvider);
                        }),
                        onDelete: () async {
                          final ok = await ConfirmDeleteDialog.show(
                            ctx,
                            title:   'Delete Expense',
                            message: 'Delete "${expenses[i].name}"?',
                          );
                          if (!ok) return;
                          await ref.read(expenseProvider.notifier).delete(expenses[i].id);
                          ref.invalidate(monthlySummaryProvider);
                        },
                      ).animate(delay: (i * 30).ms).fadeIn(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  final List<Map<String, dynamic>> summary;
  final String currency;
  const _MonthlySummaryCard({required this.summary, required this.currency});

  @override
  Widget build(BuildContext context) {
    final thisMonth = summary.firstOrNull;
    if (thisMonth == null) return const SizedBox.shrink();

    final total = (thisMonth['total'] as num?)?.toDouble() ?? 0;
    final count = thisMonth['count'] as int? ?? 0;
    final month = thisMonth['month'] as String? ?? '';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.red.shade900;
    final secTextColor = isDark ? Colors.white70 : Colors.red.shade700;
    final iconColor = isDark ? Colors.redAccent.shade100 : Colors.red.shade700;

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      color: isDark ? Colors.red.withOpacity(0.20) : Colors.red.shade100.withOpacity(0.50),
      borderColor: isDark ? Colors.red.withOpacity(0.40) : Colors.red.shade200.withOpacity(0.60),
      child: Row(
        children: [
          Icon(Icons.trending_down_rounded, color: iconColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This Month ($month)',
                    style: TextStyle(
                        color: secTextColor, fontSize: 12)),
                Text(AppFormatters.currency(total, symbol: currency),
                    style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                Text('$count expense(s)',
                    style: TextStyle(
                        color: secTextColor, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.expense,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleOnTap(
      onTap: onEdit,
      child: GlassContainer(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: GestureDetector(
          onTap: expense.receiptPhotoPath.isNotEmpty
              ? () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: InteractiveViewer(
                        child: expense.receiptPhotoPath.startsWith('http')
                            ? Image.network(expense.receiptPhotoPath)
                            : Image.file(File(expense.receiptPhotoPath)),
                      ),
                    ),
                  );
                }
              : null,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.errorSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: expense.receiptPhotoPath.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: expense.receiptPhotoPath.startsWith('http')
                        ? Image.network(
                            expense.receiptPhotoPath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.receipt_long_rounded, color: AppColors.error),
                          )
                        : Image.file(
                            File(expense.receiptPhotoPath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.receipt_long_rounded, color: AppColors.error),
                          ),
                  )
                : const Icon(Icons.receipt_rounded, color: AppColors.error),
          ),
        ),
        title: Text(expense.name,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${expense.category} • ${AppFormatters.date(expense.date)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            Text(
              AppFormatters.paymentMethod(expense.paymentMethod),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.textHint),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppFormatters.currency(expense.amount, symbol: currency),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.gray500, size: 20),
              onSelected: (v) {
                if (v == 'edit')   onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit',   child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}
