import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    ),
  );

  const bName = 'MY BUSINESS STORE';
  const phone = '+91 9876543210';
  const whatsApp = '+91 9876543210';
  const safeCurrency = 'Rs.';

  final categoryGrouped = {
    'VEGETABLES': [
      {'name': 'Fresh Tomato', 'unit': '1 kg', 'marketPrice': 40.0, 'sellingPrice': 30.0},
      {'name': 'Potato / Aloo', 'unit': '1 kg', 'marketPrice': 35.0, 'sellingPrice': 28.0},
      {'name': 'Onion / Pyaz', 'unit': '1 kg', 'marketPrice': 50.0, 'sellingPrice': 42.0},
      {'name': 'Green Capsicum', 'unit': '500 g', 'marketPrice': 45.0, 'sellingPrice': 38.0},
    ],
    'FRUITS': [
      {'name': 'Royal Gala Apple', 'unit': '1 kg', 'marketPrice': 180.0, 'sellingPrice': 150.0},
      {'name': 'Robusta Banana', 'unit': '1 dozen', 'marketPrice': 60.0, 'sellingPrice': 48.0},
      {'name': 'Fresh Orange', 'unit': '1 kg', 'marketPrice': 120.0, 'sellingPrice': 95.0},
    ],
    'GROCERIES': [
      {'name': 'Premium Basmati Rice', 'unit': '5 kg', 'marketPrice': 350.0, 'sellingPrice': 310.0},
      {'name': 'Filtered Sunflower Oil', 'unit': '1 L', 'marketPrice': 165.0, 'sellingPrice': 145.0},
      {'name': 'Whole Wheat Atta', 'unit': '10 kg', 'marketPrice': 420.0, 'sellingPrice': 380.0},
    ],
  };

  int totalItems = 0;
  for (final l in categoryGrouped.values) {
    totalItems += l.length;
  }

  // Modern Premium Colors
  const primaryTeal = PdfColor.fromInt(0xFF004D40); // Deep Teal
  const accentGold = PdfColor.fromInt(0xFFFFB300); // Warm Gold
  const bgTealLight = PdfColor.fromInt(0xFFE0F2F1); // Light Teal Tint
  const priceBg = PdfColor.fromInt(0xFFE8EAF6); // Soft Indigo Tint
  const greenBg = PdfColor.fromInt(0xFFE8F5E9); // Light Emerald Tint
  const greenText = PdfColor.fromInt(0xFF1B5E20); // Dark Emerald Text

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      header: (pw.Context context) {
        return pw.Column(
          children: [
            // ── Premium Modern Header Banner ──
            pw.Container(
              decoration: const pw.BoxDecoration(
                color: primaryTeal,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Column(
                children: [
                  pw.Container(
                    height: 5,
                    decoration: const pw.BoxDecoration(
                      color: accentGold,
                      borderRadius: pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(10),
                        topRight: pw.Radius.circular(10),
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(16),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              bName.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 22,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: const pw.BoxDecoration(
                                color: PdfColor.fromInt(0xFF00695C),
                                borderRadius:
                                    pw.BorderRadius.all(pw.Radius.circular(5)),
                              ),
                              child: pw.Text(
                                'Phone: $phone  |  WhatsApp: $whatsApp',
                                style: pw.TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: const pw.BoxDecoration(
                                color: accentGold,
                                borderRadius:
                                    pw.BorderRadius.all(pw.Radius.circular(6)),
                              ),
                              child: pw.Text(
                                'OFFICIAL CATALOG',
                                style: pw.TextStyle(
                                  color: primaryTeal,
                                  fontSize: 10.5, // LARGER FONT SIZE
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              'Date: ${DateTime.now().toIso8601String().substring(0, 10)}',
                              style: const pw.TextStyle(
                                  fontSize: 9.5, color: PdfColors.teal50),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // ── Summary KPI Dashboard Box ──
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: pw.BoxDecoration(
                color: bgTealLight,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.teal200, width: 1.0),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 9,
                        height: 9,
                        decoration: const pw.BoxDecoration(
                            color: primaryTeal, shape: pw.BoxShape.circle),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        'Total Categories: ${categoryGrouped.length}',
                        style: pw.TextStyle(
                            fontSize: 9.5, // LARGER FONT SIZE
                            fontWeight: pw.FontWeight.bold,
                            color: primaryTeal),
                      ),
                    ],
                  ),
                  pw.Text('•', style: const pw.TextStyle(color: PdfColors.teal300)),
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 9,
                        height: 9,
                        decoration: const pw.BoxDecoration(
                            color: greenText, shape: pw.BoxShape.circle),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        'Total Products: $totalItems',
                        style: pw.TextStyle(
                            fontSize: 9.5, // LARGER FONT SIZE
                            fontWeight: pw.FontWeight.bold,
                            color: greenText),
                      ),
                    ],
                  ),
                  pw.Text('•', style: const pw.TextStyle(color: PdfColors.teal300)),
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 9,
                        height: 9,
                        decoration: const pw.BoxDecoration(
                            color: accentGold, shape: pw.BoxShape.circle),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        'Best Market Rates & Direct Delivery',
                        style: pw.TextStyle(
                            fontSize: 9.5, // LARGER FONT SIZE
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey900),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
          ],
        );
      },
      footer: (pw.Context context) {
        return pw.Column(
          children: [
            pw.Container(
              height: 2.0,
              color: primaryTeal,
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Disclaimer: Prices may change according to market rates.',
                  style: pw.TextStyle(
                    fontSize: 9, // LARGER FONT SIZE
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(
                    fontSize: 9, // LARGER FONT SIZE
                    fontWeight: pw.FontWeight.bold,
                    color: primaryTeal,
                  ),
                ),
              ],
            ),
          ],
        );
      },
      build: (pw.Context context) {
        final List<pw.Widget> widgets = [];

        categoryGrouped.forEach((categoryName, catItems) {
          // Category Ribbon Header
          widgets.add(
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 12, bottom: 6),
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: pw.BoxDecoration(
                color: bgTealLight,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.teal300, width: 1.0),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 5,
                        height: 16,
                        decoration: const pw.BoxDecoration(
                          color: primaryTeal,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        categoryName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 13, // LARGER FONT SIZE
                          fontWeight: pw.FontWeight.bold,
                          color: primaryTeal,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: const pw.BoxDecoration(
                      color: primaryTeal,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
                    ),
                    child: pw.Text(
                      '${catItems.length} ITEM(S)',
                      style: pw.TextStyle(
                        fontSize: 9, // LARGER FONT SIZE
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          widgets.add(
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside:
                    pw.BorderSide(color: PdfColors.grey300, width: 0.6),
                verticalInside:
                    pw.BorderSide(color: PdfColors.grey200, width: 0.6),
                top: pw.BorderSide(color: primaryTeal, width: 1.5),
                bottom: pw.BorderSide(color: primaryTeal, width: 1.5),
                left: pw.BorderSide(color: PdfColors.grey300, width: 0.6),
                right: pw.BorderSide(color: PdfColors.grey300, width: 0.6),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(3.2),
                1: const pw.FlexColumnWidth(1.8),
                2: const pw.FlexColumnWidth(2.2),
                3: const pw.FlexColumnWidth(3.4),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: primaryTeal),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      child: pw.Text('PRODUCT NAME',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10, // LARGER FONT SIZE
                              color: PdfColors.white)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      child: pw.Text('MARKET PRICE',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10, // LARGER FONT SIZE
                              color: PdfColors.white)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      child: pw.Text('ORDERKART PRICE',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10, // LARGER FONT SIZE
                              color: PdfColors.white)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      child: pw.Text('MONEY SAVED',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10, // LARGER FONT SIZE
                              color: PdfColors.white)),
                    ),
                  ],
                ),
                // Table Data Rows
                ...catItems.map((i) {
                  final name = i['name'] as String;
                  final unit = i['unit'] as String;
                  final marketPrice = i['marketPrice'] as double;
                  final sellingPrice = i['sellingPrice'] as double;

                  final savings = marketPrice > sellingPrice
                      ? marketPrice - sellingPrice
                      : 0.0;
                  final pct = marketPrice > 0
                      ? ((savings / marketPrice) * 100).toStringAsFixed(0)
                      : '0';

                  final nameWithUnit = '$name ($unit)';
                  final mktPriceStr =
                      '$safeCurrency ${marketPrice.toStringAsFixed(2)}';
                  final sellPriceStr =
                      '$safeCurrency ${sellingPrice.toStringAsFixed(2)}';

                  return pw.TableRow(
                    children: [
                      // Product Name
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        child: pw.Text(nameWithUnit,
                            style: pw.TextStyle(
                                fontSize: 9.5, // LARGER FONT SIZE
                                fontWeight: pw.FontWeight.bold)),
                      ),
                      // Market Price
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        child: pw.Text(
                          mktPriceStr,
                          style: const pw.TextStyle(
                              fontSize: 9.5, color: PdfColors.grey700),
                        ),
                      ),
                      // OrderKart Price Box
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: const pw.BoxDecoration(
                            color: priceBg,
                            borderRadius:
                                pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            sellPriceStr,
                            style: pw.TextStyle(
                              fontSize: 9.5, // LARGER FONT SIZE
                              fontWeight: pw.FontWeight.bold,
                              color: primaryTeal,
                            ),
                          ),
                        ),
                      ),
                      // MONEY SAVED (Emerald Pill Badge)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        child: savings > 0
                            ? pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: pw.BoxDecoration(
                                  color: greenBg,
                                  border: pw.Border.all(
                                      color: PdfColors.green400, width: 0.8),
                                  borderRadius: const pw.BorderRadius.all(
                                      pw.Radius.circular(4)),
                                ),
                                child: pw.Text(
                                  'SAVE $safeCurrency ${savings.toStringAsFixed(2)} ($pct% OFF)',
                                  style: pw.TextStyle(
                                    fontSize: 9.5, // LARGER FONT SIZE
                                    fontWeight: pw.FontWeight.bold, // BOLD % OFF
                                    color: greenText,
                                  ),
                                ),
                              )
                            : pw.Text('-', style: const pw.TextStyle(fontSize: 9.5)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          );

          widgets.add(pw.SizedBox(height: 12));
        });

        return widgets;
      },
    ),
  );

  final file = File('OrderKart_Catalog_Preview.pdf');
  await file.writeAsBytes(await pdf.save());
  print('PDF Preview generated successfully at ${file.absolute.path}');
}
