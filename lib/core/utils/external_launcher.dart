import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/snackbar_helper.dart';

class ExternalLauncher {
  ExternalLauncher._();

  static Future<void> launchCall(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) {
      SnackbarHelper.showError(context, 'Phone number is missing');
      return;
    }
    final url = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (context.mounted) {
          SnackbarHelper.showError(context, 'Could not launch dialer for number: $phone');
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Failed to make phone call: $e');
      }
    }
  }

  static Future<void> launchWhatsApp(BuildContext context, String phone, {String? text}) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) {
      if (text != null) {
        Share.share(text);
      } else {
        SnackbarHelper.showError(context, 'WhatsApp number is missing');
      }
      return;
    }
    final finalPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final encodedText = text != null ? Uri.encodeComponent(text) : '';
    final nativeUrl  = Uri.parse('whatsapp://send?phone=$finalPhone${encodedText.isNotEmpty ? "&text=$encodedText" : ""}');
    final webUrl     = Uri.parse('https://wa.me/$finalPhone${encodedText.isNotEmpty ? "?text=$encodedText" : ""}');

    try {
      if (await canLaunchUrl(nativeUrl)) {
        await launchUrl(nativeUrl, mode: LaunchMode.externalApplication);
        return;
      }
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        return;
      }
      // Last resort: Share sheet
      if (text != null) {
        Share.share(text);
      } else {
        SnackbarHelper.showError(context, 'Could not open WhatsApp. Make sure it is installed.');
      }
    } catch (e) {
      if (text != null) {
        Share.share(text);
      } else if (context.mounted) {
        SnackbarHelper.showError(context, 'Could not launch WhatsApp: $e');
      }
    }
  }

  static Future<void> openMap(BuildContext context, String mapsLocation) async {
    final cleanLoc = mapsLocation.trim();
    if (cleanLoc.isEmpty) {
      SnackbarHelper.showError(context, 'No location saved for this customer.');
      return;
    }

    Uri uri;
    if (cleanLoc.startsWith('http')) {
      uri = Uri.parse(cleanLoc);
    } else {
      final parts = cleanLoc.split(',');
      if (parts.length != 2 || double.tryParse(parts[0].trim()) == null || double.tryParse(parts[1].trim()) == null) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Invalid Location'),
            content: Text('The saved coordinates "$cleanLoc" are invalid. Please edit them in customer settings (use format: latitude,longitude).'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(_),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      uri = Uri.parse('google.navigation:q=${cleanLoc.trim()}');
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final fallbackUri = cleanLoc.startsWith('http')
            ? uri
            : Uri.parse('https://www.google.com/maps/search/?api=1&query=${cleanLoc.trim()}');
            
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            SnackbarHelper.showError(context, 'Could not launch Maps app or browser fallback.');
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Failed to open Google Maps: $e');
      }
    }
  }
}
