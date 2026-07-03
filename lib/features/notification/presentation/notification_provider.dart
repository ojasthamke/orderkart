import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/app_notification.dart';
import '../data/notification_dao.dart';

final notificationListProvider = StateNotifierProvider<NotificationListNotifier, AsyncValue<List<AppNotification>>>((ref) {
  return NotificationListNotifier();
});

class NotificationListNotifier extends StateNotifier<AsyncValue<List<AppNotification>>> {
  final NotificationDao _dao = NotificationDao();

  NotificationListNotifier() : super(const AsyncValue.loading()) {
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    state = const AsyncValue.loading();
    try {
      final notifications = await _dao.getNotifications();
      state = AsyncValue.data(notifications);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _dao.markAsRead(id);
      _loadNotifications();
    } catch (e) {
      // Handle error gracefully if needed
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _dao.markAllAsRead();
      _loadNotifications();
    } catch (e) {
      // Handle error gracefully if needed
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _dao.delete(id);
      _loadNotifications();
    } catch (e) {
      // Handle error gracefully if needed
    }
  }

  Future<void> clearAll() async {
    try {
      await _dao.deleteAll();
      _loadNotifications();
    } catch (e) {
      // Handle error gracefully if needed
    }
  }
}
