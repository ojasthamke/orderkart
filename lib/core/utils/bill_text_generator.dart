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
    List<Map<String, dynamic>> questionAnswers = const [],
  }) {
    final buf = StringBuffer();
    final sep = '─' * 30;

    buf.writeln('*$businessName*');
    buf.writeln(sep);
    buf.writeln('Order $orderNoLabel');
    buf.writeln('Date: ${AppFormatters.dateTime(orderDate)}');
    buf.writeln('Customer: $customerName');
    if (customerAddress.isNotEmpty) {
      buf.writeln('Address: $customerAddress');
    }
    if (ownerPhone.trim().isNotEmpty) {
      buf.writeln('Contact: ${ownerPhone.trim()}');
    }
    if (notes.trim().isNotEmpty) {
      buf.writeln('Notes: ${notes.trim()}');
    }
    if (questionAnswers.isNotEmpty) {
      for (int i = 0; i < questionAnswers.length; i++) {
        final ans = questionAnswers[i];
        final qText = ans['question_text'] as String? ?? '';
        final opt = ans['selected_option'] as String? ?? '';
        buf.writeln('🟢 Q${i + 1}: $opt ($qText)');
      }
    }
    buf.writeln(sep);
    buf.writeln('ITEMS');

    for (final item in items) {
      final name  = item['item_name']  as String;
      final qty   = item['quantity']   as double;
      final unit  = item['item_unit']  as String;
      final price = item['unit_price'] as double;
      final total = item['total_price'] as double;
      buf.writeln(
        '• $name — ${AppFormatters.quantity(qty, unit: unit)} × $currency${price.toStringAsFixed(2)} = $currency${total.toStringAsFixed(2)}',
      );
    }

    buf.writeln(sep);
    buf.writeln('Subtotal:          $currency${subtotal.toStringAsFixed(2)}');
    if (discount > 0) {
      buf.writeln('Discount:        - $currency${discount.toStringAsFixed(2)}');
    }
    // Delivery charge line mention is removed as requested
    buf.writeln('*Grand Total:      $currency${grandTotal.toStringAsFixed(2)}*');
    buf.writeln(sep);
    buf.writeln('Paid:              $currency${paidAmount.toStringAsFixed(2)} (${AppFormatters.paymentMethod(paymentMethod)})');
    if (remainingAmount > 0) {
      buf.writeln('⚠️ Remaining:    $currency${remainingAmount.toStringAsFixed(2)}');
    } else {
      buf.writeln('Fully Paid ✅');
    }
    buf.writeln(sep);

    // ── Daily Savings Banner — always shown ──────────────────────────
    final totalSavings = discount + marketSavings;
    if (totalSavings > 0) {
      buf.writeln('🎉 *CONGRATULATIONS!*');
      if (discount > 0 && marketSavings > 0) {
        buf.writeln('You saved *$currency${discount.toStringAsFixed(2)}* (order discount) + *$currency${marketSavings.toStringAsFixed(2)}* (vs. market price)');
        buf.writeln('🏷️ *Total savings: $currency${totalSavings.toStringAsFixed(2)}* by shopping with us! 🥳✨');
      } else if (marketSavings > 0) {
        buf.writeln('You saved *$currency${marketSavings.toStringAsFixed(2)}* vs. market price by shopping with us! 🥳✨');
      } else {
        buf.writeln('You saved *$currency${discount.toStringAsFixed(2)}* on this order by shopping with us! 🥳✨');
      }
      buf.writeln(sep);
    } else {
      buf.writeln('💚 Thank you for shopping with *$businessName*!');
      buf.writeln(sep);
    }

    final hasRx = items.any((it) => it['prescription_required'] == true);
    if (hasRx) {
      buf.writeln('⚠️ *Prescription Note (Rx)*: Hand over subject to verification of a valid physical doctor note.');
      buf.writeln(sep);
    }

    return buf.toString();
  }
}
