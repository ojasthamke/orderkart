import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/package_exporter.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';

import '../data/worker_dao.dart';
import '../domain/worker.dart';
import 'worker_provider.dart';

class WorkerControlPanelScreen extends ConsumerStatefulWidget {
  final Worker worker;

  const WorkerControlPanelScreen({super.key, required this.worker});

  @override
  ConsumerState<WorkerControlPanelScreen> createState() => _WorkerControlPanelScreenState();
}

class _WorkerControlPanelScreenState extends ConsumerState<WorkerControlPanelScreen> {
  final _dao = WorkerDao();
  Map<String, bool> _permissions = {};
  bool _loadingPerms = true;
  late Worker _currentWorker;

  @override
  void initState() {
    super.initState();
    _currentWorker = widget.worker;
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final perms = await _dao.getWorkerPermissions(_currentWorker.id);
    if (mounted) {
      setState(() {
        _permissions = perms;
        _loadingPerms = false;
      });
    }
  }

  Future<void> _togglePermission(String key, bool value) async {
    AppHaptics.buttonClick();
    setState(() {
      _permissions[key] = value;
    });
    await _dao.updateWorkerPermissions(_currentWorker.id, _permissions);
  }

  Future<void> _toggleWorkerStatus() async {
    AppHaptics.buttonClick();
    final newStatus = _currentWorker.status == 'active' ? 'inactive' : 'active';
    final updated = _currentWorker.copyWith(status: newStatus);
    await ref.read(workerListProvider.notifier).update(updated);
    setState(() {
      _currentWorker = updated;
    });
    if (mounted) {
      SnackbarHelper.showSuccess(context, 'Worker status changed to ${newStatus.toUpperCase()}');
    }
  }

  Future<void> _showTransferDialog(String entityType) async {
    final workers = await _dao.getAllWorkers();
    final otherWorkers = workers.where((w) => w.id != _currentWorker.id).toList();

    if (otherWorkers.isEmpty) {
      if (mounted) {
        SnackbarHelper.showError(context, 'No other workers available for transfer.');
      }
      return;
    }

    String? targetWorkerId = otherWorkers.first.id;

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Transfer ${entityType.toUpperCase()}s'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transfer all assigned ${entityType}s from ${_currentWorker.name} to:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: targetWorkerId,
                isExpanded: true,
                items: otherWorkers.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                onChanged: (val) => setDialogState(() => targetWorkerId = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Transfer'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && targetWorkerId != null) {
      await _dao.transferAssignments(
        fromWorkerId: _currentWorker.id,
        toWorkerId: targetWorkerId!,
        entityType: entityType,
      );
      ref.read(workerListProvider.notifier).load();
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Assignments transferred successfully');
      }
    }
  }

  Future<void> _exportWorkerData() async {
    AppHaptics.buttonClick();
    await PackageExporter.exportPackage(
      selectedModules: ['customers', 'orders', 'payments', 'expenses', 'photos'],
      selectedWorkerIds: [_currentWorker.id],
      workerId: _currentWorker.id,
      workerName: _currentWorker.name,
    );
  }

  Future<void> _resetPin() async {
    final updated = _currentWorker.copyWith(pin: '');
    await ref.read(workerListProvider.notifier).update(updated);
    setState(() => _currentWorker = updated);
    if (mounted) {
      SnackbarHelper.showSuccess(context, 'Worker PIN reset successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final commSummary = ref.watch(workerCommissionProvider(_currentWorker.id));

    return AppScaffold(
      title: 'Worker Control Panel',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER PROFILE CARD ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gray200),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: _currentWorker.status == 'active'
                        ? AppColors.primarySurface
                        : AppColors.gray300,
                    child: Text(
                      _currentWorker.name.isNotEmpty ? _currentWorker.name[0].toUpperCase() : 'W',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _currentWorker.status == 'active'
                            ? AppColors.primary
                            : AppColors.gray600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _currentWorker.name,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _currentWorker.status == 'active'
                                    ? AppColors.successSurface
                                    : AppColors.gray200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 3,
                                    backgroundColor: _currentWorker.status == 'active'
                                        ? AppColors.success
                                        : AppColors.gray600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _currentWorker.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: _currentWorker.status == 'active'
                                          ? AppColors.success
                                          : AppColors.gray600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (_currentWorker.employeeId.isNotEmpty) 'ID: ${_currentWorker.employeeId}',
                            if (_currentWorker.phone.isNotEmpty) _currentWorker.phone,
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- METRICS & PERFORMANCE GRID ---
            const Text('Performance & Metrics', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(child: _metricTile('Assigned Areas', '${_currentWorker.assignedAreasCount}', Icons.map_rounded, AppColors.primary)),
                const SizedBox(width: 10),
                Expanded(child: _metricTile('Customers', '${_currentWorker.assignedCustomersCount}', Icons.people_rounded, Colors.orange)),
                const SizedBox(width: 10),
                Expanded(child: _metricTile('Score', '96%', Icons.star_rounded, Colors.amber.shade700)),
              ],
            ),
            const SizedBox(height: 10),

            commSummary.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (comm) => Row(
                children: [
                  Expanded(child: _metricTile("Today's Comm.", AppFormatters.currency(comm['today'] ?? 0), Icons.monetization_on_rounded, AppColors.success)),
                  const SizedBox(width: 10),
                  Expanded(child: _metricTile('Total Coll.', AppFormatters.currency(_currentWorker.totalCollection), Icons.account_balance_wallet_rounded, Colors.purple)),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // --- WORKER PERMISSIONS CHECKLIST ---
            const Text('Worker Permissions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Enable or disable specific features for this worker profile:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gray200),
                boxShadow: AppColors.cardShadow,
              ),
              child: _loadingPerms
                  ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
                  : Column(
                      children: [
                        _permTile('Add Customer', 'add_customer'),
                        _permTile('Edit Customer', 'edit_customer'),
                        _permTile('Delete Customer', 'delete_customer'),
                        _permTile('Create Order', 'create_order'),
                        _permTile('Edit Order', 'edit_order'),
                        _permTile('Receive Payment', 'receive_payment'),
                        _permTile('Change Stock', 'change_stock'),
                        _permTile('Change Prices', 'change_prices'),
                        _permTile('Add Expenses', 'add_expenses'),
                        _permTile('Export Data', 'export_data'),
                        _permTile('View Reports', 'view_reports'),
                        _permTile('Manage VIP', 'manage_vip'),
                        _permTile('Backup & Restore', 'backup_restore'),
                      ],
                    ),
            ),

            const SizedBox(height: 24),
            // --- ADMINISTRATIVE ACTIONS ---
            const Text('Administrative Actions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gray200),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  _actionTile(
                    title: 'Transfer Customers',
                    icon: Icons.move_up_rounded,
                    color: AppColors.primary,
                    onTap: () => _showTransferDialog('customer'),
                  ),
                  const Divider(height: 1),
                  _actionTile(
                    title: 'Transfer Areas',
                    icon: Icons.alt_route_rounded,
                    color: Colors.indigo,
                    onTap: () => _showTransferDialog('area'),
                  ),
                  const Divider(height: 1),
                  _actionTile(
                    title: 'Export Worker Data',
                    icon: Icons.ios_share_rounded,
                    color: AppColors.success,
                    onTap: _exportWorkerData,
                  ),
                  const Divider(height: 1),
                  _actionTile(
                    title: 'Reset Worker PIN',
                    icon: Icons.lock_reset_rounded,
                    color: Colors.orange,
                    onTap: _resetPin,
                  ),
                  const Divider(height: 1),
                  _actionTile(
                    title: _currentWorker.status == 'active' ? 'Deactivate Worker' : 'Activate Worker',
                    icon: _currentWorker.status == 'active' ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                    color: Colors.deepOrange,
                    onTap: _toggleWorkerStatus,
                  ),
                  const Divider(height: 1),
                  _actionTile(
                    title: 'Delete Worker Profile',
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.error,
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Worker Profile?'),
                          content: Text('Delete "${_currentWorker.name}"? Assignments will be unlinked.'),
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
                        await ref.read(workerListProvider.notifier).delete(_currentWorker.id);
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _metricTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _permTile(String label, String key) {
    final isChecked = _permissions[key] ?? false;
    return CheckboxListTile(
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      value: isChecked,
      onChanged: (val) => _togglePermission(key, val ?? false),
      activeColor: AppColors.primary,
    );
  }

  Widget _actionTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.gray400),
      onTap: onTap,
    );
  }
}
