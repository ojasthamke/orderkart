import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_provider.dart';
import '../domain/app_notification.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notification Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () {
              ref.read(notificationListProvider.notifier).markAllAsRead();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear all',
            onPressed: () {
              ref.read(notificationListProvider.notifier).clearAll();
            },
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications.'));
          }
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(notification: notification);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    IconData icon;
    switch (notification.category) {
      case 'payment_due':
        icon = Icons.payment;
        break;
      case 'low_stock':
        icon = Icons.inventory_2;
        break;
      case 'order_update':
        icon = Icons.local_shipping;
        break;
      default:
        icon = Icons.notifications;
    }

    return Material(
      color: notification.isRead
          ? Colors.transparent
          : AppColors.primary.withOpacity(0.05),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primarySurface,
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.body,
              style: TextStyle(color: AppColors.textSecondaryColor(context)),
            ),
            const SizedBox(height: 6),
            Text(
              _formatRelativeTime(notification.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHintColor(context),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () {
            ref.read(notificationListProvider.notifier).deleteNotification(notification.id);
          },
        ),
        onTap: () {
          ref.read(notificationListProvider.notifier).markAsRead(notification.id);
          
          String? route;
          switch (notification.category) {
            case 'payment_due':
              route = AppRoutes.customerProfile;
              break;
            case 'low_stock':
              route = AppRoutes.inventory;
              break;
            case 'order_update':
              route = AppRoutes.orderDetail;
              break;
          }
          
          if (route != null) {
            Navigator.of(context).pushNamed(route, arguments: notification.relatedId);
          }
        },
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
      if (difference.inMinutes == 1) return '1 minute ago';
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
