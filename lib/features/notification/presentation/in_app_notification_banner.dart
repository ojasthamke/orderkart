import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';

class InAppNotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;
  final bool enableSound;
  final bool enableVibration;

  const InAppNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    this.onTap,
    required this.onDismiss,
    this.enableSound = true,
    this.enableVibration = true,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String body,
    required String category,
    VoidCallback? onTap,
    bool enableSound = true,
    bool enableVibration = true,
  }) {
    final overlayState = Navigator.of(context).overlay;
    if (overlayState == null) return;

    late OverlayEntry overlayEntry;

    IconData icon;
    Color color;
    switch (category) {
      case 'payment_due':
        icon = Icons.payment_rounded;
        color = Colors.redAccent;
        break;
      case 'low_stock':
        icon = Icons.inventory_2_rounded;
        color = Colors.orangeAccent;
        break;
      case 'order_update':
        icon = Icons.local_shipping_rounded;
        color = Colors.green;
        break;
      case 'sync':
        icon = Icons.sync_rounded;
        color = Colors.blueAccent;
        break;
      default:
        icon = Icons.notifications_active_rounded;
        color = AppColors.primary;
    }

    overlayEntry = OverlayEntry(
      builder: (context) {
        return InAppNotificationBanner(
          title: title,
          body: body,
          icon: icon,
          color: color,
          onTap: onTap,
          enableSound: enableSound,
          enableVibration: enableVibration,
          onDismiss: () {
            try {
              overlayEntry.remove();
            } catch (_) {}
          },
        );
      },
    );

    overlayState.insert(overlayEntry);
  }

  @override
  State<InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _controller.forward();

    // Trigger Sound/Vibration
    if (widget.enableVibration) {
      AppHaptics.primarySave();
    }
    if (widget.enableSound) {
      SystemSound.play(SystemSoundType.click);
    }

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      _dismiss();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top + 12;

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: GestureDetector(
          onTap: () {
            _dismissTimer?.cancel();
            if (widget.onTap != null) {
              widget.onTap!();
            }
            _dismiss();
          },
          onPanUpdate: (details) {
            if (details.delta.dy < -5) {
              _dismissTimer?.cancel();
              _dismiss();
            }
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E293B).withOpacity(0.95)
                    : Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: widget.color.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.body,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: widget.color.withOpacity(0.6),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
