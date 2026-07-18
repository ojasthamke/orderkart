import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/smart_rounding.dart';

class SmartRoundBanner extends StatelessWidget {
  final double original;
  final double rounded;
  final bool   enabled;
  final String currency;
  final ValueChanged<bool> onToggle;

  const SmartRoundBanner({
    super.key,
    required this.original,
    required this.rounded,
    required this.enabled,
    required this.currency,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerBg = isDark ? Colors.orange.shade900.withOpacity(0.15) : AppColors.warningSurface;
    final borderCol = isDark ? Colors.orange.shade300.withOpacity(0.3) : AppColors.warning.withOpacity(0.3);
    final accentCol = isDark ? Colors.orange.shade300 : AppColors.warning;
    final subTextCol = isDark ? Colors.white70 : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_fix_high_rounded,
              color: accentCol, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Rounding',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accentCol,
                      ),
                ),
                Text(
                  SmartRounding.label(original, rounded, currency),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subTextCol,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value:     enabled,
            onChanged: onToggle,
            activeColor: accentCol,
          ),
        ],
      ),
    );
  }
}
