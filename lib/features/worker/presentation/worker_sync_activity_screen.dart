import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/ownership_badge.dart';

class WorkerSyncActivityScreen extends ConsumerStatefulWidget {
  const WorkerSyncActivityScreen({super.key});

  @override
  ConsumerState<WorkerSyncActivityScreen> createState() => _WorkerSyncActivityScreenState();
}

class _WorkerSyncActivityScreenState extends ConsumerState<WorkerSyncActivityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<Map<String, dynamic>> _workerCustomers = [];
  List<Map<String, dynamic>> _workerOrders = [];
  List<Map<String, dynamic>> _workerAreas = [];
  List<Map<String, dynamic>> _workerStreets = [];
  List<Map<String, dynamic>> _importLogs = [];
  List<Map<String, dynamic>> _workers = [];
  String _selectedWorkerId = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final db = await DatabaseHelper.instance.database;

    final workers = await db.query('workers', orderBy: 'name ASC');
    final Map<String, String> workerNameMap = {
      for (final w in workers) w['id']?.toString() ?? '': w['name']?.toString() ?? 'Worker'
    };

    // 1. Worker Customers
    final custRows = await db.query(
      'customers',
      where: 'assigned_worker_id IS NOT NULL AND assigned_worker_id != "" OR created_by != "owner"',
      orderBy: 'created_at DESC',
    );
    final customers = custRows.map((c) {
      final wid = c['assigned_worker_id']?.toString() ?? c['created_by']?.toString() ?? '';
      final wName = (c['worker_name']?.toString() ?? '').isNotEmpty 
          ? c['worker_name']!.toString() 
          : (workerNameMap[wid] ?? 'Worker');
      return {
        ...c,
        'worker_name': wName,
        'worker_id': wid,
      };
    }).toList();

    // 2. Worker Orders
    final orderRows = await db.query(
      'orders',
      where: 'assigned_worker_id IS NOT NULL AND assigned_worker_id != "" OR created_by != "owner"',
      orderBy: 'created_at DESC',
    );
    final orders = orderRows.map((o) {
      final wid = o['assigned_worker_id']?.toString() ?? '';
      final wName = (o['worker_name']?.toString() ?? '').isNotEmpty
          ? o['worker_name']!.toString()
          : (workerNameMap[wid] ?? 'Worker');
      return {
        ...o,
        'worker_name': wName,
        'worker_id': wid,
      };
    }).toList();

    // 3. Worker Areas & Streets
    final areaRows = await db.query(
      'areas',
      where: 'assigned_worker_id IS NOT NULL AND assigned_worker_id != "" OR created_by != "owner"',
      orderBy: 'created_at DESC',
    );
    final areas = areaRows.map((a) {
      final wid = a['assigned_worker_id']?.toString() ?? a['created_by']?.toString() ?? '';
      final wName = (a['worker_name']?.toString() ?? '').isNotEmpty 
          ? a['worker_name']!.toString() 
          : (workerNameMap[wid] ?? 'Worker');
      return {
        ...a,
        'worker_name': wName,
        'worker_id': wid,
      };
    }).toList();

    final streetRows = await db.query(
      'streets',
      where: 'assigned_worker_id IS NOT NULL AND assigned_worker_id != "" OR created_by != "owner"',
      orderBy: 'created_at DESC',
    );
    final streets = streetRows.map((s) {
      final wid = s['assigned_worker_id']?.toString() ?? s['created_by']?.toString() ?? '';
      final wName = (s['worker_name']?.toString() ?? '').isNotEmpty 
          ? s['worker_name']!.toString() 
          : (workerNameMap[wid] ?? 'Worker');
      return {
        ...s,
        'worker_name': wName,
        'worker_id': wid,
      };
    }).toList();

    // 4. Import Logs
    final imports = await db.query('import_history', orderBy: 'imported_at DESC');

    if (mounted) {
      setState(() {
        _workers = workers;
        _workerCustomers = customers;
        _workerOrders = orders;
        _workerAreas = areas;
        _workerStreets = streets;
        _importLogs = imports;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filteredCustomers() {
    if (_selectedWorkerId == 'all') return _workerCustomers;
    return _workerCustomers.where((c) => c['worker_id'] == _selectedWorkerId).toList();
  }

  List<Map<String, dynamic>> _filteredOrders() {
    if (_selectedWorkerId == 'all') return _workerOrders;
    return _workerOrders.where((o) => o['worker_id'] == _selectedWorkerId).toList();
  }

  List<Map<String, dynamic>> _filteredAreas() {
    if (_selectedWorkerId == 'all') return _workerAreas;
    return _workerAreas.where((a) => a['worker_id'] == _selectedWorkerId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Worker Activity & Updates',
      bottom: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Worker Updates Log', icon: Icon(Icons.history_rounded, size: 18)),
          Tab(text: 'Worker Customers', icon: Icon(Icons.people_alt_rounded, size: 18)),
          Tab(text: 'Worker Orders', icon: Icon(Icons.shopping_cart_rounded, size: 18)),
          Tab(text: 'Areas & Streets', icon: Icon(Icons.map_rounded, size: 18)),
        ],
      ),
      body: _loading
          ? const LoadingShimmer()
          : Column(
              children: [
                // Filter Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text('Filter Worker:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.gray100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.gray300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedWorkerId,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(value: 'all', child: Text('All Workers')),
                                ..._workers.map((w) => DropdownMenuItem(
                                      value: w['id']?.toString() ?? '',
                                      child: Text(w['name']?.toString() ?? 'Worker'),
                                    )),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedWorkerId = val);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildImportHistoryList(),
                      _buildCustomersList(),
                      _buildOrdersList(),
                      _buildAreasList(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildImportHistoryList() {
    final logs = _selectedWorkerId == 'all'
        ? _importLogs
        : _importLogs.where((l) => l['worker_id'] == _selectedWorkerId).toList();

    if (logs.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history_rounded,
        title: 'No Worker Updates Imported Yet',
        subtitle: 'When workers export their data packages and you import them into Owner app, detailed sync logs and record stats will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (ctx, i) {
        final imp = logs[i];
        final pkgId = imp['package_id']?.toString() ?? 'Package';
        final wName = imp['worker_name']?.toString() ?? 'Worker';
        final devName = imp['device_name']?.toString() ?? 'Mobile Device';
        final importedAt = DateTime.tryParse(imp['imported_at']?.toString() ?? '') ?? DateTime.now();
        final summaryRaw = imp['summary_json']?.toString() ?? '';
        Map<String, dynamic> summary = {};
        if (summaryRaw.isNotEmpty) {
          try { summary = jsonDecode(summaryRaw); } catch (_) {}
        }

        final recCount = imp['record_count'] as int? ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primarySurface,
              child: const Icon(Icons.download_done_rounded, color: AppColors.primary),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Update from $wName',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                OwnershipBadge(createdBy: 'worker', workerName: wName),
              ],
            ),
            subtitle: Text(
              'Imported: ${AppFormatters.dateTime(importedAt)}\nDevice: $devName • Records: $recCount',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 16),
                    const Text('Imported Data Breakdown:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if ((summary['areas'] ?? 0) > 0)
                          _statChip('🗺️ Areas: ${summary['areas']}'),
                        if ((summary['streets'] ?? 0) > 0)
                          _statChip('🛣️ Streets: ${summary['streets']}'),
                        if ((summary['customers'] ?? 0) > 0)
                          _statChip('👤 Customers: ${summary['customers']}'),
                        if ((summary['orders'] ?? 0) > 0)
                          _statChip('🛒 Orders: ${summary['orders']}'),
                        if ((summary['payments'] ?? 0) > 0)
                          _statChip('💳 Payments: ${summary['payments']}'),
                        if ((summary['expenses'] ?? 0) > 0)
                          _statChip('💸 Expenses: ${summary['expenses']}'),
                        if ((summary['photos'] ?? 0) > 0)
                          _statChip('📷 Photos: ${summary['photos']}'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Package ID: $pkgId', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
    );
  }

  Widget _buildCustomersList() {
    final list = _filteredCustomers();
    if (list.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.people_outline_rounded,
        title: 'No Worker Customers',
        subtitle: 'Customers created or updated by workers will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final c = list[i];
        final name = c['name']?.toString() ?? 'Customer';
        final phone = c['phone1']?.toString() ?? 'No Phone';
        final wName = c['worker_name']?.toString() ?? 'Worker';
        final createdAt = DateTime.tryParse(c['created_at']?.toString() ?? '') ?? DateTime.now();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray200),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primarySurface,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'C', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Phone: $phone • Added on ${AppFormatters.shortDate(createdAt)}'),
            trailing: OwnershipBadge(createdBy: 'worker', workerName: wName),
          ),
        );
      },
    );
  }

  Widget _buildOrdersList() {
    final list = _filteredOrders();
    if (list.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.receipt_long_rounded,
        title: 'No Worker Orders',
        subtitle: 'Orders generated by workers will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final o = list[i];
        final id = o['id']?.toString() ?? '';
        final amount = (o['grand_total'] as num?)?.toDouble() ?? 0.0;
        final wName = o['worker_name']?.toString() ?? 'Worker';
        final createdAt = DateTime.tryParse(o['created_at']?.toString() ?? '') ?? DateTime.now();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray200),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.successSurface,
              child: Icon(Icons.shopping_cart_rounded, color: AppColors.success),
            ),
            title: Text('Order #${id.length > 6 ? id.substring(0, 6) : id} • ${AppFormatters.currency(amount)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Date: ${AppFormatters.shortDate(createdAt)} • Status: ${o['delivery_status']}'),
            trailing: OwnershipBadge(createdBy: 'worker', workerName: wName),
          ),
        );
      },
    );
  }

  Widget _buildAreasList() {
    final areas = _filteredAreas();
    if (areas.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.map_rounded,
        title: 'No Worker Areas / Streets',
        subtitle: 'Areas and streets created by workers will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: areas.length,
      itemBuilder: (ctx, i) {
        final a = areas[i];
        final name = a['name']?.toString() ?? 'Area';
        final wName = a['worker_name']?.toString() ?? 'Worker';
        final createdAt = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray200),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primarySurface,
              child: Icon(Icons.map_rounded, color: AppColors.primary),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Created: ${AppFormatters.dateTime(createdAt)}'),
            trailing: OwnershipBadge(createdBy: 'worker', workerName: wName),
          ),
        );
      },
    );
  }
}
