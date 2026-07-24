import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../area_map_provider.dart';
import '../../../location/domain/location.dart';

class LocationContextBanner extends ConsumerStatefulWidget {
  final String areaId;

  const LocationContextBanner({
    super.key,
    required this.areaId,
  });

  @override
  ConsumerState<LocationContextBanner> createState() =>
      _LocationContextBannerState();
}

class _LocationContextBannerState extends ConsumerState<LocationContextBanner> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final sectionState = ref.watch(currentSectionProvider(widget.areaId));

    if (sectionState.currentLocation == null) {
      return const SizedBox.shrink();
    }

    final loc = sectionState.currentLocation!;
    final breadcrumbStr =
        sectionState.breadcrumbs.map((b) => b.name).join(' → ');

    return AnimatedCrossFade(
      firstChild: _buildCollapsedBanner(loc, sectionState),
      secondChild: _buildExpandedBanner(loc, breadcrumbStr, sectionState),
      crossFadeState:
          _isCollapsed ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      duration: const Duration(milliseconds: 250),
    );
  }

  Widget _buildCollapsedBanner(Location loc, CurrentSectionState state) {
    return GestureDetector(
      onTap: () => setState(() => _isCollapsed = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Colors.blueAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  loc.name,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.white38,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${state.pendingDeliveries} deliveries',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white54, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedBanner(
      Location loc, String breadcrumbStr, CurrentSectionState state) {
    return GestureDetector(
      onTap: () => setState(() => _isCollapsed = true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.72),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.pin_drop_rounded,
                              color: Colors.blueAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Inside: ${loc.name}',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_up_rounded,
                        color: Colors.white70, size: 18),
                  ],
                ),
                if (breadcrumbStr.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    breadcrumbStr,
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Divider(color: Colors.white.withOpacity(0.12), height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildMiniBadge(
                      icon: Icons.people_outline_rounded,
                      label: '${state.customerCount} Customers',
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(width: 16),
                    _buildMiniBadge(
                      icon: Icons.shopping_bag_outlined,
                      label: '${state.pendingDeliveries} Pending Deliveries',
                      color: Colors.orangeAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.85),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
