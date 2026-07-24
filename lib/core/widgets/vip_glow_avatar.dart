import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'customer_avatar.dart';

class VipGlowAvatar extends StatelessWidget {
  final String photoPath;
  final bool isVip;
  final double radius;
  final VoidCallback? onTap;

  const VipGlowAvatar({
    super.key,
    required this.photoPath,
    required this.isVip,
    this.radius = 24.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVip) {
      return GestureDetector(
        onTap: onTap,
        child: CustomerAvatar(photoPath: photoPath, radius: radius),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Soft Glowing Gold Outer Ring ────────────────────────────────
          Container(
            width: (radius * 2) + 10,
            height: (radius * 2) + 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0xFFFFD700), // Gold
                  Color(0xFFFFA500), // Amber Gold
                  Colors.transparent,
                ],
                stops: [0.4, 0.8, 1.0],
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.05, 1.05),
                  duration: 1500.ms)
              .boxShadow(
                begin: BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.3),
                    blurRadius: 6,
                    spreadRadius: 0),
                end: BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.7),
                    blurRadius: 16,
                    spreadRadius: 3),
                duration: 1500.ms,
              ),

          // ── Main Customer Avatar ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
            ),
            child: CustomerAvatar(photoPath: photoPath, radius: radius),
          ),

          // ── Gold Crown Badge ─────────────────────────────────────────
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black38, blurRadius: 4),
                ],
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFFFD700),
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VipGoldBadgeChip extends StatelessWidget {
  final String planName;
  const VipGoldBadgeChip({super.key, this.planName = 'VIP'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Color(0xFF0F172A), size: 12),
          const SizedBox(width: 3),
          Text(
            planName.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
