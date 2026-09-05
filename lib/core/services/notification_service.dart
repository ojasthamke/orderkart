import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_routes.dart';
import '../../app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService._();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {}

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onSelectNotification,
    );

    // Schedule 5-hour periodic reminder
    await schedulePeriodicReminder();

    // Initialize Firebase & FCM for Admin
    await _initFirebaseMessaging();
  }

  Future<void> _initFirebaseMessaging() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request FCM permissions
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );
      debugPrint('Admin FCM permission status: ${settings.authorizationStatus}');

      // Presentation options for foreground display:
      // Setting alert to false prevents the OS from spawning an unmanaged duplicate banner
      // while our local notification handler renders the alert cleanly and uniquely.
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      // Subscribe to admin orders topic
      try {
        await FirebaseMessaging.instance.subscribeToTopic('admin_orders');
      } catch (topicErr) {
        debugPrint('Admin FCM topic subscription notice: $topicErr');
      }

      // Retrieve and register Admin FCM device token
      await registerAdminFCMToken();

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('Admin FCM token refreshed: $newToken');
        await registerAdminFCMToken(explicitToken: newToken);
      });

      // Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final data = message.data;

        final title = notification?.title ?? data['title'] ?? 'OrderKart Alert';
        final body = notification?.body ?? data['body'] ?? '';
        final payload = data['payload'] ?? '';

        showNotification(
          id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title,
          body: body,
          payload: payload,
        );
      });

      // Handle background notification click
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final payload = message.data['payload'];
        if (payload != null && payload.isNotEmpty) {
          _handleNotificationPayload(payload);
        }
      });

      // Handle terminated launch notification click
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          final payload = message.data['payload'];
          if (payload != null && payload.isNotEmpty) {
            _handleNotificationPayload(payload);
          }
        }
      });

    } catch (e) {
      debugPrint('OrderKart Firebase Messaging initialization error: $e');
    }
  }

  Future<void> registerAdminFCMToken({String? explicitToken}) async {
    try {
      final token = explicitToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      final client = Supabase.instance.client;
      if (client.auth.currentUser != null) {
        await client.rpc('register_device_token', params: {
          'p_token': token,
          'p_role': 'admin',
          'p_device_type': 'android',
          'p_device_name': 'OrderKart Admin Device',
        });
        debugPrint('Admin FCM token registered successfully with Supabase: $token');
      }
    } catch (e) {
      debugPrint('Failed to register Admin FCM token with Supabase: $e');
    }
  }

  void _onSelectNotification(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      _handleNotificationPayload(payload);
    }
  }

  void _handleNotificationPayload(String payload) {
    debugPrint('OrderKart notification tapped with payload: $payload');
    try {
      if (payload.startsWith('admin_order_')) {
        final orderId = payload.substring('admin_order_'.length);
        if (orderId.isNotEmpty) {
          _navigateToOrder(orderId);
        }
      } else if (payload.startsWith('order_')) {
        final orderId = payload.substring('order_'.length);
        if (orderId.isNotEmpty) {
          _navigateToOrder(orderId);
        }
      }
    } catch (e) {
      debugPrint('Failed to navigate from notification payload: $e');
    }
  }

  void _navigateToOrder(String orderId) {
    Future.delayed(const Duration(milliseconds: 300), () {
      final navState = OrderKartApp.navigatorKey.currentState;
      if (navState != null) {
        navState.pushNamed(
          AppRoutes.orderDetail,
          arguments: {'orderId': orderId},
        );
      }
    });
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool playSound = true,
    bool enableVibration = true,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'orderkart_channel',
      'OrderKart Alerts',
      channelDescription: 'Notifications for OrderKart',
      importance: Importance.max,
      priority: Priority.high,
      playSound: playSound,
      enableVibration: enableVibration,
      vibrationPattern: enableVibration
          ? Int64List.fromList([0, 1000, 500, 1000])
          : null,
    );
    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(id, title, body, platformDetails,
        payload: payload);
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    bool playSound = true,
    bool enableVibration = true,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'orderkart_scheduled_channel',
      'OrderKart Reminders',
      channelDescription: 'Scheduled reminders for notes and visits',
      importance: Importance.max,
      priority: Priority.high,
      playSound: playSound,
      enableVibration: enableVibration,
      vibrationPattern: enableVibration ? Int64List.fromList([0, 3000]) : null,
    );
    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> schedulePeriodicReminder() async {
    const int periodicId = 8888;
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'orderkart_periodic_channel',
      'OrderKart Periodic Updates',
      channelDescription: 'Periodic reminders every 5 hours',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.periodicallyShowWithDuration(
      periodicId,
      'OrderKart Delivery Reminder',
      'Time to check your pending deliveries, stock levels, and client dues!',
      const Duration(hours: 5),
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'periodic_reminder',
    );
  }
}
