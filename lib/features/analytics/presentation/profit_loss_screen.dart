import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../order/presentation/order_provider.dart';
import 'analytics_provider.dart';

class ProfitLossScreen extends ConsumerStatefulWidget {
  const ProfitLossScreen({super.key});

  @override
  ConsumerState<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends ConsumerState<ProfitLossScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Date-wise filter state
  int _selectedDays = 7;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomRange() async {
    AppHaptics.buttonClick();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
    );

    if (picked != null) {
      setState(() {
        _selectedDays = 0; // custom indicator
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Profit & Loss & Analytics',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: () {
            AppHaptics.buttonClick();
            ref.invalidate(profitLossProvider);
            ref.invalidate(dateWiseProfitProvider);
            ref.invalidate(todayVsYesterdayProfitProvider);
          },
        ),
      ],
      body: Column(
        children: [
          // Segmented Tab Bar (3 Tabs: P&L Statement, Date-Wise & Accumulated, Today vs Yesterday)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : AppColors.textSecondary,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              tabs: const [
                Tab(
                  icon: Icon(Icons.analytics_rounded, size: 16),
                  text: 'P&L Statement',
                ),
                Tab(
                  icon: Icon(Icons.trending_up_rounded, size: 16),
                  text: 'Accumulated Profit',
                ),
                Tab(
                  icon: Icon(Icons.compare_arrows_rounded, size: 16),
                  text: 'Today vs Yesterday',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverallStatementTab(),
                _buildDateWiseProfitTab(),
                _buildTodayVsYesterdayTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 1: OVERALL P&L STATEMENT & SUBSECTIONS
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildOverallStatementTab() {
    final plAsync = ref.watch(profitLossProvider);
    final todayVsYestAsync = ref.watch(todayVsYesterdayProfitProvider);

    return plAsync.when(
      loading: () => const LoadingShimmer(count: 3),
      error: (err, _) => Center(child: Text('Error calculating P&L: $err')),
      data: (pl) {
        final double revenue =
            (pl['total_revenue'] ?? pl['total_sales'])?.toDouble() ?? 0.0;
        final double cogs =
            (pl['cogs'] ?? pl['total_cost'])?.toDouble() ?? 0.0;
        final double grossProfit =
            (pl['gross_profit'])?.toDouble() ?? (revenue - cogs);
        final double expenses = (pl['total_expenses'])?.toDouble() ?? 0.0;
        final double discounts = (pl['total_discounts'])?.toDouble() ?? 0.0;
        final double delivery = (pl['delivery_income'])?.toDouble() ?? 0.0;
        final double netProfit = (pl['net_profit'])?.toDouble() ??
            (grossProfit - expenses - discounts + delivery);
        final double marginPct = (pl['profit_margin_pct'])?.toDouble() ??
            (revenue > 0 ? (netProfit / revenue) * 100 : 0.0);
        final bool isProfitable = pl['is_profitable'] ?? (netProfit >= 0);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── SUBSECTION 1: Executive P&L Scorecard ──────────────────────
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

                return GlassContainer(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
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
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isProfitable ? 'ALL-TIME NET PROFIT' : 'ALL-TIME NET LOSS',
                            style: TextStyle(
                              color: secTextColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppFormatters.currency(netProfit.abs()),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${isProfitable ? '+' : ''}${marginPct.toStringAsFixed(1)}% Net Margin',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // ── SUBSECTION 2: Today vs Yesterday Snapshot Card ────────────
              todayVsYestAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (comparison) {
                  final today = comparison['today'] as Map<String, dynamic>;
                  final yesterday = comparison['yesterday'] as Map<String, dynamic>;
                  final double profitDiff = (comparison['profit_diff'] as num?)?.toDouble() ?? 0.0;
                  final double profitGrowthPct = (comparison['profit_growth_pct'] as num?)?.toDouble() ?? 0.0;
                  final bool isGrowth = comparison['is_growth'] as bool? ?? true;

                  final double todayProfit = (today['net_profit'] as num?)?.toDouble() ?? 0.0;
                  final double yestProfit = (yesterday['net_profit'] as num?)?.toDouble() ?? 0.0;

                  return GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.flash_on_rounded, size: 16, color: Colors.amber),
                                SizedBox(width: 6),
                                Text(
                                  'TODAY VS YESTERDAY PROFIT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isGrowth ? AppColors.success : AppColors.error).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${isGrowth ? '+' : ''}${profitGrowthPct.toStringAsFixed(1)}% Growth',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isGrowth ? AppColors.success : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Today column
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Today\'s Profit', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppFormatters.currency(todayProfit),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: todayProfit >= 0 ? AppColors.success : AppColors.error,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${today['orders_count']} orders • ${AppFormatters.currency((today['revenue'] as num?)?.toDouble() ?? 0)} sales',
                                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Yesterday column
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.withOpacity(0.25)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Yesterday\'s Profit', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppFormatters.currency(yestProfit),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: yestProfit >= 0 ? AppColors.success : AppColors.error,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${yesterday['orders_count']} orders • ${AppFormatters.currency((yesterday['revenue'] as num?)?.toDouble() ?? 0)} sales',
                                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Delta: ${profitDiff >= 0 ? '+' : ''}${AppFormatters.currency(profitDiff)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isGrowth ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ── SUBSECTION 3: Forensic Step-by-Step Accounting Ledger ─────
              Text(
                'Forensic Accounting Ledger',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              GlassContainer(
                padding: const EdgeInsets.all(18),
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    _calcRow(
                      context,
                      symbol: '+',
                      symbolColor: AppColors.primary,
                      label: 'Gross Sales Revenue',
                      subtitle: 'Total order bill value (active orders)',
                      amount: revenue,
                      isBold: true,
                    ),
                    const Divider(height: 22),
                    _calcRow(
                      context,
                      symbol: '-',
                      symbolColor: Colors.orange,
                      label: 'Cost of Goods Sold (COGS)',
                      subtitle: 'Direct product purchase & wholesale costs',
                      amount: cogs,
                      amountColor: Colors.orange,
                    ),
                    const Divider(height: 22),
                    _calcRow(
                      context,
                      symbol: '=',
                      symbolColor: AppColors.success,
                      label: 'Gross Trading Profit',
                      subtitle: 'Revenue minus direct wholesale product cost',
                      amount: grossProfit,
                      amountColor: AppColors.success,
                      isBold: true,
                    ),
                    const Divider(height: 22),
                    _calcRow(
                      context,
                      symbol: '-',
                      symbolColor: AppColors.error,
                      label: 'Operating & Store Expenses',
                      subtitle: 'Rent, transport, daily overheads, salaries',
                      amount: expenses,
                      amountColor: AppColors.error,
                    ),
                    const Divider(height: 22),
                    if (discounts > 0) ...[
                      _calcRow(
                        context,
                        symbol: 'ℹ️',
                        symbolColor: Colors.blue,
                        label: 'Customer Discounts Granted',
                        subtitle: 'Promotional markdowns (factored in net)',
                        amount: discounts,
                        amountColor: Colors.blue,
                      ),
                      const Divider(height: 22),
                    ],
                    if (delivery > 0) ...[
                      _calcRow(
                        context,
                        symbol: '+',
                        symbolColor: AppColors.success,
                        label: 'Delivery Surcharges Collected',
                        subtitle: 'Delivery service fees earned',
                        amount: delivery,
                      ),
                      const Divider(height: 22),
                    ],
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isProfitable
                                ? AppColors.success
                                : AppColors.error)
                            .withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: (isProfitable
                                  ? AppColors.success
                                  : AppColors.error)
                              .withOpacity(0.35),
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

              const SizedBox(height: 22),

              // ── SUBSECTION 4: Financial Ratios & Performance ──────────────
              Text(
                'Financial Health & Performance Ratios',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              GlassContainer(
                padding: const EdgeInsets.all(18),
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    _ratioBar(
                      context,
                      label: 'Product Procurement Cost (COGS)',
                      amount: cogs,
                      total: revenue,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 14),
                    _ratioBar(
                      context,
                      label: 'Operating Expenses Ratio',
                      amount: expenses,
                      total: revenue,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 14),
                    _ratioBar(
                      context,
                      label: 'Net Profit Margin Ratio',
                      amount: netProfit > 0 ? netProfit : 0,
                      total: revenue,
                      color: AppColors.success,
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricBox('Gross Margin', '${revenue > 0 ? ((grossProfit / revenue) * 100).toStringAsFixed(1) : 0.0}%', AppColors.primary),
                        _metricBox('Net Margin', '${marginPct.toStringAsFixed(1)}%', isProfitable ? AppColors.success : AppColors.error),
                        _metricBox('Markup / ROI', '${cogs > 0 ? ((grossProfit / cogs) * 100).toStringAsFixed(1) : 0.0}%', Colors.teal),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 2: DATE-WISE & ACCUMULATED PROFIT
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildDateWiseProfitTab() {
    final params = DateWiseProfitParams(
      days: _selectedDays,
      startDate: _customStart != null
          ? "${_customStart!.year}-${_customStart!.month.toString().padLeft(2, '0')}-${_customStart!.day.toString().padLeft(2, '0')}"
          : null,
      endDate: _customEnd != null
          ? "${_customEnd!.year}-${_customEnd!.month.toString().padLeft(2, '0')}-${_customEnd!.day.toString().padLeft(2, '0')}"
          : null,
    );

    final dateWiseAsync = ref.watch(dateWiseProfitProvider(params));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Filter Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodChip('Last 7 Days', 7),
                const SizedBox(width: 8),
                _buildPeriodChip('Last 14 Days', 14),
                const SizedBox(width: 8),
                _buildPeriodChip('Last 30 Days', 30),
                const SizedBox(width: 8),
                _buildCustomRangeChip(),
              ],
            ),
          ),
          const SizedBox(height: 16),

          dateWiseAsync.when(
            loading: () => const LoadingShimmer(count: 4),
            error: (err, _) => Center(child: Text('Error loading date-wise stats: $err')),
            data: (dailyRows) {
              if (dailyRows.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No order or expense data found for this period.'),
                  ),
                );
              }

              // Compute aggregate totals for the period
              double periodSales = 0;
              double periodCogs = 0;
              double periodExp = 0;
              double periodProfit = 0;
              double periodPureProfit = 0;
              int periodOrders = 0;
              double periodCash = 0;
              double periodOnline = 0;
              double periodPending = 0;

              for (final r in dailyRows) {
                periodSales += (r['revenue'] as num?)?.toDouble() ?? 0.0;
                periodCogs += (r['cogs'] as num?)?.toDouble() ?? 0.0;
                periodExp += (r['expenses'] as num?)?.toDouble() ?? 0.0;
                periodProfit += (r['net_profit'] as num?)?.toDouble() ?? 0.0;
                periodPureProfit += (r['pure_profit'] as num?)?.toDouble() ?? 0.0;
                periodOrders += (r['orders_count'] as num?)?.toInt() ?? 0;
                periodCash += (r['cash_collected'] as num?)?.toDouble() ?? 0.0;
                periodOnline += (r['online_collected'] as num?)?.toDouble() ?? 0.0;
                periodPending += (r['pending_debt'] as num?)?.toDouble() ?? 0.0;
              }

              final double periodMargin =
                  periodSales > 0 ? (periodProfit / periodSales) * 100.0 : 0.0;
              final double avgPureProfitPerOrder =
                  periodOrders > 0 ? periodPureProfit / periodOrders : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period Executive Summary Card with Accumulated Profit Highlight
                  GlassContainer(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    borderRadius: BorderRadius.circular(20),
                    color: (periodProfit >= 0 ? Colors.green : Colors.red)
                        .withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.10),
                    borderColor: (periodProfit >= 0 ? Colors.green : Colors.red)
                        .withOpacity(0.4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDays == 7
                                   ? '7-DAY ACCUMULATED PROFIT'
                                  : (_selectedDays == 14
                                      ? '14-DAY ACCUMULATED PROFIT'
                                      : (_selectedDays == 30
                                          ? '30-DAY ACCUMULATED PROFIT'
                                          : 'PERIOD ACCUMULATED PROFIT')),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                color: periodProfit >= 0 ? AppColors.success : AppColors.error,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (periodProfit >= 0 ? AppColors.success : AppColors.error).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${periodProfit >= 0 ? '+' : ''}${periodMargin.toStringAsFixed(1)}% Margin',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: periodProfit >= 0 ? AppColors.success : AppColors.error,
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
                                const Text('Total Accumulated Profit',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  AppFormatters.currency(periodProfit),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: periodProfit >= 0 ? AppColors.success : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Total Sales Inflow',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  AppFormatters.currency(periodSales),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _miniPeriodStat('Pure Profit', AppFormatters.currency(periodPureProfit)),
                            _miniPeriodStat('Profit/Order', AppFormatters.currency(avgPureProfitPerOrder)),
                            _miniPeriodStat('COGS', AppFormatters.currency(periodCogs)),
                            _miniPeriodStat('Expenses', AppFormatters.currency(periodExp)),
                          ],
                        ),
                        if (periodCash > 0 || periodOnline > 0 || periodPending > 0) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _miniPeriodStat('Cash Inflow', AppFormatters.currency(periodCash)),
                              _miniPeriodStat('Online / UPI', AppFormatters.currency(periodOnline)),
                              _miniPeriodStat('Pending Dues', AppFormatters.currency(periodPending)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Daily Date-Wise Ledger Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daily Ledger & Accumulated Trend',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${dailyRows.length} Days Recorded',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Date-by-Date Cards with Running Accumulated Profit Badge
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dailyRows.length,
                    itemBuilder: (ctx, idx) {
                      final day = dailyRows[idx];
                      final isProfitableDay = (day['is_profitable'] as bool? ?? true);
                      final double dailyNetProfit = (day['net_profit'] as num?)?.toDouble() ?? 0.0;
                      final double dailyPureProfit = (day['pure_profit'] as num?)?.toDouble() ?? 0.0;
                      final double dailyPureProfitPerOrder = (day['pure_profit_per_order'] as num?)?.toDouble() ?? 0.0;
                      final double accumulatedProfit = (day['accumulated_profit'] as num?)?.toDouble() ?? dailyNetProfit;
                      final double dailyRevenue = (day['revenue'] as num?)?.toDouble() ?? 0.0;
                      final double dailyCogs = (day['cogs'] as num?)?.toDouble() ?? 0.0;
                      final double dailyExp = (day['expenses'] as num?)?.toDouble() ?? 0.0;
                      final double dailyMargin = (day['profit_margin_pct'] as num?)?.toDouble() ?? 0.0;
                      final int dailyOrders = (day['orders_count'] as num?)?.toInt() ?? 0;
                      final double dailyCash = (day['cash_collected'] as num?)?.toDouble() ?? 0.0;
                      final double dailyOnline = (day['online_collected'] as num?)?.toDouble() ?? 0.0;
                      final double dailyPending = (day['pending_debt'] as num?)?.toDouble() ?? 0.0;

                      final isDark = Theme.of(ctx).brightness == Brightness.dark;

                      return GlassContainer(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        borderRadius: BorderRadius.circular(16),
                        borderColor: isProfitableDay
                            ? Colors.green.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Date + Day Name + Day Profit + Running Accumulated Profit Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        day['day_name'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      day['date'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '($dailyOrders ord)',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isProfitableDay ? Colors.green : Colors.red).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${dailyNetProfit >= 0 ? '+' : ''}${AppFormatters.currency(dailyNetProfit)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: isProfitableDay ? AppColors.success : AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Running Accumulated Profit Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: (accumulatedProfit >= 0 ? AppColors.primary : Colors.red).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (accumulatedProfit >= 0 ? AppColors.primary : Colors.red).withOpacity(0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.timeline_rounded, size: 14, color: accumulatedProfit >= 0 ? AppColors.primary : Colors.red),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Running Accumulated Profit:',
                                        style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    AppFormatters.currency(accumulatedProfit),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: accumulatedProfit >= 0 ? AppColors.primary : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Pure Profit Badge (No Expenses, No Delivery Charges)
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.teal.withOpacity(0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.monetization_on_outlined, size: 14, color: Colors.teal),
                                      SizedBox(width: 4),
                                      Text(
                                        'Pure Profit (No Exp / Del):',
                                        style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${AppFormatters.currency(dailyPureProfit)}  (${dailyOrders > 0 ? AppFormatters.currency(dailyPureProfitPerOrder) : "₹0"}/ord)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Divider(height: 18),

                            // Grid of Financial Details for this Day
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _dayDetailCell('Sales', AppFormatters.currency(dailyRevenue), isDark ? Colors.white : Colors.black87),
                                _dayDetailCell('COGS', AppFormatters.currency(dailyCogs), Colors.orange),
                                _dayDetailCell('Expenses', AppFormatters.currency(dailyExp), Colors.redAccent),
                                _dayDetailCell('Margin', '${dailyMargin.toStringAsFixed(1)}%', isProfitableDay ? AppColors.success : AppColors.error),
                              ],
                            ),

                            if (dailyCash > 0 || dailyOnline > 0 || dailyPending > 0) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Cash: ${AppFormatters.currency(dailyCash)}  •  Online: ${AppFormatters.currency(dailyOnline)}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                    ),
                                    if (dailyPending > 0)
                                      Text(
                                        'Pending: ${AppFormatters.currency(dailyPending)}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 3: TODAY VS YESTERDAY DETAILED COMPARISON HUB
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildTodayVsYesterdayTab() {
    final todayVsYestAsync = ref.watch(todayVsYesterdayProfitProvider);

    return todayVsYestAsync.when(
      loading: () => const LoadingShimmer(count: 3),
      error: (err, _) => Center(child: Text('Error loading comparison: $err')),
      data: (data) {
        final today = data['today'] as Map<String, dynamic>;
        final yesterday = data['yesterday'] as Map<String, dynamic>;
        final double profitDiff = (data['profit_diff'] as num?)?.toDouble() ?? 0.0;
        final double profitGrowthPct = (data['profit_growth_pct'] as num?)?.toDouble() ?? 0.0;
        final double revenueDiff = (data['revenue_diff'] as num?)?.toDouble() ?? 0.0;
        final int ordersDiff = (data['orders_diff'] as num?)?.toInt() ?? 0;
        final bool isGrowth = data['is_growth'] as bool? ?? true;

        final double todayProfit = (today['net_profit'] as num?)?.toDouble() ?? 0.0;
        final double yestProfit = (yesterday['net_profit'] as num?)?.toDouble() ?? 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Head-to-Head Hero Delta Card
              GlassContainer(
                padding: const EdgeInsets.all(20),
                borderRadius: BorderRadius.circular(22),
                color: (isGrowth ? Colors.green : Colors.red)
                    .withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.10),
                borderColor: (isGrowth ? Colors.green : Colors.red).withOpacity(0.4),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DAILY PROFIT DELTA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: isGrowth ? AppColors.success : AppColors.error,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isGrowth ? AppColors.success : AppColors.error).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${isGrowth ? '+' : ''}${profitGrowthPct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: isGrowth ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isGrowth ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          size: 32,
                          color: isGrowth ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${profitDiff >= 0 ? '+' : ''}${AppFormatters.currency(profitDiff)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: isGrowth ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isGrowth ? 'Profit increased compared to yesterday!' : 'Profit dropped compared to yesterday',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _miniPeriodStat('Revenue Change', '${revenueDiff >= 0 ? '+' : ''}${AppFormatters.currency(revenueDiff)}'),
                        _miniPeriodStat('Orders Change', '${ordersDiff >= 0 ? '+' : ''}$ordersDiff ord'),
                        _miniPeriodStat('Today Margin', '${((today['profit_margin_pct'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}%'),
                        _miniPeriodStat('Yest Margin', '${((yesterday['profit_margin_pct'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}%'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Side-by-Side Comparison Matrix Table
              Text(
                'Metrics Comparison Matrix',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              GlassContainer(
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    _matrixHeader(),
                    const Divider(height: 20),
                    _matrixRow('Pure Profit (No Exp/Del)', AppFormatters.currency((today['pure_profit'] as num?)?.toDouble() ?? 0.0), AppFormatters.currency((yesterday['pure_profit'] as num?)?.toDouble() ?? 0.0), isHighlight: true, isProfit: true),
                    _matrixRow('Pure Profit / Order', AppFormatters.currency((today['pure_profit_per_order'] as num?)?.toDouble() ?? 0.0), AppFormatters.currency((yesterday['pure_profit_per_order'] as num?)?.toDouble() ?? 0.0)),
                    _matrixRow('Net Profit (With Exp/Del)', AppFormatters.currency(todayProfit), AppFormatters.currency(yestProfit), isProfit: true),
                    _matrixRow('Total Sales Revenue', AppFormatters.currency((today['revenue'] as num?)?.toDouble() ?? 0.0), AppFormatters.currency((yesterday['revenue'] as num?)?.toDouble() ?? 0.0)),
                    _matrixRow('Cost of Goods (COGS)', AppFormatters.currency((today['cogs'] as num?)?.toDouble() ?? 0.0), AppFormatters.currency((yesterday['cogs'] as num?)?.toDouble() ?? 0.0)),
                    _matrixRow('Operating Expenses', AppFormatters.currency((today['expenses'] as num?)?.toDouble() ?? 0.0), AppFormatters.currency((yesterday['expenses'] as num?)?.toDouble() ?? 0.0)),
                    _matrixRow('Delivery Income', AppFormatters.currency((today['delivery_income'] as num?)?.toDouble() ?? 0.0), AppFormatters.currency((yesterday['delivery_income'] as num?)?.toDouble() ?? 0.0)),
                    _matrixRow('Discounts Given', AppFormatters.currency((today['discounts'] as num?)?.toDouble() ?? 0.0), AppFormatters.currency((yesterday['discounts'] as num?)?.toDouble() ?? 0.0)),
                    _matrixRow('Orders Completed', '${today['orders_count']}', '${yesterday['orders_count']}'),
                    _matrixRow('Cash Collected', AppFormatters.currency((today['cash_collected'] as num?)?.toDouble() ?? 0.0), AppFormatters.currency((yesterday['cash_collected'] as num?)?.toDouble() ?? 0.0)),
                    _matrixRow('Online / UPI Collected', AppFormatters.currency((today['online_collected'] as num?)?.toDouble() ?? 0.0), AppFormatters.currency((yesterday['online_collected'] as num?)?.toDouble() ?? 0.0)),
                    _matrixRow('Pending Debt', AppFormatters.currency((today['pending_debt'] as num?)?.toDouble() ?? 0.0), AppFormatters.currency((yesterday['pending_debt'] as num?)?.toDouble() ?? 0.0)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _matrixHeader() {
    return const Row(
      children: [
        Expanded(flex: 4, child: Text('METRIC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
        Expanded(flex: 3, child: Text('TODAY', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary))),
        Expanded(flex: 3, child: Text('YESTERDAY', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
      ],
    );
  }

  Widget _matrixRow(String label, String todayVal, String yestVal, {bool isHighlight = false, bool isProfit = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w500,
                color: isHighlight ? AppColors.primary : null,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              todayVal,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w700,
                color: isProfit ? AppColors.success : null,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              yestVal,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, int days) {
    final isSelected = _selectedDays == days;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: isSelected ? Colors.white : null),
      onSelected: (_) {
        AppHaptics.selection();
        setState(() {
          _selectedDays = days;
          _customStart = null;
          _customEnd = null;
        });
      },
    );
  }

  Widget _buildCustomRangeChip() {
    final isSelected = _selectedDays == 0;
    final String label = isSelected && _customStart != null && _customEnd != null
        ? '${_customStart!.day}/${_customStart!.month} - ${_customEnd!.day}/${_customEnd!.month}'
        : 'Custom Date 📅';

    return ActionChip(
      avatar: const Icon(Icons.date_range_rounded, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      backgroundColor: isSelected ? AppColors.primary : null,
      labelStyle: TextStyle(color: isSelected ? Colors.white : null),
      onPressed: _pickCustomRange,
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

  Widget _dayDetailCell(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _metricBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
      ],
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
}
