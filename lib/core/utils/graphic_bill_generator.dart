import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../widgets/snackbar_helper.dart';
import '../../features/order/domain/order.dart';
import '../../features/order/data/order_dao.dart';
import '../../features/customer/domain/customer.dart';
import '../../features/settings/domain/app_settings.dart';
import 'pdf_font_helper.dart';
import 'marathi_item_helper.dart';
import 'formatters.dart';
import 'unit_converter.dart';

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

      final themeName = settings?.meshTheme ?? 'emerald';
      PdfColor primaryColor = PdfColors.teal800;
      PdfColor lightColor = PdfColors.teal50;
      PdfColor borderColor = PdfColors.teal200;

      if (themeName == 'navy') {
        primaryColor = PdfColors.indigo800;
        lightColor = PdfColors.indigo50;
        borderColor = PdfColors.indigo200;
      } else if (themeName == 'slate') {
        primaryColor = PdfColors.blueGrey800;
        lightColor = PdfColors.blueGrey50;
        borderColor = PdfColors.blueGrey200;
      }

      final watermarkText = order.remainingAmount <= 0
          ? 'PAID IN FULL'
          : (order.paidAmount > 0 ? 'PARTIAL PAYMENT' : 'DUE / UNPAID');

      // Fetch customer monthly savings
      Map<String, double> savingsData = {'total': 0.0, 'monthly': 0.0};
      try {
        if (order.customerId.isNotEmpty) {
          savingsData = await OrderDao().getCustomerSavings(order.customerId);
        }
      } catch (_) {}

      final double monthlySavings = savingsData['monthly'] ?? 0.0;
      final double currentOrderSavings = order.savings > 0 ? order.savings : order.discount;

      // Load Devanagari (Marathi) capable PDF Theme
      final pdfTheme = await PdfFontHelper.getDevanagariTheme();
      final pdf = pw.Document(theme: pdfTheme);

      final now = DateTime.now();
      final orderDateStr = AppFormatters.date(order.createdAt);
      final pdfGeneratedTimeStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);
      final currentMonthName = DateFormat('MMMM yyyy').format(now);

      // Calculate Total Package Weight and Non-Weight Counts
      double totalPackageWeightKg = 0.0;
      double nonWeightCount = 0.0;

      if (orderItems != null && orderItems.isNotEmpty) {
        for (final item in orderItems) {
          final qty =
              (item['quantity'] as num?)?.toDouble() ?? 1.0;
          final unit = item['unit']?.toString() ??
              item['item_unit']?.toString() ??
              'pcs';
          if (UnitConverter.isWeightUnit(unit)) {
            totalPackageWeightKg +=
                UnitConverter.toWeightInKg(qty, unit);
          } else {
            nonWeightCount += qty;
          }
        }
      } else if (order.items.isNotEmpty) {
        for (final item in order.items) {
          if (UnitConverter.isWeightUnit(item.itemUnit)) {
            totalPackageWeightKg += UnitConverter.toWeightInKg(
                item.quantity, item.itemUnit);
          } else {
            nonWeightCount += item.quantity;
          }
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            theme: pdfTheme,
            buildBackground: (pw.Context ctx) => pw.Center(
              child: pw.Transform.rotate(
                angle: -0.45,
                child: pw.Text(
                  watermarkText,
                  style: pw.TextStyle(
                    fontSize: 54,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey200,
                  ),
                ),
              ),
            ),
          ),
          build: (pw.Context ctx) {
            return [
              // ── Header ─────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          businessName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        if (phone.isNotEmpty)
                          pw.Text('Contact: $phone',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey700)),
                        pw.Text('Official Tax Invoice & Cash Memo (बिल पावती)',
                            style: const pw.TextStyle(
                                fontSize: 8.5, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: lightColor,
                          borderRadius: pw.BorderRadius.circular(6),
                          border: pw.Border.all(color: borderColor),
                        ),
                        child: pw.Text(
                          'ORDER ${order.orderNoLabel}',
                          style: pw.TextStyle(
                              fontSize: 10.5,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        '📅 Order Date: $orderDateStr',
                        style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800),
                      ),
                      pw.Text(
                        '🖨️ Bill Generated: $pdfGeneratedTimeStr',
                        style: const pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1.2, color: borderColor),
              pw.SizedBox(height: 4),

              // ── Customer Details ────────────────────────────────
              if (customer != null || (order.customerName != null && order.customerName!.isNotEmpty)) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Billed To (ग्राहक):',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700)),
                        pw.Text(
                          customer?.name ?? order.customerName ?? 'Valued Customer',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black),
                        ),
                        if ((customer?.phone1 ?? order.customerPhone ?? '').isNotEmpty)
                          pw.Text('Phone: ${customer?.phone1 ?? order.customerPhone}',
                              style: const pw.TextStyle(fontSize: 8.5)),
                        if (customer != null && customer.address.isNotEmpty)
                          pw.Text('Address: ${customer.address}',
                              style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
              ],

              // ── Itemized Table with Marathi Names & Zebra Striping ──
              pw.TableHelper.fromTextArray(
                headers: [
                  '#',
                  'Item Description (वस्तूचे नाव)',
                  'Qty (प्रमाण)',
                  'Rate (दर)',
                  'Total (एकूण)'
                ],
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                    color: PdfColors.white),
                headerDecoration:
                    pw.BoxDecoration(color: primaryColor),
                rowDecoration:
                    const pw.BoxDecoration(color: PdfColors.white),
                oddRowDecoration:
                    pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC')),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(
                    horizontal: 5, vertical: 4),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
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
                        final rawName =
                            item['item_name']?.toString() ?? 'Product';
                        // Bilingual Marathi name formatting
                        final bilingualName =
                            MarathiItemHelper.formatBilingual(rawName);

                        final qty =
                            (item['quantity'] as num?)?.toDouble() ?? 1.0;
                        final unit = item['unit']?.toString() ??
                            item['item_unit']?.toString() ??
                            'pcs';
                        final price =
                            (item['unit_price'] as num?)?.toDouble() ?? 0.0;
                        final total =
                            (item['total_price'] as num?)?.toDouble() ??
                                (qty * price);

                        return [
                          '$idx',
                          bilingualName,
                          '${AppFormatters.quantity(qty)} $unit',
                          '$safeCurrency ${price.toStringAsFixed(2)}',
                          '$safeCurrency ${total.toStringAsFixed(2)}',
                        ];
                      }).toList(),
              ),

              // ── Dedicated Total Package Weight & Parcel Summary Bar ──
              if (totalPackageWeightKg > 0 || nonWeightCount > 0) ...[
                pw.SizedBox(height: 4),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: lightColor,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(
                        color: borderColor, width: 0.8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('⚖️ Total Package Weight: ',
                              style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryColor)),
                          pw.Text(
                            totalPackageWeightKg > 0
                                ? UnitConverter.formatWeight(
                                    totalPackageWeightKg)
                                : 'N/A',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor),
                          ),
                        ],
                      ),
                      if (nonWeightCount > 0)
                        pw.Text(
                          '+ ${nonWeightCount.toStringAsFixed(nonWeightCount == nonWeightCount.roundToDouble() ? 0 : 1)} count/bunch items',
                          style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700),
                        ),
                    ],
                  ),
                ),
              ],
              pw.SizedBox(height: 6),

              // ── Financial Breakdown & Payment Status ────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Payment Status (पेमेंट स्थिती):',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                          order.remainingAmount <= 0
                              ? 'PAID IN FULL ✓ (पूर्ण भरले)'
                              : 'DUE / PENDING ($safeCurrency ${order.remainingAmount.toStringAsFixed(2)})',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: order.remainingAmount <= 0
                                ? PdfColors.green800
                                : PdfColors.orange900,
                          ),
                        ),
                        if (order.notes.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Text('Note: ${order.notes}',
                              style: const pw.TextStyle(
                                  fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      children: [
                        _buildRow('Subtotal (उप-एकूण):',
                            '$safeCurrency ${order.subtotal.toStringAsFixed(2)}', fontSize: 8.5),
                        if (settings != null && settings.enableGstTax) ...[
                          _buildRow(
                              'CGST (${(settings.gstRate / 2).toStringAsFixed(1)}%):',
                              '$safeCurrency ${(order.subtotal * (settings.gstRate / 200)).toStringAsFixed(2)}', fontSize: 8.5),
                          _buildRow(
                              'SGST (${(settings.gstRate / 2).toStringAsFixed(1)}%):',
                              '$safeCurrency ${(order.subtotal * (settings.gstRate / 200)).toStringAsFixed(2)}', fontSize: 8.5),
                        ],
                        if (order.discount > 0)
                          _buildRow('Discount Saved (सूट):',
                              '-$safeCurrency ${order.discount.toStringAsFixed(2)}',
                              color: PdfColors.green800, fontSize: 8.5),
                        if (order.deliveryCharge > 0)
                          _buildRow('Delivery Fee (डिलिव्हरी शुल्क):',
                              '+$safeCurrency ${order.deliveryCharge.toStringAsFixed(2)}', fontSize: 8.5),
                        pw.Divider(thickness: 0.6),
                        _buildRow(
                          'Grand Total (एकूण बिल):',
                          '$safeCurrency ${order.grandTotal.toStringAsFixed(2)}',
                          isBold: true,
                          fontSize: 10,
                          color: primaryColor,
                        ),
                        if (order.paidAmount > 0)
                          _buildRow('Amount Paid (दिलेली रक्कम):',
                              '$safeCurrency ${order.paidAmount.toStringAsFixed(2)}',
                              color: PdfColors.green900, fontSize: 8.5),
                        if (order.remainingAmount > 0)
                          _buildRow('Balance Due (बाकी रक्कम):',
                              '$safeCurrency ${order.remainingAmount.toStringAsFixed(2)}',
                              isBold: true,
                              color: PdfColors.red900, fontSize: 8.5),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),

              // ── Customer Savings Card (बचत तपशील) ───────────────
              if (currentOrderSavings > 0 || monthlySavings > 0)
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.symmetric(vertical: 3),
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(
                        color: PdfColors.green400, width: 1),
                  ),
                  child: pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '🎉 YOUR SAVINGS SUMMARY (तुमची एकूण बचत):',
                            style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green900),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '• Saved on this order: $safeCurrency ${currentOrderSavings.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green800),
                          ),
                          if (monthlySavings > 0)
                            pw.Text(
                              '• Total saved this month ($currentMonthName): $safeCurrency ${monthlySavings.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.teal900),
                            ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green700,
                          borderRadius: pw.BorderRadius.circular(5),
                        ),
                        child: pw.Text(
                          'SAVED $safeCurrency ${currentOrderSavings.toStringAsFixed(0)}',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              pw.SizedBox(height: 6),

              // ── Decorative Footer & Customer Satisfaction Promise ─
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: lightColor,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(
                      color: borderColor, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      '🌿 "Your satisfaction matters to us! If something isn\'t right, just let us know and we\'ll make it right. Thank you for trusting us with your everyday fresh vegetables & groceries!"',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '🌱 "तुमचे समाधान आमच्यासाठी सर्वात महत्त्वाचे आहे! काही अडचण असल्यास आम्हाला नक्की कळवा, आम्ही ते लगेच दुरुस्त करू. रोजच्या ताज्या भाज्यांसाठी आमच्यावर विश्वास ठेवल्याबद्दल मनःपूर्वक धन्यवाद! 🙏"',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              if (settings != null &&
                  settings.invoiceDisclaimer.trim().isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Terms: ${settings.invoiceDisclaimer.trim()}',
                    style: const pw.TextStyle(
                        fontSize: 7, color: PdfColors.grey600),
                  ),
                ),
              ],
            ];
          },
        ),
      );

      // Save PDF with sanitized Customer Name & Date
      final custName = (customer?.name.isNotEmpty == true)
          ? customer!.name
          : (order.customerName?.isNotEmpty == true
              ? order.customerName!
              : 'Customer');
      final custPhone = (customer?.phone1.isNotEmpty == true)
          ? customer!.phone1
          : (order.customerPhone ?? '');

      final dateFormatted = DateFormat('yyyy-MM-dd').format(now);
      final safeCustName = custName
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\u0900-\u097F\s]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final fileName = '${dateFormatted}_${safeCustName.isEmpty ? "Customer" : safeCustName}_Invoice.pdf';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (custPhone.isNotEmpty) {
        final cleanPhone = custPhone.replaceAll(RegExp(r'\D'), '');
        if (cleanPhone.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: cleanPhone));
        }
      }

      final shareText = custPhone.isNotEmpty
          ? '📄 Tax Invoice Bill: Order ${order.orderNoLabel}\n👤 Customer: $custName ($custPhone)\n🏪 Store: $businessName\n📅 Date: $orderDateStr'
          : '📄 Tax Invoice Bill: Order ${order.orderNoLabel}\n👤 Customer: $custName\n🏪 Store: $businessName\n📅 Date: $orderDateStr';

      await Share.shareXFiles(
        [XFile(file.path, name: fileName)],
        text: shareText,
      );

      if (context.mounted && custPhone.isNotEmpty) {
        SnackbarHelper.showInfo(
            context, 'Customer contact copied for quick WhatsApp search');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate graphic bill: $e')),
        );
      }
    }
  }

  static pw.Widget _buildRow(String label, String val,
      {bool isBold = false, double fontSize = 9, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
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
