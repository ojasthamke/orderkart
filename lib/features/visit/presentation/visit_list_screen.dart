import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import 'visit_provider.dart';

class VisitListScreen extends ConsumerWidget {
  const VisitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitState = ref.watch(visitListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.addEditVisit),
          ),
        ],
      ),
      body: visitState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (visits) {
          if (visits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.route_rounded, size: 64, color: AppColors.gray300),
                  const SizedBox(height: 16),
                  Text('No visits planned',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.textSecondary,
                          )),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushNamed(AppRoutes.addEditVisit),
                    child: const Text('Schedule a Visit'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: visits.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final visit = visits[index];
              final isCompleted = visit.status == 'completed';

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: isCompleted
                          ? AppColors.success.withOpacity(0.3)
                          : AppColors.borderColor(context)),
                ),
                color: isCompleted
                    ? AppColors.success.withOpacity(0.05)
                    : Theme.of(context).cardTheme.color,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  onTap: () {
                    // Navigate to edit visit
                  },
                  leading: CircleAvatar(
                    backgroundColor: isCompleted
                        ? AppColors.success
                        : AppColors.primary,
                    child: Icon(
                      isCompleted ? Icons.check_rounded : Icons.location_on_rounded,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    visit.areaId, // Needs to be joined with actual area name later
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (visit.streetId.isNotEmpty) Text(visit.streetId),
                      if (visit.notes.isNotEmpty)
                        Text(
                          visit.notes,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        AppFormatters.dateFromString(visit.date),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'complete') {
                        ref.read(visitListProvider.notifier).markStatus(visit.id, 'completed');
                      } else if (val == 'pending') {
                        ref.read(visitListProvider.notifier).markStatus(visit.id, 'pending');
                      } else if (val == 'delete') {
                        ref.read(visitListProvider.notifier).deleteVisit(visit.id);
                      }
                    },
                    itemBuilder: (context) => [
                      if (!isCompleted)
                        const PopupMenuItem(value: 'complete', child: Text('Mark Completed')),
                      if (isCompleted)
                        const PopupMenuItem(value: 'pending', child: Text('Mark Pending')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                ),
              ).animate(delay: (index * 40).ms).fadeIn().slideX();
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.addEditVisit),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
