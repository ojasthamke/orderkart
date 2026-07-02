/// BillTextGenerator — Generates plain-text bill for WhatsApp/clipboard sharing

import '../constants/app_constants.dart';
import 'formatters.dart';

class BillTextGenerator {
  BillTextGenerator._();

  static String generate({
    required String businessName,
    required String customerName,
    required String customerAddress,
    required String orderId,
    required DateTime orderDate,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double deliveryCharge,
    required double grandTotal,
    required double paidAmount,
    required double remainingAmount,
    required String paymentMethod,
    String currency = AppConstants.defaultCurrency,
  }) {
    final buf = StringBuffer();
    final sep = '─' * 30;

    buf.writeln('🛒 *$businessName*');
    buf.writeln(sep);
    buf.writeln('📋 Order #${orderId.substring(0, 8).toUpperCase()}');
    buf.writeln('📅 ${AppFormatters.dateTime(orderDate)}');
    buf.writeln('👤 $customerName');
    if (customerAddress.isNotEmpty) buf.writeln('📍 $customerAddress');
    buf.writeln(sep);
    buf.writeln('*ITEMS*');

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
    if (deliveryCharge > 0) {
      buf.writeln('Delivery:        + $currency${deliveryCharge.toStringAsFixed(2)}');
    }
    buf.writeln('*Grand Total:      $currency${grandTotal.toStringAsFixed(2)}*');
    buf.writeln(sep);
    buf.writeln('Paid:              $currency${paidAmount.toStringAsFixed(2)} (${AppFormatters.paymentMethod(paymentMethod)})');
    if (remainingAmount > 0) {
      buf.writeln('⚠️ Remaining:    $currency${remainingAmount.toStringAsFixed(2)}');
    } else {
      buf.writeln('✅ Fully Paid');
    }
    buf.writeln(sep);
    buf.writeln('_Powered by OrderKart_');

    return buf.toString();
  }
}
