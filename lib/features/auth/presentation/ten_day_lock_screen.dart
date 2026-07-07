import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/snackbar_helper.dart';

class TenDayLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const TenDayLockScreen({super.key, required this.onUnlocked});

  @override
  State<TenDayLockScreen> createState() => _TenDayLockScreenState();
}

class _TenDayLockScreenState extends State<TenDayLockScreen> {
  final List<int> _pin = [];
  bool _loading = false;

  void _keyTap(int digit) {
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
    if (_pin.isNotEmpty) {
      AppHaptics.buttonClick();
      setState(() {
        _pin.removeLast();
      });
    }
  }

  void _clear() {
    AppHaptics.buttonClick();
    setState(() {
      _pin.clear();
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _loading = true);
    final enteredPin = _pin.join();

    await Future.delayed(const Duration(milliseconds: 300)); // subtle realism delay

    if (enteredPin == '124357') {
      AppHaptics.success();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_10day_unlock_time', DateTime.now().millisecondsSinceEpoch);
      widget.onUnlocked();
    } else {
      AppHaptics.error();
      if (mounted) {
        SnackbarHelper.showError(context, 'Incorrect PIN. Hint: Check the instruction file.');
        setState(() {
          _pin.clear();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Ultra-premium deep slate/dark theme
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // --- APP ICON / LOGO ---
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          size: 38,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- SECURITY LOCK TITLES ---
                      const Text(
                        'Security Renewal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'For security compliance, please renew app access with your security PIN.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),

                      const Spacer(),

                      // --- PIN DOTS DISPLAY ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          final active = index < _pin.length;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: active ? AppColors.primary : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: active ? AppColors.primary : Colors.white24,
                                width: 2,
                              ),
                            ),
                          );
                        }),
                      ),

                      const Spacer(),

                      // --- KEYPAD ---
                      if (_loading)
                        const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      else
                        _buildKeypad(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
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
              // Clear Button
              IconButton(
                iconSize: 26,
                icon: const Icon(Icons.clear_rounded, color: Colors.white38),
                onPressed: _clear,
              ),
              _keyButton(0),
              // Backspace Button
              IconButton(
                iconSize: 26,
                icon: const Icon(Icons.backspace_outlined, color: Colors.white60),
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
          color: Colors.white.withOpacity(0.04),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        alignment: Alignment.center,
        child: Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
