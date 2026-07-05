import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/snackbar_helper.dart';
import '../utils/haptics.dart';

class ContactExporter {
  ContactExporter._();

  /// Generates a .vcf (vCard 3.0) file and shares/opens it in Contacts app
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
      SnackbarHelper.showError(context, 'No valid phone number to save for $name');
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = name.replaceAll(RegExp(r'[^\w\s]'), '').trim().replaceAll(' ', '_');
      final fileName = sanitizedName.isEmpty ? 'customer_contact' : sanitizedName;
      final file = File('${tempDir.path}/$fileName.vcf');

      final vCardContent = [
        'BEGIN:VCARD',
        'VERSION:3.0',
        'N:;${name.trim()};;;',
        'FN:${name.trim()}',
        'TEL;TYPE=CELL,VOICE:$cleanPhone',
        if (address.trim().isNotEmpty) 'ADR;TYPE=HOME:;;${address.trim()};;;;',
        'NOTE:OrderKart Customer ${notes.trim().isNotEmpty ? " - " + notes.trim() : ""}',
        'END:VCARD',
      ].join('\r\n');

      await file.writeAsString(vCardContent);

      // Share XFile opens Android/iOS Contacts importer or system share sheet
      final xFile = XFile(file.path, name: '$fileName.vcf');
      await Share.shareXFiles(
        [xFile],
        text: 'Save contact for $name ($cleanPhone)',
        subject: 'Save $name to Contacts',
      );

      if (context.mounted) {
        SnackbarHelper.showSuccess(context, 'vCard created for $name!');
      }
    } catch (e) {
      // Fallback: Launch phone dialer if vCard sharing fails
      try {
        final telUri = Uri.parse('tel:$cleanPhone');
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
        }
      } catch (_) {}

      if (context.mounted) {
        SnackbarHelper.showInfo(context, 'vCard created for $name ($cleanPhone)');
      }
    }
  }
}
