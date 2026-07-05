import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_widget.dart';

final syncHistoryListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  return await db.query('sync_history', orderBy: 'sync_date DESC', limit: 100);
});

class SyncHistoryScreen extends ConsumerWidget {
  const SyncHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(syncHistoryListProvider);

    return AppScaffold(
      title: 'Sync History',
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading sync logs: $err')),
        data: (logs) {
          if (logs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.sync_rounded,
              title: 'No Sync History',
              subtitle: 'Past database imports and worker synchronization logs will be stored here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (ctx, idx) {
              final log = logs[idx];
              final workerName = log['worker_name'] as String? ?? 'Worker';
              final deviceName = log['device_name'] as String? ?? 'Device';
              final dateStr    = log['sync_date'] as String? ?? '';
              final custCount  = log['customers_count'] as int? ?? 0;
              final ordCount   = log['orders_count'] as int? ?? 0;
              final dt         = DateTime.tryParse(dateStr) ?? DateTime.now();

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
                    child: Icon(Icons.sync_alt_rounded, color: AppColors.success, size: 22),
                  ),
                  title: Text(
                    'Sync: $workerName ($deviceName)',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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
      ),
    );
  }
}
