import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/customer_avatar.dart';
import '../../order/presentation/order_provider.dart';
import 'analytics_provider.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _selectedSection = 'overview'; // 'overview', 'items', 'customers', 'peak', 'deadstock', 'debt'
  String _topCustomersSort = 'purchase'; // 'purchase', 'orders', 'pending'
  String _chartRange = 'weekly'; // 'weekly', 'monthly'
  String? _expandedKpi;

  // Sub-filters
  String _itemMatrixFilter = 'cash_cows'; // 'cash_cows', 'high_margin', 'low_margin', 'all'
  int _itemMatrixDays = 30;
  int _deadStockDays = 14;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(analyticsSummaryProvider);

    return AppScaffold(
      title: 'Business Analytics & Stats',
      actions: [
        IconButton(
          icon: const Icon(Icons.calculate_rounded),
          tooltip: 'Profit & Loss Statement',
          onPressed: () {
            AppHaptics.buttonClick();
            Navigator.of(context).pushNamed(AppRoutes.profitLoss);
          },
        ),
        IconButton(
          icon: const Icon(Icons.trending_down_rounded),
          tooltip: 'Churn Risk Analytics',
          onPressed: () {
            AppHaptics.buttonClick();
            Navigator.of(context).pushNamed(AppRoutes.churnRisk);
          },
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsSummaryProvider);
          ref.invalidate(weeklyChartProvider);
          ref.invalidate(monthlyChartProvider);
          ref.invalidate(topCustomersProvider);
          ref.invalidate(itemProfitabilityMatrixProvider);
          ref.invalidate(customerProfitContributionProvider);
          ref.invalidate(peakSalesAnalyticsProvider);
          ref.invalidate(deadStockAnalyticsProvider);
          ref.invalidate(cashflowDebtAgingProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section Selector Pills ────────────────────────────────────
              _buildSectionSelector(),
              const SizedBox(height: 16),

              // ── Active Section Body ───────────────────────────────────────
              if (_selectedSection == 'overview')
                _buildOverviewSection(summaryAsync)
              else if (_selectedSection == 'items')
                _buildItemProfitabilitySection()
              else if (_selectedSection == 'customers')
                _buildCustomerLtvSection()
              else if (_selectedSection == 'peak')
                _buildPeakHoursSection()
              else if (_selectedSection == 'deadstock')
                _buildDeadStockSection()
              else if (_selectedSection == 'debt')
                _buildDebtAgingSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SECTION SELECTOR
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildSectionSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sections = [
      {'id': 'overview', 'label': 'Overview', 'icon': Icons.insights_rounded},
      {'id': 'items', 'label': 'Item Margins', 'icon': Icons.leaderboard_rounded},
      {'id': 'customers', 'label': 'Customer LTV', 'icon': Icons.people_alt_rounded},
      {'id': 'peak', 'label': 'Peak Hours', 'icon': Icons.access_time_filled_rounded},
      {'id': 'deadstock', 'label': 'Dead Stock', 'icon': Icons.inventory_2_rounded},
      {'id': 'debt', 'label': 'Debt Aging', 'icon': Icons.schedule_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sections.map((s) {
          final id = s['id'] as String;
          final label = s['label'] as String;
          final icon = s['icon'] as IconData;
          final isSelected = _selectedSection == id;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : AppColors.primary),
              ),
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
              onSelected: (v) {
                if (v) {
                  AppHaptics.selection();
                  setState(() => _selectedSection = id);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. OVERVIEW & KPI RADAR SECTION
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildOverviewSection(AsyncValue<Map<String, dynamic>> summaryAsync) {
    final weeklySalesAsync = ref.watch(weeklyChartProvider);
    final monthlySalesAsync = ref.watch(monthlyChartProvider);
    final topCustomersAsync = ref.watch(topCustomersProvider);

    return summaryAsync.when(
      loading: () => const LoadingShimmer(),
      error: (e, _) => Center(child: Text('Error loading stats: $e')),
      data: (summary) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor =
            isDark ? const Color(0xFF1E293B).withOpacity(0.55) : Colors.white;
        final borderColor =
            isDark ? Colors.white.withOpacity(0.12) : AppColors.gray200;

        final double todaySales = summary['today_sales'] ?? 0;
        final double monthlySales = summary['monthly_sales'] ?? 0;
        final double pendingPayments = summary['pending_payments'] ?? 0;
        final double totalExpenses = summary['total_expenses'] ?? 0;
        final int orderCount = summary['order_count'] ?? 0;
        final int deliveredCount = summary['delivered_count'] ?? 0;
        final int pendingCount = summary['pending_count'] ?? 0;
        final int cancelledCount = summary['cancelled_count'] ?? 0;

        final topItems = summary['top_items'] as List<dynamic>? ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Live Daily & Accumulated Profit Bar ───────────────────────────
            Consumer(
              builder: (context, ref, _) {
                final todayVsYestAsync =
                    ref.watch(todayVsYesterdayProfitProvider);
                return todayVsYestAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (data) {
                    final today = data['today'] as Map<String, dynamic>;
                    final yesterday =
                        data['yesterday'] as Map<String, dynamic>;
                    final double todayProfit =
                        (today['net_profit'] as num?)?.toDouble() ?? 0.0;
                    final double yestProfit =
                        (yesterday['net_profit'] as num?)?.toDouble() ?? 0.0;
                    final double profitDiff =
                        (data['profit_diff'] as num?)?.toDouble() ?? 0.0;
                    final double profitGrowthPct =
                        (data['profit_growth_pct'] as num?)?.toDouble() ??
                            0.0;
                    final bool isGrowth =
                        data['is_growth'] as bool? ?? true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                          Icons.show_chart_rounded,
                                          size: 16,
                                          color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'PROFIT PERFORMANCE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () => Navigator.of(context)
                                      .pushNamed(AppRoutes.profitLoss),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Full P&L Report',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(Icons.arrow_forward_ios_rounded,
                                            size: 10,
                                            color: AppColors.primary),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: AppColors.primary
                                              .withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Today\'s Net Profit',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors
                                                    .textSecondary)),
                                        const SizedBox(height: 2),
                                        Text(
                                          AppFormatters.currency(todayProfit),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: todayProfit >= 0
                                                ? AppColors.success
                                                : AppColors.error,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${today['orders_count']} orders (${((today['profit_margin_pct'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}% margin)',
                                          style: const TextStyle(
                                              fontSize: 9.5,
                                              color: AppColors
                                                  .textSecondary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Pure: ${AppFormatters.currency((today['pure_profit'] as num?)?.toDouble() ?? 0.0)} (${((today['orders_count'] as num?)?.toInt() ?? 0) > 0 ? AppFormatters.currency((today['pure_profit_per_order'] as num?)?.toDouble() ?? 0.0) : "₹0"}/ord)',
                                          style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: Colors.grey
                                              .withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Yesterday\'s Net Profit',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors
                                                    .textSecondary)),
                                        const SizedBox(height: 2),
                                        Text(
                                          AppFormatters.currency(yestProfit),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: yestProfit >= 0
                                                ? AppColors.success
                                                : AppColors.error,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${yesterday['orders_count']} orders (${((yesterday['profit_margin_pct'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}% margin)',
                                          style: const TextStyle(
                                              fontSize: 9.5,
                                              color: AppColors
                                                  .textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Daily Difference: ${profitDiff >= 0 ? '+' : ''}${AppFormatters.currency(profitDiff)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isGrowth
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                                Text(
                                  '${isGrowth ? '▲ +' : '▼ '}${profitGrowthPct.toStringAsFixed(1)}% vs Yesterday',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isGrowth
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // KPI Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.15,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                InkWell(
                  onTap: () => setState(() => _expandedKpi = _expandedKpi == 'today' ? null : 'today'),
                  borderRadius: BorderRadius.circular(16),
                  child: StatCard(
                    label: "Today's Sales",
                    value: AppFormatters.currency(todaySales),
                    icon: Icons.today_rounded,
                    color: AppColors.primary,
                    trendText: _expandedKpi == 'today' ? 'Hide ▲' : 'Live ▾',
                    trendColor: AppColors.primary,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _expandedKpi = _expandedKpi == 'month' ? null : 'month'),
                  borderRadius: BorderRadius.circular(16),
                  child: StatCard(
                    label: 'This Month',
                    value: AppFormatters.currency(monthlySales),
                    icon: Icons.trending_up_rounded,
                    color: AppColors.success,
                    trendText: _expandedKpi == 'month' ? 'Hide ▲' : 'Month ▾',
                    trendColor: AppColors.success,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _expandedKpi = _expandedKpi == 'expense' ? null : 'expense'),
                  borderRadius: BorderRadius.circular(16),
                  child: StatCard(
                    label: 'Expenses',
                    value: AppFormatters.currency(totalExpenses),
                    icon: Icons.trending_down_rounded,
                    color: AppColors.error,
                    trendText: _expandedKpi == 'expense' ? 'Hide ▲' : 'Tracked ▾',
                    trendColor: AppColors.error,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _expandedKpi = _expandedKpi == 'pending' ? null : 'pending'),
                  borderRadius: BorderRadius.circular(16),
                  child: StatCard(
                    label: 'Pending Dues',
                    value: AppFormatters.currency(pendingPayments),
                    icon: Icons.pending_actions_rounded,
                    color: AppColors.warning,
                    trendText: _expandedKpi == 'pending'
                        ? 'Hide ▲'
                        : (pendingPayments > 0 ? 'Action Needed ▾' : 'Clear ✓'),
                    trendColor: pendingPayments > 0
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                ),
              ],
            ),

            if (_expandedKpi != null) ...[
              const SizedBox(height: 12),
              _buildExpandedKpiCard(_expandedKpi!, summary),
            ],

            const SizedBox(height: 24),

            // Revenue Trend Chart
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sales & Revenue Trend',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Last 7 Days'),
                      selected: _chartRange == 'weekly',
                      onSelected: (v) {
                        if (v) setState(() => _chartRange = 'weekly');
                      },
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Monthly'),
                      selected: _chartRange == 'monthly',
                      onSelected: (v) {
                        if (v) setState(() => _chartRange = 'monthly');
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(20),
              color: cardColor,
              borderColor: borderColor,
              child: SizedBox(
                height: 200,
                child: _chartRange == 'weekly'
                    ? weeklySalesAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (data) => _buildChart(data, 'day'),
                      )
                    : monthlySalesAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (data) => _buildChart(data, 'month'),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Order Status Distribution
            Text(
              'Order Fulfillment Status',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(20),
              color: cardColor,
              borderColor: borderColor,
              child: Column(
                children: [
                  _paymentSplitRow(context, 'Delivered Orders', deliveredCount.toDouble(), orderCount.toDouble(), AppColors.success),
                  const SizedBox(height: 12),
                  _paymentSplitRow(context, 'Pending Orders', pendingCount.toDouble(), orderCount.toDouble(), AppColors.warning),
                  const SizedBox(height: 12),
                  _paymentSplitRow(context, 'Cancelled Orders', cancelledCount.toDouble(), orderCount.toDouble(), AppColors.error),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Top Selling Items
            Text(
              'Top Selling Products',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            GlassContainer(
              padding: const EdgeInsets.symmetric(vertical: 8),
              borderRadius: BorderRadius.circular(20),
              color: cardColor,
              borderColor: borderColor,
              child: topItems.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text('No order items found yet.')),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: topItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final it = topItems[i];
                        final String name = it['item_name'] ?? 'Item';
                        final double revenue =
                            (it['revenue'] as num?)?.toDouble() ?? 0;
                        final double qty =
                            (it['qty'] as num?)?.toDouble() ?? 0;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primarySurface,
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700)),
                          ),
                          title: Text(name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('Sold Qty: ${AppFormatters.quantity(qty)}'),
                          trailing: Text(AppFormatters.currency(revenue),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success)),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 24),

            // Top Customers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Customers',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Purchase'),
                      selected: _topCustomersSort == 'purchase',
                      onSelected: (val) {
                        if (val) setState(() => _topCustomersSort = 'purchase');
                      },
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Orders'),
                      selected: _topCustomersSort == 'orders',
                      onSelected: (val) {
                        if (val) setState(() => _topCustomersSort = 'orders');
                      },
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Due'),
                      selected: _topCustomersSort == 'pending',
                      onSelected: (val) {
                        if (val) setState(() => _topCustomersSort = 'pending');
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            topCustomersAsync.when(
              loading: () => const LoadingShimmer(count: 3),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (customers) {
                if (customers.isEmpty) {
                  return const Center(child: Text('No customers found.'));
                }

                final sorted = List<Map<String, dynamic>>.from(customers);
                if (_topCustomersSort == 'purchase') {
                  sorted.sort((a, b) => ((b['total_purchase'] as num?)?.toDouble() ?? 0)
                      .compareTo((a['total_purchase'] as num?)?.toDouble() ?? 0));
                } else if (_topCustomersSort == 'orders') {
                  sorted.sort((a, b) => ((b['total_orders'] as num?)?.toInt() ?? 0)
                      .compareTo((a['total_orders'] as num?)?.toInt() ?? 0));
                } else if (_topCustomersSort == 'pending') {
                  sorted.sort((a, b) => ((b['pending_amount'] as num?)?.toDouble() ?? 0)
                      .compareTo((a['pending_amount'] as num?)?.toDouble() ?? 0));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sorted.take(5).length,
                  itemBuilder: (ctx, i) {
                    final c = sorted[i];
                    final String name = c['name'] ?? 'Customer';
                    final double purchase =
                        (c['total_purchase'] as num?)?.toDouble() ?? 0;
                    final int orders = (c['total_orders'] as num?)?.toInt() ?? 0;
                    final double pending =
                        (c['pending_amount'] as num?)?.toDouble() ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: CustomerAvatar(
                          photoPath: c['photo_path'],
                          radius: 20,
                        ),
                        title: Text(name,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$orders orders • ${AppFormatters.currency(purchase)} total'),
                        trailing: pending > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Due: ${AppFormatters.currency(pending)}',
                                  style: const TextStyle(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              )
                            : const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. ITEM PROFITABILITY & MARGIN MATRIX
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildItemProfitabilitySection() {
    final matrixAsync = ref.watch(itemProfitabilityMatrixProvider(_itemMatrixDays));

    return matrixAsync.when(
      loading: () => const LoadingShimmer(count: 4),
      error: (e, _) => Center(child: Text('Error loading item matrix: $e')),
      data: (data) {
        final List<dynamic> all = data['all_items'] ?? [];
        final List<dynamic> cashCows = data['cash_cows'] ?? [];
        final List<dynamic> highMargin = data['high_margin_stars'] ?? [];
        final List<dynamic> lowMargin = data['low_margin_alerts'] ?? [];

        final double overallRev = (data['overall_revenue'] as num?)?.toDouble() ?? 0;
        final double overallProfit = (data['overall_profit'] as num?)?.toDouble() ?? 0;
        final double overallMargin = (data['overall_margin_pct'] as num?)?.toDouble() ?? 0;

        List<dynamic> activeList;
        if (_itemMatrixFilter == 'cash_cows') {
          activeList = cashCows;
        } else if (_itemMatrixFilter == 'high_margin') {
          activeList = highMargin;
        } else if (_itemMatrixFilter == 'low_margin') {
          activeList = lowMargin;
        } else {
          activeList = all;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Executive Profit Summary Banner
            GlassContainer(
              padding: const EdgeInsets.all(18),
              borderRadius: BorderRadius.circular(20),
              color: AppColors.primary.withOpacity(0.12),
              borderColor: AppColors.primary.withOpacity(0.3),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ITEM PROFITABILITY RADAR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: AppColors.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${overallMargin.toStringAsFixed(1)}% Avg Margin',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: AppColors.success,
                          ),
                        ),
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
                          const Text('Total Net Profit',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.currency(overallProfit),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Total Sales Volume',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.currency(overallRev),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMatrixChip('⭐ Cash Cows (${cashCows.length})', 'cash_cows'),
                  const SizedBox(width: 8),
                  _buildMatrixChip('🚀 High Margin (${highMargin.length})', 'high_margin'),
                  const SizedBox(width: 8),
                  _buildMatrixChip('⚠️ Low Margin Risk (${lowMargin.length})', 'low_margin'),
                  const SizedBox(width: 8),
                  _buildMatrixChip('All Products (${all.length})', 'all'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Item Cards List
            if (activeList.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('No items found in this category.'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeList.length,
                itemBuilder: (ctx, i) {
                  final it = activeList[i];
                  final String name = it['name'] ?? 'Unnamed';
                  final String cat = it['category'] ?? 'General';
                  final String unit = it['unit'] ?? '';
                  final double qty = (it['qty_sold'] as num?)?.toDouble() ?? 0;
                  final double rev = (it['revenue'] as num?)?.toDouble() ?? 0;
                  final double profit = (it['profit'] as num?)?.toDouble() ?? 0;
                  final double margin = (it['margin_pct'] as num?)?.toDouble() ?? 0;
                  final double curCost = (it['current_cost'] as num?)?.toDouble() ?? 0;
                  final double curSell = (it['current_selling'] as num?)?.toDouble() ?? 0;

                  final bool isLow = margin < 12.0 || profit < 0;

                  return GlassContainer(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    borderRadius: BorderRadius.circular(16),
                    borderColor: isLow ? Colors.red.withOpacity(0.3) : null,
                    child: Column(
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
                                    name,
                                    style: const TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '$cat • Sold: ${AppFormatters.quantity(qty)} $unit',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isLow ? Colors.red : Colors.green)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${margin.toStringAsFixed(1)}% margin',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isLow ? Colors.red : Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _miniPeriodStat('Revenue', AppFormatters.currency(rev)),
                            _miniPeriodStat('Profit Generated', AppFormatters.currency(profit)),
                            _miniPeriodStat('Live Price', '${AppFormatters.currency(curSell)} / $unit'),
                            _miniPeriodStat('Cost Price', '${AppFormatters.currency(curCost)} / $unit'),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildMatrixChip(String label, String id) {
    final isSelected = _itemMatrixFilter == id;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: isSelected ? Colors.white : null),
      onSelected: (v) {
        if (v) setState(() => _itemMatrixFilter = id);
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. CUSTOMER LIFETIME VALUE & PROFIT CONTRIBUTION
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildCustomerLtvSection() {
    final ltvAsync = ref.watch(customerProfitContributionProvider);

    return ltvAsync.when(
      loading: () => const LoadingShimmer(count: 4),
      error: (e, _) => Center(child: Text('Error loading customer LTV: $e')),
      data: (customers) {
        if (customers.isEmpty) {
          return const Center(child: Text('No customer order history found.'));
        }

        double totalContributedProfit = 0;
        for (final c in customers) {
          totalContributedProfit += (c['profit_contribution'] as double);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Executive Header Banner
            GlassContainer(
              padding: const EdgeInsets.all(18),
              borderRadius: BorderRadius.circular(20),
              color: Colors.indigo.withOpacity(0.12),
              borderColor: Colors.indigo.withOpacity(0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CUSTOMER PROFIT VALUE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppFormatters.currency(totalContributedProfit),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${customers.length} Accounts',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Customers Ranked by Net Profit Contribution',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: customers.length,
              itemBuilder: (ctx, idx) {
                final c = customers[idx];
                final String name = c['name'] ?? 'Unknown';
                final String phone = c['phone'] ?? '';
                final double profit = (c['profit_contribution'] as double);
                final double rev = (c['total_revenue'] as double);
                final double aov = (c['aov'] as double);
                final double margin = (c['profit_margin_pct'] as double);
                final int orders = (c['total_orders'] as int);
                final double pending = (c['outstanding_balance'] as double);
                final bool isVip = (c['is_vip'] as bool);

                return GlassContainer(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CustomerAvatar(
                                photoPath: c['photo_path'],
                                radius: 18,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      if (isVip) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.star_rounded,
                                            color: Colors.amber, size: 16),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    phone.isNotEmpty ? phone : '$orders orders total',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '+${AppFormatters.currency(profit)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: AppColors.success,
                                ),
                              ),
                              Text(
                                '${margin.toStringAsFixed(1)}% profit share',
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _miniPeriodStat('Orders', '$orders'),
                          _miniPeriodStat('Avg Order (AOV)', AppFormatters.currency(aov)),
                          _miniPeriodStat('Total Sales', AppFormatters.currency(rev)),
                          _miniPeriodStat(
                            'Balance Due',
                            pending > 0 ? AppFormatters.currency(pending) : 'Clear ✓',
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 4. PEAK OPERATING HOURS & DAYS HEATMAP
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildPeakHoursSection() {
    final peakAsync = ref.watch(peakSalesAnalyticsProvider);

    return peakAsync.when(
      loading: () => const LoadingShimmer(count: 3),
      error: (e, _) => Center(child: Text('Error loading peak hours: $e')),
      data: (data) {
        final String peakHour = data['peak_hour'] ?? 'N/A';
        final int peakHourOrders = (data['peak_hour_orders'] as num?)?.toInt() ?? 0;
        final String bestDay = data['best_day'] ?? 'N/A';
        final double bestDayRev = (data['best_day_revenue'] as num?)?.toDouble() ?? 0;

        final List<dynamic> hourly = data['hourly'] ?? [];
        final List<dynamic> daysOfWeek = data['days_of_week'] ?? [];

        int maxHourlyOrders = 1;
        for (final h in hourly) {
          if ((h['orders_count'] as int) > maxHourlyOrders) {
            maxHourlyOrders = h['orders_count'] as int;
          }
        }

        double maxDayRevenue = 1.0;
        for (final d in daysOfWeek) {
          if ((d['revenue'] as double) > maxDayRevenue) {
            maxDayRevenue = d['revenue'] as double;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Cards
            Row(
              children: [
                Expanded(
                  child: GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.amber.withOpacity(0.15),
                    borderColor: Colors.amber.withOpacity(0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.access_time_rounded, color: Colors.amber, size: 18),
                            SizedBox(width: 6),
                            Text('PEAK HOUR',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.amber)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          peakHour,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        Text('$peakHourOrders orders placed',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.teal.withOpacity(0.15),
                    borderColor: Colors.teal.withOpacity(0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, color: Colors.teal, size: 18),
                            SizedBox(width: 6),
                            Text('BEST SALES DAY',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.teal)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bestDay,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        Text(AppFormatters.currency(bestDayRev),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 24-Hour Density Bar Distribution
            Text(
              '24-Hour Order Volume Distribution',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  SizedBox(
                    height: 160,
                    child: BarChart(
                      BarChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) {
                                final int h = val.toInt();
                                if (h % 4 == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      h == 0 ? '12A' : (h < 12 ? '${h}A' : (h == 12 ? '12P' : '${h - 12}P')),
                                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: hourly.map((h) {
                          final int hour = h['hour'] as int;
                          final int cnt = h['orders_count'] as int;
                          final isPeak = hour == (hourly.firstWhere((x) => x['label'] == peakHour, orElse: () => {'hour': -1})['hour']);

                          return BarChartGroupData(
                            x: hour,
                            barRods: [
                              BarChartRodData(
                                toY: cnt.toDouble(),
                                color: isPeak ? Colors.amber : AppColors.primary,
                                width: 7,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Day of Week Performance Bars
            Text(
              'Day of Week Sales Performance',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: daysOfWeek.map((d) {
                  final String name = d['name'] as String;
                  final double rev = (d['revenue'] as double);
                  final int cnt = (d['orders_count'] as int);
                  final double pct = maxDayRevenue > 0 ? (rev / maxDayRevenue).clamp(0.0, 1.0) : 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              '${AppFormatters.currency(rev)} ($cnt orders)',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.grey.withOpacity(0.15),
                          color: name == bestDay ? Colors.teal : AppColors.primary,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 5. DEAD STOCK & SPOILAGE LOSS
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildDeadStockSection() {
    final deadAsync = ref.watch(deadStockAnalyticsProvider(_deadStockDays));

    return deadAsync.when(
      loading: () => const LoadingShimmer(count: 3),
      error: (e, _) => Center(child: Text('Error loading dead stock: $e')),
      data: (data) {
        final List<dynamic> deadItems = data['dead_stock_items'] ?? [];
        final double locked = (data['capital_locked'] as num?)?.toDouble() ?? 0;
        final double spillage = (data['spillage_loss'] as num?)?.toDouble() ?? 0;
        final int spillageCount = (data['spillage_count'] as num?)?.toInt() ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Unsold Period Threshold:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Row(
                  children: [7, 14, 30, 60].map((d) {
                    final isSel = _deadStockDays == d;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text('${d}d'),
                        selected: isSel,
                        selectedColor: AppColors.error,
                        labelStyle: TextStyle(color: isSel ? Colors.white : null),
                        onSelected: (v) {
                          if (v) setState(() => _deadStockDays = d);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Warning Cards
            Row(
              children: [
                Expanded(
                  child: GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.red.withOpacity(0.15),
                    borderColor: Colors.red.withOpacity(0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_clock_rounded, color: Colors.redAccent, size: 18),
                            SizedBox(width: 6),
                            Text('LOCKED CAPITAL',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.redAccent)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppFormatters.currency(locked),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.redAccent),
                        ),
                        Text('${deadItems.length} items unsold >$_deadStockDays days',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.orange.withOpacity(0.15),
                    borderColor: Colors.orange.withOpacity(0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.delete_sweep_rounded, color: Colors.orange, size: 18),
                            SizedBox(width: 6),
                            Text('SPOILAGE LOSS',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.orange)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppFormatters.currency(spillage),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.orange),
                        ),
                        Text('$spillageCount recorded wastage events',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Text(
              'Dead Stock Inventory Alert (Unsold Items)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            if (deadItems.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('🎉 Awesome! No dead stock found for this threshold.'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: deadItems.length,
                itemBuilder: (ctx, i) {
                  final it = deadItems[i];
                  final String name = it['name'] ?? 'Unnamed';
                  final String cat = it['category'] ?? 'General';
                  final double stock = (it['stock'] as num?)?.toDouble() ?? 0;
                  final String unit = it['unit'] ?? '';
                  final double cost = (it['cost_price'] as num?)?.toDouble() ?? 0;
                  final double capital = (it['capital_locked'] as num?)?.toDouble() ?? 0;
                  final String daysSince = it['days_since_sold'] ?? '';

                  return GlassContainer(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('$cat • In Stock: ${AppFormatters.quantity(stock)} $unit',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Last Sold: $daysSince',
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppFormatters.currency(capital),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: Colors.redAccent),
                            ),
                            Text('Cost: ${AppFormatters.currency(cost)}/$unit',
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 6. DEBT AGING & CASHFLOW HEALTH
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildDebtAgingSection() {
    final debtAsync = ref.watch(cashflowDebtAgingProvider);

    return debtAsync.when(
      loading: () => const LoadingShimmer(count: 3),
      error: (e, _) => Center(child: Text('Error loading debt aging: $e')),
      data: (data) {
        final List<dynamic> splits = data['payment_splits'] ?? [];
        final Map<String, dynamic> aging = data['aging'] ?? {};
        final List<dynamic> overdue = data['overdue_orders'] ?? [];

        final double a07 = (aging['0_7_days']?['amount'] as num?)?.toDouble() ?? 0;
        final int c07 = (aging['0_7_days']?['count'] as num?)?.toInt() ?? 0;

        final double a814 = (aging['8_14_days']?['amount'] as num?)?.toDouble() ?? 0;
        final int c814 = (aging['8_14_days']?['count'] as num?)?.toInt() ?? 0;

        final double a1530 = (aging['15_30_days']?['amount'] as num?)?.toDouble() ?? 0;
        final int c1530 = (aging['15_30_days']?['count'] as num?)?.toInt() ?? 0;

        final double a30p = (aging['30_plus_days']?['amount'] as num?)?.toDouble() ?? 0;
        final int c30p = (aging['30_plus_days']?['count'] as num?)?.toInt() ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Methods Split
            Text(
              'Collected Payment Inflows',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: splits.map((s) {
                  final String method = s['method'] ?? 'OTHER';
                  final double amt = (s['amount'] as double);
                  final double pct = (s['percentage'] as double);

                  Color col = AppColors.primary;
                  if (method.contains('CASH')) col = Colors.green;
                  if (method.contains('UPI')) col = Colors.purple;
                  if (method.contains('KHATA')) col = Colors.amber;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(method, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('${AppFormatters.currency(amt)} (${pct.toStringAsFixed(1)}%)',
                                style: TextStyle(fontWeight: FontWeight.w700, color: col, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: (pct / 100.0).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.withOpacity(0.15),
                          color: col,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Debt Aging Brackets
            Text(
              'Pending Debt Aging Breakdown',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.35,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _debtAgingCard('0 - 7 Days (Fresh)', a07, c07, Colors.blue),
                _debtAgingCard('8 - 14 Days (Follow)', a814, c814, Colors.amber),
                _debtAgingCard('15 - 30 Days (Late)', a1530, c1530, Colors.orange),
                _debtAgingCard('30+ Days (Critical)', a30p, c30p, Colors.redAccent),
              ],
            ),

            const SizedBox(height: 24),

            // Overdue Follow-Up Orders List
            Text(
              'Actionable Overdue Debt Follow-Up',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            if (overdue.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('🎉 No overdue debts older than 7 days!'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: overdue.length,
                itemBuilder: (ctx, i) {
                  final o = overdue[i];
                  final String cust = o['customer_name'] ?? 'Unknown';
                  final String phone = o['phone'] ?? '';
                  final double amt = (o['amount'] as double);
                  final int age = (o['age_days'] as int);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      title: Text(cust, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('$age days overdue • Due: ${AppFormatters.currency(amt)}'),
                      trailing: phone.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.call_rounded, color: Colors.green),
                              onPressed: () async {
                                final uri = Uri.parse('tel:$phone');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              },
                            )
                          : null,
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _debtAgingCard(String label, double amount, int count, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(16),
      color: color.withOpacity(0.12),
      borderColor: color.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(AppFormatters.currency(amount),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          Text('$count orders pending',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildExpandedKpiCard(String kpi, Map<String, dynamic> summary) {
    if (kpi == 'today') {
      final double cash = summary['cash_received'] ?? 0;
      final double online = summary['online_received'] ?? 0;
      final double expenses = summary['today_expenses'] ?? 0;
      final double profit = summary['today_profit'] ?? 0;

      return GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(16),
        color: AppColors.primary.withOpacity(0.10),
        borderColor: AppColors.primary.withOpacity(0.3),
        child: Column(
          children: [
            _detailRow('Cash Received', AppFormatters.currency(cash), valueColor: Colors.green),
            const Divider(height: 12),
            _detailRow('UPI / Online', AppFormatters.currency(online), valueColor: Colors.purple),
            const Divider(height: 12),
            _detailRow("Today's Expenses", AppFormatters.currency(expenses), valueColor: Colors.redAccent),
            const Divider(height: 12),
            _detailRow("Today's Net Profit", AppFormatters.currency(profit),
                valueColor: profit >= 0 ? AppColors.success : AppColors.error),
          ],
        ),
      );
    }

    if (kpi == 'month') {
      final double monthlyProfit = summary['monthly_profit'] ?? 0;
      final double sales = summary['monthly_sales'] ?? 0;
      final double margin = sales > 0 ? (monthlyProfit / sales) * 100 : 0;

      return GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(16),
        color: Colors.green.withOpacity(0.10),
        borderColor: Colors.green.withOpacity(0.3),
        child: Column(
          children: [
            _detailRow('Monthly Net Profit', AppFormatters.currency(monthlyProfit), valueColor: Colors.green),
            const Divider(height: 12),
            _detailRow('Estimated Margin', '${margin.toStringAsFixed(1)}%', valueColor: Colors.green),
          ],
        ),
      );
    }

    if (kpi == 'expense') {
      final double totalExp = summary['total_expenses'] ?? 0;
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(16),
        color: Colors.red.withOpacity(0.10),
        borderColor: Colors.red.withOpacity(0.3),
        child: Column(
          children: [
            _detailRow('All Time Expenses', AppFormatters.currency(totalExp), valueColor: Colors.redAccent),
          ],
        ),
      );
    }

    if (kpi == 'pending') {
      final double pending = summary['pending_payments'] ?? 0;
      return GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(16),
        color: Colors.amber.withOpacity(0.10),
        borderColor: Colors.amber.withOpacity(0.3),
        child: Column(
          children: [
            _detailRow('Total Pending Khata Due', AppFormatters.currency(pending), valueColor: Colors.amber),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildChart(List<Map<String, dynamic>> data, String key) {
    if (data.isEmpty) {
      return const Center(child: Text('No chart data available'));
    }

    final spots = data.asMap().entries.map((e) {
      final double total = (e.value['total'] as num?)?.toDouble() ?? 0;
      return FlSpot(e.key.toDouble(), total);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final int idx = val.toInt();
                if (idx >= 0 && idx < data.length) {
                  final String raw = data[idx][key]?.toString() ?? '';
                  final parts = raw.split('-');
                  final label = parts.length > 2 ? '${parts[1]}/${parts[2]}' : raw;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryColor(context)),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimaryColor(context),
          ),
        ),
      ],
    );
  }

  Widget _paymentSplitRow(BuildContext context, String label, double amount,
      double total, Color color) {
    final double pct = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              total > 0 && amount > 0
                  ? '${label.contains('Orders') ? amount.toInt() : AppFormatters.currency(amount)} (${(pct * 100).toStringAsFixed(0)}%)'
                  : (label.contains('Orders')
                      ? '${amount.toInt()}'
                      : AppFormatters.currency(amount)),
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: AppColors.gray200,
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _miniPeriodStat(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
