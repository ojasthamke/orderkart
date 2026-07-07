import 'package:flutter/material.dart';

class SmartBusinessPulseWidget extends StatelessWidget {
  final double todaySales;
  final double salesGrowthPct;
  final double pendingDues;
  final double totalRevenue;
  final int inStockCount;
  final int lowStockCount;
  final int outOfStockCount;
  final VoidCallback? onCreateOrder;
  final VoidCallback? onViewInventory;

  const SmartBusinessPulseWidget({
    super.key,
    required this.todaySales,
    required this.salesGrowthPct,
    required this.pendingDues,
    required this.totalRevenue,
    required this.inStockCount,
    required this.lowStockCount,
    required this.outOfStockCount,
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

    final isGrowthPositive = salesGrowthPct >= 0;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: Color(0xFF38BDF8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'BUSINESS PULSE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              // Growth Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isGrowthPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444))
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isGrowthPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGrowthPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: isGrowthPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isGrowthPositive ? '+' : ''}${salesGrowthPct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: isGrowthPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
