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
    _tabController = TabController(length: 2, vsync: this);
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
      title: 'Profit & Loss & Daily Stats',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: () {
            AppHaptics.buttonClick();
            ref.invalidate(profitLossProvider);
            ref.invalidate(dateWiseProfitProvider);
          },
        ),
      ],
      body: Column(
        children: [
          // Segmented Tab Bar
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
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.analytics_rounded, size: 18),
                  text: 'P&L Statement',
                ),
                Tab(
                  icon: Icon(Icons.calendar_month_rounded, size: 18),
                  text: 'Date-Wise Profit',
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 1: OVERALL P&L STATEMENT
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildOverallStatementTab() {
    final plAsync = ref.watch(profitLossProvider);

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
              // Big Net Profit / Loss Header Card
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

              // Interactive Financial Profit Radar Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Financial Health Radar',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          isProfitable ? 'Healthy Business' : 'High Cost Pressure',
                          style: TextStyle(
                            color: isProfitable ? AppColors.success : AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildRadarBar('Sales', revenue, 1.0, AppColors.primary),
                        _buildRadarBar('Cost (COGS)', cogs,
                            revenue > 0 ? (cogs / revenue) : 0.0, Colors.orange),
                        _buildRadarBar(
                            'Expenses',
                            expenses,
                            revenue > 0 ? (expenses / revenue) : 0.0,
                            Colors.redAccent),
                        _buildRadarBar(
                            'Net Profit',
                            netProfit > 0 ? netProfit : 0,
                            revenue > 0 ? (netProfit / revenue) : 0.0,
                            Colors.green),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Accounting Step Breakdown
              Text(
                'Accounting Ledger & Breakdown',
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
                    _calcRow(
                      context,
                      symbol: '+',
                      symbolColor: AppColors.primary,
                      label: 'Gross Sales Revenue',
                      subtitle: 'Total order value of non-cancelled orders',
                      amount: revenue,
                      isBold: true,
                    ),
                    const Divider(height: 24),
                    _calcRow(
                      context,
                      symbol: '-',
                      symbolColor: Colors.orange,
                      label: 'Cost of Goods Sold (COGS)',
                      subtitle: 'Base purchase cost of all products delivered',
                      amount: cogs,
                      amountColor: Colors.orange,
                    ),
                    const Divider(height: 24),
                    _calcRow(
                      context,
                      symbol: '=',
                      symbolColor: AppColors.success,
                      label: 'Gross Profit',
                      subtitle: 'Revenue minus direct product costs',
                      amount: grossProfit,
                      amountColor: AppColors.success,
                      isBold: true,
                    ),
                    const Divider(height: 24),
                    _calcRow(
                      context,
                      symbol: '-',
                      symbolColor: AppColors.error,
                      label: 'Operating Expenses',
                      subtitle: 'Total recorded store & delivery expenses',
                      amount: expenses,
                      amountColor: AppColors.error,
                    ),
                    const Divider(height: 24),
                    if (discounts > 0) ...[
                      _calcRow(
                        context,
                        symbol: 'ℹ️',
                        symbolColor: Colors.blue,
                        label: 'Customer Discounts Granted',
                        subtitle: 'Promotional savings (already factored in Net Sales)',
                        amount: discounts,
                        amountColor: Colors.blue,
                      ),
                      const Divider(height: 24),
                    ],
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

              // Percentage Analysis Ratios
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
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 2: DATE-WISE DAILY PROFIT BREAKDOWN
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildDateWiseProfitTab() {
    final params = DateWiseProfitParams(
      days: _selectedDays > 0 ? _selectedDays : 7,
      startDate: _selectedDays == 0 && _customStart != null
          ? "${_customStart!.year}-${_customStart!.month.toString().padLeft(2, '0')}-${_customStart!.day.toString().padLeft(2, '0')}"
          : null,
      endDate: _selectedDays == 0 && _customEnd != null
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
                _buildPeriodChip('Last 7 Days (Week)', 7),
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
              int periodOrders = 0;
              double periodCash = 0;
              double periodOnline = 0;
              double periodPending = 0;

              for (final r in dailyRows) {
                periodSales += (r['revenue'] as double);
                periodCogs += (r['cogs'] as double);
                periodExp += (r['expenses'] as double);
                periodProfit += (r['net_profit'] as double);
                periodOrders += (r['orders_count'] as int);
                periodCash += (r['cash_collected'] as double);
                periodOnline += (r['online_collected'] as double);
                periodPending += (r['pending_debt'] as double);
              }

              final double periodMargin =
                  periodSales > 0 ? (periodProfit / periodSales) * 100.0 : 0.0;
              final double avgDailyProfit =
                  dailyRows.isNotEmpty ? periodProfit / dailyRows.length : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period Executive Summary Card
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
                                  ? 'LAST 7 DAYS SUMMARY'
                                  : (_selectedDays == 14
                                      ? 'LAST 14 DAYS SUMMARY'
                                      : (_selectedDays == 30
                                          ? 'LAST 30 DAYS SUMMARY'
                                          : 'CUSTOM RANGE SUMMARY')),
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
                                const Text('Total Net Profit',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  AppFormatters.currency(periodProfit),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: periodProfit >= 0 ? AppColors.success : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Total Sales',
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
                            _miniPeriodStat('Orders', '$periodOrders'),
                            _miniPeriodStat('COGS', AppFormatters.currency(periodCogs)),
                            _miniPeriodStat('Expenses', AppFormatters.currency(periodExp)),
                            _miniPeriodStat('Avg/Day', AppFormatters.currency(avgDailyProfit)),
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
                        'Daily Profit & Sales Breakdown',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${dailyRows.length} Days',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Date-by-Date Cards
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dailyRows.length,
                    itemBuilder: (ctx, idx) {
                      final day = dailyRows[idx];
                      final isProfitableDay = (day['is_profitable'] as bool);
                      final double dailyNetProfit = (day['net_profit'] as double);
                      final double dailyRevenue = (day['revenue'] as double);
                      final double dailyCogs = (day['cogs'] as double);
                      final double dailyExp = (day['expenses'] as double);
                      final double dailyMargin = (day['profit_margin_pct'] as double);
                      final int dailyOrders = (day['orders_count'] as int);
                      final double dailyCash = (day['cash_collected'] as double);
                      final double dailyOnline = (day['online_collected'] as double);
                      final double dailyPending = (day['pending_debt'] as double);

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
                            // Header: Date + Day Name + Profit Badge
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
                                      '($dailyOrders orders)',
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
    final safeRatio = (ratio.isNaN || ratio.isInfinite)
        ? 0.0
        : ratio.clamp(0.0, 1.0);

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
              height: (60 * safeRatio).clamp(4.0, 60.0),
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
