import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/customer_avatar.dart';
import 'package:orderkart/features/customer/presentation/customer_provider.dart';
import 'package:orderkart/features/settings/presentation/settings_provider.dart';
import '../../../../core/widgets/qr_full_screen_preview.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  final String customerId;
  final double remainingAmount;
  final double grandTotal;
  final String currency;
  final void Function(double amount, String method, String notes) onPay;

  const PaymentDialog({
    super.key,
    required this.customerId,
    required this.remainingAmount,
    required this.grandTotal,
    required this.currency,
    required this.onPay,
  });

  static Future<void> show(
    BuildContext context, {
    required String customerId,
    required double remainingAmount,
    required double grandTotal,
    required String currency,
    required void Function(double amount, String method, String notes) onPay,
  }) {
    return showDialog(
      context: context,
      builder: (_) => PaymentDialog(
        customerId:      customerId,
        remainingAmount: remainingAmount,
        grandTotal:      grandTotal,
        currency:        currency,
        onPay:           onPay,
      ),
    );
  }

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  final _amountCon = TextEditingController();
  final _notesCon  = TextEditingController();
  String _method   = AppConstants.paymentCash;
  double _amount   = 0;

  @override
  void initState() {
    super.initState();
    _amount = widget.remainingAmount;
    _amountCon.text = widget.remainingAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCon.dispose();
    _notesCon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ref.watch(customerDetailProvider(widget.customerId)).when(
                  data: (customer) => customer == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              CustomerAvatar(
                                photoPath: customer.photoPath,
                                radius: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  customer.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
            // Info row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Remaining:'),
                  Text(
                    AppFormatters.currency(widget.remainingAmount,
                        symbol: widget.currency),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountCon,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Payment Amount',
                prefixText: '${widget.currency} ',
                prefixIcon: const Icon(Icons.payments_rounded),
              ),
              onChanged: (v) =>
                  setState(() => _amount = double.tryParse(v) ?? 0),
            ),

            const SizedBox(height: 12),

            // Quick buttons
            Row(
              children: [
                _quickBtn('Full',      widget.remainingAmount),
                const SizedBox(width: 6),
                _quickBtn('Half',      widget.remainingAmount / 2),
              ],
            ),

            const SizedBox(height: 12),

            // Method
            Text('Payment Method',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                _methodChip('Cash',   AppConstants.paymentCash),
                _methodChip('Online', AppConstants.paymentOnline),
                _methodChip('UPI',    AppConstants.paymentUPI),
                _methodChip('Card',   AppConstants.paymentCard),
              ],
            ),

            if (_method == AppConstants.paymentOnline || _method == AppConstants.paymentUPI) ...[
              const SizedBox(height: 16),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Scan & Pay QR Code',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    ref.watch(settingsProvider).when(
                          loading: () => const CircularProgressIndicator(),
                          error: (_, __) => const Text('Failed to load QR code'),
                          data: (settings) {
                            if (settings.qrCustomImage.isNotEmpty) {
                              return GestureDetector(
                                onTap: () => QrFullScreenPreview.show(
                                  context,
                                  qrCustomImage: settings.qrCustomImage,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(settings.qrCustomImage),
                                    width: 160,
                                    height: 160,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Text('Broken Custom QR Image'),
                                  ),
                                ),
                              );
                            } else if (settings.qrContent.isNotEmpty) {
                              return GestureDetector(
                                onTap: () => QrFullScreenPreview.show(
                                  context,
                                  qrContent: settings.qrContent,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.gray200),
                                  ),
                                  child: QrImageView(
                                    data: settings.qrContent,
                                    version: QrVersions.auto,
                                    size: 160.0,
                                  ),
                                ),
                              );
                            } else {
                              return const Text('No QR Code configured in Settings',
                                  style: TextStyle(fontSize: 12, color: AppColors.textHint));
                            }
                          },
                        ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Notes
            TextFormField(
              controller: _notesCon,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _amount > 0
              ? () {
                  Navigator.of(context).pop();
                  widget.onPay(_amount, _method, _notesCon.text.trim());
                }
              : null,
          child: const Text('Record'),
        ),
      ],
    );
  }

  Widget _quickBtn(String label, double amount) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() => _amount = amount);
          _amountCon.text = amount.toStringAsFixed(2);
        },
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(8)),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _methodChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _method == value,
      onSelected: (_) => setState(() => _method = value),
    );
  }
}
