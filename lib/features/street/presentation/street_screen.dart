import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/constants/app_colors.dart';
import '../domain/street.dart';
import 'street_provider.dart';

class StreetScreen extends ConsumerStatefulWidget {
  final String areaId;
  final String areaName;

  const StreetScreen({super.key, required this.areaId, required this.areaName});

  @override
  ConsumerState<StreetScreen> createState() => _StreetScreenState();
}

class _StreetScreenState extends ConsumerState<StreetScreen> {
  @override
  Widget build(BuildContext context) {
    final streetsAsync = ref.watch(streetProviderFamily(widget.areaId));

    return AppScaffold(
      title: widget.areaName,
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
          Expanded(
            child: streetsAsync.when(
              loading: () => const LoadingShimmer(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (streets) => streets.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.turn_slight_right_rounded,
                      title: 'No Streets Yet',
                      subtitle: 'Add streets to organise your customers',
                      actionLabel: 'Add Street',
                      onAction: () => _showAddEdit(context, null),
                    )
                  : ListView.builder(
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
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEdit(BuildContext context, Street? street) {
    final nameCon  = TextEditingController(text: street?.name ?? '');
    final descCon  = TextEditingController(text: street?.description ?? '');
    final formKey  = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(street == null ? 'Add Street' : 'Edit Street'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
            ],
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
                  id:          const Uuid().v4(),
                  areaId:      widget.areaId,
                  name:        nameCon.text.trim(),
                  description: descCon.text.trim(),
                  createdAt:   now,
                ));
                if (mounted)
                  SnackbarHelper.showSuccess(context, 'Street added');
              } else {
                await notifier.update(street.copyWith(
                  name:        nameCon.text.trim(),
                  description: descCon.text.trim(),
                ));
                if (mounted)
                  SnackbarHelper.showSuccess(context, 'Street updated');
              }
            },
            child: Text(street == null ? 'Add' : 'Update'),
          ),
        ],
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppColors.cardShadow,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.turn_slight_right_rounded,
              color: AppColors.primary),
        ),
        title: Text(street.name,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${street.customerCount} customers',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        trailing: PopupMenuButton<String>(
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
        onTap: onTap,
      ),
    );
  }
}
