import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/security/app_mode_service.dart';
import '../../../core/services/package_validator.dart';
import '../../../core/services/worker_session.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/snackbar_helper.dart';
import 'welcome_splash_screen.dart';

class ModeSelectionScreen extends ConsumerStatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  ConsumerState<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends ConsumerState<ModeSelectionScreen> {
  AppMode _selectedMode = AppMode.owner;
  bool _loading = false;

  final _activationCodeCon = TextEditingController();
  final _pinCon = TextEditingController();
  final _confirmPinCon = TextEditingController();
  final _workerNameCon = TextEditingController();
  final _workerIdCon = TextEditingController();

  @override
  void dispose() {
    _activationCodeCon.dispose();
    _pinCon.dispose();
    _confirmPinCon.dispose();
    _workerNameCon.dispose();
    _workerIdCon.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    AppHaptics.buttonClick();
    if (_selectedMode == AppMode.owner) {
      _showOwnerSetupDialog();
    } else {
      _importOwnerProvisioningZip();
    }
  }

  void _showOwnerSetupDialog() {
    _activationCodeCon.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 26),
            SizedBox(width: 10),
            Text('Owner Activation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 6-digit Owner Activation Code to register as Master Owner:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _activationCodeCon,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 18),
              decoration: const InputDecoration(
                hintText: 'Enter Code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await AppModeService.validateActivationCode(_activationCodeCon.text);
              if (ok) {
                if (ctx.mounted) Navigator.pop(ctx);
                _showOwnerPinCreationDialog();
              } else {
                AppHaptics.error();
                if (context.mounted) {
                  SnackbarHelper.showError(context, 'code 1 error');
                }
              }
            },
            child: const Text('Verify Code'),
          ),
        ],
      ),
    );
  }

  void _showOwnerPinCreationDialog() {
    _pinCon.clear();
    _confirmPinCon.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: AppColors.primary, size: 26),
            SizedBox(width: 10),
            Text('Create Owner PIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a 6-digit security PIN to protect Master Settings, Inventory, Prices, Reports & Backups:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinCon,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 4, fontSize: 18),
              decoration: const InputDecoration(
                hintText: 'Enter 6-Digit PIN',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPinCon,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 4, fontSize: 18),
              decoration: const InputDecoration(
                hintText: 'Confirm PIN',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_clock_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = _pinCon.text.trim();
              final confirm = _confirmPinCon.text.trim();
              if (pin.length != 6 || !RegExp(r'^\d+$').hasMatch(pin)) {
                SnackbarHelper.showError(context, 'PIN must be exactly 6 digits');
                return;
              }
              if (pin != confirm) {
                SnackbarHelper.showError(context, 'PINs do not match!');
                return;
              }

              Navigator.pop(ctx);
              await _completeOwnerSetup(pin);
            },
            child: const Text('Save PIN & Finish'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeOwnerSetup(String pin) async {
    setState(() => _loading = true);
    try {
      await AppModeService.setOwnerPin(pin);
      await AppModeService.setAppMode(AppMode.owner);
      await AppModeService.setAppInitialized(true);

      if (!mounted) return;
      ref.invalidate(appModeProvider);
      SnackbarHelper.showSuccess(context, 'Owner Mode Activated Successfully!');
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.welcome,
        arguments: WelcomeSplashScreenArgs(
          name: 'Nayan',
          nextRoute: AppRoutes.dashboard,
        ),
      );
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Setup failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showWorkerSetupDialog() {
    _workerNameCon.clear();
    _workerIdCon.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: AppColors.primary, size: 26),
            SizedBox(width: 10),
            Text('Worker Registration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your name and optional Employee ID to configure this device for Worker Mode:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _workerNameCon,
              decoration: const InputDecoration(
                labelText: 'Worker Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _workerIdCon,
              decoration: const InputDecoration(
                labelText: 'Employee ID (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.confirmation_number_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_workerNameCon.text.trim().isEmpty) {
                SnackbarHelper.showError(context, 'Worker Name is required');
                return;
              }
              Navigator.pop(ctx);
              await _completeWorkerSetup();
            },
            child: const Text('Start Worker App'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeWorkerSetup() async {
    setState(() => _loading = true);
    try {
      final name = _workerNameCon.text.trim();
      final empId = _workerIdCon.text.trim();
      final workerId = empId.isNotEmpty ? empId : 'worker_${const Uuid().v4().substring(0, 8)}';

      final db = await DatabaseHelper.instance.database;
      final nowStr = DateTime.now().toIso8601String();
      await db.insert('workers', {
        'id': workerId,
        'name': name,
        'created_at': nowStr,
        'pin_hash': '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await WorkerSession.instance.setWorker(workerId, workerName: name);
      await AppModeService.setAppMode(AppMode.worker);
      await AppModeService.setAppInitialized(true);

      if (!mounted) return;
      ref.invalidate(appModeProvider);
      SnackbarHelper.showSuccess(context, 'Worker Mode Configured Successfully!');
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.welcome,
        arguments: WelcomeSplashScreenArgs(
          name: name,
          nextRoute: AppRoutes.workerDashboard,
        ),
      );
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Setup failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importOwnerProvisioningZip() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result == null || result.files.single.path == null) return;

      setState(() => _loading = true);
      final filePath = result.files.single.path!;

      final validation = await PackageValidator.validatePackage(filePath);
      if (!validation.isValid) {
        if (mounted) {
          SnackbarHelper.showError(context, 'Invalid Package: ${validation.errorMessage}');
        }
        setState(() => _loading = false);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final bytes = File(filePath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      final extractedDbPath = validation.dbPath;
      if (extractedDbPath.isEmpty || !File(extractedDbPath).existsSync()) {
        if (mounted) SnackbarHelper.showError(context, 'No database found in package');
        setState(() => _loading = false);
        return;
      }

      await DatabaseHelper.instance.mergeDatabaseFromPath(
        extractedDbPath,
        selectedModules: ['entire_db'],
      );

      final workerId = validation.manifest['generated_by_worker_id'] as String?;
      final workerName = validation.manifest['generated_by_worker_name'] as String? ?? 'Worker';
      if (workerId != null) {
        await WorkerSession.instance.setWorker(workerId, workerName: workerName);
      }

      await AppModeService.setAppMode(AppMode.worker);
      await AppModeService.setAppInitialized(true);

      if (!mounted) return;
      ref.invalidate(appModeProvider);
      SnackbarHelper.showSuccess(context, '🎉 Worker Device Provisioned!');
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.welcome,
        arguments: WelcomeSplashScreenArgs(
          name: workerName,
          nextRoute: AppRoutes.workerDashboard,
        ),
      );
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Provisioning import failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to OrderKart',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select Application Mode for this device:',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),

              // Mode Cards
              _buildModeOption(
                mode: AppMode.owner,
                title: 'Owner Mode (Master)',
                subtitle: 'Full Business Access, Inventory Control, Reports, PIN Security & Worker Assignments.',
                icon: Icons.admin_panel_settings_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              _buildModeOption(
                mode: AppMode.worker,
                title: 'Worker Mode (Child)',
                subtitle: 'Assigned Areas, Create Orders, Collect Payments, Track Earnings & Offline Sync.',
                icon: Icons.badge_rounded,
                color: const Color(0xFF0EA5E9),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _proceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _selectedMode == AppMode.owner ? 'Continue as Owner' : 'Continue as Worker',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // --- PROVISIONING PACKAGE BUTTON FOR WORKERS ---
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _importOwnerProvisioningZip,
                  icon: const Icon(Icons.download_for_offline_rounded, color: Color(0xFF0284C7)),
                  label: const Text('Apply Owner Provisioning ZIP (.orderkart)',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0284C7))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required AppMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.gray200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
              : AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? color : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? color : AppColors.gray400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
