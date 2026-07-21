/// StatCard — Reusable metric card for dashboard and analytics
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color? surfaceColor;
  final VoidCallback? onTap;
  final String? subtitle;
  final String? trendText;
  final Color? trendColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.surfaceColor,
    this.onTap,
    this.subtitle,
    this.trendText,
    this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = surfaceColor ?? color.withOpacity(0.10);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor(context)),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Row(
                  children: [
                    if (trendText != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: (trendColor ?? color).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (trendColor ?? color).withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          trendText!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: trendColor ?? color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (onTap != null)
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 12, color: AppColors.gray400),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimaryColor(context),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryColor(context),
                    fontWeight: FontWeight.w500,
                  ),
            ),
            if (subtitle != null) ...[  
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.2);
  }
}
