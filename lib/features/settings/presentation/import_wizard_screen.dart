import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/package_validator.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import 'settings_provider.dart';
import '../../area/presentation/area_provider.dart';
import '../../customer/presentation/customer_provider.dart';
import '../../order/presentation/order_provider.dart';
import '../../expense/presentation/expense_provider.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../../street/presentation/street_provider.dart';
import '../../notification/presentation/notification_provider.dart';
import '../../settings/presentation/sync_history_screen.dart';

class MergeConflict {
  final String table;
  final String id;
  final String name;
  final String field;
  final String localValue;
  final String incomingValue;
  String resolution; // 'keep_owner', 'accept_worker', 'merge'

  MergeConflict({
    required this.table,
    required this.id,
    required this.name,
    required this.field,
    required this.localValue,
    required this.incomingValue,
    this.resolution = 'keep_owner',
  });
}

class ImportWizardScreen extends ConsumerStatefulWidget {
  const ImportWizardScreen({super.key});

  @override
  ConsumerState<ImportWizardScreen> createState() => _ImportWizardScreenState();
}

class _ImportWizardScreenState extends ConsumerState<ImportWizardScreen> {
  int _currentStep = 0;
  bool _loading = false;

  void _invalidateAllProviders() {
    ref.invalidate(areaProvider);
    ref.invalidate(streetProviderFamily);
    ref.invalidate(allCustomersProvider);
    ref.invalidate(customerListProvider);
    ref.invalidate(pendingCustomersProvider);
    ref.invalidate(overpaidCustomersProvider);
    ref.invalidate(inventoryProvider);
    ref.invalidate(lowStockProvider);
    ref.invalidate(outOfStockProvider);
    ref.invalidate(stockSummaryProvider);
    ref.invalidate(orderManagementProvider);
    ref.invalidate(customerOrdersProvider);
    ref.invalidate(analyticsSummaryProvider);
    ref.invalidate(weeklyChartProvider);
    ref.invalidate(monthlyChartProvider);
    ref.invalidate(topCustomersProvider);
    ref.invalidate(todaysDetailedReportProvider);
    ref.invalidate(profitLossProvider);
    ref.invalidate(expenseProvider);
    ref.invalidate(monthlySummaryProvider);
    ref.invalidate(importHistoryProvider);
    ref.invalidate(workerSyncHistoryProvider);
    ref.invalidate(notificationListProvider);
  }

  Map<String, dynamic> _manifest = {};
  Map<String, Map<String, int>> _previewStats = {};
  String _dbFileToMerge = '';
  int _incomingPhotosCount = 0;

  // Import selection states
  bool _importEntireDb = true;
  bool _importAreas = true;
  bool _importStreets = true;
  bool _importCustomers = true;
  bool _importOrders = true;
  bool _importItems = true;
  bool _importExpenses = true;
  bool _importNotes = true;
  bool _importWorkers = true;
  bool _importSettings = true;

  // Interactive Conflicts
  List<MergeConflict> _conflicts = [];
  bool _applyToAllSimilar = false;

  // Progress indicators
  double _importProgress = 0.0;
  int _processedCount = 0;
  int _totalCount = 0;
  int _duplicatePhonesCount = 0;
  bool _isImporting = false;

  Future<int> _countDuplicatePhones(String incomingDbPath) async {
    int duplicates = 0;
    try {
      final targetDb = await DatabaseHelper.instance.database;
      final incomingDb = await openDatabase(incomingDbPath, readOnly: true);
      final incomingCustomers = await incomingDb.query('customers', columns: ['id', 'phone']);
      
      for (final row in incomingCustomers) {
        final phone = row['phone']?.toString() ?? '';
        final id = row['id']?.toString() ?? '';
        if (phone.isEmpty || id.isEmpty) continue;
        
        final local = await targetDb.query('customers', where: 'phone = ? AND id != ?', whereArgs: [phone, id]);
        if (local.isNotEmpty) {
          duplicates++;
        }
      }
      await incomingDb.close();
    } catch (_) {}
    return duplicates;
  }

  Future<void> _pickFile() async {
    setState(() => _loading = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final srcPath = result.files.first.path!;

      // --- 1. RUN ENTERPRISE PACKAGE VALIDATION ---
      final valResult = await PackageValidator.validatePackage(srcPath);
      if (!valResult.isValid) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Validation Rejected'),
                ],
              ),
              content: Text(valResult.errorMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        setState(() => _loading = false);
        return;
      }

      _manifest = valResult.manifest;
      _dbFileToMerge = valResult.dbPath;
      _incomingPhotosCount = valResult.photosCount;

      // Generate preview counts (dry run)
      _previewStats = await DatabaseHelper.instance.mergeDatabaseFromPath(
        _dbFileToMerge,
        dryRun: true,
      );

      _duplicatePhonesCount = await _countDuplicatePhones(_dbFileToMerge);

      // Check for conflicts
      _conflicts = await _checkConflicts(_dbFileToMerge);

      setState(() {
        _currentStep = 1; // Step 2: Preview
      });
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to parse package: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<List<MergeConflict>> _checkConflicts(String incomingDbPath) async {
    final targetDb = await DatabaseHelper.instance.database;
    final incomingDb = await openDatabase(incomingDbPath, readOnly: true);

    final List<MergeConflict> list = [];

    // 1. Check Items
    try {
      final incomingItems = await incomingDb.query('items');
      for (final row in incomingItems) {
        final id = row['id'] as String;
        final name = row['name'] as String? ?? 'Item';
        final local = await targetDb.query('items', where: 'id = ?', whereArgs: [id]);
        if (local.isNotEmpty) {
          final localPrice = (local.first['selling_price'] as num?)?.toDouble() ?? 0.0;
          final incomingPrice = (row['selling_price'] as num?)?.toDouble() ?? 0.0;
          if (localPrice != incomingPrice) {
            list.add(MergeConflict(
              table: 'items',
              id: id,
              name: name,
              field: 'Price',
              localValue: '₹${localPrice.toStringAsFixed(0)}',
              incomingValue: '₹${incomingPrice.toStringAsFixed(0)}',
            ));
          }
        }
      }
    } catch (_) {}

    // 2. Check Customers
    try {
      final incomingCustomers = await incomingDb.query('customers');
      for (final row in incomingCustomers) {
        final id = row['id'] as String;
        final name = row['name'] as String? ?? 'Customer';
        final local = await targetDb.query('customers', where: 'id = ?', whereArgs: [id]);
        if (local.isNotEmpty) {
          final localBal = (local.first['outstanding_balance'] as num?)?.toDouble() ?? 0.0;
          final incomingBal = (row['outstanding_balance'] as num?)?.toDouble() ?? 0.0;
          if (localBal != incomingBal) {
            list.add(MergeConflict(
              table: 'customers',
              id: id,
              name: name,
              field: 'Outstanding Balance',
              localValue: '₹${localBal.toStringAsFixed(0)}',
              incomingValue: '₹${incomingBal.toStringAsFixed(0)}',
            ));
          }
        }
      }
    } catch (_) {}

    await incomingDb.close();
    return list;
  }

  /// Backup current database file for transaction rollback safety
  Future<File> _backupDatabase() async {
    final dbPath = await DatabaseHelper.instance.database.then((db) => db.path);
    final dbFile = File(dbPath);
    final backupFile = File('${dbFile.parent.path}/orderkart_backup.db');
    if (backupFile.existsSync()) backupFile.deleteSync();
    await dbFile.copy(backupFile.path);
    return backupFile;
  }

  Future<void> _restoreDatabase(File backupFile) async {
    final dbPath = await DatabaseHelper.instance.database.then((db) => db.path);
    final dbFile = File(dbPath);
    await DatabaseHelper.instance.close();
    if (dbFile.existsSync()) dbFile.deleteSync();
    await backupFile.copy(dbFile.path);
    if (backupFile.existsSync()) backupFile.deleteSync();
  }

  Future<void> _executeMerge() async {
    setState(() {
      _loading = true;
      _isImporting = true;
      _importProgress = 0.0;
      _processedCount = 0;
      _totalCount = 0;
    });
    File? backupFile;

    try {
      AppHaptics.buttonClick();

      // Take a backup copy of current database before starting
      backupFile = await _backupDatabase();

      // Open temporary merge database to apply conflict resolutions first
      final tempDb = await openDatabase(_dbFileToMerge);
      final targetDb = await DatabaseHelper.instance.database;

      for (final c in _conflicts) {
        final resolution = _applyToAllSimilar ? _conflicts.first.resolution : c.resolution;
        
        if (resolution == 'keep_owner') {
          // Update temp DB row to match owner local DB values (so merge keeps local value)
          final localRecord = await targetDb.query(c.table, where: 'id = ?', whereArgs: [c.id]);
          if (localRecord.isNotEmpty) {
            await tempDb.update(c.table, localRecord.first, where: 'id = ?', whereArgs: [c.id]);
          }
        } else if (resolution == 'merge') {
          // Averaging merge values logic for prices/balances
          final localRecord = await targetDb.query(c.table, where: 'id = ?', whereArgs: [c.id]);
          if (localRecord.isNotEmpty) {
            final double localNum = double.tryParse(c.localValue.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
            final double incomingNum = double.tryParse(c.incomingValue.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
            final double mergedVal = (localNum + incomingNum) / 2;

            final keyToUpdate = c.field == 'Price' ? 'selling_price' : 'outstanding_balance';
            final Map<String, dynamic> updatedRow = Map.from(localRecord.first);
            updatedRow[keyToUpdate] = mergedVal;
            updatedRow['updated_at'] = DateTime.now().toIso8601String();

            await tempDb.update(c.table, updatedRow, where: 'id = ?', whereArgs: [c.id]);
          }
        }
      }
      await tempDb.close();

      // Compile selected modules for merge
      final selectedModules = <String>[];
      if (_importEntireDb) selectedModules.add('entire_db');
      if (_importAreas) selectedModules.add('areas');
      if (_importStreets) selectedModules.add('streets');
      if (_importCustomers) selectedModules.add('customers');
      if (_importOrders) selectedModules.add('orders');
      if (_importItems) selectedModules.add('items');
      if (_importExpenses) selectedModules.add('expenses');
      if (_importNotes) selectedModules.add('notes');
      if (_importWorkers) selectedModules.add('workers');
      if (_importSettings) selectedModules.add('settings');

      // Execute merge onto target database
      final finalStats = await DatabaseHelper.instance.mergeDatabaseFromPath(
        _dbFileToMerge,
        selectedModules: selectedModules,
        dryRun: false,
        onProgress: (progress, processed, total) {
          setState(() {
            _importProgress = progress;
            _processedCount = processed;
            _totalCount = total;
          });
        },
      );

      // Log import into Import History table
      final packageId = _manifest['package_id']?.toString() ?? const Uuid().v4();
      final workerName = _manifest['generated_by_worker_name']?.toString() ?? '';
      final deviceName = _manifest['device_name']?.toString() ?? '';
      
      await targetDb.insert('import_history', {
        'id': const Uuid().v4(),
        'package_id': packageId,
        'imported_at': DateTime.now().toIso8601String(),
        'worker_name': workerName,
        'device_name': deviceName,
        'record_count': selectedModules.length,
        'status': 'success',
      });

      // Successful merge, delete backup copy
      if (backupFile.existsSync()) backupFile.deleteSync();

      ref.read(settingsProvider.notifier).load();
      _invalidateAllProviders();

      setState(() {
        _previewStats = finalStats;
        _isImporting = false;
        _currentStep = 3; // Step 4: Finish Summary
      });

    } catch (e) {
      // Transaction failed -> Automatic rollback database file restore!
      if (backupFile != null && backupFile.existsSync()) {
        await _restoreDatabase(backupFile);
      }
      setState(() {
        _isImporting = false;
      });
      SnackbarHelper.showError(context, 'Import failed. Database rolled back safely. Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _detailedPreviewRow(String title, String tableKey) {
    final stats = _previewStats[tableKey] ?? {'inserted': 0, 'updated': 0, 'skipped': 0, 'conflicted': 0};
    final ins = stats['inserted'] ?? 0;
    final upd = stats['updated'] ?? 0;
    final skp = stats['skipped'] ?? 0;
    final con = stats['conflicted'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('New: +$ins', style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
              Text('Updated: +$upd', style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600)),
              Text('Skipped: $skp', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (con > 0)
                Text('Conflicts: $con', style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
            ],
          ),
          const Divider(height: 12),
        ],
      ),
    );
  }

  Widget _previewPhotosRow(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('New Customer Photos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
          Text('+$count', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isImporting) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 24),
                const Text(
                  'Merging Database...',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _importProgress,
                  backgroundColor: Colors.white10,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_importProgress * 100).toStringAsFixed(0)}% completed',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_processedCount / $_totalCount records processed',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Import Wizard',
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stepper(
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep == 1) {
                  setState(() => _currentStep = 2); // Step 3: Module & Conflict options
                } else if (_currentStep == 2) {
                  _executeMerge();
                } else if (_currentStep == 3) {
                  Navigator.of(context).pop();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0 && _currentStep < 3) {
                  setState(() => _currentStep--);
                }
              },
              controlsBuilder: (context, details) {
                if (_currentStep == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: _loading ? null : details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(_currentStep == 2
                            ? 'Accept & Merge'
                            : (_currentStep == 3 ? 'Finish' : 'Continue?')),
                      ),
                      if (_currentStep > 0 && _currentStep < 3) ...[
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Back'),
                        ),
                      ]
                    ],
                  ),
                );
              },
              steps: [
                // Step 1: File Selection
                Step(
                  title: const Text('Step 1: Select Package File'),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Choose an OrderKartPackage zip to verify and import:'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _pickFile,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Browse Package ZIP'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  isActive: _currentStep >= 0,
                ),

                // Step 2: Database Preview
                Step(
                  title: const Text('Step 2: Database Preview'),
                  content: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Database Preview',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 12),
                          _detailedPreviewRow('Customers', 'customers'),
                          _detailedPreviewRow('Orders', 'orders'),
                          _detailedPreviewRow('Payments', 'payments'),
                          _detailedPreviewRow('Items', 'items'),
                          _detailedPreviewRow('Expenses', 'expenses'),
                          _previewPhotosRow(_incomingPhotosCount),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Duplicate Phone Numbers:', style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                                Text('$_duplicatePhonesCount', style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Deleted Records:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const Text('0 (Preserved)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_manifest.isNotEmpty) ...[
                            const Divider(),
                            Text('Exported By: ${_manifest['generated_by_worker_name'] ?? _manifest['device_name']}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  isActive: _currentStep >= 1,
                ),

                // Step 3: Module & Conflict Resolution Settings
                Step(
                  title: const Text('Step 3: Configurations & Conflict Resolution'),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Conflicts header
                      if (_conflicts.isNotEmpty) ...[
                        const Text('Conflicts Detected:',
                            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.error, fontSize: 14)),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _conflicts.length,
                            itemBuilder: (ctx, index) {
                              final c = _conflicts[index];
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${c.name} (${c.field})',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Local: ${c.localValue}', style: const TextStyle(fontSize: 11)),
                                          Text('Incoming: ${c.incomingValue}', style: const TextStyle(fontSize: 11)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          _resolutionOption(c, 'keep_owner', 'Keep Owner'),
                                          _resolutionOption(c, 'accept_worker', 'Accept Worker'),
                                          _resolutionOption(c, 'merge', 'Merge'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SwitchListTile(
                          dense: true,
                          title: const Text('Apply resolution decision to all conflicts', style: TextStyle(fontSize: 12)),
                          value: _applyToAllSimilar,
                          onChanged: (v) => setState(() => _applyToAllSimilar = v),
                        ),
                        const Divider(),
                      ],

                      const Text('Choose Modules to Import:',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        dense: true,
                        title: const Text('Import Entire Database',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        value: _importEntireDb,
                        onChanged: (v) {
                          setState(() {
                            _importEntireDb = v!;
                            if (_importEntireDb) {
                              _importAreas = true;
                              _importStreets = true;
                              _importCustomers = true;
                              _importOrders = true;
                              _importItems = true;
                              _importExpenses = true;
                              _importWorkers = true;
                              _importSettings = true;
                            }
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                      if (!_importEntireDb) ...[
                        const Divider(),
                        _moduleCheck('Import Areas', _importAreas, (v) => setState(() => _importAreas = v!)),
                        _moduleCheck('Import Streets', _importStreets, (v) => setState(() => _importStreets = v!)),
                        _moduleCheck('Import Customers', _importCustomers, (v) => setState(() => _importCustomers = v!)),
                        _moduleCheck('Import Orders & Payments', _importOrders, (v) => setState(() => _importOrders = v!)),
                        _moduleCheck('Import Items', _importItems, (v) => setState(() => _importItems = v!)),
                        _moduleCheck('Import Expenses', _importExpenses, (v) => setState(() => _importExpenses = v!)),
                        _moduleCheck('Import Field Visit Notes', _importNotes, (v) => setState(() => _importNotes = v!)),
                        _moduleCheck('Import Workers & Reports', _importWorkers, (v) => setState(() => _importWorkers = v!)),
                        _moduleCheck('Import Settings & UPI Details', _importSettings, (v) => setState(() => _importSettings = v!)),
                      ],
                    ],
                  ),
                  isActive: _currentStep >= 2,
                ),

                // Step 4: Merge Summary
                Step(
                  title: const Text('Step 4: Merge Complete'),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                          SizedBox(width: 10),
                          Text('Data Successfully Merged!',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                          'Outstanding balances, stock values, worker earnings, and analytics dashboards have been recalculated automatically.'),
                      const SizedBox(height: 12),
                      const Text('Merge Results:', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      for (var entry in _previewStats.entries)
                        if ((entry.value['inserted']! + entry.value['updated']!) > 0)
                          Text('• ${entry.key.toUpperCase()}: +${entry.value['inserted']} new, +${entry.value['updated']} updated'),
                    ],
                  ),
                  isActive: _currentStep >= 3,
                ),
              ],
            ),
    );
  }

  Widget _previewRow(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$title :', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(count > 0 ? '+$count' : '0',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: count > 0 ? AppColors.primary : AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _moduleCheck(String title, bool val, ValueChanged<bool?> onChanged) {
    return CheckboxListTile(
      dense: true,
      title: Text(title),
      value: val,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }

  Widget _resolutionOption(MergeConflict c, String value, String label) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            if (_applyToAllSimilar) {
              for (final x in _conflicts) {
                x.resolution = value;
              }
            } else {
              c.resolution = value;
            }
          });
        },
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _applyToAllSimilar ? _conflicts.first.resolution : c.resolution,
              onChanged: (v) {
                setState(() {
                  if (_applyToAllSimilar) {
                    for (final x in _conflicts) {
                      x.resolution = value;
                    }
                  } else {
                    c.resolution = value;
                  }
                });
              },
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}
