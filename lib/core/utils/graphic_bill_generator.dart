import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../features/order/domain/order.dart';
import '../../features/customer/domain/customer.dart';
import '../../features/settings/domain/app_settings.dart';

class GraphicBillGenerator {
  GraphicBillGenerator._();

  static Future<void> generateAndShareGraphicBill({
    required BuildContext context,
    required AppOrder order,
    Customer? customer,
    AppSettings? settings,
    List<Map<String, dynamic>>? orderItems,
  }) async {
    try {
      final businessName = settings?.businessName.isNotEmpty == true
          ? settings!.businessName
          : 'OrderKart Official';
      final currency = settings?.currency ?? '₹';
      final safeCurrency = currency == '₹' ? 'Rs.' : currency;
      final phone = settings?.phone ?? '';

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (pw.Context ctx) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.teal, width: 2),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // ── Header ─────────────────────────────────────────
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            businessName.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal800,
                            ),
                          ),
                          if (phone.isNotEmpty)
                            pw.Text('Contact: $phone',
                                style: const pw.TextStyle(
                                    fontSize: 10, color: PdfColors.grey700)),
                          pw.Text('Official Tax Invoice / Cash Memo',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey600)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.teal50,
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.Text(
                              'ORDER ${order.orderNoLabel}',
                              style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.teal900),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Date: ${order.createdAt.toIso8601String().substring(0, 10)}',
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Divider(thickness: 1.5, color: PdfColors.teal200),
                  pw.SizedBox(height: 10),

                  // ── Customer Details ────────────────────────────────
                  if (customer != null) ...[
                    pw.Text('Billed To:',
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text(customer.name,
                        style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black)),
                    if (customer.phone1.isNotEmpty)
                      pw.Text('Phone: ${customer.phone1}',
                          style: const pw.TextStyle(fontSize: 10)),
                    if (customer.address.isNotEmpty)
                      pw.Text('Address: ${customer.address}',
                          style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 12),
                  ],

                  // ── Itemized Table ─────────────────────────────────
                  pw.TableHelper.fromTextArray(
                    headers: [
                      '#',
                      'Item Description',
                      'Qty',
                      'Unit Price',
                      'Total'
                    ],
                    headerStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    headerDecoration:
                        const pw.BoxDecoration(color: PdfColors.teal700),
                    cellAlignment: pw.Alignment.centerLeft,
                    data: (orderItems == null || orderItems.isEmpty)
                        ? [
                            [
                              '1',
                              'General Order Items',
                              '1',
                              '$safeCurrency ${order.subtotal.toStringAsFixed(2)}',
                              '$safeCurrency ${order.subtotal.toStringAsFixed(2)}'
                            ]
                          ]
                        : orderItems.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final item = entry.value;
                            final name =
                                item['item_name']?.toString() ?? 'Product';
                            final qty =
                                (item['quantity'] as num?)?.toDouble() ?? 1.0;
                            final unit = item['unit']?.toString() ?? 'pcs';
                            final price =
                                (item['unit_price'] as num?)?.toDouble() ?? 0.0;
                            final total =
                                (item['total_price'] as num?)?.toDouble() ??
                                    (qty * price);

                            return [
                              '$idx',
                              name,
                              '${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)} $unit',
                              '$safeCurrency ${price.toStringAsFixed(2)}',
                              '$safeCurrency ${total.toStringAsFixed(2)}',
                            ];
                          }).toList(),
                  ),
                  pw.SizedBox(height: 12),

                  // ── Financial Breakdown & Payment Status ────────────
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Payment Status:',
                              style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                            order.remainingAmount <= 0
                                ? 'PAID IN FULL ✓'
                                : 'PARTIAL / PENDING ($safeCurrency ${order.remainingAmount.toStringAsFixed(2)} DUE)',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: order.remainingAmount <= 0
                                  ? PdfColors.green800
                                  : PdfColors.orange900,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text('Thank you for your business!',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontStyle: pw.FontStyle.italic)),
                        ],
                      ),
                      pw.Container(
                        width: 220,
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          children: [
                            _buildRow('Subtotal:',
                                '$safeCurrency ${order.subtotal.toStringAsFixed(2)}'),
                            if (order.discount > 0)
                              _buildRow('Discount Saved:',
                                  '-$safeCurrency ${order.discount.toStringAsFixed(2)}',
                                  color: PdfColors.green800),
                            if (order.deliveryCharge > 0)
                              _buildRow('Delivery Fee:',
                                  '+$safeCurrency ${order.deliveryCharge.toStringAsFixed(2)}'),
                            pw.Divider(),
                            _buildRow(
                              'Grand Total:',
                              '$safeCurrency ${order.grandTotal.toStringAsFixed(2)}',
                              isBold: true,
                              fontSize: 12,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (settings != null &&
                      settings.invoiceDisclaimer.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 12),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.teal50,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: PdfColors.teal200),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Terms & Disclaimer:',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.teal900)),
                          pw.SizedBox(height: 2),
                          pw.Text(settings.invoiceDisclaimer.trim(),
                              style: const pw.TextStyle(
                                  fontSize: 8, color: PdfColors.grey800)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Order_${order.id}_Bill.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Order ${order.orderNoLabel} Graphic Tax Invoice Bill from $businessName',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate graphic bill: $e')),
        );
      }
    }
  }

  static pw.Widget _buildRow(String label, String val,
      {bool isBold = false, double fontSize = 10, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                      isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color)),
          pw.Text(val,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                      isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }
}
