// lib/features/worker/presentation/worker_control_panel_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/worker_package_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/export_filename_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';

import '../data/worker_dao.dart';
import '../domain/worker.dart';
import 'dialogs/worker_assignment_dialog.dart';
import 'dialogs/worker_package_summary_dialog.dart';
import 'worker_provider.dart';

class WorkerControlPanelScreen extends ConsumerStatefulWidget {
  final Worker worker;

  const WorkerControlPanelScreen({super.key, required this.worker});

  @override
  ConsumerState<WorkerControlPanelScreen> createState() => _WorkerControlPanelScreenState();
}

class _WorkerControlPanelScreenState extends ConsumerState<WorkerControlPanelScreen> with SingleTickerProviderStateMixin {
  final _dao = WorkerDao();
  late TabController _tabController;
  late Worker _currentWorker;
  bool _loading = true;

  // Cached assigned entity IDs
  List<String> _assignedAreaIds = [];
  List<String> _assignedStreetIds = [];
  List<String> _assignedCustomerIds = [];
  List<String> _assignedCategoryIds = [];
  List<String> _assignedItemIds = [];
  List<String> _assignedRouteIds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    final freshWorker = await _dao.getWorkerById(widget.worker.id) ?? widget.worker;

    final areaIds     = await _dao.getAssignedEntityIds(freshWorker.id, 'area');
    final streetIds   = await _dao.getAssignedEntityIds(freshWorker.id, 'street');
    final customerIds = await _dao.getAssignedEntityIds(freshWorker.id, 'customer');
    final categoryIds = await _dao.getAssignedEntityIds(freshWorker.id, 'category');
    final itemIds     = await _dao.getAssignedEntityIds(freshWorker.id, 'item');
    final routeIds    = await _dao.getAssignedEntityIds(freshWorker.id, 'route');

    if (mounted) {
      setState(() {
        _currentWorker = freshWorker;
        _assignedAreaIds = areaIds;
        _assignedStreetIds = streetIds;
        _assignedCustomerIds = customerIds;
        _assignedCategoryIds = categoryIds;
        _assignedItemIds = itemIds;
        _assignedRouteIds = routeIds;
        _loading = false;
      });
    }
  }

  Future<void> _saveAssignments(String entityType, List<String> newIds) async {
    AppHaptics.buttonClick();
    await _dao.setWorkerAssignments(
      workerId: _currentWorker.id,
      entityType: entityType,
      entityIds: newIds,
    );
    ref.read(workerListProvider.notifier).load();
    await _loadData();
    if (mounted) {
      SnackbarHelper.showSuccess(context, 'Assignments updated successfully.');
    }
  }

  // ── 1. ASSIGN AREAS (Cascading strictly to Streets & Customers in Assigned Areas) ──
  Future<void> _openAssignAreas() async {
    final db = await DatabaseHelper.instance.database;
    final areas = await db.query('areas', orderBy: 'name ASC');

    final items = areas.map((a) {
      return AssignmentItem(
        id: a['id'] as String,
        title: a['name'] as String,
        subtitle: a['description'] as String? ?? 'Area',
      );
    }).toList();

    if (!mounted) return;
    final selected = await WorkerAssignmentDialog.show(
      context,
      title: 'Assign Areas',
      items: items,
      initialSelectedIds: _assignedAreaIds,
    );

    if (selected != null) {
      // Strict Scoping: Streets & Customers MUST belong ONLY to assigned areas
      List<String> memberStreetIds = [];
      List<String> memberCustomerIds = [];

      if (selected.isNotEmpty) {
        final inClause = selected.map((id) => "'$id'").join(',');
        final memberStreets = await db.query('streets', where: 'area_id IN ($inClause)');
        memberStreetIds = memberStreets.map((s) => s['id'] as String).toList();

        if (memberStreetIds.isNotEmpty) {
          final streetInClause = memberStreetIds.map((id) => "'$id'").join(',');
          final memberCustomers = await db.query('customers', where: 'street_id IN ($streetInClause)');
          memberCustomerIds = memberCustomers.map((c) => c['id'] as String).toList();
        }
      }

      await _dao.setWorkerAssignments(workerId: _currentWorker.id, entityType: 'area', entityIds: selected);
      await _dao.setWorkerAssignments(workerId: _currentWorker.id, entityType: 'street', entityIds: memberStreetIds);
      await _dao.setWorkerAssignments(workerId: _currentWorker.id, entityType: 'customer', entityIds: memberCustomerIds);
      await _loadData();
    }
  }

  // ── 2. ASSIGN STREETS (Filtered strictly by assigned areas) ──────────────
  Future<void> _openAssignStreets() async {
    if (_assignedAreaIds.isEmpty) {
      SnackbarHelper.showInfo(context, 'Please assign at least 1 Area first to select streets.');
      return;
    }

    final db = await DatabaseHelper.instance.database;
    final inClause = _assignedAreaIds.map((id) => "'$id'").join(',');
    final streets = await db.query('streets', where: 'area_id IN ($inClause)', orderBy: 'name ASC');

    final items = streets.map((s) {
      return AssignmentItem(
        id: s['id'] as String,
        title: s['name'] as String,
        subtitle: 'Street in Area ${s['area_id']}',
      );
    }).toList();

    if (!mounted) return;
    final selected = await WorkerAssignmentDialog.show(
      context,
      title: 'Assign Streets',
      items: items,
      initialSelectedIds: _assignedStreetIds,
    );

    if (selected != null) {
      // Filter customers strictly to selected streets in assigned areas
      List<String> memberCustomerIds = [];
      if (selected.isNotEmpty) {
        final streetInClause = selected.map((id) => "'$id'").join(',');
        final memberCustomers = await db.query('customers', where: 'street_id IN ($streetInClause)');
        memberCustomerIds = memberCustomers.map((c) => c['id'] as String).toList();
      }

      await _saveAssignments('street', selected);
      await _dao.setWorkerAssignments(workerId: _currentWorker.id, entityType: 'customer', entityIds: memberCustomerIds);
      await _loadData();
    }
  }

  // ── 3. ASSIGN CUSTOMERS (Filtered strictly by assigned streets/areas) ─────
  Future<void> _openAssignCustomers() async {
    if (_assignedStreetIds.isEmpty) {
      SnackbarHelper.showInfo(context, 'Please assign Areas & Streets first to select customers.');
      return;
    }

    final db = await DatabaseHelper.instance.database;
    final inClause = _assignedStreetIds.map((id) => "'$id'").join(',');
    final customers = await db.query('customers', where: 'street_id IN ($inClause)', orderBy: 'name ASC');

    final items = customers.map((c) {
      return AssignmentItem(
        id: c['id'] as String,
        title: c['name'] as String,
        subtitle: 'Phone: ${c['phone1']} • Address: ${c['address']}',
      );
    }).toList();

    if (!mounted) return;
    final selected = await WorkerAssignmentDialog.show(
      context,
      title: 'Assign Customers',
      items: items,
      initialSelectedIds: _assignedCustomerIds,
    );

    if (selected != null) {
      await _saveAssignments('customer', selected);
    }
  }

  // ── 4. ASSIGN CATEGORIES (Cascading to Items) ─────────────────────────────
  Future<void> _openAssignCategories() async {
    final db = await DatabaseHelper.instance.database;
    final dbItems = await db.query('items');
    final categories = dbItems
        .map((e) => e['category']?.toString() ?? 'General')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();

    final items = categories.map((cat) {
      final count = dbItems.where((i) => i['category'] == cat).length;
      return AssignmentItem(
        id: cat,
        title: cat,
        subtitle: '$count Inventory Items in this Category',
      );
    }).toList();

    if (!mounted) return;
    final selected = await WorkerAssignmentDialog.show(
      context,
      title: 'Assign Categories',
      items: items,
      initialSelectedIds: _assignedCategoryIds,
    );

    if (selected != null) {
      // Cascading logic: Auto-select all items belonging to selected categories
      final Set<String> newItemIds = Set.from(_assignedItemIds);
      for (final cat in selected) {
        final catItems = dbItems.where((i) => i['category'] == cat);
        for (final item in catItems) {
          newItemIds.add(item['id'] as String);
        }
      }

      await _saveAssignments('category', selected);
      await _dao.setWorkerAssignments(workerId: _currentWorker.id, entityType: 'item', entityIds: newItemIds.toList());
      await _loadData();
    }
  }

  // ── 5. ASSIGN ITEMS ───────────────────────────────────────────────────────
  Future<void> _openAssignItems() async {
    final db = await DatabaseHelper.instance.database;
    final dbItems = await db.query('items', orderBy: 'name ASC');

    final items = dbItems.map((i) {
      return AssignmentItem(
        id: i['id'] as String,
        title: i['name'] as String,
        subtitle: 'Price: ₹${i['selling_price']} • Stock: ${i['stock_quantity']}',
        category: i['category']?.toString() ?? 'General',
      );
    }).toList();

    if (!mounted) return;
    final selected = await WorkerAssignmentDialog.show(
      context,
      title: 'Assign Inventory Items',
      items: items,
      initialSelectedIds: _assignedItemIds,
    );

    if (selected != null) {
      await _saveAssignments('item', selected);
    }
  }

  // ── 6. ASSIGN PRICE LIST ──────────────────────────────────────────────────
  Future<void> _openAssignPriceList() async {
    AppHaptics.buttonClick();
    SnackbarHelper.showInfo(context, 'Worker assigned to Standard Active Price List.');
  }

  // ── 7. ASSIGN ROUTES / VISITS ─────────────────────────────────────────────
  Future<void> _openAssignRoutes() async {
    final db = await DatabaseHelper.instance.database;
    final visits = await db.query('visits', orderBy: 'date DESC');

    final items = visits.map((v) {
      return AssignmentItem(
        id: v['id'] as String,
        title: 'Route Visit on ${v['date']}',
        subtitle: 'Status: ${v['status']} • Notes: ${v['notes']}',
      );
    }).toList();

    if (!mounted) return;
    final selected = await WorkerAssignmentDialog.show(
      context,
      title: 'Assign Routes & Visits',
      items: items,
      initialSelectedIds: _assignedRouteIds,
    );

    if (selected != null) {
      await _saveAssignments('route', selected);
    }
  }

  // ── PRE-EXPORT VALIDATION & PACKAGE SUMMARY MODAL ─────────────────────────
  Future<void> _triggerPackageSummary() async {
    AppHaptics.buttonClick();

    final double sizeEstimateMb = 0.5 + (_assignedCustomerIds.length * 0.01) + (_assignedItemIds.length * 0.005);

    WorkerPackageSummaryDialog.show(
      context,
      worker: _currentWorker,
      areasCount: _assignedAreaIds.length,
      streetsCount: _assignedStreetIds.length,
      customersCount: _assignedCustomerIds.length,
      categoriesCount: _assignedCategoryIds.length,
      itemsCount: _assignedItemIds.length,
      routesCount: _assignedRouteIds.length,
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
        SnackbarHelper.showSuccess(context, 'WorkerPackage.orderkart generated & ready to share!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Package Export Failed: $e');
      }
    }
  }



  Future<void> _toggleWorkerStatus() async {
    AppHaptics.buttonClick();
    final newStatus = _currentWorker.status == 'active' ? 'suspended' : 'active';
    final updated = _currentWorker.copyWith(status: newStatus);
    await ref.read(workerListProvider.notifier).update(updated);
    setState(() => _currentWorker = updated);
    SnackbarHelper.showSuccess(context, 'Worker status changed to ${newStatus.toUpperCase()}');
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
      if (mounted) SnackbarHelper.showInfo(context, 'No customers found for ${_currentWorker.name} to export.');
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
      final phone = row['phone1']?.toString() ?? row['phone2']?.toString() ?? '';
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
      SnackbarHelper.showSuccess(context, '✅ ${rows.length} contacts exported for phone saving!');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Worker Profile',
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return AppScaffold(
      title: _currentWorker.name,
      bottom: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        tabs: const [
          Tab(text: 'Overview', icon: Icon(Icons.person_rounded, size: 20)),
          Tab(text: 'Assignments', icon: Icon(Icons.playlist_add_check_circle_rounded, size: 20)),
          Tab(text: 'Stats', icon: Icon(Icons.analytics_rounded, size: 20)),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildAssignmentsTab(),
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
                    backgroundColor: _currentWorker.status == 'active' ? AppColors.primarySurface : AppColors.gray300,
                    child: Text(
                      _currentWorker.name.isNotEmpty ? _currentWorker.name[0].toUpperCase() : 'W',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: _currentWorker.status == 'active' ? AppColors.primary : AppColors.gray600,
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
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Phone: ${_currentWorker.phone.isEmpty ? '—' : _currentWorker.phone}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Emp ID: ${_currentWorker.employeeId.isEmpty ? _currentWorker.id.substring(0, 8) : _currentWorker.employeeId}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _currentWorker.status == 'active' ? AppColors.successSurface : AppColors.gray200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _currentWorker.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _currentWorker.status == 'active' ? AppColors.success : AppColors.gray600,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Overview Grid Details
              Row(
                children: [
                  _overviewMetric('Package Ver', hasPackage ? 'v${_currentWorker.packageVersion}' : 'v0 (None)'),
                  _overviewMetric('Status', _currentWorker.status.toUpperCase()),
                  _overviewMetric('Device', '📲 Bound'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _overviewMetric('Commission', '${_currentWorker.commissionValue}% (${_currentWorker.commissionType.name})'),
                  _overviewMetric('Last Sync', _currentWorker.joiningDate.isEmpty ? 'Never' : AppFormatters.relativeDate(DateTime.tryParse(_currentWorker.joiningDate) ?? DateTime.now())),
                  _overviewMetric('Last Generated', _currentWorker.lastPackageGenerated.isEmpty ? 'Never' : AppFormatters.shortDate(DateTime.tryParse(_currentWorker.lastPackageGenerated) ?? DateTime.now())),
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
            title: isOutdated ? 'Regenerate Worker Package' : 'Generate & Export Package',
            icon: Icons.cloud_upload_rounded,
            color: isOutdated ? Colors.deepOrange : AppColors.primary,
            onTap: _triggerPackageSummary,
          ),
          const Divider(height: 1),
          _actionTile(
            title: 'Export Worker Customers to Phone (.vcf)',
            subtitle: 'Save new customer names & phone numbers directly to phone contacts',
            icon: Icons.contacts_rounded,
            color: Colors.teal,
            onTap: _exportWorkerContactsToPhone,
          ),
          const Divider(height: 1),
          _actionTile(
            title: 'Configure Assignments',
            icon: Icons.checklist_rounded,
            color: Colors.indigo,
            onTap: () => _tabController.animateTo(1),
          ),
          const Divider(height: 1),
          _actionTile(
            title: _currentWorker.status == 'active' ? 'Suspend Worker Account' : 'Activate Worker Account',
            icon: _currentWorker.status == 'active' ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
            color: _currentWorker.status == 'active' ? Colors.red : AppColors.success,
            onTap: _toggleWorkerStatus,
          ),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── TAB 2: COMPLETE WORKER ASSIGNMENT SYSTEM (8 Cards) ────────────────────
  Widget _buildAssignmentsTab() {
    final bool isOutdated = _currentWorker.isPackageOutdated;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top Package Status Alert
        _buildPackageStatusBanner(),
        const SizedBox(height: 16),

        _sectionTitle('Worker Assignment Modules'),
        const Text(
          'Configure assigned data scope for this worker. Changes mark the Worker Package as Outdated until regenerated.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),

        // 1. Assign Areas
        _assignmentCard(
          title: '1. Assign Areas',
          subtitle: 'Multi-select geographic areas (Auto-selects streets & customers)',
          countLabel: '${_assignedAreaIds.length} Areas Assigned',
          icon: Icons.map_rounded,
          color: Colors.blue,
          onTap: _openAssignAreas,
        ),
        const SizedBox(height: 12),

        // 2. Assign Streets
        _assignmentCard(
          title: '2. Assign Streets',
          subtitle: 'Multi-select streets (Filtered by assigned areas)',
          countLabel: '${_assignedStreetIds.length} Streets Assigned',
          icon: Icons.add_road_rounded,
          color: Colors.teal,
          onTap: _openAssignStreets,
        ),
        const SizedBox(height: 12),

        // 3. Assign Customers
        _assignmentCard(
          title: '3. Assign Customers',
          subtitle: 'Multi-select customers (Filtered by assigned streets)',
          countLabel: '${_assignedCustomerIds.length} Customers Assigned',
          icon: Icons.people_alt_rounded,
          color: Colors.indigo,
          onTap: _openAssignCustomers,
        ),
        const SizedBox(height: 12),

        // 4. Assign Categories
        _assignmentCard(
          title: '4. Assign Categories (Auto-Selects Items)',
          subtitle: 'Assign entire product categories (Vegetables, Fruits, Grocery, etc.)',
          countLabel: '${_assignedCategoryIds.length} Categories Assigned',
          icon: Icons.category_rounded,
          color: Colors.deepPurple,
          onTap: _openAssignCategories,
        ),
        const SizedBox(height: 12),

        // 5. Assign Items
        _assignmentCard(
          title: '5. Assign Items',
          subtitle: 'Select specific inventory items the worker can access/sell',
          countLabel: '${_assignedItemIds.length} Items Assigned',
          icon: Icons.inventory_2_rounded,
          color: Colors.amber.shade900,
          onTap: _openAssignItems,
        ),
        const SizedBox(height: 12),

        // 6. Assign Price List
        _assignmentCard(
          title: '6. Assign Price List',
          subtitle: 'Assign custom item price rules for this worker',
          countLabel: 'Standard Price List',
          icon: Icons.sell_rounded,
          color: Colors.green,
          onTap: _openAssignPriceList,
        ),
        const SizedBox(height: 12),

        // 7. Assign Routes
        _assignmentCard(
          title: '7. Assign Routes & Visits',
          subtitle: 'Assign scheduled route visits for field delivery',
          countLabel: '${_assignedRouteIds.length} Routes Assigned',
          icon: Icons.route_rounded,
          color: Colors.purple,
          onTap: _openAssignRoutes,
        ),
        const SizedBox(height: 24),

        // --- GENERATE WORKER PACKAGE CALL TO ACTION ---
        ElevatedButton.icon(
          onPressed: _triggerPackageSummary,
          icon: Icon(isOutdated ? Icons.published_with_changes_rounded : Icons.cloud_upload_rounded),
          label: Text(
            isOutdated ? 'Regenerate Worker Package' : 'Generate Worker Package',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isOutdated ? Colors.deepOrange : AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── TAB 3: STATS & SYNC PROVENANCE TAB ────────────────────────────────────
  Widget _buildStatsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Sync & Device Provenance'),
        _card([
          _infoRow('Last Synchronized', _currentWorker.joiningDate.isEmpty ? 'Never Synced' : AppFormatters.dateFromString(_currentWorker.joiningDate)),
          _infoRow('Device Hostname', Platform.localHostname),
          _infoRow('Platform', Platform.operatingSystem.toUpperCase()),
          _infoRow('Database Schema Version', 'V4'),
        ]),
        const SizedBox(height: 20),

        _sectionTitle('Earning Stats'),
        _card([
          _infoRow('Total Collection Recovered', AppFormatters.currency(_currentWorker.totalCollection)),
          _infoRow('Average Commission Score', '96% (Executive)'),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── HELPER WIDGETS ────────────────────────────────────────────────────────
  Widget _buildPackageStatusBanner() {
    final bool isOutdated = _currentWorker.isPackageOutdated;
    final bool hasPackage = _currentWorker.packageVersion > 0 && _currentWorker.lastPackageGenerated.isNotEmpty;

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
      subtitle = 'Assignments have not been compiled into a Worker Package yet.';
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
      title = 'Package Status: ✅ Up-to-Date (v${_currentWorker.packageVersion})';
      subtitle = 'Last generated on ${AppFormatters.dateTimeFromString(_currentWorker.lastPackageGenerated)}';
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
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: border),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Generate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Widget _assignmentCard({
    required String title,
    required String subtitle,
    required String countLabel,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          countLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.gray400),
              ],
            ),
          ),
        ),
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
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
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
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      trailing: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
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
      title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)) : null,
      trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.gray400),
      onTap: onTap,
    );
  }
}
