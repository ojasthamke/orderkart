import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/package_exporter.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../data/worker_dao.dart';
import '../domain/worker.dart';

final currentWorkerProfileProvider = FutureProvider<Worker?>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final workers = await db.query('workers', limit: 1);
  if (workers.isEmpty) return null;

  final dao = WorkerDao();
  final w = Worker.fromMap(workers.first);
  
  final custRes = await db.rawQuery('SELECT COUNT(*) as v FROM customers WHERE assigned_worker_id = ?', [w.id]);
  final areaRes = await db.rawQuery('SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "area"', [w.id]);
  final streetRes = await db.rawQuery('SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "street"', [w.id]);
  final collRes = await db.rawQuery('SELECT COALESCE(SUM(amount), 0) as v FROM payments p JOIN orders o ON p.order_id = o.id WHERE o.assigned_worker_id = ?', [w.id]);

  return w.copyWith(
    assignedCustomersCount: (custRes.first['v'] as num?)?.toInt() ?? 0,
    assignedAreasCount: (areaRes.first['v'] as num?)?.toInt() ?? 0,
    assignedStreetsCount: (streetRes.first['v'] as num?)?.toInt() ?? 0,
    totalCollection: (collRes.first['v'] as num?)?.toDouble() ?? 0.0,
  );
});

class WorkerSelfProfileScreen extends ConsumerStatefulWidget {
  const WorkerSelfProfileScreen({super.key});

  @override
  ConsumerState<WorkerSelfProfileScreen> createState() => _WorkerSelfProfileScreenState();
}

class _WorkerSelfProfileScreenState extends ConsumerState<WorkerSelfProfileScreen> {
  final _dao = WorkerDao();
  Map<String, bool> _permissions = {};
  bool _loadingPerms = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final worker = await ref.read(currentWorkerProfileProvider.future);
    if (worker != null) {
      final perms = await _dao.getWorkerPermissions(worker.id);
      if (mounted) {
        setState(() {
          _permissions = perms;
          _loadingPerms = false;
        });
      }
    } else {
      if (mounted) setState(() => _loadingPerms = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workerAsync = ref.watch(currentWorkerProfileProvider);

    return AppScaffold(
      title: 'My Worker Profile',
      body: workerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error loading profile: $err')),
        data: (worker) {
          if (worker == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No Worker Profile Found.\nPlease import an Owner Provisioning Package ZIP (.orderkart) to setup this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            );
          }

          final targetPct = worker.monthlyTarget > 0
              ? (worker.totalCollection / worker.monthlyTarget).clamp(0.0, 1.0)
              : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- PROFILE HEADER CARD ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gray200),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.primarySurface,
                        child: Text(
                          worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'W',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary),
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
                                  worker.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.successSurface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'ACTIVE WORKER',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.success),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (worker.employeeId.isNotEmpty)
                              Text('Employee ID: ${worker.employeeId}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            if (worker.phone.isNotEmpty)
                              Text('Phone: ${worker.phone}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text('Device: ${Platform.localHostname}', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- MONTHLY TARGET & PERFORMANCE CARD ---
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.flag_rounded, color: Colors.white, size: 22),
                              SizedBox(width: 8),
                              Text('MONTHLY SALES TARGET', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          Text(
                            '${(targetPct * 100).toStringAsFixed(0)}% Achieved',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: targetPct,
                          minHeight: 8,
                          backgroundColor: Colors.white30,
                          color: Colors.amberAccent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Target Amount', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text(AppFormatters.currency(worker.monthlyTarget), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total Collection', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text(AppFormatters.currency(worker.totalCollection), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- TERRITORIES & METRICS GRID ---
                const Text('Assigned Territory & Route', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(child: _metricTile('Assigned Areas', '${worker.assignedAreasCount}', Icons.map_rounded, AppColors.primary)),
                    const SizedBox(width: 10),
                    Expanded(child: _metricTile('Assigned Streets', '${worker.assignedStreetsCount}', Icons.alt_route_rounded, Colors.indigo)),
                    const SizedBox(width: 10),
                    Expanded(child: _metricTile('My Customers', '${worker.assignedCustomersCount}', Icons.people_rounded, Colors.orange)),
                  ],
                ),
                const SizedBox(height: 24),

                // --- OWNER AUTHORIZED PERMISSIONS ---
                const Text('Owner Authorized Permissions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                const Text('Permissions configured specifically for this device by Master Owner:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 10),

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
                            _permBadge('Create Orders & Billing', 'create_order'),
                            _permBadge('Edit Existing Orders', 'edit_order'),
                            _permBadge('Add New Customers', 'add_customer'),
                            _permBadge('Edit Customer Details', 'edit_customer'),
                            _permBadge('Receive Customer Payments', 'receive_payment'),
                            _permBadge('Adjust Inventory Stock', 'change_stock'),
                            _permBadge('Modify Item Prices', 'change_prices'),
                            _permBadge('Add Daily Expenses', 'add_expenses'),
                            _permBadge('Export Data Package', 'export_data'),
                            _permBadge('View Reports & Performance', 'view_reports'),
                            _permBadge('Manage Field Visit Notes', 'edit_notes'),
                            _permBadge('Manage VIP Subscriptions', 'manage_vip'),
                          ],
                        ),
                ),
                const SizedBox(height: 24),

                // --- EXPORT WORKER BACKUP FOR OWNER BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      AppHaptics.buttonClick();
                      await PackageExporter.exportPackage(
                        selectedModules: ['customers', 'orders', 'payments', 'expenses', 'notes', 'photos'],
                        workerId: worker.id,
                        workerName: worker.name,
                      );
                      if (context.mounted) {
                        SnackbarHelper.showSuccess(context, 'Exported Backup Package for Owner!');
                      }
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Export My Backup Package for Owner', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
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
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _permBadge(String label, String key) {
    final isAllowed = _permissions[key] ?? false;
    return ListTile(
      dense: true,
      leading: Icon(
        isAllowed ? Icons.check_circle_rounded : Icons.lock_rounded,
        color: isAllowed ? AppColors.success : AppColors.gray400,
        size: 20,
      ),
      title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isAllowed ? AppColors.successSurface : AppColors.gray200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isAllowed ? 'ENABLED' : 'LOCKED BY OWNER',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: isAllowed ? AppColors.success : AppColors.gray600,
          ),
        ),
      ),
    );
  }
}
