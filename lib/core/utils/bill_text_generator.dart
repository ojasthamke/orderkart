/// BillTextGenerator — Generates plain-text & thermal bills for sharing with Marathi support & savings breakdown
library;

import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import 'formatters.dart';
import 'marathi_item_helper.dart';

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
    double monthlySavings = 0.0, // customer's total savings this month
    String currency = AppConstants.defaultCurrency,
    String notes = '',
    String disclaimer = '',
    List<Map<String, dynamic>> questionAnswers = const [],
    DateTime? billGeneratedAt,
  }) {
    final buf = StringBuffer();
    const sep = '────────────────────────';
    final now = billGeneratedAt ?? DateTime.now();
    final billTimeFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(now);

    buf.writeln('🏪 *${businessName.toUpperCase()}*');
    buf.writeln('• Order No:       *$orderNoLabel*');
    buf.writeln('• Order Date:     📅 ${AppFormatters.date(orderDate)} ($billTimeFormatted)');
    buf.writeln('• Customer:       👤 *$customerName*');
    if (customerAddress.trim().isNotEmpty) {
      buf.writeln('📍 Address: $customerAddress');
    }
    if (notes.trim().isNotEmpty) {
      buf.writeln('📝 Note: ${notes.trim()}');
    }
    if (questionAnswers.isNotEmpty) {
      buf.writeln(sep);
      buf.writeln('📋 *Order Details:*');
      for (final ans in questionAnswers) {
        final qText = ans['question_text'] as String? ?? '';
        final opt = ans['selected_option'] as String? ?? '';
        buf.writeln('• $qText: *$opt*');
      }
    }
    buf.writeln(sep);
    buf.writeln('🛒 *ITEMS*');

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final rawName = item['item_name']?.toString() ?? 'Item';
      final bilingualName = MarathiItemHelper.formatBilingual(rawName);

      final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final unit = item['item_unit']?.toString() ?? item['unit']?.toString() ?? '';
      final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
      final total = (item['total_price'] as num?)?.toDouble() ?? (qty * price);
      final qtyStr = AppFormatters.quantity(qty, unit: unit);
      
      buf.writeln('${i + 1}. *$bilingualName*');
      buf.writeln('   $qtyStr x $currency${price.toStringAsFixed(2)} = *$currency${total.toStringAsFixed(2)}*');
    }

    buf.writeln(sep);
    buf.writeln('💵 *BILL SUMMARY*');
    buf.writeln('• Subtotal:       $currency${subtotal.toStringAsFixed(2)}');
    if (discount > 0) {
      buf.writeln('• Discount:       -$currency${discount.toStringAsFixed(2)}');
    }
    if (deliveryCharge > 0) {
      buf.writeln('• Delivery Fee:   +$currency${deliveryCharge.toStringAsFixed(2)}');
    }
    buf.writeln('• *Grand Total:    $currency${grandTotal.toStringAsFixed(2)}*');
    buf.writeln(sep);
    buf.writeln('💳 *PAYMENT STATUS*');
    buf.writeln(
        '• Paid Amount:    $currency${paidAmount.toStringAsFixed(2)} (${AppFormatters.paymentMethod(paymentMethod).toUpperCase()})');
    if (remainingAmount > 0) {
      buf.writeln(
          '• *Due Amount:     $currency${remainingAmount.toStringAsFixed(2)}* ⚠️');
    } else {
      buf.writeln('• Status:         *Fully Paid* ✅');
    }

    final totalOrderSavings = discount + marketSavings;
    if (totalOrderSavings > 0 || monthlySavings > 0) {
      buf.writeln(sep);
      if (totalOrderSavings > 0) {
        buf.writeln('🎉 *You Saved $currency${totalOrderSavings.toStringAsFixed(2)} on this order!*');
      }
      if (monthlySavings > 0) {
        buf.writeln('🌟 *Total Saved This Month: $currency${monthlySavings.toStringAsFixed(2)}*');
      }
    }

    final hasRx = items.any((it) => it['prescription_required'] == true);
    if (hasRx) {
      buf.writeln(sep);
      buf.writeln('⚠️ *Prescription Note*: Handover subject to valid doctor note verification.');
    }

    if (ownerPhone.trim().isNotEmpty) {
      buf.writeln('📞 *Contact*: ${ownerPhone.trim()}');
    }

    if (disclaimer.trim().isNotEmpty) {
      buf.writeln('📌 *Note*: ${disclaimer.trim()}');
    }

    buf.writeln(sep);
    buf.writeln('🙏 _Thank you for shopping with us!_');

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
    String currency = 'Rs.',
  }) {
    final int width = is58mm ? 32 : 48;
    final sep = '-' * width;
    final dSep = '=' * width;
    final buf = StringBuffer();
    final now = DateTime.now();

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

    buf.writeln(center(businessName.toUpperCase()));
    buf.writeln(center('TAX INVOICE / CASH MEMO'));
    if (gstin.isNotEmpty) buf.writeln(center('GSTIN: $gstin'));
    buf.writeln(dSep);

    buf.writeln(twoCol('Order No:', orderNoLabel));
    buf.writeln(twoCol('Order Date:', AppFormatters.date(orderDate)));
    buf.writeln(twoCol('Bill Print:', DateFormat('dd/MM/yy hh:mm a').format(now)));
    buf.writeln(twoCol('Customer:', customerName));
    if (customerAddress.isNotEmpty) {
      buf.writeln('Addr: $customerAddress');
    }
    buf.writeln(sep);

    if (is58mm) {
      buf.writeln('ITEM          QTY   RATE  TOTAL');
      buf.writeln(sep);
      for (final it in items) {
        final rawName = it['item_name']?.toString() ?? 'Item';
        final bilingualName = MarathiItemHelper.formatBilingual(rawName);
        final qty = (it['quantity'] as num?)?.toDouble() ?? 1.0;
        final unit = it['item_unit']?.toString() ?? it['unit']?.toString() ?? '';
        final price = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
        final total = (it['total_price'] as num?)?.toDouble() ?? (qty * price);

        buf.writeln(bilingualName);
        final line = '  ${AppFormatters.quantity(qty)}$unit @$price = $currency${total.toStringAsFixed(2)}';
        buf.writeln(line);
      }
    } else {
      buf.writeln(twoCol('ITEM (DESCRIPTION)', 'QTY   RATE   TOTAL'));
      buf.writeln(sep);
      for (final it in items) {
        final rawName = it['item_name']?.toString() ?? 'Item';
        final bilingualName = MarathiItemHelper.formatBilingual(rawName);
        final qty = (it['quantity'] as num?)?.toDouble() ?? 1.0;
        final unit = it['item_unit']?.toString() ?? it['unit']?.toString() ?? '';
        final price = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
        final total = (it['total_price'] as num?)?.toDouble() ?? (qty * price);
        final right = '${AppFormatters.quantity(qty)}$unit x $price = $currency${total.toStringAsFixed(2)}';
        buf.writeln(twoCol(bilingualName, right));
      }
    }

    buf.writeln(sep);
    buf.writeln(twoCol('Subtotal:', '$currency${subtotal.toStringAsFixed(2)}'));

    if (enableGst) {
      final halfGst = (subtotal * (gstRate / 200)).toStringAsFixed(2);
      buf.writeln(twoCol('CGST (${(gstRate / 2).toStringAsFixed(1)}%):', '$currency$halfGst'));
      buf.writeln(twoCol('SGST (${(gstRate / 2).toStringAsFixed(1)}%):', '$currency$halfGst'));
    }

    if (discount > 0) {
      buf.writeln(twoCol('Discount:', '-$currency${discount.toStringAsFixed(2)}'));
    }
    if (deliveryCharge > 0) {
      buf.writeln(twoCol('Delivery:', '+$currency${deliveryCharge.toStringAsFixed(2)}'));
    }
    buf.writeln(dSep);
    buf.writeln(twoCol('GRAND TOTAL:', '$currency${grandTotal.toStringAsFixed(2)}'));
    buf.writeln(dSep);

    buf.writeln(twoCol('Paid ($paymentMethod):', '$currency${paidAmount.toStringAsFixed(2)}'));
    if (remainingAmount > 0) {
      buf.writeln(twoCol('DUE AMOUNT:', '$currency${remainingAmount.toStringAsFixed(2)}'));
    } else {
      buf.writeln(center('*** FULLY PAID ***'));
    }

    buf.writeln(dSep);
    buf.writeln(center('Your satisfaction matters to us!'));
    buf.writeln(center('Thank you for trusting us!'));
    buf.writeln(center('*** VISIT AGAIN ***'));
    buf.writeln('\n\n');

    return buf.toString();
  }
}
