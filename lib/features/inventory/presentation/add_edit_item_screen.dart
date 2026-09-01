import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/security/app_mode_service.dart';
import '../domain/item.dart';
import 'inventory_provider.dart';
import '../../settings/presentation/settings_provider.dart';

class AddEditItemScreen extends ConsumerStatefulWidget {
  final String? itemId;
  const AddEditItemScreen({super.key, this.itemId});

  @override
  ConsumerState<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends ConsumerState<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCon = TextEditingController();
  final _costCon = TextEditingController();
  final _sellCon = TextEditingController();
  final _marketCon = TextEditingController();
  final _stockCon = TextEditingController();
  final _minStockCon = TextEditingController();
  final _barcodeCon = TextEditingController();
  final _sequenceCon = TextEditingController();

  // Order Now fields
  final _orderNowStockCon = TextEditingController();
  final _orderNowSellCon = TextEditingController();
  final _orderNowMrpCon = TextEditingController();
  final _orderNowCostCon = TextEditingController();
  bool _orderNowIsAvailable = true;

  // New V6 fields
  final _expiryCon = TextEditingController();
  final _batchCon = TextEditingController();
  final _dosageCon = TextEditingController();
  final _bestBeforeCon = TextEditingController();
  final _packCon = TextEditingController();
  final _weightPerPieceCon = TextEditingController(text: '0.25');
  bool _rxRequired = false;
  String _photoPath = '';
  DateTime _createdAt = DateTime.now();


  String _category = AppConstants.catVegetables;
  String _unit = AppConstants.unitKg;
  bool _loading = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mode = ref.read(appModeProvider).value;
      if (mode == AppMode.worker) {
        if (mounted) {
          SnackbarHelper.showError(
              context, 'Access Denied: Workers cannot manage items.');
          Navigator.pop(context);
        }
      }
    });
    if (widget.itemId != null) {
      _isEdit = true;
      _loadItem();
    }
  }

  String _initialName = '';
  String _initialCost = '';
  String _initialSell = '';
  String _initialStock = '';

  Future<void> _loadItem() async {
    final item =
        await ref.read(inventoryRepositoryProvider).getItemById(widget.itemId!);
    if (item != null && mounted) {
      setState(() {
        _initialName = item.name;
        _initialCost = item.costPrice.toString();
        _initialSell = item.sellingPrice.toString();
        _initialStock = item.stock.toString();

        _nameCon.text = item.name;
        _costCon.text = item.costPrice.toString();
        _sellCon.text = item.sellingPrice.toString();
        _marketCon.text = item.marketPrice.toString();
        _stockCon.text = item.stock.toString();
        _minStockCon.text = item.minStock.toString();
        _barcodeCon.text = item.barcode;
        _sequenceCon.text = item.sequenceNo > 0 ? '${item.sequenceNo}' : '';
        _category = item.category;
        _unit = AppConstants.itemUnits.contains(item.unit)
            ? item.unit
            : AppConstants.unitKg;
        _expiryCon.text = item.expiryDate;
        _batchCon.text = item.batchNumber;
        _dosageCon.text = item.dosageInfo;
        _bestBeforeCon.text = item.bestBefore;
        _packCon.text = item.packDate;
        _rxRequired = item.prescriptionRequired;
        _weightPerPieceCon.text = item.weightPerPiece.toString();
        _photoPath = item.photoPath;
        _createdAt = item.createdAt;

        // Order Now fields
        _orderNowStockCon.text = item.orderNowStock > 0 ? '${item.orderNowStock}' : '';
        _orderNowSellCon.text = item.orderNowSellingPrice > 0 ? '${item.orderNowSellingPrice}' : '';
        _orderNowMrpCon.text = item.orderNowMrp > 0 ? '${item.orderNowMrp}' : '';
        _orderNowCostCon.text = item.orderNowCostPrice > 0 ? '${item.orderNowCostPrice}' : '';
        _orderNowIsAvailable = item.orderNowIsAvailable;
      });

    }
  }

  bool _hasUnsavedChanges() {
    if (_isEdit) {
      return _nameCon.text != _initialName ||
          _costCon.text != _initialCost ||
          _sellCon.text != _initialSell ||
          _stockCon.text != _initialStock;
    }
    return _nameCon.text.trim().isNotEmpty ||
        _costCon.text.trim().isNotEmpty ||
        _sellCon.text.trim().isNotEmpty ||
        _stockCon.text.trim().isNotEmpty ||
        _barcodeCon.text.trim().isNotEmpty ||
        _photoPath.isNotEmpty;
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges()) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Discard Item Changes?'),
          ],
        ),
        content: const Text(
            'You have unsaved changes in this item form. Are you sure you want to leave without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _nameCon.dispose();
    _costCon.dispose();
    _sellCon.dispose();
    _marketCon.dispose();
    _stockCon.dispose();
    _minStockCon.dispose();
    _barcodeCon.dispose();
    _sequenceCon.dispose();
    _orderNowStockCon.dispose();
    _orderNowSellCon.dispose();
    _orderNowMrpCon.dispose();
    _orderNowCostCon.dispose();
    _expiryCon.dispose();

    _batchCon.dispose();
    _dosageCon.dispose();
    _bestBeforeCon.dispose();
    _packCon.dispose();
    _weightPerPieceCon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final currency = settings?.currency ?? AppConstants.defaultCurrency;

    return PopScope(
      canPop: !_hasUnsavedChanges(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscard();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: AppScaffold(
        title: _isEdit ? 'Edit Item' : 'Add Item',
        onBack: () async {
          final shouldPop = await _confirmDiscard();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo picker
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.primaryLight, width: 2),
                          image: _photoPath.isNotEmpty
                              ? DecorationImage(
                                  image: _photoPath.startsWith('http')
                                      ? NetworkImage(_photoPath)
                                          as ImageProvider
                                      : FileImage(File(_photoPath)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _photoPath.isEmpty
                            ? const Icon(Icons.camera_alt_rounded,
                                size: 36, color: AppColors.primary)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _photoPath.isEmpty ? 'Add Photo' : 'Change Photo',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameCon,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  prefixIcon: Icon(Icons.inventory_2_rounded),
                ),
                validator: (v) =>
                    AppValidators.nameField(v, field: 'Item name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _sequenceCon,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Serial No. / Sequence No.',
                  prefixIcon: Icon(Icons.format_list_numbered_rounded),
                  helperText:
                      'Used to arrange items in custom display order (1, 2, 3...)',
                ),
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    final val = int.tryParse(v.trim());
                    if (val == null || val < 0) {
                      return 'Enter a valid positive integer';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category
              Text('Category', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: AppConstants.itemCategories.map((cat) {
                  return ChoiceChip(
                    label: Text(cat),
                    selected: _category == cat,
                    onSelected: (_) => setState(() => _category = cat),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Unit
              DropdownButtonFormField<String>(
                value: _unit,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  prefixIcon: Icon(Icons.scale_rounded),
                ),
                items: AppConstants.itemUnits
                    .map((u) => DropdownMenuItem(
                          value: u,
                          child: Text(
                            u,
                            style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _unit = v ?? _unit),
              ),
              const SizedBox(height: 16),

              if (_unit == AppConstants.unitKg ||
                  _unit == AppConstants.unitPiece) ...[
                TextFormField(
                  controller: _weightPerPieceCon,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weight per Piece (in kg)',
                    prefixIcon: Icon(Icons.fitness_center_rounded),
                    helperText:
                        'Used to switch between kg and piece during checkout',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Enter conversion weight';
                    }
                    final val = double.tryParse(v);
                    if (val == null || val <= 0) {
                      return 'Enter a valid positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costCon,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Cost Price',
                        prefixText: '$currency ',
                      ),
                      validator: (v) =>
                          AppValidators.positiveNumber(v, field: 'Cost price'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sellCon,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Selling Price *',
                        prefixText: '$currency ',
                      ),
                      validator: (v) => AppValidators.positiveNumber(v,
                          field: 'Selling price', isRequired: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Market Retail Price (for Customer Savings Calculation)
              TextFormField(
                controller: _marketCon,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Market Retail Price (MRP for Savings Calc)',
                  prefixText: '$currency ',
                  prefixIcon: const Icon(Icons.store_rounded),
                  helperText:
                      'Used to calculate customer savings against market rates',
                ),
                validator: (v) => AppValidators.positiveNumber(v,
                    field: 'Market price', allowZero: true),
              ),
              const SizedBox(height: 16),

              // Smart Pricing Suggestions
              AnimatedBuilder(
                animation: Listenable.merge([_costCon, _sellCon]),
                builder: (context, _) {
                  final cost = double.tryParse(_costCon.text.trim()) ?? 0.0;
                  final sell = double.tryParse(_sellCon.text.trim()) ?? 0.0;

                  if (cost <= 0 && sell <= 0) {
                    return const SizedBox.shrink();
                  }

                  final markupPrice = cost > 0 ? cost * 1.65 : 0.0;
                  final marginPrice = cost > 0 ? cost / 0.35 : 0.0;
                  final doubleMrpPrice = cost > 0 ? cost * 2.0 : sell * 2.0;

                  return GlassContainer(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            const Text(
                              'Smart Pricing Suggestions',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (cost > 0) ...[
                              ActionChip(
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.18),
                                side:
                                    const BorderSide(color: AppColors.primary),
                                avatar: const Icon(Icons.trending_up_rounded,
                                    size: 14, color: AppColors.primary),
                                label: Text(
                                  '⭐ 65% Markup ($currency${markupPrice.toStringAsFixed(2)})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary),
                                ),
                                onPressed: () {
                                  _sellCon.text =
                                      markupPrice.toStringAsFixed(2);
                                },
                              ),
                              ActionChip(
                                avatar:
                                    const Icon(Icons.percent_rounded, size: 14),
                                label: Text(
                                    '65% Margin ($currency${marginPrice.toStringAsFixed(2)})'),
                                onPressed: () {
                                  _sellCon.text =
                                      marginPrice.toStringAsFixed(2);
                                },
                              ),
                            ],
                            if (doubleMrpPrice > 0)
                              ActionChip(
                                avatar: const Icon(Icons.double_arrow_rounded,
                                    size: 14),
                                label: Text(
                                    'Double MRP ($currency${doubleMrpPrice.toStringAsFixed(2)})'),
                                onPressed: () {
                                  _marketCon.text =
                                      doubleMrpPrice.toStringAsFixed(2);
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockCon,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Current Stock',
                        prefixIcon: Icon(Icons.warehouse_rounded),
                      ),
                      validator: (v) => AppValidators.positiveNumber(v,
                          field: 'Current stock', allowZero: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minStockCon,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Min Stock (alert)',
                        prefixIcon: Icon(Icons.warning_amber_rounded),
                      ),
                      validator: (v) => AppValidators.positiveNumber(v,
                          field: 'Min stock', allowZero: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Barcode
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeCon,
                      decoration: const InputDecoration(
                        labelText: 'Barcode (optional)',
                        prefixIcon: Icon(Icons.qr_code_scanner_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.document_scanner_rounded),
                    tooltip: 'Scan Barcode',
                    onPressed: _scanBarcode,
                  ),
                ],
              ),

              _buildOrderNowFields(),
              _buildCategorySpecificFields(),
              const SizedBox(height: 32),


              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _save,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_isEdit ? 'Update Item' : 'Add Item'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Future<void> _scanBarcode() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _BarcodeScannerSheet(),
    );
    if (result != null) {
      setState(() => _barcodeCon.text = result);
    }
  }

  Future<void> _pickImage() async {
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

    if (source != null) {
      final img = await ImageUtils.pickAndCompress(source: source);
      if (img != null) {
        setState(() => _photoPath = img.path);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final now = DateTime.now();
      final itemId = widget.itemId ?? const Uuid().v4();

      String finalPhotoPath = _photoPath;
      if (_photoPath.isNotEmpty && !_photoPath.startsWith('http')) {
        final savedPath = await ImageUtils.saveImagePermanently(
          sourcePath: _photoPath,
          subFolder: 'item_photos',
          fileName: itemId,
        );
        if (savedPath != null) {
          finalPhotoPath = savedPath;
        }
      }

      final item = Item(
        id: itemId,
        name: _nameCon.text.trim(),
        category: _category,
        costPrice: double.tryParse(_costCon.text) ?? 0,
        sellingPrice: double.tryParse(_sellCon.text) ?? 0,
        marketPrice: double.tryParse(_marketCon.text) ?? 0,
        stock: double.tryParse(_stockCon.text) ?? 0,
        minStock: double.tryParse(_minStockCon.text) ?? 0,
        unit: _unit,
        barcode: _barcodeCon.text.trim(),
        photoPath: finalPhotoPath,
        createdAt: _isEdit ? _createdAt : now,
        updatedAt: now,
        expiryDate:
            _category == AppConstants.catMedicines ? _expiryCon.text : '',
        batchNumber:
            _category == AppConstants.catMedicines ? _batchCon.text.trim() : '',
        prescriptionRequired:
            _category == AppConstants.catMedicines ? _rxRequired : false,
        dosageInfo: _category == AppConstants.catMedicines
            ? _dosageCon.text.trim()
            : '',
        bestBefore:
            _category == AppConstants.catGroceries ? _bestBeforeCon.text : '',
        packDate: _category == AppConstants.catGroceries ? _packCon.text : '',
        weightPerPiece: double.tryParse(_weightPerPieceCon.text) ?? 0.25,
        sequenceNo: int.tryParse(_sequenceCon.text.trim()) ?? 0,
        orderNowStock: double.tryParse(_orderNowStockCon.text) ?? (double.tryParse(_stockCon.text) ?? 0),
        orderNowSellingPrice: double.tryParse(_orderNowSellCon.text) ?? (double.tryParse(_sellCon.text) ?? 0),
        orderNowMrp: double.tryParse(_orderNowMrpCon.text) ?? (double.tryParse(_marketCon.text) ?? 0),
        orderNowCostPrice: double.tryParse(_orderNowCostCon.text) ?? (double.tryParse(_costCon.text) ?? 0),
        orderNowIsAvailable: _orderNowIsAvailable,
      );


      if (_isEdit) {
        await ref.read(inventoryProvider.notifier).updateItem(item);
      } else {
        await ref.read(inventoryProvider.notifier).addItem(item);
      }

      if (!mounted) return;
      SnackbarHelper.showSuccess(
          context, _isEdit ? 'Item updated' : 'Item added');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildOrderNowFields() {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final currency = settings?.currency ?? AppConstants.defaultCurrency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFB74D), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flash_on_rounded, color: Color(0xFFE65100), size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Now (Quick Delivery)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                        Text(
                          'Priority 1-2 hour delivery inventory & pricing',
                          style: TextStyle(fontSize: 11, color: Color(0xFF795548)),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _orderNowIsAvailable,
                    activeColor: const Color(0xFFE65100),
                    onChanged: (val) => setState(() => _orderNowIsAvailable = val),
                  ),
                ],
              ),
              if (_orderNowIsAvailable) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _orderNowSellCon.text = _sellCon.text;
                        _orderNowMrpCon.text = _marketCon.text;
                        _orderNowCostCon.text = _costCon.text;
                        _orderNowStockCon.text = _stockCon.text;
                      });
                    },
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Copy from Normal Rates', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE65100),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _orderNowStockCon,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Quick Stock',
                          prefixIcon: Icon(Icons.flash_on_rounded, color: Color(0xFFE65100)),
                          helperText: 'Available for Order Now',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _orderNowSellCon,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Quick Price',
                          prefixText: '$currency ',
                          helperText: 'Selling rate for Order Now',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _orderNowMrpCon,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Quick MRP',
                          prefixText: '$currency ',
                          helperText: 'Market price for savings',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _orderNowCostCon,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Quick Cost Price',
                          prefixText: '$currency ',
                          helperText: 'Cost price for Order Now',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySpecificFields() {

    if (_category == AppConstants.catMedicines) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 32),
          Text(
            'Medicines Configuration',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _batchCon,
            decoration: const InputDecoration(
              labelText: 'Batch Number',
              prefixIcon: Icon(Icons.numbers_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _dosageCon,
            decoration: const InputDecoration(
              labelText: 'Dosage / Composition Info',
              prefixIcon: Icon(Icons.medical_services_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _expiryCon,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Expiry Date',
              prefixIcon: Icon(Icons.calendar_today_rounded),
            ),
            onTap: () async {
              DateTime initial = _expiryCon.text.isNotEmpty
                  ? (DateTime.tryParse(_expiryCon.text) ?? DateTime.now())
                  : DateTime.now();
              if (initial.isBefore(DateTime(2000))) initial = DateTime(2000);
              if (initial.isAfter(DateTime(2100))) initial = DateTime(2100);
              final date = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                setState(() =>
                    _expiryCon.text = date.toIso8601String().substring(0, 10));
              }
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Prescription Required (Rx)'),
            subtitle:
                const Text('Require prescription verification at checkout'),
            value: _rxRequired,
            onChanged: (val) => setState(() => _rxRequired = val),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      );
    } else if (_category == AppConstants.catGroceries) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 32),
          Text(
            'Groceries Configuration',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _packCon,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Pack Date',
              prefixIcon: Icon(Icons.date_range_rounded),
            ),
            onTap: () async {
              DateTime initial = _packCon.text.isNotEmpty
                  ? (DateTime.tryParse(_packCon.text) ?? DateTime.now())
                  : DateTime.now();
              if (initial.isBefore(DateTime(2000))) initial = DateTime(2000);
              if (initial.isAfter(DateTime(2100))) initial = DateTime(2100);
              final date = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                setState(() =>
                    _packCon.text = date.toIso8601String().substring(0, 10));
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bestBeforeCon,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Best Before Date',
              prefixIcon: Icon(Icons.timer_rounded),
            ),
            onTap: () async {
              DateTime initial = _bestBeforeCon.text.isNotEmpty
                  ? (DateTime.tryParse(_bestBeforeCon.text) ??
                      DateTime.now().add(const Duration(days: 30)))
                  : DateTime.now().add(const Duration(days: 30));
              if (initial.isBefore(DateTime(2000))) initial = DateTime(2000);
              if (initial.isAfter(DateTime(2100))) initial = DateTime(2100);
              final date = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                setState(() => _bestBeforeCon.text =
                    date.toIso8601String().substring(0, 10));
              }
            },
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _BarcodeScannerSheet extends StatefulWidget {
  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  final _controller = MobileScannerController();
  bool _found = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Scan Barcode',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                if (_found) return;
                final barcode = capture.barcodes.firstOrNull;
                if (barcode?.rawValue != null) {
                  _found = true;
                  Navigator.of(context).pop(barcode!.rawValue);
                }
              },
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
