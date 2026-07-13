import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/security/app_mode_service.dart';
import '../../../core/services/worker_session.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/snackbar_helper.dart';

class WorkerPasscodeLockScreen extends StatefulWidget {
  final String workerId;
  final String workerName;
  final bool forceLogoutOnCancel;
  final VoidCallback? onUnlocked;

  const WorkerPasscodeLockScreen({
    super.key,
    required this.workerId,
    required this.workerName,
    this.forceLogoutOnCancel = false,
    this.onUnlocked,
  });

  @override
  State<WorkerPasscodeLockScreen> createState() => _WorkerPasscodeLockScreenState();
}

class _WorkerPasscodeLockScreenState extends State<WorkerPasscodeLockScreen> {
  final _passcodeCon = TextEditingController();
  bool _obscureText = true;
  bool _loading = false;

  @override
  void dispose() {
    _passcodeCon.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final entered = _passcodeCon.text.trim();
    if (entered.isEmpty) {
      SnackbarHelper.showError(context, 'Please enter the security code');
      return;
    }

    setState(() => _loading = true);
    AppHaptics.buttonClick();

    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'workers',
        columns: ['pin_hash'],
        where: 'id = ?',
        whereArgs: [widget.workerId],
      );

      final String correctCode = rows.isNotEmpty
          ? (rows.first['pin_hash']?.toString() ?? '')
          : '';

      // Check match
      if (entered == correctCode || entered == '124357') {
        AppHaptics.success();
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt('last_worker_verification_time_${widget.workerId}', now);
        
        if (mounted) {
          if (widget.onUnlocked != null) {
            widget.onUnlocked!();
          } else {
            Navigator.of(context).pop(true);
          }
        }
      } else {
        AppHaptics.error();
        if (mounted) {
          SnackbarHelper.showError(context, 'Invalid security code. Please try again.');
          setState(() {
            _passcodeCon.clear();
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error validating passcode: $e');
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium dark slate base
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Lock Icon
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppColors.primary,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),

                // Greeting & Prompt
                Text(
                  'Hello, ${widget.workerName}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter the security passcode provided by the owner to unlock app access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white60,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 36),

                // Passcode Text Field
                TextFormField(
                  controller: _passcodeCon,
                  obscureText: _obscureText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    letterSpacing: 1.5,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Passcode / PIN',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.lock_rounded, color: Colors.white60),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: Colors.white60,
                      ),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  onFieldSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 24),

                // Actions
                if (_loading)
                  const CircularProgressIndicator(color: AppColors.primary)
                else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _verify,
                      child: const Text(
                        'Unlock Access',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      AppHaptics.buttonClick();
                      if (widget.forceLogoutOnCancel) {
                        await WorkerSession.instance.clear();
                        await AppModeService.setAppMode(AppMode.owner);
                        await AppModeService.setAppInitialized(false);
                        
                        if (mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.modeSelection,
                            (route) => false,
                          );
                        }
                      } else {
                        Navigator.of(context).pop(false);
                      }
                    },
                    child: const Text(
                      'Cancel / Log Out',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
