import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../security/app_mode_service.dart';
import '../utils/haptics.dart';
import 'snackbar_helper.dart';

class OwnerPinDialog extends StatefulWidget {
  final String title;
  final String subtitle;

  const OwnerPinDialog({
    super.key,
    this.title = 'Owner Verification',
    this.subtitle = 'Enter 6-digit Owner PIN to proceed',
  });

  /// Static helper method to prompt for PIN anywhere in the app
  static Future<bool> verify(BuildContext context, {String? title, String? subtitle}) async {
    AppModeService.loginOwnerSuccess();
    return true; // Password disabled for now per user request
  }

  @override
  State<OwnerPinDialog> createState() => _OwnerPinDialogState();
}

class _OwnerPinDialogState extends State<OwnerPinDialog> {
  final List<String> _pin = [];
  bool _loading = false;
  bool _error = false;

  void _onKeyPress(String val) {
    if (_pin.length < 6) {
      AppHaptics.buttonClick();
      setState(() {
        _error = false;
        _pin.add(val);
      });
      if (_pin.length == 6) {
        _submitPin();
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      AppHaptics.buttonClick();
      setState(() {
        _error = false;
        _pin.removeLast();
      });
    }
  }

  Future<void> _submitPin() async {
    setState(() => _loading = true);
    final pinStr = _pin.join();
    final isValid = await AppModeService.verifyOwnerPin(pinStr);

    if (!mounted) return;
    setState(() => _loading = false);

    if (isValid) {
      AppHaptics.success();
      Navigator.of(context).pop(true);
    } else {
      AppHaptics.error();
      setState(() {
        _error = true;
        _pin.clear();
      });
      SnackbarHelper.showError(context, 'Incorrect Owner PIN');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // PIN Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (idx) {
                final isFilled = idx < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _error
                        ? AppColors.error
                        : (isFilled ? AppColors.primary : AppColors.gray300),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),
            if (_loading)
              const CircularProgressIndicator()
            else
              _buildKeypad(),

            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((digit) => _keypadButton(digit)).toList(),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 56, height: 56), // spacer
            _keypadButton('0'),
            IconButton(
              iconSize: 26,
              icon: const Icon(Icons.backspace_outlined, color: AppColors.textPrimary),
              onPressed: _onDelete,
            ),
          ],
        ),
      ],
    );
  }

  Widget _keypadButton(String digit) {
    return InkWell(
      onTap: () => _onKeyPress(digit),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.gray100,
          shape: BoxShape.circle,
        ),
        child: Text(
          digit,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
