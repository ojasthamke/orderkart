/// CreateOrderScreen — Full order creation with item picker, quantity,
/// smart rounding, delivery charge, and complete summary

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
import '../../../core/widgets/qr_full_screen_preview.dart';
import '../../customer/presentation/customer_provider.dart';
import '../../../core/widgets/vip_glow_avatar.dart';
import '../domain/order.dart';
import '../domain/order_item.dart';
import '../domain/payment.dart';
import 'order_provider.dart';
import 'widgets/item_selector_widget.dart';
import 'widgets/smart_round_banner.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;
  final String? orderId; // non-null = edit mode

  const CreateOrderScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.orderId,
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

    if (widget.orderId != null) {
      Future.microtask(() => _loadExistingOrder(widget.orderId!));
    }
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

    return AppScaffold(
      title: widget.orderId == null ? 'Create Order' : 'Edit Order',
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

                  // Add Item button
                  const SizedBox(height: 12),
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
                  if (_cart.isNotEmpty) _buildSummaryCard(currency),

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Items', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ..._cart.asMap().entries.map((e) => _CartItemTile(
              cartItem: e.value,
              currency: currency,
              onQtyChanged: (qty) {
                setState(() => _cart[e.key] = e.value.copyWith(quantity: qty));
              },
              onRemove: () => setState(() => _cart.removeAt(e.key)),
            )),
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
                  fontWeight:
                      isBold ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isBold ? FontWeight.w700 : FontWeight.w600,
                  color: color ?? AppColors.textPrimary)),
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

  // ── Bottom save bar ───────────────────────────────────────────────────────────
  Widget _buildBottomBar(BuildContext context, String currency) {
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
            onPressed: _saveOrder,
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

    // ── Pre-Save Stock Validation ───────────────────────────────────────────────
    final inventoryAsync = ref.read(inventoryProvider);
    final inventoryList = inventoryAsync.value ?? [];

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

    final now     = DateTime.now();
    final orderId = widget.orderId ?? const Uuid().v4();

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
      createdAt:          _existingOrder?.createdAt ?? now,
      updatedAt:          now,
    );



    try {
      await ref
          .read(orderManagementProvider.notifier)
          .createOrder(order, items);

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
      setState(() => _saving = false);
      if (mounted) SnackbarHelper.showError(context, 'Failed to save order: $e');
    }
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

  _CartItem copyWith({double? quantity}) => _CartItem(
        itemId:   itemId,
        name:     name,
        unit:     unit,
        price:    price,
        quantity: quantity ?? this.quantity,
      );
}

// ── Cart item tile ────────────────────────────────────────────────────────────
class _CartItemTile extends StatelessWidget {
  final _CartItem cartItem;
  final String currency;
  final ValueChanged<double> onQtyChanged;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.cartItem,
    required this.currency,
    required this.onQtyChanged,
    required this.onRemove,
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
                Text(
                  '$currency${cartItem.price.toStringAsFixed(2)} / ${cartItem.unit}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
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
