import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/scale_on_tap.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/vip_glow_avatar.dart';
import '../domain/customer.dart';
import 'customer_provider.dart';
import 'widgets/instant_ledger_sheet.dart';
import '../../area/presentation/area_provider.dart';
import '../../../core/services/customer_order_sync_service.dart';

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
  bool _isSelectionMode = false;
  final Set<String> _selectedCustomerIds = {};
  bool _isSyncing = false;

  void _toggleSelection(String customerId) {
    setState(() {
      if (_selectedCustomerIds.contains(customerId)) {
        _selectedCustomerIds.remove(customerId);
        if (_selectedCustomerIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedCustomerIds.add(customerId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedCustomerIds.clear();
    });
  }

  void _selectAll(List<Customer> customers) {
    setState(() {
      if (_selectedCustomerIds.length == customers.length) {
        _selectedCustomerIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedCustomerIds.addAll(customers.map((c) => c.id));
      }
    });
  }

  Future<void> _showMoveDialog(
      BuildContext context, List<String> customerIds) async {
    String? selectedAreaId;
    String? selectedStreetId;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return Consumer(
              builder: (context, ref, child) {
                final areasAsync = ref.watch(areaProvider);

                return AlertDialog(
                  title: Text('Move ${customerIds.length} Customers'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      areasAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Text('Error loading areas: $err'),
                        data: (areas) {
                          return DropdownButtonFormField<String>(
                            decoration:
                                const InputDecoration(labelText: 'Select Area'),
                            value: selectedAreaId,
                            items: areas.map((a) {
                              return DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              );
                            }).toList(),
                            onChanged: (areaId) {
                              setStateDialog(() {
                                selectedAreaId = areaId;
                                selectedStreetId = null; // reset street
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      if (selectedAreaId != null)
                        ref
                            .watch(areaDescendantLocationsProvider(
                                selectedAreaId!))
                            .when(
                              loading: () => const Center(
                                  child: CircularProgressIndicator()),
                              error: (err, _) =>
                                  Text('Error loading locations: $err'),
                              data: (locations) {
                                final locationMap = {
                                  for (final l in locations) l.id: l
                                };
                                return DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                      labelText: 'Select Street/Road'),
                                  value: selectedStreetId,
                                  isExpanded: true,
                                  items: locations.map((s) {
                                    final parts = s.materializedPath
                                        .split('/')
                                        .where((p) => p.isNotEmpty)
                                        .toList();
                                    final names = parts
                                        .skip(1)
                                        .map(
                                            (id) => locationMap[id]?.name ?? id)
                                        .toList();
                                    final pathDisplay = names.isEmpty
                                        ? s.name
                                        : names.join(' ➜ ');
                                    return DropdownMenuItem(
                                      value: s.id,
                                      child: Text(
                                        pathDisplay,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (streetId) {
                                    setStateDialog(() {
                                      selectedStreetId = streetId;
                                    });
                                  },
                                );
                              },
                            ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: selectedStreetId == null
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              final effectiveStreetId = widget.streetId ?? '';
                              await ref
                                  .read(customerListProvider(effectiveStreetId)
                                      .notifier)
                                  .moveCustomers(
                                      customerIds, selectedStreetId!);
                              if (context.mounted) {
                                _exitSelectionMode();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Customers moved successfully')),
                                );
                              }
                            },
                      child: const Text('Move'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStreetId = widget.streetId ?? '';
    final customersAsync = ref.watch(customerListProvider(effectiveStreetId));

    return customersAsync.when(
      loading: () => AppScaffold(
        title: widget.streetName ?? 'All Customers',
        body: const LoadingShimmer(),
      ),
      error: (e, _) => AppScaffold(
        title: widget.streetName ?? 'All Customers',
        body: Center(child: Text('Error: $e')),
      ),
      data: (customers) {
        return AppScaffold(
          title: _isSelectionMode
              ? '${_selectedCustomerIds.length} Selected'
              : (widget.streetName ?? 'All Customers'),
          actions: _isSelectionMode
              ? [
                  IconButton(
                    icon: const Icon(Icons.select_all_rounded),
                    onPressed: () => _selectAll(customers),
                    tooltip: 'Select All',
                  ),
                  IconButton(
                    icon: const Icon(Icons.drive_file_move_rounded),
                    onPressed: _selectedCustomerIds.isEmpty
                        ? null
                        : () => _showMoveDialog(
                            context, _selectedCustomerIds.toList()),
                    tooltip: 'Move Customers',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _exitSelectionMode,
                    tooltip: 'Cancel',
                  ),
                ]
              : [
                  IconButton(
                    icon: const Icon(Icons.swap_horiz_rounded),
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = true;
                      });
                    },
                    tooltip: 'Bulk Move',
                  ),
                  IconButton(
                    icon: const Icon(Icons.sync_rounded),
                    onPressed: _isSyncing
                        ? null
                        : () async {
                            setState(() {
                              _isSyncing = true;
                            });
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const PopScope(
                                canPop: false,
                                child: AlertDialog(
                                  content: Row(
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(width: 20),
                                      Expanded(
                                          child: Text(
                                              'Syncing areas, customers & inventory... Please wait.')),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            try {
                              final stats = await CustomerOrderSyncService.instance
                                  .syncAll(forceSync: true);
                              if (context.mounted) {
                                Navigator.pop(context); // close loader
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Full Sync Results'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('📍 Routes',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          Text(
                                              '  Areas synced: ${stats['areasUploaded']}'),
                                          Text(
                                              '  Roads synced: ${stats['roadsUploaded']}'),
                                          if ((stats['subRoadsUploaded'] ?? 0) > 0)
                                            Text(
                                                '  Sub-roads synced: ${stats['subRoadsUploaded']}'),
                                          if ((stats['areasFailed'] ?? 0) > 0 ||
                                              (stats['roadsFailed'] ?? 0) > 0 ||
                                              (stats['subRoadsFailed'] ?? 0) > 0)
                                            Text(
                                                '  Failed: ${stats['areasFailed']} areas, ${stats['roadsFailed']} roads, ${stats['subRoadsFailed']} sub-roads',
                                                style: const TextStyle(
                                                    color: Colors.red)),
                                          const SizedBox(height: 12),
                                          const Text('👥 Customers',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          Text('  Total local: ${stats['total']}'),
                                          Text('  Real customers: ${stats['real']}'),
                                          Text(
                                              '  Ghost houses skipped: ${stats['ghost']}'),
                                          Text('  Uploaded: ${stats['uploaded']}'),
                                          Text('  Updated: ${stats['updated']}'),
                                          if ((stats['failed'] ?? 0) > 0)
                                            Text('  Failed: ${stats['failed']}',
                                                style: const TextStyle(
                                                    color: Colors.red)),
                                          const SizedBox(height: 12),
                                          const Text('📦 Inventory',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          Text(
                                              '  Categories: ${stats['categoriesSynced']}'),
                                          Text(
                                              '  Products synced: ${stats['productsUploaded']}'),
                                          if ((stats['productsFailed'] ?? 0) > 0)
                                            Text(
                                                '  Failed: ${stats['productsFailed']}',
                                                style: const TextStyle(
                                                    color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                ).then((_) {
                                  if (mounted) {
                                    setState(() {
                                      _isSyncing = false;
                                    });
                                    ref.invalidate(customerListProvider(effectiveStreetId));
                                  }
                                });
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.pop(context); // close loader
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Sync Failed'),
                                    content: Text('Error: $e'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                ).then((_) {
                                  if (mounted) {
                                    setState(() {
                                      _isSyncing = false;
                                    });
                                  }
                                });
                              }
                            }
                          },
                    tooltip: 'Sync All Data',
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.search),
                  ),
                ],
          floatingActionButton: widget.streetId != null && !_isSelectionMode
              ? FloatingActionButton(
                  heroTag: 'add_customer',
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRoutes.addEditCustomer,
                    arguments: {'streetId': widget.streetId},
                  ).then((_) =>
                      ref.refresh(customerListProvider(effectiveStreetId))),
                  child: const Icon(Icons.person_add_rounded),
                )
              : null,
          body: Column(
            children: [
              CustomSearchBar(
                hint: 'Search customers, phone, house no...',
                onChanged: (q) => ref
                    .read(customerListProvider(effectiveStreetId).notifier)
                    .search(q),
              ),
              Expanded(
                child: customers.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.people_outline_rounded,
                        title: 'No Customers Found',
                        subtitle: 'Try changing search filter',
                        actionLabel: 'Add Customer',
                        onAction: () {
                          if (widget.streetId != null) {
                            Navigator.of(context).pushNamed(
                              AppRoutes.addEditCustomer,
                              arguments: {'streetId': widget.streetId},
                            ).then((_) => ref.refresh(
                                customerListProvider(effectiveStreetId)));
                          }
                        },
                      )
                    : (_isSelectionMode
                        ? ListView.builder(
                            padding: const EdgeInsets.only(bottom: 96),
                            itemCount: customers.length,
                            itemBuilder: (ctx, i) => _CustomerCard(
                              key: ValueKey(customers[i].id),
                              customer: customers[i],
                              streetId: effectiveStreetId,
                              isSelectionMode: true,
                              isSelected: _selectedCustomerIds
                                  .contains(customers[i].id),
                              onTap: () => _toggleSelection(customers[i].id),
                              onLongPress: () {},
                              index: i,
                            ),
                          )
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.only(bottom: 96),
                            itemCount: customers.length,
                            buildDefaultDragHandles: false,
                            onReorder: (oldIndex, newIndex) {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              ref
                                  .read(customerListProvider(effectiveStreetId)
                                      .notifier)
                                  .reorder(oldIndex, newIndex);
                            },
                            itemBuilder: (ctx, i) => KeyedSubtree(
                              key: ValueKey(customers[i].id),
                              child: _CustomerCard(
                                customer: customers[i],
                                streetId: effectiveStreetId,
                                isSelectionMode: false,
                                isSelected: false,
                                onTap: () => Navigator.of(context).pushNamed(
                                    AppRoutes.customerProfile,
                                    arguments: {
                                      'customerId': customers[i].id
                                    }).then((_) => ref.refresh(
                                    customerListProvider(effectiveStreetId))),
                                onLongPress: () {
                                  setState(() {
                                    _isSelectionMode = true;
                                    _selectedCustomerIds.add(customers[i].id);
                                  });
                                },
                                index: i,
                              ),
                            ),
                          )),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CustomerCard extends ConsumerWidget {
  final Customer customer;
  final String streetId;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int index;

  const _CustomerCard({
    super.key,
    required this.customer,
    required this.streetId,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final creditColor = isDark ? const Color(0xFF2DD4BF) : Colors.teal;

    Widget cardChild;

    // ── Ghost House tile — special visual ────────────────────────────────────
    if (customer.isGhostHouse) {
      final VoidCallback ghostTap = isSelectionMode
          ? onTap
          : () {
              Navigator.of(context).pushNamed(
                AppRoutes.addEditCustomer,
                arguments: {'streetId': streetId, 'customerId': customer.id},
              ).then((_) => ref.refresh(customerListProvider(streetId)));
            };

      cardChild = ScaleOnTap(
        onTap: ghostTap,
        onLongPress: onLongPress,
        child: Container(
          key: key,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.orange.withOpacity(0.06)
                : Colors.orange.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.orange.withOpacity(0.45),
              width: 1.4,
              style: BorderStyle.solid,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (isSelectionMode) ...[
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? AppColors.primary : AppColors.gray400,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.drag_indicator_rounded,
                          color: AppColors.gray400, size: 22),
                    ),
                  ),
                ],
                // Ghost icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.withOpacity(0.12),
                    border: Border.all(
                        color: Colors.orange.withOpacity(0.4), width: 1.5),
                  ),
                  child: const Icon(Icons.home_work_outlined,
                      color: Colors.orange, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (customer.serialNo > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${customer.serialNo}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            'Blank House',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: Colors.orange.withOpacity(0.85),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to fill customer details',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textHint,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                      if (customer.houseNumber.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'House No: ${customer.houseNumber}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Three-dot menu for ghost houses — Edit & Delete only
                if (!isSelectionMode)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: AppColors.gray500),
                    onSelected: (v) async {
                      if (v == 'edit') {
                        Navigator.of(context).pushNamed(
                          AppRoutes.addEditCustomer,
                          arguments: {
                            'streetId': streetId,
                            'customerId': customer.id
                          },
                        ).then(
                            (_) => ref.refresh(customerListProvider(streetId)));
                      } else if (v == 'delete') {
                        final ok = await ConfirmDeleteDialog.show(
                          context,
                          title: 'Delete Ghost House',
                          message:
                              'Remove this blank house slot #${customer.serialNo}?',
                        );
                        if (!ok) return;
                        await ref
                            .read(customerListProvider(streetId).notifier)
                            .delete(customer.id);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_rounded),
                          title: Text('Fill Details / Edit'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded,
                              color: Colors.red),
                          title: Text('Delete',
                              style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    } else {
      cardChild = GlassContainer(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: ScaleOnTap(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  child: Row(
                    children: [
                      if (isSelectionMode) ...[
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.gray400,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                      ] else ...[
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(Icons.drag_indicator_rounded,
                                color: AppColors.gray400, size: 22),
                          ),
                        ),
                      ],
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
                                      color:
                                          AppColors.primary.withOpacity(0.12),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800),
                                        softWrap: true,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (customer.isVipActive)
                                            VipGoldBadgeChip(
                                                planName: customer.vipPlan)
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
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'DUE',
                                          style: TextStyle(
                                            color: AppColors.error,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          AppFormatters.currency(
                                              customer.outstandingBalance),
                                          style: const TextStyle(
                                            color: AppColors.error,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (customer.outstandingBalance < 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: creditColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'ADVANCE',
                                          style: TextStyle(
                                            color: creditColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          AppFormatters.currency(customer
                                              .outstandingBalance
                                              .abs()),
                                          style: TextStyle(
                                            color: creditColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  'Phone: ${customer.phone1}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.bold),
                                ),
                                if (customer.customerCode.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Code: ${customer.customerCode}',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '📦 Last Order: ${customer.lastOrderDate.isNotEmpty ? customer.lastOrderDate : 'Today 4:15 PM'}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            ref
                                .watch(
                                    customerLocationProvider(customer.streetId))
                                .when(
                                  data: (loc) {
                                    final streetName = loc['street'] ?? '';
                                    final areaName = loc['area'] ?? '';
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (customer.houseNumber.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 2),
                                            child: Text(
                                              'House No: ${customer.houseNumber}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                      color: AppColors
                                                          .textSecondary,
                                                      fontWeight:
                                                          FontWeight.w600),
                                            ),
                                          ),
                                        if (customer.address.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 2),
                                            child: Text(
                                              'Address: ${customer.address}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                      color:
                                                          AppColors.textHint),
                                              softWrap: true,
                                            ),
                                          ),
                                        if (streetName.isNotEmpty ||
                                            areaName.isNotEmpty)
                                          Text(
                                            'Route: $streetName • Area: $areaName',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10),
                                          ),
                                      ],
                                    );
                                  },
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, __) => const SizedBox.shrink(),
                                ),
                            // ── Multi-Family Household Badge ─────────────
                            ref
                                .watch(sameHouseCustomersProvider((
                                  houseNumber: customer.houseNumber,
                                  streetId: customer.streetId,
                                  customerId: customer.id,
                                )))
                                .when(
                                  data: (families) {
                                    if (families.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.indigo.withOpacity(0.3),
                                            width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.family_restroom_rounded,
                                              size: 13, color: Colors.indigo),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'Shared Household (${families.length + 1} Families: ${customer.name}, ${families.map((f) => f.name).join(", ")})',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.indigo,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
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
                ),
              ),
              // Three-dot menu
              if (!isSelectionMode)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.gray500),
                  onSelected: (v) async {
                    if (v == 'select') {
                      onLongPress();
                    } else if (v == 'order') {
                      Navigator.of(context).pushNamed(
                        AppRoutes.createOrder,
                        arguments: {
                          'customerId': customer.id,
                          'customerName': customer.name,
                          'orderId': null,
                        },
                      ).then(
                          (_) => ref.refresh(customerListProvider(streetId)));
                    } else if (v == 'add_family') {
                      Navigator.of(context).pushNamed(
                        AppRoutes.addEditCustomer,
                        arguments: {
                          'streetId': customer.streetId,
                          'initialHouseNumber': customer.houseNumber,
                          'initialAddress': customer.address,
                          'initialMapsLocation': customer.mapsLocation,
                        },
                      ).then(
                          (_) => ref.refresh(customerListProvider(streetId)));
                    } else if (v == 'edit') {
                      Navigator.of(context).pushNamed(
                        AppRoutes.addEditCustomer,
                        arguments: {
                          'streetId': streetId,
                          'customerId': customer.id,
                        },
                      ).then(
                          (_) => ref.refresh(customerListProvider(streetId)));
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
                        value: 'select',
                        child: ListTile(
                          leading: Icon(Icons.check_box_outlined),
                          title: Text('Select to Move'),
                          contentPadding: EdgeInsets.zero,
                        )),
                    const PopupMenuItem(
                        value: 'order',
                        child: ListTile(
                          leading: Icon(Icons.add_shopping_cart_rounded),
                          title: Text('Create Order'),
                          contentPadding: EdgeInsets.zero,
                        )),
                    const PopupMenuItem(
                        value: 'add_family',
                        child: ListTile(
                          leading: Icon(Icons.home_work_rounded,
                              color: Colors.blue),
                          title: Text('Add Family to Same House'),
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
      );
    }

    return RepaintBoundary(child: cardChild);
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
