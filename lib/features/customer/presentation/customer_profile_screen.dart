import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/external_launcher.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/customer_avatar.dart';
import '../../../core/widgets/vip_glow_avatar.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/widgets/ownership_badge.dart';
import '../../order/domain/payment.dart';
import '../../order/presentation/order_provider.dart';
import '../domain/customer.dart';
import 'customer_provider.dart';
import '../../order/domain/order.dart';
import '../../../core/constants/app_constants.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../order/presentation/order_provider.dart';
import '../../../core/utils/contact_exporter.dart';

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
              tooltip: 'Edit Customer Profile',
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'More Options',
              onSelected: (value) async {
                AppHaptics.buttonClick();
                switch (value) {
                  case 'contact':
                    final phoneToSave = customer.phone1.trim().isNotEmpty
                        ? customer.phone1
                        : (customer.whatsapp.trim().isNotEmpty ? customer.whatsapp : customer.phone2);
                    await ContactExporter.saveCustomerToContacts(
                      context,
                      name: customer.name,
                      phone: phoneToSave,
                      address: customer.address,
                      notes: customer.notes,
                    );
                    break;
                  case 'edit':
                    Navigator.of(context)
                        .pushNamed(
                          AppRoutes.addEditCustomer,
                          arguments: {
                            'streetId': customer.streetId,
                            'customerId': customer.id,
                          },
                        )
                        .then((_) => ref.refresh(customerDetailProvider(customerId)));
                    break;
                  case 'vip':
                    Navigator.of(context).pushNamed(AppRoutes.vipDashboard);
                    break;
                  case 'delete':
                    _confirmDelete(context, ref, customer);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'contact',
                  child: Row(
                    children: [
                      Icon(Icons.person_add_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 12),
                      Text('Save to Device Contacts'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 20),
                      SizedBox(width: 12),
                      Text('Edit Details'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'vip',
                  child: Row(
                    children: [
                      Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 20),
                      SizedBox(width: 12),
                      Text('VIP Club Membership'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                      SizedBox(width: 12),
                      Text('Delete Customer', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header Card
                _buildProfileHeader(context, ref, customer),
                _buildOwnershipCard(context, customer),

                // ── Big "Create New Order" CTA & Quick Reorder ──────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).pushNamed(
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
                            icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                            label: const Text(
                              'Create Order',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ordersAsync.maybeWhen(
                        data: (orders) => orders.isNotEmpty
                            ? SizedBox(
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    final latestOrder = orders.first;
                                    Navigator.of(context).pushNamed(
                                      AppRoutes.createOrder,
                                      arguments: {
                                        'customerId':   customer.id,
                                        'customerName': customer.name,
                                        'orderId':      latestOrder.id, // loads items into cart
                                      },
                                    ).then((_) {
                                      ref.refresh(customerDetailProvider(customerId));
                                      ref.refresh(customerOrdersProvider(customerId));
                                    });
                                  },
                                  icon: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
                                  label: const Text(
                                    'Reorder Last',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.amber, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Tabs / Quick Actions Row
                _buildQuickActions(context, ref, customer),

                // Customer Savings Tracker Card & WhatsApp Share
                _buildSavingsTrackerCard(context, ref, customer),

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
                ordersAsync.when(
                  loading: () => const LoadingShimmer(count: 3),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (orders) => orders.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.shopping_basket_outlined,
                          title: 'No Orders Yet',
                          subtitle: 'Create the first order for this customer',
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
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
              ],
            ),
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
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: customer.isVipActive ? const Color(0xFFFFD700) : AppColors.gray200,
          width: customer.isVipActive ? 1.5 : 1.0,
        ),
        boxShadow: customer.isVipActive
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VipGlowAvatar(
                photoPath: customer.photoPath,
                isVip: customer.isVipActive,
                radius: 36,
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
                          ?.copyWith(fontWeight: FontWeight.w900),
                      softWrap: true,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (customer.isVipActive) ...[
                          VipGoldBadgeChip(planName: customer.vipPlan),
                          const SizedBox(width: 8),
                        ],
                        OwnershipBadge(
                          createdBy: customer.createdBy,
                          workerName: customer.workerName,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Phone: ${customer.phone1}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    if (customer.phone2.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Phone 2: ${customer.phone2}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                    if (customer.whatsapp.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'WhatsApp: ${customer.whatsapp}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ref.watch(customerLocationProvider(customer.streetId)).when(
                      data: (loc) {
                        final streetName = loc['street'] ?? '';
                        final areaName = loc['area'] ?? '';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (customer.serialNo > 0 || customer.houseNumber.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  [
                                    if (customer.serialNo > 0) 'Serial No: #${customer.serialNo}',
                                    if (customer.houseNumber.isNotEmpty) 'House No: ${customer.houseNumber}',
                                  ].join('  •  '),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                                ),
                              ),
                            if (streetName.isNotEmpty || areaName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'Route: $streetName  •  Area: $areaName',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800),
                                ),
                              ),
                            if (customer.address.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'Address: ${customer.address}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.textHint),
                                  softWrap: true,
                                ),
                              ),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
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
                      ? AppColors.warning
                      : AppColors.success),
              _headerStat(context, 'Total Orders', '${customer.totalOrders}'),
              _headerStat(context, 'Total Paid',
                  AppFormatters.currency(customer.totalPaid)),
            ],
          ),
          if (customer.notes.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'NOTES',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray500),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF141414)
                    : AppColors.gray50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gray200),
              ),
              child: SelectableText(
                customer.notes,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOwnershipCard(BuildContext context, Customer customer) {
    final isOwner = customer.createdBy.toLowerCase() == 'owner' || (customer.createdBy.isEmpty && customer.assignedWorkerId.isEmpty);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Data Ownership & Attribution',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              OwnershipBadge(
                createdBy: customer.createdBy,
                workerName: customer.workerName,
              ),
            ],
          ),
          const Divider(height: 16),
          _infoRow('Source', isOwner ? 'Owner' : 'Worker'),
          _infoRow('Created By', isOwner ? 'Owner' : (customer.workerName.isNotEmpty ? customer.workerName : 'Worker')),
          if (customer.assignedWorkerId.isNotEmpty)
            _infoRow('Worker ID', customer.assignedWorkerId),
          if (customer.deviceName.isNotEmpty)
            _infoRow('Device Name', customer.deviceName),
          _infoRow('Created Date', AppFormatters.dateTime(customer.createdAt)),
          _infoRow('Last Updated', AppFormatters.dateTime(customer.updatedAt)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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

  Widget _buildSavingsTrackerCard(BuildContext context, WidgetRef ref, Customer customer) {
    final savingsAsync = ref.watch(customerSavingsProvider(customer.id));
    final currency     = ref.watch(settingsProvider).value?.currency ?? AppConstants.defaultCurrency;
    final businessName = ref.watch(settingsProvider).value?.businessName ?? 'OrderKart';

    return savingsAsync.when(
      loading: () => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 90,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF047857), Color(0xFF10B981)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (savings) {
        final totalSavings   = savings['total']   ?? 0.0;
        final monthlySavings = savings['monthly'] ?? 0.0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF047857), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Text('🎉', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text(
                        'SAVINGS TRACKER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      AppHaptics.buttonClick();
                      final msg = StringBuffer();
                      msg.writeln('🎉 *CONGRATULATIONS ${customer.name.toUpperCase()}!* 🥳✨');
                      msg.writeln();
                      if (monthlySavings > 0) {
                        msg.writeln('This month you saved *${AppFormatters.currency(monthlySavings, symbol: currency)}* by shopping with us!');
                      }
                      if (totalSavings > 0) {
                        msg.writeln('Your total all-time savings: *${AppFormatters.currency(totalSavings, symbol: currency)}* 🛒');
                      }
                      if (totalSavings == 0) {
                        msg.writeln('Thank you for shopping with *$businessName*! 🙏');
                      } else {
                        msg.writeln();
                        msg.writeln('Thank you for your valuable trust & business at *$businessName*! 🙏');
                      }
                      final cleanPhone = customer.whatsapp.isNotEmpty ? customer.whatsapp : customer.phone1;
                      final phone = cleanPhone.replaceAll(RegExp(r'[^0-9+]'), '');
                      final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(msg.toString())}';
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        if (context.mounted) SnackbarHelper.showError(context, 'Could not open WhatsApp');
                      }
                    },
                    icon: const Icon(Icons.share_rounded, size: 14, color: Colors.green),
                    label: const Text('Share Savings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade900,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
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
                      const Text("This Month's Savings",
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        monthlySavings > 0
                            ? AppFormatters.currency(monthlySavings, symbol: currency)
                            : '—',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total All-Time Savings',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        totalSavings > 0
                            ? AppFormatters.currency(totalSavings, symbol: currency)
                            : '—',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
              if (totalSavings == 0) ...[
                const SizedBox(height: 6),
                const Text(
                  'Savings appear once items have market prices set in inventory.',
                  style: TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(
      BuildContext context, WidgetRef ref, Customer customer) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Save Contact
          _actionBtn(
            context: context,
            icon: Icons.person_add_rounded,
            label: 'Save Contact',
            color: const Color(0xFF8B5CF6),
            onTap: () {
              final phoneToSave = customer.phone1.trim().isNotEmpty
                  ? customer.phone1
                  : (customer.whatsapp.trim().isNotEmpty ? customer.whatsapp : customer.phone2);
              ContactExporter.saveCustomerToContacts(
                context,
                name: customer.name,
                phone: phoneToSave,
                address: customer.address,
                notes: customer.notes,
              );
            },
          ),
          // Call
          _actionBtn(
            context: context,
            icon: Icons.phone_rounded,
            label: 'Call',
            color: AppColors.primary,
            onTap: () => ExternalLauncher.launchCall(context, customer.phone1),
          ),
          // WhatsApp
          if (customer.whatsapp.isNotEmpty || customer.phone1.isNotEmpty)
            _actionBtn(
              context: context,
              icon: Icons.chat_rounded,
              label: 'WhatsApp',
              color: AppColors.success,
              onTap: () => ExternalLauncher.launchWhatsApp(
                  context,
                  customer.whatsapp.isNotEmpty
                      ? customer.whatsapp
                      : customer.phone1),
            ),
          // Google Maps
          if (customer.mapsLocation.isNotEmpty)
            _actionBtn(
              context: context,
              icon: Icons.map_rounded,
              label: 'Map',
              color: Colors.blue,
              onTap: () => ExternalLauncher.openMap(context, customer.mapsLocation),
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



  Future<void> _showPayDialog(BuildContext context, WidgetRef ref, Customer customer) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.paymentDetails,
      arguments: {
        'customerId': customer.id,
        'remainingAmount': customer.outstandingBalance,
        'grandTotal': customer.outstandingBalance,
        'currency': '₹',
      },
    );

    if (result != null && result is Map<String, dynamic>) {
      final amount = result['amount'] as double;
      final method = result['method'] as String;
      final notes = result['notes'] as String;

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
          SnackbarHelper.showSuccess(context, 'Payment of ₹$amount applied to Order ${oldest.orderNoLabel}');
        }
      } else {
        if (context.mounted) {
          SnackbarHelper.showInfo(context, 'No pending orders found to apply payment.');
        }
      }
    }
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
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Row(
          children: [
            Text(
              'Order ${order.orderNoLabel}',
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
