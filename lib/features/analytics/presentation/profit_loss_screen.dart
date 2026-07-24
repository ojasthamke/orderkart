import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../order/presentation/order_provider.dart';

class ProfitLossScreen extends ConsumerWidget {
  const ProfitLossScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plAsync = ref.watch(profitLossProvider);

    return AppScaffold(
      title: 'Profit & Loss Statement',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(profitLossProvider),
        ),
      ],
      body: plAsync.when(
        loading: () => const LoadingShimmer(count: 3),
        error: (err, _) => Center(child: Text('Error calculating P&L: $err')),
        data: (pl) {
          final double revenue = pl['total_revenue'] ?? 0.0;
          final double cogs = pl['cogs'] ?? 0.0;
          final double grossProfit = pl['gross_profit'] ?? 0.0;
          final double expenses = pl['total_expenses'] ?? 0.0;
          final double discounts = pl['total_discounts'] ?? 0.0;
          final double delivery = pl['delivery_income'] ?? 0.0;
          final double netProfit = pl['net_profit'] ?? 0.0;
          final double marginPct = pl['profit_margin_pct'] ?? 0.0;
          final bool isProfitable = pl['is_profitable'] ?? true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Big Net Profit / Loss Header Card ─────────────────────
                Builder(builder: (ctx) {
                  final isDark = Theme.of(ctx).brightness == Brightness.dark;
                  final bannerColor = isProfitable
                      ? (isDark
                          ? Colors.green.withOpacity(0.20)
                          : Colors.green.shade100.withOpacity(0.50))
                      : (isDark
                          ? Colors.red.withOpacity(0.20)
                          : Colors.red.shade100.withOpacity(0.50));
                  final bannerBorder = isProfitable
                      ? (isDark
                          ? Colors.green.withOpacity(0.40)
                          : Colors.green.shade200.withOpacity(0.60))
                      : (isDark
                          ? Colors.red.withOpacity(0.40)
                          : Colors.red.shade200.withOpacity(0.60));
                  final textColor = isProfitable
                      ? (isDark ? Colors.white : Colors.green.shade900)
                      : (isDark ? Colors.white : Colors.red.shade900);
                  final secTextColor = isProfitable
                      ? (isDark ? Colors.white70 : Colors.green.shade700)
                      : (isDark ? Colors.white70 : Colors.red.shade700);
                  final badgeBgColor = isProfitable
                      ? (isDark
                          ? Colors.white.withOpacity(0.15)
                          : Colors.green.shade200.withOpacity(0.60))
                      : (isDark
                          ? Colors.white.withOpacity(0.15)
                          : Colors.red.shade200.withOpacity(0.60));
                  final badgeTextColor = isProfitable
                      ? (isDark ? Colors.white : Colors.green.shade900)
                      : (isDark ? Colors.white : Colors.red.shade900);

                  return GlassContainer(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    borderRadius: BorderRadius.circular(24),
                    color: bannerColor,
                    borderColor: bannerBorder,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isProfitable
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: textColor,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isProfitable ? 'NET PROFIT' : 'NET LOSS',
                              style: TextStyle(
                                color: secTextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppFormatters.currency(netProfit.abs()),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: badgeBgColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${isProfitable ? '+' : ''}${marginPct.toStringAsFixed(1)}% Net Margin',
                            style: TextStyle(
                              color: badgeTextColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 20),

                // ── Interactive Financial Profit Radar Card ───────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderColor(context)),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.pie_chart_outline_rounded,
                                  color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text('Financial Radar Breakdown',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Live Ratio',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRadarBar('Sales', revenue,
                                revenue > 0 ? 1.0 : 0.0, AppColors.success),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildRadarBar(
                                'COGS',
                                cogs,
                                revenue > 0
                                    ? (cogs / revenue).clamp(0.0, 1.0)
                                    : 0.0,
                                Colors.orange),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildRadarBar(
                                'Expenses',
                                expenses,
                                revenue > 0
                                    ? (expenses / revenue).clamp(0.0, 1.0)
                                    : 0.0,
                                AppColors.error),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildRadarBar(
                                'Net',
                                netProfit,
                                revenue > 0
                                    ? (netProfit / revenue).clamp(0.0, 1.0)
                                    : 0.0,
                                AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Detailed Calculation Breakdown ─────────────────────────
                Text(
                  'Mathematical Calculation Breakdown',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      // 1. Gross Revenue
                      _calcRow(
                        context,
                        symbol: '+',
                        symbolColor: AppColors.success,
                        label: 'Gross Sales Revenue',
                        subtitle: 'Total billings from delivered orders',
                        amount: revenue,
                      ),
                      const Divider(height: 24),

                      // 2. Cost of Goods Sold
                      _calcRow(
                        context,
                        symbol: '−',
                        symbolColor: AppColors.error,
                        label: 'Cost of Goods Sold (COGS)',
                        subtitle: 'Purchase cost of inventory items sold',
                        amount: cogs,
                      ),
                      const Divider(height: 24),

                      // 3. Gross Profit Line
                      _calcRow(
                        context,
                        symbol: '=',
                        symbolColor: AppColors.primary,
                        label: 'Gross Profit',
                        subtitle: 'Revenue minus COGS',
                        amount: grossProfit,
                        isBold: true,
                        amountColor: grossProfit >= 0
                            ? AppColors.primary
                            : AppColors.error,
                      ),
                      const Divider(height: 24, thickness: 1.5),

                      // 4. Operating Expenses
                      _calcRow(
                        context,
                        symbol: '−',
                        symbolColor: AppColors.error,
                        label: 'Operating Expenses',
                        subtitle: 'Shop expenses (rent, fuel, salaries, etc.)',
                        amount: expenses,
                      ),
                      const Divider(height: 24),

                      // 5. Discounts Given
                      if (discounts > 0) ...[
                        _calcRow(
                          context,
                          symbol: '−',
                          symbolColor: AppColors.warning,
                          label: 'Discounts Allowed',
                          subtitle: 'Total promotional price discounts',
                          amount: discounts,
                        ),
                        const Divider(height: 24),
                      ],

                      // 6. Delivery Fees Income
                      if (delivery > 0) ...[
                        _calcRow(
                          context,
                          symbol: '+',
                          symbolColor: AppColors.success,
                          label: 'Delivery Fees Collected',
                          subtitle: 'Delivery service charges earned',
                          amount: delivery,
                        ),
                        const Divider(height: 24),
                      ],

                      // 7. Net Profit Final Total
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (isProfitable
                                  ? AppColors.success
                                  : AppColors.error)
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: (isProfitable
                                    ? AppColors.success
                                    : AppColors.error)
                                .withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'NET PROFIT / LOSS',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: isProfitable
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                            Text(
                              AppFormatters.currency(netProfit),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isProfitable
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Percentage Analysis Ratios ──────────────────────────────
                Text(
                  'Financial Ratios & Ratios Breakdown',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      _ratioBar(
                        context,
                        label: 'Cost of Goods (COGS)',
                        amount: cogs,
                        total: revenue,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      _ratioBar(
                        context,
                        label: 'Operating Expenses',
                        amount: expenses,
                        total: revenue,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 16),
                      _ratioBar(
                        context,
                        label: 'Net Retained Profit',
                        amount: netProfit > 0 ? netProfit : 0,
                        total: revenue,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _calcRow(
    BuildContext context, {
    required String symbol,
    required Color symbolColor,
    required String label,
    required String subtitle,
    required double amount,
    bool isBold = false,
    Color? amountColor,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: symbolColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            symbol,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: symbolColor,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: isBold ? 15 : 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondaryColor(context)),
              ),
            ],
          ),
        ),
        Text(
          AppFormatters.currency(amount),
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            fontSize: isBold ? 16 : 14,
            color: amountColor ?? AppColors.textPrimaryColor(context),
          ),
        ),
      ],
    );
  }

  Widget _ratioBar(
    BuildContext context, {
    required String label,
    required double amount,
    required double total,
    required Color color,
  }) {
    final pct = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(
              '${AppFormatters.currency(amount)} (${(pct * 100).toStringAsFixed(1)}%)',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: color, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white12
              : AppColors.gray200,
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildRadarBar(String label, double val, double ratio, Color col) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 60,
              width: 14,
              decoration: BoxDecoration(
                color: col.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: (60 * ratio).clamp(4.0, 60.0),
              width: 14,
              decoration: BoxDecoration(
                color: col,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${(ratio * 100).toStringAsFixed(0)}%',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: col),
          ),
        ),
      ],
    );
  }
}
