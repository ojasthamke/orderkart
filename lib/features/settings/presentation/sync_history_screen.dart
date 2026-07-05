import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_widget.dart';

final importHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  return await db.query('import_history', orderBy: 'imported_at DESC', limit: 100);
});

final exportHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  return await db.query('export_history', orderBy: 'exported_at DESC', limit: 100);
});

final workerSyncHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  return await db.query('sync_history', orderBy: 'sync_date DESC', limit: 100);
});

class SyncHistoryScreen extends ConsumerWidget {
  const SyncHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: AppScaffold(
        title: 'Data Sync Logs',
        bottom: const TabBar(
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: 'Imports', icon: Icon(Icons.arrow_downward_rounded, size: 20)),
            Tab(text: 'Exports', icon: Icon(Icons.arrow_upward_rounded, size: 20)),
            Tab(text: 'Worker Syncs', icon: Icon(Icons.sync_rounded, size: 20)),
          ],
        ),
        body: TabBarView(
          children: [
            _buildImportList(ref),
            _buildExportList(ref),
            _buildWorkerSyncList(ref),
          ],
        ),
      ),
    );
  }

  Widget _buildImportList(WidgetRef ref) {
    final importsAsync = ref.watch(importHistoryProvider);
    return importsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, _) => Center(child: Text('Error loading imports: $err')),
      data: (logs) {
        if (logs.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.cloud_download_rounded,
            title: 'No Import Logs',
            subtitle: 'All imported worker database merges are recorded here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (ctx, idx) {
            final log = logs[idx];
            final dateStr = log['imported_at'] as String? ?? '';
            final workerName = log['worker_name'] as String? ?? 'Owner';
            final deviceName = log['device_name'] as String? ?? 'Unknown Device';
            final count = log['record_count'] as int? ?? 0;
            final dt = DateTime.tryParse(dateStr) ?? DateTime.now();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gray200),
                boxShadow: AppColors.cardShadow,
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.successSurface,
                  child: Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 20),
                ),
                title: Text(
                  'Imported: $workerName ($deviceName)',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                subtitle: Text(
                  'Modules merged: $count · ${AppFormatters.dateTime(dt)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExportList(WidgetRef ref) {
    final exportsAsync = ref.watch(exportHistoryProvider);
    return exportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, _) => Center(child: Text('Error loading exports: $err')),
      data: (logs) {
        if (logs.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.cloud_upload_rounded,
            title: 'No Export Logs',
            subtitle: 'All modular database packages you export are recorded here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (ctx, idx) {
            final log = logs[idx];
            final dateStr = log['exported_at'] as String? ?? '';
            final type = log['package_type'] as String? ?? 'modular';
            final count = log['record_count'] as int? ?? 0;
            final dt = DateTime.tryParse(dateStr) ?? DateTime.now();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gray200),
                boxShadow: AppColors.cardShadow,
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primarySurface,
                  child: Icon(Icons.arrow_upward_rounded, color: AppColors.primary, size: 20),
                ),
                title: Text(
                  'Export: ${type.toUpperCase()} Package',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                subtitle: Text(
                  'Selected fields: $count · ${AppFormatters.dateTime(dt)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWorkerSyncList(WidgetRef ref) {
    final historyAsync = ref.watch(workerSyncHistoryProvider);
    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, _) => Center(child: Text('Error loading worker syncs: $err')),
      data: (logs) {
        if (logs.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.sync_rounded,
            title: 'No Sync History',
            subtitle: 'Sync operations logged from active worker devices.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (ctx, idx) {
            final log = logs[idx];
            final workerName = log['worker_name'] as String? ?? 'Worker';
            final deviceName = log['device_name'] as String? ?? 'Device';
            final dateStr = log['sync_date'] as String? ?? '';
            final custCount = log['customers_count'] as int? ?? 0;
            final ordCount = log['orders_count'] as int? ?? 0;
            final dt = DateTime.tryParse(dateStr) ?? DateTime.now();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gray200),
                boxShadow: AppColors.cardShadow,
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.successSurface,
                  child: Icon(Icons.sync_alt_rounded, color: AppColors.success, size: 20),
                ),
                title: Text(
                  'Sync: $workerName ($deviceName)',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                subtitle: Text(
                  'Customers +$custCount · Orders +$ordCount · ${AppFormatters.dateTime(dt)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
