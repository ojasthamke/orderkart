import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          SnackbarHelper.showError(
              context, 'Could not launch dialer for number: $phone');
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Failed to make phone call: $e');
      }
    }
  }

  static Future<void> launchWhatsApp(BuildContext context, String phone,
      {String? text}) async {
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
    final nativeUrl = Uri.parse(
        'whatsapp://send?phone=$finalPhone${encodedText.isNotEmpty ? "&text=$encodedText" : ""}');
    final webUrl = Uri.parse(
        'https://wa.me/$finalPhone${encodedText.isNotEmpty ? "?text=$encodedText" : ""}');

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
      } else if (context.mounted) {
        SnackbarHelper.showError(
            context, 'Could not open WhatsApp. Make sure it is installed.');
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
      final isCoordinates = parts.length == 2 &&
          double.tryParse(parts[0].trim()) != null &&
          double.tryParse(parts[1].trim()) != null;

      if (isCoordinates) {
        uri = Uri.parse('google.navigation:q=${cleanLoc.trim()}');
      } else {
        // Fallback to address search on Google Maps
        uri = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(cleanLoc)}');
      }
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final fallbackUri = cleanLoc.startsWith('http')
            ? uri
            : Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=${cleanLoc.trim()}');

        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            SnackbarHelper.showError(
                context, 'Could not launch Maps app or browser fallback.');
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Failed to open Google Maps: $e');
      }
    }
  }

  static Future<void> launchNavigationCoordinates(
      BuildContext context, double latitude, double longitude) async {
    await openMap(context, '$latitude,$longitude');
  }

  static const MethodChannel _playStoreChannel =
      MethodChannel('com.orderkart.app/playstore');

  /// Opens the Google Play Store directly without showing other apps or browsers.
  static Future<bool> openPlayStore({
    String packageName = 'com.example.orderkart',
    String? customUrl,
  }) async {
    final targetPackage = (customUrl != null && customUrl.contains('id='))
        ? (Uri.tryParse(customUrl)?.queryParameters['id'] ?? packageName)
        : packageName;

    // 1. Direct native Intent targeting com.android.vending
    try {
      final bool? direct = await _playStoreChannel.invokeMethod<bool>(
        'openPlayStoreDirectly',
        {'packageName': targetPackage},
      );
      if (direct == true) return true;
    } catch (_) {}

    // 2. Non-browser market scheme
    try {
      final marketUri = Uri.parse('market://details?id=$targetPackage');
      if (await canLaunchUrl(marketUri)) {
        return await launchUrl(
          marketUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      }
    } catch (_) {}

    // 3. Fallback web URL
    try {
      final webUrl = customUrl ??
          'https://play.google.com/store/apps/details?id=$targetPackage';
      return await launchUrl(
        Uri.parse(webUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
