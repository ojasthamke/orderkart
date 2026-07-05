import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
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
      if (_exportInventory) selectedModules.add('inventory');
      if (_exportPrices) selectedModules.add('prices');
      if (_exportVip) selectedModules.add('vip');
      if (_exportNotes) selectedModules.add('notes');
      if (_exportReports) selectedModules.add('reports');
      if (_exportSettings) selectedModules.add('settings');
      if (_exportPhotos) selectedModules.add('photos');
      if (_exportWorkers) selectedModules.add('workers');

      final packageType = selectedModules.contains('entire_db') ? 'full' : selectedModules.join('_');
      await PackageExporter.exportPackage(packageType: packageType);

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
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      Text('Modular Export Package', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      Text('Select modules to export:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select All Modules', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                TextButton(
                  onPressed: () => _selectAll(!_exportEntireDb),
                  child: Text(_exportEntireDb ? 'Unselect All' : 'Select All'),
                ),
              ],
            ),
            const Divider(height: 1),

            Expanded(
              child: ListView(
                children: [
                  _moduleCheckbox('Entire Database (Full Package)', _exportEntireDb, (v) => setState(() => _exportEntireDb = v!)),
                  _moduleCheckbox('Areas & Geographic Regions', _exportAreas, (v) => setState(() => _exportAreas = v!)),
                  _moduleCheckbox('Streets & Routes', _exportStreets, (v) => setState(() => _exportStreets = v!)),
                  _moduleCheckbox('Customer Profiles & Outstanding', _exportCustomers, (v) => setState(() => _exportCustomers = v!)),
                  _moduleCheckbox('Orders & Delivery History', _exportOrders, (v) => setState(() => _exportOrders = v!)),
                  _moduleCheckbox('Payments & Collection Logs', _exportPayments, (v) => setState(() => _exportPayments = v!)),
                  _moduleCheckbox('Business Expenses', _exportExpenses, (v) => setState(() => _exportExpenses = v!)),
                  _moduleCheckbox('Inventory, Items & Stock', _exportInventory, (v) => setState(() => _exportInventory = v!)),
                  _moduleCheckbox('Item Price Lists & Markup', _exportPrices, (v) => setState(() => _exportPrices = v!)),
                  _moduleCheckbox('VIP Memberships & Subscriptions', _exportVip, (v) => setState(() => _exportVip = v!)),
                  _moduleCheckbox('Notes & Customer Reminders', _exportNotes, (v) => setState(() => _exportNotes = v!)),
                  _moduleCheckbox('Worker & Owner Reports', _exportReports, (v) => setState(() => _exportReports = v!)),
                  _moduleCheckbox('Business Settings & UPI QR', _exportSettings, (v) => setState(() => _exportSettings = v!)),
                  _moduleCheckbox('Customer Profile Photos', _exportPhotos, (v) => setState(() => _exportPhotos = v!)),
                  _moduleCheckbox('Worker Profiles & Assignments', _exportWorkers, (v) => setState(() => _exportWorkers = v!)),
                ],
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
                label: Text(_exporting ? 'Generating Package...' : 'Export Selected Package'),
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
