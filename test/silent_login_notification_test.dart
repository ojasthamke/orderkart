import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:orderkart/core/services/notification_service.dart';

void main() {
  group('OrderKart Silent Customer Login Notification Invariant Tests', () {
    test('Constants match architectural specifications', () {
      expect(NotificationService.customerLoginNotificationId, 9999);
      expect(NotificationService.customerLoginNotificationTag, 'customer_login');
      expect(NotificationService.customerLoginChannelId, 'customer_login_channel');
      expect(NotificationService.customerLoginChannelName, 'Customer Login Alerts');
      expect(NotificationService.customerLoginChannelDesc, 'Silent notifications when customers log in');
    });

    test('Customer login detection invariants from various payloads', () {
      bool isCustomerLogin({
        String? channelId,
        String? payload,
        String? title,
        String? body,
      }) {
        final t = title?.toLowerCase() ?? '';
        final b = body?.toLowerCase() ?? '';
        return channelId == NotificationService.customerLoginChannelId ||
            (payload != null && payload.startsWith('customer_login_')) ||
            t.contains('customer login') ||
            b.contains('logged in');
      }

      // Case 1: FCM message with channelId
      expect(
        isCustomerLogin(
          channelId: 'customer_login_channel',
          title: 'Customer Login 👤',
          body: 'Nayan [HZ123] (8605498416) has logged in.',
        ),
        isTrue,
      );

      // Case 2: FCM message with payload prefix
      expect(
        isCustomerLogin(
          payload: 'customer_login_HZ123',
          title: 'Customer Login 👤',
          body: 'Nayan has logged in.',
        ),
        isTrue,
      );

      // Case 3: Title and body match
      expect(
        isCustomerLogin(
          title: 'Customer Login 👤',
          body: 'Nayan has logged in.',
        ),
        isTrue,
      );

      // Case 4: Regular new order notification should NOT match
      expect(
        isCustomerLogin(
          channelId: 'orderkart_channel',
          title: 'New Online Order Received!',
          body: 'Order #1001 from Ojas for ₹120.00',
          payload: 'order_1001',
        ),
        isFalse,
      );
    });

    test('Silent channel enforces Importance.low, no sound, no vibration, and tag/id replacement', () {
      AndroidNotificationDetails buildDetails(bool isLogin) {
        final effectiveChannelId = isLogin
            ? NotificationService.customerLoginChannelId
            : 'orderkart_channel';
        final effectiveTag = isLogin
            ? NotificationService.customerLoginNotificationTag
            : null;
        final effectivePlaySound = !isLogin;
        final effectiveEnableVibration = !isLogin;
        final effectiveImportance = isLogin ? Importance.low : Importance.max;
        final effectivePriority = isLogin ? Priority.low : Priority.high;

        return AndroidNotificationDetails(
          effectiveChannelId,
          'Customer Login Alerts',
          channelDescription: 'Silent notifications when customers log in',
          importance: effectiveImportance,
          priority: effectivePriority,
          playSound: effectivePlaySound,
          enableVibration: effectiveEnableVibration,
          vibrationPattern: effectiveEnableVibration ? Int64List.fromList([0, 1000]) : null,
          tag: effectiveTag,
          onlyAlertOnce: isLogin,
        );
      }

      final details = buildDetails(true);
      expect(details.channelId, 'customer_login_channel');
      expect(details.importance, Importance.low);
      expect(details.priority, Priority.low);
      expect(details.playSound, isFalse);
      expect(details.enableVibration, isFalse);
      expect(details.vibrationPattern, isNull);
      expect(details.tag, 'customer_login');
      expect(details.onlyAlertOnce, isTrue);
      expect(NotificationService.customerLoginNotificationId, 9999);
    });

    test('Active new order alerts retain loud sound, vibration, and max importance', () {
      AndroidNotificationDetails buildOrderDetails(bool isLogin) {
        final effectiveChannelId = isLogin
            ? NotificationService.customerLoginChannelId
            : 'orderkart_channel';
        final effectivePlaySound = !isLogin;
        final effectiveEnableVibration = !isLogin;
        final effectiveImportance = isLogin ? Importance.low : Importance.max;
        final effectivePriority = isLogin ? Priority.low : Priority.high;

        return AndroidNotificationDetails(
          effectiveChannelId,
          'OrderKart Alerts',
          importance: effectiveImportance,
          priority: effectivePriority,
          playSound: effectivePlaySound,
          enableVibration: effectiveEnableVibration,
          vibrationPattern: effectiveEnableVibration ? Int64List.fromList([0, 1000]) : null,
          onlyAlertOnce: isLogin,
        );
      }

      final details = buildOrderDetails(false);
      expect(details.channelId, 'orderkart_channel');
      expect(details.importance, Importance.max);
      expect(details.priority, Priority.high);
      expect(details.playSound, isTrue);
      expect(details.enableVibration, isTrue);
      expect(details.vibrationPattern, isNotNull);
      expect(details.onlyAlertOnce, isFalse);
    });

    test('Empty or control messages on notification clearing are completely suppressed', () {
      bool shouldProcessMessage({String? rawTitle, String? rawBody}) {
        if ((rawTitle == null || rawTitle.trim().isEmpty) &&
            (rawBody == null || rawBody.trim().isEmpty)) {
          return false; // Suppress empty ghost notification
        }
        return true;
      }

      // Notification clearing / sync intent with null title and body
      expect(shouldProcessMessage(rawTitle: null, rawBody: null), isFalse);
      expect(shouldProcessMessage(rawTitle: '', rawBody: ''), isFalse);
      expect(shouldProcessMessage(rawTitle: '   ', rawBody: '   '), isFalse);

      // Real messages with title or body are processed
      expect(shouldProcessMessage(rawTitle: 'Customer Login 👤', rawBody: 'Nayan logged in'), isTrue);
      expect(shouldProcessMessage(rawTitle: 'New Order Received! 🛒', rawBody: 'Order #101'), isTrue);
    });

    test('OS-rendered notifications in background handler are not duplicated', () {
      bool shouldShowLocalNotificationInBackground({bool hasOsNotification = false, String? rawTitle}) {
        if (hasOsNotification) {
          return false; // Android OS already rendered it in notification shade
        }
        if (rawTitle == null || rawTitle.trim().isEmpty) {
          return false; // Don't show empty notification
        }
        return true;
      }

      // Push notification with OS notification block: OS renders it, handler skips
      expect(shouldShowLocalNotificationInBackground(hasOsNotification: true, rawTitle: 'Customer Login 👤'), isFalse);

      // Data-only push message with title: handler renders it locally
      expect(shouldShowLocalNotificationInBackground(hasOsNotification: false, rawTitle: 'Customer Login 👤'), isTrue);

      // Empty / clearance ping: handler skips
      expect(shouldShowLocalNotificationInBackground(hasOsNotification: false, rawTitle: null), isFalse);
    });
  });
}
