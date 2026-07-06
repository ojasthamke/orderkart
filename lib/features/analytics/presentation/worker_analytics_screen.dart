import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_widget.dart';

final workerAnalyticsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  
  final workers = await db.query('workers');
  final List<Map<String, dynamic>> list = [];

  for (final w in workers) {
    final wid = w['id'] as String;
    final wname = w['name'] as String? ?? 'Worker';
    final empId = w['employee_id'] as String? ?? '';
    final commType = w['commission_type'] as String? ?? 'pct_order';
    final commVal = (w['commission_value'] as num?)?.toDouble() ?? 5.0;
    final monthlyTarget = (w['monthly_target'] as num?)?.toDouble() ?? 50000.0;

    // Fetch order totals for this worker safely
    final orderRes = await db.rawQuery('''
      SELECT COALESCE(SUM(o.grand_total), 0) as total_sales, COUNT(o.id) as order_count 
      FROM orders o
      LEFT JOIN customers c ON o.customer_id = c.id
      WHERE c.assigned_worker_id = ? OR o.id IN (
        SELECT entity_id FROM worker_assignments WHERE worker_id = ? AND entity_type = 'order'
      )
    ''', [wid, wid]);
    
    final totalSales = (orderRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final orderCount = (orderRes.first['order_count'] as num?)?.toInt() ?? 0;

    // Fetch payment totals (Cash vs Online) safely
    final cashRes = await db.rawQuery('''
      SELECT COALESCE(SUM(p.amount), 0) as sum 
      FROM payments p
      JOIN orders o ON p.order_id = o.id
      JOIN customers c ON o.customer_id = c.id
      WHERE (c.assigned_worker_id = ? OR o.id IN (
        SELECT entity_id FROM worker_assignments WHERE worker_id = ? AND entity_type = 'order'
      )) AND LOWER(p.method) = 'cash'
    ''', [wid, wid]);

    final onlineRes = await db.rawQuery('''
      SELECT COALESCE(SUM(p.amount), 0) as sum 
      FROM payments p
      JOIN orders o ON p.order_id = o.id
      JOIN customers c ON o.customer_id = c.id
      WHERE (c.assigned_worker_id = ? OR o.id IN (
        SELECT entity_id FROM worker_assignments WHERE worker_id = ? AND entity_type = 'order'
      )) AND LOWER(p.method) != 'cash'
    ''', [wid, wid]);

    final cashColl = (cashRes.first['sum'] as num?)?.toDouble() ?? 0.0;
    final onlineColl = (onlineRes.first['sum'] as num?)?.toDouble() ?? 0.0;
    final totalColl = cashColl + onlineColl;

    // Fetch areas added
    final areaRes = await db.rawQuery(
      'SELECT COUNT(id) as count FROM areas WHERE assigned_worker_id = ? OR created_by = ? OR worker_name = ?',
      [wid, wid, wname],
    );
    final areasAdded = (areaRes.first['count'] as num?)?.toInt() ?? 0;

    // Fetch streets added
    final streetRes = await db.rawQuery(
      'SELECT COUNT(id) as count FROM streets WHERE assigned_worker_id = ? OR created_by = ? OR worker_name = ?',
      [wid, wid, wname],
    );
    final streetsAdded = (streetRes.first['count'] as num?)?.toInt() ?? 0;

    // Fetch customer count
    final custRes = await db.rawQuery(
      'SELECT COUNT(id) as count FROM customers WHERE assigned_worker_id = ? OR created_by = ? OR worker_name = ?',
      [wid, wid, wname],
    );
    final customerCount = (custRes.first['count'] as num?)?.toInt() ?? 0;

    // Fetch expenses added
    final expRes = await db.rawQuery(
      'SELECT COUNT(id) as count, COALESCE(SUM(amount), 0) as total FROM expenses WHERE assigned_worker_id = ? OR created_by = ? OR worker_name = ?',
      [wid, wid, wname],
    );
    final expensesCount = (expRes.first['count'] as num?)?.toInt() ?? 0;
    final totalExpenses = (expRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // Fetch photos uploaded count
    final photosRes = await db.rawQuery(
      'SELECT COUNT(id) as count FROM customers WHERE (assigned_worker_id = ? OR created_by = ? OR worker_name = ?) AND photo_path != ""',
      [wid, wid, wname],
    );
    final photosUploaded = (photosRes.first['count'] as num?)?.toInt() ?? 0;

    // Calculate commission
    double commEarned = 0.0;
    if (commType == 'fixed') {
      commEarned = orderCount * commVal;
    } else {
      commEarned = (totalSales * commVal) / 100.0;
    }

    final double target = monthlyTarget > 0 ? monthlyTarget : 50000.0;
    final targetPct = (totalColl / target).clamp(0.0, 1.0);

    list.add({
      'id': wid,
      'name': wname,
      'employee_id': empId,
      'total_sales': totalSales,
      'order_count': orderCount,
      'cash_collected': cashColl,
      'online_collected': onlineColl,
      'total_collected': totalColl,
      'customer_count': customerCount,
      'areas_added': areasAdded,
      'streets_added': streetsAdded,
      'expenses_count': expensesCount,
      'total_expenses': totalExpenses,
      'photos_uploaded': photosUploaded,
      'commission_earned': commEarned,
      'target_pct': targetPct,
      'monthly_target': target,
    });
  }

  list.sort((a, b) => (b['total_collected'] as double).compareTo(a['total_collected'] as double));
  return list;
});

class WorkerAnalyticsScreen extends ConsumerWidget {
  const WorkerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(workerAnalyticsProvider);

    return AppScaffold(
      title: 'Worker Analytics & Performance',
      body: analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error loading analytics: $err')),
        data: (workers) {
          if (workers.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.analytics_outlined,
              title: 'No Worker Performance Data',
              subtitle: 'Add workers and import sync packages to view performance leaderboards.',
            );
          }

          final topWorker = workers.first;
          final lowestWorker = workers.length > 1 ? workers.last : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- LEADERBOARD HIGHLIGHT CARDS ---
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.successSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.success.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.emoji_events_rounded, color: AppColors.success, size: 20),
                                SizedBox(width: 6),
                                Text('TOP PERFORMER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.success)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(topWorker['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            Text('Collected: ${AppFormatters.currency(topWorker['total_collected'] as double)}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                    if (lowestWorker != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.errorSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.error.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.trending_down_rounded, color: AppColors.error, size: 20),
                                  SizedBox(width: 6),
                                  Text('NEEDS SUPPORT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.error)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(lowestWorker['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              Text('Collected: ${AppFormatters.currency(lowestWorker['total_collected'] as double)}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                const Text('Worker Performance Breakdown', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: workers.length,
                  itemBuilder: (ctx, idx) {
                    final w = workers[idx];
                    final rank = idx + 1;
                    final targetPct = w['target_pct'] as double;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.gray200),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: rank == 1 ? Colors.amber.shade100 : AppColors.primarySurface,
                                child: Text('#$rank',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: rank == 1 ? Colors.amber.shade900 : AppColors.primary,
                                    )),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(w['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                    if ((w['employee_id'] as String).isNotEmpty)
                                      Text('ID: ${w['employee_id']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(AppFormatters.currency(w['total_collected'] as double),
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary)),
                                  const Text('Total Collection', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Target Progress Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Target Progress', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              Text('${(targetPct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.success)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: targetPct,
                              minHeight: 6,
                              backgroundColor: AppColors.gray200,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Breakdown Metrics Row 1: Sales & Financials
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _subStat('Sales', AppFormatters.currency(w['total_sales'] as double)),
                              _subStat('Cash', AppFormatters.currency(w['cash_collected'] as double)),
                              _subStat('Online', AppFormatters.currency(w['online_collected'] as double)),
                              _subStat('Commission', AppFormatters.currency(w['commission_earned'] as double)),
                            ],
                          ),
                          const Divider(height: 16),
                          // Breakdown Metrics Row 2: Ownership Activity
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _subStat('Areas', '${w['areas_added']}'),
                              _subStat('Streets', '${w['streets_added']}'),
                              _subStat('Customers', '${w['customer_count']}'),
                              _subStat('Expenses', AppFormatters.currency(w['total_expenses'] as double)),
                              _subStat('Photos', '${w['photos_uploaded']}'),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _subStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
      ],
    );
  }
}
