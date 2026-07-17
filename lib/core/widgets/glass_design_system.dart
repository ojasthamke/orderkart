import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reusable Glass Container mapping to Apple's Frosted Material specs.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final Color? color;
  final double blurSigma;

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
    this.blurSigma = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = borderRadius ?? BorderRadius.circular(20);
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (color ?? (isDark ? const Color(0xFF1E293B) : Colors.white))
                      .withOpacity(isDark ? 0.55 : 0.80),
                  (color ?? (isDark ? const Color(0xFF0F172A) : Colors.white))
                      .withOpacity(isDark ? 0.30 : 0.45),
                ],
              ),
              border: Border.all(
                color: borderColor ??
                    (isDark
                        ? Colors.white.withOpacity(0.18)
                        : Colors.black.withOpacity(0.12)),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Frosted Capsule Button with Apple-style spring press compression animation.
class GlassButton extends StatefulWidget {
  final Widget label;
  final VoidCallback? onPressed;
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final Color? color;

  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.width,
    this.height = 50,
    this.borderRadius,
    this.color,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GlassContainer(
          width: widget.width,
          height: widget.height,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(25),
          color: widget.color,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(child: widget.label),
        ),
      ),
    );
  }
}

/// Floating glass card container.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: padding ?? const EdgeInsets.all(18),
      margin: margin,
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      color: color,
      child: child,
    );
  }
}

/// Frosted Floating Action Button.
class GlassFAB extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const GlassFAB({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassButton(
      width: 60,
      height: 60,
      borderRadius: BorderRadius.circular(30),
      color: color,
      onPressed: onPressed,
      label: Icon(icon, color: AppColors.primary, size: 24),
    );
  }
}

/// Glass Search Bar Capsule with focus glow.
class GlassSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hintText;
  final VoidCallback? onVoicePressed;

  const GlassSearchBar({
    super.key,
    required this.onChanged,
    this.hintText = 'Search...',
    this.onVoicePressed,
  });

  @override
  State<GlassSearchBar> createState() => _GlassSearchBarState();
}

class _GlassSearchBarState extends State<GlassSearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.20),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: GlassContainer(
        height: 52,
        borderRadius: BorderRadius.circular(25),
        borderColor: _isFocused ? AppColors.primary.withOpacity(0.5) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                focusNode: _focusNode,
                onChanged: widget.onChanged,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (widget.onVoicePressed != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.mic_rounded, color: AppColors.primary),
                onPressed: widget.onVoicePressed,
              )
            ]
          ],
        ),
      ),
    );
  }
}

/// Frosted Filter Chip.
class GlassChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const GlassChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        borderRadius: BorderRadius.circular(15),
        color: isSelected ? AppColors.primary.withOpacity(0.25) : null,
        borderColor: isSelected ? AppColors.primary.withOpacity(0.5) : null,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Frosted Toggle Switch.
class GlassSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const GlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 32,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: value
              ? AppColors.primary.withOpacity(0.3)
              : (isDark ? Colors.white10 : Colors.black12),
          border: Border.all(
            color: value ? AppColors.primary.withOpacity(0.5) : Colors.transparent,
          ),
        ),
        child: AlignmentCard(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: GlassContainer(
            width: 24,
            height: 24,
            borderRadius: BorderRadius.circular(12),
            color: value ? AppColors.primary : (isDark ? Colors.grey.shade400 : Colors.white),
            padding: EdgeInsets.zero,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class AlignmentCard extends StatelessWidget {
  final Alignment alignment;
  final Widget child;

  const AlignmentCard({super.key, required this.alignment, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: child,
    );
  }
}

/// Frosted Range Slider track indicator.
class GlassSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;

  const GlassSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.primary.withOpacity(0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayColor: AppColors.primary.withOpacity(0.15),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    );
  }
}

/// Frosted Segmented Control slider pill.
class GlassSegmentedControl<T> extends StatelessWidget {
  final Map<T, String> children;
  final T selectedValue;
  final ValueChanged<T> onValueChanged;

  const GlassSegmentedControl({
    super.key,
    required this.children,
    required this.selectedValue,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(4),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: children.entries.map((entry) {
          final isSelected = entry.key == selectedValue;
          return Expanded(
            child: GestureDetector(
              onTap: () => onValueChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected ? AppColors.primary.withOpacity(0.20) : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Frosted input form field configuration.
class GlassFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  const GlassFormField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      borderRadius: BorderRadius.circular(16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.textSecondary) : null,
          border: InputBorder.none,
        ),
      ),
    );
  }
}

/// Frosted circular loading indicator.
class GlassLoadingIndicator extends StatelessWidget {
  const GlassLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassContainer(
        width: 80,
        height: 80,
        borderRadius: BorderRadius.circular(40),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            strokeWidth: 3.5,
          ),
        ),
      ),
    );
  }
}

/// Frosted linear progress bar.
class GlassProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0

  const GlassProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      height: 10,
      borderRadius: BorderRadius.circular(5),
      padding: EdgeInsets.zero,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Glass Map circular control.
class GlassMapControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const GlassMapControl({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        width: 46,
        height: 46,
        borderRadius: BorderRadius.circular(23),
        padding: EdgeInsets.zero,
        child: Center(
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}

/// Frosted overlay banner widget.
class GlassBanner extends StatelessWidget {
  final String title;
  final String message;
  final IconData? icon;

  const GlassBanner({
    super.key,
    required this.title,
    required this.message,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
