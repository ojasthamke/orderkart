import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
import '../../../core/widgets/vip_glow_avatar.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/security/app_mode_service.dart';
import '../../customer/domain/customer.dart';
import '../../customer/presentation/customer_provider.dart';
import '../../customer/presentation/widgets/instant_ledger_sheet.dart';
import '../../worker/presentation/worker_provider.dart';
import '../domain/location.dart';
import '../domain/location_kind.dart';
import 'location_provider.dart';

class LocationDetailScreen extends ConsumerStatefulWidget {
  final String locationId;
  final String locationName;

  const LocationDetailScreen({
    super.key,
    required this.locationId,
    required this.locationName,
  });

  @override
  ConsumerState<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends ConsumerState<LocationDetailScreen> with SingleTickerProviderStateMixin {
  String _filterMode = 'all'; // 'all', 'owner', or workerId
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breadcrumbsAsync = ref.watch(breadcrumbsProvider(widget.locationId));
    final childLocationsAsync = ref.watch(locationListProvider(widget.locationId));
    final customersAsync = ref.watch(customerListProvider(widget.locationId));
    
    final workersAsync = ref.watch(activeWorkersListProvider);
    final modeAsync = ref.watch(appModeProvider);
    final isWorker = modeAsync.valueOrNull == AppMode.worker;

    return AppScaffold(
      title: widget.locationName,
      drawer: const AppDrawer(),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.search),
        ),
      ],
      body: Column(
        children: [
          // Breadcrumbs Path Row
          breadcrumbsAsync.when(
            loading: () => const SizedBox(height: 48),
            error: (_, __) => const SizedBox.shrink(),
            data: (breadcrumbs) {
              if (breadcrumbs.isEmpty) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).cardTheme.color,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(breadcrumbs.length, (idx) {
                      final node = breadcrumbs[idx];
                      final isLast = idx == breadcrumbs.length - 1;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: isLast
                                ? null
                                : () {
                                    // Pop back to this breadcrumb parent
                                    final popsCount = (breadcrumbs.length - 1) - idx;
                                    for (int i = 0; i < popsCount; i++) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                            child: Text(
                              node.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                                color: isLast ? AppColors.textPrimary : AppColors.primary,
                              ),
                            ),
                          ),
                          if (!isLast)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.gray400),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              );
            },
          ),
          
          // Tab bar to switch between Sub-locations and Customers
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Sub-Roads / Sectors'),
              Tab(text: 'Customers Here'),
            ],
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Sub-Locations List
                Column(
                  children: [
                    CustomSearchBar(
                      hint: 'Search sub-locations...',
                      onChanged: (q) => ref.read(locationListProvider(widget.locationId).notifier).search(q),
                    ),
                    Expanded(
                      child: childLocationsAsync.when(
                        loading: () => const LoadingShimmer(),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (rawLocs) {
                          var locs = rawLocs;
                          if (locs.isEmpty) {
                            return EmptyStateWidget(
                              icon: Icons.holiday_village_rounded,
                              title: 'No Sub-locations',
                              subtitle: 'Add societies, gallis, buildings, or lanes inside this location.',
                              actionLabel: 'Add Sub-location',
                              onAction: () => _showAddEditLocationDialog(context, null),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 96),
                            itemCount: locs.length,
                            itemBuilder: (ctx, i) {
                              final loc = locs[i];
                              return _LocationTile(
                                location: loc,
                                onTap: () {
                                  // Navigate recursively deeper using streets route argument mapping
                                  Navigator.of(context).pushNamed(
                                    AppRoutes.streets,
                                    arguments: {
                                      'areaId': loc.id,
                                      'areaName': loc.name,
                                    },
                                  ).then((_) {
                                    ref.invalidate(locationListProvider(widget.locationId));
                                    ref.invalidate(breadcrumbsProvider(widget.locationId));
                                  });
                                },
                                onEdit: () => _showAddEditLocationDialog(context, loc),
                                onDelete: () => _confirmDeleteLocation(context, loc),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // Tab 2: Customers List registered directly at this Location
                Column(
                  children: [
                    CustomSearchBar(
                      hint: 'Search customers...',
                      onChanged: (q) => ref.read(customerListProvider(widget.locationId).notifier).search(q),
                    ),
                    Expanded(
                      child: customersAsync.when(
                        loading: () => const LoadingShimmer(),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (rawCustomers) {
                          if (rawCustomers.isEmpty) {
                            return EmptyStateWidget(
                              icon: Icons.people_outline_rounded,
                              title: 'No Customers Here',
                              subtitle: 'No customers are registered at this specific road/location.',
                              actionLabel: 'Add Customer',
                              onAction: () {
                                Navigator.of(context).pushNamed(
                                  AppRoutes.addEditCustomer,
                                  arguments: {'streetId': widget.locationId},
                                ).then((_) => ref.refresh(customerListProvider(widget.locationId)));
                              },
                            );
                          }

                          return ReorderableListView.builder(
                            padding: const EdgeInsets.only(bottom: 96),
                            itemCount: rawCustomers.length,
                            onReorder: (oldIndex, newIndex) {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              ref.read(customerListProvider(widget.locationId).notifier).reorder(oldIndex, newIndex);
                            },
                            itemBuilder: (ctx, i) {
                              final cust = rawCustomers[i];
                              return KeyedSubtree(
                                key: ValueKey(cust.id),
                                child: _CustomerTile(
                                  customer: cust,
                                  index: i,
                                  currency: '₹',
                                  onTap: () {
                                    Navigator.of(context).pushNamed(
                                      AppRoutes.customerProfile,
                                      arguments: {'customerId': cust.id},
                                    ).then((_) => ref.refresh(customerListProvider(widget.locationId)));
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'add_customer_fab',
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRoutes.addEditCustomer,
                arguments: {'streetId': widget.locationId},
              ).then((_) => ref.refresh(customerListProvider(widget.locationId)));
            },
            tooltip: 'Add Customer',
            child: const Icon(Icons.person_add_rounded),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add_sub_location_fab',
            onPressed: () => _showAddEditLocationDialog(context, null),
            tooltip: 'Add Sub-location',
            child: const Icon(Icons.add_location_alt_rounded),
          ),
        ],
      ),
    );
  }

  void _showAddEditLocationDialog(BuildContext context, Location? location) {
    final nameCon = TextEditingController(text: location?.name ?? '');
    final descCon = TextEditingController(text: location?.description ?? '');
    final mapsCon = TextEditingController(text: location?.mapsLocation ?? '');
    String photoPath = location?.photoPath ?? '';
    LocationKind selectedKind = location?.locationKind ?? LocationKind.road;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          title: Text(location == null ? 'Add Sub-location' : 'Edit Sub-location'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Photo Picker
                  GestureDetector(
                    onTap: () async {
                      final source = await showModalBottomSheet<ImageSource>(
                        context: dlgCtx,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.camera_alt_rounded),
                                title: const Text('Take a Photo'),
                                onTap: () => Navigator.pop(ctx, ImageSource.camera),
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library_rounded),
                                title: const Text('Choose from Gallery'),
                                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (source != null) {
                        final file = await ImageUtils.pickAndCompress(source: source);
                        if (file != null) {
                          setDlgState(() => photoPath = file.path);
                        }
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.gray300),
                        image: (photoPath.isNotEmpty && File(photoPath).existsSync())
                            ? DecorationImage(image: FileImage(File(photoPath)), fit: BoxFit.cover)
                            : null,
                      ),
                      child: (photoPath.isEmpty || !File(photoPath).existsSync())
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_rounded, color: AppColors.gray500, size: 24),
                                SizedBox(height: 2),
                                Text('Photo', style: TextStyle(fontSize: 10, color: AppColors.gray600)),
                              ],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Kind dropdown selection
                  DropdownButtonFormField<LocationKind>(
                    value: selectedKind,
                    decoration: const InputDecoration(
                      labelText: 'Location Type',
                      prefixIcon: Icon(Icons.layers_rounded),
                    ),
                    items: LocationKind.values
                        .where((k) => k != LocationKind.area) // root locations are Area, sub-locations are Road/Galli/etc.
                        .map((k) => DropdownMenuItem(value: k, child: Text(k.value)))
                        .toList(),
                    onChanged: (k) {
                      if (k != null) {
                        setDlgState(() => selectedKind = k);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: nameCon,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      prefixIcon: Icon(Icons.location_on_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCon,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: mapsCon,
                    decoration: const InputDecoration(
                      labelText: 'Location / Maps Link',
                      prefixIcon: Icon(Icons.location_on_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dlgCtx).pop();

                final notifier = ref.read(locationListProvider(widget.locationId).notifier);
                final now = DateTime.now();
                final locId = location?.id ?? const Uuid().v4();

                String finalPhotoPath = photoPath;
                if (photoPath.isNotEmpty && !photoPath.startsWith('/data/user/')) {
                  final savedPath = await ImageUtils.saveImagePermanently(
                    sourcePath: photoPath,
                    subFolder: 'location_photos',
                    fileName: locId,
                  );
                  if (savedPath != null) {
                    finalPhotoPath = savedPath;
                  }
                }

                if (location == null) {
                  await notifier.add(Location(
                    id: locId,
                    parentLocationId: widget.locationId,
                    name: nameCon.text.trim(),
                    description: descCon.text.trim(),
                    locationKind: selectedKind,
                    sequenceKey: '', // automatically generated by notifier
                    photoPath: finalPhotoPath,
                    mapsLocation: mapsCon.text.trim(),
                    createdAt: now,
                    updatedAt: now,
                  ));
                  if (mounted) {
                    SnackbarHelper.showSuccess(context, '${selectedKind.value} added');
                  }
                } else {
                  await notifier.updateLocation(location.copyWith(
                    name: nameCon.text.trim(),
                    description: descCon.text.trim(),
                    locationKind: selectedKind,
                    photoPath: finalPhotoPath,
                    mapsLocation: mapsCon.text.trim(),
                    updatedAt: now,
                  ));
                  if (mounted) {
                    SnackbarHelper.showSuccess(context, '${selectedKind.value} updated');
                  }
                }
              },
              child: Text(location == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteLocation(BuildContext context, Location location) async {
    final ok = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete ${location.locationKind.value}',
      message: 'Delete "${location.name}"? All nested child sub-locations and customers inside will also be deleted.',
    );
    if (!ok || !mounted) return;
    await ref.read(locationListProvider(widget.locationId).notifier).delete(location.id);
    if (!mounted) return;
    SnackbarHelper.showSuccess(context, '"${location.name}" deleted');
  }
}

class _LocationTile extends StatelessWidget {
  final Location location;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LocationTile({
    required this.location,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppColors.cardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo/Icon indicator
              GestureDetector(
                onTap: () {
                  if (location.photoPath.isNotEmpty && File(location.photoPath).existsSync()) {
                    FullScreenImageViewer.show(context, location.photoPath, title: location.name);
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                    image: (location.photoPath.isNotEmpty && File(location.photoPath).existsSync())
                        ? DecorationImage(image: FileImage(File(location.photoPath)), fit: BoxFit.cover)
                        : null,
                  ),
                  child: (location.photoPath.isEmpty || !File(location.photoPath).existsSync())
                      ? Icon(location.locationKind.icon, color: AppColors.primary, size: 24)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (location.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        location.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            location.locationKind.value,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ),
                        if (location.childCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${location.childCount} sub-roads',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green),
                            ),
                          ),
                        if (location.customerCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${location.customerCount} customers',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue),
                            ),
                          ),
                        if (location.mapsLocation.isNotEmpty)
                          InkWell(
                            onTap: () async {
                              final loc = location.mapsLocation.trim();
                              Uri uri;
                              if (loc.startsWith('http://') || loc.startsWith('https://')) {
                                uri = Uri.parse(loc);
                              } else {
                                uri = Uri.parse('https://maps.google.com/?q=${Uri.encodeComponent(loc)}');
                              }
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_rounded, size: 12, color: Colors.deepOrange),
                                  SizedBox(width: 4),
                                  Text('📍 Location', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.deepOrange)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.gray500),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerTile extends ConsumerWidget {
  final Customer customer;
  final int index;
  final String currency;
  final VoidCallback onTap;

  const _CustomerTile({
    required this.customer,
    required this.index,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppColors.cardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.drag_indicator_rounded, color: AppColors.gray400),
                ),
              ),
              
              VipGlowAvatar(
                isVip: customer.isVipActive,
                photoPath: customer.photoPath,
                radius: 22,
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (customer.serialNo > 0)
                          Text(
                            customer.serialLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Phone: ${customer.phone1}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                    if (customer.houseNumber.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'House: ${customer.houseNumber}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormatters.currency(customer.outstandingBalance, symbol: currency),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: customer.outstandingBalance > 0
                          ? AppColors.error
                          : (customer.outstandingBalance < 0 ? AppColors.success : AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppColors.primary),
                        onPressed: () {
                          InstantLedgerSheet.show(
                            context,
                            customer,
                          ).then((_) {
                            ref.invalidate(customerListProvider(customer.streetId));
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
