import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import 'settings_provider.dart';

class ImportWizardScreen extends ConsumerStatefulWidget {
  const ImportWizardScreen({super.key});

  @override
  ConsumerState<ImportWizardScreen> createState() => _ImportWizardScreenState();
}

class _ImportWizardScreenState extends ConsumerState<ImportWizardScreen> {
  int _currentStep = 0;
  bool _loading = false;

  File? _selectedFile;
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
  bool _importWorkers = true;
  bool _importSettings = true;

  Future<void> _pickFile() async {
    setState(() => _loading = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final srcPath = result.files.first.path!;
      _selectedFile = File(srcPath);
      final tempDir = await getTemporaryDirectory();
      _incomingPhotosCount = 0;

      if (srcPath.toLowerCase().endsWith('.zip')) {
        final bytes = await _selectedFile!.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        List<int>? dbData;
        String? manifestStr;

        for (final f in archive) {
          if (f.name == 'orderkart.db' && f.isFile) {
            dbData = f.content as List<int>;
          } else if (f.name == 'manifest.json' && f.isFile) {
            manifestStr = utf8.decode(f.content as List<int>);
          }
        }

        if (dbData == null) throw Exception('Invalid package: zip missing orderkart.db');

        final tempDb = File('${tempDir.path}/wizard_incoming.db');
        await tempDb.writeAsBytes(dbData);
        _dbFileToMerge = tempDb.path;

        if (manifestStr != null) {
          _manifest = jsonDecode(manifestStr) as Map<String, dynamic>;
        }

        // Count photo files & extract them
        for (final f in archive) {
          final norm = f.name.replaceAll('\\', '/');
          if (f.isFile && norm.startsWith('customer_photos/')) {
            _incomingPhotosCount++;
            final filename = p.basename(norm);
            final dest = File('${AppConstants.appDocsDir}/customer_photos/$filename');
            if (!dest.existsSync()) {
              await dest.parent.create(recursive: true);
              await dest.writeAsBytes(f.content as List<int>);
            }
          }
        }
      } else {
        _dbFileToMerge = srcPath;
      }

      // Generate preview counts (DRY RUN - does not write to target db!)
      _previewStats = await DatabaseHelper.instance.mergeDatabaseFromPath(
        _dbFileToMerge,
        dryRun: true,
      );

      setState(() {
        _currentStep = 1; // Move to Step 2: Database Preview
      });
    } catch (e) {
      SnackbarHelper.showError(context, 'Failed to parse package: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _executeMerge() async {
    setState(() => _loading = true);
    try {
      AppHaptics.buttonClick();

      // Compile selected modules for actual merge
      final selectedModules = <String>[];
      if (_importEntireDb) selectedModules.add('entire_db');
      if (_importAreas) selectedModules.add('areas');
      if (_importStreets) selectedModules.add('streets');
      if (_importCustomers) selectedModules.add('customers');
      if (_importOrders) selectedModules.add('orders');
      if (_importItems) selectedModules.add('items');
      if (_importExpenses) selectedModules.add('expenses');
      if (_importWorkers) selectedModules.add('workers');
      if (_importSettings) selectedModules.add('settings');

      // Execute merge (dryRun = false)
      final finalStats = await DatabaseHelper.instance.mergeDatabaseFromPath(
        _dbFileToMerge,
        selectedModules: selectedModules,
        dryRun: false,
      );

      ref.read(settingsProvider.notifier).load();

      setState(() {
        _previewStats = finalStats;
        _currentStep = 3; // Step 4: Merge complete
      });
    } catch (e) {
      SnackbarHelper.showError(context, 'Merge failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Import Wizard',
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Stepper(
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep == 1) {
                  setState(() => _currentStep = 2); // Step 3: Module Selection
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
                      const Text('Choose a database package (.zip or .db) to begin synchronization:'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _pickFile,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Browse Package File'),
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
                          _previewRow('Customers', _previewStats['customers']?['inserted'] ?? 0),
                          _previewRow('Orders', _previewStats['orders']?['inserted'] ?? 0),
                          _previewRow('Payments', _previewStats['payments']?['inserted'] ?? 0),
                          _previewRow('Items', _previewStats['items']?['inserted'] ?? 0),
                          _previewRow('Expenses', _previewStats['expenses']?['inserted'] ?? 0),
                          _previewRow('Photos', _incomingPhotosCount),
                          const SizedBox(height: 12),
                          if (_manifest.isNotEmpty) ...[
                            const Divider(),
                            Text('Exported By: ${_manifest['worker_name'] ?? _manifest['device_name']}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  isActive: _currentStep >= 1,
                ),

                // Step 3: Module Selection for Import
                Step(
                  title: const Text('Step 3: Select Modules to Import'),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Choose what data you want to merge into your database:',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
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
                          'Outstanding balances, stock, benefits, worker earnings, and analytics dashboards have been recalculated automatically.'),
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
}
