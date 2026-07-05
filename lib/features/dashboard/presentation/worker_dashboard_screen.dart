import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/stat_card.dart';
import '../../customer/presentation/customer_provider.dart';
import '../../order/presentation/order_provider.dart';

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('WORKER MODE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      Icon(Icons.offline_pin_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Assigned Route & Orders', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showCustomerPickerForOrder(context, ref),
                    icon: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF0284C7)),
                    label: const Text('Create New Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0284C7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text("Today's Performance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),

            reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (rpt) => GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StatCard(
                    label: "Today's Sales",
                    value: AppFormatters.currency((rpt['total_sales'] as num?)?.toDouble() ?? 0),
                    icon: Icons.shopping_bag_outlined,
                    color: AppColors.primary,
                  ),
                  StatCard(
                    label: "Cash Collected",
                    value: AppFormatters.currency((rpt['cash_received'] as num?)?.toDouble() ?? 0),
                    icon: Icons.payments_outlined,
                    color: AppColors.success,
                  ),
                  StatCard(
                    label: "Online Collected",
                    value: AppFormatters.currency((rpt['online_received'] as num?)?.toDouble() ?? 0),
                    icon: Icons.account_balance_outlined,
                    color: Colors.purple,
                  ),
                  StatCard(
                    label: "Assigned Areas",
                    value: "Active",
                    icon: Icons.map_outlined,
                    color: Colors.orange,
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.areas),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text("Quick Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed(AppRoutes.customers),
                    icon: const Icon(Icons.people_outline_rounded),
                    label: const Text('My Customers'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed(AppRoutes.orderManagement),
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: const Text('My Orders'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
