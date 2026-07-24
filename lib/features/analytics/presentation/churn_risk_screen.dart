import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/utils/formatters.dart';

class ChurnRiskScreen extends ConsumerStatefulWidget {
  const ChurnRiskScreen({super.key});

  @override
  ConsumerState<ChurnRiskScreen> createState() => _ChurnRiskScreenState();
}

class _ChurnRiskScreenState extends ConsumerState<ChurnRiskScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allProfiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT 
          c.id, 
          c.name, 
          c.phone1 AS phone, 
          c.is_vip,
          (
            SELECT MAX(created_at) 
            FROM orders 
            WHERE customer_id = c.id AND delivery_status != 'cancelled'
          ) as last_order_date,
          (
            SELECT SUM(grand_total)
            FROM orders
            WHERE customer_id = c.id AND delivery_status != 'cancelled'
          ) as lifetime_value,
          (
            SELECT COUNT(id)
            FROM orders
            WHERE customer_id = c.id AND delivery_status != 'cancelled'
          ) as order_count
        FROM customers c
        WHERE c.is_archived = 0
      ''');

      final now = DateTime.now();
      final List<Map<String, dynamic>> processed = [];

      for (final r in rows) {
        final lastOrderStr = r['last_order_date'] as String?;
        int daysSince = 999; // Default if never ordered
        if (lastOrderStr != null) {
          final lastDate = DateTime.tryParse(lastOrderStr);
          if (lastDate != null) {
            daysSince = now.difference(lastDate).inDays;
          }
        }

        double riskScore = 0.0;
        String riskLevel = 'Low';
        Color statusColor = AppColors.success;
        double recommendedDiscountPct = 5.0;

        if (daysSince > 45) {
          riskScore = 0.9;
          riskLevel = 'High';
          statusColor = AppColors.error;
          recommendedDiscountPct = 15.0;
        } else if (daysSince > 30) {
          riskScore = 0.6;
          riskLevel = 'Medium';
          statusColor = Colors.orange;
          recommendedDiscountPct = 10.0;
        } else {
          riskScore = 0.2;
          riskLevel = 'Low';
          statusColor = AppColors.success;
          recommendedDiscountPct = 5.0;
        }

        // Calculate a reasonable flat discount amount based on average order value
        final double ltv = (r['lifetime_value'] as num?)?.toDouble() ?? 0.0;
        final int orders = (r['order_count'] as num?)?.toInt() ?? 0;
        final double aov =
            orders > 0 ? (ltv / orders) : 500.0; // fallback to 500
        final double promoAmount =
            (aov * (recommendedDiscountPct / 100)).clamp(20.0, 500.0);

        processed.add({
          'id': r['id'],
          'name': r['name'],
          'phone': r['phone'] ?? '',
          'is_vip': (r['is_vip'] as num?)?.toInt() == 1,
          'last_order_date': lastOrderStr,
          'days_since': daysSince,
          'lifetime_value': ltv,
          'order_count': orders,
          'risk_level': riskLevel,
          'risk_score': riskScore,
          'status_color': statusColor,
          'discount_pct': recommendedDiscountPct,
          'promo_amount': promoAmount,
        });
      }

      // Sort by risk days descending
      processed.sort(
          (a, b) => (b['days_since'] as int).compareTo(a['days_since'] as int));

      if (mounted) {
        setState(() {
          _allProfiles = processed;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _shareWhatsAppPromo(Map<String, dynamic> customer) async {
    final phone = customer['phone'] as String;
    if (phone.isEmpty) {
      SnackbarHelper.showError(
          context, 'No phone number registered for this customer');
      return;
    }

    final String missingTag = customer['days_since'] == 999
        ? "to try our fresh products"
        : "since you last ordered (${customer['days_since']} days ago)";

    final text = Uri.encodeComponent("Hello ${customer['name']}!\n\n"
        "We miss having you around at OrderKart $missingTag. "
        "Here is a special retention promo of ₹${(customer['promo_amount'] as double).toStringAsFixed(0)} off "
        "on your next purchase with us!\n\n"
        "Reply back to place your order now! 🛒");

    final urlStr = "https://wa.me/$phone?text=$text";
    final url = Uri.parse(urlStr);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        SnackbarHelper.showError(
            context, 'Could not open WhatsApp for this link');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        title: 'Smart Churn Analytics',
        body: LoadingShimmer(),
      );
    }

    final highRiskList =
        _allProfiles.where((p) => p['risk_level'] == 'High').toList();
    final mediumRiskList =
        _allProfiles.where((p) => p['risk_level'] == 'Medium').toList();
    final lowRiskList =
        _allProfiles.where((p) => p['risk_level'] == 'Low').toList();

    return AppScaffold(
      title: 'Smart Churn Analytics',
      bottom: TabBar(
        controller: _tabController,
        tabs: [
          Tab(text: 'High Risk (${highRiskList.length})'),
          Tab(text: 'Medium Risk (${mediumRiskList.length})'),
          Tab(text: 'Low Risk (${lowRiskList.length})'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfiles,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildProfileList(highRiskList),
            _buildProfileList(mediumRiskList),
            _buildProfileList(lowRiskList),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.check_circle_outline_rounded,
        title: 'All Safe!',
        subtitle: 'No customers match this risk category currently.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final p = list[index];
        final days =
            p['days_since'] == 999 ? 'Never' : '${p['days_since']} days';
        final isVip = p['is_vip'] as bool;

        return GlassContainer(
          margin: const EdgeInsets.only(bottom: 12),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              (p['status_color'] as Color).withOpacity(0.12),
                          child: Icon(
                            isVip ? Icons.stars_rounded : Icons.person_rounded,
                            color: p['status_color'] as Color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Phone: ${p['phone']}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryColor(context)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (p['status_color'] as Color).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Risk: ${p['risk_level']}',
                        style: TextStyle(
                          color: p['status_color'] as Color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Last Ordered',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryColor(context))),
                        const SizedBox(height: 2),
                        Text(days,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LTV',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryColor(context))),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.currency(p['lifetime_value']),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Promo Discount',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryColor(context))),
                        const SizedBox(height: 2),
                        Text(
                          '₹${(p['promo_amount'] as double).toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.success),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('WhatsApp Promotion',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () => _shareWhatsAppPromo(p),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon:
                            const Icon(Icons.shopping_basket_rounded, size: 16),
                        label: const Text('Apply & Order',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.createOrder,
                            arguments: {
                              'customerId': p['id'],
                              'customerName': p['name'],
                              'orderId': null,
                              'initialDiscount': p['promo_amount'],
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
