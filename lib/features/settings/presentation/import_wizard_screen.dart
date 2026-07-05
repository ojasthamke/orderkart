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

        // Extract photos without overwriting existing
        for (final f in archive) {
          final norm = f.name.replaceAll('\\', '/');
          if (f.isFile && norm.startsWith('customer_photos/')) {
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

      // Generate preview counts
      _previewStats = await DatabaseHelper.instance.mergeDatabaseFromPath(_dbFileToMerge);

      setState(() {
        _currentStep = 1; // Move to Step 2: Preview
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
      final finalStats = await DatabaseHelper.instance.mergeDatabaseFromPath(_dbFileToMerge);
      ref.read(settingsProvider.notifier).load();

      setState(() {
        _previewStats = finalStats;
        _currentStep = 3; // Step 4: Finish Summary
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
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 1) {
            setState(() => _currentStep = 2); // Step 3: Conflict Approval
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: Text(_currentStep == 2 ? 'Accept & Merge' : (_currentStep == 3 ? 'Finish' : 'Next')),
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
                const Text('Pick a Worker export package (.zip or .db) to begin synchronization:'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _pickFile,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Browse Package File'),
                ),
              ],
            ),
            isActive: _currentStep >= 0,
          ),

          // Step 2: Package Preview
          Step(
            title: const Text('Step 2: Package & Record Preview'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_manifest.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Package: ${_manifest['package_type']?.toString().toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('Exported By: ${_manifest['worker_name'] ?? _manifest['device_name']}'),
                        Text('Timestamp: ${_manifest['export_timestamp']}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Incoming Record Counts:', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (var entry in _previewStats.entries)
                  if ((entry.value['inserted']! + entry.value['updated']!) > 0)
                    Text('• ${entry.key.toUpperCase()}: ${entry.value['inserted']} new, ${entry.value['updated']} updates'),
              ],
            ),
            isActive: _currentStep >= 1,
          ),

          // Step 3: Conflict Approval Workflow
          Step(
            title: const Text('Step 3: Conflict Approval'),
            content: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conflict Policy: Last-Write-Wins (LWW)\n• Existing owner data is preserved.\n• Worker modifications with newer timestamps will be updated safely.\n• Importing twice creates zero duplicates.',
                  style: TextStyle(height: 1.4),
                ),
              ],
            ),
            isActive: _currentStep >= 2,
          ),

          // Step 4: Summary & Finish
          Step(
            title: const Text('Step 4: Merge Complete'),
            content: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                    SizedBox(width: 10),
                    Text('Data Successfully Merged!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
                SizedBox(height: 8),
                Text('All customer balances, savings, commissions, and dashboards have been recalculated automatically.'),
              ],
            ),
            isActive: _currentStep >= 3,
          ),
        ],
      ),
    );
  }
}
