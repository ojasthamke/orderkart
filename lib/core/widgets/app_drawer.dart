import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/app_mode_service.dart';

import 'glass_design_system.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modeAsync = ref.watch(appModeProvider);
    final isWorker = modeAsync.value == AppMode.worker;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassContainer(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        padding: EdgeInsets.zero,
        borderColor: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06),
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
                  
                  // 1. Dashboard
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

                  // 2. Orders & Sales
                  _DrawerItem(
                    icon: Icons.shopping_cart_rounded,
                    title: isWorker ? 'My Orders & Sales' : 'Orders & Sales',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.orderManagement);
                    },
                  ),

                  // 3. Customers
                  _DrawerItem(
                    icon: Icons.people_alt_rounded,
                    title: isWorker ? 'My Customers' : 'Customers',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.customers);
                    },
                  ),

                  // 4. Inventory Catalog
                  _DrawerItem(
                    icon: Icons.inventory_rounded,
                    title: 'Inventory Catalog',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.inventory);
                    },
                  ),

                  // 5. Catalog Showroom
                  _DrawerItem(
                    icon: Icons.image_rounded,
                    title: 'Catalog Showroom',
                    iconColor: Colors.deepPurple,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.catalogShowroom);
                    },
                  ),

                  // 6. Area Intelligence Map
                  _DrawerItem(
                    icon: Icons.map_rounded,
                    title: 'Area Intelligence Map',
                    iconColor: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.areaIntelligenceMap);
                    },
                  ),

                  // 7. VIP Membership Club
                  if (!isWorker)
                    _DrawerItem(
                      icon: Icons.workspace_premium_rounded,
                      title: 'VIP Membership Club',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.vipDashboard);
                      },
                    ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                    child: Divider(height: 1),
                  ),
                  const _SectionHeader(title: 'LOGISTICS & SERVICES'),

                  // 8. Field Visits Schedule
                  _DrawerItem(
                    icon: Icons.calendar_today_rounded,
                    title: 'Field Visits Schedule',
                    iconColor: Colors.blueAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.visits);
                    },
                  ),

                  // 9. Expenses Tracker
                  _DrawerItem(
                    icon: Icons.receipt_long_rounded,
                    title: 'Expenses Tracker',
                    iconColor: Colors.redAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.expenses);
                    },
                  ),

                  // 10. Groceries Hub
                  _DrawerItem(
                    icon: Icons.local_grocery_store_rounded,
                    title: 'Groceries Hub',
                    iconColor: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.groceriesHub);
                    },
                  ),

                  // 11. Medicines Hub
                  _DrawerItem(
                    icon: Icons.local_pharmacy_rounded,
                    title: 'Medicines Hub',
                    iconColor: Colors.pink,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.medicinesHub);
                    },
                  ),

                  // Divider & Insights Section
                  if (!isWorker) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                      child: Divider(height: 1),
                    ),
                    const _SectionHeader(title: 'INSIGHTS & ALERTS'),
                    _DrawerItem(
                      icon: Icons.analytics_rounded,
                      title: 'Analytics & Reports',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.analytics);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.badge_rounded,
                      title: 'Worker Analytics',
                      iconColor: AppColors.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.workerAnalytics);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.warning_amber_rounded,
                      title: 'Churn Risk Analyzer',
                      iconColor: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.churnRisk);
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
                    _DrawerItem(
                      icon: Icons.phone_callback_rounded,
                      title: 'Call Logs & Directory',
                      iconColor: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.callLogs);
                      },
                    ),
                  ],

                  // Alerts & Notifications
                  _DrawerItem(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications & Alerts',
                    iconColor: Colors.amber,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.notifications);
                    },
                  ),

                  // Divider & Settings Section
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                    child: Divider(height: 1),
                  ),
                  const _SectionHeader(title: 'SETTINGS & SECURITY'),
                  _DrawerItem(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.settings);
                    },
                  ),
                  if (!isWorker) ...[
                    _DrawerItem(
                      icon: Icons.question_answer_rounded,
                      title: 'Order Notes Questions',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.orderQuestionsConfig);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.history_edu_rounded,
                      title: 'Worker Sync Activity',
                      iconColor: Colors.teal,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.workerSyncActivity);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Advance Operation Control',
                      iconColor: Colors.blueAccent,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.ownerFeaturesHub);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.badge_rounded,
                      title: 'Worker Management',
                      iconColor: AppColors.primary,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.workers);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.map_rounded,
                      title: 'Areas & Routes (Area → Street)',
                      iconColor: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.areas);
                      },
                    ),
                  ],

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

                  // Divider & Sync and Data Section
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                    child: Divider(height: 1),
                  ),
                  const _SectionHeader(title: 'SYNC & DATA'),
                  
                  _DrawerItem(
                    icon: Icons.sync_alt_rounded,
                    title: isWorker ? 'Sync & Export' : 'Import & Export Data',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.backupRestore);
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
                  if (!isWorker) ...[
                    _DrawerItem(
                      icon: Icons.auto_mode_rounded,
                      title: 'Import Wizard (Merge)',
                      iconColor: const Color(0xFF0284C7),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.importWizard);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.storefront_rounded,
                      title: 'Business Profile',
                      iconColor: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.businessProfile);
                      },
                    ),
                  ],

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = iconColor ?? (isDark ? Colors.white : AppColors.textPrimary);
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (iconColor ?? (isDark ? Colors.white : AppColors.primary)).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: color,
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
