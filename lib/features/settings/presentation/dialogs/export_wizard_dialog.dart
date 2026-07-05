import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/package_exporter.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/snackbar_helper.dart';

class ExportWizardDialog extends StatefulWidget {
  const ExportWizardDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (ctx) => const ExportWizardDialog(),
    );
  }

  @override
  State<ExportWizardDialog> createState() => _ExportWizardDialogState();
}

class _ExportWizardDialogState extends State<ExportWizardDialog> {
  // Modules selection
  bool _exportEntireDb = true;
  bool _exportAreas = true;
  bool _exportStreets = true;
  bool _exportCustomers = true;
  bool _exportOrders = true;
  bool _exportPayments = true;
  bool _exportExpenses = true;
  bool _exportInventory = true;
  bool _exportPrices = true;
  bool _exportVip = true;
  bool _exportNotes = true;
  bool _exportReports = true;
  bool _exportSettings = true;
  bool _exportPhotos = true;
  bool _exportWorkers = true;

  bool _exporting = false;

  // Filter Selection Data
  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _workers = [];
  String? _selectedAreaId;
  String? _selectedWorkerId;

  // Date Filtering
  bool _filterByDate = false;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final areas = await db.query('areas', orderBy: 'name ASC');
      final workers = await db.query('workers', orderBy: 'name ASC');
      setState(() {
        _areas = areas;
        _workers = workers;
      });
    } catch (_) {}
  }

  void _selectAll(bool val) {
    setState(() {
      _exportEntireDb = val;
      _exportAreas = val;
      _exportStreets = val;
      _exportCustomers = val;
      _exportOrders = val;
      _exportPayments = val;
      _exportExpenses = val;
      _exportInventory = val;
      _exportPrices = val;
      _exportVip = val;
      _exportNotes = val;
      _exportReports = val;
      _exportSettings = val;
      _exportPhotos = val;
      _exportWorkers = val;
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? now) : (_endDate ?? now),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _startExport() async {
    AppHaptics.buttonClick();
    setState(() => _exporting = true);

    try {
      final selectedModules = <String>[];
      if (_exportEntireDb) selectedModules.add('entire_db');
      if (_exportAreas) selectedModules.add('areas');
      if (_exportStreets) selectedModules.add('streets');
      if (_exportCustomers) selectedModules.add('customers');
      if (_exportOrders) selectedModules.add('orders');
      if (_exportPayments) selectedModules.add('payments');
      if (_exportExpenses) selectedModules.add('expenses');
      if (_exportInventory) selectedModules.add('items'); // item module key
      if (_exportPrices) selectedModules.add('prices');
      if (_exportVip) selectedModules.add('vip');
      if (_exportNotes) selectedModules.add('notes');
      if (_exportReports) selectedModules.add('reports');
      if (_exportSettings) selectedModules.add('settings');
      if (_exportPhotos) selectedModules.add('photos');
      if (_exportWorkers) selectedModules.add('workers');

      await PackageExporter.exportPackage(
        selectedModules: selectedModules,
        startDate: _filterByDate ? _startDate : null,
        endDate: _filterByDate ? _endDate : null,
        selectedAreaIds: _selectedAreaId != null ? [_selectedAreaId!] : null,
        selectedWorkerIds: _selectedWorkerId != null ? [_selectedWorkerId!] : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        SnackbarHelper.showSuccess(context, 'Export package generated successfully!');
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 700, maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.drive_folder_upload_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Modular Export Wizard', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      Text('Select options to package database:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SELECT MODULES ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Select Modules', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        TextButton(
                          onPressed: () => _selectAll(!_exportEntireDb),
                          child: Text(_exportEntireDb ? 'Unselect All' : 'Select All'),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    _moduleCheckbox('Entire Database (Full Package)', _exportEntireDb, (v) => setState(() => _exportEntireDb = v!)),
                    _moduleCheckbox('Areas & Geographic Regions', _exportAreas, (v) => setState(() => _exportAreas = v!)),
                    _moduleCheckbox('Streets & Routes', _exportStreets, (v) => setState(() => _exportStreets = v!)),
                    _moduleCheckbox('Customer Profiles', _exportCustomers, (v) => setState(() => _exportCustomers = v!)),
                    _moduleCheckbox('Orders & Order History', _exportOrders, (v) => setState(() => _exportOrders = v!)),
                    _moduleCheckbox('Payments & Collections', _exportPayments, (v) => setState(() => _exportPayments = v!)),
                    _moduleCheckbox('Business Expenses', _exportExpenses, (v) => setState(() => _exportExpenses = v!)),
                    _moduleCheckbox('Inventory, Items & Stock', _exportInventory, (v) => setState(() => _exportInventory = v!)),
                    _moduleCheckbox('Price Lists & Markups', _exportPrices, (v) => setState(() => _exportPrices = v!)),
                    _moduleCheckbox('VIP Customers & Subscriptions', _exportVip, (v) => setState(() => _exportVip = v!)),
                    _moduleCheckbox('Notes & Customer Reminders', _exportNotes, (v) => setState(() => _exportNotes = v!)),
                    _moduleCheckbox('Worker & Owner Reports', _exportReports, (v) => setState(() => _exportReports = v!)),
                    _moduleCheckbox('Settings & UPI QR Code', _exportSettings, (v) => setState(() => _exportSettings = v!)),
                    _moduleCheckbox('Customer Photos & Business Logo', _exportPhotos, (v) => setState(() => _exportPhotos = v!)),
                    _moduleCheckbox('Worker Profiles & Assignments', _exportWorkers, (v) => setState(() => _exportWorkers = v!)),

                    const SizedBox(height: 16),
                    // --- SELECT FILTERS ---
                    const Text('Selective Filtering', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const Divider(height: 8),

                    // Filter by Area
                    if (_areas.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Filter by Area:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedAreaId,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        hint: const Text('All Areas'),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('All Areas')),
                          ..._areas.map((a) => DropdownMenuItem<String>(value: a['id'], child: Text(a['name'] ?? ''))),
                        ],
                        onChanged: (val) => setState(() => _selectedAreaId = val),
                      ),
                    ],

                    // Filter by Worker
                    if (_workers.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Filter by Assigned Worker:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedWorkerId,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        hint: const Text('All Workers'),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('All Workers')),
                          ..._workers.map((w) => DropdownMenuItem<String>(value: w['id'], child: Text(w['name'] ?? ''))),
                        ],
                        onChanged: (val) => setState(() => _selectedWorkerId = val),
                      ),
                    ],

                    const SizedBox(height: 12),
                    // Date Filter Toggle
                    SwitchListTile(
                      dense: true,
                      title: const Text('Filter by Date Range', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      value: _filterByDate,
                      onChanged: (val) => setState(() => _filterByDate = val),
                      activeColor: AppColors.primary,
                    ),

                    if (_filterByDate) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _pickDate(true),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(_startDate == null
                                  ? 'Start Date'
                                  : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _pickDate(false),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(_endDate == null
                                  ? 'End Date'
                                  : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _exporting ? null : _startExport,
                icon: _exporting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.ios_share_rounded),
                label: Text(_exporting ? 'Generating Package...' : 'Export Package'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moduleCheckbox(String title, bool val, ValueChanged<bool?> onChanged) {
    return CheckboxListTile(
      dense: true,
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      value: val,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }
}
