// lib/features/worker/presentation/worker_control_panel_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/worker_package_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/export_filename_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';

import '../domain/worker.dart';
import '../data/worker_dao.dart';
import 'dialogs/worker_package_summary_dialog.dart';
import 'dialogs/add_edit_worker_dialog.dart';
import 'worker_provider.dart';

class WorkerControlPanelScreen extends ConsumerStatefulWidget {
  final Worker worker;

  const WorkerControlPanelScreen({super.key, required this.worker});

  @override
  ConsumerState<WorkerControlPanelScreen> createState() =>
      _WorkerControlPanelScreenState();
}

class _WorkerControlPanelScreenState
    extends ConsumerState<WorkerControlPanelScreen>
    with SingleTickerProviderStateMixin {
  final _dao = WorkerDao();
  late TabController _tabController;
  late Worker _currentWorker;
  bool _loading = true;
  String _lastSyncTime = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    final freshWorker =
        await _dao.getWorkerById(widget.worker.id) ?? widget.worker;

    // Fetch last sync from sync_history for this worker
    final db = await DatabaseHelper.instance.database;
    final syncRows = await db.query(
      'sync_history',
      columns: ['sync_date'],
      where: 'worker_id = ?',
      whereArgs: [widget.worker.id],
      orderBy: 'sync_date DESC',
      limit: 1,
    );
    final String lastSync =
        syncRows.isNotEmpty ? (syncRows.first['sync_date'] as String) : '';

    if (mounted) {
      setState(() {
        _currentWorker = freshWorker;
        _lastSyncTime = lastSync;
        _loading = false;
      });
    }
  }

  // ── PRE-EXPORT VALIDATION & PACKAGE SUMMARY MODAL ─────────────────────────
  Future<void> _triggerPackageSummary() async {
    AppHaptics.buttonClick();

    final db = await DatabaseHelper.instance.database;
    final int areasCount = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM locations WHERE location_kind = 'area' AND is_archived = 0")) ??
        0;
    final int streetsCount = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM locations WHERE location_kind = 'road' AND is_archived = 0")) ??
        0;
    final int customersCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM customers')) ??
        0;
    final int categoriesCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(DISTINCT category) FROM items')) ??
        0;
    final int itemsCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM items')) ??
        0;
    final int routesCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM visits')) ??
        0;

    final double sizeEstimateMb =
        0.5 + (customersCount * 0.01) + (itemsCount * 0.005);

    if (!mounted) return;

    WorkerPackageSummaryDialog.show(
      context,
      worker: _currentWorker,
      areasCount: areasCount,
      streetsCount: streetsCount,
      customersCount: customersCount,
      categoriesCount: categoriesCount,
      itemsCount: itemsCount,
      routesCount: routesCount,
      estimatedSizeMb: sizeEstimateMb,
      onConfirmExport: _executePackageExport,
    );
  }

  Future<void> _executePackageExport() async {
    SnackbarHelper.showInfo(context, 'Generating WorkerPackage.orderkart...');
    try {
      await WorkerPackageService.generateWorkerProvisioningPackage(
        workerId: _currentWorker.id,
        workerName: _currentWorker.name,
      );
      await _loadData();
      if (mounted) {
        SnackbarHelper.showSuccess(
            context, 'WorkerPackage.orderkart generated & ready to share!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Package Export Failed: $e');
      }
    }
  }

  Future<void> _editWorker() async {
    AppHaptics.buttonClick();
    final updatedWorker =
        await AddEditWorkerDialog.show(context, worker: _currentWorker);
    if (updatedWorker != null) {
      await ref.read(workerListProvider.notifier).update(updatedWorker);
      setState(() {
        _currentWorker = updatedWorker;
      });
      if (mounted) {
        SnackbarHelper.showSuccess(
            context, 'Worker details updated successfully');
      }
    }
  }

  Future<void> _toggleWorkerStatus() async {
    AppHaptics.buttonClick();
    final newStatus =
        _currentWorker.status == 'active' ? 'suspended' : 'active';
    final updated = _currentWorker.copyWith(status: newStatus);
    await ref.read(workerListProvider.notifier).update(updated);
    setState(() => _currentWorker = updated);
    SnackbarHelper.showSuccess(
        context, 'Worker status changed to ${newStatus.toUpperCase()}');
  }

  Future<void> _exportWorkerContactsToPhone() async {
    AppHaptics.buttonClick();
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'customers',
      where: 'assigned_worker_id = ? OR created_by = ?',
      whereArgs: [_currentWorker.id, _currentWorker.id],
      orderBy: 'name ASC',
    );

    if (rows.isEmpty) {
      if (mounted)
        SnackbarHelper.showInfo(context,
            'No customers found for ${_currentWorker.name} to export.');
      return;
    }

    final defaultName = 'Contacts_${_currentWorker.name.replaceAll(' ', '_')}';
    final customName = await ExportFilenameDialog.show(
      context,
      defaultName: defaultName,
      extension: '.vcf',
      title: 'Export Worker Contacts to Phone',
    );
    if (customName == null) return;

    final buffer = StringBuffer();
    for (final row in rows) {
      final name = row['name']?.toString() ?? 'Customer';
      final phone =
          row['phone1']?.toString() ?? row['phone2']?.toString() ?? '';
      if (phone.isEmpty) continue;

      buffer.writeln('BEGIN:VCARD');
      buffer.writeln('VERSION:3.0');
      buffer.writeln('FN:$name');
      buffer.writeln('TEL;TYPE=CELL:$phone');
      if ((row['address']?.toString() ?? '').isNotEmpty) {
        buffer.writeln('ADR:;;${row['address']};;;;');
      }
      buffer.writeln('END:VCARD');
      buffer.writeln();
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$customName');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Exported ${rows.length} contacts for ${_currentWorker.name}',
      subject: 'Worker Contacts Export',
    );

    if (mounted) {
      SnackbarHelper.showSuccess(
          context, '✅ ${rows.length} contacts exported for phone saving!');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Worker Profile',
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return AppScaffold(
      title: _currentWorker.name,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_rounded),
          tooltip: 'Edit Worker Profile',
          onPressed: _editWorker,
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: Colors.transparent,
        indicator: AppColors.tabDecoration(context),
        tabs: const [
          Tab(text: 'Overview', icon: Icon(Icons.person_rounded, size: 20)),
          Tab(text: 'Stats', icon: Icon(Icons.analytics_rounded, size: 20)),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildStatsTab(),
        ],
      ),
    );
  }

  // ── TAB 1: WORKER OVERVIEW CARD (Everything at a glance) ──────────────────
  Widget _buildOverviewTab() {
    final bool isOutdated = _currentWorker.isPackageOutdated;
    final bool hasPackage = _currentWorker.packageVersion > 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- WORKER INFORMATION CARD (Top) ---
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.gray200),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: _currentWorker.status == 'active'
                        ? AppColors.primarySurface
                        : AppColors.gray300,
                    child: Text(
                      _currentWorker.name.isNotEmpty
                          ? _currentWorker.name[0].toUpperCase()
                          : 'W',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: _currentWorker.status == 'active'
                            ? AppColors.primary
                            : AppColors.gray600,
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
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Phone: ${_currentWorker.phone.isEmpty ? '—' : _currentWorker.phone}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Emp ID: ${_currentWorker.employeeId.isEmpty ? _currentWorker.id.substring(0, 8) : _currentWorker.employeeId}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _currentWorker.status == 'active'
                          ? AppColors.successSurface
                          : AppColors.gray200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _currentWorker.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _currentWorker.status == 'active'
                            ? AppColors.success
                            : AppColors.gray600,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Overview Grid Details
              Row(
                children: [
                  _overviewMetric(
                      'Package Ver',
                      hasPackage
                          ? 'v${_currentWorker.packageVersion}'
                          : 'v0 (None)'),
                  _overviewMetric(
                      'Status', _currentWorker.status.toUpperCase()),
                  _overviewMetric('Device', '📲 Bound'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _overviewMetric('Commission',
                      '${_currentWorker.commissionValue}% (${_currentWorker.commissionType.name})'),
                  _overviewMetric(
                      'Last Sync',
                      _lastSyncTime.isEmpty
                          ? 'Never'
                          : AppFormatters.relativeDate(
                              DateTime.tryParse(_lastSyncTime) ??
                                  DateTime.now())),
                  _overviewMetric(
                      'Last Generated',
                      _currentWorker.lastPackageGenerated.isEmpty
                          ? 'Never'
                          : AppFormatters.shortDate(DateTime.tryParse(
                                  _currentWorker.lastPackageGenerated) ??
                              DateTime.now())),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- PACKAGE STATUS BANNER ---
        _buildPackageStatusBanner(),
        const SizedBox(height: 20),

        // --- QUICK ACTIONS ---
        _sectionTitle('Quick Actions'),
        _card([
          _actionTile(
            title: isOutdated
                ? 'Regenerate Worker Package'
                : 'Generate & Export Package',
            icon: Icons.cloud_upload_rounded,
            color: isOutdated ? Colors.deepOrange : AppColors.primary,
            onTap: _triggerPackageSummary,
          ),
          const Divider(height: 1),
          _actionTile(
            title: 'Export Worker Customers to Phone (.vcf)',
            subtitle:
                'Save new customer names & phone numbers directly to phone contacts',
            icon: Icons.contacts_rounded,
            color: Colors.teal,
            onTap: _exportWorkerContactsToPhone,
          ),
          const Divider(height: 1),
          _actionTile(
            title: _currentWorker.status == 'active'
                ? 'Suspend Worker Account'
                : 'Activate Worker Account',
            icon: _currentWorker.status == 'active'
                ? Icons.pause_circle_outline_rounded
                : Icons.play_circle_outline_rounded,
            color: _currentWorker.status == 'active'
                ? Colors.red
                : AppColors.success,
            onTap: _toggleWorkerStatus,
          ),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── TAB 2: COMPLETE WORKER ASSIGNMENT SYSTEM (8 Cards) ────────────────────

  // ── TAB 3: STATS & SYNC PROVENANCE TAB ────────────────────────────────────
  Future<Map<String, dynamic>> _fetchWorkerStats() async {
    final db = await DatabaseHelper.instance.database;

    final List<Map<String, dynamic>> ordersRows = await db.query(
      'orders',
      where: 'assigned_worker_id = ?',
      whereArgs: [_currentWorker.id],
      orderBy: 'created_at DESC',
    );

    double totalSales = 0.0;
    double totalCommission = 0.0;
    final List<Map<String, dynamic>> processedOrders = [];

    for (final row in ordersRows) {
      final grandTotal = (row['grand_total'] as num?)?.toDouble() ?? 0.0;
      final commRate = (row['commission_rate'] as num?)?.toDouble() ?? 0.0;
      final commType = row['commission_type']?.toString() ?? 'pct_order';
      final orderId = row['id']?.toString() ?? '';
      final createdAtStr = row['created_at']?.toString() ?? '';

      double commAmount = 0.0;
      if (commType == 'fixed_order') {
        commAmount = commRate;
      } else {
        commAmount = grandTotal * (commRate / 100.0);
      }

      totalSales += grandTotal;
      totalCommission += commAmount;

      processedOrders.add({
        'id': orderId,
        'grand_total': grandTotal,
        'commission': commAmount,
        'created_at': createdAtStr,
      });
    }

    final List<Map<String, dynamic>> workersRows = await db.query('workers');
    final List<Map<String, dynamic>> workerComparisons = [];

    for (final wRow in workersRows) {
      final wId = wRow['id']?.toString() ?? '';
      final wName = wRow['name']?.toString() ?? '';

      final List<Map<String, dynamic>> wOrders = await db.query(
        'orders',
        columns: ['grand_total', 'commission_rate', 'commission_type'],
        where: 'assigned_worker_id = ?',
        whereArgs: [wId],
      );

      double wSales = 0.0;
      double wComm = 0.0;
      for (final o in wOrders) {
        final total = (o['grand_total'] as num?)?.toDouble() ?? 0.0;
        final rate = (o['commission_rate'] as num?)?.toDouble() ?? 0.0;
        final type = o['commission_type']?.toString() ?? 'pct_order';

        if (type == 'fixed_order') {
          wComm += rate;
        } else {
          wComm += total * (rate / 100.0);
        }
        wSales += total;
      }

      workerComparisons.add({
        'name': wName,
        'id': wId,
        'total_sales': wSales,
        'total_commission': wComm,
        'orders_count': wOrders.length,
      });
    }

    workerComparisons.sort((a, b) =>
        (b['total_sales'] as double).compareTo(a['total_sales'] as double));

    return {
      'orders': processedOrders,
      'total_sales': totalSales,
      'total_commission': totalCommission,
      'comparisons': workerComparisons,
    };
  }

  // ── TAB 2: STATS & COMMISSION DASHBOARD ────────────────────────────────────
  Widget _buildStatsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchWorkerStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading stats: ${snapshot.error}'));
        }

        final data = snapshot.data ?? {};
        final ordersList = data['orders'] as List<Map<String, dynamic>>? ?? [];
        final double totalSales = data['total_sales'] as double? ?? 0.0;
        final double totalCommission =
            data['total_commission'] as double? ?? 0.0;
        final comparisons =
            data['comparisons'] as List<Map<String, dynamic>>? ?? [];

        final double avgOrder =
            ordersList.isNotEmpty ? totalSales / ordersList.length : 0.0;
        final double maxSales = comparisons.isNotEmpty
            ? comparisons.first['total_sales'] as double
            : 1.0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('Performance Summary'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.gray200),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _kpiItem('Total Orders', '${ordersList.length}',
                          Colors.purple),
                      _kpiItem(
                          'Total Sales',
                          AppFormatters.currency(totalSales),
                          AppColors.success),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _kpiItem(
                          'Commission Earned',
                          AppFormatters.currency(totalCommission),
                          Colors.orange),
                      _kpiItem('Avg Order Value',
                          AppFormatters.currency(avgOrder), AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Worker Comparisons & Leaderboard'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.gray200),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < comparisons.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _workerComparisonRow(
                      rank: i + 1,
                      comparison: comparisons[i],
                      maxSales: maxSales,
                      isCurrent: comparisons[i]['id'] == _currentWorker.id,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Order & Commission Breakdown'),
            if (ordersList.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: const Center(
                  child: Text(
                    'No orders processed by this worker yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.gray200),
                  boxShadow: AppColors.cardShadow,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ordersList.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final o = ordersList[index];
                    final dateStr = o['created_at'] != null
                        ? AppFormatters.dateTimeFromString(o['created_at'])
                        : 'Unknown Date';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      title: Text(
                        'Order #${o['id']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        dateStr,
                        style: const TextStyle(
                            color: AppColors.textHint, fontSize: 11),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppFormatters.currency(o['grand_total']),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Comm: ${AppFormatters.currency(o['commission'])}',
                            style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w700,
                                fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _kpiItem(String title, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textHint),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _workerComparisonRow({
    required int rank,
    required Map<String, dynamic> comparison,
    required double maxSales,
    required bool isCurrent,
  }) {
    final double sales = comparison['total_sales'] as double;
    final double commission = comparison['total_commission'] as double;
    final int orders = comparison['orders_count'] as int;
    final String name = comparison['name'] as String;

    final double ratio =
        maxSales > 0 ? (sales / maxSales).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFFFFD700).withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFFFFD700).withOpacity(0.4)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color:
                      isCurrent ? const Color(0xFFFFD700) : AppColors.gray200,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCurrent
                        ? const Color(0xFF0F172A)
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isCurrent ? '$name (Current)' : name,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.bold,
                    color: isCurrent
                        ? const Color(0xFFB45309)
                        : AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                AppFormatters.currency(sales),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: AppColors.gray100,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCurrent
                    ? const Color(0xFFFFD700)
                    : AppColors.primary.withOpacity(0.7),
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$orders Orders Handled',
                style: const TextStyle(color: AppColors.textHint, fontSize: 11),
              ),
              Text(
                'Comm: ${AppFormatters.currency(commission)}',
                style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── HELPER WIDGETS ────────────────────────────────────────────────────────
  Widget _buildPackageStatusBanner() {
    final bool isOutdated = _currentWorker.isPackageOutdated;
    final bool hasPackage = _currentWorker.packageVersion > 0 &&
        _currentWorker.lastPackageGenerated.isNotEmpty;

    Color bg;
    Color border;
    IconData icon;
    String title;
    String subtitle;

    if (!hasPackage) {
      bg = AppColors.errorSurface;
      border = AppColors.error;
      icon = Icons.cancel_rounded;
      title = 'Package Status: ❌ Not Generated';
      subtitle =
          'Assignments have not been compiled into a Worker Package yet.';
    } else if (isOutdated) {
      bg = Colors.amber.shade50;
      border = Colors.amber.shade800;
      icon = Icons.warning_amber_rounded;
      title = 'Package Status: ⚠️ Worker Package Outdated';
      subtitle = 'Assignments modified! Regenerate package before sharing.';
    } else {
      bg = AppColors.successSurface;
      border = AppColors.success;
      icon = Icons.check_circle_rounded;
      title =
          'Package Status: ✅ Up-to-Date (v${_currentWorker.packageVersion})';
      subtitle =
          'Last generated on ${AppFormatters.dateTimeFromString(_currentWorker.lastPackageGenerated)}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: border, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13, color: border),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          if (isOutdated || !hasPackage)
            ElevatedButton(
              onPressed: _triggerPackageSummary,
              style: ElevatedButton.styleFrom(
                backgroundColor: border,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Generate',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Widget _overviewMetric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: AppColors.primary),
      ),
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

  Widget _actionTile({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(title,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textSecondary))
          : null,
      trailing: const Icon(Icons.chevron_right_rounded,
          size: 18, color: AppColors.gray400),
      onTap: onTap,
    );
  }
}
