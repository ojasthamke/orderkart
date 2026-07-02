import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';

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
            title:    'Export',
            icon:     Icons.upload_rounded,
            iconColor: AppColors.success,
            children: [
              _ActionTile(
                icon:     Icons.storage_rounded,
                title:    'Export Database File',
                subtitle: 'Share the SQLite .db file',
                onTap:    _exportDatabase,
                loading:  _loading,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title:    'Import',
            icon:     Icons.download_rounded,
            iconColor: AppColors.primary,
            children: [
              _ActionTile(
                icon:     Icons.folder_open_rounded,
                title:    'Restore from File',
                subtitle: 'Pick a .db backup file',
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

  Future<void> _exportDatabase() async {
    setState(() => _loading = true);
    try {
      final dbPath = await DatabaseHelper.instance.database.then((db) => db.path);
      final dbFile = File(dbPath);
      if (!dbFile.existsSync()) {
        SnackbarHelper.showError(context, 'Database file not found');
        return;
      }
      // Copy to application documents directory
      final dir  = await getApplicationDocumentsDirectory();
      final dest = File('${dir.path}/orderkart_backup.db');
      await dbFile.copy(dest.path);
      await Share.shareXFiles([XFile(dest.path)],
          subject: 'OrderKart Database Backup');
      if (mounted)
        SnackbarHelper.showSuccess(context, 'Database exported');
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
      final dest    = File(dbPath);

      // Close the current connection first
      await DatabaseHelper.instance.close();

      // Copy file
      await File(srcPath).copy(dest.path);

      // Reinitialize connection
      await DatabaseHelper.instance.database;

      if (mounted) {
        SnackbarHelper.showSuccess(
            context, 'Database restored successfully!');
      }
    } catch (e) {
      if (mounted)
        SnackbarHelper.showError(context, 'Restore failed: $e');
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppColors.cardShadow,
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
