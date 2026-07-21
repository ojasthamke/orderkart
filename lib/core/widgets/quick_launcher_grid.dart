import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_routes.dart';
import '../utils/haptics.dart';
import 'glass_container.dart';
import 'scale_on_tap.dart';

class _LauncherItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;

  const _LauncherItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class QuickLauncherGrid extends StatelessWidget {
  const QuickLauncherGrid({super.key});

  static const List<_LauncherItem> _items = [
    _LauncherItem(
      title: 'Order Quantity',
      icon: Icons.inventory_2_rounded,
      color: Color(0xFF10B981),
      route: AppRoutes.inventory,
    ),
    _LauncherItem(
      title: 'P & L',
      icon: Icons.analytics_rounded,
      color: Color(0xFF8B5CF6),
      route: AppRoutes.analytics,
    ),
    _LauncherItem(
      title: 'Quick Rates',
      icon: Icons.edit_note_rounded,
      color: Color(0xFF14B8A6),
      route: AppRoutes.quickInventoryAdjust,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final item = _items[i];
        return ScaleOnTap(
          onTap: () {
            AppHaptics.buttonClick();
            Navigator.of(context).pushNamed(item.route);
          },
          child: GlassContainer(
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: item.color.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
