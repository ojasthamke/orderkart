import 'dart:ui';
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
  final double monthlySales;
  final double cashReceived;
  final double onlineReceived;
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
    required this.monthlySales,
    required this.cashReceived,
    required this.onlineReceived,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColors = isDark 
        ? [const Color(0xFF1E293B).withOpacity(0.65), const Color(0xFF0F172A).withOpacity(0.35)]
        : [Colors.white.withOpacity(0.85), Colors.white.withOpacity(0.50)];
    final shadowColor = isDark ? const Color(0xFF0F172A).withOpacity(0.40) : Colors.black.withOpacity(0.08);
    final borderColor = isDark ? Colors.white30 : Colors.white70;

    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMainColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondaryColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final textMutedColor = isDark ? Colors.white54 : const Color(0xFF64748B);
    final dividerColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.06);

    final subCardBg = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02);
    final subCardBorder = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);

    final accentColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.03 : 0.02),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: bgColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
            ),
            child: RepaintBoundary(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Row ──────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.analytics_rounded,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'FEATURE STATISTICS',
                      style: TextStyle(
                        color: textSecondaryColor,
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
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Today's Net Realized Revenue",
                  style: TextStyle(
                    color: textMutedColor,
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
                        Text(
                          'Stock Health Ratio',
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$inStockCount In Stock · $lowStockCount Low · $outOfStockCount Out',
                          style: TextStyle(
                            color: textMutedColor,
                            fontSize: 11,
                          ),
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
                        Text(
                          'Collection Progress',
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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
                      backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.08),
                      color: accentColor,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Divider(color: dividerColor, height: 1),
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
                        cardBg: subCardBg,
                        cardBorder: subCardBorder,
                        titleColor: textMutedColor,
                        valueColor: textMainColor,
                        subtitleColor: textMutedColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        title: 'Monthly Volume',
                        value: '₹${monthlySales.toStringAsFixed(0)}',
                        subtitle: 'This Month\'s Sales',
                        icon: Icons.calendar_month_outlined,
                        iconColor: const Color(0xFFF59E0B),
                        cardBg: subCardBg,
                        cardBorder: subCardBorder,
                        titleColor: textMutedColor,
                        valueColor: textMainColor,
                        subtitleColor: textMutedColor.withOpacity(0.7),
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
                        cardBg: subCardBg,
                        cardBorder: subCardBorder,
                        titleColor: textMutedColor,
                        valueColor: textMainColor,
                        subtitleColor: textMutedColor.withOpacity(0.7),
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
                        cardBg: subCardBg,
                        cardBorder: subCardBorder,
                        titleColor: textMutedColor,
                        valueColor: textMainColor,
                        subtitleColor: textMutedColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        title: 'Cash / Online Ratio',
                        value: '₹${cashReceived.toStringAsFixed(0)} / ₹${onlineReceived.toStringAsFixed(0)}',
                        subtitle: 'Payment Breakup',
                        icon: Icons.account_balance_wallet_outlined,
                        iconColor: const Color(0xFFA855F7),
                        cardBg: subCardBg,
                        cardBorder: subCardBorder,
                        titleColor: textMutedColor,
                        valueColor: textMainColor,
                        subtitleColor: textMutedColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        title: 'Active Customers',
                        value: '$customerCount',
                        subtitle: 'Total Registered',
                        icon: Icons.people_outline_rounded,
                        iconColor: const Color(0xFFEC4899),
                        cardBg: subCardBg,
                        cardBorder: subCardBorder,
                        titleColor: textMutedColor,
                        valueColor: textMainColor,
                        subtitleColor: textMutedColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Divider(color: dividerColor, height: 1),
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
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onViewInventory,
                      icon: Icon(Icons.inventory_2_rounded, size: 16, color: textSecondaryColor),
                      label: Text('Inventory', style: TextStyle(color: textSecondaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: subCardBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        foregroundColor: textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color cardBg,
    required Color cardBorder,
    required Color titleColor,
    required Color valueColor,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
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
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
