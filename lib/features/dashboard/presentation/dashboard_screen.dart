import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/customer_avatar.dart';
import '../../customer/presentation/customer_provider.dart';
import '../../order/presentation/order_provider.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../../order/domain/order.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _selectedFilter = 'all'; // 'all', 'today', 'yesterday', 'week', 'month', 'custom'
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(analyticsSummaryProvider);
    final params = DashboardOrdersParams(
      filter: _selectedFilter == 'custom' ? null : _selectedFilter,
      startDate: _startDate,
      endDate: _endDate,
    );
    final ordersAsync = ref.watch(dashboardOrdersProvider(params));

    return AppScaffold(
      title: 'OrderKart Dashboard',
      showBack: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.search),
        ),
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.settings),
        ),
      ],
      body: summaryAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => Center(child: Text('Dashboard error: $e')),
        data: (summary) {
          final double todaySales = summary['today_sales'] ?? 0;
          final int orderCount = summary['order_count'] ?? 0;
          final int customerCount = summary['customer_count'] ?? 0;
          final double pendingPayments = summary['pending_payments'] ?? 0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(analyticsSummaryProvider);
              ref.invalidate(inventoryProvider);
              ref.invalidate(lowStockProvider);
              ref.invalidate(dashboardOrdersProvider(params));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Welcome row ──────────────────────────────────────
                  Row(
                    children: [
                      // App Logo
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppColors.cardShadow,
                          color: AppColors.primarySurface,
                          border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
                        ),
                        child: const Icon(
                          Icons.local_mall_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome Back!',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            Text(
                              'OrderKart',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      ref.watch(lowStockProvider).when(
                            data: (lowItems) => lowItems.isNotEmpty
                                ? Badge(
                                    label: Text('${lowItems.length}'),
                                    child: IconButton.filledTonal(
                                      icon: const Icon(Icons.warning_amber_rounded,
                                          color: AppColors.warning),
                                      onPressed: () => Navigator.of(context)
                                          .pushNamed(AppRoutes.inventory),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── KPI grid ──────────────────────────────────────────
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      StatCard(
                        label: "Today's Sales",
                        value: AppFormatters.currency(todaySales),
                        icon: Icons.currency_rupee_rounded,
                        color: AppColors.primary,
                      ),
                      StatCard(
                        label: 'Due Payments',
                        value: AppFormatters.currency(pendingPayments),
                        icon: Icons.payments_rounded,
                        color: AppColors.error,
                      ),
                      StatCard(
                        label: 'Active Customers',
                        value: '$customerCount',
                        icon: Icons.people_rounded,
                        color: AppColors.success,
                      ),
                      StatCard(
                        label: 'Total Orders',
                        value: '$orderCount',
                        icon: Icons.receipt_long_rounded,
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Shortcut modules ──────────────────────────────────
                  Text(
                    'Quick Access',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    childAspectRatio: 0.95,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      _shortcutTile(context, 'Areas & Map', Icons.map_rounded,
                          AppColors.primary, AppRoutes.areas),
                      _shortcutTile(context, 'Orders List',
                          Icons.receipt_long_rounded, Colors.orange, AppRoutes.orderManagement),
                      _shortcutTile(context, 'Inventory', Icons.inventory_2_rounded,
                          AppColors.success, AppRoutes.inventory),
                      _shortcutTile(context, 'Expenses', Icons.money_off_rounded,
                          AppColors.error, AppRoutes.expenses),
                      _shortcutTile(context, 'Reports', Icons.analytics_rounded,
                          Colors.purple, AppRoutes.analytics),
                      _shortcutTile(context, 'Settings', Icons.settings_rounded,
                          Colors.blueGrey, AppRoutes.settings),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Orders History & Filter Header ───────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Orders History',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (_selectedFilter == 'custom' && _startDate != null && _endDate != null)
                        IconButton(
                          icon: const Icon(Icons.date_range_rounded, size: 20, color: AppColors.primary),
                          onPressed: _pickDateRange,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Filter Chips Row
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip('all', 'All'),
                        _buildFilterChip('today', 'Today'),
                        _buildFilterChip('yesterday', 'Yesterday'),
                        _buildFilterChip('week', 'This Week'),
                        _buildFilterChip('month', 'This Month'),
                        _buildFilterChip('custom', 'Custom'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_selectedFilter == 'custom' && _startDate != null && _endDate != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Range: ${AppFormatters.date(_startDate!)} - ${AppFormatters.date(_endDate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                      ),
                    ),
                  ],

                  ordersAsync.when(
                    loading: () => const LoadingShimmer(count: 3),
                    error: (e, _) => Text('Error loading orders: $e'),
                    data: (orders) => orders.isEmpty
                        ? Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: const Center(
                              child: Text('No orders match this filter'),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: orders.length,
                            itemBuilder: (ctx, i) {
                              final o = orders[i];
                              return _RecentOrderTile(
                                order: o,
                                onTap: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.orderDetail,
                                        arguments: {'orderId': o.id})
                                    .then((_) {
                                  ref.invalidate(analyticsSummaryProvider);
                                  ref.invalidate(dashboardOrdersProvider(params));
                                }),
                              ).animate(delay: (i * 30).ms).fadeIn();
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

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedFilter = value;
              if (value != 'custom') {
                _startDate = null;
                _endDate = null;
              } else {
                _pickDateRange();
              }
            });
          }
        },
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    } else if (_startDate == null || _endDate == null) {
      // Revert back to all if they cancel without picking
      setState(() {
        _selectedFilter = 'all';
      });
    }
  }

  Widget _shortcutTile(BuildContext context, String label, IconData icon,
      Color color, String routeName) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(routeName),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gray200),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentOrderTile extends ConsumerWidget {
  final AppOrder order;
  final VoidCallback onTap;

  const _RecentOrderTile({required this.order, required this.onTap});

  Color get _statusColor {
    switch (order.deliveryStatus) {
      case 'delivered': return AppColors.delivered;
      case 'cancelled': return AppColors.cancelled;
      default:          return AppColors.pending;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(order.customerId));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
      ),
      child: ListTile(
        onTap: onTap,
        leading: customerAsync.when(
          data: (customer) => CustomerAvatar(
            photoPath: customer?.photoPath,
            radius: 20,
          ),
          loading: () => const CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primarySurface,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, __) => const CustomerAvatar(photoPath: '', radius: 20),
        ),
        title: Text(
          order.customerName ?? 'Unknown Customer',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        subtitle: Text(
          AppFormatters.relativeDate(order.createdAt),
          style: const TextStyle(fontSize: 11, color: AppColors.textHint),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              AppFormatters.currency(order.grandTotal),
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AppFormatters.deliveryStatus(order.deliveryStatus),
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
