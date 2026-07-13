import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/services/worker_session.dart';
import '../../customer/presentation/customer_provider.dart';
import '../../order/presentation/order_provider.dart';
import '../../worker/presentation/worker_provider.dart';

class WorkerDashboardScreen extends ConsumerWidget {
  const WorkerDashboardScreen({super.key});

  Future<void> _showCustomerPickerForOrder(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final customersAsync = ref.watch(allCustomersProvider);
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Customer for Order',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: customersAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (err, _) => Center(child: Text('Error: $err')),
                    data: (customers) {
                      if (customers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('No customers found.'),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.pushNamed(context, AppRoutes.addEditCustomer);
                                },
                                icon: const Icon(Icons.person_add_rounded),
                                label: const Text('Add Customer First'),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final c = customers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primarySurface,
                              child: Text(
                                c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                              ),
                            ),
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text([if (c.phone1.isNotEmpty) c.phone1, c.address].where((e) => e.isNotEmpty).join(' · ')),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.pushNamed(
                                context,
                                AppRoutes.createOrder,
                                arguments: {'customerId': c.id, 'customerName': c.name},
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(todaysDetailedReportProvider);
    final workerId = WorkerSession.instance.currentWorkerId ?? '';
    final commissionAsync = ref.watch(workerCommissionProvider(workerId));
    final workerName = WorkerSession.instance.currentWorkerName ?? 'Worker';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final headerGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
          : [AppColors.primary, const Color(0xFF0284C7)],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text('Worker Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Pending Sync Queue',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.pendingSync),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                gradient: headerGradient,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.white.withOpacity(0.8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    workerName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          AppFormatters.shortDate(DateTime.now()),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: -0.1, end: 0, curve: Curves.easeOutCubic),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  reportAsync.maybeWhen(
                    data: (rpt) {
                      final collected = (rpt['cash_received'] as num?)?.toDouble() ?? 0.0;
                      const double target = 50000.0;
                      final pct = (collected / target).clamp(0.0, 1.0);
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.transparent : AppColors.gray200),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Today's Collection Target",
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                Text('${(pct * 100).toStringAsFixed(0)}% Achieved',
                                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 10,
                                backgroundColor: isDark ? const Color(0xFF334155) : AppColors.gray200,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Collected: ${AppFormatters.currency(collected)}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                Text('Target: ${AppFormatters.currency(target)}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 600.ms, delay: 100.ms)
                          .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), curve: Curves.easeOutBack);
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),

                  const Text("Quick Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),

                  GridView.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: MediaQuery.textScalerOf(context).scale(1.0) > 1.4
                        ? 0.72
                        : (MediaQuery.textScalerOf(context).scale(1.0) > 1.1 ? 0.80 : 0.88),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _actionCard(
                        context,
                        title: 'Areas & Routes',
                        subtitle: 'Area → Street',
                        icon: Icons.map_rounded,
                        color: Colors.orange,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.areas),
                        index: 0,
                      ),
                      _actionCard(
                        context,
                        title: 'My Customers',
                        subtitle: 'Assigned List',
                        icon: Icons.people_outline_rounded,
                        color: AppColors.primary,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.customers),
                        index: 1,
                      ),
                      _actionCard(
                        context,
                        title: 'Quick Order',
                        subtitle: '+ New Order',
                        icon: Icons.add_shopping_cart_rounded,
                        color: AppColors.success,
                        onTap: () => _showCustomerPickerForOrder(context, ref),
                        index: 2,
                      ),
                      _actionCard(
                        context,
                        title: 'Quick Orders',
                        subtitle: 'Order History',
                        icon: Icons.receipt_long_rounded,
                        color: Colors.purple,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.orderManagement),
                        index: 3,
                      ),
                      _actionCard(
                        context,
                        title: 'Call Center',
                        subtitle: 'Logs & Directory',
                        icon: Icons.phone_callback_rounded,
                        color: Colors.blue,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.callLogs),
                        index: 4,
                      ),
                      _actionCard(
                        context,
                        title: 'Field Visits',
                        subtitle: 'Check-ins / Logs',
                        icon: Icons.directions_walk_rounded,
                        color: Colors.teal,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.visits),
                        index: 5,
                      ),
                      _actionCard(
                        context,
                        title: 'Field Notes',
                        subtitle: 'Log Notes',
                        icon: Icons.note_alt_outlined,
                        color: Colors.blueGrey,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.notes),
                        index: 6,
                      ),
                      _actionCard(
                        context,
                        title: 'Statistics',
                        subtitle: 'Perform. Stats',
                        icon: Icons.bar_chart_rounded,
                        color: Colors.deepOrange,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.workerAnalytics),
                        index: 7,
                      ),
                      _actionCard(
                        context,
                        title: 'Groceries Hub',
                        subtitle: 'Freshness / Log',
                        icon: Icons.shopping_basket_rounded,
                        color: Colors.green,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.groceriesHub),
                        index: 8,
                      ),
                      _actionCard(
                        context,
                        title: 'Medicines Hub',
                        subtitle: 'Rx / Expiries',
                        icon: Icons.medical_services_rounded,
                        color: Colors.teal,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.medicinesHub),
                        index: 9,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                  const Text("Today's Performance Metrics", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),

                  commissionAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (e, _) => Text('Error loading earnings: $e'),
                    data: (comm) {
                      final todayEarning = comm['today'] ?? 0.0;
                      final monthlyEarning = comm['monthly'] ?? 0.0;

                      return reportAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        error: (e, _) => Text('Error loading report: $e'),
                        data: (rpt) {
                          final pendingDues = (rpt['pending_amount'] as num?)?.toDouble() ?? 0.0;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: StatCard(
                                      label: "Today's Earning",
                                      value: AppFormatters.currency(todayEarning),
                                      icon: Icons.monetization_on_rounded,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: StatCard(
                                      label: "This Month's Earnings",
                                      value: AppFormatters.currency(monthlyEarning),
                                      icon: Icons.trending_up_rounded,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              StatCard(
                                label: "Pending Dues",
                                value: AppFormatters.currency(pendingDues),
                                icon: Icons.hourglass_empty_rounded,
                                color: Colors.red,
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required int index,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        AppHaptics.buttonClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.transparent : AppColors.gray200),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (index * 60).ms)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), curve: Curves.easeOutBack);
  }
}
