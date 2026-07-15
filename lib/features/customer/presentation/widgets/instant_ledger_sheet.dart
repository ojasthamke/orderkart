import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/customer.dart';
import '../../../order/domain/order.dart';
import '../../../order/domain/order_item.dart';
import '../../../order/presentation/order_provider.dart';

class InstantLedgerSheet extends ConsumerStatefulWidget {
  final Customer customer;
  const InstantLedgerSheet({super.key, required this.customer});

  static Future<void> show(BuildContext context, Customer customer) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InstantLedgerSheet(customer: customer),
    );
  }

  @override
  ConsumerState<InstantLedgerSheet> createState() => _InstantLedgerSheetState();
}

class _InstantLedgerSheetState extends ConsumerState<InstantLedgerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<OrderItem> _boughtItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final orders = await ref.read(orderRepositoryProvider).getAllOrders(
        customerId: widget.customer.id,
      );
      final sortedOrders = List<AppOrder>.from(orders)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final last5 = sortedOrders.take(5).toList();

      List<OrderItem> items = [];
      for (final order in last5) {
        final orderItems = await ref.read(orderRepositoryProvider).getOrderItems(order.id);
        items.addAll(orderItems);
      }

      if (mounted) {
        setState(() {
          _boughtItems = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(customerOrdersProvider(widget.customer.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.customer.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Phone: ${widget.customer.phone1.isNotEmpty ? widget.customer.phone1 : "N/A"}',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            // Dues Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.customer.outstandingBalance > 0
                    ? AppColors.error.withOpacity(0.08)
                    : AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.customer.outstandingBalance > 0
                      ? AppColors.error.withOpacity(0.2)
                      : AppColors.success.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Outstanding Balance Dues:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '₹${widget.customer.outstandingBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.customer.outstandingBalance > 0
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Order History and Items Tabs
            Expanded(
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    tabs: const [
                      Tab(text: 'Past 5 Orders'),
                      Tab(text: 'Items Purchased'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                          // Tab 1: Past 5 Orders
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: ordersAsync.when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(color: AppColors.primary),
                              ),
                              error: (e, _) => Center(child: Text('Error: $e')),
                              data: (ordersList) {
                                final sorted = List<AppOrder>.from(ordersList)
                                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                                final past5 = sorted.take(5).toList();
                                if (past5.isEmpty) {
                                  return const Center(
                                    child: Text('No orders recorded for this customer yet.'),
                                  );
                                }
                                return ListView.builder(
                                  controller: _tabController.index == 0 ? controller : null,
                                  itemCount: past5.length,
                                  itemBuilder: (context, index) {
                                    final order = past5[index];
                                    final isPending = order.remainingAmount > 0;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          'Order #${order.orderNoLabel}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          'Date: ${order.createdAt.toIso8601String().substring(0, 10)}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '₹${order.grandTotal.toStringAsFixed(1)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isPending
                                                    ? AppColors.error.withOpacity(0.1)
                                                    : AppColors.success.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isPending
                                                    ? 'Due: ₹${order.remainingAmount.toStringAsFixed(1)}'
                                                    : 'Paid',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: isPending
                                                      ? AppColors.error
                                                      : AppColors.success,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                          // Tab 2: Items Purchased
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _loading
                                ? const Center(
                                    child: CircularProgressIndicator(color: AppColors.primary),
                                  )
                                : _boughtItems.isEmpty
                                    ? const Center(
                                        child: Text('No purchased items found.'),
                                      )
                                    : ListView.builder(
                                        controller: _tabController.index == 1 ? controller : null,
                                        itemCount: _boughtItems.length,
                                        itemBuilder: (context, index) {
                                          final item = _boughtItems[index];
                                          return Card(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            child: ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                                child: const Icon(Icons.shopping_bag_rounded,
                                                    color: AppColors.primary, size: 20),
                                              ),
                                              title: Text(
                                                item.itemName,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              subtitle: Text('Qty: ${item.quantity} ${item.itemUnit}'),
                                              trailing: Text(
                                                '₹${item.unitPrice.toStringAsFixed(1)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}
