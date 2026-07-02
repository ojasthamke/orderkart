import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/customer_avatar.dart';
import '../../order/presentation/order_provider.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _topCustomersSort = 'purchase'; // 'purchase', 'orders', 'pending'

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(analyticsSummaryProvider);
    final weeklySalesAsync = ref.watch(weeklyChartProvider);
    final topCustomersAsync = ref.watch(topCustomersProvider);

    return AppScaffold(
      title: 'Analytics & Reports',
      body: summaryAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => Center(child: Text('Error loading stats: $e')),
        data: (summary) {
          final double todaySales      = summary['today_sales'] ?? 0;
          final double monthlySales    = summary['monthly_sales'] ?? 0;
          final double pendingPayments = summary['pending_payments'] ?? 0;
          final double totalExpenses   = summary['total_expenses'] ?? 0;
          final double cashReceived    = summary['cash_received'] ?? 0;
          final double onlineReceived  = summary['online_received'] ?? 0;
          final int    customerCount   = summary['customer_count'] ?? 0;
          final int    orderCount      = summary['order_count'] ?? 0;

          final topItems = summary['top_items'] as List<dynamic>? ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(analyticsSummaryProvider);
              ref.invalidate(weeklyChartProvider);
              ref.invalidate(topCustomersProvider);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── KPI grid ──────────────────────────────────────────
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.15,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      StatCard(
                        label: "Today's Sales",
                        value: AppFormatters.currency(todaySales),
                        icon: Icons.today_rounded,
                        color: AppColors.primary,
                      ),
                      StatCard(
                        label: 'This Month',
                        value: AppFormatters.currency(monthlySales),
                        icon: Icons.trending_up_rounded,
                        color: AppColors.success,
                      ),
                      StatCard(
                        label: 'Expenses',
                        value: AppFormatters.currency(totalExpenses),
                        icon: Icons.trending_down_rounded,
                        color: AppColors.error,
                      ),
                      StatCard(
                        label: 'Outstandings',
                        value: AppFormatters.currency(pendingPayments),
                        icon: Icons.assignment_late_rounded,
                        color: AppColors.warning,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Weekly Chart ──────────────────────────────────────
                  Text(
                    'Sales Trend (Last 7 Days)',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 220,
                    padding: const EdgeInsets.fromLTRB(8, 16, 24, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: weeklySalesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Chart error: $e')),
                      data: (weekly) => weekly.isEmpty
                          ? const Center(child: Text('Not enough sales data'))
                          : _buildLineChart(weekly),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Cash vs Online comparison ──────────────────────────
                  Text(
                    'Payment Breakdown',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: Column(
                      children: [
                        _paymentSplitRow(
                          context,
                          'Cash Payments',
                          cashReceived,
                          cashReceived + onlineReceived,
                          AppColors.success,
                        ),
                        const SizedBox(height: 14),
                        _paymentSplitRow(
                          context,
                          'Online Payments',
                          onlineReceived,
                          cashReceived + onlineReceived,
                          AppColors.primary,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Top Selling Items ──────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Top Selling Items',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Icon(Icons.star_rounded, color: Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: topItems.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No orders yet')),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: topItems.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final it = topItems[i];
                              final String name = it['item_name'] ?? '';
                              final double revenue = (it['revenue'] as num?)?.toDouble() ?? 0;
                              final double qty = (it['qty'] as num?)?.toDouble() ?? 0;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primarySurface,
                                  child: Text('${i + 1}',
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700)),
                                ),
                                title: Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    'Sold Qty: ${AppFormatters.quantity(qty)}'),
                                trailing: Text(AppFormatters.currency(revenue),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.success)),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 24),

                  // ── Top Customers Section ─────────────────────────────
                  Text(
                    'Top Customers',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Purchase'),
                        selected: _topCustomersSort == 'purchase',
                        onSelected: (val) {
                          if (val) setState(() => _topCustomersSort = 'purchase');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Orders'),
                        selected: _topCustomersSort == 'orders',
                        onSelected: (val) {
                          if (val) setState(() => _topCustomersSort = 'orders');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Pending'),
                        selected: _topCustomersSort == 'pending',
                        onSelected: (val) {
                          if (val) setState(() => _topCustomersSort = 'pending');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: topCustomersAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, _) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('Error loading customers: $err')),
                      ),
                      data: (list) {
                        if (list.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No customers found')),
                          );
                        }

                        // Sort the list based on selection
                        final sortedList = List<Map<String, dynamic>>.from(list);
                        sortedList.sort((a, b) {
                          if (_topCustomersSort == 'orders') {
                            final int valA = a['total_orders'] ?? 0;
                            final int valB = b['total_orders'] ?? 0;
                            return valB.compareTo(valA);
                          } else if (_topCustomersSort == 'pending') {
                            final double valA = (a['pending_amount'] as num?)?.toDouble() ?? 0;
                            final double valB = (b['pending_amount'] as num?)?.toDouble() ?? 0;
                            return valB.compareTo(valA);
                          } else {
                            final double valA = (a['total_purchase'] as num?)?.toDouble() ?? 0;
                            final double valB = (b['total_purchase'] as num?)?.toDouble() ?? 0;
                            return valB.compareTo(valA);
                          }
                        });

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sortedList.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final cust = sortedList[i];
                            final String name = cust['name'] ?? 'Unknown';
                            final String photo = cust['photo_path'] ?? '';
                            final int orders = cust['total_orders'] ?? 0;
                            final double purchase = (cust['total_purchase'] as num?)?.toDouble() ?? 0;
                            final double paid = (cust['total_paid'] as num?)?.toDouble() ?? 0;
                            final double pending = (cust['pending_amount'] as num?)?.toDouble() ?? 0;
                            final String lastOrder = cust['last_order_date'] ?? '';

                            return ListTile(
                              leading: CustomerAvatar(
                                photoPath: photo,
                                radius: 22,
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'Orders: $orders  •  Purchase: ${AppFormatters.currency(purchase)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'Paid: ${AppFormatters.currency(paid)}  •  Pending: ${AppFormatters.currency(pending)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: pending > 0 ? FontWeight.w600 : FontWeight.normal,
                                      color: pending > 0 ? AppColors.error : AppColors.textSecondary,
                                    ),
                                  ),
                                  if (lastOrder.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Last Order: ${AppFormatters.dateFromString(lastOrder)}',
                                      style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                                    ),
                                  ]
                                ],
                              ),
                              isThreeLine: true,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLineChart(List<Map<String, dynamic>> data) {
    final List<FlSpot> spots = [];
    final List<String> labels = [];

    for (int i = 0; i < data.length; i++) {
      final total = (data[i]['total'] as num?)?.toDouble() ?? 0.0;
      final String day = data[i]['day'] ?? '';
      spots.add(FlSpot(i.toDouble(), total));
      labels.add(day.length >= 8 ? day.substring(5) : day); // MM-DD
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final int index = val.toInt();
                if (index < 0 || index >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[index],
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                );
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
            barWidth: 4,
            isStrokeCapRound: true,
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

  Widget _paymentSplitRow(BuildContext context, String label, double amount,
      double total, Color color) {
    final double pct = total > 0 ? (amount / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              '${AppFormatters.currency(amount)} (${(pct * 100).toStringAsFixed(0)}%)',
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
}
