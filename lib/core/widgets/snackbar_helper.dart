/// SnackbarHelper — Consistent snackbar messages with undo support
library;

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SnackbarHelper {
  SnackbarHelper._();

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Shows snackbar with undo action — returns true if user tapped Undo
  static Future<bool> showWithUndo(
    BuildContext context, {
    required String message,
    String undoLabel = 'Undo',
  }) async {
    bool undone = false;
    final messenger = ScaffoldMessenger.of(context);
    final result = await messenger
        .showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.gray900,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: undoLabel,
              textColor: Colors.amber,
              onPressed: () {
                undone = true;
              },
            ),
          ),
        )
        .closed;
    return undone || result == SnackBarClosedReason.action;
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
