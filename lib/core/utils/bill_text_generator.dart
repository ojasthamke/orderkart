/// BillTextGenerator — Generates plain-text bill for sharing
/// Clean, sophisticated style, with no emojis (except warning), no footer, and optional owner phone.
library;

import '../constants/app_constants.dart';
import 'formatters.dart';

class BillTextGenerator {
  BillTextGenerator._();

  static String generate({
    required String businessName,
    required String customerName,
    required String customerAddress,
    required String orderNoLabel,
    required DateTime orderDate,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double deliveryCharge,
    required double grandTotal,
    required double paidAmount,
    required double remainingAmount,
    required String paymentMethod,
    required String ownerPhone,
    double marketSavings = 0.0, // savings vs market price
    String currency = AppConstants.defaultCurrency,
    String notes = '',
    String disclaimer = '',
    List<Map<String, dynamic>> questionAnswers = const [],
  }) {
    final buf = StringBuffer();
    final sep = '─' * 30;
    final doubleSep = '═' * 30;

    buf.writeln(doubleSep);
    buf.writeln('🏪 *${businessName.toUpperCase()}*');
    buf.writeln(doubleSep);
    buf.writeln('🧾 *INVOICE DETAILS*');
    buf.writeln('• Order No: $orderNoLabel');
    buf.writeln('• Date:     ${AppFormatters.dateTime(orderDate)}');
    buf.writeln('• Customer: $customerName');
    if (customerAddress.isNotEmpty) {
      buf.writeln('• Address:  $customerAddress');
    }
    if (notes.trim().isNotEmpty) {
      buf.writeln('• Notes:    ${notes.trim()}');
    }
    if (questionAnswers.isNotEmpty) {
      buf.writeln(sep);
      buf.writeln('📋 *ORDER QUESTIONS*');
      for (int i = 0; i < questionAnswers.length; i++) {
        final ans = questionAnswers[i];
        final qText = ans['question_text'] as String? ?? '';
        final opt = ans['selected_option'] as String? ?? '';
        buf.writeln('  $qText: *$opt*');
      }
    }
    buf.writeln(sep);
    buf.writeln('🛒 *ITEMS SUMMARY*');
    buf.writeln(sep);

    for (final item in items) {
      final name = item['item_name']?.toString() ?? 'Item';
      final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final unit = item['item_unit']?.toString() ?? '';
      final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
      final total = (item['total_price'] as num?)?.toDouble() ?? (qty * price);
      buf.writeln('🔹 *$name* (${AppFormatters.quantity(qty, unit: unit)})');
      buf.writeln(
          '  Rate: $currency${price.toStringAsFixed(2)}  |  Total: *$currency${total.toStringAsFixed(2)}*');
      buf.writeln('');
    }

    buf.writeln(sep);
    buf.writeln('💵 *BILLING DETAILS*');
    buf.writeln('• Subtotal: $currency${subtotal.toStringAsFixed(2)}');
    if (discount > 0) {
      buf.writeln('• Discount: -$currency${discount.toStringAsFixed(2)}');
    }
    if (deliveryCharge > 0) {
      buf.writeln(
          '• Delivery Fee: +$currency${deliveryCharge.toStringAsFixed(2)}');
    }
    buf.writeln('• *Grand Total: $currency${grandTotal.toStringAsFixed(2)}*');
    buf.writeln(sep);
    buf.writeln('💳 *PAYMENT STATUS*');
    buf.writeln(
        '• Paid Amount: $currency${paidAmount.toStringAsFixed(2)} (${AppFormatters.paymentMethod(paymentMethod).toUpperCase()})');
    if (remainingAmount > 0) {
      buf.writeln(
          '• *Due Amount: $currency${remainingAmount.toStringAsFixed(2)}* ⚠️');
    } else {
      buf.writeln('• Status: *Fully Paid* ✅');
    }
    buf.writeln(doubleSep);

    // ── Daily Savings Banner ──────────────────────────────────────────
    final totalSavings = discount + marketSavings;
    if (totalSavings > 0) {
      buf.writeln('🎉 *CONGRATULATIONS!*');
      if (discount > 0 && marketSavings > 0) {
        buf.writeln(
            'You saved *$currency${discount.toStringAsFixed(2)}* (order discount) + *$currency${marketSavings.toStringAsFixed(2)}* (vs. market price)');
        buf.writeln(
            '🏷️ *Total savings: $currency${totalSavings.toStringAsFixed(2)}* by shopping with us! 🥳✨');
      } else if (marketSavings > 0) {
        buf.writeln(
            'You saved *$currency${marketSavings.toStringAsFixed(2)}* vs. market price by shopping with us! 🥳✨');
      } else {
        buf.writeln(
            'You saved *$currency${discount.toStringAsFixed(2)}* on this order by shopping with us! 🥳✨');
      }
      buf.writeln(doubleSep);
    } else {
      buf.writeln('💚 Thank you for shopping with *$businessName*!');
      buf.writeln(doubleSep);
    }

    final hasRx = items.any((it) => it['prescription_required'] == true);
    if (hasRx) {
      buf.writeln(
          '⚠️ *Prescription Note (Rx)*: Hand over subject to verification of a valid physical doctor note.');
      buf.writeln(doubleSep);
    }

    if (ownerPhone.trim().isNotEmpty) {
      buf.writeln('📞 *STORE CONTACT*');
      buf.writeln('Owner Phone: ${ownerPhone.trim()}');
      buf.writeln(doubleSep);
    }

    if (disclaimer.trim().isNotEmpty) {
      buf.writeln('📌 *TERMS & DISCLAIMER*');
      buf.writeln(disclaimer.trim());
      buf.writeln(doubleSep);
    }

    return buf.toString();
  }

  /// Generates a standardized monospaced receipt text ready for ESC/POS Thermal Bluetooth/USB Printers
  /// Supports both 58mm (32 cols) and 80mm (48 cols) formats.
  static String generateThermalReceipt({
    required String businessName,
    required String customerName,
    required String customerAddress,
    required String orderNoLabel,
    required DateTime orderDate,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double deliveryCharge,
    required double grandTotal,
    required double paidAmount,
    required double remainingAmount,
    required String paymentMethod,
    bool is58mm = true,
    bool enableGst = false,
    double gstRate = 5.0,
    String gstin = '',
    String currency = '₹',
  }) {
    final int width = is58mm ? 32 : 48;
    final sep = '-' * width;
    final dSep = '=' * width;
    final buf = StringBuffer();

    String center(String s) {
      if (s.length >= width) return s.substring(0, width);
      final pad = (width - s.length) ~/ 2;
      return ' ' * pad + s;
    }

    String twoCol(String left, String right) {
      final safeRight = right.length >= width ? right.substring(0, width - 1) : right;
      final maxL = (width - safeRight.length - 1).clamp(0, width);
      final cleanL = left.length > maxL ? left.substring(0, maxL) : left;
      final spaces = (width - cleanL.length - safeRight.length).clamp(1, width);
      return cleanL + (' ' * spaces) + safeRight;
    }

    buf.writeln(dSep);
    buf.writeln(center(businessName.toUpperCase()));
    if (gstin.isNotEmpty) buf.writeln(center('GSTIN: $gstin'));
    buf.writeln(center('ORDER RECEIPT'));
    buf.writeln(dSep);
    buf.writeln(twoCol('Order #:', orderNoLabel));
    buf.writeln(twoCol('Date:', AppFormatters.date(orderDate)));
    buf.writeln(twoCol('Cust:', customerName));
    if (customerAddress.isNotEmpty) {
      buf.writeln('Addr: $customerAddress');
    }
    buf.writeln(sep);
    buf.writeln(twoCol('ITEM / QTY', 'TOTAL'));
    buf.writeln(sep);

    for (final it in items) {
      final name = it['item_name']?.toString() ?? 'Item';
      final qty = (it['quantity'] as num?)?.toDouble() ?? 0.0;
      final unit = it['item_unit']?.toString() ?? '';
      final price = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
      final total = (it['total_price'] as num?)?.toDouble() ?? (qty * price);

      buf.writeln(name);
      buf.writeln(twoCol(
        '  ${AppFormatters.quantity(qty, unit: unit)} @ $price',
        total.toStringAsFixed(2),
      ));
    }

    buf.writeln(sep);
    buf.writeln(twoCol('Subtotal:', '$currency${subtotal.toStringAsFixed(2)}'));
    if (discount > 0) {
      buf.writeln(twoCol('Discount:', '-$currency${discount.toStringAsFixed(2)}'));
    }
    if (deliveryCharge > 0) {
      buf.writeln(twoCol('Delivery:', '+$currency${deliveryCharge.toStringAsFixed(2)}'));
    }
    if (enableGst && gstRate > 0) {
      final cgst = (subtotal * (gstRate / 200.0));
      final sgst = (subtotal * (gstRate / 200.0));
      buf.writeln(twoCol('CGST (${(gstRate / 2).toStringAsFixed(1)}%):', '+$currency${cgst.toStringAsFixed(2)}'));
      buf.writeln(twoCol('SGST (${(gstRate / 2).toStringAsFixed(1)}%):', '+$currency${sgst.toStringAsFixed(2)}'));
    }
    buf.writeln(dSep);
    buf.writeln(twoCol('GRAND TOTAL:', '$currency${grandTotal.toStringAsFixed(2)}'));
    buf.writeln(twoCol('PAID (${paymentMethod.toUpperCase()}):', '$currency${paidAmount.toStringAsFixed(2)}'));
    if (remainingAmount > 0) {
      buf.writeln(twoCol('DUE BALANCE:', '$currency${remainingAmount.toStringAsFixed(2)}'));
    } else if (remainingAmount < 0) {
      buf.writeln(twoCol('ADVANCE CREDIT:', '$currency${remainingAmount.abs().toStringAsFixed(2)}'));
    }
    buf.writeln(dSep);
    buf.writeln(center('Thank you for your business!'));
    buf.writeln(center('Please visit again'));
    buf.writeln('\n\n');
    return buf.toString();
  }
}
