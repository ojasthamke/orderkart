import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../order/domain/payment.dart';
import '../../order/presentation/order_provider.dart';
import '../../order/presentation/widgets/payment_dialog.dart';
import '../domain/customer.dart';
import 'customer_provider.dart';

class CustomerProfileScreen extends ConsumerWidget {
  final String customerId;
  const CustomerProfileScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(customerId));
    final ordersAsync   = ref.watch(customerOrdersProvider(customerId));

    return customerAsync.when(
      loading: () => const AppScaffold(
        title: 'Customer Profile',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Customer Profile',
        body: Center(child: Text('Error loading customer: $e')),
      ),
      data: (customer) {
        if (customer == null) {
          return const AppScaffold(
            title: 'Customer Profile',
            body: Center(child: Text('Customer not found')),
          );
        }

        return AppScaffold(
          title: customer.name,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => Navigator.of(context)
                  .pushNamed(
                    AppRoutes.addEditCustomer,
                    arguments: {
                      'streetId': customer.streetId,
                      'customerId': customer.id,
                    },
                  )
                  .then((_) => ref.refresh(customerDetailProvider(customerId))),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmDelete(context, ref, customer),
            ),
          ],
          body: Column(
            children: [
              // Profile Header Card
              _buildProfileHeader(context, ref, customer),

              // Tabs / Quick Actions Row
              _buildQuickActions(context, ref, customer),

              // Orders title
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order History',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    ordersAsync.when(
                      data: (orders) => Text(
                        '${orders.length} orders',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              // Orders List
              Expanded(
                child: ordersAsync.when(
                  loading: () => const LoadingShimmer(),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (orders) => orders.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.shopping_basket_outlined,
                          title: 'No Orders Yet',
                          subtitle: 'Create the first order for this customer',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: orders.length,
                          itemBuilder: (ctx, i) {
                            final order = orders[i];
                            return _CustomerOrderTile(
                              order: order,
                              onTap: () => Navigator.of(context)
                                  .pushNamed(
                                    AppRoutes.orderDetail,
                                    arguments: {'orderId': order.id},
                                  )
                                  .then((_) {
                                    ref.refresh(customerDetailProvider(customerId));
                                    ref.refresh(customerOrdersProvider(customerId));
                                  }),
                            ).animate(delay: (i * 30).ms).fadeIn();
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, WidgetRef ref, Customer customer) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primarySurface,
                backgroundImage: customer.photoPath.isNotEmpty
                    ? AssetImage(customer.photoPath)
                    : null,
                child: customer.photoPath.isEmpty
                    ? Text(
                        customer.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 28,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.phone1,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    if (customer.address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        customer.address,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textHint),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _headerStat(context, 'Outstanding',
                  AppFormatters.currency(customer.outstandingBalance),
                  color: customer.outstandingBalance > 0
                      ? AppColors.error
                      : AppColors.success),
              _headerStat(context, 'Total Orders', '${customer.totalOrders}'),
              _headerStat(context, 'Total Paid',
                  AppFormatters.currency(customer.totalPaid)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(BuildContext context, String label, String value,
      {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color ?? AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildQuickActions(
      BuildContext context, WidgetRef ref, Customer customer) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Call
          _actionBtn(
            context: context,
            icon: Icons.phone_rounded,
            label: 'Call',
            color: AppColors.primary,
            onTap: () => launchUrl(Uri.parse('tel:${customer.phone1}')),
          ),
          // WhatsApp
          if (customer.whatsapp.isNotEmpty || customer.phone1.isNotEmpty)
            _actionBtn(
              context: context,
              icon: Icons.chat_rounded,
              label: 'WhatsApp',
              color: AppColors.success,
              onTap: () {
                final wa = customer.whatsapp.isNotEmpty
                    ? customer.whatsapp
                    : customer.phone1;
                launchUrl(Uri.parse('https://wa.me/$wa'));
              },
            ),
          // Create Order
          _actionBtn(
            context: context,
            icon: Icons.add_shopping_cart_rounded,
            label: 'New Order',
            color: AppColors.primary,
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.createOrder,
              arguments: {
                'customerId':   customer.id,
                'customerName': customer.name,
                'orderId':      null,
              },
            ).then((_) {
              ref.refresh(customerDetailProvider(customerId));
              ref.refresh(customerOrdersProvider(customerId));
            }),
          ),
          // Record Payment
          if (customer.outstandingBalance > 0)
            _actionBtn(
              context: context,
              icon: Icons.payments_rounded,
              label: 'Record Pay',
              color: AppColors.warning,
              onTap: () => _showPayDialog(context, ref, customer),
            ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withOpacity(0.2)),
          ),
        ),
      ),
    );
  }

  void _showPayDialog(BuildContext context, WidgetRef ref, Customer customer) {
    PaymentDialog.show(
      context,
      remainingAmount: customer.outstandingBalance,
      grandTotal:      customer.outstandingBalance,
      currency:        '₹',
      onPay: (amount, method, notes) async {
        // Record payment for outstanding balance
        // To do this, we can associate with a dummy/general payment or just update balance.
        // For compliance with our data model, payments belong to an order, so let's prompt them
        // to pay off their oldest pending order or apply payment directly.
        // We'll query orders and apply it. Or we can show a list of pending orders.
        // To keep it direct, we'll let them add a payment to the oldest pending order.
        final orders = ref.read(customerOrdersProvider(customer.id)).value;
        final pending = orders?.where((o) => o.remainingAmount > 0).toList();
        if (pending != null && pending.isNotEmpty) {
          final oldest = pending.last;
          await ref.read(orderManagementProvider.notifier).addPayment(Payment(
                id:         const Uuid().v4(),
                orderId:    oldest.id,
                customerId: customer.id,
                amount:     amount,
                method:     method,
                notes:      notes,
                createdAt:  DateTime.now(),
              ));
          ref.refresh(customerDetailProvider(customer.id));
          ref.refresh(customerOrdersProvider(customer.id));
          if (context.mounted) {
            SnackbarHelper.showSuccess(context, 'Payment of ₹$amount applied to Order #${oldest.id.substring(0,8).toUpperCase()}');
          }
        } else {
          if (context.mounted) {
            SnackbarHelper.showError(context, 'No pending orders found to apply payment');
          }
        }
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Customer customer) async {
    final ok = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete Customer',
      message: 'Delete "${customer.name}"? This will delete all order history.',
    );
    if (!ok) return;

    await ref
        .read(customerListProvider(customer.streetId).notifier)
        .delete(customer.id);
    if (context.mounted) {
      SnackbarHelper.showSuccess(context, '"${customer.name}" deleted');
      Navigator.of(context).pop();
    }
  }
}

class _CustomerOrderTile extends StatelessWidget {
  final AppOrder order;
  final VoidCallback onTap;

  const _CustomerOrderTile({required this.order, required this.onTap});

  Color get _statusColor {
    switch (order.deliveryStatus) {
      case 'delivered': return AppColors.delivered;
      case 'cancelled': return AppColors.cancelled;
      default:          return AppColors.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Row(
          children: [
            Text(
              'Order #${order.id.substring(0, 8).toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                AppFormatters.deliveryStatus(order.deliveryStatus),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _statusColor),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              AppFormatters.dateTime(order.createdAt),
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              AppFormatters.currency(order.grandTotal),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
            if (order.remainingAmount > 0)
              Text(
                'Due: ${AppFormatters.currency(order.remainingAmount)}',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }
}
