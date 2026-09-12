import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import '../../../core/services/customer_order_sync_service.dart';
import '../../../core/utils/external_launcher.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/bill_text_generator.dart';
import '../../../core/utils/graphic_bill_generator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/customer_avatar.dart';
import '../../../core/widgets/status_dot_badge.dart';
import '../../customer/presentation/customer_provider.dart';
import '../../customer/domain/customer.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../../inventory/domain/item.dart';
import '../../settings/presentation/settings_provider.dart';
import '../data/order_questions_dao.dart';
import '../data/order_dao.dart';
import '../domain/order.dart';
import '../domain/order_item.dart';
import '../domain/payment.dart';
import 'order_provider.dart';
import '../../location/presentation/location_provider.dart';
import '../../customer/data/customer_dao.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/smart_rounding.dart';
import '../../../core/utils/catalog_classifier.dart';
import 'widgets/smart_round_banner.dart';
import 'widgets/delivery_time_bottom_sheet.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _isDeleting = false;
  bool _isUpdatingRates = false;

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));
    final settings = ref.watch(settingsProvider).value;
    final currency = settings?.currency ?? AppConstants.defaultCurrency;

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
        if (_isDeleting) {
          return const AppScaffold(
            title: 'Order Details',
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (order == null) {
          return const AppScaffold(
            title: 'Order Details',
            body: Center(child: Text('Order not found')),
          );
        }

        return AppScaffold(
          title: 'Order Details',
          onBack: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed(
                AppRoutes.customerProfile,
                arguments: {'customerId': order.customerId},
              );
            }
          },
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  Navigator.of(context).pushNamed(
                    AppRoutes.createOrder,
                    arguments: {
                      'customerId': order.customerId,
                      'customerName': (order.customerName != null &&
                              order.customerName!.trim().isNotEmpty)
                          ? order.customerName!.trim()
                          : '',
                      'orderId': order.id,
                    },
                  ).then(
                      (_) => ref.refresh(orderDetailProvider(widget.orderId)));
                } else if (v == 'update_rates') {
                  if (!_isUpdatingRates) {
                    _updateRates(order);
                  }
                } else if (v == 'whatsapp_review') {
                  _showWhatsAppReviewDialog(order);
                } else if (v == 'customer_profile') {
                  Navigator.of(context).pushNamed(
                    AppRoutes.customerProfile,
                    arguments: {'customerId': order.customerId},
                  );
                } else if (v == 'new_order') {
                  Navigator.of(context).pushNamed(
                    AppRoutes.createOrder,
                    arguments: {
                      'customerId': order.customerId,
                      'customerName': (order.customerName != null &&
                              order.customerName!.trim().isNotEmpty)
                          ? order.customerName!.trim()
                          : '',
                    },
                  ).then((_) => ref.refresh(orderDetailProvider(widget.orderId)));
                } else if (v == 'delete') {
                  _deleteOrder(order);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit Items')),
                const PopupMenuItem(
                  value: 'update_rates',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Update Rates to Current Prices'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'whatsapp_review',
                  child: Row(
                    children: [
                      Icon(Icons.rate_review_rounded,
                          size: 18, color: Color(0xFF25D366)),
                      SizedBox(width: 8),
                      Text('WhatsApp Review Request'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'customer_profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded,
                          size: 18, color: Colors.blueGrey),
                      SizedBox(width: 8),
                      Text('Customer Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'new_order',
                  child: Row(
                    children: [
                      Icon(Icons.add_shopping_cart_rounded,
                          size: 18, color: Colors.teal),
                      SizedBox(width: 8),
                      Text('Create New Order'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child:
                      Text('Delete Order', style: TextStyle(color: Colors.red)),
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

                // Delivery Time / Store Acceptance Card
                _buildDeliveryTimeCard(order),
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

                // Order Questions & Answers Section
                ref.watch(orderAnswersProvider(order.id)).when(
                      data: (answers) => answers.isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildQuestionsSection(answers),
                                const SizedBox(height: 16),
                              ],
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

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
    String deliveryDateFormatted = '';
    if (order.deliveryDate != null && order.deliveryDate!.trim().isNotEmpty) {
      deliveryDateFormatted = AppFormatters.dateFromString(order.deliveryDate!);
    } else {
      deliveryDateFormatted = AppFormatters.date(order.createdAt);
    }

    final String orderDateFormatted = AppFormatters.dateTime(order.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Order ${order.orderNoLabel}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (order.estimatedDeliveryTime != null &&
                        order.estimatedDeliveryTime!.trim().isNotEmpty &&
                        order.estimatedDeliveryTime!.trim().toLowerCase() != 'null') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF4CAF50), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_filled_rounded,
                                size: 12, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 2),
                            Text(
                              order.estimatedDeliveryTime!,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (order.orderType == 'Pre-Order') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Pre-Order',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (order.orderType == 'Pre-Order' &&
                    order.orderTakingDate != null &&
                    order.orderTakingDate!.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 13, color: Colors.purple),
                      const SizedBox(width: 5),
                      Text(
                        'Order-Taking Date: ${AppFormatters.dateFromString(order.orderTakingDate!)}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.purple,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 13, color: AppColors.textHint),
                      const SizedBox(width: 5),
                      Text(
                        'Placed: $orderDateFormatted',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 13, color: AppColors.textHint),
                      const SizedBox(width: 5),
                      Text(
                        'Order Date: $orderDateFormatted',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Delivery Date: $deliveryDateFormatted',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusDotBadge(status: order.deliveryStatus),
        ],
      ),
    );
  }

  Widget _buildDeliveryTimeCard(AppOrder order) {
    final normStatus = order.deliveryStatus.toLowerCase().trim();
    final isPending = normStatus == AppConstants.statusPending || normStatus == 'placed';
    final isCancelled = normStatus == AppConstants.statusCancelled;
    final isDelivered = normStatus == AppConstants.statusDelivered;

    if (isCancelled || isDelivered) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isPending) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2E2412) : const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFFB300),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.hourglass_top_rounded,
                    color: Color(0xFFE65100), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Awaiting Store Acceptance',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Accept this order and set an estimated delivery duration for the customer.',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF795548),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openAcceptOrderBottomSheet(order),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text(
                  'Accept Order & Set Delivery Time',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Order is confirmed / preparing / out for delivery
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.timer_outlined,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ESTIMATED DELIVERY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (order.estimatedDeliveryTime != null &&
                          order.estimatedDeliveryTime!.trim().isNotEmpty &&
                          order.estimatedDeliveryTime!.trim().toLowerCase() != 'null')
                      ? order.estimatedDeliveryTime!
                      : 'Not specified',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (order.estimatedDeliveryAt != null &&
                    order.estimatedDeliveryAt!.trim().isNotEmpty &&
                    order.estimatedDeliveryAt!.trim().toLowerCase() != 'null') ...[
                  const SizedBox(height: 1),
                  Text(
                    'Expected by ${AppFormatters.time(DateTime.tryParse(order.estimatedDeliveryAt!)?.toLocal() ?? DateTime.now())}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _openChangeDeliveryTimeBottomSheet(order),
            icon: const Icon(Icons.access_time_rounded, size: 16),
            label: const Text('Change', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAcceptOrderBottomSheet(AppOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeliveryTimeBottomSheet(
        order: order,
        isAccepting: true,
        onConfirm: (durationStr, targetTime) async {
          await ref.read(orderManagementProvider.notifier).acceptOrder(
                order.id,
                deliveryTimeStr: durationStr,
                estimatedDeliveryAt: targetTime,
              );
          ref.invalidate(orderDetailProvider(widget.orderId));
          if (mounted) {
            SnackbarHelper.showSuccess(
              context,
              'Order accepted! Delivery set to $durationStr',
            );
          }
        },
      ),
    );
  }

  void _openChangeDeliveryTimeBottomSheet(AppOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeliveryTimeBottomSheet(
        order: order,
        isAccepting: false,
        onConfirm: (durationStr, targetTime) async {
          await ref
              .read(orderManagementProvider.notifier)
              .updateEstimatedDeliveryTime(
                order.id,
                deliveryTimeStr: durationStr,
                estimatedDeliveryAt: targetTime,
              );
          ref.invalidate(orderDetailProvider(widget.orderId));
          if (mounted) {
            SnackbarHelper.showSuccess(
              context,
              'Delivery time updated to $durationStr',
            );
          }
        },
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
        border: Border.all(color: AppColors.borderColor(context)),
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
                const Text(
                  'CUSTOMER',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gray500),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        (order.customerName != null &&
                                order.customerName!.trim().isNotEmpty)
                            ? order.customerName!.trim()
                            : 'Unknown Customer',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    customerAsync.maybeWhen(
                      data: (c) {
                        if (c == null) return const SizedBox.shrink();
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (c.isBrandNewCustomer) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: const Color(0xFF81C784), width: 0.8),
                                ),
                                child: const Text(
                                  '🌱 NEW',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (c.isGoogleCustomer)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F0FE),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: const Color(0xFF4285F4), width: 0.8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.g_mobiledata_rounded,
                                        size: 15, color: Color(0xFF1967D2)),
                                    Text(
                                      'GOOGLE ACCOUNT',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF1967D2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                if (order.customerPhone != null && order.customerPhone!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        order.customerPhone!,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => ExternalLauncher.launchCall(context, order.customerPhone!),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(Icons.phone_outlined, size: 16, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => ExternalLauncher.launchWhatsApp(context, order.customerPhone!),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(Icons.chat_outlined, size: 16, color: Color(0xFF047857)),
                        ),
                      ),
                    ],
                  ),
                ],
                customerAsync.when(
                  data: (cust) {
                    final double? effectiveLat = (order.latitude != null && order.latitude != 0.0)
                        ? order.latitude
                        : (cust?.latitude != null && cust!.latitude != 0.0 ? cust.latitude : null);
                    final double? effectiveLng = (order.longitude != null && order.longitude != 0.0)
                        ? order.longitude
                        : (cust?.longitude != null && cust!.longitude != 0.0 ? cust.longitude : null);

                    final displayAddress = (cust?.address != null && cust!.address.isNotEmpty)
                        ? cust.address
                        : (order.customerAddress ?? '');

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cust?.phone2 != null && cust!.phone2.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.history_rounded, size: 14, color: Color(0xFFB45309)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Last Phone: ${cust.phone2}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => ExternalLauncher.launchCall(context, cust.phone2),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Icon(Icons.phone_outlined, size: 16, color: Color(0xFFB45309)),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => ExternalLauncher.launchWhatsApp(context, cust.phone2),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Icon(Icons.chat_outlined, size: 16, color: Color(0xFF047857)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (cust != null)
                          ref.watch(locationPathNameProvider(cust.streetId)).when(
                            data: (fullPath) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (cust.serialNo > 0 ||
                                      cust.houseNumber.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        if (cust.serialNo > 0)
                                          'Serial: #${cust.serialNo}',
                                        if (cust.houseNumber.isNotEmpty)
                                          'House: ${cust.houseNumber}',
                                      ].join('  •  '),
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                  if (displayAddress.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Address: $displayAddress',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13),
                                      softWrap: true,
                                    ),
                                  ],
                                  if (fullPath.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Location: $fullPath',
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ],
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          )
                        else if (displayAddress.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Address: $displayAddress',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                            softWrap: true,
                          ),
                        ],
                        if (effectiveLat != null && effectiveLng != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFF86EFAC), width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.pin_drop_rounded,
                                    size: 16, color: Color(0xFF15803D)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'GPS: ${effectiveLat.toStringAsFixed(5)}, ${effectiveLng.toStringAsFixed(5)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await ExternalLauncher.launchNavigationCoordinates(
                                    context, effectiveLat, effectiveLng);
                              },
                              icon: const Icon(Icons.navigation_rounded,
                                  size: 18, color: Colors.white),
                              label: const Text(
                                'Navigate (Google Maps)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ] else if (displayAddress.isNotEmpty && (cust?.isGoogleCustomer ?? false)) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await ExternalLauncher.openMap(
                                    context, displayAddress);
                              },
                              icon: const Icon(Icons.navigation_rounded,
                                  size: 18, color: Colors.white),
                              label: const Text(
                                'Navigate Address (Google Maps)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                            ),
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

  Widget _buildOrderItemSubSection({
    required AppOrder order,
    required String title,
    required IconData icon,
    required Color accentColor,
    required Color lightBg,
    required List<OrderItem> items,
    required double subtotal,
    required String currency,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? accentColor.withValues(alpha: 0.18) : lightBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: accentColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black38 : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '${items.length} ${items.length == 1 ? "item" : "items"}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$currency${subtotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...items.asMap().entries.map((entry) {
          final idx = entry.key;
          final it = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${idx + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        it.itemName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppFormatters.quantity(it.quantity, unit: it.itemUnit),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '@ $currency${it.unitPrice > 0 && it.unitPrice < 1.0 ? it.unitPrice.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '') : it.unitPrice.toStringAsFixed(2)} / ${it.itemUnit}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$currency${it.totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.block_rounded,
                    size: 18,
                    color: Colors.orange.shade700,
                  ),
                  tooltip: 'Mark Unavailable',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: () => _toggleItemAvailability(order, it),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildItemsSection(AppOrder order, String currency) {
    final items = order.items;
    final availableItems = items.where((it) => it.isAvailable).toList();
    final unavailableItems = items.where((it) => !it.isAvailable).toList();

    final inventoryItems = ref.watch(inventoryProvider).valueOrNull ?? [];
    final Map<String, Item> itemByIdMap = {for (final item in inventoryItems) item.id: item};
    final Map<String, Item> itemByNameMap = {
      for (final item in inventoryItems) item.name.toLowerCase().trim(): item
    };

    final produceItems = <OrderItem>[];
    final groceryItems = <OrderItem>[];
    double produceSubtotal = 0.0;
    double grocerySubtotal = 0.0;

    for (final it in availableItems) {
      Item? matchedItem = itemByIdMap[it.itemId];
      if (matchedItem == null && it.itemId.contains('_var_')) {
        final baseId = it.itemId.split('_var_').first;
        matchedItem = itemByIdMap[baseId];
      }
      matchedItem ??= itemByNameMap[it.itemName.toLowerCase().trim()];
      final isGrocery = CatalogClassifier.isGroceryOrderItem(it, matchedItem);
      if (isGrocery) {
        groceryItems.add(it);
        grocerySubtotal += it.totalPrice;
      } else {
        produceItems.add(it);
        produceSubtotal += it.totalPrice;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ITEMS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray500),
              ),
              InkWell(
                onTap: _isUpdatingRates ? null : () => _updateRates(order),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isUpdatingRates)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        )
                      else
                        const Icon(Icons.refresh_rounded,
                            size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        _isUpdatingRates ? 'Updating...' : 'Update Rates',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (availableItems.isEmpty && unavailableItems.isEmpty)
            const Text('No items in this order')
          else ...[
            if (produceItems.isNotEmpty)
              _buildOrderItemSubSection(
                order: order,
                title: 'Fresh Produce & Vegetables',
                icon: Icons.eco_rounded,
                accentColor: const Color(0xFF047857),
                lightBg: const Color(0xFFECFDF5),
                items: produceItems,
                subtotal: produceSubtotal,
                currency: currency,
              ),
            if (produceItems.isNotEmpty && groceryItems.isNotEmpty)
              const SizedBox(height: 12),
            if (groceryItems.isNotEmpty)
              _buildOrderItemSubSection(
                order: order,
                title: 'Groceries & Packaged Goods',
                icon: Icons.shopping_bag_outlined,
                accentColor: const Color(0xFF1D4ED8),
                lightBg: const Color(0xFFEFF6FF),
                items: groceryItems,
                subtotal: grocerySubtotal,
                currency: currency,
              ),
            if (unavailableItems.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: Divider(),
              ),
              Row(
                children: [
                  Icon(Icons.remove_shopping_cart_rounded,
                      color: Colors.orange.shade800, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'OUT OF STOCK / UNAVAILABLE ITEMS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: Colors.orange.shade800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...unavailableItems.map((it) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF451A03).withValues(alpha: 0.3)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF7C2D12)
                          : const Color(0xFFFED7AA),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.itemName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                decoration: TextDecoration.lineThrough,
                                color: Color(0xFF9A3412),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${AppFormatters.quantity(it.quantity, unit: it.itemUnit)} @ $currency${it.unitPrice > 0 && it.unitPrice < 1.0 ? it.unitPrice.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '') : it.unitPrice.toStringAsFixed(2)} / ${it.itemUnit}',
                              style: const TextStyle(
                                color: Color(0xFFC2410C),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${currency}0.00',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: Color(0xFFC2410C),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.check_circle_outline_rounded,
                            size: 18, color: Colors.green.shade700),
                        tooltip: 'Mark Available',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: () => _toggleItemAvailability(order, it),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSummarySection(AppOrder order, String currency) {
    final totalCombinedSavings = order.savings;
    final totalSavings = order.discount;
    final itemsList = ref.watch(inventoryProvider).valueOrNull ?? [];
    double marketSavings = 0.0;
    for (final oi in order.items) {
      final inv = itemsList.where((i) => i.id == oi.itemId).firstOrNull;
      if (inv != null && inv.marketPrice > 0) {
        final qtyInInvUnit = UnitConverter.convert(
          quantity: oi.quantity,
          fromUnit: oi.itemUnit,
          toUnit: inv.unit,
        );
        final totalMarketCost = inv.marketPrice * qtyInInvUnit;
        final totalOrderCost = oi.totalPrice > 0 ? oi.totalPrice : (oi.unitPrice * oi.quantity);
        if (totalMarketCost > totalOrderCost) {
          marketSavings += (totalMarketCost - totalOrderCost);
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          _sumRow('Subtotal', '$currency${order.subtotal.toStringAsFixed(2)}'),
          if (order.discount > 0)
            _sumRow(
                'Discount', '- $currency${order.discount.toStringAsFixed(2)}',
                color: AppColors.success),
          if (order.smartRoundedAmount != 0)
            _sumRow('Smart Rounded',
                '$currency${order.smartRoundedAmount.toStringAsFixed(2)}',
                color: AppColors.warning),
          if (order.deliveryCharge > 0)
            _sumRow('Delivery Charge',
                '+ $currency${order.deliveryCharge.toStringAsFixed(2)}'),
          const Divider(height: 20),
          _sumRow(
              'Grand Total', '$currency${order.grandTotal.toStringAsFixed(2)}',
              isBold: true, color: AppColors.primary),
          _sumRow(
              'Paid Amount', '$currency${order.paidAmount.toStringAsFixed(2)}',
              color: AppColors.success),
          if (order.remainingAmount > 0)
            _sumRow('Due Amount',
                '$currency${order.remainingAmount.toStringAsFixed(2)}',
                color: AppColors.warning, isBold: true),

          const SizedBox(height: 12),
          SmartRoundBanner(
            original: order.grandTotal - order.smartRoundedAmount,
            rounded: SmartRounding.round(
                order.grandTotal - order.smartRoundedAmount),
            enabled: order.smartRoundedAmount != 0,
            currency: currency,
            onToggle: (enable) => _toggleOrderRoundOff(order, enable, currency),
          ),

          // ── Daily Savings Banner — always shown on every receipt ──
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: totalCombinedSavings > 0
                  ? const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF10B981)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: totalCombinedSavings > 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text('🎉', style: TextStyle(fontSize: 22)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'CONGRATULATIONS!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (totalSavings > 0 && marketSavings > 0) ...[
                        Text(
                          '💰 Order Discount: $currency${totalSavings.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '🏷️ vs. Market Price: $currency${marketSavings.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total Savings: $currency${totalCombinedSavings.toStringAsFixed(2)} 🥳✨',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ] else if (marketSavings > 0) ...[
                        Text(
                          'You saved $currency${marketSavings.toStringAsFixed(2)} vs. market price by shopping with us! 🥳✨',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                      ] else ...[
                        Text(
                          'You saved $currency${totalSavings.toStringAsFixed(2)} on this order by shopping with us! 🥳✨',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                      ],
                    ],
                  )
                : const Row(
                    children: [
                      Text('💚', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Thank you for shopping with us! Come back soon. 🙏',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
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
        border: Border.all(color: AppColors.borderColor(context)),
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
              border: Border.all(color: AppColors.borderColor(context)),
            ),
            child: SelectableText(
              order.notes,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
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
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                  color: color ?? AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsSection(AppOrder order, String currency) {
    final payments = order.payments;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PAYMENTS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray500),
              ),
              if (order.remainingAmount > 0 &&
                  order.deliveryStatus != AppConstants.statusCancelled)
                TextButton.icon(
                  onPressed: () => _addPayment(order),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label:
                      const Text('Add Payment', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
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
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Text(
                    AppFormatters.dateTime(p.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(AppOrder order, String currency) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cancelColor = isDark ? const Color(0xFFF87171) : AppColors.error;
    Widget? statusButtons;

    final normStatus = order.deliveryStatus.toLowerCase().trim();

    if (normStatus == AppConstants.statusPending || normStatus == 'confirmed' || normStatus == 'approved') {
      statusButtons = Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(order.id, 'preparing'),
                  icon: const Icon(Icons.soup_kitchen_rounded),
                  label: const Text('Mark Preparing'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(order.id, 'out for delivery'),
                  icon: const Icon(Icons.delivery_dining_rounded),
                  label: const Text('Out for Delivery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _updateStatus(order.id, AppConstants.statusDelivered),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Mark Delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _updateStatus(order.id, AppConstants.statusCancelled),
                  icon: Icon(Icons.cancel_rounded, color: cancelColor),
                  label: const Text('Cancel Order'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cancelColor,
                    side: BorderSide(color: cancelColor),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (normStatus == 'preparing') {
      statusButtons = Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus(order.id, 'out for delivery'),
              icon: const Icon(Icons.delivery_dining_rounded),
              label: const Text('Out for Delivery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  _updateStatus(order.id, AppConstants.statusDelivered),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Mark Delivered'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => _updateStatus(order.id, AppConstants.statusCancelled),
            icon: Icon(Icons.cancel_rounded, color: cancelColor),
            tooltip: 'Cancel Order',
          ),
        ],
      );
    } else if (normStatus == 'out for delivery') {
      statusButtons = Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  _updateStatus(order.id, AppConstants.statusDelivered),
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
              onPressed: () =>
                  _updateStatus(order.id, AppConstants.statusCancelled),
              icon: Icon(Icons.cancel_rounded, color: cancelColor),
              label: const Text('Cancel Order'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cancelColor,
                side: BorderSide(color: cancelColor),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      );
    } else if (normStatus == AppConstants.statusDelivered) {
      statusButtons = Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  _updateStatus(order.id, AppConstants.statusPending),
              icon: const Icon(Icons.history_rounded),
              label: const Text('Mark Undelivered'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () =>
                  _updateStatus(order.id, AppConstants.statusCancelled),
              icon: Icon(Icons.cancel_rounded, color: cancelColor),
              label: const Text('Cancel Order'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cancelColor,
                side: BorderSide(color: cancelColor),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      );
    } else if (normStatus == AppConstants.statusCancelled || normStatus == 'denied') {
      statusButtons = Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  _updateStatus(order.id, AppConstants.statusPending),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reactivate (Undelivered)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      );
    }


    return Column(
      children: [
        if (statusButtons != null) ...[
          statusButtons,
          const SizedBox(height: 16),
        ],
        ElevatedButton.icon(
          onPressed: () async {
            try {
              final cust = await ref
                  .read(customerDetailProvider(order.customerId).future);
              final settings = ref.read(settingsProvider).valueOrNull;
              final itemsList = order.items
                  .map((i) => {
                        'item_name': i.itemName,
                        'quantity': i.quantity,
                        'unit': i.itemUnit,
                        'unit_price': i.unitPrice,
                        'total_price': i.totalPrice,
                      })
                  .toList();
              if (context.mounted) {
                await GraphicBillGenerator.generateAndShareGraphicBill(
                  context: context,
                  order: order,
                  customer: cust,
                  settings: settings,
                  orderItems: itemsList,
                );
              }
            } catch (e) {
              if (context.mounted) {
                SnackbarHelper.showError(
                    context, 'Failed to share graphic invoice: $e');
              }
            }
          },
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('Share Graphic Invoice (PDF/WhatsApp)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _shareBill(order, currency, isCustomer: true),
          icon: const Icon(Icons.chat_rounded),
          label: const Text('Customer WA Text Bill'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _printThermalReceipt(order, currency),
          icon: const Icon(Icons.print_rounded),
          label: const Text('Print Thermal Receipt (58mm / 80mm)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF334155), // Slate Dark
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Future<void> _addPayment(AppOrder order) async {
    final settings = ref.read(settingsProvider).valueOrNull;
    final currency = settings?.currency ?? '₹';
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.paymentDetails,
      arguments: {
        'customerId': order.customerId,
        'remainingAmount': order.remainingAmount,
        'grandTotal': order.grandTotal,
        'currency': currency,
      },
    );

    if (result != null && result is Map<String, dynamic>) {
      final isSplit = result['isSplit'] == true;
      final totalAmount = (result['amount'] as num?)?.toDouble() ?? 0.0;
      final notes = (result['notes'] as String?) ?? '';

      try {
        if (isSplit && result['splits'] is List) {
          final splits = result['splits'] as List;
          for (final s in splits) {
            final sAmount = (s['amount'] as num?)?.toDouble() ?? 0.0;
            final sMethod = s['method']?.toString() ?? 'cash';
            if (sAmount > 0) {
              await ref.read(orderManagementProvider.notifier).addPayment(Payment(
                    id: const Uuid().v4(),
                    orderId: order.id,
                    customerId: order.customerId,
                    amount: sAmount,
                    method: sMethod,
                    notes: notes.isNotEmpty ? notes : 'Split: $sMethod',
                    createdAt: DateTime.now(),
                  ));
            }
          }
        } else {
          final method = result['method'] as String;
          await ref.read(orderManagementProvider.notifier).addPayment(Payment(
                id: const Uuid().v4(),
                orderId: order.id,
                customerId: order.customerId,
                amount: totalAmount,
                method: method,
                notes: notes,
                createdAt: DateTime.now(),
              ));
        }
        ref.invalidate(orderDetailProvider(widget.orderId));
        if (mounted) {
          SnackbarHelper.showSuccess(
              context, 'Payment of $currency$totalAmount added');
        }
      } catch (e) {
        if (mounted) {
          SnackbarHelper.showError(context, 'Failed to add payment: $e');
        }
      }
    }
  }

  Future<void> _updateStatus(String orderId, String status) async {
    final norm = status.toLowerCase().trim();
    if (norm == AppConstants.statusCancelled || norm == 'denied') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancel Order?'),
          content: const Text(
              'Are you sure you want to cancel this order? This will restore the order items back into inventory stock.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, Keep Order'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Cancel Order', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await ref
          .read(orderManagementProvider.notifier)
          .updateDeliveryStatus(orderId, status);
      ref.invalidate(orderDetailProvider(widget.orderId));
      if (mounted) {
        SnackbarHelper.showSuccess(
            context, 'Order updated to ${status.toUpperCase()}');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to update status: $e');
      }
    }
  }

  void _showWhatsAppReviewDialog(AppOrder order) {
    final settingsVal = ref.read(settingsProvider).valueOrNull;
    final bName = (settingsVal?.businessName.trim().isNotEmpty ?? false)
        ? settingsVal!.businessName.trim()
        : 'OrderKart Store';
    final customerName = (order.customerName != null &&
            order.customerName!.trim().isNotEmpty)
        ? order.customerName!.trim()
        : 'Valued Customer';
    final phone = order.customerPhone ?? '';

    final defaultMessage =
        'Namaste $customerName! 🙏\n\n'
        'Thank you for your recent order (#${order.orderNoLabel}) from $bName! '
        'We hope you are happy with the products and service.\n\n'
        '⭐ We would love to hear your feedback! Please rate your experience:\n'
        '1️⃣ Product Quality\n'
        '2️⃣ Delivery Speed\n'
        '3️⃣ Overall Service\n\n'
        'Your feedback helps us serve you better! 🌿\n'
        'Thank you, Team $bName';

    final controller = TextEditingController(text: defaultMessage);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.rate_review_rounded, color: Color(0xFF25D366)),
            SizedBox(width: 8),
            Expanded(child: Text('WhatsApp Review Request', style: TextStyle(fontSize: 16))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To: $customerName${phone.isNotEmpty ? " ($phone)" : ""}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              const Text('Edit message before sending:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 10,
                minLines: 6,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  hintText: 'Type your review request message...',
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ExternalLauncher.launchWhatsApp(
                context,
                phone,
                text: controller.text,
              );
            },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send via WhatsApp'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOrder(AppOrder order) async {
    final ok = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete Order',
      message: 'Delete this order permanently?',
    );
    if (!ok) return;
    try {
      setState(() {
        _isDeleting = true;
      });
      await ref.read(orderManagementProvider.notifier).deleteOrder(order.id);
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Order deleted');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        SnackbarHelper.showError(context, 'Failed to delete order: $e');
      }
    }
  }

  Future<void> _toggleOrderRoundOff(
      AppOrder order, bool enable, String currency) async {
    final double unrounded = order.grandTotal - order.smartRoundedAmount;
    final double rounded = SmartRounding.round(unrounded);
    final double newSmartRounded = enable ? (rounded - unrounded) : 0.0;
    final double newGrandTotal = enable ? rounded : unrounded;
    final double newRemaining = newGrandTotal - order.paidAmount;

    final db = await DatabaseHelper.instance.database;
    await db.update(
      'orders',
      {
        'smart_rounded_amount': newSmartRounded,
        'grand_total': newGrandTotal,
        'remaining_amount': newRemaining,
        'sync_status': 'pending_update',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [order.id],
    );

    try {
      await CustomerDao().recalcCustomerTotals(order.customerId, executor: db);
    } catch (_) {}

    try {
      CustomerOrderSyncService.instance.notifyOrderChanged();
      unawaited(CustomerOrderSyncService.instance.pushModifiedOrders());
    } catch (_) {}

    // Auto-save setting if unselected/changed
    final currentSettings = ref.read(settingsProvider).valueOrNull;
    if (currentSettings != null && currentSettings.smartRounding != enable) {
      await ref.read(settingsProvider.notifier).update(
            currentSettings.copyWith(smartRounding: enable),
          );
    }

    ref.invalidate(orderDetailProvider(order.id));
    ref.invalidate(customerOrdersProvider);
    ref.invalidate(customerListProvider);
    ref.invalidate(orderManagementProvider);
    ref.invalidate(analyticsSummaryProvider);
    ref.invalidate(todaysDetailedReportProvider);
    ref.invalidate(dashboardOrdersProvider);

    if (mounted) {
      SnackbarHelper.showSuccess(
        context,
        enable
            ? 'Round Off applied (Grand Total: $currency${newGrandTotal.toStringAsFixed(2)})'
            : 'Round Off undone (Grand Total: $currency${newGrandTotal.toStringAsFixed(2)})',
      );
    }
  }

  Future<void> _toggleItemAvailability(AppOrder order, OrderItem item) async {
    final willBeUnavailable = item.isAvailable;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              willBeUnavailable ? Icons.block_rounded : Icons.check_circle_rounded,
              color: willBeUnavailable ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(willBeUnavailable ? 'Mark Unavailable' : 'Mark Available'),
          ],
        ),
        content: Text(
          willBeUnavailable
              ? 'Mark "${item.itemName}" as unavailable in this order?\n\n'
                  '• Item cost will be deducted from order total.\n'
                  '• Physical stock will be restored to inventory.\n'
                  '• This will NOT be counted as spoilage or loss.'
              : 'Mark "${item.itemName}" as available in this order?\n\n'
                  '• Item cost will be added to order total.\n'
                  '• Physical stock will be deducted from inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willBeUnavailable ? Colors.orange : Colors.green,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              willBeUnavailable ? 'Mark Unavailable' : 'Mark Available',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await ref
          .read(orderManagementProvider.notifier)
          .toggleOrderItemAvailability(order.id, item.id);
      ref.invalidate(orderDetailProvider(widget.orderId));
      if (mounted) {
        if (res['success'] == true) {
          final isAvail = res['isAvailable'] == true;
          SnackbarHelper.showSuccess(
            context,
            isAvail
                ? '"${item.itemName}" is now Available'
                : '"${item.itemName}" marked Unavailable (Stock Restored)',
          );
        } else {
          SnackbarHelper.showError(
              context, res['message'] ?? 'Failed to update item availability');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error updating item: $e');
      }
    }
  }

  Future<void> _updateRates(AppOrder order) async {
    if (_isUpdatingRates) return;

    final settings = ref.read(settingsProvider).valueOrNull;
    final currency = settings?.currency ?? '₹';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.refresh_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Update Order Rates'),
          ],
        ),
        content: Text(
          'Do you want to update all item prices in Order ${order.orderNoLabel} to the current selling / custom prices?\n\n'
          'This will recalculate item totals, order subtotal, and grand total.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update Rates',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted || _isUpdatingRates) return;

    setState(() {
      _isUpdatingRates = true;
    });

    try {
      final res = await ref
          .read(orderManagementProvider.notifier)
          .updateOrderRates(order.id);

      ref.invalidate(orderDetailProvider(widget.orderId));

      if (mounted) {
        if (res['success'] == true) {
          final count = res['updatedCount'] ?? 0;
          final oldTotal = (res['oldGrandTotal'] as num?)?.toDouble() ?? 0.0;
          final newTotal = (res['newGrandTotal'] as num?)?.toDouble() ?? 0.0;
          SnackbarHelper.showSuccess(
            context,
            'Updated $count items! Total: $currency${oldTotal.toStringAsFixed(2)} ➔ $currency${newTotal.toStringAsFixed(2)}',
          );
        } else {
          SnackbarHelper.showError(
            context,
            res['message']?.toString() ?? 'Failed to update rates',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to update rates: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingRates = false;
        });
      }
    }
  }

  Future<void> _shareBill(AppOrder order, String currency,
      {required bool isCustomer}) async {
    final settings = ref.read(settingsProvider).value;
    final itemsList = ref.read(inventoryProvider).valueOrNull ?? [];
    double marketSavings = 0.0;
    for (final oi in order.items) {
      final inv = itemsList.where((i) => i.id == oi.itemId).firstOrNull;
      if (inv != null && inv.marketPrice > 0) {
        final qtyInInvUnit = UnitConverter.convert(
          quantity: oi.quantity,
          fromUnit: oi.itemUnit,
          toUnit: inv.unit,
        );
        final totalMarketCost = inv.marketPrice * qtyInInvUnit;
        final totalOrderCost = oi.totalPrice > 0 ? oi.totalPrice : (oi.unitPrice * oi.quantity);
        if (totalMarketCost > totalOrderCost) {
          marketSavings += (totalMarketCost - totalOrderCost);
        }
      }
    }
    final list = order.items.map((it) {
      final matchedItem = itemsList.firstWhere(
        (i) => i.id == it.itemId,
        orElse: () => Item(
          id: '',
          name: '',
          category: 'Other',
          unit: 'kg',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return {
        'item_name': it.itemName,
        'quantity': it.quantity,
        'item_unit': it.itemUnit,
        'unit_price': it.unitPrice,
        'total_price': it.totalPrice,
        'prescription_required': matchedItem.prescriptionRequired,
      };
    }).toList();

    final qAnswers = await OrderQuestionDao.instance.getOrderAnswers(order.id);
    double monthlySavings = 0.0;
    try {
      if (order.customerId.isNotEmpty) {
        final sav = await OrderDao().getCustomerSavings(order.customerId);
        monthlySavings = sav['monthly'] ?? 0.0;
      }
    } catch (_) {}

    Customer? liveCust;
    if (order.customerId.isNotEmpty) {
      try {
        liveCust = await CustomerDao().getCustomerById(order.customerId);
      } catch (_) {}
    }
    final custName = liveCust?.name.trim().isNotEmpty == true
        ? liveCust!.name.trim()
        : (order.customerName ?? 'Walk-in Customer');
    final custAddress = liveCust?.address ?? order.customerAddress ?? '';
    final custPhone = liveCust?.phone1 ?? order.customerPhone ?? '';

    final text = BillTextGenerator.generate(
      businessName: settings?.businessName ?? 'My Business',
      customerName: custName,
      customerAddress: custAddress,
      orderNoLabel: order.orderNoLabel,
      orderDate: order.createdAt,
      items: list,
      subtotal: order.subtotal,
      discount: order.discount,
      deliveryCharge: order.deliveryCharge,
      grandTotal: order.grandTotal,
      paidAmount: order.paidAmount,
      remainingAmount: order.remainingAmount,
      paymentMethod: order.payments.firstOrNull?.method ?? 'cash',
      ownerPhone: settings?.phone ?? '',
      marketSavings: marketSavings,
      monthlySavings: monthlySavings,
      currency: currency,
      notes: order.notes,
      disclaimer: settings?.invoiceDisclaimer ?? '',
      questionAnswers: qAnswers,
    );

    String encodedText = Uri.encodeComponent(text);

    if (isCustomer) {
      final phone = custPhone.isNotEmpty ? custPhone : (order.customerPhone ?? '');
      await ExternalLauncher.launchWhatsApp(context, phone, text: text);
      return;
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
      } catch (_) {}
      return;
    }
  }

  void _printThermalReceipt(AppOrder order, String currency) async {
    final settings = ref.read(settingsProvider).valueOrNull;
    Customer? liveCust;
    if (order.customerId.isNotEmpty) {
      try {
        liveCust = await CustomerDao().getCustomerById(order.customerId);
      } catch (_) {}
    }
    final custName = liveCust?.name.trim().isNotEmpty == true
        ? liveCust!.name.trim()
        : (order.customerName ?? 'Walk-in Customer');
    final custAddress = liveCust?.address ?? order.customerAddress ?? '';

    final itemsList = order.items
        .map((it) => {
              'item_name': it.itemName,
              'quantity': it.quantity,
              'item_unit': it.itemUnit,
              'unit_price': it.unitPrice,
              'total_price': it.totalPrice,
            })
        .toList();

    final thermalText = BillTextGenerator.generateThermalReceipt(
      businessName: settings?.businessName ?? 'OrderKart Store',
      customerName: custName,
      customerAddress: custAddress,
      orderNoLabel: order.orderNoLabel,
      orderDate: order.createdAt,
      items: itemsList,
      subtotal: order.subtotal,
      discount: order.discount,
      deliveryCharge: order.deliveryCharge,
      grandTotal: order.grandTotal,
      paidAmount: order.paidAmount,
      remainingAmount: order.remainingAmount,
      paymentMethod: order.payments.firstOrNull?.method ?? 'cash',
      is58mm: true,
      enableGst: settings?.enableGstTax ?? false,
      gstRate: settings?.gstRate ?? 5.0,
      gstin: settings?.gstinNumber ?? '',
      currency: currency,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.print_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Thermal ESC/POS Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 380),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF0F172A)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gray300),
          ),
          child: SingleChildScrollView(
            child: Text(
              thermalText,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: thermalText));
              if (mounted) {
                Navigator.pop(ctx);
                SnackbarHelper.showSuccess(context, 'Thermal receipt copied to clipboard');
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Thermal Text'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsSection(List<Map<String, dynamic>> answers) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORDER QUESTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 12),
          ...answers.map((ans) {
            final question = ans['question_text']?.toString() ?? '';
            final selected = ans['selected_option']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      question,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text(
                      selected,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
