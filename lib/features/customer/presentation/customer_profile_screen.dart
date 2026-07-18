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
import '../../../core/widgets/vip_glow_avatar.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../order/domain/payment.dart';
import '../../order/presentation/order_provider.dart';
import '../domain/customer.dart';
import 'customer_provider.dart';
import 'widgets/instant_ledger_sheet.dart';
import '../../order/domain/order.dart';
import '../../../core/constants/app_constants.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../../core/utils/contact_exporter.dart';
import '../../order/data/order_questions_dao.dart';
import 'vip_dashboard_screen.dart';
import '../data/customer_dao.dart';

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
                  .then((_) => ref.invalidate(customerDetailProvider(customerId))),
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
                        .then((_) => ref.invalidate(customerDetailProvider(customerId)));
                    break;
                  case 'vip':
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => VipEditModal(existingCustomer: customer),
                    ).then((_) => ref.invalidate(customerDetailProvider(customerId)));
                    break;
                  case 'delete':
                    _confirmDelete(context, ref, customer);
                    break;
                  case 'welcome':
                    if (customer.customWelcomeMessage.isNotEmpty) {
                      await _showCustomMessageDialog(context, customer, ref);
                    } else {
                      await _sendDefaultWelcomeMessage(context, customer, ref);
                    }
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
                PopupMenuItem(
                  value: 'welcome',
                  child: Row(
                    children: [
                      Icon(
                        customer.customWelcomeMessage.isNotEmpty
                            ? Icons.chat_bubble_outline_rounded
                            : Icons.mark_chat_read_rounded,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        customer.customWelcomeMessage.isNotEmpty
                            ? 'Send Custom Message'
                            : 'Send Welcome Message',
                      ),
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
                              ref.invalidate(customerDetailProvider(customerId));
                              ref.invalidate(customerOrdersProvider(customerId));
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
                                       ref.invalidate(customerDetailProvider(customerId));
                                       ref.invalidate(customerOrdersProvider(customerId));
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

                CustomerPreferencesCard(
                  customerId: customer.id,
                  customerName: customer.name,
                ),

                CustomerCustomFieldsCard(customerId: customer.id),

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
                                    ref.invalidate(customerDetailProvider(customerId));
                                    ref.invalidate(customerOrdersProvider(customerId));
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
    return GlassContainer(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      borderColor: customer.isVipActive ? const Color(0xFFFFD700).withOpacity(0.7) : null,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                            softWrap: true,
                          ),
                        ),
                        if (customer.dietaryPreference.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _DietaryPreferenceIcon(preference: customer.dietaryPreference),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (customer.isVipActive) ...[
                      Row(
                        children: [
                          VipGoldBadgeChip(planName: customer.vipPlan),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ] else if (customer.isVip) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withOpacity(0.3), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Expired VIP (${customer.vipPlan})',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
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
                    if (customer.isVip) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: customer.isVipActive 
                              ? Colors.amber.withOpacity(0.06)
                              : Colors.red.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: customer.isVipActive 
                                ? Colors.amber.withOpacity(0.2)
                                : Colors.red.withOpacity(0.15),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  customer.isVipActive ? 'ACTIVE VIP SUBSCRIPTION' : 'EXPIRED VIP SUBSCRIPTION',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: customer.isVipActive ? Colors.amber[800] : Colors.red[800],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => VipEditModal(existingCustomer: customer),
                                    ).then((_) => ref.invalidate(customerDetailProvider(customerId)));
                                  },
                                  icon: const Icon(Icons.edit_rounded, size: 12, color: AppColors.primary),
                                  label: const Text(
                                    'Edit Membership',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Started: ${customer.vipStartDate.isNotEmpty ? AppFormatters.dateFromString(customer.vipStartDate) : "N/A"}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                Text(
                                  'Expires: ${customer.vipExpiryDate.isNotEmpty ? AppFormatters.dateFromString(customer.vipExpiryDate) : "N/A"}',
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: customer.isVipActive ? AppColors.textSecondary : Colors.red,
                                    fontWeight: customer.isVipActive ? FontWeight.normal : FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
              _headerStat(
                context,
                customer.outstandingBalance >= 0 ? 'Outstanding' : 'Credit / Advance',
                AppFormatters.currency(customer.outstandingBalance.abs()),
                color: customer.outstandingBalance > 0
                    ? AppColors.warning
                    : (customer.outstandingBalance < 0 ? Colors.teal : AppColors.textPrimary),
              ),
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
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white10
                      : Colors.black12,
                ),
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

        return GlassContainer(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF047857).withOpacity(0.85),
          borderColor: const Color(0xFF10B981).withOpacity(0.4),
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
                      var phoneDigits = cleanPhone.replaceAll(RegExp(r'\D'), '');
                      if (phoneDigits.length == 10) {
                        phoneDigits = '91$phoneDigits';
                      } else if (phoneDigits.length == 11 && phoneDigits.startsWith('0')) {
                        phoneDigits = '91${phoneDigits.substring(1)}';
                      }
                      final url = 'https://wa.me/$phoneDigits?text=${Uri.encodeComponent(msg.toString())}';
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
          // Instant Ledger
          _actionBtn(
            context: context,
            icon: Icons.account_balance_wallet_rounded,
            label: 'Ledger',
            color: Colors.blueGrey,
            onTap: () => InstantLedgerSheet.show(context, customer),
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
    final currencySymbol = ref.read(settingsProvider).valueOrNull?.currency ?? AppConstants.defaultCurrency;
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.paymentDetails,
      arguments: {
        'customerId': customer.id,
        'remainingAmount': customer.outstandingBalance,
        'grandTotal': customer.outstandingBalance,
        'currency': currencySymbol,
      },
    );

    if (result != null && result is Map<String, dynamic>) {
      final amount = result['amount'] as double;
      final method = result['method'] as String;
      final notes = result['notes'] as String;

      final orders = await ref.read(orderRepositoryProvider).getAllOrders(customerId: customer.id);
      final pending = orders.where((o) => o.remainingAmount > 0).toList();
      if (pending.isNotEmpty) {
        final sortedPending = pending.reversed.toList();
        double remainingPayment = amount;
        final listApplied = <String>[];

        for (final order in sortedPending) {
          if (remainingPayment <= 0) break;
          final payForThisOrder = remainingPayment > order.remainingAmount ? order.remainingAmount : remainingPayment;
          await ref.read(orderManagementProvider.notifier).addPayment(Payment(
                id:         const Uuid().v4(),
                orderId:    order.id,
                customerId: customer.id,
                amount:     payForThisOrder,
                method:     method,
                notes:      notes,
                createdAt:  DateTime.now(),
              ));
          remainingPayment -= payForThisOrder;
          listApplied.add('$currencySymbol$payForThisOrder to Order ${order.orderNoLabel}');
        }

        if (remainingPayment > 0) {
          final newest = pending.first;
          await ref.read(orderManagementProvider.notifier).addPayment(Payment(
                id:         const Uuid().v4(),
                orderId:    newest.id,
                customerId: customer.id,
                amount:     remainingPayment,
                method:     method,
                notes:      '$notes (Excess Payment)',
                createdAt:  DateTime.now(),
              ));
          listApplied.add('$currencySymbol$remainingPayment (Excess) to Order ${newest.orderNoLabel}');
        }

        ref.invalidate(customerDetailProvider(customer.id));
        ref.invalidate(customerOrdersProvider(customer.id));
        ref.invalidate(pendingCustomersProvider);
        ref.invalidate(allCustomersProvider);
        if (context.mounted) {
          final summary = listApplied.join(', ');
          SnackbarHelper.showSuccess(context, 'Payment applied: $summary');
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
    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      borderRadius: BorderRadius.circular(14),
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
            if (order.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.notes_rounded, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.notes,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
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

class CustomerPreferencesCard extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerPreferencesCard({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CustomerPreferencesCard> createState() => _CustomerPreferencesCardState();
}

class _CustomerPreferencesCardState extends State<CustomerPreferencesCard> {
  List<OrderQuestion> _questions = [];
  Map<String, String> _answers = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final qList = await OrderQuestionDao.instance.getAllQuestionsForCustomer(widget.customerId);
      final ansMap = await OrderQuestionDao.instance.getCustomerAnswers(widget.customerId);
      setState(() {
        _questions = qList;
        _answers = ansMap;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _showAddSpecificQuestionDialog() {
    AppHaptics.buttonClick();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Specific Question', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: _AddSpecificQuestionForm(
          customerId: widget.customerId,
          onSaved: () {
            Navigator.pop(context);
            _load();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return GlassContainer(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      );
    }

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment_turned_in_rounded, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Order Notes Preferences',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _showAddSpecificQuestionDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Specific Q', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const Divider(),
            if (_questions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'No order questions configured yet.',
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _questions.length,
                itemBuilder: (context, idx) {
                  final q = _questions[idx];
                  final selected = _answers[q.id];
                  final isSpecific = q.customerId != null && q.customerId!.isNotEmpty;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      q.question,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    ),
                                  ),
                                  if (isSpecific)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Specific',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selected != null ? 'Answer: $selected' : 'Answer: Not set (uses common/default)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: selected != null ? AppColors.success : AppColors.textSecondary,
                                  fontWeight: selected != null ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownButton<String>(
                          value: q.options.contains(selected) ? selected : null,
                          hint: const Text('Select', style: TextStyle(fontSize: 12)),
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down_rounded),
                          items: q.options.map((opt) {
                            return DropdownMenuItem<String>(
                              value: opt,
                              child: Text(opt, style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                          onChanged: (val) async {
                            if (val != null) {
                              AppHaptics.buttonClick();
                              await OrderQuestionDao.instance.saveCustomerAnswer(widget.customerId, q.id, val);
                              _load();
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AddSpecificQuestionForm extends StatefulWidget {
  final String customerId;
  final VoidCallback onSaved;

  const _AddSpecificQuestionForm({required this.customerId, required this.onSaved});

  @override
  State<_AddSpecificQuestionForm> createState() => _AddSpecificQuestionFormState();
}

class _AddSpecificQuestionFormState extends State<_AddSpecificQuestionForm> {
  final _formKey = GlobalKey<FormState>();
  final _questionCon = TextEditingController();
  final List<TextEditingController> _optionCons = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionCon.dispose();
    for (final c in _optionCons) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    AppHaptics.buttonClick();
    setState(() {
      _optionCons.add(TextEditingController());
    });
  }

  void _removeOption(int idx) {
    AppHaptics.buttonClick();
    setState(() {
      _optionCons[idx].dispose();
      _optionCons.removeAt(idx);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final question = _questionCon.text.trim();
    final options = _optionCons.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

    if (options.isEmpty) {
      SnackbarHelper.showError(context, 'Please add at least 1 option');
      return;
    }

    try {
      await OrderQuestionDao.instance.addQuestion(question, options, customerId: widget.customerId);
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save specific question: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _questionCon,
              decoration: const InputDecoration(
                labelText: 'Question Text',
                hintText: 'e.g., how should be the tomato?',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter question text' : null,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Options:', style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                  onPressed: _addOption,
                ),
              ],
            ),
            ...List.generate(_optionCons.length, (idx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _optionCons[idx],
                        decoration: InputDecoration(
                          labelText: 'Option ${idx + 1}',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter option text' : null,
                      ),
                    ),
                    if (_optionCons.length > 1) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        onPressed: () => _removeOption(idx),
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: _submit,
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class CustomerCustomFieldsCard extends StatefulWidget {
  final String customerId;

  const CustomerCustomFieldsCard({super.key, required this.customerId});

  @override
  State<CustomerCustomFieldsCard> createState() => _CustomerCustomFieldsCardState();
}

class _CustomerCustomFieldsCardState extends State<CustomerCustomFieldsCard> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  @override
  void didUpdateWidget(CustomerCustomFieldsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId != widget.customerId) {
      _future = _loadData();
    }
  }

  Future<List<Map<String, dynamic>>> _loadData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      return await db.rawQuery('''
        SELECT cf.field_name, cfv.value
        FROM custom_field_values cfv
        JOIN custom_fields cf ON cfv.field_id = cf.id
        WHERE cfv.entity_id = ? AND cf.entity_type = 'customer'
      ''', [widget.customerId]);
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        return GlassContainer(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dashboard_customize_rounded, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Custom Attributes',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...data.map((row) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          row['field_name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        Text(
                          row['value'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DietaryPreferenceIcon extends StatelessWidget {
  final String preference;
  static const double size = 18;

  const _DietaryPreferenceIcon({
    required this.preference,
  });

  @override
  Widget build(BuildContext context) {
    if (preference != 'veg' && preference != 'non_veg') {
      return const SizedBox.shrink();
    }
    final isVeg = preference == 'veg';
    final color = isVeg ? Colors.green.shade700 : Colors.red.shade800;

    return Tooltip(
      message: isVeg ? 'Veg Customer' : 'Non-Veg Customer',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.22),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

Future<void> _sendDefaultWelcomeMessage(BuildContext context, Customer customer, WidgetRef ref) async {
  final msg = StringBuffer();
  msg.writeln('Hello dear customer,');
  msg.writeln();
  msg.writeln('Welcome to OrderKart! 🛒💚');
  msg.writeln();
  msg.writeln('Thank you for joining us. We are very happy to serve you! Here is how we work:');
  msg.writeln();
  msg.writeln('* 🌾 *Best Quality*: Fresh and clean vegetables delivered to your home.');
  msg.writeln('* 💰 *Wholesale Rates*: You can order any quantity at wholesale rates.');
  msg.writeln('* 📅 *Weekly Visits*: Our agent visits you once a week.');
  msg.writeln('* ⚡ *Doorstep Delivery*: Simply give your order to our agent when he arrives at your door, and the fresh vegetables will be delivered to your doorstep.');
  msg.writeln('* 🤝 *Trusted Service*: Honest pricing with zero compromise on quality.');
  msg.writeln();
  msg.writeln('_Note: We take weekly orders only through our agent when he visits._');
  msg.writeln();
  msg.writeln('Contact No: 9021107009');
  msg.writeln();
  msg.writeln('Thank you,');
  msg.writeln('OrderKart Team');

  final cleanPhone = customer.whatsapp.isNotEmpty ? customer.whatsapp : customer.phone1;
  var phoneDigits = cleanPhone.replaceAll(RegExp(r'\D'), '');
  if (phoneDigits.length == 10) {
    phoneDigits = '91$phoneDigits';
  } else if (phoneDigits.length == 11 && phoneDigits.startsWith('0')) {
    phoneDigits = '91${phoneDigits.substring(1)}';
  }
  final url = 'https://wa.me/$phoneDigits?text=${Uri.encodeComponent(msg.toString())}';
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    
    // Prompt done confirmation dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Done?'),
          content: const Text('Did you successfully send the welcome message to the customer? Click Done to convert it to a custom message.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await CustomerDao().updateCustomWelcomeMessage(customer.id, msg.toString());
                  ref.invalidate(customerDetailProvider(customer.id));
                } catch (_) {}
              },
              child: const Text('Done?'),
            ),
          ],
        ),
      );
    }
  } else {
    if (context.mounted) SnackbarHelper.showError(context, 'Could not open WhatsApp');
  }
}

Future<void> _showCustomMessageDialog(BuildContext context, Customer customer, WidgetRef ref) async {
  final controller = TextEditingController(text: customer.customWelcomeMessage);

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Send Custom Message'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit message draft below to send to this customer:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 8,
              style: const TextStyle(fontSize: 13, height: 1.4),
              decoration: InputDecoration(
                hintText: 'Type your custom welcome message here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final text = controller.text.trim();
            if (text.isEmpty) {
              SnackbarHelper.showError(context, 'Message cannot be empty');
              return;
            }
            Navigator.pop(ctx);
            
            final cleanPhone = customer.whatsapp.isNotEmpty ? customer.whatsapp : customer.phone1;
            var phoneDigits = cleanPhone.replaceAll(RegExp(r'\D'), '');
            if (phoneDigits.length == 10) {
              phoneDigits = '91$phoneDigits';
            } else if (phoneDigits.length == 11 && phoneDigits.startsWith('0')) {
              phoneDigits = '91${phoneDigits.substring(1)}';
            }
            final url = 'https://wa.me/$phoneDigits?text=${Uri.encodeComponent(text)}';
            final uri = Uri.parse(url);
            
            AppHaptics.buttonClick();
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              
              // Prompt done confirmation dialog
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (confirmCtx) => AlertDialog(
                    title: const Text('Done?'),
                    content: const Text('Did you successfully send the message? Click Done to save the message draft.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(confirmCtx),
                        child: const Text('No'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(confirmCtx);
                          try {
                            await CustomerDao().updateCustomWelcomeMessage(customer.id, text);
                            ref.invalidate(customerDetailProvider(customer.id));
                            if (context.mounted) {
                              SnackbarHelper.showSuccess(context, 'Custom message saved!');
                            }
                          } catch (_) {}
                        },
                        child: const Text('Done?'),
                      ),
                    ],
                  ),
                );
              }
            } else {
              if (context.mounted) {
                SnackbarHelper.showError(context, 'Could not open WhatsApp');
              }
            }
          },
          child: const Text('Send'),
        ),
      ],
    ),
  );
}

