import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../domain/worker.dart';
import 'dialogs/add_edit_worker_dialog.dart';
import 'worker_provider.dart';

class WorkerManagementScreen extends ConsumerWidget {
  const WorkerManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workersAsync = ref.watch(workerListProvider);

    return AppScaffold(
      title: 'Worker Management',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          AppHaptics.buttonClick();
          final newWorker = await AddEditWorkerDialog.show(context);
          if (newWorker != null) {
            await ref.read(workerListProvider.notifier).add(newWorker);
            if (context.mounted) {
              SnackbarHelper.showSuccess(context, 'Worker "${newWorker.name}" added successfully');
            }
          }
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Worker'),
        backgroundColor: AppColors.primary,
      ),
      body: workersAsync.when(
        loading: () => const LoadingShimmer(count: 5),
        error: (err, _) => Center(child: Text('Error loading workers: $err')),
        data: (workers) {
          if (workers.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.badge_outlined,
              title: 'No Workers Added Yet',
              subtitle: 'Add worker profiles to assign Areas, Streets, and Customers.',
              actionLabel: 'Add First Worker',
              onAction: () async {
                final newWorker = await AddEditWorkerDialog.show(context);
                if (newWorker != null) {
                  await ref.read(workerListProvider.notifier).add(newWorker);
                }
              },
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: workers.length,
            itemBuilder: (ctx, idx) {
              final w = workers[idx];
              return _WorkerCard(worker: w);
            },
          );
        },
      ),
    );
  }
}

class _WorkerCard extends ConsumerWidget {
  final Worker worker;

  const _WorkerCard({required this.worker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInactive = worker.status == 'inactive';
    final commSummary = ref.watch(workerCommissionProvider(worker.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInactive ? AppColors.gray300 : AppColors.gray200,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: isInactive ? AppColors.gray300 : AppColors.primarySurface,
          child: Text(
            worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'W',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isInactive ? AppColors.gray600 : AppColors.primary,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              worker.name,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                decoration: isInactive ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isInactive ? AppColors.gray200 : AppColors.successSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                worker.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isInactive ? AppColors.gray600 : AppColors.success,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          [
            if (worker.employeeId.isNotEmpty) 'ID: ${worker.employeeId}',
            if (worker.phone.isNotEmpty) worker.phone,
            'Rule: ${worker.commissionType.name.toUpperCase()} (${worker.commissionValue}%)',
          ].join(' · '),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statBox('Assigned Customers', '${worker.assignedCustomersCount}', Icons.people_outline_rounded),
                    _statBox('Assigned Areas', '${worker.assignedAreasCount}', Icons.map_outlined),
                    _statBox('Total Collection', AppFormatters.currency(worker.totalCollection), Icons.payments_outlined),
                  ],
                ),
                const SizedBox(height: 16),

                // Commission breakdown box
                commSummary.maybeWhen(
                  data: (comm) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Today's Commission", style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                            Text(AppFormatters.currency(comm['today'] ?? 0),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("Monthly Commission", style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                            Text(AppFormatters.currency(comm['monthly'] ?? 0),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.success)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                      tooltip: 'Edit Worker Profile',
                      onPressed: () async {
                        final updated = await AddEditWorkerDialog.show(context, worker: worker);
                        if (updated != null) {
                          await ref.read(workerListProvider.notifier).update(updated);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                      tooltip: 'Delete Worker',
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Worker?'),
                            content: Text('Delete "${worker.name}"? Assignments will be cleared.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ref.read(workerListProvider.notifier).delete(worker.id);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.gray600),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
      ],
    );
  }
}
