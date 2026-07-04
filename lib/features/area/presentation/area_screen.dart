/// AreaScreen — List of all areas with search, sort, stats

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../domain/area.dart';
import 'area_provider.dart';
import 'dialogs/add_edit_area_dialog.dart';
import 'widgets/area_card.dart';

class AreaScreen extends ConsumerStatefulWidget {
  final bool showBack;
  const AreaScreen({super.key, this.showBack = true});

  @override
  ConsumerState<AreaScreen> createState() => _AreaScreenState();
}

class _AreaScreenState extends ConsumerState<AreaScreen> {
  String _sort = 'name';

  @override
  Widget build(BuildContext context) {
    final areasAsync = ref.watch(areaProvider);

    return AppScaffold(
      title: 'Areas',
      drawer: const AppDrawer(),
      showBack: widget.showBack,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort_rounded),
          tooltip: 'Sort',
          onSelected: (v) {
            setState(() => _sort = v);
            ref.read(areaProvider.notifier).sort(v);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'name',          child: Text('Sort by Name')),
            const PopupMenuItem(value: 'date',          child: Text('Sort by Date')),
            const PopupMenuItem(value: 'street_count',  child: Text('Sort by Streets')),
            const PopupMenuItem(value: 'customer_count',child: Text('Sort by Customers')),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.search),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_area',
        onPressed: () => _showAddEditDialog(context, null),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          CustomSearchBar(
            hint: 'Search areas...',
            onChanged: (q) => ref.read(areaProvider.notifier).search(q),
          ),
          Expanded(
            child: areasAsync.when(
              loading: () => const LoadingShimmer(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (areas) => areas.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.map_outlined,
                      title: 'No Areas Yet',
                      subtitle: 'Add your first area to get started',
                      actionLabel: 'Add Area',
                      onAction: () => _showAddEditDialog(context, null),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: areas.length,
                      itemBuilder: (ctx, i) => AreaCard(
                        area: areas[i],
                        index: i,
                        onTap: () => Navigator.of(context).pushNamed(
                          AppRoutes.streets,
                          arguments: {
                            'areaId':   areas[i].id,
                            'areaName': areas[i].name,
                          },
                        ),
                        onEdit: () => _showAddEditDialog(context, areas[i]),
                        onDelete: () => _confirmDelete(context, areas[i]),
                      ).animate(delay: (i * 50).ms).fadeIn().slideX(begin: 0.1),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, Area? area) {
    showDialog(
      context: context,
      builder: (_) => AddEditAreaDialog(
        area: area,
        onSave: (name, description, color) async {
          final now = DateTime.now();
          if (area == null) {
            await ref.read(areaProvider.notifier).addArea(Area(
                  id:          const Uuid().v4(),
                  name:        name,
                  description: description,
                  color:       color,
                  createdAt:   now,
                  updatedAt:   now,
                ));
            if (mounted) SnackbarHelper.showSuccess(context, 'Area added successfully');
          } else {
            await ref.read(areaProvider.notifier).updateArea(area.copyWith(
                  name:        name,
                  description: description,
                  color:       color,
                  updatedAt:   now,
                ));
            if (mounted) SnackbarHelper.showSuccess(context, 'Area updated');
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Area area) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete Area',
      message:
          'Delete "${area.name}"? This will also delete all streets and customers inside it.',
    );
    if (!confirmed || !mounted) return;

    await ref.read(areaProvider.notifier).deleteArea(area.id);
    if (!mounted) return;
    SnackbarHelper.showSuccess(context, '"${area.name}" deleted');
  }
}
