// lib/features/worker/presentation/worker_control_panel_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/package_exporter.dart';
import '../../../core/services/worker_permission_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/models/worker_permission.dart';

import '../data/worker_dao.dart';
import '../domain/worker.dart';
import 'worker_provider.dart';

class WorkerControlPanelScreen extends ConsumerStatefulWidget {
  final Worker worker;

  const WorkerControlPanelScreen({super.key, required this.worker});

  @override
  ConsumerState<WorkerControlPanelScreen> createState() => _WorkerControlPanelScreenState();
}

class _WorkerControlPanelScreenState extends ConsumerState<WorkerControlPanelScreen> with SingleTickerProviderStateMixin {
  final _dao = WorkerDao();
  late TabController _tabController;
  late Worker _currentWorker;
  WorkerPermission? _permissions;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentWorker = widget.worker;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final perms = await WorkerPermissionService.getPermissionsForWorker(_currentWorker.id);
    if (mounted) {
      setState(() {
        _permissions = perms;
        _loading = false;
      });
    }
  }

  Future<void> _changePermissionLevel(String field, PermissionLevel newLevel) async {
    if (_permissions == null) return;
    AppHaptics.buttonClick();

    final map = _permissions!.toMap();
    // Translate UI field names to DB column names if needed
    String dbCol = field;
    if (field == 'customers') dbCol = 'add_customer';
    if (field == 'orders') dbCol = 'create_order';
    if (field == 'payments') dbCol = 'receive_payment';
    if (field == 'expenses') dbCol = 'add_expenses';
    if (field == 'sellingPrice') dbCol = 'edit_selling_price';
    if (field == 'costPrice') dbCol = 'edit_cost_price';
    if (field == 'stock') dbCol = 'edit_stock_quantity';
    if (field == 'items') dbCol = 'add_new_item';
    if (field == 'vip') dbCol = 'manage_vip';
    if (field == 'reports') dbCol = 'view_reports';
    if (field == 'notes') dbCol = 'edit_notes';
    if (field == 'export') dbCol = 'export_data';
    if (field == 'import') dbCol = 'import_data';
    if (field == 'settings') dbCol = 'backup_restore';
    if (field == 'analytics') dbCol = 'delete_customer';

    map[dbCol] = newLevel.toInt();
    map['updated_at'] = DateTime.now().toIso8601String();

    final updatedPerms = WorkerPermission.fromMap(map);
    await WorkerPermissionService.savePermissions(updatedPerms);
    setState(() {
      _permissions = updatedPerms;
    });
    SnackbarHelper.showSuccess(context, 'Permissions updated successfully.');
  }

  Future<void> _toggleWorkerStatus() async {
    AppHaptics.buttonClick();
    final newStatus = _currentWorker.status == 'active' ? 'inactive' : 'active';
    final updated = _currentWorker.copyWith(status: newStatus);
    await ref.read(workerListProvider.notifier).update(updated);
    setState(() {
      _currentWorker = updated;
    });
    SnackbarHelper.showSuccess(context, 'Worker status changed to ${newStatus.toUpperCase()}');
  }

  Future<void> _showTransferDialog(String entityType) async {
    final workers = await _dao.getAllWorkers();
    final otherWorkers = workers.where((w) => w.id != _currentWorker.id).toList();

    if (otherWorkers.isEmpty) {
      SnackbarHelper.showError(context, 'No other workers available for transfer.');
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
      SnackbarHelper.showSuccess(context, 'Assignments transferred successfully');
    }
  }

  Future<void> _exportWorkerPackage() async {
    AppHaptics.buttonClick();
    SnackbarHelper.showInfo(context, 'Generating provisioning package...');
    await PackageExporter.exportPackage(
      selectedModules: ['workers', 'settings', 'areas', 'streets', 'customers', 'items'],
      selectedWorkerIds: [_currentWorker.id],
      workerId: _currentWorker.id,
      workerName: _currentWorker.name,
    );
  }

  Future<void> _resetPin() async {
    final updated = _currentWorker.copyWith(pinHash: '');
    await ref.read(workerListProvider.notifier).update(updated);
    setState(() => _currentWorker = updated);
    SnackbarHelper.showSuccess(context, 'Worker PIN reset successfully. PIN lock is cleared.');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Worker Profile',
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return AppScaffold(
      title: _currentWorker.name,
      bottom: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        tabs: const [
          Tab(text: 'Profile', icon: Icon(Icons.person_rounded, size: 20)),
          Tab(text: 'Access', icon: Icon(Icons.shield_rounded, size: 20)),
          Tab(text: 'Assign', icon: Icon(Icons.map_rounded, size: 20)),
          Tab(text: 'Stats', icon: Icon(Icons.analytics_rounded, size: 20)),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(),
          _buildPermissionsTab(),
          _buildAssignmentsTab(),
          _buildStatsTab(),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- HEADER ---
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
                radius: 32,
                backgroundColor: _currentWorker.status == 'active' ? AppColors.primarySurface : AppColors.gray300,
                child: Text(
                  _currentWorker.name.isNotEmpty ? _currentWorker.name[0].toUpperCase() : 'W',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _currentWorker.status == 'active' ? AppColors.primary : AppColors.gray600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentWorker.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Employee ID: ${_currentWorker.employeeId.isEmpty ? '—' : _currentWorker.employeeId}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _currentWorker.status == 'active' ? AppColors.successSurface : AppColors.gray200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _currentWorker.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _currentWorker.status == 'active' ? AppColors.success : AppColors.gray600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // --- CONTACT & PERSONAL ---
        _sectionTitle('Contact & Personal Details'),
        _card([
          _infoRow('Phone', _currentWorker.phone.isEmpty ? '—' : _currentWorker.phone),
          _infoRow('Address', _currentWorker.address.isEmpty ? '—' : _currentWorker.address),
          _infoRow('Aadhaar ID', _currentWorker.aadhaarId.isEmpty ? '—' : _currentWorker.aadhaarId),
          _infoRow('Emergency Contact', _currentWorker.emergencyContact.isEmpty ? '—' : _currentWorker.emergencyContact),
          _infoRow('Bank Details / UPI', _currentWorker.bankDetails.isEmpty ? '—' : _currentWorker.bankDetails),
        ]),
        const SizedBox(height: 20),

        // --- FINANCIAL TERMS ---
        _sectionTitle('Financial Terms'),
        _card([
          _infoRow('Commission Type', _currentWorker.commissionType.name.toUpperCase()),
          _infoRow('Commission Value', '${_currentWorker.commissionValue}%'),
          _infoRow('Base Salary', AppFormatters.currency(_currentWorker.salary)),
          _infoRow('Performance Bonus', AppFormatters.currency(_currentWorker.bonus)),
          _infoRow('Monthly Target', AppFormatters.currency(_currentWorker.monthlyTarget)),
          _infoRow('Remarks / Notes', _currentWorker.remarks.isEmpty ? '—' : _currentWorker.remarks),
        ]),
        const SizedBox(height: 20),

        // --- ADMINISTRATIVE ACTIONS ---
        _sectionTitle('Administrative Actions'),
        _card([
          _actionTile(
            title: 'Generate Worker Package',
            icon: Icons.cloud_upload_rounded,
            color: AppColors.primary,
            onTap: _exportWorkerPackage,
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
            title: _currentWorker.status == 'active' ? 'Suspend Worker Account' : 'Activate Worker Account',
            icon: _currentWorker.status == 'active' ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
            color: _currentWorker.status == 'active' ? Colors.deepOrange : AppColors.success,
            onTap: _toggleWorkerStatus,
          ),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPermissionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Worker Permissions Levels'),
        const Text(
          'Select access level for each operational domain. Hidden restricts access; View allows read-only; Edit allows writes; Full allows administrative writes.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        _card([
          _permissionLevelRow('Customers', 'customers'),
          const Divider(height: 1),
          _permissionLevelRow('Orders', 'orders'),
          const Divider(height: 1),
          _permissionLevelRow('Payments', 'payments'),
          const Divider(height: 1),
          _permissionLevelRow('Expenses', 'expenses'),
          const Divider(height: 1),
          _permissionLevelRow('Selling Price (Daily Updates)', 'sellingPrice'),
          const Divider(height: 1),
          _permissionLevelRow('Cost Price Visibility', 'costPrice'),
          const Divider(height: 1),
          _permissionLevelRow('Stock Levels', 'stock'),
          const Divider(height: 1),
          _permissionLevelRow('Items Catalog', 'items'),
          const Divider(height: 1),
          _permissionLevelRow('VIP Customers', 'vip'),
          const Divider(height: 1),
          _permissionLevelRow('Reports Dashboard', 'reports'),
          const Divider(height: 1),
          _permissionLevelRow('Notes Manager', 'notes'),
          const Divider(height: 1),
          _permissionLevelRow('Data Export Slices', 'export'),
          const Divider(height: 1),
          _permissionLevelRow('Data Import merges', 'import'),
          const Divider(height: 1),
          _permissionLevelRow('System Settings', 'settings'),
          const Divider(height: 1),
          _permissionLevelRow('Analytics Dashboard', 'analytics'),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAssignmentsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Territory & Catalog Assignments'),
        _card([
          _infoRow('Assigned Areas Count', '${_currentWorker.assignedAreasCount} Areas'),
          _infoRow('Assigned Streets Count', '${_currentWorker.assignedStreetsCount} Streets'),
          _infoRow('Assigned Customers Count', '${_currentWorker.assignedCustomersCount} Customers'),
        ]),
        const SizedBox(height: 20),

        _sectionTitle('Re-Route / Transfer Tools'),
        _card([
          _actionTile(
            title: 'Transfer Assigned Customers',
            icon: Icons.move_up_rounded,
            color: Colors.indigo,
            onTap: () => _showTransferDialog('customer'),
          ),
          const Divider(height: 1),
          _actionTile(
            title: 'Transfer Assigned Areas',
            icon: Icons.alt_route_rounded,
            color: Colors.teal,
            onTap: () => _showTransferDialog('area'),
          ),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStatsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Sync & Device Provenance'),
        _card([
          _infoRow('Last Synchronized', _currentWorker.joiningDate.isEmpty ? 'Never Synced' : AppFormatters.dateFromString(_currentWorker.joiningDate)),
          _infoRow('Device Hostname', 'Child-Device-Active'),
          _infoRow('App Version Version', 'v1.0.0'),
          _infoRow('Database Schema Version', 'V4'),
        ]),
        const SizedBox(height: 20),

        _sectionTitle('Earning Stats'),
        _card([
          _infoRow('Total Collection Recovered', AppFormatters.currency(_currentWorker.totalCollection)),
          _infoRow('Average Commission Score', '96% (Executive)'),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      trailing: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _permissionLevelRow(String title, String field) {
    if (_permissions == null) return const SizedBox.shrink();
    final map = _permissions!.toMap();

    String dbCol = field;
    if (field == 'customers') dbCol = 'add_customer';
    if (field == 'orders') dbCol = 'create_order';
    if (field == 'payments') dbCol = 'receive_payment';
    if (field == 'expenses') dbCol = 'add_expenses';
    if (field == 'sellingPrice') dbCol = 'edit_selling_price';
    if (field == 'costPrice') dbCol = 'edit_cost_price';
    if (field == 'stock') dbCol = 'edit_stock_quantity';
    if (field == 'items') dbCol = 'add_new_item';
    if (field == 'vip') dbCol = 'manage_vip';
    if (field == 'reports') dbCol = 'view_reports';
    if (field == 'notes') dbCol = 'edit_notes';
    if (field == 'export') dbCol = 'export_data';
    if (field == 'import') dbCol = 'import_data';
    if (field == 'settings') dbCol = 'backup_restore';
    if (field == 'analytics') dbCol = 'delete_customer';

    final int rawVal = map[dbCol] as int? ?? 0;
    final PermissionLevel currentLevel = PermissionLevel.fromInt(rawVal);

    return ListTile(
      dense: true,
      title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      trailing: DropdownButton<PermissionLevel>(
        value: currentLevel,
        underline: const SizedBox.shrink(),
        items: PermissionLevel.values.map((lvl) {
          return DropdownMenuItem<PermissionLevel>(
            value: lvl,
            child: Text(lvl.name.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            _changePermissionLevel(field, val);
          }
        },
      ),
    );
  }

  Widget _actionTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.gray400),
      onTap: onTap,
    );
  }
}
