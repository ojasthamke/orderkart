import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/snackbar_helper.dart';
import '../utils/haptics.dart';

class ContactExporter {
  ContactExporter._();

  /// Copies customer name with suffix "(CUSTOMER)" to clipboard and loads phone on dialer
  static Future<void> saveCustomerToContacts(
    BuildContext context, {
    required String name,
    required String phone,
    String address = '',
    String notes = '',
  }) async {
    AppHaptics.buttonClick();
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleanPhone.isEmpty) {
      SnackbarHelper.showError(
          context, 'No valid phone number to save for $name');
      return;
    }

    try {
      // 1. Copy the name to clipboard with suffix (CUSTOMER)
      final nameWithSuffix = '$name (CUSTOMER)';
      await Clipboard.setData(ClipboardData(text: nameWithSuffix));

      // 2. Open the dial pad
      final telUri = Uri.parse('tel:$cleanPhone');
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
        if (context.mounted) {
          SnackbarHelper.showSuccess(
            context,
            'Copied "$nameWithSuffix" to clipboard & loaded dial pad!',
          );
        }
      } else {
        throw 'Could not launch dialer app';
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Failed: $e');
      }
    }
  }
}
