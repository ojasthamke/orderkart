import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    }    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );
    int totalPdfItems = 0;
    for (final l in categoryGrouped.values) {
      totalPdfItems += l.length;
    }

    const primaryTeal = PdfColor.fromInt(0xFF004D40);
    const accentGold = PdfColor.fromInt(0xFFFFB300);
    const bgTealLight = PdfColor.fromInt(0xFFE0F2F1);
    const priceBg = PdfColor.fromInt(0xFFE8EAF6);
    const greenBg = PdfColor.fromInt(0xFFE8F5E9);
    const greenText = PdfColor.fromInt(0xFF1B5E20);

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
                              if (phone.isNotEmpty || whatsApp.isNotEmpty) ...[
                                pw.SizedBox(height: 8),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColor.fromInt(0xFF00695C),
                                    borderRadius: pw.BorderRadius.all(
                                        pw.Radius.circular(5)),
                                  ),
                                  child: pw.Text(
                                    [
                                      if (phone.isNotEmpty) 'Phone: $phone',
                                      if (whatsApp.isNotEmpty)
                                        'WhatsApp: $whatsApp',
                                    ].join('  |  '),
                                    style: pw.TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.white,
                                    ),
                                  ),
                                ),
                              ],
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
                                  borderRadius: pw.BorderRadius.all(
                                      pw.Radius.circular(6)),
                                ),
                                child: pw.Text(
                                  'OFFICIAL CATALOG',
                                  style: pw.TextStyle(
                                    color: primaryTeal,
                                    fontSize: 10.5,
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
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16, vertical: 9),
                decoration: pw.BoxDecoration(
                  color: bgTealLight,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
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
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryTeal),
                        ),
                      ],
                    ),
                    pw.Text('•',
                        style: const pw.TextStyle(color: PdfColors.teal300)),
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
                          'Total Products: $totalPdfItems',
                          style: pw.TextStyle(
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              color: greenText),
                        ),
                      ],
                    ),
                    pw.Text('•',
                        style: const pw.TextStyle(color: PdfColors.teal300)),
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
                              fontSize: 9.5,
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
                    0: const pw.FlexColumnWidth(3.2),
                    1: const pw.FlexColumnWidth(1.8),
                    2: const pw.FlexColumnWidth(2.2),
                    3: const pw.FlexColumnWidth(3.4),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: primaryTeal),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          child: pw.Text('PRODUCT NAME',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                  color: PdfColors.white)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          child: pw.Text('MARKET PRICE',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                  color: PdfColors.white)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          child: pw.Text('ORDERKART PRICE',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                  color: PdfColors.white)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          child: pw.Text('MONEY SAVED',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
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

                      final nameWithUnit = i.unit.isNotEmpty
                          ? '${i.name} (${i.unit})'
                          : i.name;
                      final mktPriceStr = i.marketPrice > 0
                          ? '$safeCurrency ${i.marketPrice.toStringAsFixed(2)}'
                          : '-';
                      final sellPriceStr =
                          '$safeCurrency ${i.sellingPrice.toStringAsFixed(2)}';
                      final savedStr = savings > 0
                          ? 'SAVE $safeCurrency ${savings.toStringAsFixed(2)} ($pct% OFF)'
                          : '-';

                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            child: pw.Text(nameWithUnit,
                                style: pw.TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            child: pw.Text(mktPriceStr,
                                style: const pw.TextStyle(
                                    fontSize: 9.5, color: PdfColors.grey700)),
                          ),
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
                                  fontSize: 9.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryTeal,
                                ),
                              ),
                            ),
                          ),
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
                                          color: PdfColors.green400,
                                          width: 0.8),
                                      borderRadius: const pw.BorderRadius.all(
                                          pw.Radius.circular(4)),
                                    ),
                                    child: pw.Text(
                                      savedStr,
                                      style: pw.TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: greenText,
                                      ),
                                    ),
                                  )
                                : pw.Text('-',
                                    style: const pw.TextStyle(fontSize: 9.5)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              );

              widgets.add(pw.SizedBox(height: 12));
            });
          }

          return widgets;
        },
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/OrderKart_Catalog.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Sharing Product Catalog & Price List',
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
