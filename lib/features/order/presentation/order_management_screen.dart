/// OrderManagementScreen — All orders with tabs, filters, one-tap actions

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/customer_avatar.dart';
import '../../customer/presentation/customer_provider.dart';
import '../domain/order.dart';
import '../domain/payment.dart';
import 'order_provider.dart';

class OrderManagementScreen extends ConsumerStatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  ConsumerState<OrderManagementScreen> createState() =>
      _OrderManagementScreenState();
}

class _OrderManagementScreenState
    extends ConsumerState<OrderManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filter = 'all';
  String _sourceMode = 'all'; // 'all', 'owner', 'worker'

  final _tabs = [
    {'label': 'All',       'status': 'all'},
    {'label': 'Pending',   'status': 'pending'},
    {'label': 'Delivered', 'status': 'delivered'},
    {'label': 'Cancelled', 'status': 'cancelled'},
  ];

  final _filters = [
    {'label': 'All Time',   'value': 'all'},
    {'label': 'Today',      'value': 'today'},
    {'label': 'Yesterday',  'value': 'yesterday'},
    {'label': 'This Week',  'value': 'week'},
    {'label': 'This Month', 'value': 'month'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final status = _tabs[_tabController.index]['status']!;
      ref.read(orderManagementProvider.notifier).setStatus(status);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(orderManagementProvider);

    return AppScaffold(
      title: 'Orders',
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.search),
        ),
      ],
      body: Column(
        children: [
          // Tab bar
          TabBar(
            controller: _tabController,
            tabs: _tabs
                .map((t) => Tab(text: t['label']))
                .toList(),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
          ),

          // Source filter chips (Owner vs Worker orders)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 6),
            child: Row(
              children: [
                const Text('Source:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _sourceChip('All Orders', 'all', Icons.inventory_2_rounded),
                        const SizedBox(width: 6),
                        _sourceChip('Owner Orders', 'owner', Icons.person_rounded),
                        const SizedBox(width: 6),
                        _sourceChip('Worker Orders', 'worker', Icons.badge_rounded),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Date filter chips
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = f['value'] == _filter;
                return GestureDetector(
                  onTap: () {
                    setState(() => _filter = f['value']!);
                    ref
                        .read(orderManagementProvider.notifier)
                        .setFilter(f['value']!);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.gray100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.gray300),
                    ),
                    child: Text(
                      f['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Orders list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs
                  .map((t) => ordersAsync.when(
                        loading: () => const LoadingShimmer(),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (orders) {
                          var filtered = orders;
                          if (_sourceMode == 'owner') {
                            filtered = orders.where((o) => o.assignedWorkerId.isEmpty).toList();
                          } else if (_sourceMode == 'worker') {
                            filtered = orders.where((o) => o.assignedWorkerId.isNotEmpty).toList();
                          }
                          return filtered.isEmpty
                              ? const EmptyStateWidget(
                                  icon: Icons.receipt_long_rounded,
                                  title: 'No Orders Found',
                                  subtitle: 'Try changing source or status filters',
                                )
                              : _buildOrderList(filtered);
                        },
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceChip(String label, String value, IconData icon) {
    final selected = _sourceMode == value;
    return GestureDetector(
      onTap: () {
        setState(() => _sourceMode = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.gray100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.gray300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? AppColors.primary : AppColors.gray600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(List<AppOrder> orders) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: orders.length,
      itemBuilder: (ctx, i) => _OrderCard(
        order:    orders[i],
        onTap: () => Navigator.of(ctx).pushNamed(
          AppRoutes.orderDetail,
          arguments: {'orderId': orders[i].id},
        ).then((_) => ref.refresh(orderManagementProvider)),
        onToggleDelivery: () => _toggleDelivery(orders[i]),
        onAddPayment:     () => _addPayment(ctx, orders[i]),
        onEdit: () => Navigator.of(ctx).pushNamed(
          AppRoutes.createOrder,
          arguments: {
            'customerId':   orders[i].customerId,
            'customerName': orders[i].customerName ?? '',
            'orderId':      orders[i].id,
          },
        ).then((_) => ref.refresh(orderManagementProvider)),
        onDelete: () => _deleteOrder(ctx, orders[i]),
        onDuplicate: () => _duplicateOrder(orders[i]),
      ).animate(delay: (i * 40).ms).fadeIn(),
    );
  }

  Future<void> _toggleDelivery(AppOrder order) async {
    final newStatus = order.deliveryStatus == AppConstants.statusPending
        ? AppConstants.statusDelivered
        : AppConstants.statusPending;
    await ref
        .read(orderManagementProvider.notifier)
        .updateDeliveryStatus(order.id, newStatus);
    if (mounted) {
      SnackbarHelper.showSuccess(
          context, 'Order marked as ${AppFormatters.deliveryStatus(newStatus)}');
    }
  }

  Future<void> _addPayment(BuildContext context, AppOrder order) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.paymentDetails,
      arguments: {
        'customerId': order.customerId,
        'remainingAmount': order.remainingAmount,
        'grandTotal': order.grandTotal,
        'currency': '₹',
      },
    );

    if (result != null && result is Map<String, dynamic>) {
      final amount = result['amount'] as double;
      final method = result['method'] as String;
      final notes = result['notes'] as String;

      await ref.read(orderManagementProvider.notifier).addPayment(Payment(
            id:         const Uuid().v4(),
            orderId:    order.id,
            customerId: order.customerId,
            amount:     amount,
            method:     method,
            notes:      notes,
            createdAt:  DateTime.now(),
          ));
      
      if (context.mounted) {
        SnackbarHelper.showSuccess(context, 'Payment of ₹$amount added');
      }
    }
  }

  Future<void> _deleteOrder(BuildContext context, AppOrder order) async {
    final ok = await ConfirmDeleteDialog.show(
      context,
      title:   'Delete Order',
      message: 'Delete this order? This cannot be undone.',
    );
    if (!ok || !mounted) return;
    await ref.read(orderManagementProvider.notifier).deleteOrder(order.id);
    if (mounted) SnackbarHelper.showSuccess(context, 'Order deleted');
  }

  Future<void> _duplicateOrder(AppOrder order) async {
    final now     = DateTime.now();
    final newId   = const Uuid().v4();
    final duplicate = order.copyWith(
      id:             newId,
      paidAmount:     0,
      remainingAmount:order.grandTotal,
      deliveryStatus: AppConstants.statusPending,
      createdAt:      now,
      updatedAt:      now,
    );
    // Get items to duplicate
    final repo  = ref.read(orderRepositoryProvider);
    final items = await repo.getOrderItems(order.id);
    await ref
        .read(orderManagementProvider.notifier)
        .createOrder(duplicate, items.map((it) =>
            it.copyWith(id: const Uuid().v4(), orderId: newId)).toList());
    if (mounted)
      SnackbarHelper.showSuccess(context, 'Order duplicated');
  }
}

// ── Order Card ────────────────────────────────────────────────────────────────
class _OrderCard extends ConsumerWidget {
  final AppOrder order;
  final VoidCallback onTap;
  final VoidCallback onToggleDelivery;
  final VoidCallback onAddPayment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const _OrderCard({
    required this.order,
    required this.onTap,
    required this.onToggleDelivery,
    required this.onAddPayment,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
  });

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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    customerAsync.when(
                      data: (customer) => CustomerAvatar(
                        photoPath: customer?.photoPath,
                        radius: 18,
                      ),
                      loading: () => const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primarySurface,
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (_, __) => const CustomerAvatar(photoPath: '', radius: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${order.orderNoLabel} · ${order.customerName ?? 'Unknown'}',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        AppFormatters.deliveryStatus(order.deliveryStatus),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _statusColor),
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: AppColors.gray500, size: 20),
                      onSelected: (v) {
                        if (v == 'edit')      onEdit();
                        if (v == 'delete')    onDelete();
                        if (v == 'duplicate') onDuplicate();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit',      child: Text('Edit')),
                        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                        const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Address / phone
                customerAsync.when(
                  data: (cust) {
                    if (cust == null) return const SizedBox.shrink();
                    final houseStr = [
                      if (cust.serialNo > 0) '#${cust.serialNo}',
                      if (cust.houseNumber.isNotEmpty) cust.houseNumber,
                    ].join(' · ');
                    return Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 2),
                      child: Text(
                        '${houseStr.isNotEmpty ? '$houseStr  •  ' : ''}${cust.address}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 8),

                // Amount row
                Row(
                  children: [
                    _amountChip(context, 'Total',
                        '\u20b9${order.grandTotal.toStringAsFixed(2)}',
                        AppColors.primary),
                    const SizedBox(width: 8),
                    if (order.paidAmount > 0)
                      _amountChip(context, 'Paid',
                          '\u20b9${order.paidAmount.toStringAsFixed(2)}',
                          AppColors.success),
                    const SizedBox(width: 8),
                    if (order.remainingAmount > 0)
                      _amountChip(context, 'Due',
                          '\u20b9${order.remainingAmount.toStringAsFixed(2)}',
                          AppColors.warning),
                  ],
                ),

                const SizedBox(height: 8),

                // Time + action buttons
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 12, color: AppColors.gray400),
                    const SizedBox(width: 4),
                    Text(
                      AppFormatters.dateTime(order.createdAt),
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: AppColors.textHint),
                    ),
                    const Spacer(),
                    // Delivery toggle
                    if (order.deliveryStatus != AppConstants.statusCancelled)
                      _ActionBtn(
                        label: order.deliveryStatus == AppConstants.statusDelivered
                            ? 'Delivered ✓'
                            : 'Mark Delivered',
                        color: order.deliveryStatus == AppConstants.statusDelivered
                            ? AppColors.success
                            : AppColors.primary,
                        onTap: onToggleDelivery,
                      ),
                    const SizedBox(width: 6),
                    // Pay button
                    if (order.remainingAmount > 0)
                      _ActionBtn(
                        label: 'Pay',
                        color: AppColors.warning,
                        onTap: onAddPayment,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _amountChip(
      BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color  color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style:
              TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
