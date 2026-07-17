import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/customer_avatar.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/widgets/smart_business_pulse_widget.dart';
import '../../customer/presentation/customer_provider.dart';
import '../../customer/domain/customer.dart';
import '../../order/presentation/order_provider.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../../order/domain/order.dart';
import '../../visit/presentation/visit_provider.dart';
import '../../note/presentation/note_provider.dart';
import '../../notification/presentation/notification_provider.dart';

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
      title: 'OrderKart',
      showBack: false,
      drawer: const AppDrawer(),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.search),
        ),
      ],
      body: summaryAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => Center(child: Text('Dashboard error: $e')),
        data: (summary) {
          final double pendingPayments = summary['pending_payments'] ?? 0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(analyticsSummaryProvider);
              ref.invalidate(inventoryProvider);
              ref.invalidate(lowStockProvider);
              ref.invalidate(dashboardOrdersProvider(params));
              ref.invalidate(visitListProvider);
              ref.invalidate(pendingCustomersProvider);
              ref.invalidate(noteListNotifier);
              ref.invalidate(notificationListProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Welcome row ──────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // App Logo
                      _buildGlassContainer(
                        context: context,
                        width: 56,
                        height: 56,
                        borderRadius: BorderRadius.circular(16),
                        padding: EdgeInsets.zero,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.local_mall_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
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
                            const SizedBox(height: 2),
                            Text(
                              "Today: ${summary['today_orders_count'] ?? 0} orders • ${AppFormatters.currency(summary['today_sales'] ?? 0)}",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
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
                      // ── Payment warning button ─────────────────────────
                      ref.watch(pendingCustomersProvider).when(
                        data: (pending) => pending.isNotEmpty
                            ? Badge(
                                label: Text('${pending.length}'),
                                backgroundColor: AppColors.error,
                                child: IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.errorSurface,
                                  ),
                                  icon: const Icon(Icons.warning_amber_rounded,
                                      color: AppColors.error),
                                  onPressed: () =>
                                      _showPendingReminder(context, pending),
                                ),
                              )
                            : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),

                  // ── Pending Payments Warning Banner ───────────────────
                  ref.watch(pendingCustomersProvider).when(
                    data: (pending) => pending.isNotEmpty
                        ? Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.error.withOpacity(0.18),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_rounded,
                                    color: AppColors.error, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${pending.length} customer${pending.length > 1 ? 's have' : ' has'} unpaid remaining money.',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _showPendingReminder(context, pending),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    backgroundColor:
                                        AppColors.error.withOpacity(0.12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'TRACK',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // ── Overpaid / Remaining Money Return Reminder Banner ────────────────
                  ref.watch(overpaidCustomersProvider).when(
                    data: (overpaid) => overpaid.isNotEmpty
                        ? Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF0284C7).withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_wallet_rounded,
                                    color: Color(0xFF0284C7), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${overpaid.length} customer${overpaid.length > 1 ? 's have' : ' has'} overpaid balance to return.',
                                    style: const TextStyle(
                                      color: Color(0xFF0284C7),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _showOverpaidReminder(context, overpaid),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    backgroundColor:
                                        const Color(0xFF0284C7).withOpacity(0.12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'RETURN',
                                    style: TextStyle(
                                      color: Color(0xFF0284C7),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 20),

                  // ── Feature Statistics Executive Card ─────────────
                  () {
                    final stockData = ref.watch(stockSummaryProvider).maybeWhen(
                          data: (s) => s,
                          orElse: () => <String, dynamic>{},
                        );
                    final totalItems = (stockData['total_items'] as int?) ?? 0;
                    final lowStockCount = (stockData['low_stock_count'] as int?) ?? 0;
                    final outOfStockCount = (stockData['out_of_stock_count'] as int?) ?? 0;
                    final inStock = (totalItems - outOfStockCount - lowStockCount).clamp(0, 99999);

                    return SmartBusinessPulseWidget(
                      todaySales: (summary['today_sales'] as num?)?.toDouble() ?? 0.0,
                      pendingDues: pendingPayments,
                      totalRevenue: (summary['all_time_sales'] as num?)?.toDouble() ?? 0.0,
                      inStockCount: inStock,
                      lowStockCount: lowStockCount,
                      outOfStockCount: outOfStockCount,
                      customerCount: (summary['customer_count'] as int?) ?? 0,
                      vipCount: (summary['vip_count'] as int?) ?? 0,
                      deliveredCount: (summary['delivered_count'] as int?) ?? 0,
                      pendingCount: (summary['pending_count'] as int?) ?? 0,
                      todayExpenses: (summary['today_expenses'] as num?)?.toDouble() ?? 0.0,
                      todayOrdersCount: (summary['today_orders_count'] as int?) ?? 0,
                      monthlySales: (summary['monthly_sales'] as num?)?.toDouble() ?? 0.0,
                      cashReceived: (summary['cash_received'] as num?)?.toDouble() ?? 0.0,
                      onlineReceived: (summary['online_received'] as num?)?.toDouble() ?? 0.0,
                      onCreateOrder: () => Navigator.of(context).pushNamed(AppRoutes.customers),
                      onViewInventory: () => Navigator.of(context).pushNamed(AppRoutes.inventory),
                    );
                  }(),

                  const SizedBox(height: 20),

                  // ── Dashboard Quick Cards (Material 3) ─────────────────
                  SizedBox(
                    height: 112,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildDashboardCard(
                          context,
                          title: "Today's Orders",
                          icon: Icons.shopping_bag_rounded,
                          color: AppColors.primary,
                          providerValue: summaryAsync.maybeWhen(
                            data: (s) => (s['today_orders_count'] ?? 0).toString(),
                            orElse: () => '0',
                          ),
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.orderManagement),
                        ),
                        _buildDashboardCard(
                          context,
                          title: 'Pending Dues',
                          icon: Icons.account_balance_wallet_rounded,
                          color: AppColors.warning,
                          providerValue: ref.watch(pendingCustomersProvider).maybeWhen(
                            data: (list) => list.length.toString(),
                            orElse: () => '-',
                          ),
                          onTap: () {
                            ref.read(pendingCustomersProvider).whenData((pending) {
                              if (pending.isNotEmpty) {
                                _showPendingReminder(context, pending);
                              } else {
                                SnackbarHelper.showInfo(context, 'No customers currently have pending dues');
                              }
                            });
                          },
                        ),
                        _buildDashboardCard(
                          context,
                          title: 'Low Stock',
                          icon: Icons.inventory_rounded,
                          color: AppColors.warning,
                          providerValue: ref.watch(lowStockProvider).maybeWhen(
                            data: (list) => list.length.toString(),
                            orElse: () => '-',
                          ),
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.inventory),
                        ),
                        _buildDashboardCard(
                          context,
                          title: 'Upcoming Notes',
                          icon: Icons.note_alt_rounded,
                          color: Colors.purple,
                          providerValue: ref.watch(noteListNotifier).maybeWhen(
                            data: (list) => list.where((n) => n.remindAt.isNotEmpty).length.toString(),
                            orElse: () => '-',
                          ),
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.notes),
                        ),
                        _buildDashboardCard(
                          context,
                          title: 'Unread Alerts',
                          icon: Icons.notifications_active_rounded,
                          color: Colors.teal,
                          providerValue: ref.watch(notificationListProvider).maybeWhen(
                            data: (list) => list.where((n) => !n.isRead).length.toString(),
                            orElse: () => '-',
                          ),
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.notifications),
                        ),
                        _buildDashboardCard(
                          context,
                          title: 'Field Workers',
                          icon: Icons.badge_rounded,
                          color: Colors.indigo,
                          providerValue: 'Add / View',
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.workers),
                        ),
                        _buildDashboardCard(
                          context,
                          title: 'Notes Questions',
                          icon: Icons.question_answer_rounded,
                          color: Colors.amber.shade900,
                          providerValue: 'Manage',
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.orderQuestionsConfig),
                        ),
                        _buildDashboardCard(
                          context,
                          title: 'Groceries Hub',
                          icon: Icons.shopping_basket_rounded,
                          color: Colors.green,
                          providerValue: 'Freshness / Spoilage',
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.groceriesHub),
                        ),
                        _buildDashboardCard(
                          context,
                          title: 'Medicines Hub',
                          icon: Icons.medical_services_rounded,
                          color: Colors.teal,
                          providerValue: 'Rx / Expiry Radar',
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.medicinesHub),
                        ),
                        _buildDashboardCard(
                          context,
                          title: 'Catalog Showroom',
                          icon: Icons.grid_view_rounded,
                          color: Colors.pink,
                          providerValue: 'Showroom Mode',
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.catalogShowroom),
                        ),
                        _buildDashboardCard(
                          context,
                          title: 'Churn Analytics',
                          icon: Icons.trending_down_rounded,
                          color: Colors.redAccent,
                          providerValue: 'Smart Retention',
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.churnRisk),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Money Remained Tracker ─────────────────────────────
                  _buildGlassContainer(
                    context: context,
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    borderColor: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF78350F).withOpacity(0.6)
                        : const Color(0xFFFDE68A),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'MONEY REMAINED',
                              style: TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Color(0xFFD97706),
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppFormatters.currency(pendingPayments),
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Total outstanding dues from orders.',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
                  
                  // ── Areas Quick Access Section ───────────────────
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'GEOGRAPHIC REGIONS',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.areas),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.map_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Manage Areas & Streets',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildDashboardCard(BuildContext context, {required String title, required IconData icon, required Color color, required String providerValue, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: _buildGlassContainer(
        context: context,
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        borderColor: color.withOpacity(0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      providerValue,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textPrimary.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : cs.onSurface.withOpacity(0.75),
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.gray100,
        side: BorderSide(
          color: isSelected
              ? AppColors.primary
              : (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2A2A)
                  : AppColors.gray300),
          width: isSelected ? 1.5 : 1,
        ),
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

  void _showPendingReminder(BuildContext context, List<Customer> pending) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.70,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).bottomSheetTheme.backgroundColor ??
                Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.errorSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active_rounded,
                          color: AppColors.error, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Reminders',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${pending.length} customer${pending.length > 1 ? 's have' : ' has'} pending dues',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              // Customer list
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: pending.length,
                  itemBuilder: (_, i) {
                    final c = pending[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).pushNamed(
                            AppRoutes.customerProfile,
                            arguments: {'customerId': c.id},
                          );
                        },
                        leading: CustomerAvatar(
                          photoPath: c.photoPath,
                          radius: 22,
                        ),
                        title: Text(
                          c.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (c.phone1.isNotEmpty)
                              Text(
                                c.phone1,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            if (c.address.isNotEmpty)
                              Text(
                                c.address,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                             if (c.serialNo > 0 || c.houseNumber.isNotEmpty)
                               Text(
                                 [
                                   if (c.serialNo > 0)
                                     '#${c.serialNo}',
                                   if (c.houseNumber.isNotEmpty)
                                     c.houseNumber,
                                 ].join(' · '),
                                 style: Theme.of(context)
                                     .textTheme
                                     .labelSmall
                                     ?.copyWith(color: AppColors.textHint),
                               ),
                           ],
                         ),
                         trailing: Column(
                           mainAxisAlignment: MainAxisAlignment.center,
                           crossAxisAlignment: CrossAxisAlignment.end,
                           children: [
                             Text(
                               AppFormatters.currency(c.outstandingBalance),
                               style: Theme.of(context)
                                   .textTheme
                                   .titleSmall
                                   ?.copyWith(
                                     color: AppColors.error,
                                     fontWeight: FontWeight.w800,
                                   ),
                             ),
                             const SizedBox(height: 2),
                             Text(
                               'Due',
                               style: Theme.of(context)
                                   .textTheme
                                   .labelSmall
                                   ?.copyWith(color: AppColors.error),
                             ),
                           ],
                         ),
                       ),
                     ).animate(delay: (i * 40).ms).fadeIn().slideX(begin: 0.05);
                   },
                 ),
               ),
             ],
           ),
         ),
       ),
     );
   }

  void _showOverpaidReminder(BuildContext context, List<Customer> overpaid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: Color(0xFF0284C7), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overpaid / Remaining Change to Return',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${overpaid.length} customer${overpaid.length > 1 ? 's' : ''} paid extra money',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: overpaid.length,
                  itemBuilder: (_, i) {
                    final c = overpaid[i];
                    final returnAmount = c.advanceBalance;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF0284C7).withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).pushNamed(
                            AppRoutes.customerProfile,
                            arguments: {'customerId': c.id},
                          );
                        },
                        leading: CustomerAvatar(
                          photoPath: c.photoPath,
                          radius: 22,
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          c.phone1.isNotEmpty ? c.phone1 : c.address,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppFormatters.currency(returnAmount),
                              style: const TextStyle(
                                color: Color(0xFF0284C7),
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const Text(
                              'Return Change',
                              style: TextStyle(fontSize: 10, color: Color(0xFF0284C7)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassContainer({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    Color? borderColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = borderRadius ?? BorderRadius.circular(16);
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.20 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (isDark ? const Color(0xFF1E293B) : Colors.white).withOpacity(isDark ? 0.60 : 0.85),
                  (isDark ? const Color(0xFF0F172A) : Colors.white).withOpacity(isDark ? 0.35 : 0.50),
                ],
              ),
              border: Border.all(
                color: borderColor ?? (isDark ? Colors.white24 : Colors.black12),
                width: 1.2,
              ),
            ),
            child: child,
          ),
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
          '${order.orderNoLabel} · ${order.customerName ?? 'Unknown Customer'}',
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
