import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/security/app_mode_service.dart';
import '../domain/item.dart';
import 'inventory_provider.dart';

class AddEditItemScreen extends ConsumerStatefulWidget {
  final String? itemId;
  const AddEditItemScreen({super.key, this.itemId});

  @override
  ConsumerState<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends ConsumerState<AddEditItemScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCon      = TextEditingController();
  final _costCon      = TextEditingController();
  final _sellCon      = TextEditingController();
  final _marketCon    = TextEditingController();
  final _stockCon     = TextEditingController();
  final _minStockCon  = TextEditingController();
  final _barcodeCon   = TextEditingController();

  String _category = AppConstants.catVegetables;
  String _unit     = AppConstants.unitKg;
  bool   _loading  = false;
  bool   _isEdit   = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mode = ref.read(appModeProvider).value;
      if (mode == AppMode.worker) {
        SnackbarHelper.showError(context, 'Access Denied: Workers cannot manage items.');
        Navigator.pop(context);
      }
    });
    if (widget.itemId != null) {
      _isEdit = true;
      _loadItem();
    }
  }

  Future<void> _loadItem() async {
    final item = await ref.read(inventoryRepositoryProvider).getItemById(widget.itemId!);
    if (item != null && mounted) {
      setState(() {
        _nameCon.text     = item.name;
        _costCon.text     = item.costPrice.toString();
        _sellCon.text     = item.sellingPrice.toString();
        _marketCon.text   = item.marketPrice.toString();
        _stockCon.text    = item.stock.toString();
        _minStockCon.text = item.minStock.toString();
        _barcodeCon.text  = item.barcode;
        _category         = item.category;
        _unit             = item.unit;
      });
    }
  }

  @override
  void dispose() {
    _nameCon.dispose(); _costCon.dispose(); _sellCon.dispose(); _marketCon.dispose();
    _stockCon.dispose(); _minStockCon.dispose(); _barcodeCon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit Item' : 'Add Item',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCon,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  prefixIcon: Icon(Icons.inventory_2_rounded),
                ),
                validator: (v) => AppValidators.nameField(v, field: 'Item name'),
                textCapitalization: TextCapitalization.words,
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
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _unit = v ?? _unit),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costCon,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cost Price',
                        prefixText: '₹ ',
                      ),
                      validator: (v) => AppValidators.positiveNumber(v, field: 'Cost price'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sellCon,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Selling Price *',
                        prefixText: '₹ ',
                      ),
                      validator: (v) => AppValidators.positiveNumber(v, field: 'Selling price'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Market Retail Price (for Customer Savings Calculation)
              TextFormField(
                controller: _marketCon,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Market Retail Price (MRP for Savings Calc)',
                  prefixText: '₹ ',
                  prefixIcon: Icon(Icons.store_rounded),
                  helperText: 'Used to calculate customer savings against market rates',
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockCon,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Current Stock',
                        prefixIcon: Icon(Icons.warehouse_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minStockCon,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Min Stock (alert)',
                        prefixIcon: Icon(Icons.warning_amber_rounded),
                      ),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final now  = DateTime.now();
      final item = Item(
        id:           widget.itemId ?? const Uuid().v4(),
        name:         _nameCon.text.trim(),
        category:     _category,
        costPrice:    double.tryParse(_costCon.text) ?? 0,
        sellingPrice: double.tryParse(_sellCon.text) ?? 0,
        marketPrice:  double.tryParse(_marketCon.text) ?? 0,
        stock:        double.tryParse(_stockCon.text) ?? 0,
        minStock:     double.tryParse(_minStockCon.text) ?? 0,
        unit:         _unit,
        barcode:      _barcodeCon.text.trim(),
        createdAt:    now,
        updatedAt:    now,
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
