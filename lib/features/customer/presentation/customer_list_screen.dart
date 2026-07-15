import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/vip_glow_avatar.dart';
import '../domain/customer.dart';
import 'customer_provider.dart';
import 'widgets/instant_ledger_sheet.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  final String? streetId;
  final String? streetName;

  const CustomerListScreen({
    super.key,
    this.streetId,
    this.streetName,
  });

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  @override
  Widget build(BuildContext context) {
    final effectiveStreetId = widget.streetId ?? '';
    final customersAsync = ref.watch(customerListProvider(effectiveStreetId));

    return AppScaffold(
      title: widget.streetName ?? 'All Customers',
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.search),
        ),
      ],
      floatingActionButton: widget.streetId != null 
        ? FloatingActionButton(
            heroTag: 'add_customer',
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.addEditCustomer,
              arguments: {'streetId': widget.streetId},
            ).then((_) => ref.refresh(customerListProvider(effectiveStreetId))),
            child: const Icon(Icons.person_add_rounded),
          )
        : null,
      body: Column(
        children: [
          CustomSearchBar(
            hint: 'Search customers, phone, house no...',
            onChanged: (q) =>
                ref.read(customerListProvider(effectiveStreetId).notifier).search(q),
          ),

          Expanded(
            child: customersAsync.when(
              loading: () => const LoadingShimmer(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (rawCustomers) {
                final customers = rawCustomers;

                if (customers.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.people_outline_rounded,
                    title: 'No Customers Found',
                    subtitle: 'Try changing search filter',
                    actionLabel: 'Add Customer',
                    onAction: () {
                      if (widget.streetId != null) {
                        Navigator.of(context)
                          .pushNamed(
                            AppRoutes.addEditCustomer,
                            arguments: {'streetId': widget.streetId},
                          )
                          .then((_) =>
                              ref.refresh(customerListProvider(effectiveStreetId)));
                      }
                    },
                  );
                }

                return ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: customers.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    ref
                        .read(customerListProvider(effectiveStreetId).notifier)
                        .reorder(oldIndex, newIndex);
                  },
                  itemBuilder: (ctx, i) => KeyedSubtree(
                    key: ValueKey(customers[i].id),
                    child: _CustomerCard(
                      customer: customers[i],
                      streetId: effectiveStreetId,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends ConsumerWidget {
  final Customer customer;
  final String streetId;

  const _CustomerCard({
    required this.customer,
    required this.streetId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context)
              .pushNamed(AppRoutes.customerProfile,
                  arguments: {'customerId': customer.id})
              .then((_) => ref.refresh(customerListProvider(streetId))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                VipGlowAvatar(
                  photoPath: customer.photoPath,
                  isVip: customer.isVipActive,
                  radius: 26,
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Serial number badge
                          if (customer.serialNo > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${customer.serialNo}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                  softWrap: true,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (customer.isVipActive)
                                      VipGoldBadgeChip(planName: customer.vipPlan)
                                    else
                                      _buildTagBadge(customer.tag),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (customer.outstandingBalance > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.warningSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                AppFormatters.currency(
                                    customer.outstandingBalance),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Phone: ${customer.phone1}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      ref.watch(customerLocationProvider(customer.streetId)).when(
                        data: (loc) {
                          final streetName = loc['street'] ?? '';
                          final areaName = loc['area'] ?? '';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (customer.houseNumber.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    'House No: ${customer.houseNumber}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              if (customer.address.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    'Address: ${customer.address}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.textHint),
                                    softWrap: true,
                                  ),
                                ),
                              if (streetName.isNotEmpty || areaName.isNotEmpty)
                                Text(
                                  'Route: $streetName • Area: $areaName',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10),
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
                // Three-dot menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.gray500),
                  onSelected: (v) async {
                    if (v == 'order') {
                      Navigator.of(context).pushNamed(
                        AppRoutes.createOrder,
                        arguments: {
                          'customerId':   customer.id,
                          'customerName': customer.name,
                          'orderId':      null,
                        },
                      ).then((_) =>
                          ref.refresh(customerListProvider(streetId)));
                    } else if (v == 'edit') {
                      Navigator.of(context)
                          .pushNamed(
                        AppRoutes.addEditCustomer,
                        arguments: {
                          'streetId':   streetId,
                          'customerId': customer.id,
                        },
                      )
                          .then((_) =>
                              ref.refresh(customerListProvider(streetId)));
                    } else if (v == 'ledger') {
                      InstantLedgerSheet.show(context, customer);
                    } else if (v == 'delete') {
                      final ok = await ConfirmDeleteDialog.show(
                        context,
                        title: 'Delete Customer',
                        message:
                            'Delete "${customer.name}"? All orders will also be deleted.',
                      );
                      if (!ok) return;
                      await ref
                          .read(customerListProvider(streetId).notifier)
                          .delete(customer.id);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'order',
                        child: ListTile(
                          leading: Icon(Icons.add_shopping_cart_rounded),
                          title: Text('Create Order'),
                          contentPadding: EdgeInsets.zero,
                        )),
                    const PopupMenuItem(
                        value: 'ledger',
                        child: ListTile(
                          leading: Icon(Icons.account_balance_wallet_rounded),
                          title: Text('Instant Ledger'),
                          contentPadding: EdgeInsets.zero,
                        )),
                    const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_rounded),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                        )),
                    const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded,
                              color: Colors.red),
                          title: Text('Delete',
                              style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagBadge(String tag) {
    Color color;
    Color bg;
    switch (tag) {
      case 'VIP':
        color = Colors.purple;
        bg = Colors.purple.withOpacity(0.12);
        break;
      case 'Expired':
        color = Colors.red;
        bg = Colors.red.withOpacity(0.12);
        break;
      case 'Loyal':
        color = Colors.blue;
        bg = Colors.blue.withOpacity(0.12);
        break;
      case 'New':
        color = Colors.green;
        bg = Colors.green.withOpacity(0.12);
        break;
      case 'Inactive':
        color = Colors.grey;
        bg = Colors.grey.withOpacity(0.15);
        break;
      default:
        color = AppColors.primary;
        bg = AppColors.primary.withOpacity(0.12);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
