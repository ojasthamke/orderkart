import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../data/pending_sync_dao.dart';

final pendingSyncDaoProvider = Provider<PendingSyncDao>((ref) => PendingSyncDao());

final pendingSyncListProvider = FutureProvider<List<PendingSyncItem>>((ref) {
  return ref.watch(pendingSyncDaoProvider).getPendingItems();
});

class PendingSyncScreen extends ConsumerWidget {
  const PendingSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingSyncListProvider);

    return AppScaffold(
      title: 'Pending Sync Queue',
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading queue: $err')),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.cloud_done_outlined,
              title: 'All Edits Synced!',
              subtitle: 'You have no offline edits pending export.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (ctx, idx) {
              final item = items[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gray200),
                  boxShadow: AppColors.cardShadow,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primarySurface,
                    child: Icon(
                      item.actionType == 'created' ? Icons.add_circle_outline_rounded : Icons.edit_note_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    '${item.actionType.toUpperCase()}: ${item.entityType.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Recorded: ${AppFormatters.dateTime(item.createdAt)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PENDING',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.amber.shade900),
                    ),
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
