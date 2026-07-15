import 'package:flutter/material.dart';

class SmartBusinessPulseWidget extends StatelessWidget {
  final double todaySales;
  final double pendingDues;
  final double totalRevenue;
  final int inStockCount;
  final int lowStockCount;
  final int outOfStockCount;
  final int customerCount;
  final int vipCount;
  final int deliveredCount;
  final int pendingCount;
  final double todayExpenses;
  final int todayOrdersCount;
  final VoidCallback? onCreateOrder;
  final VoidCallback? onViewInventory;

  const SmartBusinessPulseWidget({
    super.key,
    required this.todaySales,
    required this.pendingDues,
    required this.totalRevenue,
    required this.inStockCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.customerCount,
    required this.vipCount,
    required this.deliveredCount,
    required this.pendingCount,
    required this.todayExpenses,
    required this.todayOrdersCount,
    this.onCreateOrder,
    this.onViewInventory,
  });

  @override
  Widget build(BuildContext context) {
    final totalItems = (inStockCount + lowStockCount + outOfStockCount).clamp(1, 999999);
    final inStockPct = inStockCount / totalItems;
    final lowStockPct = lowStockCount / totalItems;
    final outStockPct = outOfStockCount / totalItems;
    final collectionPct = totalRevenue > 0
        ? ((totalRevenue - pendingDues) / totalRevenue).clamp(0.0, 1.0)
        : 1.0;

    final totalOrdersCount = deliveredCount + pendingCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ──────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Color(0xFF38BDF8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'FEATURE STATISTICS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Today's Sales Counter ────────────────────────────────
          Text(
            '₹${todaySales.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            "Today's Net Realized Revenue",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 20),

          // ── Segment 1: Inventory Health Bar ──────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Stock Health Ratio',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$inStockCount In Stock · $lowStockCount Low · $outOfStockCount Out',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      if (inStockPct > 0)
                        Expanded(
                          flex: (inStockPct * 100).toInt().clamp(1, 100),
                          child: Container(color: const Color(0xFF22C55E)),
                        ),
                      if (lowStockPct > 0)
                        Expanded(
                          flex: (lowStockPct * 100).toInt().clamp(1, 100),
                          child: Container(color: const Color(0xFFF59E0B)),
                        ),
                      if (outStockPct > 0)
                        Expanded(
                          flex: (outStockPct * 100).toInt().clamp(1, 100),
                          child: Container(color: const Color(0xFFEF4444)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Segment 2: Collection Rate Meter ────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Collection Progress',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${(collectionPct * 100).toStringAsFixed(0)}% Realized (₹${pendingDues.toStringAsFixed(0)} Pending)',
                    style: TextStyle(
                      color: pendingDues > 0 ? const Color(0xFFF87171) : const Color(0xFF4ADE80),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: collectionPct,
                backgroundColor: Colors.white10,
                color: const Color(0xFF38BDF8),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),

          // ── Segment 3: Deep Feature Statistics Grid ─────────────
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Success Rate',
                  value: totalOrdersCount > 0
                      ? '${(deliveredCount / totalOrdersCount * 100).toStringAsFixed(1)}%'
                      : '0.0%',
                  subtitle: '$deliveredCount Completed',
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  title: 'VIP Members',
                  value: '$vipCount / $customerCount',
                  subtitle: 'Loyalty Count',
                  icon: Icons.star_outline_rounded,
                  iconColor: const Color(0xFFFFD700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Avg Order Value',
                  value: todayOrdersCount > 0
                      ? '₹${(todaySales / todayOrdersCount).toStringAsFixed(1)}'
                      : '₹0.0',
                  subtitle: '$todayOrdersCount Orders Today',
                  icon: Icons.shopping_bag_outlined,
                  iconColor: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  title: 'Today\'s Expenses',
                  value: '₹${todayExpenses.toStringAsFixed(1)}',
                  subtitle: 'Total Outflow',
                  icon: Icons.payments_outlined,
                  iconColor: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),

          // ── Quick Action Bar ────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCreateOrder,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: const Text('New Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onViewInventory,
                icon: const Icon(Icons.inventory_2_rounded, size: 16, color: Colors.white70),
                label: const Text('Inventory', style: TextStyle(color: Colors.white70, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, color: iconColor, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
