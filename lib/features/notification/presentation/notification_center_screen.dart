import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_provider.dart';
import '../domain/app_notification.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/haptics.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  bool _showSimulator = false;

  void _triggerSimulatedAlert(String type) {
    AppHaptics.selection();
    final notifier = ref.read(notificationListProvider.notifier);

    switch (type) {
      case 'low_stock':
        notifier.triggerNotification(
          context,
          title: '⚠️ Low Stock Alert: Fresh Apples',
          body:
              'Inventory for "Fresh Apples" is down to 2 kgs. Reorder immediately to avoid stockouts.',
          category: 'low_stock',
          relatedId: '',
        );
        break;
      case 'payment_due':
        notifier.triggerNotification(
          context,
          title: '💰 Payment Pending: Rajesh Sharma',
          body:
              'Rajesh Sharma has a pending balance of Rs. 1,450.00 outstanding for over 15 days.',
          category: 'payment_due',
          relatedId: '',
        );
        break;
      case 'order_update':
        notifier.triggerNotification(
          context,
          title: '🚚 Order #1084 Dispatched',
          body:
              'Delivery package for "Subhash Stores" has been dispatched with worker Aman Kumar.',
          category: 'order_update',
          relatedId: '',
        );
        break;
      case 'sync':
        notifier.triggerNotification(
          context,
          title: '🔄 P2P Hotspot Sync Complete',
          body:
              'Successfully synchronized 24 new order records with field device "Worker-Tablet-A".',
          category: 'sync',
          relatedId: '',
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Notification Hub',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Icon(_showSimulator
                ? Icons.bug_report_rounded
                : Icons.bug_report_outlined),
            tooltip: 'Simulate Alerts',
            color: _showSimulator ? AppColors.primary : null,
            onPressed: () {
              setState(() => _showSimulator = !_showSimulator);
            },
          ),
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Mark all read',
            onPressed: () {
              AppHaptics.selection();
              ref.read(notificationListProvider.notifier).markAllAsRead();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear history',
            onPressed: () {
              AppHaptics.warning();
              ref.read(notificationListProvider.notifier).clearAll();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Animated Simulator Panel ─────────────────────────────
          AnimatedCrossFade(
            firstChild: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.3), width: 1.5),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded,
                          color: Colors.amberAccent, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'LIVE ALERTS SIMULATOR',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white60, size: 18),
                        onPressed: () => setState(() => _showSimulator = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Trigger instant simulated alerts to test the real-time slide-down notification banner, click actions, sound, and custom haptics.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _simulatorButton('Low Stock', Icons.inventory_2_rounded,
                          Colors.orangeAccent, 'low_stock'),
                      _simulatorButton('Payment Due', Icons.payment_rounded,
                          Colors.redAccent, 'payment_due'),
                      _simulatorButton('Dispatch', Icons.local_shipping_rounded,
                          Colors.greenAccent, 'order_update'),
                      _simulatorButton('P2P Sync', Icons.sync_rounded,
                          Colors.blueAccent, 'sync'),
                    ],
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _showSimulator
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),

          // ── Notification List ────────────────────────────────────
          Expanded(
            child: notificationsAsync.when(
              data: (notifications) {
                if (notifications.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications_none_rounded,
                                size: 64, color: AppColors.primary),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your Notification Hub is Quiet',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Critical low stock alerts, pending payment reminders, and worker updates will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () =>
                                setState(() => _showSimulator = true),
                            icon: const Icon(Icons.bolt_rounded),
                            label: const Text('Open Simulator & Test'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _NotificationCard(notification: notification);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _simulatorButton(
      String label, IconData icon, Color color, String type) {
    return ElevatedButton.icon(
      onPressed: () => _triggerSimulatedAlert(type),
      icon: Icon(icon, size: 14, color: Colors.black87),
      label: Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final AppNotification notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    IconData icon;
    Color color;
    switch (notification.category) {
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
        icon = Icons.notifications_rounded;
        color = AppColors.primary;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              notification.isRead ? AppColors.gray200 : color.withOpacity(0.4),
          width: notification.isRead ? 1.0 : 1.5,
        ),
        boxShadow: notification.isRead
            ? null
            : [
                BoxShadow(
                  color: color.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left category accent bar
              Container(
                width: 6,
                color: color,
              ),
              Expanded(
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.normal
                                : FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 12,
                              color:
                                  isDark ? Colors.white38 : AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            _formatRelativeTime(notification.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color:
                                  isDark ? Colors.white38 : AppColors.textHint,
                            ),
                          ),
                          const Spacer(),
                          if (!notification.isRead)
                            TextButton(
                              onPressed: () {
                                AppHaptics.selection();
                                ref
                                    .read(notificationListProvider.notifier)
                                    .markAsRead(notification.id);
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Mark Read',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    onPressed: () {
                      AppHaptics.warning();
                      ref
                          .read(notificationListProvider.notifier)
                          .deleteNotification(notification.id);
                    },
                  ),
                  onTap: () {
                    AppHaptics.selection();
                    ref
                        .read(notificationListProvider.notifier)
                        .markAsRead(notification.id);

                    String? route;
                    Object? routeArgs;
                    switch (notification.category) {
                      case 'payment_due':
                        route = AppRoutes.customerProfile;
                        routeArgs = {'customerId': notification.relatedId};
                        break;
                      case 'low_stock':
                        route = AppRoutes.inventory;
                        break;
                      case 'order_update':
                        route = AppRoutes.orderDetail;
                        routeArgs = {'orderId': notification.relatedId};
                        break;
                    }

                    if (route != null) {
                      Navigator.of(context)
                          .pushNamed(route, arguments: routeArgs);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays > 0) {
      if (difference.inDays == 1) return '1 day ago';
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      if (difference.inHours == 1) return '1 hour ago';
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      if (difference.inMinutes == 1) return '1 min ago';
      return '${difference.inMinutes} mins ago';
    } else {
      return 'Just now';
    }
  }
}
