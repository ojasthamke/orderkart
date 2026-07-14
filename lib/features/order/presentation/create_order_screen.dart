/// CreateOrderScreen — Full order creation with item picker, quantity,
/// smart rounding, delivery charge, and complete summary
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/smart_rounding.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../inventory/domain/item.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../settings/domain/app_settings.dart';
import '../../customer/presentation/customer_provider.dart';
import '../../../core/widgets/vip_glow_avatar.dart';
import '../domain/order.dart';
import '../domain/order_item.dart';
import '../domain/payment.dart';
import 'order_provider.dart';
import '../data/order_dao.dart';
import '../data/order_questions_dao.dart';
import '../../../core/security/app_mode_service.dart';
import '../../../core/localization/app_localization.dart';
import 'widgets/item_selector_widget.dart';
import 'widgets/smart_round_banner.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;
  final String? orderId; // non-null = edit mode
  final double? initialDiscount;

  const CreateOrderScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.orderId,
    this.initialDiscount,
  });

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final List<_CartItem> _cart = [];
  double _deliveryCharge = AppConstants.defaultDeliveryCharge;
  double _discount       = 0;
  double _paidAmount     = 0;
  String _paymentMethod  = AppConstants.paymentCash;
  bool   _smartRound     = true;
  bool   _deliveryEnabled= true;
  final _noteCon         = TextEditingController();
  final _discountCon     = TextEditingController();
  final _paidCon         = TextEditingController();
  AppOrder? _existingOrder;
  bool   _saving         = false;
  bool   _rxVerified     = false;

  List<OrderQuestion> _questions = [];
  Map<String, String> _selectedAnswers = {};

  Future<void> _loadQuestionsAndPreferences() async {
    try {
      final qList = await OrderQuestionDao.instance.getAllQuestionsForCustomer(widget.customerId);
      final prefs = await OrderQuestionDao.instance.getCustomerAnswers(widget.customerId);
      
      Map<String, String> orderAnswers = {};
      if (widget.orderId != null) {
        final savedOrderAns = await OrderQuestionDao.instance.getOrderAnswers(widget.orderId!);
        for (final row in savedOrderAns) {
          final qId = row['question_id']?.toString() ?? '';
          final opt = row['selected_option']?.toString() ?? '';
          if (qId.isNotEmpty) {
            orderAnswers[qId] = opt;
          }
        }
      }

      setState(() {
        _questions = qList;
        for (final q in qList) {
          if (orderAnswers.containsKey(q.id)) {
            _selectedAnswers[q.id] = orderAnswers[q.id]!;
          } else if (prefs.containsKey(q.id)) {
            _selectedAnswers[q.id] = prefs[q.id]!;
          }
        }
      });
    } catch (_) {}
  }

  // Calculated
  double get _subtotal => _cart.fold(0, (s, i) => s + i.total);
  double get _afterDiscount => (_subtotal - _discount).clamp(0, double.infinity);
  double get _smartRounded {
    if (!_smartRound) return _afterDiscount;
    return SmartRounding.round(_afterDiscount);
  }
  double get _grandTotal => _smartRounded + (_deliveryEnabled ? _deliveryCharge : 0);
  double get _remaining  => (_grandTotal - _paidAmount).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider).value;
    if (settings != null) {
      _deliveryCharge = settings.lastDeliveryCharge;
      _smartRound     = settings.smartRounding;
    }

    if (widget.initialDiscount != null && widget.initialDiscount! > 0) {
      _discount = widget.initialDiscount!;
      _discountCon.text = _discount.toStringAsFixed(2);
    }

    if (widget.orderId != null) {
      Future.microtask(() => _loadExistingOrder(widget.orderId!));
    }
    _loadQuestionsAndPreferences();
  }

  Future<void> _loadExistingOrder(String orderId) async {
    final order = await ref.read(orderDetailProvider(orderId).future);
    if (order != null && mounted) {
      setState(() {
        _existingOrder = order;
        _discount = order.discount;
        _deliveryCharge = order.deliveryCharge;
        _deliveryEnabled = order.deliveryCharge > 0;
        _paidAmount = order.paidAmount;
        _noteCon.text = order.notes;
        
        if (_discount > 0) _discountCon.text = _discount.toStringAsFixed(2);
        if (_paidAmount > 0) _paidCon.text = _paidAmount.toStringAsFixed(2);
        
        if (order.payments.isNotEmpty) {
          _paymentMethod = order.payments.first.method;
        }
        
        _cart.clear();
        for (final item in order.items) {
          _cart.add(_CartItem(
            itemId: item.itemId,
            name: item.itemName,
            unit: item.itemUnit,
            price: item.unitPrice,
            quantity: item.quantity,
          ));
        }
      });
    }
  }

  @override
  void dispose() {
    _noteCon.dispose();
    _discountCon.dispose();
    _paidCon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    final currency = settings?.currency ?? AppConstants.defaultCurrency;

    final discountCapPct = settings?.workerDiscountCap ?? 10.0;
    final isWorker = ref.watch(appModeProvider).valueOrNull == AppMode.worker;
    final enteredDiscountPct = _subtotal > 0 ? (_discount / _subtotal) * 100 : 0.0;
    final exceedsCap = isWorker && enteredDiscountPct > discountCapPct;

    return AppScaffold(
      title: widget.orderId == null
          ? AppLocalization.translate(ref, 'create_order', 'Create Order')
          : 'Edit Order',
      body: Column(
        children: [
          // Customer header
          _buildCustomerHeader(currency),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cart Items
                  _buildCartSection(context, currency),

                  // Reorder from Past Orders
                  if (widget.orderId == null) ...[
                    OutlinedButton.icon(
                      onPressed: () => _showPastOrdersReorderSheet(context),
                      icon: const Icon(Icons.history_rounded, color: AppColors.primary),
                      label: const Text('Reorder from Customer\'s Past Orders'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 46),
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Add Item button
                  OutlinedButton.icon(
                    onPressed: () => _showItemSelector(context),
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: const Text('Add Item'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Delivery Charge
                  _buildDeliverySection(currency),

                  const SizedBox(height: 16),

                  // Discount
                  TextFormField(
                    controller: _discountCon,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Discount',
                      prefixText: '₹ ',
                      prefixIcon: Icon(Icons.discount_rounded),
                    ),
                    onChanged: (v) =>
                        setState(() => _discount = double.tryParse(v) ?? 0),
                  ),
                  if (exceedsCap)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '⚠️ Discount of ${enteredDiscountPct.toStringAsFixed(1)}% exceeds maximum allowed worker limit of ${discountCapPct.toStringAsFixed(0)}%',
                        style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Smart Rounding banner
                  if (_subtotal > 0 && SmartRounding.needsRounding(_afterDiscount))
                    SmartRoundBanner(
                      original:   _afterDiscount,
                      rounded:    SmartRounding.round(_afterDiscount),
                      enabled:    _smartRound,
                      currency:   currency,
                      onToggle:   (v) => setState(() => _smartRound = v),
                    ).animate().fadeIn(),

                  const SizedBox(height: 16),

                  // Order Summary card
                  if (_cart.isNotEmpty) ...[
                    _buildSummaryCard(currency),
                    _buildRxVerificationSection(),
                  ],

                  const SizedBox(height: 16),

                  // Payment
                  _buildPaymentSection(currency, settings),

                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: _noteCon,
                    decoration: const InputDecoration(
                      labelText: 'Order Notes (optional)',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                    maxLines: 2,
                  ),

                  _buildQuestionsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
      // Bottom Save bar
      bottomNavigationBar: _cart.isNotEmpty ? _buildBottomBar(context, currency) : null,
    );
  }

  // ── Customer header ──────────────────────────────────────────────────────────
  Widget _buildCustomerHeader(String currency) {
    final customerAsync = ref.watch(customerDetailProvider(widget.customerId));
    final customer = customerAsync.valueOrNull;
    final isVip = customer?.isVipActive ?? false;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isVip ? const Color(0xFFFFD700).withOpacity(0.12) : AppColors.primarySurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isVip ? const Color(0xFFFFD700) : AppColors.primary.withOpacity(0.2),
              width: isVip ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              VipGlowAvatar(
                photoPath: customer?.photoPath ?? '',
                isVip: isVip,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.customerName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: isVip ? const Color(0xFFB45309) : AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVip) ...[
                          const SizedBox(width: 6),
                          VipGoldBadgeChip(planName: customer?.vipPlan ?? 'VIP'),
                        ],
                      ],
                    ),
                    if (isVip)
                      Text(
                        'Benefits: ${customer!.vipFreeDelivery ? 'Free Delivery • ' : ''}${customer.vipDiscountPct.toStringAsFixed(0)}% Off',
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${_cart.length} items',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Cart section ─────────────────────────────────────────────────────────────
  Widget _buildCartSection(BuildContext context, String currency) {
    if (_cart.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gray200, style: BorderStyle.solid),
        ),
        child: const Center(
          child: Text(
            'No items added yet.\nTap "Add Item" to begin.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final inventoryList = ref.read(inventoryProvider).value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Items', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ..._cart.asMap().entries.map((e) {
          final cartItem = e.value;
          final dbItem = inventoryList.firstWhere(
            (i) => i.id == cartItem.itemId,
            orElse: () => Item(
              id: cartItem.itemId,
              name: cartItem.name,
              category: '',
              unit: cartItem.unit,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          const bool canToggleUnit = true; // Allow switching unit for all items in checkout!

          return _CartItemTile(
            cartItem: cartItem,
            currency: currency,
            canToggleUnit: canToggleUnit,
            onQtyChanged: (qty) {
              setState(() => _cart[e.key] = cartItem.copyWith(quantity: qty));
            },
            onRemove: () => setState(() => _cart.removeAt(e.key)),
            onUnitChanged: (newUnit) {
              if (newUnit == cartItem.unit) return;

              final conversion = dbItem.weightPerPiece;
              double newQty = cartItem.quantity;
              double newPrice = cartItem.price;

              if (newUnit == 'piece' && cartItem.unit == 'dozen') {
                newQty = cartItem.quantity * 12;
                newPrice = cartItem.price / 12;
              } else if (newUnit == 'dozen' && cartItem.unit == 'piece') {
                newQty = cartItem.quantity / 12;
                newPrice = cartItem.price * 12;
              } else if (newUnit == 'piece' && dbItem.unit == 'kg') {
                newQty = cartItem.quantity / conversion;
                newPrice = dbItem.sellingPrice * conversion;
              } else if (newUnit == 'kg' && dbItem.unit == 'kg') {
                newQty = cartItem.quantity * conversion;
                newPrice = dbItem.sellingPrice;
              } else if (newUnit == 'kg' && dbItem.unit == 'piece') {
                newQty = cartItem.quantity * conversion;
                newPrice = dbItem.sellingPrice / conversion;
              } else if (newUnit == 'piece' && dbItem.unit == 'piece') {
                newQty = cartItem.quantity / conversion;
                newPrice = dbItem.sellingPrice;
              }

              setState(() {
                _cart[e.key] = cartItem.copyWith(
                  quantity: double.parse(newQty.toStringAsFixed(2)),
                  unit: newUnit,
                  price: double.parse(newPrice.toStringAsFixed(2)),
                );
              });
            },
          );
        }),
      ],
    );
  }

  // ── Delivery section ─────────────────────────────────────────────────────────
  Widget _buildDeliverySection(String currency) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: _deliveryCharge.toStringAsFixed(0),
            enabled: _deliveryEnabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Delivery Charge',
              prefixText: '$currency ',
              prefixIcon: const Icon(Icons.delivery_dining_rounded),
              suffixText: _deliveryEnabled ? null : 'DISABLED',
            ),
            onChanged: (v) =>
                setState(() => _deliveryCharge = double.tryParse(v) ?? 0),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            const Text('Enable', style: TextStyle(fontSize: 11)),
            Switch(
              value: _deliveryEnabled,
              onChanged: (v) => setState(() => _deliveryEnabled = v),
            ),
          ],
        ),
      ],
    );
  }

  // ── Summary card ─────────────────────────────────────────────────────────────
  Widget _buildSummaryCard(String currency) {
    double marketSavings = 0.0;
    final inventoryAsync = ref.read(inventoryProvider);
    final inventoryList = inventoryAsync.value ?? [];
    for (final cartItem in _cart) {
      Item? dbItem;
      for (final item in inventoryList) {
        if (item.id == cartItem.itemId) {
          dbItem = item;
          break;
        }
      }
      if (dbItem != null && dbItem.marketPrice > cartItem.price) {
        marketSavings += (dbItem.marketPrice - cartItem.price) * cartItem.quantity;
      }
    }
    final totalSavings = marketSavings + _discount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          _sumRow('Subtotal',         AppFormatters.currency(_subtotal,       symbol: currency)),
          if (_discount > 0)
            _sumRow('Discount',       '- ${AppFormatters.currency(_discount, symbol: currency)}',
                color: AppColors.success),
          if (_smartRound && SmartRounding.needsRounding(_afterDiscount))
            _sumRow('Smart Rounded',  AppFormatters.currency(_smartRounded - _afterDiscount, symbol: currency),
                color: AppColors.warning),
          if (_deliveryEnabled && _deliveryCharge > 0)
            _sumRow('Delivery',       AppFormatters.currency(_deliveryCharge, symbol: currency)),
          const Divider(height: 20),
          _sumRow('Grand Total',      AppFormatters.currency(_grandTotal,     symbol: currency),
              isBold: true, color: AppColors.primary),
          _sumRow('Paid',             AppFormatters.currency(_paidAmount,     symbol: currency),
              color: AppColors.success),
          if (_remaining > 0)
            _sumRow('Remaining',      AppFormatters.currency(_remaining,      symbol: currency),
                color: AppColors.error, isBold: true),
          if (totalSavings > 0) ...[
            const Divider(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are saving ${AppFormatters.currency(totalSavings, symbol: currency)} on this order!',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isBold ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.textSecondary)),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isBold ? FontWeight.w700 : FontWeight.w600,
                    color: color ?? AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  // ── Payment section ──────────────────────────────────────────────────────────
  Widget _buildPaymentSection(String currency, AppSettings? settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _paidCon,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Paid Amount',
                  prefixText: '$currency ',
                  prefixIcon: const Icon(Icons.payments_rounded),
                ),
                onChanged: (v) =>
                    setState(() => _paidAmount = double.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Method', style: TextStyle(fontSize: 11)),
                const SizedBox(height: 4),
                DropdownButton<String>(
                  value: _paymentMethod,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                        value: 'cash',
                        child: Text('Cash',
                            style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : AppColors.textPrimary))),
                    DropdownMenuItem(
                        value: 'online',
                        child: Text('Online',
                            style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : AppColors.textPrimary))),
                    DropdownMenuItem(
                        value: 'upi',
                        child: Text('UPI',
                            style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : AppColors.textPrimary))),
                    DropdownMenuItem(
                        value: 'card',
                        child: Text('Card',
                            style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : AppColors.textPrimary))),
                  ],
                  onChanged: (v) =>
                      setState(() => _paymentMethod = v ?? 'cash'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Quick-fill buttons
        Row(
          children: [
            _quickPayBtn('Pay Full', _grandTotal, currency),
            const SizedBox(width: 8),
            _quickPayBtn('Pay Half', _grandTotal / 2, currency),
            const SizedBox(width: 8),
            _quickPayBtn('Pay None', 0, currency),
          ],
        ),
        if (_paymentMethod == AppConstants.paymentOnline || _paymentMethod == AppConstants.paymentUPI) ...[
          const SizedBox(height: 16),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Scan & Pay QR Code',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                if (settings != null) ...[
                  if (settings.qrCustomImage.isNotEmpty)
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.qrPreview,
                        arguments: {'qrCustomImage': settings.qrCustomImage},
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
                    )
                  else if (settings.qrContent.isNotEmpty)
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.qrPreview,
                        arguments: {'qrContent': settings.qrContent},
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
                    )
                  else
                    const Text('No QR Code configured in Settings',
                        style: TextStyle(fontSize: 12, color: AppColors.textHint))
                ] else
                  const CircularProgressIndicator(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _quickPayBtn(String label, double amount, String currency) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() => _paidAmount = amount);
          _paidCon.text = amount.toStringAsFixed(2);
        },
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(8)),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, String currency) {
    final settingsVal = ref.watch(settingsProvider).valueOrNull;
    final discountCapPct = settingsVal?.workerDiscountCap ?? 10.0;
    final isWorker = ref.watch(appModeProvider).valueOrNull == AppMode.worker;
    final enteredDiscountPct = _subtotal > 0 ? (_discount / _subtotal) * 100 : 0.0;
    final exceedsCap = isWorker && enteredDiscountPct > discountCapPct;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        boxShadow: AppColors.elevatedShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total: ${AppFormatters.currency(_grandTotal, symbol: currency)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (_remaining > 0)
                  Text('Remaining: ${AppFormatters.currency(_remaining, symbol: currency)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.error)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: exceedsCap ? null : _saveOrder,
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Save Order'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ── Save order ────────────────────────────────────────────────────────────────
  Future<void> _saveOrder() async {
    if (_saving) return;
    if (_cart.isEmpty) {
      SnackbarHelper.showError(context, 'Add at least one item');
      return;
    }

    final settingsVal = ref.read(settingsProvider).value;
    final discountCapPct = settingsVal?.workerDiscountCap ?? 10.0;
    final isWorker = ref.read(appModeProvider).valueOrNull == AppMode.worker;
    final enteredDiscountPct = _subtotal > 0 ? (_discount / _subtotal) * 100 : 0.0;
    if (isWorker && enteredDiscountPct > discountCapPct) {
      SnackbarHelper.showError(context, 'Discount of ${enteredDiscountPct.toStringAsFixed(1)}% exceeds maximum allowed worker limit of ${discountCapPct.toStringAsFixed(0)}%');
      return;
    }

    // ── Pre-Save Stock Validation ───────────────────────────────────────────────
    final inventoryAsync = ref.read(inventoryProvider);
    final inventoryList = inventoryAsync.value ?? [];

    bool hasRxItems = false;
    for (final cartItem in _cart) {
      final dbItem = inventoryList.firstWhere(
        (i) => i.id == cartItem.itemId,
        orElse: () => Item(
          id: '',
          name: '',
          category: 'Other',
          unit: 'kg',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (dbItem.id.isNotEmpty && dbItem.prescriptionRequired) {
        hasRxItems = true;
        break;
      }
    }

    if (hasRxItems && !_rxVerified) {
      AppHaptics.error();
      SnackbarHelper.showError(
        context,
        '⚠️ Prescription Required: You must physically verify the Doctor\'s Prescription for this order.',
      );
      return;
    }

    for (final cartItem in _cart) {
      final dbItem = inventoryList.firstWhere((i) => i.id == cartItem.itemId,
          orElse: () => Item(
                id: cartItem.itemId,
                name: cartItem.name,
                category: 'Other',
                sellingPrice: cartItem.price,
                stock: 0,
                unit: cartItem.unit,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ));
      
      if (cartItem.quantity > dbItem.stock) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.error),
                SizedBox(width: 8),
                Text('Insufficient Stock'),
              ],
            ),
            content: Text(
              'Item "${cartItem.name}" has only ${AppFormatters.quantity(dbItem.stock)} ${dbItem.unit} in stock, but ${AppFormatters.quantity(cartItem.quantity)} was added to order.\n\nPlease adjust quantity before saving.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    AppHaptics.primarySave();
    setState(() => _saving = true);

    final now = DateTime.now();
    final String orderId = widget.orderId ?? await OrderDao.generateUniqueOrderNo();

    final roundingDiff = _smartRound ? _smartRounded - _afterDiscount : 0;
    
    final List<OrderItem> items = [];
    if (_cart.isNotEmpty) {
      double distributedSum = 0;
      for (int i = 0; i < _cart.length; i++) {
        final c = _cart[i];
        double adjustedTotal = c.total;
        
        if (roundingDiff != 0 && _subtotal > 0) {
          if (i == _cart.length - 1) {
            adjustedTotal = double.parse((c.total + (roundingDiff - distributedSum)).toStringAsFixed(2));
          } else {
            final share = double.parse((roundingDiff * (c.total / _subtotal)).toStringAsFixed(2));
            adjustedTotal = double.parse((c.total + share).toStringAsFixed(2));
            distributedSum += share;
          }
        }
        
        final adjustedUnitPrice = c.quantity > 0 
            ? double.parse((adjustedTotal / c.quantity).toStringAsFixed(4))
            : c.price;
        
        items.add(OrderItem(
          id:         const Uuid().v4(),
          orderId:    orderId,
          itemId:     c.itemId,
          itemName:   c.name,
          itemUnit:   c.unit,
          quantity:   c.quantity,
          unitPrice:  adjustedUnitPrice,
          totalPrice: adjustedTotal,
        ));
      }
    }

    final adjustedSubtotal = double.parse((_subtotal + roundingDiff).toStringAsFixed(2));

    double marketSavings = 0.0;
    for (final cartItem in _cart) {
      Item? dbItem;
      for (final item in inventoryList) {
        if (item.id == cartItem.itemId) {
          dbItem = item;
          break;
        }
      }
      if (dbItem != null && dbItem.marketPrice > cartItem.price) {
        marketSavings += (dbItem.marketPrice - cartItem.price) * cartItem.quantity;
      }
    }
    final totalSavings = marketSavings + _discount;

    final order = AppOrder(
      id:                 orderId,
      customerId:         widget.customerId,
      subtotal:           adjustedSubtotal,
      discount:           _discount,
      deliveryCharge:     _deliveryEnabled ? _deliveryCharge : 0,
      smartRoundedAmount: 0, 
      grandTotal:         _grandTotal,
      paidAmount:         _paidAmount,
      remainingAmount:    _remaining,
      notes:              _noteCon.text.trim(),
      savings:            totalSavings,
      createdAt:          _existingOrder?.createdAt ?? now,
      updatedAt:          now,
    );



    try {
      await ref
          .read(orderManagementProvider.notifier)
          .createOrder(order, items);

      final List<Map<String, dynamic>> orderAnsToSave = [];
      for (final entry in _selectedAnswers.entries) {
        final q = _questions.where((x) => x.id == entry.key).firstOrNull;
        if (q != null) {
          orderAnsToSave.add({
            'question_id': entry.key,
            'question_text': q.question,
            'selected_option': entry.value,
          });
        }
        await OrderQuestionDao.instance.saveCustomerAnswer(widget.customerId, entry.key, entry.value);
      }
      await OrderQuestionDao.instance.saveOrderAnswers(orderId, orderAnsToSave);

      // Add initial payment if any
      if (_paidAmount > 0) {
        await ref.read(orderManagementProvider.notifier).addPayment(Payment(
              id:         const Uuid().v4(),
              orderId:    orderId,
              customerId: widget.customerId,
              amount:     _paidAmount,
              method:     _paymentMethod,
              createdAt:  now,
            ));
      }

      // Persist last delivery charge
      ref.read(settingsProvider.notifier).updateLastDeliveryCharge(_deliveryCharge);

      if (!mounted) return;
      // Navigate to order detail
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.orderDetail,
        arguments: {'orderId': orderId},
      );
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Failed to save order: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showPastOrdersReorderSheet(BuildContext context) {
    AppHaptics.selection();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final ordersAsync = ref.watch(customerOrdersProvider(widget.customerId));
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Reorder Past Order for ${widget.customerName}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ordersAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error loading past orders: $e')),
                    data: (pastOrders) {
                      if (pastOrders.isEmpty) {
                        return const Center(child: Text('No previous orders found for this customer.'));
                      }
                      return ListView.builder(
                        itemCount: pastOrders.length,
                        itemBuilder: (_, i) {
                          final o = pastOrders[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text('Order ${o.orderNoLabel} — ${AppFormatters.currency(o.grandTotal)}'),
                              subtitle: Text(
                                '${AppFormatters.date(o.createdAt)} • ${o.items.length} items (${o.items.map((it) => it.itemName).join(', ')})',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  AppHaptics.itemAdded();
                                  setState(() {
                                    _cart.clear();
                                    for (final it in o.items) {
                                      _cart.add(_CartItem(
                                        itemId: it.itemId,
                                        name: it.itemName,
                                        unit: it.itemUnit,
                                        price: it.unitPrice,
                                        quantity: it.quantity,
                                      ));
                                    }
                                  });
                                  Navigator.pop(ctx);
                                  SnackbarHelper.showSuccess(context, 'Reordered ${o.items.length} items from past order');
                                },
                                child: const Text('Reorder'),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showItemSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemSelectorWidget(
        onItemSelected: (item, qty) {
          setState(() {
            final existing = _cart.indexWhere((c) => c.itemId == item.id);
            if (existing >= 0) {
              final newTotal = _cart[existing].quantity + qty;
              if (newTotal > item.stock) {
                SnackbarHelper.showError(
                  context,
                  'Cannot add more "${item.name}". Stock limit is ${AppFormatters.quantity(item.stock)}',
                );
                return;
              }
              _cart[existing] = _cart[existing].copyWith(quantity: newTotal);
            } else {
              if (qty > item.stock) {
                SnackbarHelper.showError(
                  context,
                  'Cannot add ${AppFormatters.quantity(qty)} of "${item.name}". Stock limit is ${AppFormatters.quantity(item.stock)}',
                );
                return;
              }
              double unitPrice = item.sellingPrice;
              final customer = ref.read(customerDetailProvider(widget.customerId)).value;
              final settings = ref.read(settingsProvider).valueOrNull;
              final enableMarkup = settings?.enableVipPriceMarkup ?? true;
              if (enableMarkup && customer != null && customer.isVipActive && customer.vipMarkupPct > 0) {
                unitPrice = double.parse((item.sellingPrice * (1 + (customer.vipMarkupPct / 100))).toStringAsFixed(2));
              }

              _cart.add(_CartItem(
                itemId:   item.id,
                name:     item.name,
                unit:     item.unit,
                price:    unitPrice,
                quantity: qty,
              ));
            }
          });
        },
      ),
    );
  }

  void _addQuestion(bool isSpecific) {
    AppHaptics.buttonClick();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isSpecific ? 'Add Specific Question' : 'Add Common Question', style: const TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: _AddSpecificQuestionForm(
          customerId: isSpecific ? widget.customerId : '',
          onSaved: () {
            Navigator.pop(context);
            _loadQuestionsAndPreferences();
          },
        ),
      ),
    );
  }

  Widget _buildQuestionsSection() {
    if (_questions.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(top: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Order Notes Questions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'No template questions configured yet.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _addQuestion(false),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Common Q', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _addQuestion(true),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Specific Q', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Notes Questions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _addQuestion(false),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Common', style: TextStyle(fontSize: 11)),
                    ),
                    TextButton.icon(
                      onPressed: () => _addQuestion(true),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Specific', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            ..._questions.map((q) {
              final selectedValue = _selectedAnswers[q.id];
              final isSpecific = q.customerId != null && q.customerId!.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            q.question,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        if (isSpecific)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Specific',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: q.options.map((opt) {
                        final isSel = selectedValue == opt;
                        return ChoiceChip(
                          label: Text(opt, style: const TextStyle(fontSize: 12)),
                          selected: isSel,
                          selectedColor: AppColors.primary.withOpacity(0.15),
                          labelStyle: TextStyle(
                            color: isSel ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedAnswers[q.id] = opt;
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRxVerificationSection() {
    final inventoryAsync = ref.read(inventoryProvider);
    final inventoryList = inventoryAsync.value ?? [];

    bool hasRxItems = false;
    for (final cartItem in _cart) {
      final dbItem = inventoryList.firstWhere(
        (i) => i.id == cartItem.itemId,
        orElse: () => Item(
          id: '',
          name: '',
          category: 'Other',
          unit: 'kg',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (dbItem.id.isNotEmpty && dbItem.prescriptionRequired) {
        hasRxItems = true;
        break;
      }
    }

    if (!hasRxItems) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.18), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'Prescription Required (Rx)',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error.withOpacity(0.9)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'This order contains prescription-only medicines. Please physically verify the doctor\'s prescription before proceeding.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text(
              'Doctor Prescription Verified physically',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error),
            ),
            value: _rxVerified,
            onChanged: (val) {
              if (val != null) {
                AppHaptics.buttonClick();
                setState(() => _rxVerified = val);
              }
            },
            activeColor: AppColors.error,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }
}

// ── Cart data model ───────────────────────────────────────────────────────────
class _CartItem {
  final String itemId;
  final String name;
  final String unit;
  final double price;
  final double quantity;

  double get total => double.parse((price * quantity).toStringAsFixed(2));

  const _CartItem({
    required this.itemId,
    required this.name,
    required this.unit,
    required this.price,
    required this.quantity,
  });

  _CartItem copyWith({double? quantity, String? unit, double? price}) => _CartItem(
        itemId:   itemId,
        name:     name,
        unit:     unit ?? this.unit,
        price:    price ?? this.price,
        quantity: quantity ?? this.quantity,
      );
}

// ── Cart item tile ────────────────────────────────────────────────────────────
class _CartItemTile extends StatelessWidget {
  final _CartItem cartItem;
  final String currency;
  final ValueChanged<double> onQtyChanged;
  final VoidCallback onRemove;
  final bool canToggleUnit;
  final ValueChanged<String>? onUnitChanged;

  const _CartItemTile({
    required this.cartItem,
    required this.currency,
    required this.onQtyChanged,
    required this.onRemove,
    this.canToggleUnit = false,
    this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cartItem.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$currency${cartItem.price.toStringAsFixed(2)} ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    if (canToggleUnit)
                      DropdownButton<String>(
                        value: cartItem.unit,
                        underline: const SizedBox(),
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppColors.primary),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                        items: {
                          cartItem.unit,
                          ...AppConstants.itemUnits,
                        }.map((u) => DropdownMenuItem(
                          value: u,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(u),
                          ),
                        )).toList(),
                        onChanged: (v) {
                          if (v != null) onUnitChanged?.call(v);
                        },
                      )
                    else
                      Text(
                        '/ ${cartItem.unit}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Qty picker
          _QtyPicker(
            quantity:   cartItem.quantity,
            onChanged:  onQtyChanged,
          ),
          const SizedBox(width: 12),
          Text(
            '$currency${cartItem.total.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
            onPressed: onRemove,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(left: 8),
          ),
        ],
      ),
    );
  }
}

class _QtyPicker extends StatefulWidget {
  final double quantity;
  final ValueChanged<double> onChanged;
  const _QtyPicker({required this.quantity, required this.onChanged});

  @override
  State<_QtyPicker> createState() => _QtyPickerState();
}

class _QtyPickerState extends State<_QtyPicker> {
  late double _qty;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _qty = widget.quantity;
    _ctrl.text = AppFormatters.quantity(_qty);
  }

  @override
  void didUpdateWidget(_QtyPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantity != widget.quantity) {
      _qty = widget.quantity;
      final formatted = AppFormatters.quantity(_qty);
      if (_ctrl.text != formatted) {
        _ctrl.text = formatted;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: _ctrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          suffixIcon: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _qty = double.parse((_qty + 0.25).toStringAsFixed(2));
                    _ctrl.text = AppFormatters.quantity(_qty);
                    widget.onChanged(_qty);
                  });
                },
                child: const Icon(Icons.keyboard_arrow_up_rounded, size: 16),
              ),
              InkWell(
                onTap: () {
                  if (_qty > 0.25) {
                    setState(() {
                      _qty = double.parse((_qty - 0.25).toStringAsFixed(2));
                      _ctrl.text = AppFormatters.quantity(_qty);
                      widget.onChanged(_qty);
                    });
                  }
                },
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              ),
            ],
          ),
        ),
        onChanged: (v) {
          final clean = v.trim();
          if (clean.isEmpty) return;
          final parsed = double.tryParse(clean);
          if (parsed != null && parsed >= 0) {
            _qty = parsed;
            widget.onChanged(_qty);
          }
        },
      ),
    );
  }
}

class _AddSpecificQuestionForm extends StatefulWidget {
  final String customerId;
  final VoidCallback onSaved;

  const _AddSpecificQuestionForm({required this.customerId, required this.onSaved});

  @override
  State<_AddSpecificQuestionForm> createState() => _AddSpecificQuestionFormState();
}

class _AddSpecificQuestionFormState extends State<_AddSpecificQuestionForm> {
  final _formKey = GlobalKey<FormState>();
  final _questionCon = TextEditingController();
  final List<TextEditingController> _optionCons = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionCon.dispose();
    for (final c in _optionCons) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    AppHaptics.buttonClick();
    setState(() {
      _optionCons.add(TextEditingController());
    });
  }

  void _removeOption(int idx) {
    AppHaptics.buttonClick();
    setState(() {
      _optionCons[idx].dispose();
      _optionCons.removeAt(idx);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final question = _questionCon.text.trim();
    final options = _optionCons.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

    if (options.isEmpty) {
      SnackbarHelper.showError(context, 'Please add at least 1 option');
      return;
    }

    try {
      await OrderQuestionDao.instance.addQuestion(
        question,
        options,
        customerId: widget.customerId.trim().isEmpty ? null : widget.customerId,
      );
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save question: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _questionCon,
              decoration: const InputDecoration(
                labelText: 'Question Text',
                hintText: 'e.g., how should be the tomato?',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter question text' : null,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Options:', style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                  onPressed: _addOption,
                ),
              ],
            ),
            ...List.generate(_optionCons.length, (idx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _optionCons[idx],
                        decoration: InputDecoration(
                          labelText: 'Option ${idx + 1}',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter option text' : null,
                      ),
                    ),
                    if (_optionCons.length > 1) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        onPressed: () => _removeOption(idx),
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: _submit,
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
