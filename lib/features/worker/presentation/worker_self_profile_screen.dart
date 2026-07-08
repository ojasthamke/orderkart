import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/package_exporter.dart';
import '../../../core/services/package_validator.dart';
import '../../../core/services/worker_package_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/services/hotspot_sync_service.dart';
import '../../../core/widgets/hotspot_sync_control_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/export_filename_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../domain/worker.dart';
import '../../area/presentation/area_provider.dart';
import '../../customer/presentation/customer_provider.dart';
import '../../order/presentation/order_provider.dart';
import '../../expense/presentation/expense_provider.dart';
import '../../settings/presentation/sync_history_screen.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../../street/presentation/street_provider.dart';
import '../../notification/presentation/notification_provider.dart';
import '../../../core/services/worker_session.dart';

class WorkerProfileData {
  final Worker worker;
  final int totalOrders;
  final double totalSales;
  final double pendingDues;
  final int totalNotes;

  WorkerProfileData({
    required this.worker,
    required this.totalOrders,
    required this.totalSales,
    required this.pendingDues,
    required this.totalNotes,
  });
}

final currentWorkerProfileProvider = FutureProvider<WorkerProfileData?>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final workerId = WorkerSession.instance.currentWorkerId;
  final List<Map<String, dynamic>> workers;
  if (workerId != null && workerId.isNotEmpty) {
    workers = await db.query('workers', where: 'id = ?', whereArgs: [workerId]);
  } else {
    workers = await db.query('workers', limit: 1);
  }
  if (workers.isEmpty) return null;

  final w = Worker.fromMap(workers.first);
  
  final custRes = await db.rawQuery('SELECT COUNT(*) as v FROM customers WHERE assigned_worker_id = ?', [w.id]);
  final areaRes = await db.rawQuery('SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "area"', [w.id]);
  final streetRes = await db.rawQuery('SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "street"', [w.id]);
  final collRes = await db.rawQuery('SELECT COALESCE(SUM(amount), 0) as v FROM payments p JOIN orders o ON p.order_id = o.id WHERE o.assigned_worker_id = ?', [w.id]);

  final orderRes = await db.rawQuery('SELECT COUNT(*) as v FROM orders WHERE assigned_worker_id = ?', [w.id]);
  final salesRes = await db.rawQuery('SELECT COALESCE(SUM(grand_total), 0) as v FROM orders WHERE assigned_worker_id = ?', [w.id]);
  final duesRes = await db.rawQuery('SELECT COALESCE(SUM(remaining_amount), 0) as v FROM orders WHERE assigned_worker_id = ?', [w.id]);
  final noteRes = await db.rawQuery('SELECT COUNT(*) as v FROM notes WHERE worker_id = ?', [w.id]);

  final workerWithCounts = w.copyWith(
    assignedCustomersCount: (custRes.first['v'] as num?)?.toInt() ?? 0,
    assignedAreasCount: (areaRes.first['v'] as num?)?.toInt() ?? 0,
    assignedStreetsCount: (streetRes.first['v'] as num?)?.toInt() ?? 0,
    totalCollection: (collRes.first['v'] as num?)?.toDouble() ?? 0.0,
  );

  return WorkerProfileData(
    worker: workerWithCounts,
    totalOrders: (orderRes.first['v'] as num?)?.toInt() ?? 0,
    totalSales: (salesRes.first['v'] as num?)?.toDouble() ?? 0.0,
    pendingDues: (duesRes.first['v'] as num?)?.toDouble() ?? 0.0,
    totalNotes: (noteRes.first['v'] as num?)?.toInt() ?? 0,
  );
});

class WorkerSelfProfileScreen extends ConsumerStatefulWidget {
  const WorkerSelfProfileScreen({super.key});

  @override
  ConsumerState<WorkerSelfProfileScreen> createState() => _WorkerSelfProfileScreenState();
}

class _WorkerSelfProfileScreenState extends ConsumerState<WorkerSelfProfileScreen> {

  void _invalidateAllProviders() {
    ref.invalidate(currentWorkerProfileProvider);
    ref.invalidate(areaProvider);
    ref.invalidate(streetProviderFamily);
    ref.invalidate(allCustomersProvider);
    ref.invalidate(customerListProvider);
    ref.invalidate(pendingCustomersProvider);
    ref.invalidate(overpaidCustomersProvider);
    ref.invalidate(inventoryProvider);
    ref.invalidate(lowStockProvider);
    ref.invalidate(outOfStockProvider);
    ref.invalidate(stockSummaryProvider);
    ref.invalidate(orderManagementProvider);
    ref.invalidate(customerOrdersProvider);
    ref.invalidate(analyticsSummaryProvider);
    ref.invalidate(weeklyChartProvider);
    ref.invalidate(monthlyChartProvider);
    ref.invalidate(topCustomersProvider);
    ref.invalidate(todaysDetailedReportProvider);
    ref.invalidate(profitLossProvider);
    ref.invalidate(expenseProvider);
    ref.invalidate(monthlySummaryProvider);
    ref.invalidate(importHistoryProvider);
    ref.invalidate(workerSyncHistoryProvider);
    ref.invalidate(notificationListProvider);
  }

  @override
  void initState() {
    super.initState();
    _initProfile();
  }

  Future<void> _initProfile() async {
    final profileData = await ref.read(currentWorkerProfileProvider.future);
    if (profileData != null) {
      final worker = profileData.worker;
      await _ensureWorkerSecurity(worker.id);
      
      // Start Wi-Fi automatic connection sync listener
      HotspotSyncService.startAutoSyncListener(
        workerId: worker.id,
        workerName: worker.name,
        onSyncEvent: (msg) {
          if (mounted) {
            SnackbarHelper.showInfo(context, msg);
            if (msg.contains('SUCCESS')) {
              _invalidateAllProviders();
            }
          }
        },
      );
    }
  }

  @override
  void dispose() {
    HotspotSyncService.stopAutoSyncListener();
    super.dispose();
  }

  Future<void> _ensureWorkerSecurity(String workerId) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('worker_security', where: 'worker_id = ?', whereArgs: [workerId]);
    if (res.isEmpty || (res.first['worker_secret']?.toString() ?? '').isEmpty) {
      final secret = DateTime.now().millisecondsSinceEpoch.toString();
      final nowStr = DateTime.now().toIso8601String();
      await db.insert(
        'worker_security',
        {
          'worker_id': workerId,
          'worker_secret': secret,
          'created_at': nowStr,
          'updated_at': nowStr,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
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
        data: (profileData) {
          if (profileData == null) {
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

          final worker = profileData.worker;

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

                const Text('Sales & Visit Performance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(child: _metricTile('Total Orders', '${profileData.totalOrders}', Icons.receipt_long_rounded, Colors.purple)),
                    const SizedBox(width: 10),
                    Expanded(child: _metricTile('Total Sales', AppFormatters.currency(profileData.totalSales), Icons.shopping_cart_checkout_rounded, AppColors.success)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _metricTile('Pending Dues', AppFormatters.currency(profileData.pendingDues), Icons.hourglass_empty_rounded, Colors.red)),
                    const SizedBox(width: 10),
                    Expanded(child: _metricTile('Logged Notes', '${profileData.totalNotes}', Icons.note_alt_rounded, Colors.teal)),
                  ],
                ),
                const SizedBox(height: 24),



          HotspotSyncControlCard(
            workerId: worker.id,
            workerName: worker.name,
            onSyncCompleted: () {
              _invalidateAllProviders();
            },
          ),
          const SizedBox(height: 24),

                 // --- WORKER IMPORT & EXPORT SECTION ---
                 const Text('Worker Data Import & Export', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                 const SizedBox(height: 4),
                 const Text('Import packages from Owner or export work updates with custom file names:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                 const SizedBox(height: 12),

                 // 1. Import Button
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton.icon(
                     onPressed: () async {
                       AppHaptics.buttonClick();
                       try {
                         final result = await FilePicker.platform.pickFiles(type: FileType.any);
                         if (result == null) return;
                         final path = result.files.single.path;
                         if (path == null) return;
                         final val = await PackageValidator.validatePackage(path);
                         if (!val.isValid) {
                           if (context.mounted) SnackbarHelper.showError(context, 'Invalid Package: ${val.errorMessage}');
                           return;
                         }
                         await DatabaseHelper.instance.mergeDatabaseFromPath(val.dbPath, selectedModules: ['entire_db']);
                         _invalidateAllProviders();
                         if (context.mounted) SnackbarHelper.showSuccess(context, '✅ Owner package imported successfully!');
                       } catch (e) {
                         if (context.mounted) SnackbarHelper.showError(context, 'Import failed: $e');
                       }
                     },
                     icon: const Icon(Icons.file_download_rounded),
                     label: const Text('Import Package from Owner'),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.teal,
                       foregroundColor: Colors.white,
                       padding: const EdgeInsets.symmetric(vertical: 14),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                     ),
                   ),
                 ),
                 const SizedBox(height: 12),

                // 2 Export Buttons Side-by-Side
                Row(
                  children: [
                    // Button 1: Export Entire Worker Backup
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          AppHaptics.buttonClick();
                          await _ensureWorkerSecurity(worker.id);
                          final defaultName = 'Worker_FullBackup_${worker.name.replaceAll(' ', '_')}_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}';
                          final customName = await ExportFilenameDialog.show(
                            context,
                            defaultName: defaultName,
                            extension: '.orderkart',
                            title: 'Name Worker Backup File',
                          );
                          if (customName == null) return;

                          try {
                            await PackageExporter.exportPackage(
                              selectedModules: ['entire_db', 'photos', 'settings'],
                              workerId: worker.id,
                              workerName: worker.name,
                              customFileName: customName,
                            );
                            if (context.mounted) {
                              SnackbarHelper.showSuccess(context, '✅ Full Backup "$customName" exported!');
                            }
                          } catch (e) {
                            if (context.mounted) SnackbarHelper.showError(context, 'Export failed: $e');
                          }
                        },
                        icon: const Icon(Icons.inventory_2_rounded),
                        label: const Text('Export Entire Backup', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Button 2: Share Data to Update Owner
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          AppHaptics.buttonClick();
                          await _ensureWorkerSecurity(worker.id);
                          final defaultName = 'Update_Owner_Data_${worker.name.replaceAll(' ', '_')}_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}';
                          final customName = await ExportFilenameDialog.show(
                            context,
                            defaultName: defaultName,
                            extension: '.orderkart',
                            title: 'Name Owner Update File',
                          );
                          if (customName == null) return;

                          try {
                            await WorkerPackageService.generateWorkerReportPackage(
                              workerId: worker.id,
                              workerName: worker.name,
                              customFileName: customName,
                              isIncremental: true,
                            );
                            if (context.mounted) {
                              SnackbarHelper.showSuccess(context, '✅ Data update "$customName" shared with Owner!');
                            }
                          } catch (e) {
                            if (context.mounted) SnackbarHelper.showError(context, 'Export failed: $e');
                          }
                        },
                        icon: const Icon(Icons.sync_alt_rounded),
                        label: const Text('Share Data to Update Owner', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
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


}
