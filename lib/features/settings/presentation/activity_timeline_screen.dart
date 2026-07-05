import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_widget.dart';

final activityLogsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  return await db.query('audit_logs', orderBy: 'created_at DESC', limit: 100);
});

class ActivityTimelineScreen extends ConsumerWidget {
  const ActivityTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(activityLogsProvider);

    return AppScaffold(
      title: 'Activity Timeline',
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading activity: $err')),
        data: (logs) {
          if (logs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.history_rounded,
              title: 'No Activity Logged',
              subtitle: 'Important actions like imports, edits, and stock adjustments will appear here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (ctx, idx) {
              final log = logs[idx];
              final action = log['action'] as String? ?? 'Action';
              final userType = log['user_type'] as String? ?? 'owner';
              final createdAt = DateTime.tryParse(log['created_at'] as String? ?? '') ?? DateTime.now();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gray200),
                  boxShadow: AppColors.cardShadow,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: userType == 'owner' ? AppColors.primarySurface : const Color(0xFFF0F9FF),
                    child: Icon(
                      userType == 'owner' ? Icons.security_rounded : Icons.badge_rounded,
                      color: userType == 'owner' ? AppColors.primary : const Color(0xFF0369A1),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    action,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${userType.toUpperCase()} · ${AppFormatters.dateTime(createdAt)}',
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
