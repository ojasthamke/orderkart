import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final Color? color;
  final bool enableBlur;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.borderColor,
    this.color,
    this.enableBlur = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = borderRadius ?? BorderRadius.circular(16);

    final innerContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        gradient: color == null
            ? (isDark
                ? AppColors.glassGradientDark
                : AppColors.glassGradientLight)
            : null,
        borderRadius: r,
        border: Border.all(
          color: borderColor ?? (isDark ? Colors.white30 : Colors.white70),
          width: 1.5,
        ),
      ),
      child: RepaintBoundary(
        child: child,
      ),
    );

    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: (isDark ? Colors.white : Colors.black)
                  .withOpacity(isDark ? 0.03 : 0.02),
              blurRadius: 1,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: r,
          child: enableBlur
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: innerContent,
                )
              : innerContent,
        ),
      ),
    );
  }
}
