import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../../../core/widgets/snackbar_helper.dart';
import '../../domain/item_variant.dart';
import '../../data/item_dao.dart';
import '../../data/inventory_repository_impl.dart';

/// Compact bottom sheet for adding or editing a variant (sub-product)
class VariantEditorSheet extends StatefulWidget {
  final String parentItemId;
  final String parentItemName;
  final ItemVariant? existingVariant; // null = add mode
  final VoidCallback onSaved;

  const VariantEditorSheet({
    super.key,
    required this.parentItemId,
    required this.parentItemName,
    this.existingVariant,
    required this.onSaved,
  });

  @override
  State<VariantEditorSheet> createState() => _VariantEditorSheetState();
}

class _VariantEditorSheetState extends State<VariantEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelCon = TextEditingController();
  final _sellCon = TextEditingController();
  final _costCon = TextEditingController();
  final _marketCon = TextEditingController();
  final _stockCon = TextEditingController();
  final _barcodeCon = TextEditingController();
  String _unit = AppConstants.unitKg;
  String _photoPath = '';
  bool _isUploadingPhoto = false;
  bool _isAvailable = true;
  bool _saving = false;

  bool get _isEditing => widget.existingVariant != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final v = widget.existingVariant!;
      _labelCon.text = v.variantLabel;
      _sellCon.text = v.sellingPrice > 0 ? v.sellingPrice.toString() : '';
      _costCon.text = v.costPrice > 0 ? v.costPrice.toString() : '';
      _marketCon.text = v.marketPrice > 0 ? v.marketPrice.toString() : '';
      _stockCon.text = v.stock > 0 ? v.stock.toString() : '';
      _barcodeCon.text = v.barcode;
      _photoPath = v.photoPath;
      _unit = v.unit;
      _isAvailable = v.isAvailable;
    }
  }

  @override
  void dispose() {
    _labelCon.dispose();
    _sellCon.dispose();
    _costCon.dispose();
    _marketCon.dispose();
    _stockCon.dispose();
    _barcodeCon.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final img = await ImageUtils.pickAndCompress(source: source);
      if (img != null) {
        final fileName = 'variant_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = await ImageUtils.saveImagePermanently(
          sourcePath: img.path,
          subFolder: 'variant_photos',
          fileName: fileName,
        );
        if (mounted) {
          setState(() => _photoPath = savedPath ?? img.path);
        }

        // Upload to Supabase Storage bucket 'product-images' so other apps & customers get it
        try {
          final fileBytes = await File(img.path).readAsBytes();
          final storage = Supabase.instance.client.storage;
          await storage.from('product-images').uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '31536000',
              upsert: true,
            ),
          );
          final publicUrl = storage.from('product-images').getPublicUrl(fileName);
          if (mounted && publicUrl.isNotEmpty) {
            setState(() => _photoPath = publicUrl);
          }
        } catch (storageErr) {
          debugPrint('Variant image cloud upload failed, kept local: $storageErr');
        }
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Failed to pick image: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final dao = ItemDao();
      final now = DateTime.now();
      final variant = ItemVariant(
        id: _isEditing ? widget.existingVariant!.id : '',
        parentItemId: widget.parentItemId,
        variantLabel: _labelCon.text.trim(),
        sellingPrice: double.tryParse(_sellCon.text) ?? 0,
        costPrice: double.tryParse(_costCon.text) ?? 0,
        marketPrice: double.tryParse(_marketCon.text) ?? 0,
        stock: double.tryParse(_stockCon.text) ?? 0,
        unit: _unit,
        barcode: _barcodeCon.text.trim(),
        photoPath: _photoPath,
        isAvailable: _isAvailable,
        sequenceNo: _isEditing ? widget.existingVariant!.sequenceNo : 0,
        createdAt: _isEditing ? widget.existingVariant!.createdAt : now,
        updatedAt: now,
      );

      if (_isEditing) {
        await dao.updateVariant(variant);
      } else {
        await dao.insertVariant(variant);
      }

      // Sync updated variants to Supabase so customer app sees them immediately
      try {
        await InventoryRepositoryImpl(dao).syncItemVariantsToSupabase(widget.parentItemId);
      } catch (e) {
        debugPrint('Variant sync error: $e');
      }

      widget.onSaved();
      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          _isEditing ? 'Variant updated!' : 'Variant added!',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isEditing
                          ? Icons.edit_rounded
                          : Icons.add_box_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Variant' : 'Add Variant',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.parentItemName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Sub-product Photo Picker
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: _photoPath.isNotEmpty
                                  ? (_photoPath.startsWith('http')
                                      ? AppCachedImage(
                                          imageUrl: _photoPath,
                                          fit: BoxFit.cover,
                                          width: 80,
                                          height: 80,
                                        )
                                      : Image.file(
                                          File(_photoPath),
                                          fit: BoxFit.cover,
                                          width: 80,
                                          height: 80,
                                        ))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_a_photo_outlined,
                                          color: AppColors.primary,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Photo',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          if (_isUploadingPhoto)
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          if (_photoPath.isNotEmpty && !_isUploadingPhoto)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => setState(() => _photoPath = ''),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _photoPath.isEmpty ? 'Add Sub-Product Photo' : 'Change Photo',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Variant Label
              TextFormField(
                controller: _labelCon,
                decoration: InputDecoration(
                  labelText: 'Variant Name *',
                  hintText: 'e.g. 1kg Pack, 500g, Family Pack',
                  prefixIcon: const Icon(Icons.label_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),

              // Price Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sellCon,
                      decoration: InputDecoration(
                        labelText: 'Sell Price',
                        prefixText: '₹',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _costCon,
                      decoration: InputDecoration(
                        labelText: 'Cost Price',
                        prefixText: '₹',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // MRP + Stock Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _marketCon,
                      decoration: InputDecoration(
                        labelText: 'MRP',
                        prefixText: '₹',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _stockCon,
                      decoration: InputDecoration(
                        labelText: 'Stock',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Unit Selector
              Wrap(
                spacing: 8,
                children: [
                  AppConstants.unitKg,
                  'g',
                  'piece',
                  'packet',
                  'litre',
                  'ml',
                  'box',
                  'dozen',
                ].map((u) {
                  final isSelected = _unit == u;
                  return ChoiceChip(
                    label: Text(u, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    onSelected: (_) => setState(() => _unit = u),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Available toggle
              SwitchListTile.adaptive(
                title: const Text('Available',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_isAvailable
                    ? 'Variant visible to customers'
                    : 'Hidden from customers'),
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded),
                  label: Text(_isEditing ? 'Save Changes' : 'Add Variant'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
