import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../constants/app_routes.dart';
import '../utils/haptics.dart';
import '../../features/settings/presentation/settings_provider.dart';
import 'glass_container.dart';
import 'scale_on_tap.dart';

class _LauncherItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  final bool isGroceries;

  const _LauncherItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
    this.isGroceries = false,
  });
}

class QuickLauncherGrid extends ConsumerWidget {
  const QuickLauncherGrid({super.key});

  static const List<_LauncherItem> _items = [
    _LauncherItem(
      title: 'Vegetables',
      icon: Icons.eco_rounded,
      color: Color(0xFF10B981),
      route: AppRoutes.inventory,
    ),
    _LauncherItem(
      title: 'Groceries',
      icon: Icons.local_grocery_store_rounded,
      color: Color(0xFF059669),
      route: AppRoutes.groceriesHub,
      isGroceries: true,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGrocOpen = ref.watch(groceriesStatusProvider).valueOrNull ?? true;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.90,
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
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
                    if (item.isGroceries)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isGrocOpen
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 10.5,
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
