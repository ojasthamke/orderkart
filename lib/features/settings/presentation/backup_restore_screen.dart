import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'dialogs/export_wizard_dialog.dart';
import '../../../core/services/package_exporter.dart';
import '../../../core/services/package_validator.dart';
import '../../../core/security/app_mode_service.dart';
import '../../../core/widgets/export_filename_dialog.dart';
import '../../../core/widgets/hotspot_sync_control_card.dart';
import '../../area/presentation/area_provider.dart';
import '../../customer/presentation/customer_provider.dart';
import '../../order/presentation/order_provider.dart';
import '../../expense/presentation/expense_provider.dart';
import '../../settings/presentation/sync_history_screen.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Backup & Restore',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title:    'Export Packages',
            icon:     Icons.upload_rounded,
            iconColor: AppColors.success,
            children: [
              _ActionTile(
                icon:     Icons.backup_rounded,
                title:    'Full Business Backup',
                subtitle: 'Export entire database and files (.orderkart backup)',
                onTap:    _exportBusinessBackup,
                loading:  _loading,
              ),
              const Divider(height: 1),
              _ActionTile(
                icon:     Icons.drive_folder_upload_rounded,
                title:    'Modular Package Export',
                subtitle: 'Select Areas, Customers, Orders, Inventory, Settings to export (.zip)',
                onTap:    () => ExportWizardDialog.show(context),
                loading:  _loading,
              ),
            ],
          ),
          HotspotSyncControlCard(
            workerId: 'owner',
            workerName: 'Owner',
            onSyncCompleted: () {
              ref.invalidate(areaProvider);
              ref.invalidate(allCustomersProvider);
              ref.invalidate(orderManagementProvider);
              ref.invalidate(analyticsSummaryProvider);
              ref.invalidate(weeklyChartProvider);
              ref.invalidate(monthlyChartProvider);
              ref.invalidate(expenseProvider);
              ref.invalidate(monthlySummaryProvider);
              ref.invalidate(importHistoryProvider);
              ref.invalidate(workerSyncHistoryProvider);
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title:    'Import & Merge Data',
            icon:     Icons.download_rounded,
            iconColor: AppColors.primary,
            children: [
              _ActionTile(
                icon:     Icons.auto_mode_rounded,
                title:    '4-Step Import Wizard (Preview & Merge)',
                subtitle: 'Preview incoming record counts, review conflict policy, and merge safely',
                onTap:    () => Navigator.pushNamed(context, AppRoutes.importWizard),
                loading:  _loading,
              ),
              const Divider(height: 1),
              _ActionTile(
                icon:     Icons.folder_open_rounded,
                title:    'Full Restore from File (Overwrite)',
                subtitle: 'Replace entire database with a .db or .zip backup file',
                onTap:    _importDatabase,
                loading:  _loading,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title:    'Cloud Sync (Coming Soon)',
            icon:     Icons.cloud_rounded,
            iconColor: AppColors.gray400,
            children: [
              _ComingSoon('Google Drive Backup'),
              _ComingSoon('GitHub JSON Backup'),
              _ComingSoon('Sync to Server'),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportBusinessBackup() async {
    final defaultName = 'BusinessBackup_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}';
    final customName = await ExportFilenameDialog.show(
      context,
      defaultName: defaultName,
      extension: '.orderkart',
      title: 'Name Business Backup File',
    );
    if (customName == null) return;

    setState(() => _loading = true);
    try {
      await PackageExporter.exportPackage(
        selectedModules: ['entire_db', 'photos', 'settings'],
        customFileName: customName,
      );
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Full Business Backup "$customName" created successfully!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Export failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _isValidSqliteFile(File file) async {
    try {
      final raf = await file.open(mode: FileMode.read);
      final bytes = await raf.read(16);
      await raf.close();
      final header = String.fromCharCodes(bytes);
      return header.startsWith('SQLite format 3');
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isValidSqliteBytes(List<int> bytes) async {
    try {
      if (bytes.length < 16) return false;
      final header = String.fromCharCodes(bytes.sublist(0, 16));
      return header.startsWith('SQLite format 3');
    } catch (_) {
      return false;
    }
  }

  Future<void> _importDatabase() async {
    setState(() => _loading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final srcPath = result.files.first.path!;
      final dbPath  = await DatabaseHelper.instance.database.then((db) => db.path);

      // Preserve current active mode before replacing database file
      final currentMode = await AppModeService.getAppMode();

      // Enterprise validation & extraction (.orderkart, .zip, .db)
      final validation = await PackageValidator.validatePackage(srcPath);
      if (!validation.isValid) {
        throw Exception(validation.errorMessage);
      }

      final incomingDbPath = validation.dbPath;
      if (incomingDbPath.isEmpty || !File(incomingDbPath).existsSync()) {
        throw Exception("Could not extract a valid database from the package.");
      }

      // Close connection first
      await DatabaseHelper.instance.close();

      final dbDest = File(dbPath);
      await File(incomingDbPath).copy(dbDest.path);

      // Reinitialize connection
      await DatabaseHelper.instance.database;

      // Invalidate cache to auto-update screens
      ref.invalidate(areaProvider);
      ref.invalidate(allCustomersProvider);
      ref.invalidate(orderManagementProvider);
      ref.invalidate(analyticsSummaryProvider);
      ref.invalidate(weeklyChartProvider);
      ref.invalidate(monthlyChartProvider);
      ref.invalidate(expenseProvider);
      ref.invalidate(monthlySummaryProvider);
      ref.invalidate(importHistoryProvider);
      ref.invalidate(workerSyncHistoryProvider);

      // Restore current app mode and active session so Owner is NEVER logged out!
      await AppModeService.setAppMode(currentMode);
      if (currentMode == AppMode.owner) {
        AppModeService.loginOwnerSuccess();
      }

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Backup restored successfully!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Restore failed: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mergeImportDatabase() async {
    setState(() => _loading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final srcPath = result.files.first.path!;

      // Enterprise validation & extraction (.orderkart, .zip, .db)
      final validation = await PackageValidator.validatePackage(srcPath);
      if (!validation.isValid) {
        throw Exception(validation.errorMessage);
      }

      final dbFileToMerge = validation.dbPath;
      if (dbFileToMerge.isEmpty || !File(dbFileToMerge).existsSync()) {
        throw Exception("Could not extract a valid database from the package.");
      }

      // Perform non-destructive merge into target DB
      final stats = await DatabaseHelper.instance.mergeDatabaseFromPath(dbFileToMerge);

      // Invalidate cache to auto-update screens
      ref.invalidate(areaProvider);
      ref.invalidate(allCustomersProvider);
      ref.invalidate(orderManagementProvider);
      ref.invalidate(analyticsSummaryProvider);
      ref.invalidate(weeklyChartProvider);
      ref.invalidate(monthlyChartProvider);
      ref.invalidate(expenseProvider);
      ref.invalidate(monthlySummaryProvider);
      ref.invalidate(importHistoryProvider);
      ref.invalidate(workerSyncHistoryProvider);

      // Record in import_history table for worker updates tracking
      try {
        final db = await DatabaseHelper.instance.database;
        final manifest = validation.manifest;
        final pkgId = manifest['package_id']?.toString() ?? const Uuid().v4();
        final wId = manifest['generated_by_worker_id']?.toString() ?? '';
        final wName = manifest['generated_by_worker_name']?.toString() ?? (manifest['generated_by_name']?.toString() ?? 'Worker');
        final devName = manifest['device_name']?.toString() ?? 'Mobile Device';

        final summaryMap = <String, int>{};
        stats.forEach((key, val) {
          summaryMap[key] = (val['inserted'] ?? 0) + (val['updated'] ?? 0);
        });

        await db.insert('import_history', {
          'id': const Uuid().v4(),
          'package_id': pkgId,
          'imported_at': DateTime.now().toIso8601String(),
          'worker_id': wId,
          'worker_name': wName,
          'device_name': devName,
          'record_count': stats.values.fold<int>(0, (sum, m) => sum + ((m['inserted'] as num?)?.toInt() ?? 0) + ((m['updated'] as num?)?.toInt() ?? 0)),
          'summary_json': jsonEncode(summaryMap),
          'status': 'success',
        });
      } catch (_) {}

      if (mounted) {
        final totalInserted = stats.values.fold(0, (sum, m) => sum + (m['inserted'] ?? 0));
        final totalUpdated  = stats.values.fold(0, (sum, m) => sum + (m['updated'] ?? 0));
        final totalSkipped  = stats.values.fold(0, (sum, m) => sum + (m['skipped'] ?? 0));

        final summaryLines = stats.entries
            .where((e) => ((e.value['inserted'] ?? 0) + (e.value['updated'] ?? 0)) > 0)
            .map((e) => '• ${e.key.toUpperCase()}: ${e.value['inserted']} added, ${e.value['updated']} updated, ${e.value['skipped']} skipped')
            .join('\n');

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                SizedBox(width: 10),
                Text('Worker Data Merged!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sync Summary: $totalInserted inserted, $totalUpdated updated, $totalSkipped skipped (idempotent).\n'),
                if (summaryLines.isNotEmpty)
                  Text(summaryLines, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, height: 1.4))
                else
                  const Text('All records are already up to date!', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Great!'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Merge failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? (isDark ? const Color(0xFF0A0A0A) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1A1A1A) : AppColors.gray200,
        ),
        boxShadow: isDark ? null : AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: iconColor,
                        )),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool loading;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary)),
      trailing: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: loading ? null : onTap,
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final String title;
  const _ComingSoon(this.title);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.cloud_outlined, color: AppColors.gray400),
      title: Text(title,
          style: const TextStyle(color: AppColors.gray500)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(8)),
        child: const Text('Soon',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.gray500,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
