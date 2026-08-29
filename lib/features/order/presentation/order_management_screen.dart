/// OrderManagementScreen — All orders with tabs, filters, one-tap actions
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/customer_avatar.dart';
import '../../../core/widgets/status_dot_badge.dart';
import '../../customer/presentation/customer_provider.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/order.dart';
import '../data/order_dao.dart';
import '../domain/payment.dart';
import 'order_provider.dart';
import '../../../core/utils/graphic_bill_generator.dart';
import '../../location/presentation/location_provider.dart';
import '../../inventory/domain/item.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../../../core/utils/external_launcher.dart';
import 'widgets/running_month_date_strip.dart';

class OrderManagementScreen extends ConsumerStatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  ConsumerState<OrderManagementScreen> createState() =>
      _OrderManagementScreenState();
}

class _OrderManagementScreenState extends ConsumerState<OrderManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filter = 'all';
  String _sourceMode = 'all'; // 'all', 'owner', 'worker'

  final _tabs = [
    {'label': 'All', 'status': 'all'},
    {'label': 'Pending', 'status': 'pending'},
    {'label': 'Delivered', 'status': 'delivered'},
    {'label': 'Cancelled', 'status': 'cancelled'},
    {'label': 'Pre-Orders', 'status': 'preorder'},
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
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            labelColor: Colors.white,
            unselectedLabelColor:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : AppColors.textSecondary,
            indicatorColor: Colors.transparent,
            indicator: AppColors.tabDecoration(context),
            tabs: _tabs.map((t) => Tab(text: t['label'])).toList(),
          ),

          // Source filter chips (Owner vs Worker orders)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 6),
            child: Row(
              children: [
                const Text('Source:',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _sourceChip(
                            'All Orders', 'all', Icons.inventory_2_rounded),
                        const SizedBox(width: 6),
                        _sourceChip(
                            'Owner Orders', 'owner', Icons.person_rounded),
                        const SizedBox(width: 6),
                        _sourceChip(
                            'Worker Orders', 'worker', Icons.badge_rounded),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Date filter chips strip (Running Month & Custom Range)
          ref.watch(preOrderDateCountsProvider).maybeWhen(
                data: (dateCounts) => RunningMonthDateStrip(
                  selectedFilter: _filter,
                  dateCounts: dateCounts,
                  onFilterSelected: (val) {
                    setState(() => _filter = val);
                    ref
                        .read(orderManagementProvider.notifier)
                        .setFilter(val);
                  },
                ),
                orElse: () => RunningMonthDateStrip(
                  selectedFilter: _filter,
                  onFilterSelected: (val) {
                    setState(() => _filter = val);
                    ref
                        .read(orderManagementProvider.notifier)
                        .setFilter(val);
                  },
                ),
              ),

          const SizedBox(height: 4),

          // Orders list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs
                  .map((t) => ordersAsync.when(
                        loading: () => const LoadingShimmer(),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (orders) {
                          final now = DateTime.now();
                          final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                          final statusKey = t['status']!;
                          var filtered = orders;

                          if (statusKey == 'preorder') {
                            filtered = filtered
                                .where((o) => o.orderType == 'Pre-Order')
                                .toList();
                            if (_filter.startsWith('date:')) {
                              final targetDate = _filter.substring(5);
                              filtered = filtered.where((o) => (o.orderTakingDate ?? '').startsWith(targetDate) || (o.deliveryDate ?? '').startsWith(targetDate)).toList();
                            } else if (_filter == 'today') {
                              filtered = filtered.where((o) => (o.orderTakingDate ?? '').startsWith(todayStr) || (o.deliveryDate ?? '').startsWith(todayStr)).toList();
                            }
                            filtered.sort((a, b) {
                              final aDate = a.orderTakingDate ?? '';
                              final bDate = b.orderTakingDate ?? '';
                              return aDate.compareTo(bDate);
                            });
                          } else if (statusKey != 'all') {
                            filtered = filtered
                                .where((o) => o.deliveryStatus == statusKey)
                                .toList();
                          }
                          if (_sourceMode == 'owner') {
                            filtered = filtered
                                .where((o) => o.assignedWorkerId.isEmpty)
                                .toList();
                          } else if (_sourceMode == 'worker') {
                            filtered = filtered
                                .where((o) => o.assignedWorkerId.isNotEmpty)
                                .toList();
                          }
                          return filtered.isEmpty
                              ? EmptyStateWidget(
                                  icon: Icons.receipt_long_rounded,
                                  title: 'No ${t['label']} Orders',
                                  subtitle:
                                      'Try changing source or status filters',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        setState(() => _sourceMode = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (isDark ? const Color(0xFF1E293B) : AppColors.gray100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (isDark ? Colors.white.withOpacity(0.12) : AppColors.gray300),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : AppColors.gray600)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(List<AppOrder> orders) {
    double totalWeightKg = 0.0;
    double totalAmount = 0.0;
    for (final o in orders) {
      totalAmount += o.grandTotal;
      for (final it in o.items) {
        final u = it.itemUnit.toLowerCase();
        if (u.contains('kg')) {
          totalWeightKg += it.quantity;
        } else if (u.contains('gm') || u.contains('g')) {
          totalWeightKg += it.quantity / 1000.0;
        }
      }
    }

    final currency = ref.watch(settingsProvider).valueOrNull?.currency ?? '₹';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: orders.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : AppColors.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Total Orders',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text('${orders.length}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary)),
                  ],
                ),
                Container(
                    height: 22,
                    width: 1,
                    color: isDark ? Colors.white24 : Colors.black12),
                Column(
                  children: [
                    const Text('Total Weight',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text('${totalWeightKg.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.teal)),
                  ],
                ),
                Container(
                    height: 22,
                    width: 1,
                    color: isDark ? Colors.white24 : Colors.black12),
                Column(
                  children: [
                    const Text('Total Value',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(AppFormatters.currency(totalAmount, symbol: currency),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.success)),
                  ],
                ),
              ],
            ),
          );
        }

        final order = orders[i - 1];
        return _OrderCard(
          order: order,
          onTap: () => Navigator.of(ctx).pushNamed(
            AppRoutes.orderDetail,
            arguments: {'orderId': order.id},
          ).then((_) => ref.invalidate(orderManagementProvider)),
          onToggleDelivery: () => _toggleDelivery(order),
          onAddPayment: () => _addPayment(ctx, order),
          onEdit: () => Navigator.of(ctx).pushNamed(
            AppRoutes.createOrder,
            arguments: {
              'customerId': order.customerId,
              'customerName': order.customerName ?? '',
              'orderId': order.id,
            },
          ).then((_) => ref.invalidate(orderManagementProvider)),
          onDelete: () => _deleteOrder(order),
          onDuplicate: () => _duplicateOrder(order),
        ).animate(delay: ((i - 1) * 30).ms).fadeIn();
      },
    );
  }

  Future<void> _toggleDelivery(AppOrder order) async {
    final newStatus = order.deliveryStatus == AppConstants.statusDelivered
        ? AppConstants.statusPending
        : (order.deliveryStatus == AppConstants.statusCancelled
            ? AppConstants.statusPending
            : AppConstants.statusDelivered);
    try {
      await ref
          .read(orderManagementProvider.notifier)
          .updateDeliveryStatus(order.id, newStatus);
      if (mounted) {
        SnackbarHelper.showSuccess(context,
            'Order marked as ${AppFormatters.deliveryStatus(newStatus).toUpperCase()}');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to update status: $e');
      }
    }
  }

  Future<void> _addPayment(BuildContext context, AppOrder order) async {
    final settings = ref.read(settingsProvider).valueOrNull;
    final currency = settings?.currency ?? '₹';
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.paymentDetails,
      arguments: {
        'customerId': order.customerId,
        'remainingAmount': order.remainingAmount,
        'grandTotal': order.grandTotal,
        'currency': currency,
      },
    );

    if (result != null && result is Map<String, dynamic>) {
      final amount = (result['amount'] as num?)?.toDouble() ?? 0.0;
      final method = (result['method'] as String?) ?? 'cash';
      final notes = (result['notes'] as String?) ?? '';

      try {
        await ref.read(orderManagementProvider.notifier).addPayment(Payment(
              id: const Uuid().v4(),
              orderId: order.id,
              customerId: order.customerId,
              amount: amount,
              method: method,
              notes: notes,
              createdAt: DateTime.now(),
            ));

        if (context.mounted) {
          SnackbarHelper.showSuccess(
              context, 'Payment of $currency$amount added');
        }
      } catch (e) {
        if (context.mounted) {
          SnackbarHelper.showError(context, 'Failed to add payment: $e');
        }
      }
    }
  }

  Future<void> _deleteOrder(AppOrder order) async {
    final ok = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete Order',
      message: 'Delete this order permanently?',
    );
    if (!ok) return;

    try {
      await ref.read(orderManagementProvider.notifier).deleteOrder(order.id);
      if (mounted) SnackbarHelper.showSuccess(context, 'Order deleted');
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to delete order: $e');
      }
    }
  }

  Future<void> _duplicateOrder(AppOrder order) async {
    try {
      final repo = ref.read(orderRepositoryProvider);
      final items = await repo.getOrderItems(order.id);
      final inventoryList =
          await ref.read(inventoryRepositoryProvider).getAllItems();

      for (final it in items) {
        final dbItem = inventoryList.firstWhere(
          (i) => i.id == it.itemId,
          orElse: () => Item(
            id: '',
            name: '',
            category: 'Other',
            unit: 'kg',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        if (dbItem.id.isNotEmpty && it.quantity > dbItem.stock) {
          if (mounted) {
            SnackbarHelper.showError(context,
                'Cannot duplicate. Insufficient stock for "${it.itemName}" (${dbItem.stock} ${dbItem.unit} available)');
          }
          return;
        }
      }

      final now = DateTime.now();
      final newId = await OrderDao.generateUniqueOrderNo();
      final duplicate = order.copyWith(
        id: newId,
        paidAmount: 0,
        remainingAmount: order.grandTotal,
        deliveryStatus: AppConstants.statusPending,
        createdAt: now,
        updatedAt: now,
        payments: const [],
      );

      await ref.read(orderManagementProvider.notifier).createOrder(
          duplicate,
          items
              .map((it) => it.copyWith(id: const Uuid().v4(), orderId: newId))
              .toList());
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Order duplicated');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to duplicate order: $e');
      }
    }
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsVal = ref.watch(settingsProvider).valueOrNull;
    final currency = settingsVal?.currency ?? '₹';
    final customerAsync = ref.watch(customerDetailProvider(order.customerId));

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.customerProfile,
                          arguments: {'customerId': order.customerId},
                        );
                      },
                      child: customerAsync.when(
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
                        error: (_, __) =>
                            const CustomerAvatar(photoPath: '', radius: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.customerProfile,
                            arguments: {'customerId': order.customerId},
                          );
                        },
                        child: Text(
                          '${order.orderNoLabel} · ${(order.customerName != null && order.customerName!.trim().isNotEmpty) ? order.customerName!.trim() : 'Unknown'}',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    StatusDotBadge(status: order.deliveryStatus),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: AppColors.gray500, size: 20),
                      onSelected: (v) async {
                        if (v == 'profile') {
                          Navigator.of(context).pushNamed(
                            AppRoutes.customerProfile,
                            arguments: {'customerId': order.customerId},
                          );
                        }
                        if (v == 'invoice') {
                          try {
                            final cust = await ref.read(
                                customerDetailProvider(order.customerId).future);
                            final settings =
                                ref.read(settingsProvider).valueOrNull;
                            final rawItems = await ref
                                .read(orderRepositoryProvider)
                                .getOrderItems(order.id);
                            final itemsList = rawItems
                                .map((i) => {
                                      'item_name': i.itemName,
                                      'quantity': i.quantity,
                                      'unit': i.itemUnit,
                                      'unit_price': i.unitPrice,
                                      'total_price': i.totalPrice,
                                    })
                                .toList();
                            if (context.mounted) {
                              await GraphicBillGenerator
                                  .generateAndShareGraphicBill(
                                context: context,
                                order: order,
                                customer: cust,
                                settings: settings,
                                orderItems: itemsList,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              SnackbarHelper.showError(
                                  context, 'Failed to generate invoice: $e');
                            }
                          }
                        }
                        if (v == 'whatsapp_review') {
                          final settingsVal = ref.read(settingsProvider).valueOrNull;
                          final bName = (settingsVal?.businessName.trim().isNotEmpty ?? false)
                              ? settingsVal!.businessName.trim()
                              : 'OrderKart Store';
                          final customerName = (order.customerName != null &&
                                  order.customerName!.trim().isNotEmpty)
                              ? order.customerName!.trim()
                              : 'Valued Customer';
                          final phone = order.customerPhone ?? '';

                          final defaultMessage =
                              'Namaste $customerName! 🙏\n\n'
                              'Thank you for your recent order (#${order.orderNoLabel}) from $bName! '
                              'We hope you are happy with the products and service.\n\n'
                              '⭐ We would love to hear your feedback! Please rate your experience:\n'
                              '1️⃣ Product Quality\n'
                              '2️⃣ Delivery Speed\n'
                              '3️⃣ Overall Service\n\n'
                              'Your feedback helps us serve you better! 🌿\n'
                              'Thank you, Team $bName';

                          final controller = TextEditingController(text: defaultMessage);

                          if (context.mounted) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Row(
                                  children: [
                                    Icon(Icons.rate_review_rounded, color: Color(0xFF25D366)),
                                    SizedBox(width: 8),
                                    Expanded(child: Text('WhatsApp Review Request', style: TextStyle(fontSize: 16))),
                                  ],
                                ),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'To: $customerName${phone.isNotEmpty ? " ($phone)" : ""}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text('Edit message before sending:',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: controller,
                                        maxLines: 10,
                                        minLines: 6,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          contentPadding: const EdgeInsets.all(12),
                                          hintText: 'Type your review request message...',
                                        ),
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      ExternalLauncher.launchWhatsApp(
                                        context,
                                        phone,
                                        text: controller.text,
                                      );
                                    },
                                    icon: const Icon(Icons.send_rounded, size: 18),
                                    label: const Text('Send via WhatsApp'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                        if (v == 'new_order') {
                          Navigator.of(context).pushNamed(
                            AppRoutes.createOrder,
                            arguments: {
                              'customerId': order.customerId,
                              'customerName': order.customerName ?? '',
                            },
                          );
                        }
                        if (v == 'edit') onEdit();
                        if (v == 'delete') onDelete();
                        if (v == 'duplicate') onDuplicate();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'profile', child: Text('Customer Profile')),
                        const PopupMenuItem(
                          value: 'invoice',
                          child: Row(
                            children: [
                              Icon(Icons.picture_as_pdf_rounded,
                                  size: 16, color: Color(0xFF0F766E)),
                              SizedBox(width: 8),
                              Text('Share Graphic Invoice'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'whatsapp_review',
                          child: Row(
                            children: [
                              Icon(Icons.rate_review_rounded,
                                  size: 16, color: Color(0xFF25D366)),
                              SizedBox(width: 8),
                              Text('WhatsApp Review'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'new_order',
                          child: Row(
                            children: [
                              Icon(Icons.add_shopping_cart_rounded,
                                  size: 16, color: Colors.teal),
                              SizedBox(width: 8),
                              Text('Create New Order'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                            value: 'duplicate', child: Text('Duplicate')),
                        const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Order Date & Delivery Date Row
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      AppFormatters.dateTime(order.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                    ),
                    if (order.deliveryDate != null &&
                        order.deliveryDate!.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_shipping_outlined,
                                size: 11, color: AppColors.primary),
                            const SizedBox(width: 3),
                            Text(
                              'Delivery: ${AppFormatters.dateFromString(order.deliveryDate!)}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 6),

                // Address / phone
                customerAsync.when(
                  data: (cust) {
                    if (cust == null) return const SizedBox.shrink();
                    return ref
                        .watch(locationPathNameProvider(cust.streetId))
                        .when(
                          data: (fullPath) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(top: 4, bottom: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white10
                                      : Colors.black12,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (cust.serialNo > 0 ||
                                      cust.houseNumber.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        [
                                          if (cust.serialNo > 0)
                                            'Serial: #${cust.serialNo}',
                                          if (cust.houseNumber.isNotEmpty)
                                            'House: ${cust.houseNumber}',
                                        ].join('  •  '),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  if (cust.address.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        'Address: ${cust.address}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: AppColors.textSecondary),
                                        softWrap: true,
                                      ),
                                    ),
                                  if (fullPath.isNotEmpty)
                                    Text(
                                      'Location: $fullPath',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11),
                                    ),
                                ],
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                if (order.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.notes_rounded,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.notes,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 8),

                // Amount row
                Row(
                  children: [
                    _amountChip(
                        context,
                        'Total',
                        '$currency${order.grandTotal.toStringAsFixed(2)}',
                        AppColors.primary),
                    if (order.deliveryCharge > 0) ...[
                      const SizedBox(width: 8),
                      _amountChip(
                          context,
                          'Delivery',
                          '+$currency${order.deliveryCharge.toStringAsFixed(0)}',
                          const Color(0xFF6366F1)),
                    ],
                    if (order.paidAmount > 0) ...[
                      const SizedBox(width: 8),
                      _amountChip(
                          context,
                          'Paid',
                          '$currency${order.paidAmount.toStringAsFixed(2)}',
                          AppColors.success),
                    ],
                    if (order.remainingAmount > 0) ...[
                      const SizedBox(width: 8),
                      _amountChip(
                          context,
                          'Due',
                          '$currency${order.remainingAmount.toStringAsFixed(2)}',
                          AppColors.warning),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // Time + action buttons
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 12, color: AppColors.gray400),
                    const SizedBox(width: 4),
                    Text(
                      order.orderType == 'Pre-Order'
                          ? 'Taking: ${order.orderTakingDate ?? '-'} | Delivery: ${order.deliveryDate ?? '-'}'
                          : AppFormatters.dateTime(order.createdAt),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: order.orderType == 'Pre-Order'
                                ? AppColors.primary
                                : AppColors.textHint,
                            fontWeight: order.orderType == 'Pre-Order'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Delivery toggle
                            _ActionBtn(
                              label:
                                  order.deliveryStatus == AppConstants.statusDelivered
                                      ? 'Delivered ✓'
                                      : (order.deliveryStatus ==
                                              AppConstants.statusCancelled
                                          ? 'Reactivate'
                                          : 'Mark Delivered'),
                              color:
                                  order.deliveryStatus == AppConstants.statusDelivered
                                      ? AppColors.success
                                      : (order.deliveryStatus ==
                                              AppConstants.statusCancelled
                                          ? AppColors.warning
                                          : AppColors.primary),
                              onTap: onToggleDelivery,
                            ),
                            const SizedBox(width: 6),
                            // Pay button
                            if (order.remainingAmount > 0) ...[
                              _ActionBtn(
                                label: 'Pay',
                                color: AppColors.warning,
                                onTap: onAddPayment,
                              ),
                              const SizedBox(width: 6),
                            ],
                            // Profile button
                            _ActionBtn(
                              label: 'Profile',
                              color: Colors.blueGrey,
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  AppRoutes.customerProfile,
                                  arguments: {'customerId': order.customerId},
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            // Invoice button
                            _ActionBtn(
                              label: 'Invoice',
                              color: const Color(0xFF0F766E),
                              onTap: () async {
                                try {
                                  final cust = await ref.read(
                                      customerDetailProvider(order.customerId).future);
                                  final settings = ref.read(settingsProvider).valueOrNull;
                                  final rawItems = await ref
                                      .read(orderRepositoryProvider)
                                      .getOrderItems(order.id);
                                  final itemsList = rawItems
                                      .map((i) => {
                                            'item_name': i.itemName,
                                            'quantity': i.quantity,
                                            'unit': i.itemUnit,
                                            'unit_price': i.unitPrice,
                                            'total_price': i.totalPrice,
                                          })
                                      .toList();
                                  if (context.mounted) {
                                    await GraphicBillGenerator
                                        .generateAndShareGraphicBill(
                                      context: context,
                                      order: order,
                                      customer: cust,
                                      settings: settings,
                                      orderItems: itemsList,
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    SnackbarHelper.showError(
                                        context, 'Failed to generate invoice: $e');
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
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
                  fontSize: 10, color: color, fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
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
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
