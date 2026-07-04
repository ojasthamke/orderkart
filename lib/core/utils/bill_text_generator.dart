/// BillTextGenerator — Generates plain-text bill for sharing
/// Clean, sophisticated style, with no emojis (except warning), no footer, and optional owner phone.

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
    String currency = AppConstants.defaultCurrency,
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
      buf.writeln('Fully Paid');
    }
    buf.writeln(sep);

    final totalSavings = discount;
    if (totalSavings > 0) {
      buf.writeln('🎉 *CONGRATULATIONS!* You saved *$currency${totalSavings.toStringAsFixed(2)}* on this order by shopping with us! 🥳✨');
      buf.writeln(sep);
    }

    return buf.toString();
  }
}
