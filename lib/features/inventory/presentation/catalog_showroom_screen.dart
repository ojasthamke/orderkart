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
import '../domain/item.dart';
import 'inventory_provider.dart';

class CatalogShowroomScreen extends ConsumerStatefulWidget {
  const CatalogShowroomScreen({super.key});

  @override
  ConsumerState<CatalogShowroomScreen> createState() => _CatalogShowroomScreenState();
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

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ORDERKART OFFICIAL CATALOG', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Generated: ${DateTime.now().toIso8601String().substring(0, 10)}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: ['Product Name', 'Category', 'Selling Price', 'Unit', 'Stock Status'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              data: pdfItems.isEmpty
                  ? [
                      ['No products available', '', '', '', '']
                    ]
                  : pdfItems.map((i) {
                      return [
                        i.name,
                        i.category,
                        'Rs. ${i.sellingPrice.toStringAsFixed(2)}',
                        i.unit,
                        i.stock > 0 ? 'In Stock (${i.stock})' : 'Out of Stock'
                      ];
                    }).toList(),
            ),
          ];
        },
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/OrderKart_Catalog.pdf');
      await file.writeAsBytes(await pdf.save());
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Sharing OrderKart Official Product Stock & Price List Catalog',
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
                  backgroundColor: _getCategoryColor(item.category).withOpacity(0.1),
                  backgroundImage: (item.photoPath.isNotEmpty && (item.photoPath.startsWith('http') || AppConstants.resolveFile(item.photoPath).existsSync()))
                      ? (item.photoPath.startsWith('http')
                          ? NetworkImage(item.photoPath) as ImageProvider
                          : FileImage(AppConstants.resolveFile(item.photoPath)))
                      : null,
                  child: (item.photoPath.isEmpty || (!item.photoPath.startsWith('http') && !AppConstants.resolveFile(item.photoPath).existsSync()))
                      ? Icon(_getCategoryIcon(item.category), color: _getCategoryColor(item.category))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        item.category,
                        style: TextStyle(color: _getCategoryColor(item.category), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Specification fields
            _buildDetailRow('Unit / Pack Size', item.unit),
            _buildDetailRow('Price', '₹${item.sellingPrice.toStringAsFixed(2)}'),
            if (item.marketPrice > item.sellingPrice) ...[
              _buildDetailRow('Market Price', '₹${item.marketPrice.toStringAsFixed(2)}', isStrike: true),
              _buildDetailRow('Instant Savings', '₹${(item.marketPrice - item.sellingPrice).toStringAsFixed(2)}', isSavings: true),
            ],

            if (item.category == AppConstants.catMedicines) ...[
              if (item.dosageInfo.isNotEmpty) _buildDetailRow('Dosage Info', item.dosageInfo),
              if (item.expiryDate.isNotEmpty) _buildDetailRow('Expiry Date', item.expiryDate),
              _buildDetailRow('Requires Prescription (Rx)', item.prescriptionRequired ? 'Yes' : 'No', 
                  isRx: item.prescriptionRequired),
            ] else if (item.category == AppConstants.catGroceries) ...[
              if (item.bestBefore.isNotEmpty) _buildDetailRow('Best Before', item.bestBefore),
              if (item.packDate.isNotEmpty) _buildDetailRow('Pack Date', item.packDate),
            ],

            const SizedBox(height: 12),
            _buildDetailRow('Availability', item.stock > 0 ? 'In Stock' : 'Out of Stock', 
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Showroom', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStrike = false, bool isSavings = false, bool isRx = false, Color? color}) {
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
              color: isRx ? Colors.red : (isSavings ? Colors.green : (color ?? AppColors.textPrimary)),
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
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search items...',
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: catColor,
                    backgroundColor: AppColors.gray100,
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
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(child: Text('Error loading showroom: $e')),
              data: (itemsList) {
                // Filter items
                final filtered = itemsList.where((item) {
                  final matchesCat = _selectedCategory == 'all' || item.category == _selectedCategory;
                  final matchesSearch = item.name.toLowerCase().contains(_searchQuery);
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
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gray200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Visual category display block
                            Expanded(
                              flex: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: catColor.withOpacity(0.08),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  image: (item.photoPath.isNotEmpty && (item.photoPath.startsWith('http') || AppConstants.resolveFile(item.photoPath).existsSync()))
                                      ? DecorationImage(
                                          image: item.photoPath.startsWith('http')
                                              ? NetworkImage(item.photoPath) as ImageProvider
                                              : FileImage(AppConstants.resolveFile(item.photoPath)),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: (item.photoPath.isEmpty || (!item.photoPath.startsWith('http') && !AppConstants.resolveFile(item.photoPath).existsSync()))
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
                                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                                    ),
                                    const Spacer(),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '₹${item.sellingPrice.toStringAsFixed(1)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        if (item.marketPrice > item.sellingPrice) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '₹${item.marketPrice.toStringAsFixed(1)}',
                                            style: const TextStyle(
                                              decoration: TextDecoration.lineThrough,
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
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Save ₹${savings.toStringAsFixed(1)}',
                                          style: const TextStyle(
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
