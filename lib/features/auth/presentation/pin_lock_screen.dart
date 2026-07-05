// lib/features/auth/presentation/pin_lock_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/security/app_mode_service.dart';
import '../../../core/services/worker_session.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/security_helper.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/snackbar_helper.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  final List<int> _pin = [];
  String _targetName = 'User';
  bool _isWorker = false;
  bool _loading = false;
  int _lockoutTimeRemaining = 0;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _determineUser();
    _checkLockoutStatus();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockoutStatus() async {
    if (_isWorker) return;
    final remaining = await AppModeService.getRemainingLockoutTime();
    if (remaining > 0) {
      setState(() {
        _lockoutTimeRemaining = remaining;
      });
      _startLockoutTimer();
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutTimeRemaining <= 1) {
        timer.cancel();
        setState(() {
          _lockoutTimeRemaining = 0;
        });
      } else {
        setState(() {
          _lockoutTimeRemaining--;
        });
      }
    });
  }

  Future<void> _determineUser() async {
    final mode = await AppModeService.getAppMode();
    if (mode == AppMode.worker) {
      await WorkerSession.instance.load();
      final workerId = WorkerSession.instance.currentWorkerId;
      if (workerId != null && workerId.isNotEmpty) {
        final db = await DatabaseHelper.instance.database;
        final res = await db.query('workers', where: 'id = ?', whereArgs: [workerId]);
        if (res.isNotEmpty) {
          setState(() {
            _targetName = res.first['name'] as String? ?? 'Worker';
            _isWorker = true;
          });
          return;
        }
      }
      setState(() {
        _targetName = 'Worker';
        _isWorker = true;
      });
    } else {
      setState(() {
        _targetName = 'Master Owner';
        _isWorker = false;
      });
      await _checkLockoutStatus();
    }
  }

  void _keyTap(int digit) {
    if (_lockoutTimeRemaining > 0 && !_isWorker) {
      AppHaptics.error();
      return;
    }
    if (_pin.length < 6) {
      AppHaptics.buttonClick();
      setState(() {
        _pin.add(digit);
      });
      if (_pin.length == 6) {
        _verifyPin();
      }
    }
  }

  void _backspace() {
    if (_lockoutTimeRemaining > 0 && !_isWorker) {
      AppHaptics.error();
      return;
    }
    if (_pin.isNotEmpty) {
      AppHaptics.buttonClick();
      setState(() {
        _pin.removeLast();
      });
    }
  }

  Future<void> _verifyPin() async {
    if (!_isWorker) {
      final remaining = await AppModeService.getRemainingLockoutTime();
      if (remaining > 0) {
        AppHaptics.error();
        SnackbarHelper.showError(context, 'Locked out. Please wait $remaining seconds.');
        setState(() {
          _pin.clear();
        });
        return;
      }
    }

    setState(() => _loading = true);
    final enteredPin = _pin.join();
    bool validated = false;

    try {
      if (_isWorker) {
        final workerId = WorkerSession.instance.currentWorkerId;
        if (workerId != null) {
          final db = await DatabaseHelper.instance.database;
          final res = await db.query('workers', where: 'id = ?', whereArgs: [workerId]);
          if (res.isNotEmpty) {
            final storedHash = res.first['pin_hash'] as String? ?? '';
            final enteredHash = SecurityHelper.hashPin(enteredPin);
            
            // If worker hasn't set a pin yet (e.g. fresh import), let them set it!
            if (storedHash.isEmpty) {
              await db.update('workers', {'pin_hash': enteredHash}, where: 'id = ?', whereArgs: [workerId]);
              validated = true;
              if (mounted) {
                SnackbarHelper.showSuccess(context, 'Security PIN established successfully!');
              }
            } else {
              validated = (enteredHash == storedHash);
            }
          }
        }
      } else {
        validated = await AppModeService.verifyOwnerPin(enteredPin);
      }

      if (validated) {
        AppHaptics.buttonClick();
        if (mounted) {
          if (_isWorker) {
            Navigator.of(context).pushReplacementNamed(AppRoutes.workerDashboard);
          } else {
            AppModeService.loginOwnerSuccess();
            Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
          }
        }
      } else {
        AppHaptics.error();
        if (!_isWorker) {
          await _checkLockoutStatus();
        }
        if (mounted) {
          if (_lockoutTimeRemaining > 0) {
            SnackbarHelper.showError(context, 'Incorrect PIN. Locked out for $_lockoutTimeRemaining seconds.');
          } else {
            SnackbarHelper.showError(context, 'Incorrect security PIN. Please try again.');
          }
          setState(() {
            _pin.clear();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Authentication error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            
            // --- HEADER INFO ---
            const Icon(Icons.lock_rounded, size: 54, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Welcome Back, $_targetName',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              _lockoutTimeRemaining > 0 && !_isWorker
                  ? 'Too many failed attempts. Try again in $_lockoutTimeRemaining seconds'
                  : 'Enter your 6-digit security PIN to unlock:',
              style: TextStyle(
                color: _lockoutTimeRemaining > 0 && !_isWorker ? Colors.redAccent : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: _lockoutTimeRemaining > 0 && !_isWorker ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            
            const Spacer(),
            
            // --- PIN DOTS DISPLAY ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final active = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                );
              }),
            ),
            
            const Spacer(),
            
            // --- KEYPAD ---
            _buildKeypad(),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _keyButton(1),
              _keyButton(2),
              _keyButton(3),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _keyButton(4),
              _keyButton(5),
              _keyButton(6),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _keyButton(7),
              _keyButton(8),
              _keyButton(9),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Clear button
              IconButton(
                iconSize: 28,
                icon: const Icon(Icons.logout_rounded, color: Colors.white54),
                onPressed: () {
                  AppHaptics.buttonClick();
                  WorkerSession.instance.clear();
                  Navigator.of(context).pushReplacementNamed(AppRoutes.modeSelection);
                },
              ),
              _keyButton(0),
              // Backspace button
              IconButton(
                iconSize: 28,
                icon: const Icon(Icons.backspace_outlined, color: Colors.white70),
                onPressed: _backspace,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keyButton(int value) {
    return InkWell(
      onTap: () => _keyTap(value),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        alignment: Alignment.center,
        child: Text(
          '$value',
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
