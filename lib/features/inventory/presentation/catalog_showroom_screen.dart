import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/utils/pdf_font_helper.dart';
import '../../../core/utils/marathi_item_helper.dart';
import '../domain/item.dart';
import 'inventory_provider.dart';
import '../../settings/presentation/settings_provider.dart';

class CatalogShowroomScreen extends ConsumerStatefulWidget {
  const CatalogShowroomScreen({super.key});

  @override
  ConsumerState<CatalogShowroomScreen> createState() =>
      _CatalogShowroomScreenState();
}

class _CatalogShowroomScreenState extends ConsumerState<CatalogShowroomScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  Future<void> _sharePdfCatalog(List<Item> items) async {
    List<Item> pdfItems = items;
    try {
      final all = await ref.read(inventoryRepositoryProvider).getAllItems();
      if (all.isNotEmpty) {
        pdfItems = all;
      }
    } catch (_) {}

    final settingsVal = ref.read(settingsProvider).valueOrNull;
    final currency = settingsVal?.currency ?? '₹';
    final safeCurrency = currency == '₹' ? 'Rs.' : currency;
    final bName = (settingsVal?.businessName.trim().isNotEmpty ?? false)
        ? settingsVal!.businessName.trim()
        : 'OrderKart Store';
    final phone = settingsVal?.phone.trim() ?? '';
    final whatsApp = settingsVal?.whatsApp.trim() ?? '';

    // Group items by category
    final Map<String, List<Item>> categoryGrouped = {};
    for (final item in pdfItems) {
      final cat = item.category.trim().isEmpty ? 'General' : item.category.trim();
      categoryGrouped.putIfAbsent(cat, () => []).add(item);
    }
    final pdfTheme = await PdfFontHelper.getDevanagariTheme();
    final pdf = pw.Document(theme: pdfTheme);

    const primaryTeal = PdfColor.fromInt(0xFF004D40);
    const accentGold = PdfColor.fromInt(0xFFFFB300);
    const bgTealLight = PdfColor.fromInt(0xFFE0F2F1);
    const priceBg = PdfColor.fromInt(0xFFE8EAF6);
    const greenBg = PdfColor.fromInt(0xFFE8F5E9);
    const greenText = PdfColor.fromInt(0xFF1B5E20);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              // ── Premium Modern Header Banner ──
              pw.Container(
                decoration: const pw.BoxDecoration(
                  color: primaryTeal,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    pw.Container(
                      height: 4,
                      decoration: const pw.BoxDecoration(
                        color: accentGold,
                        borderRadius: pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(8),
                          topRight: pw.Radius.circular(8),
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                ),
                              ),
                              if (phone.isNotEmpty || whatsApp.isNotEmpty) ...[
                                pw.SizedBox(height: 4),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColor.fromInt(0xFF00695C),
                                    borderRadius: pw.BorderRadius.all(
                                        pw.Radius.circular(4)),
                                  ),
                                  child: pw.Text(
                                    [
                                      if (phone.isNotEmpty) 'Phone: $phone',
                                      if (whatsApp.isNotEmpty)
                                        'WhatsApp: $whatsApp',
                                    ].join('  |  '),
                                    style: const pw.TextStyle(
                                        fontSize: 7.5, color: PdfColors.white),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: const pw.BoxDecoration(
                              color: accentGold,
                              borderRadius:
                                  pw.BorderRadius.all(pw.Radius.circular(6)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text(
                                  'OFFICIAL CATALOG',
                                  style: pw.TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey900,
                                  ),
                                ),
                                pw.Text(
                                  'DAILY FRESH RATES',
                                  style: const pw.TextStyle(
                                      fontSize: 7.0, color: PdfColors.grey800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
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
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(
                      fontSize: 9,
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

          if (categoryGrouped.isEmpty) {
            widgets.add(
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 40),
                  child: pw.Text(
                    'No products available in catalog',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                  ),
                ),
              ),
            );
          } else {
            categoryGrouped.forEach((categoryName, catItems) {
              widgets.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 12, bottom: 6),
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: pw.BoxDecoration(
                    color: bgTealLight,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border:
                        pw.Border.all(color: PdfColors.teal300, width: 1.0),
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
                              borderRadius:
                                  pw.BorderRadius.all(pw.Radius.circular(2)),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            categoryName.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 13,
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
                          borderRadius:
                              pw.BorderRadius.all(pw.Radius.circular(10)),
                        ),
                        child: pw.Text(
                          '${catItems.length} ITEM(S)',
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
              );

              widgets.add(
                pw.Table(
                  border: const pw.TableBorder(
                    horizontalInside: pw.BorderSide(
                        color: PdfColors.grey300, width: 0.6),
                    verticalInside: pw.BorderSide(
                        color: PdfColors.grey200, width: 0.6),
                    top: pw.BorderSide(color: primaryTeal, width: 1.5),
                    bottom: pw.BorderSide(color: primaryTeal, width: 1.5),
                    left: pw.BorderSide(color: PdfColors.grey300, width: 0.6),
                    right: pw.BorderSide(color: PdfColors.grey300, width: 0.6),
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.8),
                    1: const pw.FlexColumnWidth(1.6),
                    2: const pw.FlexColumnWidth(1.6),
                    3: const pw.FlexColumnWidth(1.6),
                    4: const pw.FlexColumnWidth(1.6),
                    5: const pw.FlexColumnWidth(2.8),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: primaryTeal),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 3),
                          child: pw.Text('PRODUCT NAME',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 7.5,
                                  color: PdfColors.white)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 3),
                          child: pw.Text('MARKET RATE\n( kg )',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 7.5,
                                  color: PdfColors.white)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 3),
                          child: pw.Text('250 GM\nMARKET',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 7.5,
                                  color: PdfColors.white)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 3),
                          child: pw.Text('ORDERKART RATE\n( kg )',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 7.5,
                                  color: PdfColors.white)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 3),
                          child: pw.Text('250 GM\nORDERKART',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 7.5,
                                  color: PdfColors.white)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 4, vertical: 3),
                          child: pw.Text('MONEY SAVED',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 7.5,
                                  color: PdfColors.white)),
                        ),
                      ],
                    ),
                    ...catItems.map((i) {
                      final savings = i.marketPrice > i.sellingPrice
                          ? i.marketPrice - i.sellingPrice
                          : 0.0;
                      final pct = i.marketPrice > 0
                          ? ((savings / i.marketPrice) * 100)
                              .toStringAsFixed(0)
                          : '0';

                      final bilingualName = MarathiItemHelper.formatBilingual(i.name);
                      final nameWithUnit = i.unit.isNotEmpty
                          ? '$bilingualName (${i.unit})'
                          : bilingualName;
                      final mktPriceStr = i.marketPrice > 0
                          ? '$safeCurrency ${i.marketPrice.toStringAsFixed(2)}'
                          : '-';
                      final sellPriceStr =
                          '$safeCurrency ${i.sellingPrice.toStringAsFixed(2)}';
                      final savedStr = savings > 0
                          ? 'SAVE $safeCurrency ${savings.toStringAsFixed(2)} ($pct%)'
                          : '-';

                      // Calculate 250gm prices for weight-based units
                      final unitLower = i.unit.trim().toLowerCase();
                      final bool isKgUnit = unitLower == 'kg' || unitLower == 'kilo' || unitLower == 'kilogram' || unitLower == 'kilograms';
                      final bool isGmUnit = unitLower == 'gram' || unitLower == 'grams' || unitLower == 'g' || unitLower == 'gm' || unitLower == 'gms';

                      String mkt250Str = '-';
                      String sell250Str = '-';
                      if (isKgUnit) {
                        if (i.marketPrice > 0) {
                          mkt250Str = '$safeCurrency ${(i.marketPrice * 0.25).toStringAsFixed(2)}';
                        }
                        sell250Str = '$safeCurrency ${(i.sellingPrice * 0.25).toStringAsFixed(2)}';
                      } else if (isGmUnit) {
                        if (i.marketPrice > 0) {
                          mkt250Str = '$safeCurrency ${(i.marketPrice * 250).toStringAsFixed(2)}';
                        }
                        sell250Str = '$safeCurrency ${(i.sellingPrice * 250).toStringAsFixed(2)}';
                      }

                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2.5),
                            child: pw.Text(nameWithUnit,
                                style: pw.TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2.5),
                            child: pw.Text(mktPriceStr,
                                style: const pw.TextStyle(
                                    fontSize: 7.5, color: PdfColors.grey700)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2.5),
                            child: pw.Text(mkt250Str,
                                style: const pw.TextStyle(
                                    fontSize: 7.5, color: PdfColors.grey600)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2.5),
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1.5),
                              decoration: const pw.BoxDecoration(
                                color: priceBg,
                                borderRadius:
                                    pw.BorderRadius.all(pw.Radius.circular(3)),
                              ),
                              child: pw.Text(
                                sellPriceStr,
                                style: pw.TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryTeal,
                                ),
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2.5),
                            child: sell250Str != '-'
                                ? pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1.5),
                                    decoration: const pw.BoxDecoration(
                                      color: priceBg,
                                      borderRadius:
                                          pw.BorderRadius.all(pw.Radius.circular(3)),
                                    ),
                                    child: pw.Text(
                                      sell250Str,
                                      style: pw.TextStyle(
                                        fontSize: 7.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: primaryTeal,
                                      ),
                                    ),
                                  )
                                : pw.Text('-',
                                    style: const pw.TextStyle(fontSize: 7.5)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2.5),
                            child: savings > 0
                                ? pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1.5),
                                    decoration: pw.BoxDecoration(
                                      color: greenBg,
                                      border: pw.Border.all(
                                          color: PdfColors.green400,
                                          width: 0.6),
                                      borderRadius: const pw.BorderRadius.all(
                                          pw.Radius.circular(3)),
                                    ),
                                    child: pw.Text(
                                      savedStr,
                                      style: pw.TextStyle(
                                        fontSize: 7.0,
                                        fontWeight: pw.FontWeight.bold,
                                        color: greenText,
                                      ),
                                    ),
                                  )
                                : pw.Text('-',
                                    style: const pw.TextStyle(fontSize: 7.5)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              );

              widgets.add(pw.SizedBox(height: 6));
            });

            // Decorative Satisfaction Footer Box in Catalog
            widgets.add(
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: bgTealLight,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.teal300, width: 1.0),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      '🌿 "Your satisfaction matters to us! If something isn\'t right, just let us know and we\'ll make it right. Thank you for trusting us with your everyday fresh vegetables & groceries!" 🙏',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryTeal,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      '🌱 "तुमचे समाधान आमच्यासाठी सर्वात महत्त्वाचे आहे! काही अडचण असल्यास आम्हाला नक्की कळवा. रोजच्या ताज्या भाज्यांसाठी मनःपूर्वक धन्यवाद!"',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryTeal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return widgets;
        },
      ),
    );

    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final fileName = '${dateStr}_Product_Catalog.pdf';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path, name: fileName)],
        text: 'Sharing Product Catalog & Price List ($dateStr)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Generation failed: $e')),
        );
      }
    }
  }

  final List<String> _categories = [
    'all',
    AppConstants.catVegetables,
    AppConstants.catFruits,
    AppConstants.catGroceries,
    AppConstants.catMedicines,
    'Other'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case AppConstants.catVegetables:
        return Colors.green;
      case AppConstants.catFruits:
        return Colors.orange;
      case AppConstants.catGroceries:
        return Colors.blue;
      case AppConstants.catMedicines:
        return Colors.teal;
      default:
        return Colors.purple;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case AppConstants.catVegetables:
        return Icons.local_florist_rounded;
      case AppConstants.catFruits:
        return Icons.apple_rounded;
      case AppConstants.catGroceries:
        return Icons.shopping_basket_rounded;
      case AppConstants.catMedicines:
        return Icons.medical_services_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  void _showItemDetails(Item item) {
    final settingsVal = ref.read(settingsProvider).valueOrNull;
    final currency = settingsVal?.currency ?? '₹';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      _getCategoryColor(item.category).withOpacity(0.1),
                  backgroundImage: (item.photoPath.isNotEmpty &&
                          (item.photoPath.startsWith('http') ||
                              AppConstants.resolveFile(item.photoPath)
                                  .existsSync()))
                      ? (item.photoPath.startsWith('http')
                          ? NetworkImage(item.photoPath) as ImageProvider
                          : FileImage(AppConstants.resolveFile(item.photoPath)))
                      : null,
                  child: (item.photoPath.isEmpty ||
                          (!item.photoPath.startsWith('http') &&
                              !AppConstants.resolveFile(item.photoPath)
                                  .existsSync()))
                      ? Icon(_getCategoryIcon(item.category),
                          color: _getCategoryColor(item.category))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        item.category,
                        style: TextStyle(
                            color: _getCategoryColor(item.category),
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Specification fields
            _buildDetailRow('Unit / Pack Size', item.unit),
            _buildDetailRow(
                'Price', '$currency${item.sellingPrice.toStringAsFixed(2)}'),
            if (item.marketPrice > item.sellingPrice) ...[
              _buildDetailRow('Market Price',
                  '$currency${item.marketPrice.toStringAsFixed(2)}',
                  isStrike: true),
              _buildDetailRow('Instant Savings',
                  '$currency${(item.marketPrice - item.sellingPrice).toStringAsFixed(2)}',
                  isSavings: true),
            ],

            if (item.category == AppConstants.catMedicines) ...[
              if (item.dosageInfo.isNotEmpty)
                _buildDetailRow('Dosage Info', item.dosageInfo),
              if (item.expiryDate.isNotEmpty)
                _buildDetailRow('Expiry Date', item.expiryDate),
              _buildDetailRow('Requires Prescription (Rx)',
                  item.prescriptionRequired ? 'Yes' : 'No',
                  isRx: item.prescriptionRequired),
            ] else if (item.category == AppConstants.catGroceries) ...[
              if (item.bestBefore.isNotEmpty)
                _buildDetailRow('Best Before', item.bestBefore),
              if (item.packDate.isNotEmpty)
                _buildDetailRow('Pack Date', item.packDate),
            ],

            const SizedBox(height: 12),
            _buildDetailRow(
                'Availability', item.stock > 0 ? 'In Stock' : 'Out of Stock',
                color: item.stock > 0 ? Colors.green : Colors.red),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Showroom',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isStrike = false,
      bool isSavings = false,
      bool isRx = false,
      Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isRx
                  ? Colors.red
                  : (isSavings
                      ? Colors.green
                      : (color ?? AppColors.textPrimary)),
              decoration: isStrike ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsVal = ref.watch(settingsProvider).valueOrNull;
    final currency = settingsVal?.currency ?? '₹';

    return AppScaffold(
      title: 'Showroom Mode',
      actions: [
        itemsAsync.maybeWhen(
          data: (items) => IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Share PDF Catalog',
            onPressed: () => _sharePdfCatalog(items),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
      body: Column(
        children: [
          // Search & Filter Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B).withOpacity(0.4)
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.12)
                              : AppColors.gray200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(
                          () => _searchQuery = val.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search items...',
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Colors.grey),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Categories Chips Row
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                final catColor = _getCategoryColor(cat);

                return Container(
                  margin: const EdgeInsets.only(right: 8, bottom: 8),
                  child: ChoiceChip(
                    label: Text(
                      cat == 'all' ? 'All Items' : cat,
                      style: TextStyle(
                        color: isSelected
                            ? (isDark ? Colors.white : catColor)
                            : (isDark
                                ? Colors.white70
                                : AppColors.textSecondary),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor:
                        catColor.withOpacity(isSelected ? 0.35 : 0.8),
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.08)
                        : AppColors.gray100,
                    side: BorderSide(
                      color: isSelected
                          ? catColor
                          : (isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.transparent),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = cat);
                      }
                    },
                  ),
                );
              },
            ),
          ),

          const Divider(),

          // Grid View of Showroom Products
          Expanded(
            child: itemsAsync.when(
              loading: () =>
                  LoadingShimmer.grid(count: 6, childAspectRatio: 0.82),
              error: (e, _) =>
                  Center(child: Text('Error loading showroom: $e')),
              data: (itemsList) {
                // Filter items
                final filtered = itemsList.where((item) {
                  final matchesCat = _selectedCategory == 'all' ||
                      item.category == _selectedCategory;
                  final matchesSearch =
                      item.name.toLowerCase().contains(_searchQuery);
                  return matchesCat && matchesSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.grid_view_rounded,
                    title: 'No Items Displayed',
                    subtitle: 'Modify filters or search term to show products',
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final catColor = _getCategoryColor(item.category);
                    final savings = item.marketPrice - item.sellingPrice;

                    return GestureDetector(
                      onTap: () => _showItemDetails(item),
                      child: GlassContainer(
                        borderRadius: BorderRadius.circular(16),
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Visual category display block
                            Expanded(
                              flex: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: catColor.withOpacity(0.08),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16)),
                                  image: (item.photoPath.isNotEmpty &&
                                          (item.photoPath.startsWith('http') ||
                                              AppConstants.resolveFile(
                                                      item.photoPath)
                                                  .existsSync()))
                                      ? DecorationImage(
                                          image:
                                              item.photoPath.startsWith('http')
                                                  ? NetworkImage(item.photoPath)
                                                      as ImageProvider
                                                  : FileImage(
                                                      AppConstants.resolveFile(
                                                          item.photoPath)),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: (item.photoPath.isEmpty ||
                                        (!item.photoPath.startsWith('http') &&
                                            !AppConstants.resolveFile(
                                                    item.photoPath)
                                                .existsSync()))
                                    ? Center(
                                        child: Icon(
                                          _getCategoryIcon(item.category),
                                          size: 44,
                                          color: catColor.withOpacity(0.85),
                                        ),
                                      )
                                    : null,
                              ),
                            ),

                            // Item Name & Prices
                            Expanded(
                              flex: 5,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.category}  •  ${item.unit}',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 10),
                                    ),
                                    const Spacer(),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '$currency${item.sellingPrice.toStringAsFixed(1)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        if (item.marketPrice >
                                            item.sellingPrice) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '$currency${item.marketPrice.toStringAsFixed(1)}',
                                            style: TextStyle(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              color: Colors.grey,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (savings > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Save $currency${savings.toStringAsFixed(1)}',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
