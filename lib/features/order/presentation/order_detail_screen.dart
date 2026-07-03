import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/bill_text_generator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/customer_avatar.dart';
import '../../customer/presentation/customer_provider.dart';
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

                if (order.notes.isNotEmpty) ...[
                  _buildNotesSection(order),
                  const SizedBox(height: 16),
                ],

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
        color: Theme.of(context).cardTheme.color,
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
                'Order ${order.orderNoLabel}',
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
    final customerAsync = ref.watch(customerDetailProvider(order.customerId));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          customerAsync.when(
            data: (customer) => CustomerAvatar(
              photoPath: customer?.photoPath,
              radius: 24,
            ),
            loading: () => const CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primarySurface,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => const CustomerAvatar(photoPath: '', radius: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
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
                customerAsync.when(
                  data: (cust) {
                    if (cust == null) return const SizedBox.shrink();
                    final houseStr = [
                      if (cust.serialNo > 0) '#${cust.serialNo}',
                      if (cust.houseNumber.isNotEmpty) cust.houseNumber,
                    ].join(' · ');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (houseStr.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            houseStr,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                        if (cust.address.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            cust.address,
                            style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
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
        color: Theme.of(context).cardTheme.color,
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
        color: Theme.of(context).cardTheme.color,
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

  Widget _buildNotesSection(AppOrder order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORDER NOTES',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.gray500),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF141414)
                  : AppColors.gray50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gray200),
            ),
            child: SelectableText(
              order.notes,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
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
        color: Theme.of(context).cardTheme.color,
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
                onPressed: () => _shareBill(order, currency, isCustomer: true),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Customer WA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _shareBill(order, currency, isCustomer: false),
          icon: const Icon(Icons.send_rounded),
          label: const Text('Share to Staff Telegram'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF229ED9), // Telegram Blue
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Future<void> _addPayment(AppOrder order) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.paymentDetails,
      arguments: {
        'customerId': order.customerId,
        'remainingAmount': order.remainingAmount,
        'grandTotal': order.grandTotal,
        'currency': '₹',
      },
    );

    if (result != null && result is Map<String, dynamic>) {
      final amount = result['amount'] as double;
      final method = result['method'] as String;
      final notes = result['notes'] as String;

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
    }
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
                child: pw.Text('OrderKart Receipt',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 16)),
              ),
              pw.Divider(),
              pw.Text('Order: ${order.orderNoLabel}'),
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

  Future<void> _shareBill(AppOrder order, String currency, {required bool isCustomer}) async {
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
      ownerPhone:      settings?.phone ?? '',
      currency:        currency,
    );

    String encodedText = Uri.encodeComponent(text);
    Uri? url;

    if (isCustomer) {
      String phone = order.customerPhone ?? '';
      String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length == 10) cleanPhone = '91$cleanPhone'; // Default to +91 if 10 digits
      
      if (cleanPhone.isNotEmpty) {
        url = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedText');
      } else {
        url = Uri.parse('whatsapp://send?text=$encodedText');
      }
    } else {
      // ── Telegram Sharing ───────────────────────────────────────────
      final staffLink = settings?.staffWhatsApp ?? '';
      
      // Copy to clipboard as first priority to guarantee it's on the keypad pasteboard
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        SnackbarHelper.showInfo(context, 'Receipt copied to clipboard');
      }

      Uri telegramUri;
      if (staffLink.trim().isNotEmpty) {
        var cleanLink = staffLink.trim();
        if (cleanLink.startsWith('@')) {
          cleanLink = cleanLink.substring(1);
        }
        if (cleanLink.contains('t.me/')) {
          cleanLink = cleanLink.substring(cleanLink.indexOf('t.me/') + 5);
        }
        telegramUri = Uri.parse('tg://resolve?domain=$cleanLink');
      } else {
        telegramUri = Uri.parse('tg://msg_url?url=&text=$encodedText');
      }

      try {
        if (await canLaunchUrl(telegramUri)) {
          await launchUrl(telegramUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}

      // Fallback Telegram link
      final fallbackUrl = staffLink.trim().isNotEmpty
          ? Uri.parse(staffLink.trim().startsWith('http')
              ? staffLink.trim()
              : 'https://t.me/${staffLink.trim().replaceAll('@', '')}')
          : Uri.parse('https://t.me/share/url?url=&text=$encodedText');

      try {
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      } catch (e) {
        // Last resort: OS share sheet
        Share.share(text);
      }
      return;
    }

    try {
      // Try native whatsapp:// scheme first
      if (url != null && await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
      // Fallback to wa.me web link (opens WhatsApp or web.whatsapp.com)
      final fallbackUrl = isCustomer && order.customerPhone != null && order.customerPhone!.isNotEmpty
          ? Uri.parse('https://wa.me/${order.customerPhone!.replaceAll(RegExp(r'\D'), '')}?text=$encodedText')
          : Uri.parse('https://wa.me/?text=$encodedText');
      await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Last resort: OS share sheet
      Share.share(text, subject: 'Invoice for Order ${order.orderNoLabel}');
    }
  }
}
