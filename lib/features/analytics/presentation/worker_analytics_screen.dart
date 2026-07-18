import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/customer_avatar.dart';
import '../../../core/services/worker_session.dart';
import '../../../core/security/app_mode_service.dart';

// --- PROVIDERS ---

/// Fetch all workers summary (leaderboard data for Owner)
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
      WHERE o.assigned_worker_id = ? OR o.created_by = ? OR o.worker_id = ? OR c.assigned_worker_id = ? OR o.id IN (
        SELECT entity_id FROM worker_assignments WHERE worker_id = ? AND entity_type = 'order'
      )
    ''', [wid, wid, wid, wid, wid]);
    
    final totalSales = (orderRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final orderCount = (orderRes.first['order_count'] as num?)?.toInt() ?? 0;

    // Fetch payment totals (Cash vs Online) safely
    final cashRes = await db.rawQuery('''
      SELECT COALESCE(SUM(p.amount), 0) as sum 
      FROM payments p
      JOIN orders o ON p.order_id = o.id
      LEFT JOIN customers c ON o.customer_id = c.id
      WHERE (o.assigned_worker_id = ? OR o.created_by = ? OR o.worker_id = ? OR 
             c.assigned_worker_id = ? OR o.id IN (
               SELECT entity_id FROM worker_assignments WHERE worker_id = ? AND entity_type = 'order'
             )) AND LOWER(p.method) = 'cash'
    ''', [wid, wid, wid, wid, wid]);

    final onlineRes = await db.rawQuery('''
      SELECT COALESCE(SUM(p.amount), 0) as sum 
      FROM payments p
      JOIN orders o ON p.order_id = o.id
      LEFT JOIN customers c ON o.customer_id = c.id
      WHERE (o.assigned_worker_id = ? OR o.created_by = ? OR o.worker_id = ? OR 
             c.assigned_worker_id = ? OR o.id IN (
               SELECT entity_id FROM worker_assignments WHERE worker_id = ? AND entity_type = 'order'
             )) AND LOWER(p.method) != 'cash'
    ''', [wid, wid, wid, wid, wid]);

    final cashColl = (cashRes.first['sum'] as num?)?.toDouble() ?? 0.0;
    final onlineColl = (onlineRes.first['sum'] as num?)?.toDouble() ?? 0.0;
    final totalColl = cashColl + onlineColl;

    // Fetch areas added
    final areaRes = await db.rawQuery(
      "SELECT COUNT(id) as count FROM locations WHERE location_kind = 'area' AND (assigned_worker_id = ? OR created_by = ? OR worker_name = ?)",
      [wid, wid, wname],
    );
    final areasAdded = (areaRes.first['count'] as num?)?.toInt() ?? 0;

    // Fetch streets added
    final streetRes = await db.rawQuery(
      "SELECT COUNT(id) as count FROM locations WHERE location_kind = 'road' AND (assigned_worker_id = ? OR created_by = ? OR worker_name = ?)",
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

/// Fetch detailed metrics for a single worker (Personal Stats)
final singleWorkerStatsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, workerId) async {
  final db = await DatabaseHelper.instance.database;
  
  final workerRows = await db.query('workers', where: 'id = ?', whereArgs: [workerId]);
  if (workerRows.isEmpty) return {};
  final w = workerRows.first;
  final wname = w['name'] as String? ?? 'Worker';
  final commType = w['commission_type'] as String? ?? 'pct_order';
  final commVal = (w['commission_value'] as num?)?.toDouble() ?? 5.0;
  final monthlyTarget = (w['monthly_target'] as num?)?.toDouble() ?? 50000.0;

  // Sales and orders
  final salesRes = await db.rawQuery('''
    SELECT COALESCE(SUM(grand_total), 0) as total_sales, COUNT(id) as order_count 
    FROM orders 
    WHERE assigned_worker_id = ? OR created_by = ?
  ''', [workerId, workerId]);
  final totalSales = (salesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;
  final orderCount = (salesRes.first['order_count'] as num?)?.toInt() ?? 0;

  final now = DateTime.now();
  final todayStr = DateTime(now.year, now.month, now.day).toIso8601String();
  final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

  final todaySalesRes = await db.rawQuery('''
    SELECT COALESCE(SUM(grand_total), 0) as total_sales 
    FROM orders 
    WHERE DATE(created_at) = DATE(?) AND (assigned_worker_id = ? OR created_by = ?)
  ''', [todayStr, workerId, workerId]);
  final todaySales = (todaySalesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;

  final monthlySalesRes = await db.rawQuery('''
    SELECT COALESCE(SUM(grand_total), 0) as total_sales 
    FROM orders 
    WHERE strftime('%Y-%m', created_at) = ? AND (assigned_worker_id = ? OR created_by = ?)
  ''', [monthStr, workerId, workerId]);
  final monthlySales = (monthlySalesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;

  final duesRes = await db.rawQuery('''
    SELECT COALESCE(SUM(remaining_amount), 0) as pending_dues 
    FROM orders 
    WHERE remaining_amount > 0 AND (assigned_worker_id = ? OR created_by = ?)
  ''', [workerId, workerId]);
  final pendingDues = (duesRes.first['pending_dues'] as num?)?.toDouble() ?? 0.0;

  // Collections (Cash vs Online)
  final cashRes = await db.rawQuery('''
    SELECT COALESCE(SUM(p.amount), 0) as sum 
    FROM payments p
    JOIN orders o ON p.order_id = o.id
    WHERE (o.assigned_worker_id = ? OR o.created_by = ?) AND LOWER(p.method) = 'cash'
  ''', [workerId, workerId]);
  final cashColl = (cashRes.first['sum'] as num?)?.toDouble() ?? 0.0;

  final onlineRes = await db.rawQuery('''
    SELECT COALESCE(SUM(p.amount), 0) as sum 
    FROM payments p
    JOIN orders o ON p.order_id = o.id
    WHERE (o.assigned_worker_id = ? OR o.created_by = ?) AND LOWER(p.method) != 'cash'
  ''', [workerId, workerId]);
  final onlineColl = (onlineRes.first['sum'] as num?)?.toDouble() ?? 0.0;
  final totalColl = cashColl + onlineColl;

  // Expenses
  final expRes = await db.rawQuery('''
    SELECT COALESCE(SUM(amount), 0) as total, COUNT(id) as count 
    FROM expenses 
    WHERE assigned_worker_id = ? OR created_by = ?
  ''', [workerId, workerId]);
  final totalExpenses = (expRes.first['total'] as num?)?.toDouble() ?? 0.0;
  final expensesCount = (expRes.first['count'] as num?)?.toInt() ?? 0;

  // Territories and notes
  final areaRes = await db.rawQuery("SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = 'area'", [workerId]);
  final areasCount = (areaRes.first['v'] as num?)?.toInt() ?? 0;

  final streetRes = await db.rawQuery("SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = 'street'", [workerId]);
  final streetsCount = (streetRes.first['v'] as num?)?.toInt() ?? 0;

  final custRes = await db.rawQuery('''
    SELECT COUNT(id) as count 
    FROM customers 
    WHERE assigned_worker_id = ? OR created_by = ? OR id IN (SELECT entity_id FROM worker_assignments WHERE worker_id = ? AND entity_type = 'customer')
  ''', [workerId, workerId, workerId]);
  final customerCount = (custRes.first['count'] as num?)?.toInt() ?? 0;

  final noteRes = await db.rawQuery('SELECT COUNT(*) as v FROM notes WHERE worker_id = ?', [workerId]);
  final notesCount = (noteRes.first['v'] as num?)?.toInt() ?? 0;

  final photosRes = await db.rawQuery('''
    SELECT COUNT(id) as count 
    FROM customers 
    WHERE (assigned_worker_id = ? OR created_by = ?) AND photo_path != ""
  ''', [workerId, workerId]);
  final photosUploaded = (photosRes.first['count'] as num?)?.toInt() ?? 0;

  // Commission
  double commEarned = 0.0;
  if (commType == 'fixed') {
    commEarned = orderCount * commVal;
  } else {
    commEarned = (totalSales * commVal) / 100.0;
  }

  // Delivery status distribution
  final deliveredRes = await db.rawQuery("SELECT COUNT(*) as v FROM orders WHERE delivery_status = 'delivered' AND (assigned_worker_id = ? OR created_by = ?)", [workerId, workerId]);
  final deliveredCount = (deliveredRes.first['v'] as num?)?.toInt() ?? 0;

  final pendingRes = await db.rawQuery("SELECT COUNT(*) as v FROM orders WHERE delivery_status = 'pending' AND (assigned_worker_id = ? OR created_by = ?)", [workerId, workerId]);
  final pendingCount = (pendingRes.first['v'] as num?)?.toInt() ?? 0;

  final cancelledRes = await db.rawQuery("SELECT COUNT(*) as v FROM orders WHERE delivery_status = 'cancelled' AND (assigned_worker_id = ? OR created_by = ?)", [workerId, workerId]);
  final cancelledCount = (cancelledRes.first['v'] as num?)?.toInt() ?? 0;

  // Weekly Trend
  final weeklySales = await db.rawQuery('''
    SELECT DATE(created_at) AS day, COALESCE(SUM(grand_total), 0) AS total
    FROM orders
    WHERE created_at >= datetime('now', '-7 days') AND (assigned_worker_id = ? OR created_by = ?)
    GROUP BY DATE(created_at)
    ORDER BY day ASC
  ''', [workerId, workerId]);

  // Top Items sold by this worker
  final topItems = await db.rawQuery('''
    SELECT item_name, SUM(total_price) AS revenue, SUM(quantity) AS qty
    FROM order_items
    WHERE order_id IN (SELECT id FROM orders WHERE assigned_worker_id = ? OR created_by = ?)
    GROUP BY item_name
    ORDER BY revenue DESC
    LIMIT 5
  ''', [workerId, workerId]);

  // Top Customers served by this worker
  final topCustomers = await db.rawQuery('''
    SELECT c.name, c.photo_path, COUNT(o.id) as total_orders, SUM(o.grand_total) as total_purchase, SUM(o.remaining_amount) as pending_amount
    FROM orders o
    JOIN customers c ON o.customer_id = c.id
    WHERE o.assigned_worker_id = ? OR o.created_by = ?
    GROUP BY c.id
    ORDER BY total_purchase DESC
    LIMIT 5
  ''', [workerId, workerId]);

  final targetPct = monthlyTarget > 0 ? (totalColl / monthlyTarget).clamp(0.0, 1.0) : 0.0;

  return {
    'id': workerId,
    'name': wname,
    'employee_id': w['employee_id'] ?? '',
    'phone': w['phone'] ?? '',
    'today_sales': todaySales,
    'monthly_sales': monthlySales,
    'total_sales': totalSales,
    'order_count': orderCount,
    'cash_collected': cashColl,
    'online_collected': onlineColl,
    'total_collected': totalColl,
    'total_expenses': totalExpenses,
    'expenses_count': expensesCount,
    'areas_count': areasCount,
    'streets_count': streetsCount,
    'customer_count': customerCount,
    'notes_count': notesCount,
    'photos_uploaded': photosUploaded,
    'commission_earned': commEarned,
    'target_pct': targetPct,
    'monthly_target': monthlyTarget,
    'pending_dues': pendingDues,
    'delivered_count': deliveredCount,
    'pending_count': pendingCount,
    'cancelled_count': cancelledCount,
    'weekly_sales': weeklySales,
    'top_items': topItems,
    'top_customers': topCustomers,
  };
});

// --- WORKER ANALYTICS MAIN SCREEN ---

class WorkerAnalyticsScreen extends ConsumerWidget {
  const WorkerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = AppModeService.isOwnerSessionActive;
    
    if (!isOwner) {
      // ── WORKER MODE: SHOW DIRECT WORKER REPORT & DASHBOARD ──
      final workerId = WorkerSession.instance.currentWorkerId ?? '';
      if (workerId.isEmpty) {
        return const AppScaffold(
          title: 'My Performance Stats',
          body: Center(
            child: Text(
              'No active worker session. Please provision this device first.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
      return AppScaffold(
        title: 'My Performance Stats',
        body: _WorkerStatsDashboard(workerId: workerId),
      );
    }

    // ── OWNER MODE: SHOW WORKER LEADERBOARD & TAP-TO-ZOOM REPORT ──
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

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(workerAnalyticsProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Leaderboard highlight cards
                  Row(
                    children: [
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.success.withOpacity(0.12)
                                    : AppColors.successSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.success.withOpacity(0.4)
                                      : AppColors.success.withOpacity(0.3),
                                ),
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
                                  Text(topWorker['name'] as String,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: isDark ? Colors.white : AppColors.textPrimary)),
                                  Text('Collected: ${AppFormatters.currency(topWorker['total_collected'] as double)}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white70 : AppColors.textSecondary)),
                                ],
                              ),
                            );
                          }
                        ),
                      ),
                      if (lowestWorker != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final isDark = Theme.of(context).brightness == Brightness.dark;
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.error.withOpacity(0.12)
                                      : AppColors.errorSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.error.withOpacity(0.4)
                                        : AppColors.error.withOpacity(0.3),
                                  ),
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
                                    Text(lowestWorker['name'] as String,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: isDark ? Colors.white : AppColors.textPrimary)),
                                    Text('Collected: ${AppFormatters.currency(lowestWorker['total_collected'] as double)}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : AppColors.textSecondary)),
                                  ],
                                ),
                              );
                            }
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Row(
                    children: [
                      Text('Worker Performance Leaderboard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      SizedBox(width: 6),
                      Icon(Icons.touch_app_outlined, color: AppColors.primary, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Tap any worker card below to open their detailed report and charts.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: workers.length,
                    itemBuilder: (ctx, idx) {
                      final w = workers[idx];
                      final rank = idx + 1;
                      final targetPct = w['target_pct'] as double;
                      final String workerId = w['id'] as String;

                      return InkWell(
                        onTap: () {
                          // Tap to zoom into worker stats detailed report via full screen bottom sheet!
                          _showWorkerDetailsSheet(context, workerId, w['name'] as String);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Builder(
                          builder: (context) {
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B).withOpacity(0.55) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : AppColors.gray200),
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

                              // Target progress
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

                              // Small metrics rows
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _subStat('Sales', AppFormatters.currency(w['total_sales'] as double)),
                                  _subStat('Commission', AppFormatters.currency(w['commission_earned'] as double)),
                                  _subStat('Expenses', AppFormatters.currency(w['total_expenses'] as double)),
                                  _subStat('Customers', '${w['customer_count']}'),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    );
                  },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _subStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textHint)),
      ],
    );
  }

  /// Show detailed worker report in a beautiful modal sliding sheet
  void _showWorkerDetailsSheet(BuildContext context, String workerId, String workerName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.88,
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
              child: Column(
                children: [
                  // Handlebar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(color: AppColors.gray300, borderRadius: BorderRadius.circular(10)),
                  ),
                  // Sheet Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$workerName Report', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                              const Text('Detailed analytics and history', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  
                  // Content
                  Expanded(
                    child: _WorkerStatsDashboard(workerId: workerId),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- WORKER STATS DASHBOARD COMPONENT ---

class _WorkerStatsDashboard extends ConsumerWidget {
  final String workerId;

  const _WorkerStatsDashboard({required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statsAsync = ref.watch(singleWorkerStatsProvider(workerId));

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error loading stats: $e')),
      data: (stats) {
        if (stats.isEmpty) {
          return const Center(child: Text('No performance data available.'));
        }

        final double todaySales = stats['today_sales'] ?? 0.0;
        final double monthlySales = stats['monthly_sales'] ?? 0.0;
        final double pendingDues = stats['pending_dues'] ?? 0.0;
        final double totalExpenses = stats['total_expenses'] ?? 0.0;
        final double cashColl = stats['cash_collected'] ?? 0.0;
        final double onlineColl = stats['online_collected'] ?? 0.0;
        final double totalColl = stats['total_collected'] ?? 0.0;
        final double commEarned = stats['commission_earned'] ?? 0.0;
        final double target = stats['monthly_target'] ?? 50000.0;
        final double targetPct = stats['target_pct'] ?? 0.0;
        final int orderCount = stats['order_count'] ?? 0;

        final int deliveredCount = stats['delivered_count'] ?? 0;
        final int pendingCount = stats['pending_count'] ?? 0;
        final int cancelledCount = stats['cancelled_count'] ?? 0;

        final weeklySalesData = stats['weekly_sales'] as List<dynamic>? ?? [];
        final topItems = stats['top_items'] as List<dynamic>? ?? [];
        final topCustomers = stats['top_customers'] as List<dynamic>? ?? [];

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(singleWorkerStatsProvider(workerId));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── KPI GRID (Like Owner App) ──
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: MediaQuery.textScalerOf(context).scale(1.0) > 1.4 ? 0.85 : 1.15,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    StatCard(
                      label: "Today's Sales",
                      value: AppFormatters.currency(todaySales),
                      icon: Icons.today_rounded,
                      color: AppColors.primary,
                    ).animate().scale(delay: 50.ms, duration: 300.ms),
                    StatCard(
                      label: 'This Month',
                      value: AppFormatters.currency(monthlySales),
                      icon: Icons.trending_up_rounded,
                      color: AppColors.success,
                    ).animate().scale(delay: 100.ms, duration: 300.ms),
                    StatCard(
                      label: 'Commission',
                      value: AppFormatters.currency(commEarned),
                      icon: Icons.percent_rounded,
                      color: Colors.amber.shade800,
                    ).animate().scale(delay: 150.ms, duration: 300.ms),
                    StatCard(
                      label: 'Pending Dues',
                      value: AppFormatters.currency(pendingDues),
                      icon: Icons.pending_actions_rounded,
                      color: AppColors.error,
                    ).animate().scale(delay: 200.ms, duration: 300.ms),
                  ],
                ),
                const SizedBox(height: 16),

                // ── MONTHLY GAUGE TARGET CARD ──
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
                              Text(AppFormatters.currency(target), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total Collection', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text(AppFormatters.currency(totalColl), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── SALES TREND LINE CHART (Like Owner App) ──
                Text(
                  'Sales Trend (Last 7 Days)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 220,
                  padding: const EdgeInsets.fromLTRB(8, 16, 24, 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: weeklySalesData.isEmpty
                      ? const Center(child: Text('Not enough sales trend data'))
                      : _buildLineChart(weeklySalesData),
                ),
                const SizedBox(height: 24),

                // ── PAYMENT BREAKDOWN ──
                Text(
                  'Collection Breakdown',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: Column(
                    children: [
                      _paymentSplitRow(
                        context,
                        'Cash Collections',
                        cashColl,
                        totalColl,
                        AppColors.success,
                      ),
                      const SizedBox(height: 14),
                      _paymentSplitRow(
                        context,
                        'Online Collections',
                        onlineColl,
                        totalColl,
                        AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── PERFORMANCE BREAKDOWN ──
                Text(
                  'Performance Breakdown',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: Column(
                    children: [
                      _detailRow('All-Time Sales', AppFormatters.currency(stats['total_sales'] as double)),
                      const Divider(height: 20),
                      _detailRow('Average Order Value (AOV)', 
                          AppFormatters.currency(orderCount > 0 ? ((stats['total_sales'] as double) / orderCount) : 0.0)),
                      const Divider(height: 20),
                      _detailRow('Expenses Logged', AppFormatters.currency(totalExpenses), valueColor: AppColors.error),
                      const Divider(height: 20),
                      _detailRow('Active Customers Served', '${stats['customer_count']}'),
                      const Divider(height: 20),
                      _detailRow('Assigned Areas/Streets', '${stats['areas_count']} / ${stats['streets_count']}'),
                      const Divider(height: 20),
                      _detailRow('Notes Logged', '${stats['notes_count']}'),
                      const Divider(height: 20),
                      _detailRow('Photos Uploaded', '${stats['photos_uploaded']}'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── ORDER STATUS DISTRIBUTION ──
                Text(
                  'Order Status Distribution',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: Column(
                    children: [
                      _paymentSplitRow(
                        context,
                        'Delivered Orders',
                        deliveredCount.toDouble(),
                        orderCount.toDouble(),
                        AppColors.success,
                      ),
                      const SizedBox(height: 14),
                      _paymentSplitRow(
                        context,
                        'Pending Orders',
                        pendingCount.toDouble(),
                        orderCount.toDouble(),
                        AppColors.pending,
                      ),
                      const SizedBox(height: 14),
                      _paymentSplitRow(
                        context,
                        'Cancelled Orders',
                        cancelledCount.toDouble(),
                        orderCount.toDouble(),
                        AppColors.cancelled,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── TOP SELLING ITEMS ──
                Text(
                  'Top Selling Items',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: topItems.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('No items sold yet')),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: topItems.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final it = topItems[i];
                            final String name = it['item_name'] ?? '';
                            final double revenue = (it['revenue'] as num?)?.toDouble() ?? 0;
                            final double qty = (it['qty'] as num?)?.toDouble() ?? 0;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primarySurface,
                                child: Text('${i + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('Sold Qty: ${AppFormatters.quantity(qty)}'),
                              trailing: Text(AppFormatters.currency(revenue),
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 24),

                // ── TOP CUSTOMERS ──
                Text(
                  'Top Customers Served',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: topCustomers.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('No customers served yet')),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: topCustomers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final cust = topCustomers[i];
                            final String name = cust['name'] ?? 'Unknown';
                            final String photo = cust['photo_path'] ?? '';
                            final int orders = cust['total_orders'] ?? 0;
                            final double purchase = (cust['total_purchase'] as num?)?.toDouble() ?? 0;
                            final double pending = (cust['pending_amount'] as num?)?.toDouble() ?? 0;

                            return ListTile(
                              leading: CustomerAvatar(
                                photoPath: photo,
                                radius: 20,
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('Orders: $orders  •  Purchase: ${AppFormatters.currency(purchase)}'),
                              trailing: Text(
                                pending > 0 ? 'Dues: ${AppFormatters.currency(pending)}' : 'Clear',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: pending > 0 ? AppColors.error : AppColors.success,
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLineChart(List<dynamic> data) {
    final List<FlSpot> spots = [];
    final List<String> labels = [];

    for (int i = 0; i < data.length; i++) {
      final total = (data[i]['total'] as num?)?.toDouble() ?? 0.0;
      final String day = data[i]['day'] ?? '';
      spots.add(FlSpot(i.toDouble(), total));
      labels.add(day.length >= 7 ? day.substring(5) : day); // MM-DD
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final int index = val.toInt();
                if (index < 0 || index >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[index],
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: valueColor ?? AppColors.textPrimary)),
      ],
    );
  }

  Widget _paymentSplitRow(BuildContext context, String label, double amount, double total, Color color) {
    final double pct = total > 0 ? (amount / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              total > 0 && amount > 0
                  ? '${label.contains('Orders') ? amount.toInt() : AppFormatters.currency(amount)} (${(pct * 100).toStringAsFixed(0)}%)'
                  : (label.contains('Orders') ? '${amount.toInt()}' : AppFormatters.currency(amount)),
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: AppColors.gray200,
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
