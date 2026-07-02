import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/bill_text_generator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../settings/presentation/settings_provider.dart';
import '../domain/order.dart';
import '../domain/payment.dart';
import 'order_provider.dart';
import 'widgets/payment_dialog.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));
    final settings   = ref.watch(settingsProvider).value;
    final currency   = settings?.currency ?? AppConstants.defaultCurrency;

    return orderAsync.when(
      loading: () => const AppScaffold(
        title: 'Order Details',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Order Details',
        body: Center(child: Text('Error loading order: $e')),
      ),
      data: (order) {
        if (order == null) {
          return const AppScaffold(
            title: 'Order Details',
            body: Center(child: Text('Order not found')),
          );
        }

        return AppScaffold(
          title: 'Order Details',
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  Navigator.of(context).pushNamed(
                    AppRoutes.createOrder,
                    arguments: {
                      'customerId':   order.customerId,
                      'customerName': order.customerName ?? '',
                      'orderId':      order.id,
                    },
                  ).then((_) => ref.refresh(orderDetailProvider(widget.orderId)));
                } else if (v == 'delete') {
                  _deleteOrder(order);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit Items')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Order', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status & Header Card
                _buildHeaderCard(order, currency),
                const SizedBox(height: 16),

                // Customer info
                _buildCustomerCard(order),
                const SizedBox(height: 16),

                // Items list
                _buildItemsSection(order, currency),
                const SizedBox(height: 16),

                // Summary calculations
                _buildSummarySection(order, currency),
                const SizedBox(height: 16),

                // Payments list
                _buildPaymentsSection(order, currency),
                const SizedBox(height: 24),

                // Receipt actions
                _buildActionsSection(order, currency),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(AppOrder order, String currency) {
    Color statusColor = AppColors.pending;
    if (order.deliveryStatus == AppConstants.statusDelivered) statusColor = AppColors.success;
    if (order.deliveryStatus == AppConstants.statusCancelled) statusColor = AppColors.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #${order.id.substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                AppFormatters.dateTime(order.createdAt),
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              AppFormatters.deliveryStatus(order.deliveryStatus),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(AppOrder order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CUSTOMER',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.gray500),
          ),
          const SizedBox(height: 8),
          Text(
            order.customerName ?? 'Unknown Customer',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          if (order.customerPhone != null) ...[
            const SizedBox(height: 4),
            Text(
              order.customerPhone!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
          if (order.customerAddress != null && order.customerAddress!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              order.customerAddress!,
              style: const TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsSection(AppOrder order, String currency) {
    final items = order.items ?? [];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ITEMS',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.gray500),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('No items in this order')
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final it = items[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.itemName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Text(
                              '${AppFormatters.quantity(it.quantity, unit: it.itemUnit)} × $currency${it.unitPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$currency${it.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(AppOrder order, String currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          _sumRow('Subtotal',         '$currency${order.subtotal.toStringAsFixed(2)}'),
          if (order.discount > 0)
            _sumRow('Discount',       '- $currency${order.discount.toStringAsFixed(2)}',
                color: AppColors.success),
          if (order.smartRoundedAmount != 0)
            _sumRow('Smart Rounded',  '$currency${order.smartRoundedAmount.toStringAsFixed(2)}',
                color: AppColors.warning),
          if (order.deliveryCharge > 0)
            _sumRow('Delivery Charge', '+ $currency${order.deliveryCharge.toStringAsFixed(2)}'),
          const Divider(height: 20),
          _sumRow('Grand Total',      '$currency${order.grandTotal.toStringAsFixed(2)}',
              isBold: true, color: AppColors.primary),
          _sumRow('Paid Amount',      '$currency${order.paidAmount.toStringAsFixed(2)}',
              color: AppColors.success),
          if (order.remainingAmount > 0)
            _sumRow('Due Amount',     '$currency${order.remainingAmount.toStringAsFixed(2)}',
                color: AppColors.error, isBold: true),
        ],
      ),
    );
  }

  Widget _sumRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                  color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildPaymentsSection(AppOrder order, String currency) {
    final payments = order.payments ?? [];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PAYMENTS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray500),
              ),
              if (order.remainingAmount > 0 && order.deliveryStatus != AppConstants.statusCancelled)
                TextButton.icon(
                  onPressed: () => _addPayment(order),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Payment', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (payments.isEmpty)
            const Text('No payments recorded yet')
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length,
              itemBuilder: (ctx, i) {
                final p = payments[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.success),
                  title: Text(
                    '$currency${p.amount.toStringAsFixed(2)} (${AppFormatters.paymentMethod(p.method)})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Text(
                    AppFormatters.dateTime(p.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(AppOrder order, String currency) {
    return Column(
      children: [
        if (order.deliveryStatus == AppConstants.statusPending) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(order.id, AppConstants.statusDelivered),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Mark Delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _updateStatus(order.id, AppConstants.statusCancelled),
                  icon: const Icon(Icons.cancel_rounded),
                  label: const Text('Cancel Order'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _printPdf(order, currency),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Print / PDF'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _shareBill(order, currency),
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _addPayment(AppOrder order) {
    PaymentDialog.show(
      context,
      remainingAmount: order.remainingAmount,
      grandTotal:      order.grandTotal,
      currency:        '₹',
      onPay: (amount, method, notes) async {
        await ref.read(orderManagementProvider.notifier).addPayment(Payment(
              id:         const Uuid().v4(),
              orderId:    order.id,
              customerId: order.customerId,
              amount:     amount,
              method:     method,
              notes:      notes,
              createdAt:  DateTime.now(),
            ));
        ref.refresh(orderDetailProvider(widget.orderId));
        if (mounted) SnackbarHelper.showSuccess(context, 'Payment of ₹$amount added');
      },
    );
  }

  Future<void> _updateStatus(String orderId, String status) async {
    await ref.read(orderManagementProvider.notifier).updateDeliveryStatus(orderId, status);
    ref.refresh(orderDetailProvider(widget.orderId));
    if (mounted) SnackbarHelper.showSuccess(context, 'Order updated to ${status.toUpperCase()}');
  }

  Future<void> _deleteOrder(AppOrder order) async {
    final ok = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete Order',
      message: 'Delete this order permanently?',
    );
    if (!ok) return;
    await ref.read(orderManagementProvider.notifier).deleteOrder(order.id);
    if (mounted) {
      SnackbarHelper.showSuccess(context, 'Order deleted');
      Navigator.of(context).pop();
    }
  }

  Future<void> _printPdf(AppOrder order, String currency) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('FreshFlow Receipt',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 16)),
              ),
              pw.Divider(),
              pw.Text('Order: #${order.id.substring(0, 8).toUpperCase()}'),
              pw.Text('Date: ${AppFormatters.dateTime(order.createdAt)}'),
              pw.Text('Customer: ${order.customerName}'),
              pw.Divider(),
              pw.Text('Items:'),
              ...?order.items?.map((it) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                          '${it.itemName} (${AppFormatters.quantity(it.quantity)} ${it.itemUnit})'),
                      pw.Text('$currency${it.totalPrice.toStringAsFixed(2)}'),
                    ],
                  )),
              pw.Divider(),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total:'),
                    pw.Text('$currency${order.grandTotal.toStringAsFixed(2)}'),
                  ]),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Paid:'),
                    pw.Text('$currency${order.paidAmount.toStringAsFixed(2)}'),
                  ]),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Due:'),
                    pw.Text(
                        '$currency${order.remainingAmount.toStringAsFixed(2)}'),
                  ]),
              pw.Divider(),
              pw.Center(child: pw.Text('Thank you for your business!')),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save());
  }

  void _shareBill(AppOrder order, String currency) {
    final settings = ref.read(settingsProvider).value;
    final list = order.items
            ?.map((it) => {
                  'item_name':   it.itemName,
                  'quantity':    it.quantity,
                  'item_unit':   it.itemUnit,
                  'unit_price':  it.unitPrice,
                  'total_price': it.totalPrice,
                })
            .toList() ??
        [];

    final text = BillTextGenerator.generate(
      businessName:    settings?.businessName ?? 'My Business',
      customerName:    order.customerName ?? '',
      customerAddress: order.customerAddress ?? '',
      orderId:         order.id,
      orderDate:       order.createdAt,
      items:           list,
      subtotal:        order.subtotal,
      discount:        order.discount,
      deliveryCharge:  order.deliveryCharge,
      grandTotal:      order.grandTotal,
      paidAmount:      order.paidAmount,
      remainingAmount: order.remainingAmount,
      paymentMethod:   order.payments?.firstOrNull?.method ?? 'cash',
      currency:        currency,
    );

    Share.share(text, subject: 'Invoice for Order #${order.id.substring(0, 8).toUpperCase()}');
  }
}
