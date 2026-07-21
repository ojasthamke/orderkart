import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/app_notification.dart';
import '../data/notification_dao.dart';
import '../../settings/presentation/settings_provider.dart';
import '../../../core/constants/app_routes.dart';
import 'in_app_notification_banner.dart';

final notificationListProvider = StateNotifierProvider<NotificationListNotifier, AsyncValue<List<AppNotification>>>((ref) {
  return NotificationListNotifier(ref);
});

class NotificationListNotifier extends StateNotifier<AsyncValue<List<AppNotification>>> {
  final Ref _ref;
  final NotificationDao _dao = NotificationDao();

  NotificationListNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent && state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }
    try {
      final notifications = await _dao.getNotifications();
      state = AsyncValue.data(notifications);
    } catch (e, st) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> triggerNotification(
    BuildContext context, {
    required String title,
    required String body,
    required String category,
    String relatedId = '',
  }) async {
    final settingsVal = _ref.read(settingsProvider).valueOrNull;
    final enabled = settingsVal?.notificationsEnabled ?? true;
    if (!enabled) return;

    final id = const Uuid().v4();
    final notification = AppNotification(
      id: id,
      title: title,
      body: body,
      category: category,
      relatedId: relatedId,
      createdAt: DateTime.now(),
      isRead: false,
    );

    try {
      await _dao.insert(notification);
      await _loadNotifications(silent: true);

      // Show top overlay banner
      InAppNotificationBanner.show(
        context,
        title: title,
        body: body,
        category: category,
        enableSound: settingsVal?.notificationSound ?? true,
        enableVibration: settingsVal?.notificationVibration ?? true,
        onTap: () {
          markAsRead(id);
          String? route;
          Map<String, dynamic>? routeArgs;
          switch (category) {
            case 'payment_due':
              route = AppRoutes.customerProfile;
              routeArgs = {'customerId': relatedId};
              break;
            case 'low_stock':
              route = AppRoutes.inventory;
              break;
            case 'order_update':
              route = AppRoutes.orderDetail;
              routeArgs = {'orderId': relatedId};
              break;
          }
          if (route != null) {
            Navigator.of(context).pushNamed(route, arguments: routeArgs);
          }
        },
      );
    } catch (_) {}
  }

  Future<void> markAsRead(String id) async {
    try {
      await _dao.markAsRead(id);
      _loadNotifications(silent: true);
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _dao.markAllAsRead();
      _loadNotifications(silent: true);
    } catch (_) {}
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _dao.delete(id);
      _loadNotifications(silent: true);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    try {
      await _dao.deleteAll();
      _loadNotifications(silent: true);
    } catch (_) {}
  }
}
