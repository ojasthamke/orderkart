import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/customer_avatar.dart';
import 'package:orderkart/features/customer/presentation/customer_provider.dart';
import 'package:orderkart/features/settings/presentation/settings_provider.dart';
import 'package:orderkart/features/settings/domain/app_settings.dart';
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
  ConsumerState<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends ConsumerState<PaymentDetailsScreen> {
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

  void _onRecord() {
    if (_amount <= 0) return;
    Navigator.of(context).pop({
      'amount': _amount,
      'method': _method,
      'notes': _notesCon.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
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
                                        style: TextStyle(
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
            
            const SizedBox(height: 24),
            
            // Info row
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.errorSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Remaining Due:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  Text(
                    AppFormatters.currency(widget.remainingAmount,
                        symbol: widget.currency),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Amount
            TextFormField(
              controller: _amountCon,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Payment Amount',
                prefixText: '${widget.currency} ',
                prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                prefixIcon: const Icon(Icons.payments_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onChanged: (v) => setState(() => _amount = double.tryParse(v) ?? 0),
            ),

            const SizedBox(height: 16),

            // Quick buttons
            Row(
              children: [
                _quickBtn('Full Amount', widget.remainingAmount),
                const SizedBox(width: 12),
                _quickBtn('Half Amount', widget.remainingAmount / 2),
              ],
            ),

            const SizedBox(height: 32),

            // Method
            Text(
              'Payment Method',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _methodChip('Cash',   AppConstants.paymentCash),
                _methodChip('Online', AppConstants.paymentOnline),
                _methodChip('UPI',    AppConstants.paymentUPI),
                _methodChip('Card',   AppConstants.paymentCard),
              ],
            ),

            if (_method == AppConstants.paymentOnline || _method == AppConstants.paymentUPI) ...[
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Scan & Pay QR Code',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                      ),
                      const SizedBox(height: 16),
                      ref.watch(settingsProvider).when(
                            loading: () => const CircularProgressIndicator(),
                            error: (_, __) => const Text('Failed to load QR code'),
                            data: (settings) {
                              if (settings.qrCustomImage.isNotEmpty) {
                                return GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.qrPreview,
                                    arguments: {'qrCustomImage': settings.qrCustomImage},
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(settings.qrCustomImage),
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Text('Broken Custom QR Image'),
                                    ),
                                  ),
                                );
                              } else if (settings.qrContent.isNotEmpty) {
                                return GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.qrPreview,
                                    arguments: {'qrContent': settings.qrContent},
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.gray200),
                                      boxShadow: AppColors.cardShadow,
                                    ),
                                    child: QrImageView(
                                      data: settings.qrContent,
                                      version: QrVersions.auto,
                                      size: 200.0,
                                    ),
                                  ),
                                );
                              } else {
                                return const Text(
                                  'No QR Code configured in Settings',
                                  style: TextStyle(fontSize: 14, color: AppColors.textHint),
                                );
                              }
                            },
                          ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Notes
            TextFormField(
              controller: _notesCon,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.notes_rounded),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            
            const SizedBox(height: 48), // Bottom padding
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: FilledButton(
          onPressed: _amount > 0 ? _onRecord : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Record Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _quickBtn(String label, double amount) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() => _amount = amount);
          _amountCon.text = amount.toStringAsFixed(2);
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _methodChip(String label, String value) {
    final isSelected = _method == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _method = value),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
