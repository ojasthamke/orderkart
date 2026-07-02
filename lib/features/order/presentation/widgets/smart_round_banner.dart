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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_fix_high_rounded,
              color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Rounding',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                ),
                Text(
                  SmartRounding.label(original, rounded, currency),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value:     enabled,
            onChanged: onToggle,
            activeColor: AppColors.warning,
          ),
        ],
      ),
    );
  }
}
