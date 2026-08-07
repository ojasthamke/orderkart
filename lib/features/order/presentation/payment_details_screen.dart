import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/customer_avatar.dart';
import 'package:orderkart/features/customer/presentation/customer_provider.dart';
import 'package:orderkart/features/settings/presentation/settings_provider.dart';
import '../../../../core/constants/app_routes.dart';

class PaymentDetailsScreen extends ConsumerStatefulWidget {
  final String customerId;
  final double remainingAmount;
  final double grandTotal;
  final String currency;

  const PaymentDetailsScreen({
    super.key,
    required this.customerId,
    required this.remainingAmount,
    required this.grandTotal,
    this.currency = '₹',
  });

  @override
  ConsumerState<PaymentDetailsScreen> createState() =>
      _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends ConsumerState<PaymentDetailsScreen> {
  final _amountCon = TextEditingController();
  final _notesCon = TextEditingController();
  String _method = AppConstants.paymentCash;
  double _amount = 0;

  // Split Payment Mode
  bool _isSplitPayment = false;
  final _splitCashCon = TextEditingController();
  final _splitUpiCon = TextEditingController();
  final _splitOnlineCon = TextEditingController();
  final _splitCardCon = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amount = 0;
    _amountCon.text = '';
  }

  @override
  void dispose() {
    _amountCon.dispose();
    _notesCon.dispose();
    _splitCashCon.dispose();
    _splitUpiCon.dispose();
    _splitOnlineCon.dispose();
    _splitCardCon.dispose();
    super.dispose();
  }

  double get _splitTotal {
    final c = double.tryParse(_splitCashCon.text) ?? 0.0;
    final u = double.tryParse(_splitUpiCon.text) ?? 0.0;
    final o = double.tryParse(_splitOnlineCon.text) ?? 0.0;
    final cd = double.tryParse(_splitCardCon.text) ?? 0.0;
    return c + u + o + cd;
  }

  void _onRecord() {
    if (_isSplitPayment) {
      final total = _splitTotal;
      if (total <= 0) return;
      AppHaptics.primarySave();

      final List<Map<String, dynamic>> splits = [];
      final c = double.tryParse(_splitCashCon.text) ?? 0.0;
      final u = double.tryParse(_splitUpiCon.text) ?? 0.0;
      final o = double.tryParse(_splitOnlineCon.text) ?? 0.0;
      final cd = double.tryParse(_splitCardCon.text) ?? 0.0;

      if (c > 0) splits.add({'method': AppConstants.paymentCash, 'amount': c});
      if (u > 0) splits.add({'method': AppConstants.paymentUPI, 'amount': u});
      if (o > 0) splits.add({'method': AppConstants.paymentOnline, 'amount': o});
      if (cd > 0) splits.add({'method': AppConstants.paymentCard, 'amount': cd});

      Navigator.of(context).pop({
        'isSplit': true,
        'splits': splits,
        'amount': total,
        'method': 'split',
        'notes': _notesCon.text.trim().isNotEmpty
            ? _notesCon.text.trim()
            : 'Split payment (${splits.map((s) => '${s['method']}: ${s['amount']}').join(', ')})',
      });
      return;
    }

    if (_amount <= 0) return;
    AppHaptics.primarySave();
    Navigator.of(context).pop({
      'isSplit': false,
      'amount': _amount,
      'method': _method,
      'notes': _notesCon.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsVal = ref.watch(settingsProvider).valueOrNull;
    final currency = settingsVal?.currency ?? widget.currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      title: 'Record Payment',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ref.watch(customerDetailProvider(widget.customerId)).when(
                  data: (customer) => customer == null
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.gray200),
                          ),
                          child: Row(
                            children: [
                              CustomerAvatar(
                                photoPath: customer.photoPath,
                                radius: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (customer.phone1.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        customer.phone1,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 14),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

            const SizedBox(height: 16),

            // Info row
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: widget.remainingAmount > 0
                    ? AppColors.warningSurface
                    : Colors.teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.remainingAmount > 0
                      ? AppColors.warning.withOpacity(0.3)
                      : Colors.teal.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.remainingAmount >= 0
                        ? 'Remaining Due:'
                        : 'Credit / Advance Balance:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: widget.remainingAmount > 0
                          ? AppColors.warning
                          : Colors.teal,
                    ),
                  ),
                  Text(
                    AppFormatters.currency(widget.remainingAmount.abs(),
                        symbol: currency),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      color: widget.remainingAmount > 0
                          ? AppColors.warning
                          : Colors.teal,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Mode Selector: Single Payment vs Split Payment
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isSplitPayment = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isSplitPayment
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Single Payment',
                            style: TextStyle(
                              color: !_isSplitPayment
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : AppColors.textPrimary),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isSplitPayment = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isSplitPayment
                              ? const Color(0xFF0F766E)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.call_split_rounded,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'Split Payment',
                                style: TextStyle(
                                  color: _isSplitPayment
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : AppColors.textPrimary),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (!_isSplitPayment) ...[
              // Single Payment Amount
              TextFormField(
                controller: _amountCon,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Payment Amount',
                  prefixText: '$currency ',
                  prefixStyle:
                      const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  prefixIcon: const Icon(Icons.payments_rounded),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onChanged: (v) =>
                    setState(() => _amount = double.tryParse(v) ?? 0),
              ),

              const SizedBox(height: 16),

              // Quick buttons
              if (widget.remainingAmount > 0) ...[
                Row(
                  children: [
                    _quickBtn('Full Amount', widget.remainingAmount),
                    const SizedBox(width: 12),
                    _quickBtn('Half Amount', widget.remainingAmount / 2),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Method
              Text(
                'Payment Method',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _methodChip('Cash', AppConstants.paymentCash),
                  _methodChip('Online', AppConstants.paymentOnline),
                  _methodChip('UPI', AppConstants.paymentUPI),
                  _methodChip('Card', AppConstants.paymentCard),
                ],
              ),
            ] else ...[
              // ── Split Payment Mode Form ────────────────────────────────
              Text(
                'Enter allocated amounts for each method:',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _splitRow('💵 Cash', _splitCashCon, currency, Colors.green),
              const SizedBox(height: 10),
              _splitRow('📱 UPI / QR', _splitUpiCon, currency, Colors.purple),
              const SizedBox(height: 10),
              _splitRow('🌐 Online / Net', _splitOnlineCon, currency, Colors.blue),
              const SizedBox(height: 10),
              _splitRow('💳 Card POS', _splitCardCon, currency, Colors.blueGrey),
              const SizedBox(height: 16),

              // Split summary bar
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderColor(context)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Split Allocated:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '$currency${_splitTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _splitTotal == widget.remainingAmount
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (!_isSplitPayment &&
                (_method == AppConstants.paymentOnline ||
                    _method == AppConstants.paymentUPI)) ...[
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Scan & Pay QR Code',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primary),
                      ),
                      const SizedBox(height: 16),
                      ref.watch(settingsProvider).when(
                            loading: () => const CircularProgressIndicator(),
                            error: (_, __) =>
                                const Text('Error loading QR code'),
                            data: (settings) {
                              if (settings.qrCustomImage.isNotEmpty) {
                                return GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.qrPreview,
                                    arguments: {
                                      'qrCustomImage': settings.qrCustomImage
                                    },
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: settings.qrCustomImage.startsWith('http')
                                        ? Image.network(
                                            settings.qrCustomImage,
                                            width: 180,
                                            height: 180,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const Text('Broken Custom QR Image'),
                                          )
                                        : Image.file(
                                            File(settings.qrCustomImage),
                                            width: 180,
                                            height: 180,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const Text('Broken Custom QR Image'),
                                          ),
                                  ),
                                );
                              }
                              if (settings.qrContent.isNotEmpty) {
                                return GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.qrPreview,
                                    arguments: {
                                      'qrContent': settings.qrContent
                                    },
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.gray200),
                                    ),
                                    child: QrImageView(
                                      data: settings.qrContent,
                                      version: QrVersions.auto,
                                      size: 180.0,
                                    ),
                                  ),
                                );
                              }
                              return const Text(
                                'No UPI QR code configured.\nConfigure in Settings.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary),
                              );
                            },
                          ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Notes
            TextFormField(
              controller: _notesCon,
              decoration: InputDecoration(
                labelText: 'Payment Note / Reference (Optional)',
                hintText: 'e.g. UPI Ref #12345, Part payment',
                prefixIcon: const Icon(Icons.note_rounded),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),

            const SizedBox(height: 32),

            // Submit button
            ElevatedButton(
              onPressed: _onRecord,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _isSplitPayment
                    ? 'Record Split Payment ($currency${_splitTotal.toStringAsFixed(2)})'
                    : 'Record Payment ($currency${_amount.toStringAsFixed(2)})',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _splitRow(String label, TextEditingController controller,
      String currency, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withOpacity(0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: accentColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '$currency ',
              hintText: '0.00',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Auto-fill remainder',
          icon: const Icon(Icons.flash_on_rounded, size: 20),
          onPressed: () {
            final otherAllocated = _splitTotal -
                (double.tryParse(controller.text) ?? 0.0);
            final remainingDue =
                (widget.remainingAmount - otherAllocated).clamp(0.0, double.infinity);
            setState(() {
              controller.text = remainingDue.toStringAsFixed(2);
            });
          },
        ),
      ],
    );
  }

  Widget _quickBtn(String label, double val) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _amount = val;
            _amountCon.text = val.toStringAsFixed(2);
          });
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _methodChip(String label, String value) {
    final isSelected = _method == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _method = value);
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
