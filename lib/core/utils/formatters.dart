/// Formatters — Currency, date, phone, quantity display helpers
library;

import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class AppFormatters {
  AppFormatters._();

  static final _currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '');
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _timeFmt = DateFormat('hh:mm a');
  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');
  static final _monthFmt = DateFormat('MMMM yyyy');
  static final _shortDate = DateFormat('dd MMM');

  /// Format amount as currency: ₹1,234.50
  static String currency(double amount, {String? symbol}) {
    final sym = symbol ?? AppConstants.defaultCurrency;
    return '$sym${_currencyFmt.format(amount)}';
  }

  /// Format date: 01 Jan 2024
  static String date(DateTime dt) => _dateFmt.format(dt);
  static String dateFromString(String iso) {
    if (iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '—';
    return _dateFmt.format(parsed.toLocal());
  }

  /// Format time: 02:30 PM
  static String time(DateTime dt) => _timeFmt.format(dt.toLocal());

  /// Format date + time: 01 Jan 2024, 02:30 PM
  static String dateTime(DateTime dt) => _dateTimeFmt.format(dt.toLocal());
  static String dateTimeFromString(String iso) {
    if (iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '—';
    return _dateTimeFmt.format(parsed.toLocal());
  }

  /// Month label: January 2024
  static String month(DateTime dt) => _monthFmt.format(dt);

  /// Short date: 01 Jan
  static String shortDate(DateTime dt) => _shortDate.format(dt);

  /// Format quantity with smart display:
  /// 1 kg, 3 kg for whole kg; 250 g, 500 g, 670 g for fractional kg / sub-kg grams
  static String quantity(double qty, {String? unit}) {
    if (unit == null || unit.trim().isEmpty) {
      return qty == qty.truncateToDouble()
          ? qty.toInt().toString()
          : qty
              .toStringAsFixed(2)
              .replaceAll(RegExp(r'\.?0+$'), '');
    }

    final u = unit.trim().toLowerCase();
    final isKg = u == 'kg' || u == 'kilo' || u == 'kilogram' || u == 'kilograms';
    final isGm = u == 'g' || u == 'gm' || u == 'gms' || u == 'gram' || u == 'grams';

    if (isKg) {
      if (qty == qty.truncateToDouble()) {
        return '${qty.toInt()} kg';
      }
      if (qty < 1.0) {
        final g = (qty * 1000).round();
        return '$g g';
      }
      final wholeKg = qty.floor();
      final remGrams = ((qty - wholeKg) * 1000).round();
      if (remGrams == 0) {
        return '$wholeKg kg';
      }
      return '$wholeKg kg $remGrams g';
    }

    if (isGm) {
      if (qty >= 1000 && (qty % 1000) == 0) {
        return '${(qty / 1000).toInt()} kg';
      }
      if (qty >= 1000) {
        final wholeKg = (qty / 1000).floor();
        final remGrams = (qty % 1000).round();
        return '$wholeKg kg $remGrams g';
      }
      final g = qty == qty.truncateToDouble()
          ? qty.toInt().toString()
          : qty.toStringAsFixed(1).replaceAll(RegExp(r'\.?0+$'), '');
      return '$g g';
    }

    final display = qty == qty.truncateToDouble()
        ? qty.toInt().toString()
        : qty
            .toStringAsFixed(qty < 1 ? 2 : 1)
            .replaceAll(RegExp(r'\.?0+$'), '');
    return '$display $unit';
  }

  /// Compact number: 1200 → 1.2K
  static String compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return _currencyFmt.format(value);
  }

  /// Phone display: +91 98765 43210
  static String phone(String raw) {
    if (raw.isEmpty) return '—';
    final cleaned = raw.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 10) {
      return '+91 ${cleaned.substring(0, 5)} ${cleaned.substring(5)}';
    }
    return raw;
  }

  /// Relative date: Today, Yesterday, DD MMM
  static String relativeDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return _dateFmt.format(dt);
  }

  /// Payment method display label
  static String paymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'online':
        return 'Online';
      case 'upi':
        return 'UPI';
      case 'card':
        return 'Card';
      default:
        return method;
    }
  }

  /// Delivery status display label
  static String deliveryStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
