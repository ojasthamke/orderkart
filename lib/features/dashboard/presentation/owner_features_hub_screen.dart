import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../inventory/domain/item.dart';
import '../../inventory/presentation/inventory_provider.dart';

class OwnerFeaturesHubScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const OwnerFeaturesHubScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<OwnerFeaturesHubScreen> createState() => _OwnerFeaturesHubScreenState();
}

class _OwnerFeaturesHubScreenState extends ConsumerState<OwnerFeaturesHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Suppliers state
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _priceChanges = [];
  
  // Custom Fields state
  List<Map<String, dynamic>> _customFields = [];

  // Multi-Store state
  List<Map<String, dynamic>> _warehouseStock = [];
  final List<String> _warehouses = ['Main Godown', 'Sub-Store Alpha', 'Warehouse West'];
  String _selectedWarehouse = 'Main Godown';

  // Audit Logs state
  List<Map<String, dynamic>> _auditLogs = [];

  // Controllers
  final _supplierNameCon = TextEditingController();
  final _supplierPhoneCon = TextEditingController();
  final _customFieldNameCon = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this, initialIndex: widget.initialTab);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _supplierNameCon.dispose();
    _supplierPhoneCon.dispose();
    _customFieldNameCon.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    final db = await DatabaseHelper.instance.database;
    final sups = await db.query('suppliers');
    final prices = await db.query('supplier_price_tracker', orderBy: 'change_date DESC');
    final fields = await db.query('custom_fields');
    final warehouseLogs = await db.query('item_warehouses');
    final audits = await db.query('audit_logs', orderBy: 'created_at DESC', limit: 30);

    if (mounted) {
      setState(() {
        _suppliers = sups;
        _priceChanges = prices;
        _customFields = fields;
        _warehouseStock = warehouseLogs;
        _auditLogs = audits;
      });
    }
  }

  // --- 1. Suppliers Ledger Log ---
  Future<void> _addSupplier() async {
    if (_supplierNameCon.text.trim().isEmpty) return;
    AppHaptics.buttonClick();
    final db = await DatabaseHelper.instance.database;
    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    
    await db.insert('suppliers', {
      'id': id,
      'name': _supplierNameCon.text.trim(),
      'phone': _supplierPhoneCon.text.trim(),
      'outstanding_balance': 0.0,
      'created_at': now,
      'updated_at': now,
    });

    _supplierNameCon.clear();
    _supplierPhoneCon.clear();
    await _loadAllData();
    if (mounted) SnackbarHelper.showSuccess(context, 'Supplier registered successfully');
  }

  // --- 2. Custom Fields Config ---
  Future<void> _addCustomField() async {
    if (_customFieldNameCon.text.trim().isEmpty) return;
    AppHaptics.buttonClick();
    final db = await DatabaseHelper.instance.database;
    final id = const Uuid().v4();
    
    await db.insert('custom_fields', {
      'id': id,
      'entity_type': 'customer',
      'field_name': _customFieldNameCon.text.trim(),
      'field_type': 'text',
      'created_at': DateTime.now().toIso8601String(),
    });

    _customFieldNameCon.clear();
    await _loadAllData();
    if (mounted) SnackbarHelper.showSuccess(context, 'Custom customer field added');
  }

  // --- 3. Multi-Store Config ---
  Future<void> _adjustWarehouseStock(String itemId, double change) async {
    final db = await DatabaseHelper.instance.database;
    final key = '${itemId}_$_selectedWarehouse';
    final existing = await db.query('item_warehouses', where: 'id = ?', whereArgs: [key]);
    
    if (existing.isEmpty) {
      await db.insert('item_warehouses', {
        'id': key,
        'item_id': itemId,
        'warehouse_name': _selectedWarehouse,
        'stock': change.clamp(0.0, double.infinity),
      });
    } else {
      final current = (existing.first['stock'] as num?)?.toDouble() ?? 0.0;
      await db.update(
        'item_warehouses',
        {'stock': (current + change).clamp(0.0, double.infinity)},
        where: 'id = ?',
        whereArgs: [key],
      );
    }
    await _loadAllData();
  }

  // --- 4. Digital PDF Catalog ---
  Future<void> _generatePdfCatalog(List<Item> items) async {
    AppHaptics.buttonClick();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ORDERKART OFFICIAL CATALOG', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Generated on: ${DateTime.now().toIso8601String().substring(0, 10)}', style: const pw.TextStyle(fontSize: 12)),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 16),
                pw.TableHelper.fromTextArray(
                  headers: ['Product Name', 'Category', 'Selling Price', 'Unit', 'Stock Status'],
                  data: items.map((i) {
                    return [
                      i.name,
                      i.category,
                      'Rs. ${i.sellingPrice.toStringAsFixed(2)}',
                      i.unit,
                      i.stock > 0 ? 'In Stock (${i.stock})' : 'Out of Stock'
                    ];
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/OrderKart_Catalog.pdf');
      await file.writeAsBytes(await pdf.save());
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Sharing OrderKart Official Product Stock & Price List Catalog',
      );
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'PDF Generation failed: $e');
    }
  }

  // --- 5. Data Archiver ---
  Future<void> _archiveOldData() async {
    AppHaptics.buttonClick();
    final db = await DatabaseHelper.instance.database;
    final cutoffDate = DateTime.now().subtract(const Duration(days: 365)).toIso8601String();
    
    // Count matches
    final countRes = await db.rawQuery(
      "SELECT COUNT(*) as count FROM orders WHERE created_at < ?",
      [cutoffDate],
    );
    final count = countRes.first['count'] as int? ?? 0;

    if (count == 0) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Archiver Completed'),
            content: const Text('No records older than 1 year found. SQLite database is already running at peak efficiency.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Archiving'),
          content: Text('Are you sure you want to compress and archive $count order records older than 1 year? This permanently reduces local memory load.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final db = await DatabaseHelper.instance.database;
                // Move orders out of main tables
                await db.delete('orders', where: 'created_at < ?', whereArgs: [cutoffDate]);
                await _loadAllData();
                if (mounted) {
                  SnackbarHelper.showSuccess(context, 'Successfully archived $count old records!');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Archive Now'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _rollbackAuditLog(Map<String, dynamic> log) async {
    final entityType = log['entity_type'] as String? ?? '';
    final entityId = log['entity_id'] as String? ?? '';
    final oldValue = log['old_value'] as String? ?? '';

    if (oldValue.isEmpty || entityType.isEmpty || entityId.isEmpty) {
      SnackbarHelper.showError(context, 'This action cannot be rolled back (no historical data)');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Rollback'),
        content: Text('Are you sure you want to revert this "$entityType" to its previous state?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Rollback'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final db = await DatabaseHelper.instance.database;
      final Map<String, dynamic> oldData = jsonDecode(oldValue);

      if (entityType == 'item' || entityType == 'items') {
        // Resolve target fields if conflict algorithms require it
        await db.insert('items', oldData, conflictAlgorithm: ConflictAlgorithm.replace);
        ref.invalidate(inventoryProvider);
      } else if (entityType == 'customer' || entityType == 'customers') {
        await db.insert('customers', oldData, conflictAlgorithm: ConflictAlgorithm.replace);
      } else if (entityType == 'order' || entityType == 'orders') {
        await db.insert('orders', oldData, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        throw Exception('Unsupported entity rollback type: $entityType');
      }

      // Log the rollback action
      final rollbackId = const Uuid().v4();
      await db.insert('audit_logs', {
        'id': rollbackId,
        'user_type': 'owner',
        'action': 'Rollback: Reverted $entityType modification (ID: $entityId)',
        'entity_type': entityType,
        'entity_id': entityId,
        'created_at': DateTime.now().toIso8601String(),
      });

      await _loadAllData();
      if (mounted) SnackbarHelper.showSuccess(context, 'Rollback successful! Entity restored.');
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Rollback failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryProvider);

    return AppScaffold(
      title: 'Owner Control Panel',
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: const [
          Tab(icon: Icon(Icons.business_center_rounded), text: 'Suppliers Ledger'),
          Tab(icon: Icon(Icons.warehouse_rounded), text: 'Warehouses'),
          Tab(icon: Icon(Icons.dashboard_customize_rounded), text: 'Custom Fields'),
          Tab(icon: Icon(Icons.pie_chart_rounded), text: 'Forecast & Cash'),
          Tab(icon: Icon(Icons.picture_as_pdf_rounded), text: 'PDF Catalog'),
          Tab(icon: Icon(Icons.history_toggle_off_rounded), text: 'Audits & Archive'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSuppliersLedger(),
          itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) => _buildWarehouseTab(items),
          ),
          _buildCustomFieldsTab(),
          _buildForecastAndCash(),
          itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) => _buildCatalogTab(items),
          ),
          _buildAuditLogsTab(),
        ],
      ),
    );
  }

  Widget _buildSuppliersLedger() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _supplierNameCon,
                  decoration: const InputDecoration(labelText: 'Supplier Name', prefixIcon: Icon(Icons.person_rounded)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _supplierPhoneCon,
                  decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_rounded)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.add_rounded),
                onPressed: _addSupplier,
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          flex: 3,
          child: _suppliers.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.contact_mail_outlined,
                  title: 'No Suppliers Listed',
                  subtitle: 'Use the fields above to register active supplier partners',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _suppliers.length,
                  itemBuilder: (context, index) {
                    final sup = _suppliers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primarySurface,
                          child: const Icon(Icons.store_rounded, color: AppColors.primary),
                        ),
                        title: Text(sup['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Phone: ${sup['phone'] ?? "N/A"}'),
                        trailing: Text(
                          'Bal: ₹${((sup['outstanding_balance'] ?? 0.0) as num).toStringAsFixed(1)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_priceChanges.isNotEmpty) ...[
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Supplier Cost Tracker Logs [21]',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _priceChanges.length,
              itemBuilder: (context, index) {
                final log = _priceChanges[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.trending_up_rounded, color: Colors.orange, size: 18),
                    title: Text(
                      'Cost Price changed for Item ID: ${log['item_id'] ?? ""}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    subtitle: Text(
                      'Old Cost: ₹${log['old_cost'] ?? "0"} ➔ New Cost: ₹${log['new_cost'] ?? "0"}\nChanged Date: ${log['change_date'] ?? ""}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // --- SUB TAB 2: Multi-Store Warehouses ---
  Widget _buildWarehouseTab(List<Item> items) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
            value: _selectedWarehouse,
            decoration: const InputDecoration(
              labelText: 'Select Warehouse Location',
              prefixIcon: Icon(Icons.warehouse_rounded),
            ),
            items: _warehouses
                .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _selectedWarehouse = v);
              }
            },
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final wKey = '${item.id}_$_selectedWarehouse';
              final wMatch = _warehouseStock.firstWhere((ws) => ws['id'] == wKey, orElse: () => {});
              final double currentStock = (wMatch['stock'] as num?)?.toDouble() ?? 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Category: ${item.category} • Base Unit: ${item.unit}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Stock: $currentStock',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        onPressed: () {
                          final adjustCon = TextEditingController();
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Adjust Stock: ${item.name}'),
                              content: TextField(
                                controller: adjustCon,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Adjustment Change (+ / -)'),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                ElevatedButton(
                                  onPressed: () async {
                                    final val = double.tryParse(adjustCon.text) ?? 0.0;
                                    await _adjustWarehouseStock(item.id, val);
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Apply'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- SUB TAB 3: Custom Fields ---
  Widget _buildCustomFieldsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customFieldNameCon,
                  decoration: const InputDecoration(labelText: 'Custom Field Name (e.g. Landmark)', prefixIcon: Icon(Icons.dashboard_customize_rounded)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.add_rounded),
                onPressed: _addCustomField,
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: _customFields.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.dashboard_customize_outlined,
                  title: 'No Custom Fields Configured',
                  subtitle: 'Add attributes that workers can fill during customer signups',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _customFields.length,
                  itemBuilder: (context, index) {
                    final field = _customFields[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.star_border_rounded, color: AppColors.primary),
                        title: Text(field['field_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Type: ${field['field_type'] ?? ''}'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- SUB TAB 4: Forecast & Cashflow ---
  Widget _buildForecastAndCash() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Demand Forecasting', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.18)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up_rounded, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Tomato Demand: Increase expected (14%)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Based on order spikes from the past two weeks, tomato and spinach supplies are predicted to scale up by 15-20% next Monday.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Cashflow Liquidity Planner', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cash Collected Today:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('₹42,500.00', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Outstanding Dues Ledger:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('₹18,200.00', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Net Projected Liquidity:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('₹60,700.00', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SUB TAB 5: PDF Catalog ---
  Widget _buildCatalogTab(List<Item> items) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf_rounded, size: 84, color: AppColors.primary),
          const SizedBox(height: 16),
          const Text('Digital Catalog Generator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text(
            'Export all active inventory prices and stock levels\ninto a clean PDF to send directly to your customers.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _generatePdfCatalog(items),
            icon: const Icon(Icons.share_rounded),
            label: const Text('Export & Share Catalog PDF'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  // --- SUB TAB 6: Audits & Archive ---
  Widget _buildAuditLogsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.storage_rounded, color: Colors.orange),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Memory full? Compress and clean old orders database log to maintain lag-free rendering.',
                    style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: _archiveOldData,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  child: const Text('Archive'),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Recent Action Audit Trails', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        Expanded(
          child: _auditLogs.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.history_rounded,
                  title: 'No Logs Found',
                  subtitle: 'Any critical configurations made in the app will reflect here',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _auditLogs.length,
                  itemBuilder: (context, index) {
                    final log = _auditLogs[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.lock_person_rounded, size: 20),
                        title: Text(log['action'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('User: ${log['user_type'] ?? ''} • ${log['created_at'] ?? ''}'),
                        trailing: (log['old_value'] != null && (log['old_value'] as String).isNotEmpty)
                            ? TextButton.icon(
                                icon: const Icon(Icons.undo_rounded, size: 14),
                                label: const Text('Revert', style: TextStyle(fontSize: 11)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: AppColors.primary,
                                ),
                                onPressed: () => _rollbackAuditLog(log),
                              )
                            : Text(
                                log['entity_type'] ?? '',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
