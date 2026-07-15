import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../domain/expense.dart';
import 'expense_provider.dart';
import '../../settings/presentation/settings_provider.dart';

class AddEditExpenseScreen extends ConsumerStatefulWidget {
  final String? expenseId;
  const AddEditExpenseScreen({super.key, this.expenseId});

  @override
  ConsumerState<AddEditExpenseScreen> createState() =>
      _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState
    extends ConsumerState<AddEditExpenseScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCon     = TextEditingController();
  final _amountCon   = TextEditingController();
  final _notesCon    = TextEditingController();

  String   _category      = AppConstants.expTransport;
  String   _paymentMethod = AppConstants.paymentCash;
  DateTime _date          = DateTime.now();
  String   _receiptPath   = '';
  bool     _loading       = false;
  bool     _isEdit        = false;

  @override
  void initState() {
    super.initState();
    if (widget.expenseId != null) {
      _isEdit = true;
      _loadExpense();
    }
  }

  Future<void> _loadExpense() async {
    final e = await ref.read(expenseRepositoryProvider).getExpenseById(widget.expenseId!);
    if (e != null && mounted) {
      setState(() {
        _nameCon.text   = e.name;
        _amountCon.text = e.amount.toString();
        _notesCon.text  = e.notes;
        _category       = e.category;
        _paymentMethod  = e.paymentMethod;
        _date           = e.date;
        _receiptPath    = e.receiptPhotoPath;
      });
    }
  }

  @override
  void dispose() {
    _nameCon.dispose(); _amountCon.dispose(); _notesCon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsVal = ref.watch(settingsProvider).valueOrNull;
    final currency = settingsVal?.currency ?? '₹';

    return AppScaffold(
      title: _isEdit ? 'Edit Expense' : 'Add Expense',
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
                  labelText: 'Expense Name *',
                  prefixIcon: Icon(Icons.receipt_long_rounded),
                ),
                validator: (v) => AppValidators.nameField(v, field: 'Expense name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountCon,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount *',
                  prefixText: '$currency ',
                  prefixIcon: const Icon(Icons.monetization_on_rounded),
                ),
                validator: (v) => AppValidators.positiveNumber(v, field: 'Amount'),
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: AppConstants.expenseCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 16),

              // Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded),
                title: Text(
                  'Date: ${_date.day}/${_date.month}/${_date.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),

              const SizedBox(height: 16),

              // Payment method
              Text('Payment Method',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Cash'),
                    selected: _paymentMethod == 'cash',
                    onSelected: (_) =>
                        setState(() => _paymentMethod = 'cash'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Online'),
                    selected: _paymentMethod == 'online',
                    onSelected: (_) =>
                        setState(() => _paymentMethod = 'online'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesCon,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Receipt Photo
              Text('Receipt Capture', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              if (_receiptPath.isNotEmpty) ...[
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: InteractiveViewer(
                              child: Image.file(File(_receiptPath)),
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_receiptPath),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _receiptPath = ''),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.delete_rounded),
                      label: const Text('Remove'),
                    ),
                  ],
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: _pickReceiptImage,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Capture Receipt Photo'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                  ),
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
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(_isEdit ? 'Update Expense' : 'Add Expense'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickReceiptImage() async {
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
        setState(() => _receiptPath = img.path);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final expenseId = widget.expenseId ?? const Uuid().v4();

      String finalReceiptPath = _receiptPath;
      if (_receiptPath.isNotEmpty && !_receiptPath.startsWith('http')) {
        final saved = await ImageUtils.saveImagePermanently(
          sourcePath: _receiptPath,
          subFolder: 'expense_receipts',
          fileName: 'receipt_$expenseId',
        );
        if (saved != null) {
          finalReceiptPath = saved;
        }
      }

      final expense = Expense(
        id:            expenseId,
        name:          _nameCon.text.trim(),
        category:      _category,
        amount:        double.tryParse(_amountCon.text) ?? 0,
        date:          _date,
        notes:         _notesCon.text.trim(),
        paymentMethod: _paymentMethod,
        createdAt:     now,
        updatedAt:     now,
        receiptPhotoPath: finalReceiptPath,
      );
      if (_isEdit) {
        await ref.read(expenseProvider.notifier).update(expense);
      } else {
        await ref.read(expenseProvider.notifier).add(expense);
      }
      if (!mounted) return;
      SnackbarHelper.showSuccess(context, _isEdit ? 'Expense updated' : 'Expense added');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
