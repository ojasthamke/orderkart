import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/empty_state_widget.dart';

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
  List<Map<String, dynamic>> _importLogs = [];
  List<Map<String, dynamic>> _workers = [];
  String _selectedWorkerId = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final wName = workerNameMap[wid] ?? (c['created_by']?.toString() ?? 'Worker');
      return {
        ...c,
        'worker_name': wName,
        'worker_id': wid,
      };
    }).toList();

    // 2. Worker Orders
    final orderRows = await db.query(
      'orders',
      where: 'assigned_worker_id IS NOT NULL AND assigned_worker_id != "" OR order_source == "worker"',
      orderBy: 'created_at DESC',
    );
    final orders = orderRows.map((o) {
      final wid = o['assigned_worker_id']?.toString() ?? '';
      final wName = workerNameMap[wid] ?? 'Field Worker';
      return {
        ...o,
        'worker_name': wName,
        'worker_id': wid,
      };
    }).toList();

    // 3. Import Logs
    final imports = await db.query('import_history', orderBy: 'imported_at DESC');

    if (mounted) {
      setState(() {
        _workers = workers;
        _workerCustomers = customers;
        _workerOrders = orders;
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Worker Activity & Sync Logs',
      bottom: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        tabs: const [
          Tab(text: 'Customers', icon: Icon(Icons.people_alt_rounded, size: 18)),
          Tab(text: 'Orders', icon: Icon(Icons.shopping_cart_rounded, size: 18)),
          Tab(text: 'Import Packages', icon: Icon(Icons.history_rounded, size: 18)),
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
                      _buildCustomersList(),
                      _buildOrdersList(),
                      _buildImportHistoryList(),
                    ],
                  ),
                ),
              ],
            ),
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
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Text('By: $wName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.purple)),
            ),
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
            title: Text('Order #${id.substring(0, 6)} • ${AppFormatters.currency(amount)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Date: ${AppFormatters.shortDate(createdAt)} • Status: ${o['delivery_status']}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Text('By: $wName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.indigo)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImportHistoryList() {
    if (_importLogs.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history_rounded,
        title: 'No Import Packages Yet',
        subtitle: 'Imported package records from workers will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _importLogs.length,
      itemBuilder: (ctx, i) {
        final imp = _importLogs[i];
        final pkgId = imp['package_id']?.toString() ?? 'Package';
        final importedAt = DateTime.tryParse(imp['imported_at']?.toString() ?? '') ?? DateTime.now();
        final modules = imp['modules']?.toString() ?? 'All Modules';

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
              child: Icon(Icons.inventory_2_rounded, color: AppColors.primary),
            ),
            title: Text('Import: ${pkgId.length > 12 ? pkgId.substring(0, 12) : pkgId}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Imported on ${AppFormatters.dateTime(importedAt)}\nModules: $modules'),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
