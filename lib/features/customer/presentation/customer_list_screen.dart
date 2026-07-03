import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/customer_avatar.dart';
import '../domain/customer.dart';
import 'customer_provider.dart';

class CustomerListScreen extends ConsumerWidget {
  final String? streetId;
  final String? streetName;

  const CustomerListScreen({
    super.key,
    this.streetId,
    this.streetName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveStreetId = streetId ?? '';
    final customersAsync = ref.watch(customerListProvider(effectiveStreetId));

    return AppScaffold(
      title: streetName ?? 'All Customers',
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.search),
        ),
      ],
      floatingActionButton: streetId != null 
        ? FloatingActionButton(
            heroTag: 'add_customer',
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.addEditCustomer,
              arguments: {'streetId': streetId},
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
              data: (customers) => customers.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.people_outline_rounded,
                      title: 'No Customers Yet',
                      subtitle: 'Add your first customer in this street',
                      actionLabel: 'Add Customer',
                      onAction: () {
                        if (streetId != null) {
                          Navigator.of(context)
                            .pushNamed(
                              AppRoutes.addEditCustomer,
                              arguments: {'streetId': streetId},
                            )
                            .then((_) =>
                                ref.refresh(customerListProvider(effectiveStreetId)));
                        }
                      },
                    )
                  : ReorderableListView.builder(
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
                          ref: ref,
                        )
                            .animate(delay: (i * 40).ms)
                            .fadeIn()
                            .slideX(begin: 0.05),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final String streetId;
  final WidgetRef ref;

  const _CustomerCard({
    super.key,
    required this.customer,
    required this.streetId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
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
                CustomerAvatar(
                  photoPath: customer.photoPath,
                  radius: 26,
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                            child: Text(
                              customer.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (customer.outstandingBalance > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.errorSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                AppFormatters.currency(
                                    customer.outstandingBalance),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.phone1,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      if (customer.houseNumber.isNotEmpty ||
                          customer.address.isNotEmpty)
                        Text(
                          [
                            if (customer.houseNumber.isNotEmpty)
                              customer.houseNumber,
                            if (customer.address.isNotEmpty)
                              customer.address,
                          ].join(', '),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textHint),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
}
