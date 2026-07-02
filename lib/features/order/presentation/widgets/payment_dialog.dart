/// PaymentDialog — Add payment to an existing order

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';

class PaymentDialog extends StatefulWidget {
  final double remainingAmount;
  final double grandTotal;
  final String currency;
  final void Function(double amount, String method, String notes) onPay;

  const PaymentDialog({
    super.key,
    required this.remainingAmount,
    required this.grandTotal,
    required this.currency,
    required this.onPay,
  });

  static Future<void> show(
    BuildContext context, {
    required double remainingAmount,
    required double grandTotal,
    required String currency,
    required void Function(double amount, String method, String notes) onPay,
  }) {
    return showDialog(
      context: context,
      builder: (_) => PaymentDialog(
        remainingAmount: remainingAmount,
        grandTotal:      grandTotal,
        currency:        currency,
        onPay:           onPay,
      ),
    );
  }

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
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
