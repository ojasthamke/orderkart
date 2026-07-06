// lib/features/worker/presentation/worker_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../domain/worker.dart';
import 'dialogs/add_edit_worker_dialog.dart';
import 'worker_control_panel_screen.dart';
import 'worker_provider.dart';

class WorkerManagementScreen extends ConsumerStatefulWidget {
  const WorkerManagementScreen({super.key});

  @override
  ConsumerState<WorkerManagementScreen> createState() => _WorkerManagementScreenState();
}

class _WorkerManagementScreenState extends ConsumerState<WorkerManagementScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'all'; // 'all', 'active', 'suspended', 'leave'

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(workerListProvider);

    return AppScaffold(
      title: 'Worker Management',
      actions: [
        IconButton(
          icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.deepPurple),
          tooltip: 'Permission Manager',
          onPressed: () {
            SnackbarHelper.showInfo(context, 'Select any worker below to configure permissions.');
          },
        ),
        IconButton(
          icon: const Icon(Icons.analytics_rounded),
          tooltip: 'Worker Analytics',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.workerAnalytics),
        ),
      ],
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
      body: Column(
        children: [
          // --- SEARCH BAR ---
          CustomSearchBar(
            hint: 'Search workers by name or ID...',
            onChanged: (val) {
              setState(() {
                _searchQuery = val.toLowerCase();
              });
            },
          ),

          // --- FILTER CHIPS ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _filterChip('All Statuses', 'all'),
                const SizedBox(width: 8),
                _filterChip('Active', 'active'),
                const SizedBox(width: 8),
                _filterChip('Suspended', 'suspended'),
                const SizedBox(width: 8),
                _filterChip('On Leave', 'leave'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // --- WORKER DIRECTORY LIST ---
          Expanded(
            child: workersAsync.when(
              loading: () => const LoadingShimmer(count: 5),
              error: (err, _) => Center(child: Text('Error loading workers: $err')),
              data: (workers) {
                // Filter the list based on query and status selection
                final filtered = workers.where((w) {
                  final matchesSearch = w.name.toLowerCase().contains(_searchQuery) ||
                      w.employeeId.toLowerCase().contains(_searchQuery);

                  if (!matchesSearch) return false;

                  if (_selectedStatus == 'active' && w.status != 'active') return false;
                  if (_selectedStatus == 'suspended' && w.status != 'inactive') return false;
                  if (_selectedStatus == 'leave' && w.leaveStatus != 'leave') return false;

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.badge_outlined,
                    title: 'No Workers Match Filters',
                    subtitle: 'Modify search criteria or add new worker profile.',
                    actionLabel: 'Clear Search',
                    onAction: () {
                      setState(() {
                        _searchQuery = '';
                        _selectedStatus = 'all';
                      });
                    },
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final w = filtered[idx];
                    return _WorkerCard(worker: w);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      onSelected: (val) {
        AppHaptics.buttonClick();
        setState(() {
          _selectedStatus = value;
        });
      },
    );
  }
}

class _WorkerCard extends ConsumerWidget {
  final Worker worker;

  const _WorkerCard({required this.worker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuspended = worker.status == 'inactive';
    final isOnLeave = worker.leaveStatus == 'leave';

    // Calculate Target completion %
    final double targetCompletion = worker.monthlyTarget > 0
        ? (worker.totalCollection / worker.monthlyTarget) * 100.0
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuspended ? AppColors.gray300 : AppColors.gray200,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: isSuspended ? AppColors.gray300 : AppColors.primarySurface,
              child: Text(
                worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'W',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isSuspended ? AppColors.gray600 : AppColors.primary,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    worker.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      decoration: isSuspended ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                _statusBadge(isSuspended, isOnLeave),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                [
                  if (worker.employeeId.isNotEmpty) 'ID: ${worker.employeeId}',
                  'Rule: ${worker.commissionType.name.toUpperCase()}',
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ),
          const Divider(height: 1),

          // --- STATS OVERVIEW ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniStat('Total Coll.', AppFormatters.currency(worker.totalCollection)),
                _miniStat('Target %', '${targetCompletion.toStringAsFixed(0)}%'),
                _miniStat('Last Sync', worker.joiningDate.isEmpty ? 'Never' : AppFormatters.shortDate(DateTime.tryParse(worker.joiningDate) ?? DateTime.now())),
              ],
            ),
          ),

          const Divider(height: 1),
          // --- LINK TO ADMINISTRATIVE VIEW ---
          ListTile(
            dense: true,
            title: const Text('Open Profile & Access Controls',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
            onTap: () {
              AppHaptics.buttonClick();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkerControlPanelScreen(worker: worker),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: AppColors.textHint, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _statusBadge(bool isSuspended, bool isOnLeave) {
    String label = 'ACTIVE';
    Color color = AppColors.success;
    Color bg = AppColors.successSurface;

    if (isSuspended) {
      label = 'SUSPENDED';
      color = AppColors.error;
      bg = AppColors.errorSurface;
    } else if (isOnLeave) {
      label = 'ON LEAVE';
      color = Colors.orange;
      bg = Colors.orange.withOpacity(0.12);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
