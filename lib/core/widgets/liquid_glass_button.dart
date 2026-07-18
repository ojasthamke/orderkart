import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class LiquidGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final bool animate;

  const LiquidGlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.width,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.borderRadius,
    this.boxShadow,
    this.animate = true,
  });

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.bounceOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null && widget.animate) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null && widget.animate) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null && widget.animate) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.borderRadius ?? BorderRadius.circular(16);

    Widget buttonBody = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: widget.boxShadow ??
            [
              BoxShadow(
                color: AppColors.primary.withOpacity(isDark ? 0.30 : 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              )
            ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              gradient: isDark ? AppColors.glassGradientDark : AppColors.glassGradientLight,
              borderRadius: r,
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.white60,
                width: 1.5,
              ),
            ),
            child: Center(
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    if (widget.onTap == null) return buttonBody;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: buttonBody,
      ),
    );
  }
}
