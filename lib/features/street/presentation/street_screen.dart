import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/constants/app_colors.dart';
import '../domain/street.dart';
import 'street_provider.dart';
import '../../../core/widgets/ownership_badge.dart';
import '../../../core/database/database_helper.dart';

final activeWorkersListProvider = FutureProvider<List<Map<String, String>>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.query('workers', columns: ['id', 'name'], orderBy: 'name ASC');
  return rows.map((r) => {
    'id': r['id']?.toString() ?? '',
    'name': r['name']?.toString() ?? '',
  }).toList();
});

class StreetScreen extends ConsumerStatefulWidget {
  final String areaId;
  final String areaName;

  const StreetScreen({super.key, required this.areaId, required this.areaName});

  @override
  ConsumerState<StreetScreen> createState() => _StreetScreenState();
}

class _StreetScreenState extends ConsumerState<StreetScreen> {
  String _filterMode = 'all'; // 'all', 'owner', or workerId

  @override
  Widget build(BuildContext context) {
    final streetsAsync = ref.watch(streetProviderFamily(widget.areaId));
    final workersAsync = ref.watch(activeWorkersListProvider);

    return AppScaffold(
      title: widget.areaName,
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_street',
        onPressed: () => _showAddEdit(context, null),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          CustomSearchBar(
            hint: 'Search streets...',
            onChanged: (q) =>
                ref.read(streetProviderFamily(widget.areaId).notifier).search(q),
          ),

          // Dynamic Material 3 Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  selected: _filterMode == 'all',
                  label: const Text('All'),
                  avatar: const Icon(Icons.apps_rounded, size: 16),
                  selectedColor: AppColors.primarySurface,
                  onSelected: (_) => setState(() => _filterMode = 'all'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _filterMode == 'owner',
                  label: const Text('🟢 Owner'),
                  selectedColor: AppColors.success.withOpacity(0.18),
                  onSelected: (_) => setState(() => _filterMode = 'owner'),
                ),
                const SizedBox(width: 8),
                ...workersAsync.when(
                  data: (workers) => workers.map((w) {
                    final wId = w['id']!;
                    final wName = w['name']!;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: _filterMode == wId,
                        label: Text('🔵 $wName'),
                        selectedColor: AppColors.primarySurface,
                        onSelected: (_) => setState(() => _filterMode = wId),
                      ),
                    );
                  }).toList(),
                  loading: () => [],
                  error: (_, __) => [],
                ),
              ],
            ),
          ),

          Expanded(
            child: streetsAsync.when(
              loading: () => const LoadingShimmer(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (rawStreets) {
                var streets = rawStreets;
                if (_filterMode == 'owner') {
                  streets = rawStreets.where((s) => s.createdBy.toLowerCase() == 'owner' || (s.createdBy.isEmpty && s.assignedWorkerId.isEmpty)).toList();
                } else if (_filterMode != 'all') {
                  streets = rawStreets.where((s) => s.assignedWorkerId == _filterMode || s.createdBy == _filterMode || s.workerName.toLowerCase() == _filterMode.toLowerCase()).toList();
                }

                if (streets.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.turn_slight_right_rounded,
                    title: 'No Streets Found',
                    subtitle: _filterMode == 'all' ? 'Add streets to organise your customers' : 'No streets match the selected filter',
                    actionLabel: 'Add Street',
                    onAction: () => _showAddEdit(context, null),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: streets.length,
                  itemBuilder: (ctx, i) {
                    final st = streets[i];
                    return _StreetTile(
                      street: st,
                      onTap: () => Navigator.of(context).pushNamed(
                        AppRoutes.customers,
                        arguments: {
                          'streetId':   st.id,
                          'streetName': st.name,
                        },
                      ),
                      onEdit:   () => _showAddEdit(context, st),
                      onDelete: () => _confirmDelete(context, st),
                    ).animate(delay: (i * 40).ms).fadeIn().slideX(begin: 0.1);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEdit(BuildContext context, Street? street) {
    final nameCon     = TextEditingController(text: street?.name ?? '');
    final descCon     = TextEditingController(text: street?.description ?? '');
    final locationCon = TextEditingController(text: street?.mapsLocation ?? '');
    String photoPath  = street?.photoPath ?? '';
    final formKey     = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          title: Text(street == null ? 'Add Street' : 'Edit Street'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Photo Picker
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
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
                        final file = await picker.pickImage(source: source, imageQuality: 85);
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
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.add_a_photo_rounded, color: AppColors.gray500, size: 24),
                                SizedBox(height: 2),
                                Text('Photo', style: TextStyle(fontSize: 10, color: AppColors.gray600)),
                              ],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: nameCon,
                    decoration: const InputDecoration(
                      labelText: 'Street Name *',
                      prefixIcon: Icon(Icons.turn_slight_right_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Street name is required';
                      return null;
                    },
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCon,
                    decoration: const InputDecoration(
                      labelText: 'Description (Full visibility enabled)',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: locationCon,
                    decoration: const InputDecoration(
                      labelText: 'Street Location / Maps Link',
                      hintText: 'e.g. Near Market or maps link',
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
                Navigator.of(context).pop();
                final notifier =
                    ref.read(streetProviderFamily(widget.areaId).notifier);
                final now = DateTime.now();
                if (street == null) {
                  await notifier.add(Street(
                    id:           const Uuid().v4(),
                    areaId:       widget.areaId,
                    name:         nameCon.text.trim(),
                    description:  descCon.text.trim(),
                    photoPath:    photoPath,
                    mapsLocation: locationCon.text.trim(),
                    createdAt:    now,
                  ));
                  if (mounted)
                    SnackbarHelper.showSuccess(context, 'Street added');
                } else {
                  await notifier.update(street.copyWith(
                    name:         nameCon.text.trim(),
                    description:  descCon.text.trim(),
                    photoPath:    photoPath,
                    mapsLocation: locationCon.text.trim(),
                  ));
                  if (mounted)
                    SnackbarHelper.showSuccess(context, 'Street updated');
                }
              },
              child: Text(street == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Street street) async {
    final ok = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete Street',
      message: 'Delete "${street.name}"? All customers inside will also be deleted.',
    );
    if (!ok || !mounted) return;
    await ref.read(streetProviderFamily(widget.areaId).notifier).delete(street.id);
    if (!mounted) return;
    SnackbarHelper.showSuccess(context, '"${street.name}" deleted');
  }
}

class _StreetTile extends StatelessWidget {
  final Street street;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StreetTile({
    required this.street,
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
              // Photo or Icon Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                  image: (street.photoPath.isNotEmpty && File(street.photoPath).existsSync())
                      ? DecorationImage(image: FileImage(File(street.photoPath)), fit: BoxFit.cover)
                      : null,
                ),
                child: (street.photoPath.isEmpty || !File(street.photoPath).existsSync())
                    ? const Icon(Icons.turn_slight_right_rounded, color: AppColors.primary, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            street.name,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        OwnershipBadge(
                          createdBy: street.createdBy,
                          workerName: street.workerName,
                        ),
                      ],
                    ),
                    if (street.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        street.description,
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
                            '${street.customerCount} customers',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                        if (street.mapsLocation.isNotEmpty)
                          InkWell(
                            onTap: () async {
                              final loc = street.mapsLocation.trim();
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.location_on_rounded, size: 12, color: Colors.deepOrange),
                                  SizedBox(width: 4),
                                  Text('📍 Location', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.deepOrange)),
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
                  if (v == 'edit')   onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit',   child: Text('Edit')),
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
