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

  // New V6 fields
  final _expiryCon     = TextEditingController();
  final _batchCon      = TextEditingController();
  final _dosageCon     = TextEditingController();
  final _bestBeforeCon = TextEditingController();
  final _packCon       = TextEditingController();
  final _weightPerPieceCon = TextEditingController(text: '0.25');
  bool  _rxRequired    = false;

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
        _expiryCon.text   = item.expiryDate;
        _batchCon.text    = item.batchNumber;
        _dosageCon.text   = item.dosageInfo;
        _bestBeforeCon.text = item.bestBefore;
        _packCon.text     = item.packDate;
        _rxRequired       = item.prescriptionRequired;
        _weightPerPieceCon.text = item.weightPerPiece.toString();
      });
    }
  }

  @override
  void dispose() {
    _nameCon.dispose(); _costCon.dispose(); _sellCon.dispose(); _marketCon.dispose();
    _stockCon.dispose(); _minStockCon.dispose(); _barcodeCon.dispose();
    _expiryCon.dispose(); _batchCon.dispose(); _dosageCon.dispose();
    _bestBeforeCon.dispose(); _packCon.dispose();
    _weightPerPieceCon.dispose();
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

              if (_unit == AppConstants.unitKg || _unit == AppConstants.unitPiece) ...[
                TextFormField(
                  controller: _weightPerPieceCon,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weight per Piece (in kg)',
                    prefixIcon: Icon(Icons.fitness_center_rounded),
                    helperText: 'Used to switch between kg and piece during checkout',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter conversion weight';
                    final val = double.tryParse(v);
                    if (val == null || val <= 0) return 'Enter a valid positive number';
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

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
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
                                avatar: const Icon(Icons.trending_up_rounded, size: 14),
                                label: Text('65% Markup (₹${markupPrice.toStringAsFixed(2)})'),
                                onPressed: () {
                                  _sellCon.text = markupPrice.toStringAsFixed(2);
                                },
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.percent_rounded, size: 14),
                                label: Text('65% Margin (₹${marginPrice.toStringAsFixed(2)})'),
                                onPressed: () {
                                  _sellCon.text = marginPrice.toStringAsFixed(2);
                                },
                              ),
                            ],
                            if (doubleMrpPrice > 0)
                              ActionChip(
                                avatar: const Icon(Icons.double_arrow_rounded, size: 14),
                                label: Text('Double MRP (₹${doubleMrpPrice.toStringAsFixed(2)})'),
                                onPressed: () {
                                  _marketCon.text = doubleMrpPrice.toStringAsFixed(2);
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
        expiryDate:   _category == AppConstants.catMedicines ? _expiryCon.text : '',
        batchNumber:  _category == AppConstants.catMedicines ? _batchCon.text.trim() : '',
        prescriptionRequired: _category == AppConstants.catMedicines ? _rxRequired : false,
        dosageInfo:   _category == AppConstants.catMedicines ? _dosageCon.text.trim() : '',
        bestBefore:   _category == AppConstants.catGroceries ? _bestBeforeCon.text : '',
        packDate:     _category == AppConstants.catGroceries ? _packCon.text : '',
        weightPerPiece: double.tryParse(_weightPerPieceCon.text) ?? 0.25,
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
              final date = await showDatePicker(
                context: context,
                initialDate: _expiryCon.text.isNotEmpty
                    ? DateTime.parse(_expiryCon.text)
                    : DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                setState(() => _expiryCon.text = date.toIso8601String().substring(0, 10));
              }
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Prescription Required (Rx)'),
            subtitle: const Text('Require prescription verification at checkout'),
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
              final date = await showDatePicker(
                context: context,
                initialDate: _packCon.text.isNotEmpty
                    ? DateTime.parse(_packCon.text)
                    : DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                setState(() => _packCon.text = date.toIso8601String().substring(0, 10));
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
              final date = await showDatePicker(
                context: context,
                initialDate: _bestBeforeCon.text.isNotEmpty
                    ? DateTime.parse(_bestBeforeCon.text)
                    : DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                setState(() => _bestBeforeCon.text = date.toIso8601String().substring(0, 10));
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
