import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return Drawer(
      backgroundColor: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.inventory_2_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'OrderKart',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                children: [
                  _SectionHeader(title: 'MAIN'),
                  _DrawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    onTap: () => Navigator.pop(context),
                  ),
                  _DrawerItem(
                    icon: Icons.people_alt_rounded,
                    title: 'Customers',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.customers);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.workspace_premium_rounded,
                    title: 'VIP Membership Club',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.vipDashboard);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.shopping_cart_rounded,
                    title: 'Orders & Sales',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.orderManagement);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.inventory_rounded,
                    title: 'Inventory & Stock',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.inventory);
                    },
                  ),

                  // ── Quick Access ─────────────────────────────────────
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                    child: Divider(height: 1),
                  ),
                  _SectionHeader(title: 'QUICK ACCESS'),
                  _DrawerItem(
                    icon: Icons.map_rounded,
                    title: 'Areas & Streets',
                    iconColor: const Color(0xFF0EA5E9),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.areas);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.receipt_long_rounded,
                    title: 'Expenses',
                    iconColor: const Color(0xFFD97706),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.expenses);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.note_alt_rounded,
                    title: 'Notes & Reminders',
                    iconColor: const Color(0xFF8B5CF6),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.notes);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.search_rounded,
                    title: 'Global Search',
                    iconColor: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.search);
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                    child: Divider(height: 1),
                  ),

                  _SectionHeader(title: 'MANAGEMENT & ROUTES'),
                  _DrawerItem(
                    icon: Icons.map_rounded,
                    title: 'Areas & Streets',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.areas);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.alt_route_rounded,
                    title: 'Visits & Route Plan',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.visits);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.receipt_long_rounded,
                    title: 'Expenses',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.expenses);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.note_alt_rounded,
                    title: 'Notes & Reminders',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.notes);
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                    child: Divider(height: 1),
                  ),

                  _SectionHeader(title: 'INSIGHTS & ALERTS'),
                  _DrawerItem(
                    icon: Icons.analytics_rounded,
                    title: 'Analytics & Reports',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.analytics);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.calculate_rounded,
                    title: 'Profit & Loss Statement',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.profitLoss);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.search_rounded,
                    title: 'Global Search',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.search);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.notifications_rounded,
                    title: 'Notification Center',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.notifications);
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                    child: Divider(height: 1),
                  ),

                  _SectionHeader(title: 'SYSTEM & SETTINGS'),
                  _DrawerItem(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.settings);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.restore_rounded,
                    title: 'Backup & Restore',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.backupRestore);
                    },
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'v1.0.0 • FreshFlow',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.textPrimary;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: iconColor != null
            ? BoxDecoration(
                color: iconColor!.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              )
            : null,
        child: Icon(icon, color: color, size: iconColor != null ? 20 : 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: iconColor != null ? color : null,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      hoverColor: (iconColor ?? AppColors.primary).withOpacity(0.05),
      splashColor: (iconColor ?? AppColors.primary).withOpacity(0.1),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textHint,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
