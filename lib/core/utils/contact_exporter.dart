import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/snackbar_helper.dart';

class ContactExporter {
  ContactExporter._();

  /// Generates a .vcf (vCard 3.0) file and prompts the device contacts app or share sheet to save it
  static Future<void> saveCustomerToContacts(
    BuildContext context, {
    required String name,
    required String phone,
    String address = '',
    String notes = '',
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      SnackbarHelper.showError(context, 'No valid phone number to save');
      return;
    }

    final vCardBuffer = StringBuffer()
      ..writeln('BEGIN:VCARD')
      ..writeln('VERSION:3.0')
      ..writeln('FN:$name')
      ..writeln('TEL;TYPE=CELL,VOICE:$cleanPhone')
      ..writeln('NOTE:OrderKart Customer ${address.isNotEmpty ? "- $address" : ""}')
      ..writeln('END:VCARD');

    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = name.replaceAll(RegExp(r'[^\w\s]'), '').trim().replaceAll(' ', '_');
      final file = File('${tempDir.path}/$sanitizedName.vcf');
      await file.writeAsString(vCardBuffer.toString());

      // Attempt to open directly via system vCard handler
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (context.mounted) {
          SnackbarHelper.showSuccess(context, 'Opening contacts app for $name...');
        }
        return;
      }

      // Fallback: system share sheet (User selects Contacts app / Google Contacts)
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/vcard')],
        subject: 'Save $name to Contacts',
      );
      if (context.mounted) {
        SnackbarHelper.showSuccess(context, 'vCard generated for $name!');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Failed to save contact: $e');
      }
    }
  }
}
