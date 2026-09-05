/// CreateOrderScreen — Full order creation with item picker, quantity,
/// smart rounding, delivery charge, and complete summary
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/unit_converter.dart';
import '../../../core/utils/smart_rounding.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../inventory/domain/item.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../settings/domain/app_settings.dart';
import '../../customer/domain/customer.dart';
import '../../customer/presentation/customer_provider.dart';
import '../../../core/widgets/vip_glow_avatar.dart';
import '../domain/order.dart';
import '../domain/order_item.dart';
import '../domain/payment.dart';
import 'order_provider.dart';
import '../data/order_dao.dart';
import '../../location/presentation/location_provider.dart';
import '../data/order_questions_dao.dart';
import '../../../core/security/app_mode_service.dart';
import '../../../core/widgets/owner_pin_dialog.dart';
import '../../../core/localization/app_localization.dart';
import 'widgets/item_selector_widget.dart';
import 'widgets/smart_round_banner.dart';

class CartItem {
  final String itemId;
  final String name;
  final String unit;
  final double price;
  final double quantity;
  final bool isAvailable;

  double get total => isAvailable ? double.parse((price * quantity).toStringAsFixed(2)) : 0.0;
  double get fullPrice => double.parse((price * quantity).toStringAsFixed(2));

  const CartItem({
    required this.itemId,
    required this.name,
    required this.unit,
    required this.price,
    required this.quantity,
    this.isAvailable = true,
  });

  CartItem copyWith({double? quantity, String? unit, double? price, bool? isAvailable}) =>
      CartItem(
        itemId: itemId,
        name: name,
        unit: unit ?? this.unit,
        price: price ?? this.price,
        quantity: quantity ?? this.quantity,
        isAvailable: isAvailable ?? this.isAvailable,
      );
}

final createOrderCartProvider =
    StateProvider.family<List<CartItem>, String>((ref, customerId) => []);

class CreateOrderScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;
  final String? orderId; // non-null = edit mode
  final double? initialDiscount;
  final bool autoReorder;

  const CreateOrderScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.orderId,
    this.initialDiscount,
    this.autoReorder = false,
  });

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final List<CartItem> _cart = [];
  double _deliveryCharge = AppConstants.defaultDeliveryCharge;
  double _discount = 0;
  double _paidAmount = 0;
  String _paymentMethod = AppConstants.paymentCash;
  bool _smartRound = true;
  bool _deliveryEnabled = true;
  final _noteCon = TextEditingController();
  final _discountCon = TextEditingController();
  final _paidCon = TextEditingController();
  AppOrder? _existingOrder;
  bool _saving = false;
  bool _rxVerified = false;
  bool _orderSaved = false;
  bool _isDiscountManuallyEdited = false;
  bool _isDeliveryManuallyToggled = false;
  bool _showProfit = false;

  List<OrderQuestion> _questions = [];
  Map<String, String> _selectedAnswers = {};

  Future<void> _loadQuestionsAndPreferences() async {
    try {
      final qList = await OrderQuestionDao.instance
          .getAllQuestionsForCustomer(widget.customerId);
      final prefs =
          await OrderQuestionDao.instance.getCustomerAnswers(widget.customerId);

      Map<String, String> orderAnswers = {};
      if (widget.orderId != null) {
        final savedOrderAns =
            await OrderQuestionDao.instance.getOrderAnswers(widget.orderId!);
        for (final row in savedOrderAns) {
          final qId = row['question_id']?.toString() ?? '';
          final opt = row['selected_option']?.toString() ?? '';
          if (qId.isNotEmpty) {
            orderAnswers[qId] = opt;
          }
        }
      }

      if (mounted) {
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
      }
    } catch (_) {}
  }



  // Calculated
  double get _subtotal => _cart.fold(0, (s, i) => s + i.total);
  double get _afterDiscount =>
      (_subtotal - _discount).clamp(0, double.infinity);
  double get _unroundedGrandTotal =>
      _afterDiscount + (_deliveryEnabled ? _deliveryCharge : 0);
  double get _smartRounded {
    if (!_smartRound) return _unroundedGrandTotal;
    return SmartRounding.round(_unroundedGrandTotal);
  }

  double get _grandTotal => _smartRounded;
  double get _remaining => _grandTotal - _paidAmount;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider).value;
    if (settings != null) {
      _deliveryCharge = settings.deliveryCharge;
      _deliveryEnabled = settings.enableDeliveryCharges;
      _smartRound = settings.smartRounding;
    }

    if (widget.initialDiscount != null && widget.initialDiscount! > 0) {
      _discount = widget.initialDiscount!;
      _discountCon.text = _discount.toStringAsFixed(2);
    }

    if (widget.orderId != null) {
      _isDiscountManuallyEdited = true;
      _isDeliveryManuallyToggled = true;
      Future.microtask(() => _loadExistingOrder(widget.orderId!));
    } else {
      final savedCart = ref.read(createOrderCartProvider(widget.customerId));
      if (savedCart.isNotEmpty) {
        _cart.addAll(savedCart);
      }
      if (widget.autoReorder) {
        Future.microtask(() => _quickReorderPreviousOrder());
      }
    }
    _loadQuestionsAndPreferences();
  }

  Future<void> _loadExistingOrder(String orderId) async {
    try {
      final order = await ref.read(orderDetailProvider(orderId).future);
      if (order != null && mounted) {
        setState(() {
          _existingOrder = order;
          _discount = order.discount;

          final itemsTotal = order.items.fold(0.0, (s, i) => s + i.totalPrice);
          double effDelivery = order.deliveryCharge;
          if (effDelivery <= 0 && order.grandTotal > itemsTotal + 0.05 && itemsTotal > 0) {
            effDelivery = order.grandTotal - itemsTotal;
          }

          _deliveryCharge = effDelivery;
          _deliveryEnabled = effDelivery > 0;
          _paidAmount = order.paidAmount;
          _noteCon.text = order.notes;

          _isDiscountManuallyEdited = true;
          _isDeliveryManuallyToggled = true;

          if (_discount > 0) _discountCon.text = _discount.toStringAsFixed(2);
          if (_paidAmount > 0) _paidCon.text = _paidAmount.toStringAsFixed(2);

          if (order.payments.isNotEmpty) {
            _paymentMethod = order.payments.first.method;
          }

          _cart.clear();
          for (final item in order.items) {
            _cart.add(CartItem(
              itemId: item.itemId,
              name: item.itemName,
              unit: item.itemUnit,
              price: item.unitPrice,
              quantity: item.quantity,
              isAvailable: item.isAvailable,
            ));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to load existing order: $e');
      }
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
    if (widget.orderId != null && _existingOrder == null) {
      return const AppScaffold(
        title: 'Edit Order',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final settings = ref.watch(settingsProvider).valueOrNull;
    final currency = settings?.currency ?? AppConstants.defaultCurrency;

    final customerAsync = ref.watch(customerDetailProvider(widget.customerId));
    final customer = customerAsync.valueOrNull;
    final isVip = customer?.isVipActive ?? false;

    // Auto-calculate VIP discount if not manually edited
    if (customer != null && isVip && !_isDiscountManuallyEdited) {
      final targetDiscount = double.parse(
          (_subtotal * (customer.vipDiscountPct / 100)).toStringAsFixed(2));
      if (_discount != targetDiscount) {
        _discount = targetDiscount;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDiscountManuallyEdited) {
            _discountCon.text =
                _discount > 0 ? _discount.toStringAsFixed(2) : '';
          }
        });
      }
    } else if ((customer == null || !isVip) &&
        !_isDiscountManuallyEdited &&
        _discount != 0) {
      _discount = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDiscountManuallyEdited) {
          _discountCon.text = '';
        }
      });
    }

    // Auto-calculate VIP free delivery if not manually toggled
    final enableDelivery = settings?.enableDeliveryCharges ?? true;
    if (!enableDelivery) {
      if (_deliveryEnabled) {
        _deliveryEnabled = false;
      }
    } else {
      if (customer != null &&
          isVip &&
          customer.vipFreeDelivery &&
          !_isDeliveryManuallyToggled) {
        if (_deliveryEnabled) {
          _deliveryEnabled = false;
        }
      } else if ((customer == null || !isVip || !customer.vipFreeDelivery) &&
          !_isDeliveryManuallyToggled) {
        if (!_deliveryEnabled) {
          _deliveryEnabled = true;
        }
      }
    }

    final discountCapPct = settings?.workerDiscountCap ?? 10.0;
    final isWorker = ref.watch(appModeProvider).valueOrNull == AppMode.worker;
    final enteredDiscountPct =
        _subtotal > 0 ? (_discount / _subtotal) * 100 : 0.0;
    final exceedsCap = isWorker && enteredDiscountPct > discountCapPct;

    return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop && !_orderSaved && widget.orderId == null) {
            ref
                .read(createOrderCartProvider(widget.customerId).notifier)
                .state = List.from(_cart);
          }
        },
        child: AppScaffold(
          title: widget.orderId == null
              ? AppLocalization.translate(ref, 'create_order', 'Create Order')
              : 'Edit Order',
          body: Column(
            children: [
              // Customer header
              _buildCustomerHeader(currency),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cart Items
                      _buildCartSection(context, currency),

                      // Reorder from Past Orders CTA Buttons
                      if (widget.orderId == null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _quickReorderPreviousOrder,
                            icon: const Icon(Icons.bolt_rounded,
                                size: 19, color: Colors.amber),
                            label: const Text(
                              'Reorder Last Order',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Add Item button
                      OutlinedButton.icon(
                        onPressed: () => _showItemSelector(context),
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: const Text('Add Item',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Delivery Charge
                      _buildDeliverySection(currency),

                      const SizedBox(height: 16),

                      // Discount
                      TextFormField(
                        controller: _discountCon,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Discount',
                          prefixText: '$currency ',
                          prefixIcon: const Icon(Icons.discount_rounded),
                        ),
                        onChanged: (v) {
                          _isDiscountManuallyEdited = true;
                          final parsed = math.max(0.0, double.tryParse(v) ?? 0);
                          setState(() => _discount = parsed);
                          if (_subtotal > 0 && (parsed / _subtotal) > 0.25) {
                            AppHaptics.selection();
                          }
                        },
                      ),
                      if (exceedsCap)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '⚠️ Discount of ${enteredDiscountPct.toStringAsFixed(1)}% exceeds maximum allowed worker limit of ${discountCapPct.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (_discount > _subtotal && _subtotal > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '⚠️ Discount cannot exceed the subtotal amount',
                            style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFFF87171)
                                  : AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Smart Rounding banner
                      if (_subtotal > 0 &&
                          SmartRounding.needsRounding(_unroundedGrandTotal))
                        SmartRoundBanner(
                          original: _unroundedGrandTotal,
                          rounded: SmartRounding.round(_unroundedGrandTotal),
                          enabled: _smartRound,
                          currency: currency,
                          onToggle: (v) async {
                            setState(() => _smartRound = v);
                            final currentSettings =
                                ref.read(settingsProvider).valueOrNull;
                            if (currentSettings != null &&
                                currentSettings.smartRounding != v) {
                              await ref.read(settingsProvider.notifier).update(
                                    currentSettings.copyWith(smartRounding: v),
                                  );
                            }
                          },
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

                      const SizedBox(height: 16),

                      // Order Questions & Preferences Section
                      _buildOrderQuestionsSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Bottom Save bar
          bottomNavigationBar:
              _cart.isNotEmpty ? _buildBottomBar(context, currency) : null,
        ));
  }

  // ── Customer header ──────────────────────────────────────────────────────────
  Widget _buildCustomerHeader(String currency) {
    final customerAsync = ref.watch(customerDetailProvider(widget.customerId));
    final customer = customerAsync.valueOrNull;
    final isVip = customer?.isVipActive ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVip
            ? const Color(0xFFFFD700).withOpacity(0.12)
            : (isDark
                ? AppColors.primary.withOpacity(0.15)
                : AppColors.primarySurface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isVip
              ? const Color(0xFFFFD700)
              : (isDark
                  ? Colors.white.withOpacity(0.12)
                  : AppColors.primary.withOpacity(0.2)),
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
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: isVip
                                  ? const Color(0xFFFFD700)
                                  : (isDark ? Colors.white : AppColors.primary),
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
                if (customer != null)
                  ref.watch(locationPathNameProvider(customer.streetId)).when(
                        data: (fullPath) {
                          if (fullPath.isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                fullPath,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }
                          return Container(
                            margin: const EdgeInsets.only(top: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange.withOpacity(0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_location_alt_rounded, size: 11, color: Colors.orange),
                                SizedBox(width: 4),
                                Text(
                                  '⚠️ Delivery Area Not Set',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                if (customer != null && customer.houseNumber.isNotEmpty)
                  ref.watch(sameHouseCustomersProvider((
                    houseNumber: customer.houseNumber,
                    streetId: customer.streetId,
                    customerId: customer.id,
                  ))).when(
                    data: (families) {
                      if (families.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: InkWell(
                          onTap: () => _showFamilySwitcherSheet(context, families),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.indigo.withOpacity(0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.family_restroom_rounded, size: 14, color: Colors.indigo),
                                const SizedBox(width: 4),
                                Text(
                                  'House #${customer.houseNumber} (${families.length + 1} Families) ▾',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                if (customer != null && customer.outstandingBalance != 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: customer.outstandingBalance < 0
                            ? Colors.teal.withOpacity(0.15)
                            : AppColors.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: customer.outstandingBalance < 0
                              ? Colors.teal.withOpacity(0.4)
                              : AppColors.error.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        customer.outstandingBalance < 0
                            ? 'Advance Credit: $currency${customer.outstandingBalance.abs().toStringAsFixed(2)}'
                            : 'Previous Due: $currency${customer.outstandingBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: customer.outstandingBalance < 0
                              ? Colors.teal.shade700
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ),
                if (isVip)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Benefits: ${customer!.vipFreeDelivery ? 'Free Delivery • ' : ''}${customer.vipDiscountPct.toStringAsFixed(0)}% Off',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFFB45309),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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
    );
  }





  // ── Animated Margin & Profit Pill ──────────────────────────────────────────
  Widget _buildProfitMarginPill(String currency, List<Item> inventoryList) {
    if (_cart.isEmpty) return const SizedBox.shrink();

    double totalCost = 0.0;
    for (final cartItem in _cart) {
      Item? dbItem;
      for (final it in inventoryList) {
        if (it.id == cartItem.itemId) {
          dbItem = it;
          break;
        }
      }
      if (dbItem != null) {
        totalCost += dbItem.costPrice * cartItem.quantity;
      }
    }

    final netProfit =
        (_subtotal - _discount - totalCost).clamp(0.0, double.infinity);
    final marginPct = _subtotal > 0 ? (netProfit / _subtotal) * 100 : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        AppHaptics.selection();
        setState(() => _showProfit = !_showProfit);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF065F46),
                    const Color(0xFF047857),
                  ]
                : [
                    const Color(0xFFD1FAE5),
                    const Color(0xFFA7F3D0),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? const Color(0xFF34D399).withOpacity(0.6)
                : const Color(0xFF059669).withOpacity(0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.25)
                    : Colors.white.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showProfit
                    ? Icons.trending_up_rounded
                    : Icons.lock_outline_rounded,
                size: 13,
                color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _showProfit
                  ? 'Est. Profit: $currency${netProfit.toStringAsFixed(2)} (${marginPct.toStringAsFixed(1)}%)'
                  : 'Est. Profit: • • • • (Tap to view)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color:
                    isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cart section ─────────────────────────────────────────────────────────────
  Widget _buildCartSection(BuildContext context, String currency) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_cart.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B).withOpacity(0.4)
              : AppColors.gray50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.12) : AppColors.gray200,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Text(
            'No items added yet.\nTap "Add Item" to begin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    final inventoryList = ref.read(inventoryProvider).value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Items', style: Theme.of(context).textTheme.titleSmall),
            _buildProfitMarginPill(currency, inventoryList),
          ],
        ),
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

          const bool canToggleUnit =
              true; // Allow switching unit for all items in checkout!

          return _CartItemTile(
            cartItem: cartItem,
            dbItem: dbItem,
            currency: currency,
            canToggleUnit: canToggleUnit,
            onQtyChanged: (qty) {
              if (qty <= 0) {
                SnackbarHelper.showError(
                  context,
                  'Quantity for "${cartItem.name}" must be greater than 0',
                );
                setState(
                    () => _cart[e.key] = cartItem.copyWith(quantity: 0.25));
                return;
              }
              final double maxStock = UnitConverter.convert(
                quantity: dbItem.stock,
                fromUnit: dbItem.unit,
                toUnit: cartItem.unit,
              );

              if (maxStock < 0.001) {
                SnackbarHelper.showError(
                  context,
                  '"${cartItem.name}" is OUT OF STOCK (0 ${cartItem.unit} available)',
                );
                return;
              }

              if (qty > maxStock) {
                SnackbarHelper.showError(
                  context,
                  'Cannot exceed stock limit of ${AppFormatters.quantity(maxStock)} ${cartItem.unit} for "${cartItem.name}"',
                );
                setState(
                    () => _cart[e.key] = cartItem.copyWith(quantity: maxStock));
                return;
              }
              setState(() => _cart[e.key] = cartItem.copyWith(quantity: qty));
            },
            onRemove: () => setState(() => _cart.removeAt(e.key)),
            onUnitChanged: (newUnit) {
              if (newUnit == cartItem.unit) return;

              final double newQty = UnitConverter.convert(
                quantity: cartItem.quantity,
                fromUnit: cartItem.unit,
                toUnit: newUnit,
              );

              final double newPrice = (newQty > 0)
                  ? double.parse(((cartItem.price * cartItem.quantity) / newQty).toStringAsFixed(4))
                  : cartItem.price;

              setState(() {
                _cart[e.key] = cartItem.copyWith(
                  quantity: double.parse(newQty.toStringAsFixed(3)),
                  unit: newUnit,
                  price: newPrice,
                );
              });
            },
            onToggleAvailable: () {
              AppHaptics.selection();
              setState(() {
                _cart[e.key] =
                    cartItem.copyWith(isAvailable: !cartItem.isAvailable);
              });
            },
          );
        }),
        if (_cart.any((i) => !i.isAvailable)) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_cart.where((i) => !i.isAvailable).length} item(s) marked Unavailable. Their price is deducted from the bill total.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Delivery section ─────────────────────────────────────────────────────────
  Widget _buildDeliverySection(String currency) {
    final enableDelivery =
        ref.watch(settingsProvider).valueOrNull?.enableDeliveryCharges ?? true;
    if (!enableDelivery) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withOpacity(0.5)
            : AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : AppColors.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.delivery_dining_rounded,
                    size: 22,
                    color: _deliveryEnabled
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add Delivery Charge',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Switch.adaptive(
                value: _deliveryEnabled,
                activeColor: AppColors.primary,
                onChanged: (v) {
                  AppHaptics.selection();
                  setState(() {
                    _isDeliveryManuallyToggled = true;
                    _deliveryEnabled = v;
                  });
                },
              ),
            ],
          ),
          if (_deliveryEnabled) ...[
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _deliveryCharge.toStringAsFixed(0),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Delivery Fee Amount',
                prefixText: '$currency ',
                prefixIcon: const Icon(Icons.edit_road_rounded, size: 18),
                isDense: true,
              ),
              onChanged: (v) {
                _isDeliveryManuallyToggled = true;
                setState(() =>
                    _deliveryCharge = math.max(0.0, double.tryParse(v) ?? 0));
              },
            ),
          ],
        ],
      ),
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
      if (dbItem != null && dbItem.marketPrice > 0) {
        final qtyInInvUnit = UnitConverter.convert(
          quantity: cartItem.quantity,
          fromUnit: cartItem.unit,
          toUnit: dbItem.unit,
        );
        final totalMarketCost = dbItem.marketPrice * qtyInInvUnit;
        final totalOrderCost = cartItem.total > 0 ? cartItem.total : (cartItem.price * cartItem.quantity);
        if (totalMarketCost > totalOrderCost) {
          marketSavings += (totalMarketCost - totalOrderCost);
        }
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
          _sumRow(
              'Subtotal', AppFormatters.currency(_subtotal, symbol: currency)),
          if (_discount > 0)
            _sumRow('Discount',
                '- ${AppFormatters.currency(_discount, symbol: currency)}',
                color: AppColors.success),
          if (_deliveryEnabled && _deliveryCharge > 0)
            _sumRow('Delivery',
                AppFormatters.currency(_deliveryCharge, symbol: currency)),
          if (_smartRound && SmartRounding.needsRounding(_unroundedGrandTotal))
            _sumRow(
                'Smart Rounded',
                AppFormatters.currency(_smartRounded - _unroundedGrandTotal,
                    symbol: currency),
                color: AppColors.warning),
          const Divider(height: 20),
          _sumRow('Grand Total',
              AppFormatters.currency(_grandTotal, symbol: currency),
              isBold: true, color: AppColors.primary),
          _sumRow('Paid', AppFormatters.currency(_paidAmount, symbol: currency),
              color: AppColors.success),
          if (_remaining > 0)
            _sumRow('Remaining Due',
                AppFormatters.currency(_remaining, symbol: currency),
                color: AppColors.error, isBold: true)
          else if (_remaining < 0)
            _sumRow('Advance Credit',
                AppFormatters.currency(_remaining.abs(), symbol: currency),
                color: Colors.teal, isBold: true),
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
                  Icon(
                    Icons.stars_rounded,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF34D399)
                        : Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are saving ${AppFormatters.currency(totalSavings, symbol: currency)} on this order!',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF34D399)
                            : Colors.green.shade800,
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
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.textSecondary)),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                    color: color ?? AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  // ── Payment section ──────────────────────────────────────────────────────────
  Widget _buildPaymentSection(String currency, AppSettings? settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customer = ref.watch(customerDetailProvider(widget.customerId)).valueOrNull;

    final paymentMethods = [
      {
        'id': AppConstants.paymentCash,
        'label': 'Cash',
        'icon': Icons.payments_rounded,
        'color': Colors.green
      },
      {
        'id': AppConstants.paymentUPI,
        'label': 'UPI / QR',
        'icon': Icons.qr_code_scanner_rounded,
        'color': Colors.purple
      },
      {
        'id': AppConstants.paymentKhata,
        'label': 'Khata',
        'icon': Icons.account_balance_wallet_rounded,
        'color': Colors.amber
      },
      {
        'id': 'online',
        'label': 'Card / Net',
        'icon': Icons.credit_card_rounded,
        'color': Colors.blue
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        // Segmented payment cards
        Row(
          children: paymentMethods.map((m) {
            final id = m['id'] as String;
            final label = m['label'] as String;
            final icon = m['icon'] as IconData;
            final color = m['color'] as MaterialColor;
            final isSelected = _paymentMethod == id;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () {
                    AppHaptics.selection();
                    setState(() => _paymentMethod = id);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: isDark
                                  ? [
                                      color.shade900.withOpacity(0.6),
                                      color.shade800.withOpacity(0.4)
                                    ]
                                  : [
                                      color.shade50,
                                      color.shade100.withOpacity(0.5)
                                    ],
                            )
                          : null,
                      color: !isSelected
                          ? (isDark
                              ? const Color(0xFF1E293B).withOpacity(0.4)
                              : AppColors.gray50)
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? color.shade600
                            : (isDark ? Colors.white12 : AppColors.gray300),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: isSelected
                              ? (isDark ? Colors.white : color.shade700)
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? (isDark ? Colors.white : color.shade800)
                                : (isDark
                                    ? Colors.white70
                                    : AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Paid amount text field
        TextFormField(
          controller: _paidCon,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Paid Amount',
            prefixText: '$currency ',
            prefixIcon: const Icon(Icons.payments_rounded),
          ),
          onChanged: (v) =>
              setState(() => _paidAmount = double.tryParse(v) ?? 0),
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
        if (customer != null && customer.outstandingBalance < 0) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              AppHaptics.selection();
              final advance = customer.outstandingBalance.abs();
              final settleAmt = math.min(_grandTotal, advance);
              setState(() {
                _paidAmount = settleAmt;
                _paidCon.text = settleAmt > 0 ? settleAmt.toStringAsFixed(2) : '';
                _paymentMethod = AppConstants.paymentCash;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Settle from Advance Credit ($currency${customer.outstandingBalance.abs().toStringAsFixed(2)})',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.teal),
                ],
              ),
            ),
          ),
        ],
        if (_paymentMethod == AppConstants.paymentOnline ||
            _paymentMethod == AppConstants.paymentUPI) ...[
          const SizedBox(height: 16),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Scan & Pay QR Code',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                        child: settings.qrCustomImage.startsWith('http')
                            ? Image.network(
                                settings.qrCustomImage,
                                width: 160,
                                height: 160,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Text('Broken Custom QR Image'),
                              )
                            : Image.file(
                                File(settings.qrCustomImage),
                                width: 160,
                                height: 160,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Text('Broken Custom QR Image'),
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
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textHint))
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

  void _showAddSpecificQuestionDialog() {
    AppHaptics.buttonClick();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Specific Question',
            style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: _AddSpecificQuestionForm(
          customerId: widget.customerId,
          onSaved: () {
            Navigator.pop(context);
            _loadQuestionsAndPreferences();
          },
        ),
      ),
    );
  }

  // ── Order Questions Section ───────────────────────────────────────────────────
  Widget _buildOrderQuestionsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.quiz_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Order Questions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  if (_questions.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_selectedAnswers.length}/${_questions.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.customerId.isNotEmpty) ...[
                    InkWell(
                      onTap: _showAddSpecificQuestionDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 2),
                            Text(
                              '+ Specific',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.lightBlueAccent : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  InkWell(
                    onTap: () async {
                      AppHaptics.buttonClick();
                      await Navigator.pushNamed(context, AppRoutes.orderQuestionsConfig);
                      _loadQuestionsAndPreferences();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.tune_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 2),
                          Text(
                            'Manage',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.lightBlueAccent : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_questions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.help_outline_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No order questions configured yet. Tap "Manage" to create reusable questions (e.g., Ripeness, Bag Type).',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      AppHaptics.buttonClick();
                      await Navigator.pushNamed(context, AppRoutes.orderQuestionsConfig);
                      _loadQuestionsAndPreferences();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Add Qs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else ...[
            ..._questions.map((q) {
              final selected = _selectedAnswers[q.id];
              final isSpecific = q.customerId != null && q.customerId!.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            q.question,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isSpecific)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Customer Specific',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: q.options.map((opt) {
                        final isOptSelected = selected == opt;
                        return ChoiceChip(
                          label: Text(
                            opt,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isOptSelected ? FontWeight.bold : FontWeight.normal,
                              color: isOptSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          selected: isOptSelected,
                          selectedColor: AppColors.primary,
                          onSelected: (val) {
                            AppHaptics.selection();
                            setState(() {
                              if (val) {
                                _selectedAnswers[q.id] = opt;
                              } else {
                                _selectedAnswers.remove(q.id);
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
        ],
      ),
    );
  }

  void _showVisualCartDrawer(BuildContext context, String currency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDrawerState) => Container(
          height: MediaQuery.of(context).size.height * 0.70,
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_bag_rounded,
                          color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Visual Mini-Cart (${_cart.length} items)',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _cart.length,
                  itemBuilder: (context, i) {
                    final item = _cart[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(
                          '${item.quantity} ${item.unit} x $currency${item.price.toStringAsFixed(2)}'),
                      trailing: Text(
                          '$currency${item.total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: !item.isAvailable ? TextDecoration.lineThrough : null,
                            color: !item.isAvailable ? Colors.grey : null,
                          )),
                    );
                  },
                ),
              ),
              const Divider(),
              Row(
                children: [
                  const Text('Quick Discount:',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 6,
                    children: [5.0, 10.0, 15.0].map((pct) {
                      return ChoiceChip(
                        label: Text('${pct.toInt()}%'),
                        selected: false,
                        onSelected: (_) {
                          final discAmt = (_subtotal * pct) / 100;
                          setState(() {
                            _discount = discAmt;
                            _discountCon.text = discAmt.toStringAsFixed(2);
                          });
                          setDrawerState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      'Grand Total: ${AppFormatters.currency(_grandTotal, symbol: currency)}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _saveOrder();
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white),
                    child: const Text('Confirm & Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            child: GestureDetector(
              onTap: () => _showVisualCartDrawer(context, currency),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                          'Total: ${AppFormatters.currency(_grandTotal, symbol: currency)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_up_rounded,
                          size: 18, color: AppColors.primary),
                    ],
                  ),
                  Text('${_cart.length} item(s) • Tap to view drawer',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _saving ? null : _saveOrder,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded),
            label: Text(_saving ? 'Saving...' : 'Save Order'),
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
    try {
      if (_saving) {
        return;
      }
      if (_cart.isEmpty) {
        SnackbarHelper.showError(context, 'Add at least one item');
        return;
      }

    final settingsVal = ref.read(settingsProvider).value;
    final discountCapPct = settingsVal?.workerDiscountCap ?? 10.0;
    final isWorker = ref.read(appModeProvider).valueOrNull == AppMode.worker;
    final enteredDiscountPct =
        _subtotal > 0 ? (_discount / _subtotal) * 100 : 0.0;
    if (isWorker && enteredDiscountPct > discountCapPct) {
      final pinOk = await OwnerPinDialog.verify(
        context,
        title: 'Discount Exceeds Limit',
        subtitle:
            'Discount of ${enteredDiscountPct.toStringAsFixed(1)}% exceeds worker cap of ${discountCapPct.toStringAsFixed(0)}%. Enter Owner PIN to approve:',
      );
      if (!pinOk) {
        if (mounted) {
          SnackbarHelper.showError(context,
              'Discount cap exceeded. Owner PIN authorization required.');
        }
        return;
      }
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

    // Collect all low-stock items into one batch warning
    final List<String> lowStockWarnings = [];
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

      double oldQtyBase = 0.0;
      if (_existingOrder != null) {
        final existingItem = _existingOrder!.items
            .cast<OrderItem>()
            .where((oi) => oi.itemId == cartItem.itemId)
            .firstOrNull;
        if (existingItem != null) {
          final oldQty = existingItem.quantity;
          oldQtyBase = UnitConverter.toBase(oldQty, existingItem.itemUnit);
        }
      }
      final double availableStockBase =
          UnitConverter.toBase(dbItem.stock, dbItem.unit) + oldQtyBase;
      final double requestedQtyBase =
          UnitConverter.toBase(cartItem.quantity, cartItem.unit);

      if (requestedQtyBase > availableStockBase) {
        lowStockWarnings.add(
          '• ${cartItem.name}: ${AppFormatters.quantity(dbItem.stock)} ${dbItem.unit} available, ${AppFormatters.quantity(cartItem.quantity)} ${cartItem.unit} requested',
        );
      }
    }

    if (lowStockWarnings.isNotEmpty) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text('Low Stock Warning',
                    style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lowStockWarnings.length} item(s) have insufficient stock:\n',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(lowStockWarnings.join('\n')),
                const SizedBox(height: 12),
                const Text(
                  'Do you want to save the order anyway?',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go Back'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) {
        debugPrint('[SaveOrder] BLOCKED: User declined low-stock warning');
        return;
      }
      debugPrint('[SaveOrder] User accepted low-stock warning, proceeding...');
    }

    debugPrint('[SaveOrder] All validations passed! Proceeding to save...');
    AppHaptics.primarySave();
    setState(() => _saving = true);

    final now = DateTime.now();
    final String generatedOrderNo = await OrderDao.generateUniqueOrderNo();
    final String orderId = widget.orderId ?? const Uuid().v4();
    final String orderNumberStr = (_existingOrder?.orderNumberStr.isNotEmpty == true)
        ? _existingOrder!.orderNumberStr
        : generatedOrderNo;
    debugPrint('[SaveOrder] orderId=$orderId, orderNumberStr=$orderNumberStr, widget.orderId=${widget.orderId}');

    final roundingDiff = _smartRound ? _smartRounded - _unroundedGrandTotal : 0;

    final List<OrderItem> items = [];
    if (_cart.isNotEmpty) {
      for (int i = 0; i < _cart.length; i++) {
        final c = _cart[i];
        items.add(OrderItem(
          id: const Uuid().v4(),
          orderId: orderId,
          itemId: c.itemId,
          itemName: c.name,
          itemUnit: c.unit,
          quantity: c.quantity,
          unitPrice: c.price,
          totalPrice: c.total,
          isAvailable: c.isAvailable,
        ));
      }
    }

    final adjustedSubtotal = double.parse(_subtotal.toStringAsFixed(2));

    double marketSavings = 0.0;
    for (final cartItem in _cart) {
      Item? dbItem;
      for (final item in inventoryList) {
        if (item.id == cartItem.itemId) {
          dbItem = item;
          break;
        }
      }
      if (dbItem != null && dbItem.marketPrice > 0) {
        final qtyInInvUnit = UnitConverter.convert(
          quantity: cartItem.quantity,
          fromUnit: cartItem.unit,
          toUnit: dbItem.unit,
        );
        final totalMarketCost = dbItem.marketPrice * qtyInInvUnit;
        final totalOrderCost = cartItem.total > 0 ? cartItem.total : (cartItem.price * cartItem.quantity);
        if (totalMarketCost > totalOrderCost) {
          marketSavings += (totalMarketCost - totalOrderCost);
        }
      }
    }
    final totalSavings = marketSavings + _discount;

    final order = AppOrder(
      id: orderId,
      customerId: widget.customerId,
      subtotal: adjustedSubtotal,
      discount: _discount,
      deliveryCharge: _deliveryEnabled ? _deliveryCharge : 0,
      smartRoundedAmount: roundingDiff.toDouble(),
      grandTotal: _grandTotal,
      paidAmount: _paidAmount,
      remainingAmount: _remaining,
      deliveryStatus: _existingOrder?.deliveryStatus ?? 'pending',
      notes: _noteCon.text.trim(),
      savings: totalSavings,
      createdAt: _existingOrder?.createdAt ?? now,
      updatedAt: now,
      assignedWorkerId: _existingOrder?.assignedWorkerId ?? '',
      createdBy: _existingOrder?.createdBy ?? 'owner',
      workerName: _existingOrder?.workerName ?? '',
      deviceName: _existingOrder?.deviceName ?? '',
      commissionRate: _existingOrder?.commissionRate ?? 0.0,
      commissionType: _existingOrder?.commissionType ?? '',
      orderNumber: _existingOrder?.orderNumber,
      orderNumberStr: orderNumberStr,
      orderType: _existingOrder?.orderType ?? 'Normal',
      orderTakingDate: _existingOrder?.orderTakingDate,
      deliveryDate: _existingOrder?.deliveryDate,
    );

    try {
      debugPrint('[SaveOrder] Calling createOrder...');
      await ref
          .read(orderManagementProvider.notifier)
          .createOrder(order, items);
      debugPrint('[SaveOrder] createOrder succeeded!');

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
        await OrderQuestionDao.instance
            .saveCustomerAnswer(widget.customerId, entry.key, entry.value);
      }
      await OrderQuestionDao.instance.saveOrderAnswers(orderId, orderAnsToSave);

      _orderSaved = true;
      debugPrint('[SaveOrder] Order answers saved. _orderSaved=true');

      // Add initial payment or adjust payment difference if editing
      if (widget.orderId != null && _existingOrder != null) {
        final double diff = _paidAmount - _existingOrder!.paidAmount;
        debugPrint('[SaveOrder] Edit mode: payment diff=$diff');
        if (diff != 0) {
          await ref.read(orderManagementProvider.notifier).addPayment(Payment(
                id: const Uuid().v4(),
                orderId: orderId,
                customerId: widget.customerId,
                amount: diff,
                method: _paymentMethod,
                notes: diff < 0
                    ? 'Adjustment: Paid amount decreased'
                    : 'Adjustment: Additional payment',
                createdAt: now,
              ));
        }
      } else if (widget.orderId == null && _paidAmount > 0) {
        await ref.read(orderManagementProvider.notifier).addPayment(Payment(
              id: const Uuid().v4(),
              orderId: orderId,
              customerId: widget.customerId,
              amount: _paidAmount,
              method: _paymentMethod,
              notes: 'Initial payment',
              createdAt: now,
            ));
      }

      // Persist last delivery charge
      ref
          .read(settingsProvider.notifier)
          .updateLastDeliveryCharge(_deliveryCharge);

      // Clear the saved cart provider
      ref.read(createOrderCartProvider(widget.customerId).notifier).state = [];

      debugPrint('[SaveOrder] About to navigate. mounted=$mounted, widget.orderId=${widget.orderId}');
      if (!mounted) return;

      // Invalidate Customer & Order Providers
      ref.invalidate(customerOrdersProvider(widget.customerId));
      ref.invalidate(customerDetailProvider(widget.customerId));
      ref.invalidate(orderDetailProvider(orderId));
      ref.invalidate(customerOrdersProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(allCustomersProvider);
      ref.invalidate(pendingCustomersProvider);
      ref.invalidate(overpaidCustomersProvider);

      // Invalidate & Refresh Inventory & Stock Providers
      ref.invalidate(inventoryProvider);
      ref.invalidate(lowStockProvider);
      ref.invalidate(outOfStockProvider);
      ref.invalidate(stockSummaryProvider);
      ref.invalidate(stockHistoryProvider);
      ref.invalidate(orderedItemStatsProvider);
      try {
        ref.read(inventoryProvider.notifier).load(silent: true);
      } catch (_) {}

      // Invalidate & Refresh Dashboard & Analytics Providers
      ref.invalidate(analyticsSummaryProvider);
      ref.invalidate(todaysDetailedReportProvider);
      ref.invalidate(dashboardOrdersProvider);
      ref.invalidate(weeklyChartProvider);
      ref.invalidate(monthlyChartProvider);
      ref.invalidate(profitLossProvider);
      ref.invalidate(customerSavingsProvider);
      ref.invalidate(orderManagementProvider);
      try {
        ref.read(orderManagementProvider.notifier).load(silent: true);
      } catch (_) {}

      if (widget.orderId != null) {
        ref.invalidate(orderDetailProvider(widget.orderId!));
        debugPrint('[SaveOrder] Edit mode: popping screen with result=true');
        Navigator.of(context).pop(true);
      } else {
        debugPrint('[SaveOrder] New order: navigating to order detail');
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.orderDetail,
          arguments: {'orderId': orderId},
        );
      }
    } catch (e, st) {
      debugPrint('[SaveOrder] ERROR: $e');
      debugPrint('[SaveOrder] STACK: $st');
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save order: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    } catch (outerError, outerStack) {
      // Catch ANY unhandled error from the entire function including pre-validation
      debugPrint('[SaveOrder] OUTER ERROR: $outerError');
      debugPrint('[SaveOrder] OUTER STACK: $outerStack');
      if (mounted) {
        SnackbarHelper.showError(context, 'Unexpected error: $outerError');
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _quickReorderPreviousOrder() async {
    try {
      AppHaptics.itemAdded();
      final orders = await ref
          .read(orderRepositoryProvider)
          .getAllOrders(customerId: widget.customerId);

      List<OrderItem> items = [];
      if (orders.isNotEmpty) {
        for (final o in orders) {
          final oItems = await OrderDao().getOrderItems(o.id);
          if (oItems.isNotEmpty) {
            items = oItems;
            break;
          }
        }
      }

      final inventoryList = ref.read(inventoryProvider).valueOrNull ??
          await ref.read(inventoryRepositoryProvider).getAllItems();

      if (items.isEmpty) {
        final topFavs =
            await OrderDao().getCustomerTopOrderedItems(widget.customerId);
        if (topFavs.isNotEmpty) {
          final List<CartItem> newCartItems = [];
          final List<String> skippedOos = [];
          final List<String> adjustedQty = [];

          for (final fav in topFavs) {
            final itemId = fav['item_id']?.toString() ?? '';
            final itemName = fav['item_name']?.toString() ?? 'Item';
            final itemUnit = fav['item_unit']?.toString() ?? 'kg';
            final dbItem =
                inventoryList.where((i) => i.id == itemId).firstOrNull;

            double maxStock = dbItem?.stock ?? 0.0;
            if (dbItem != null) {
              final conversion =
                  dbItem.weightPerPiece > 0 ? dbItem.weightPerPiece : 1.0;
              if (dbItem.unit == 'kg' && itemUnit == 'gram') {
                maxStock = dbItem.stock * 1000.0;
              } else if (dbItem.unit == 'kg' && itemUnit == 'piece') {
                maxStock = dbItem.stock / conversion;
              } else if (dbItem.unit == 'piece' && itemUnit == 'dozen') {
                maxStock = dbItem.stock / 12.0;
              } else if (dbItem.unit == 'piece' && itemUnit == 'kg') {
                maxStock = dbItem.stock * conversion;
              }
            }

            if (dbItem != null && maxStock < 0.001) {
              skippedOos.add(itemName);
              continue;
            }

            // Prefer current live inventory price over historic price from past orders
            double unitPrice = (dbItem != null && dbItem.sellingPrice > 0)
                ? dbItem.sellingPrice
                : ((fav['unit_price'] as num?)?.toDouble() ??
                    (fav['selling_price'] as num?)?.toDouble() ??
                    0.0);

            double requestedQty = (fav['avg_qty'] as num?)?.toDouble() ?? 1.0;
            if (requestedQty <= 0) requestedQty = 1.0;

            if (dbItem != null && requestedQty > maxStock) {
              adjustedQty.add(
                  '$itemName (${AppFormatters.quantity(maxStock)} $itemUnit)');
              requestedQty = maxStock;
            }

            newCartItems.add(CartItem(
              itemId: itemId,
              name: itemName,
              unit: itemUnit,
              price: unitPrice,
              quantity: requestedQty,
            ));
          }

          if (newCartItems.isEmpty) {
            if (mounted) {
              SnackbarHelper.showError(context,
                  'All top favorite items are currently OUT OF STOCK.');
            }
            return;
          }

          setState(() {
            _cart.clear();
            _cart.addAll(newCartItems);
          });

          if (mounted) {
            if (skippedOos.isNotEmpty || adjustedQty.isNotEmpty) {
              final msgs = <String>[];
              if (skippedOos.isNotEmpty) {
                msgs.add(
                    'Skipped ${skippedOos.length} out-of-stock items (${skippedOos.join(", ")})');
              }
              if (adjustedQty.isNotEmpty) {
                msgs.add('Adjusted to available stock: ${adjustedQty.join(", ")}');
              }
              SnackbarHelper.showWarning(context, msgs.join('. '));
            } else {
              SnackbarHelper.showSuccess(context,
                  '⚡ Added ${newCartItems.length} previous items to cart');
            }
          }
          return;
        }

        if (mounted) {
          SnackbarHelper.showInfo(context,
              'No previous order items found for ${widget.customerName}');
        }
        return;
      }

      final List<CartItem> newCartItems = [];
      final List<String> skippedOos = [];
      final List<String> adjustedQty = [];

      for (final it in items) {
        final dbItem =
            inventoryList.where((i) => i.id == it.itemId).firstOrNull;

        double maxStock = dbItem?.stock ?? 0.0;
        if (dbItem != null) {
          final conversion =
              dbItem.weightPerPiece > 0 ? dbItem.weightPerPiece : 1.0;
          if (dbItem.unit == 'kg' && it.itemUnit == 'gram') {
            maxStock = dbItem.stock * 1000.0;
          } else if (dbItem.unit == 'kg' && it.itemUnit == 'piece') {
            maxStock = dbItem.stock / conversion;
          } else if (dbItem.unit == 'piece' && it.itemUnit == 'dozen') {
            maxStock = dbItem.stock / 12.0;
          } else if (dbItem.unit == 'piece' && it.itemUnit == 'kg') {
            maxStock = dbItem.stock * conversion;
          }
        }

        if (dbItem != null && maxStock < 0.001) {
          skippedOos.add(it.itemName);
          continue;
        }

        // Prefer current live inventory price over historic price from past orders
        double unitPrice = (dbItem != null && dbItem.sellingPrice > 0)
            ? dbItem.sellingPrice
            : it.unitPrice;

        double requestedQty = it.quantity;
        if (requestedQty <= 0) requestedQty = 0.25;

        if (dbItem != null && requestedQty > maxStock) {
          adjustedQty.add(
              '${it.itemName} (${AppFormatters.quantity(maxStock)} ${it.itemUnit})');
          requestedQty = maxStock;
        }

        newCartItems.add(CartItem(
          itemId: it.itemId,
          name: it.itemName,
          unit: it.itemUnit,
          price: unitPrice,
          quantity: requestedQty,
        ));
      }

      if (newCartItems.isEmpty) {
        if (mounted) {
          SnackbarHelper.showError(context,
              'All items from previous order are currently OUT OF STOCK.');
        }
        return;
      }

      setState(() {
        _cart.clear();
        _cart.addAll(newCartItems);
      });

      if (mounted) {
        if (skippedOos.isNotEmpty || adjustedQty.isNotEmpty) {
          final msgs = <String>[];
          if (skippedOos.isNotEmpty) {
            msgs.add(
                'Skipped ${skippedOos.length} out-of-stock items (${skippedOos.join(", ")})');
          }
          if (adjustedQty.isNotEmpty) {
            msgs.add('Adjusted to available stock: ${adjustedQty.join(", ")}');
          }
          SnackbarHelper.showWarning(context, msgs.join('. '));
        } else {
          SnackbarHelper.showSuccess(context,
              '⚡ Reordered ${newCartItems.length} items from previous order');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to reorder: $e');
      }
    }
  }


  void _showFamilySwitcherSheet(BuildContext context, List<Customer> families) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.family_restroom_rounded, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text(
                    'Family Quick Switcher (Same House)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Switch this order or duplicate the same item basket for another family living in this house:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Divider(height: 20),
              ...families.map((f) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE0E7FF),
                        child: Icon(Icons.person_rounded, color: Colors.indigo),
                      ),
                      title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(f.phone1.isNotEmpty ? f.phone1 : 'House #${f.houseNumber}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.createOrder,
                                arguments: {
                                  'customerId': f.id,
                                  'customerName': f.name,
                                },
                              );
                            },
                            child: const Text('Switch'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.pushNamed(
                                context,
                                AppRoutes.createOrder,
                                arguments: {
                                  'customerId': f.id,
                                  'customerName': f.name,
                                },
                              );
                              SnackbarHelper.showSuccess(
                                context,
                                'Opened new basket for ${f.name}',
                              );
                            },
                            child: const Text('Copy Basket'),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemSelectorWidget(
        customerId: widget.customerId,
        currentCartCount: _cart.length,
        currentCartTotal: _subtotal,
        cartItems: _cart,
        onItemSelected: (item, qty, price) {
          final stockInBase = UnitConverter.toBase(item.stock, item.unit);
          if (stockInBase < 0.001 || item.stock < 0.001) {
            SnackbarHelper.showError(
              context,
              '"${item.name}" is OUT OF STOCK (0 ${item.unit} available) and cannot be added.',
            );
            return;
          }
          if (qty <= 0) {
            SnackbarHelper.showError(
              context,
              'Quantity must be greater than 0.',
            );
            return;
          }

          setState(() {
            double unitPrice = price > 0 ? price : item.sellingPrice;
            if (price == item.sellingPrice) {
              final customer =
                  ref.read(customerDetailProvider(widget.customerId)).value;
              final settings = ref.read(settingsProvider).valueOrNull;
              final enableMarkup = settings?.enableVipPriceMarkup ?? true;
              if (enableMarkup &&
                  customer != null &&
                  customer.isVipActive &&
                  customer.vipMarkupPct > 0) {
                unitPrice = double.parse(
                    (item.sellingPrice * (1 + (customer.vipMarkupPct / 100)))
                        .toStringAsFixed(2));
              }
            }

            final existing = _cart.indexWhere((c) => c.itemId == item.id);
            if (existing >= 0) {
              final cartItem = _cart[existing];
              final existingQtyInAddedUnit = UnitConverter.convert(
                quantity: cartItem.quantity,
                fromUnit: cartItem.unit,
                toUnit: item.unit,
              );
              final newTotalInAddedUnit = existingQtyInAddedUnit + qty;
              final newTotalInBase =
                  UnitConverter.toBase(newTotalInAddedUnit, item.unit);
              final stockInBase = UnitConverter.toBase(item.stock, item.unit);

              if (newTotalInBase > stockInBase) {
                SnackbarHelper.showError(
                  context,
                  'Cannot add more "${item.name}". Stock limit is ${AppFormatters.quantity(item.stock)} ${item.unit}',
                );
                return;
              }
              _cart[existing] = cartItem.copyWith(
                quantity: newTotalInAddedUnit,
                unit: item.unit,
                price: unitPrice,
              );
            } else {
              final qtyInBase = UnitConverter.toBase(qty, item.unit);
              final stockInBase = UnitConverter.toBase(item.stock, item.unit);
              if (qtyInBase > stockInBase) {
                SnackbarHelper.showError(
                  context,
                  'Cannot add ${AppFormatters.quantity(qty)} ${item.unit} of "${item.name}". Stock limit is ${AppFormatters.quantity(item.stock)} ${item.unit}',
                );
                return;
              }

              _cart.add(CartItem(
                itemId: item.id,
                name: item.name,
                unit: item.unit,
                price: unitPrice,
                quantity: qty,
              ));
            }
          });
        },
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rxColor = isDark ? const Color(0xFFF87171) : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rxColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rxColor.withOpacity(0.18), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: rxColor),
              const SizedBox(width: 8),
              Text(
                'Prescription Required (Rx)',
                style: TextStyle(fontWeight: FontWeight.bold, color: rxColor),
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
            title: Text(
              'Doctor Prescription Verified physically',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: rxColor),
            ),
            value: _rxVerified,
            onChanged: (val) {
              if (val != null) {
                AppHaptics.buttonClick();
                setState(() => _rxVerified = val);
              }
            },
            activeColor: rxColor,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }
}

// ── Cart item tile ────────────────────────────────────────────────────────────
class _CartItemTile extends StatelessWidget {
  final CartItem cartItem;
  final Item? dbItem;
  final String currency;
  final ValueChanged<double> onQtyChanged;
  final VoidCallback onRemove;
  final bool canToggleUnit;
  final ValueChanged<String>? onUnitChanged;
  final VoidCallback? onToggleAvailable;

  const _CartItemTile({
    required this.cartItem,
    this.dbItem,
    required this.currency,
    required this.onQtyChanged,
    required this.onRemove,
    this.canToggleUnit = false,
    this.onUnitChanged,
    this.onToggleAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    double maxStock = dbItem?.stock ?? 999999.0;
    if (dbItem != null) {
      maxStock = UnitConverter.convert(
        quantity: dbItem!.stock,
        fromUnit: dbItem!.unit,
        toUnit: cartItem.unit,
      );
    }

    final isOutOfStock = (dbItem != null && dbItem!.stock < 0.001);
    final exceedsStock = cartItem.quantity > maxStock && !isOutOfStock;
    final isLowStock = (dbItem != null && dbItem!.isLowStock && !isOutOfStock);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOutOfStock
            ? (isDark ? Colors.red.withOpacity(0.12) : Colors.red.withOpacity(0.06))
            : exceedsStock
                ? (isDark ? Colors.red.withOpacity(0.08) : Colors.red.withOpacity(0.04))
                : (isDark
                    ? const Color(0xFF1E293B).withOpacity(0.4)
                    : AppColors.gray50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOutOfStock || exceedsStock
              ? AppColors.error.withOpacity(0.6)
              : isLowStock
                  ? Colors.orange.withOpacity(0.5)
                  : (isDark ? Colors.white.withOpacity(0.12) : AppColors.gray200),
          width: isOutOfStock || exceedsStock ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cartItem.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: isOutOfStock ? TextDecoration.lineThrough : null,
                            ),
                      ),
                    ),
                    if (isOutOfStock)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'OUT OF STOCK',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      )
                    else if (exceedsStock)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.error.withOpacity(0.4)),
                        ),
                        child: Text(
                          'Exceeds Stock (${AppFormatters.quantity(maxStock)} max)',
                          style: const TextStyle(color: AppColors.error, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      )
                    else if (isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.withOpacity(0.4)),
                        ),
                        child: Text(
                          'Low Stock: ${AppFormatters.quantity(dbItem!.stock)} ${dbItem!.unit}',
                          style: const TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
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
                        icon: const Icon(Icons.arrow_drop_down_rounded,
                            size: 16, color: AppColors.primary),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                        items: {
                          cartItem.unit,
                          ...AppConstants.itemUnits,
                        }
                            .map((u) => DropdownMenuItem(
                                  value: u,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Text(u),
                                  ),
                                ))
                            .toList(),
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
            quantity: cartItem.quantity,
            maxStock: maxStock,
            onChanged: onQtyChanged,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48),
            child: Text(
              '$currency${cartItem.total.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
            ),
          ),
          if (onToggleAvailable != null)
            IconButton(
              tooltip: cartItem.isAvailable ? 'Mark as Unavailable' : 'Mark as Available',
              icon: Icon(
                cartItem.isAvailable ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                size: 18,
                color: cartItem.isAvailable ? Colors.amber.shade800 : Colors.green,
              ),
              onPressed: onToggleAvailable,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 4),
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.error),
            onPressed: onRemove,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(left: 4),
          ),
        ],
      ),
    );
  }
}

class _QtyPicker extends StatefulWidget {
  final double quantity;
  final double maxStock;
  final ValueChanged<double> onChanged;
  const _QtyPicker({
    required this.quantity,
    this.maxStock = double.infinity,
    required this.onChanged,
  });

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
    if (widget.quantity != _qty) {
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
      width: 82,
      child: TextField(
        controller: _ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          suffixIcon: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  final nextQty =
                      double.parse((_qty + 0.25).toStringAsFixed(2));
                  if (nextQty <= widget.maxStock) {
                    setState(() {
                      _qty = nextQty;
                      _ctrl.text = AppFormatters.quantity(_qty);
                      widget.onChanged(_qty);
                    });
                  } else if (_qty < widget.maxStock) {
                    setState(() {
                      _qty = widget.maxStock;
                      _ctrl.text = AppFormatters.quantity(_qty);
                      widget.onChanged(_qty);
                    });
                  }
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
            final clamped = parsed > widget.maxStock ? widget.maxStock : parsed;
            _qty = clamped;
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

  const _AddSpecificQuestionForm(
      {required this.customerId, required this.onSaved});

  @override
  State<_AddSpecificQuestionForm> createState() =>
      _AddSpecificQuestionFormState();
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
    final options = _optionCons
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

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
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter question text'
                  : null,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Options:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: AppColors.primary),
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
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter option text'
                            : null,
                      ),
                    ),
                    if (_optionCons.length > 1) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent),
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
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  onPressed: _submit,
                  child:
                      const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
