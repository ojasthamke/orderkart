import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/app_mode_service.dart';
import 'owner_pin_dialog.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final modeAsync = ref.watch(appModeProvider);
    final isWorker = modeAsync.value == AppMode.worker;

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
                        errorBuilder: (_, __, ___) => Icon(
                          isWorker ? Icons.badge_rounded : Icons.inventory_2_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OrderKart',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        isWorker ? 'WORKER APP' : 'OWNER CONTROL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isWorker ? const Color(0xFF0EA5E9) : AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                children: [
                  const _SectionHeader(title: 'NAVIGATION'),
                  _DrawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    onTap: () {
                      Navigator.pop(context);
                      if (isWorker) {
                        Navigator.pushNamed(context, AppRoutes.workerDashboard);
                      } else {
                        Navigator.pushNamed(context, AppRoutes.dashboard);
                      }
                    },
                  ),
                  
                  // ONLY SHOW WORKER MANAGEMENT & PERMISSION MANAGER IF IN OWNER MODE!
                  if (!isWorker) ...[
                    _DrawerItem(
                      icon: Icons.badge_rounded,
                      title: 'Worker Management',
                      iconColor: AppColors.primary,
                      onTap: () async {
                        Navigator.pop(context);
                        if (await OwnerPinDialog.verify(context, title: 'Worker Management')) {
                          Navigator.pushNamed(context, AppRoutes.workers);
                        }
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Worker Permission Manager',
                      iconColor: Colors.deepPurple,
                      onTap: () async {
                        Navigator.pop(context);
                        if (await OwnerPinDialog.verify(context, title: 'Worker Permission Manager')) {
                          Navigator.pushNamed(context, AppRoutes.workers);
                        }
                      },
                    ),
                  ],

                  _DrawerItem(
                    icon: Icons.map_rounded,
                    title: 'Areas & Routes (Area → Street)',
                    iconColor: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.areas);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.people_alt_rounded,
                    title: isWorker ? 'My Customers' : 'Customers',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.customers);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.shopping_cart_rounded,
                    title: isWorker ? 'My Orders & Sales' : 'Orders & Sales',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.orderManagement);
                    },
                  ),
                  
                  if (isWorker) ...[
                    _DrawerItem(
                      icon: Icons.person_rounded,
                      title: 'My Worker Profile',
                      iconColor: AppColors.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.workerSelfProfile);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.note_alt_rounded,
                      title: 'Field Visit Notes',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.notes);
                      },
                    ),
                  ],

                  if (!isWorker)
                    _DrawerItem(
                      icon: Icons.workspace_premium_rounded,
                      title: 'VIP Membership Club',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.vipDashboard);
                      },
                    ),
                  
                  _DrawerItem(
                    icon: Icons.inventory_rounded,
                    title: 'Inventory Catalog',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.inventory);
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                    child: Divider(height: 1),
                  ),
                  const _SectionHeader(title: 'SYNC & DATA'),
                  
                  if (!isWorker)
                    _DrawerItem(
                      icon: Icons.auto_mode_rounded,
                      title: 'Import Wizard (Merge)',
                      iconColor: const Color(0xFF0284C7),
                      onTap: () async {
                        Navigator.pop(context);
                        if (await OwnerPinDialog.verify(context, title: 'Import Wizard Access')) {
                          Navigator.pushNamed(context, AppRoutes.importWizard);
                        }
                      },
                    ),

                  _DrawerItem(
                    icon: Icons.sync_rounded,
                    title: 'Pending Sync Queue',
                    iconColor: const Color(0xFFD97706),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.pendingSync);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.history_toggle_off_rounded,
                    title: 'Sync Log History',
                    iconColor: const Color(0xFF8B5CF6),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.syncHistory);
                    },
                  ),
                  
                  if (!isWorker)
                    _DrawerItem(
                      icon: Icons.storefront_rounded,
                      title: 'Business Profile',
                      iconColor: const Color(0xFF10B981),
                      onTap: () async {
                        Navigator.pop(context);
                        if (await OwnerPinDialog.verify(context, title: 'Business Profile')) {
                          Navigator.pushNamed(context, AppRoutes.businessProfile);
                        }
                      },
                    ),

                  if (!isWorker) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                      child: Divider(height: 1),
                    ),

                    const _SectionHeader(title: 'INSIGHTS & ALERTS'),
                    _DrawerItem(
                      icon: Icons.analytics_rounded,
                      title: 'Analytics & Reports',
                      onTap: () async {
                        Navigator.pop(context);
                        if (await OwnerPinDialog.verify(context, title: 'Analytics Access')) {
                          Navigator.pushNamed(context, AppRoutes.analytics);
                        }
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.badge_rounded,
                      title: 'Worker Analytics',
                      iconColor: AppColors.primary,
                      onTap: () async {
                        Navigator.pop(context);
                        if (await OwnerPinDialog.verify(context, title: 'Worker Analytics')) {
                          Navigator.pushNamed(context, AppRoutes.workerAnalytics);
                        }
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.history_rounded,
                      title: 'Activity Timeline',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.activityTimeline);
                      },
                    ),
                  ],

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                    child: Divider(height: 1),
                  ),

                  const _SectionHeader(title: 'SECURITY & MODE'),
                  if (!isWorker)
                    _DrawerItem(
                      icon: Icons.settings_rounded,
                      title: 'Settings',
                      onTap: () async {
                        Navigator.pop(context);
                        if (await OwnerPinDialog.verify(context, title: 'Master Settings')) {
                          Navigator.pushNamed(context, AppRoutes.settings);
                        }
                      },
                    ),
                  _DrawerItem(
                    icon: Icons.sync_alt_rounded,
                    title: 'Import & Export Data',
                    onTap: () async {
                      Navigator.pop(context);
                      if (isWorker) {
                        Navigator.pushNamed(context, AppRoutes.backupRestore);
                      } else {
                        if (await OwnerPinDialog.verify(context, title: 'Import & Export Data')) {
                          Navigator.pushNamed(context, AppRoutes.backupRestore);
                        }
                      }
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
