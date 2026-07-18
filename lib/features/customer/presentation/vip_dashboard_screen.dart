import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/vip_glow_avatar.dart';
import '../../../core/widgets/glass_container.dart';
import '../domain/customer.dart';
import 'customer_provider.dart';

class VipDashboardScreen extends ConsumerStatefulWidget {
  const VipDashboardScreen({super.key});

  @override
  ConsumerState<VipDashboardScreen> createState() => _VipDashboardScreenState();
}

class _VipDashboardScreenState extends ConsumerState<VipDashboardScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'active', 'expiring', 'expired'
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(allCustomersProvider);

    return AppScaffold(
      title: 'VIP Memberships',
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Search VIP Members',
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.search),
        ),
        IconButton(
          icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700)),
          onPressed: () => _showAddEditVipDialog(context),
        ),
      ],
      body: customersAsync.when(
        loading: () => const LoadingShimmer(),
        error: (err, _) => Center(child: Text('Error loading VIP data: $err')),
        data: (allCustomers) {
          // Filter VIP customers
          final vipList = allCustomers.where((c) => c.isVip || c.isVipActive).toList();
          final activeVip = vipList.where((c) => c.isVipActive).toList();
          final expiringVip = vipList.where((c) => c.isVipExpiringSoon).toList();
          final expiredVip = vipList.where((c) => c.isVip && !c.isVipActive).toList();

          double totalSubscriptionIncome = 0;
          for (final c in vipList) {
            totalSubscriptionIncome += c.vipSubscriptionFee;
          }

          // Apply UI Filters
          var filteredList = vipList.where((c) {
            if (_selectedFilter == 'active' && !c.isVipActive) return false;
            if (_selectedFilter == 'expiring' && !c.isVipExpiringSoon) return false;
            if (_selectedFilter == 'expired' && c.isVipActive) return false;

            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              return c.name.toLowerCase().contains(q) ||
                  c.phone1.contains(q) ||
                  c.vipPlan.toLowerCase().contains(q);
            }
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(allCustomersProvider),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── VIP Executive Header Card ──────────────────────────
                      GlassContainer(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        borderRadius: BorderRadius.circular(24),
                        color: const Color(0xFF0F172A).withOpacity(0.75),
                        borderColor: const Color(0xFFFFD700).withOpacity(0.4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 28),
                                    SizedBox(width: 10),
                                    Text(
                                      'VIP CLUB DASHBOARD',
                                      style: TextStyle(
                                        color: Color(0xFFFFD700),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _showAddEditVipDialog(context),
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('Add VIP'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFD700),
                                    foregroundColor: const Color(0xFF0F172A),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // KPI Grid Inside Header
                            Row(
                              children: [
                                _kpiItem('ACTIVE MEMBERS', '${activeVip.length}', Colors.greenAccent),
                                _kpiItem('EXPIRING SOON', '${expiringVip.length}', Colors.amberAccent),
                                _kpiItem('MEMBERSHIP INCOME', AppFormatters.currency(totalSubscriptionIncome), Colors.lightBlueAccent),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Search & Filter Chips ─────────────────────────────
                      GlassContainer(
                        borderRadius: BorderRadius.circular(16),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search VIP members by name, phone, plan...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip('all', 'All (${vipList.length})'),
                            _filterChip('active', 'Active (${activeVip.length})'),
                            _filterChip('expiring', 'Expiring Soon (${expiringVip.length})'),
                            _filterChip('expired', 'Expired (${expiredVip.length})'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                    ]),
                  ),
                ),
                if (filteredList.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Icon(Icons.workspace_premium_rounded, size: 64, color: AppColors.gray400),
                              const SizedBox(height: 12),
                              Text(
                                vipList.isEmpty ? 'No VIP Members Yet' : 'No matching VIP members found',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Upgrade loyal customers to VIP to grant free delivery & custom discounts.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _showAddEditVipDialog(context),
                                icon: const Icon(Icons.stars_rounded),
                                label: const Text('Add First VIP Customer'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final customer = filteredList[i];
                          return _buildVipCustomerCard(context, customer);
                        },
                        childCount: filteredList.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kpiItem(String title, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final selected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        selectedColor: const Color(0xFFFFD700).withOpacity(0.2),
        checkmarkColor: const Color(0xFFB45309),
        onSelected: (_) => setState(() => _selectedFilter = key),
      ),
    );
  }

  Widget _buildVipCustomerCard(BuildContext context, Customer customer) {
    final isExpiring = customer.isVipExpiringSoon;
    final isActive = customer.isVipActive;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(20),
      borderColor: isActive
          ? const Color(0xFFFFD700).withOpacity(0.7)
          : (Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                VipGlowAvatar(
                  photoPath: customer.photoPath,
                  isVip: isActive,
                  radius: 26,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            softWrap: true,
                          ),
                          const SizedBox(height: 6),
                          VipGoldBadgeChip(planName: customer.vipPlan),
                          const SizedBox(height: 6),
                          if (customer.phone1.isNotEmpty)
                            Text(
                              'Phone: ${customer.phone1}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          if (customer.address.isNotEmpty)
                            Text(
                              'Address: ${customer.address}',
                              style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                              softWrap: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showAddEditVipDialog(context, existing: customer);
                    } else if (val == 'renew') {
                      _renewMembership(customer);
                    } else if (val == 'cancel') {
                      _cancelMembership(customer);
                    } else if (val == 'profile') {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.customerProfile,
                        arguments: {'customerId': customer.id},
                      );
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'profile', child: Text('View Profile')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit VIP Benefits')),
                    const PopupMenuItem(value: 'renew', child: Text('Renew (+30 Days)')),
                    const PopupMenuItem(value: 'cancel', child: Text('Cancel VIP Membership', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Started: ${customer.vipStartDate.isNotEmpty ? AppFormatters.dateFromString(customer.vipStartDate) : "N/A"}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                Text(
                  'Expires: ${customer.vipExpiryDate.isNotEmpty ? AppFormatters.dateFromString(customer.vipExpiryDate) : "N/A"}',
                  style: TextStyle(
                    fontSize: 11, 
                    color: isActive ? AppColors.textSecondary : Colors.red,
                    fontWeight: isActive ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Benefits Tags & Expiry info
            Row(
              children: [
                if (customer.vipFreeDelivery)
                  _benefitBadge('Free Delivery', Icons.local_shipping_rounded, Colors.green),
                if (customer.vipDiscountPct > 0)
                  _benefitBadge('${customer.vipDiscountPct.toStringAsFixed(0)}% Off', Icons.discount_rounded, Colors.amber),
                if (customer.vipMarkupPct > 0)
                  _benefitBadge('+${customer.vipMarkupPct.toStringAsFixed(0)}% Price Adjusted', Icons.balance_rounded, Colors.purple),
                const Spacer(),
                Text(
                  isActive
                      ? (isExpiring
                          ? 'Expires in ${customer.daysUntilVipExpiry} days'
                          : 'Active Member')
                      : 'Expired',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isActive ? (isExpiring ? Colors.orange : Colors.green) : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefitBadge(String label, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  // ── Renew VIP Membership ───────────────────────────────────────────────
  Future<void> _renewMembership(Customer customer) async {
    final now = DateTime.now();
    final currentExpiry = customer.vipExpiryDate.isNotEmpty
        ? (DateTime.tryParse(customer.vipExpiryDate) ?? now)
        : now;
    final baseDate = currentExpiry.isAfter(now) ? currentExpiry : now;

    final start = DateTime.tryParse(customer.vipStartDate);
    final expiry = DateTime.tryParse(customer.vipExpiryDate);
    int planDays = 30;
    if (start != null && expiry != null) {
      final diff = expiry.difference(start).inDays;
      if (diff > 0) planDays = diff;
    }

    final newExpiry = baseDate.add(Duration(days: planDays)).toIso8601String();

    final updated = customer.copyWith(
      isVip: true,
      vipExpiryDate: newExpiry,
      vipStartDate: customer.vipStartDate.isEmpty ? now.toIso8601String() : customer.vipStartDate,
    );

    await ref.read(customerListProvider(updated.streetId).notifier).update(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renewed VIP Membership for ${customer.name} by $planDays days!')),
      );
    }
  }

  // ── Cancel VIP Membership ──────────────────────────────────────────────
  Future<void> _cancelMembership(Customer customer) async {
    final updated = customer.copyWith(
      isVip: false,
      vipPlan: '',
      vipStartDate: '',
      vipExpiryDate: '',
      vipSubscriptionFee: 0.0,
      vipNotes: '',
      vipAutoRenewal: false,
      vipFreeDelivery: false,
      vipDiscountPct: 0.0,
      vipMarkupPct: 0.0,
      vipPriorityDelivery: false,
    );
    await ref.read(customerListProvider(updated.streetId).notifier).update(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cancelled VIP Membership for ${customer.name}')),
      );
    }
  }

  // ── Add/Edit VIP Dialog ────────────────────────────────────────────────
  void _showAddEditVipDialog(BuildContext context, {Customer? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VipEditModal(existingCustomer: existing),
    );
  }
}

class VipEditModal extends ConsumerStatefulWidget {
  final Customer? existingCustomer;
  const VipEditModal({super.key, this.existingCustomer});

  @override
  ConsumerState<VipEditModal> createState() => VipEditModalState();
}

class VipEditModalState extends ConsumerState<VipEditModal> {
  Customer? _selectedCustomer;
  String _plan = 'Gold VIP';
  double _fee = 499.0;
  double _discountPct = 10.0;
  double _markupPct = 5.0;
  bool _freeDelivery = true;
  bool _priorityDelivery = true;
  int _durationDays = 365;
  bool _autoRenewal = false;
  final _notesCon = TextEditingController();
  String _customerSearch = '';
  final _customerSearchCon = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));

  @override
  void initState() {
    super.initState();
    if (widget.existingCustomer != null) {
      _selectedCustomer = widget.existingCustomer;
      _plan = widget.existingCustomer!.vipPlan.isNotEmpty ? widget.existingCustomer!.vipPlan : 'Gold VIP';
      _fee = widget.existingCustomer!.vipSubscriptionFee;
      _discountPct = widget.existingCustomer!.vipDiscountPct;
      _markupPct = widget.existingCustomer!.vipMarkupPct;
      _freeDelivery = widget.existingCustomer!.vipFreeDelivery;
      _priorityDelivery = widget.existingCustomer!.vipPriorityDelivery;
      _autoRenewal = widget.existingCustomer!.vipAutoRenewal;
      _notesCon.text = widget.existingCustomer!.vipNotes;
      if (widget.existingCustomer!.vipStartDate.isNotEmpty) {
        _startDate = DateTime.tryParse(widget.existingCustomer!.vipStartDate) ?? DateTime.now();
      }
      if (widget.existingCustomer!.vipExpiryDate.isNotEmpty) {
        _expiryDate = DateTime.tryParse(widget.existingCustomer!.vipExpiryDate) ?? DateTime.now().add(const Duration(days: 365));
        _durationDays = _expiryDate.difference(_startDate).inDays;
      }
    }
  }

  @override
  void dispose() {
    _customerSearchCon.dispose();
    _notesCon.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _expiryDate = picked.add(Duration(days: _durationDays));
      });
    }
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate.isAfter(_startDate) ? _expiryDate : _startDate.add(const Duration(days: 1)),
      firstDate: _startDate.add(const Duration(days: 1)),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
        _durationDays = _expiryDate.difference(_startDate).inDays;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(allCustomersProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 28),
                const SizedBox(width: 10),
                Text(
                  widget.existingCustomer == null ? 'Upgrade Customer to VIP' : 'Edit VIP Benefits',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Select Customer if new
            if (widget.existingCustomer == null) ...[
              const Text('Search & Select Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _customerSearchCon,
                decoration: InputDecoration(
                  hintText: 'Search by name or phone...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: _customerSearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _customerSearchCon.clear();
                            setState(() => _customerSearch = '');
                          },
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _customerSearch = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              if (_selectedCustomer != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFFB45309), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedCustomer!.name}  •  ${_selectedCustomer!.phone1}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _selectedCustomer = null),
                        child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              customersAsync.when(
                data: (list) {
                  final filtered = _customerSearch.isEmpty
                      ? <Customer>[]
                      : list.where((c) {
                          return c.name.toLowerCase().contains(_customerSearch) ||
                              c.phone1.contains(_customerSearch);
                        }).take(8).toList();
                  if (filtered.isEmpty && _customerSearch.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('No customers found for "$_customerSearch"',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final c = filtered[i];
                      final isSelected = _selectedCustomer?.id == c.id;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCustomer = c;
                            _customerSearch = '';
                            _customerSearchCon.clear();
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFFD700).withOpacity(0.15)
                                : Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFFFD700) : AppColors.gray200,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded, size: 18, color: AppColors.textSecondary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('${c.name}  •  ${c.phone1}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_rounded, size: 18, color: Color(0xFFB45309)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 16),
            ],

            // Membership Plan Name
            TextFormField(
              initialValue: _plan,
              decoration: const InputDecoration(
                labelText: 'Membership Plan Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _plan = v,
            ),
            const SizedBox(height: 12),

            // Subscription Fee & Duration
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _fee.toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Subscription Fee (₹)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _fee = double.tryParse(v) ?? 0.0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: [30, 90, 180, 365].contains(_durationDays) ? _durationDays : null,
                    decoration: const InputDecoration(
                      labelText: 'Preset Duration',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 30, child: Text('1 Month')),
                      DropdownMenuItem(value: 90, child: Text('3 Months')),
                      DropdownMenuItem(value: 180, child: Text('6 Months')),
                      DropdownMenuItem(value: 365, child: Text('1 Year')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _durationDays = v;
                          _expiryDate = _startDate.add(Duration(days: v));
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date selection system (Start Date / Expiry Date)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectStartDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                      ),
                      child: Text(
                        AppFormatters.date(_startDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _selectExpiryDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Expiry Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event_busy_rounded, size: 18),
                      ),
                      child: Text(
                        AppFormatters.date(_expiryDate),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Text('Configurable Benefits & Pricing Adjustment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),

            // Discount Preset Selector
            Wrap(
              spacing: 8,
              children: [5.0, 10.0, 15.0, 20.0].map((d) {
                final selected = _discountPct == d;
                return ChoiceChip(
                  label: Text('${d.toStringAsFixed(0)}% Off'),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _discountPct = d;
                    // Auto set custom markup based on formula (markup = discount / 2)
                    _markupPct = d / 2;
                  }),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Price Markup adjustment setting
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item Price Adjustment: +${_markupPct.toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.purple, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'App item prices will adjust by +5% or +10% so actual realization matches business margin while receipt displays full VIP discount.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Toggles
            SwitchListTile(
              title: const Text('Free Delivery Included'),
              subtitle: const Text('Waive all delivery charges on orders'),
              value: _freeDelivery,
              onChanged: (v) => setState(() => _freeDelivery = v),
            ),
            SwitchListTile(
              title: const Text('Priority Delivery Handling'),
              subtitle: const Text('Mark VIP orders as high priority'),
              value: _priorityDelivery,
              onChanged: (v) => setState(() => _priorityDelivery = v),
            ),
            SwitchListTile(
              title: const Text('Auto-Renew Membership'),
              subtitle: const Text('Automatically renew subscription at expiry'),
              value: _autoRenewal,
              onChanged: (v) => setState(() => _autoRenewal = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCon,
              decoration: const InputDecoration(
                labelText: 'VIP Membership Notes',
                hintText: 'Enter preferences, terms, or special conditions...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_alt_rounded),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 20),

            // Save Button
            ElevatedButton(
              onPressed: _saveVip,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: const Color(0xFF0F172A),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('SAVE VIP MEMBERSHIP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveVip() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }

    final updated = _selectedCustomer!.copyWith(
      isVip: true,
      vipPlan: _plan,
      vipStartDate: _startDate.toIso8601String(),
      vipExpiryDate: _expiryDate.toIso8601String(),
      vipSubscriptionFee: _fee,
      vipDiscountPct: _discountPct,
      vipMarkupPct: _markupPct,
      vipFreeDelivery: _freeDelivery,
      vipPriorityDelivery: _priorityDelivery,
      vipNotes: _notesCon.text.trim(),
      vipAutoRenewal: _autoRenewal,
    );

    await ref.read(customerListProvider(updated.streetId).notifier).update(updated);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('VIP Membership active for ${_selectedCustomer!.name}!')),
      );
    }
  }
}
