import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// StatusDotBadge — Modern status badge with glowing live status dots
class StatusDotBadge extends StatelessWidget {
  final String status;
  final bool showLabel;
  final TextStyle? textStyle;

  const StatusDotBadge({
    super.key,
    required this.status,
    this.showLabel = true,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color color;
    String label;
    bool shouldPulse = false;

    switch (normalized) {
      case 'delivered':
        color = const Color(0xFF10B981); // Emerald Green
        label = 'Delivered';
        break;
      case 'cancelled':
        color = const Color(0xFFEF4444); // Crimson Red
        label = 'Cancelled';
        break;
      case 'pending':
      default:
        color = const Color(0xFFF59E0B); // Amber Orange
        label = 'Pending';
        shouldPulse = true;
        break;
    }

    Widget dotWidget = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 6,
            spreadRadius: 1.5,
          ),
        ],
      ),
    );

    if (shouldPulse) {
      dotWidget = dotWidget
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(0.85, 0.85),
            end: const Offset(1.15, 1.15),
            duration: 900.ms,
          )
          .fadeIn(begin: 0.5, duration: 900.ms);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dotWidget,
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: textStyle ??
                  TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
