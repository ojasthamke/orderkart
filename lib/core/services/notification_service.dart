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

    final notification = message.notification;
    final data = message.data;

    // 1. If the message already contains an OS-rendered notification block,
    // Google Play Services on Android automatically handles rendering it in the system tray.
    // Calling localNotifications.show() here would generate a duplicate notification.
    if (notification != null) {
      return;
    }

    // 2. For data-only messages, extract title and body
    final rawTitle = data['title']?.toString();
    final rawBody = data['body']?.toString();

    // 3. Strictly ignore empty / control / dismissal sync messages.
    // Never synthesize a fake notification or show "OrderKart Alert" when notifications are cleared!
    if ((rawTitle == null || rawTitle.trim().isEmpty) &&
        (rawBody == null || rawBody.trim().isEmpty)) {
      debugPrint('OrderKart background FCM: ignoring empty/control message without title or body');
      return;
    }

    final String title = rawTitle?.trim() ?? '';
    final String body = rawBody?.trim() ?? '';
    final String payload = data['payload']?.toString() ?? '';
    final String channelId = (data['channelId'] ?? data['channel_id'])?.toString() ?? '';

    final localNotifications = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await localNotifications.initialize(initSettings);

    final bool isCustomerLogin = channelId == 'customer_login_channel' ||
        payload.startsWith('customer_login_') ||
        title.toLowerCase().contains('customer login') ||
        body.toLowerCase().contains('logged in');

    if (isCustomerLogin) {
      final androidPlugin = localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        const silentChannel = AndroidNotificationChannel(
          'customer_login_channel',
          'Customer Login Alerts',
          description: 'Silent notifications when customers log in',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: true,
        );
        await androidPlugin.createNotificationChannel(silentChannel);
      }

      const androidDetails = AndroidNotificationDetails(
        'customer_login_channel',
        'Customer Login Alerts',
        channelDescription: 'Silent notifications when customers log in',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        tag: 'customer_login',
        onlyAlertOnce: true,
      );
      const platformDetails = NotificationDetails(android: androidDetails);
      await localNotifications.show(
        9999,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } else {
      const androidDetails = AndroidNotificationDetails(
        'orderkart_channel',
        'OrderKart Alerts',
        channelDescription: 'Notifications for OrderKart',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
      const platformDetails = NotificationDetails(android: androidDetails);
      await localNotifications.show(
        message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    }
  } catch (e) {
    debugPrint('OrderKart background FCM error: $e');
  }
}

class NotificationService {
  static const int customerLoginNotificationId = 9999;
  static const String customerLoginNotificationTag = 'customer_login';
  static const String customerLoginChannelId = 'customer_login_channel';
  static const String customerLoginChannelName = 'Customer Login Alerts';
  static const String customerLoginChannelDesc = 'Silent notifications when customers log in';

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

    // Register silent notification channel for customer logins
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const silentChannel = AndroidNotificationChannel(
        customerLoginChannelId,
        customerLoginChannelName,
        description: customerLoginChannelDesc,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: true,
      );
      await androidPlugin.createNotificationChannel(silentChannel);
    }

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

        final rawTitle = notification?.title ?? data['title']?.toString();
        final rawBody = notification?.body ?? data['body']?.toString();

        // Strictly ignore empty / control / dismissal sync messages without real title or body
        if ((rawTitle == null || rawTitle.trim().isEmpty) &&
            (rawBody == null || rawBody.trim().isEmpty)) {
          debugPrint('OrderKart foreground FCM: ignoring message without title or body');
          return;
        }

        final String title = rawTitle?.trim() ?? '';
        final String body = rawBody?.trim() ?? '';
        final payload = data['payload']?.toString() ?? '';
        final channelId = (data['channelId'] ?? data['channel_id'])?.toString() ?? '';

        final bool isCustomerLogin = channelId == customerLoginChannelId ||
            payload.startsWith('customer_login_') ||
            title.toLowerCase().contains('customer login') ||
            body.toLowerCase().contains('logged in');

        showNotification(
          id: isCustomerLogin
              ? customerLoginNotificationId
              : (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000),
          title: title,
          body: body,
          payload: payload,
          channelId: isCustomerLogin ? customerLoginChannelId : null,
          tag: isCustomerLogin ? customerLoginNotificationTag : null,
          playSound: !isCustomerLogin,
          enableVibration: !isCustomerLogin,
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
    String? channelId,
    String? tag,
  }) async {
    // Guard against showing blank or ghost notifications (e.g. on notification clear)
    if (title.trim().isEmpty && body.trim().isEmpty) {
      debugPrint('NotificationService.showNotification: suppressed empty notification');
      return;
    }

    final bool isCustomerLogin = channelId == customerLoginChannelId ||
        tag == customerLoginNotificationTag ||
        (payload != null && payload.startsWith('customer_login_')) ||
        title.toLowerCase().contains('customer login') ||
        body.toLowerCase().contains('logged in');

    final String effectiveChannelId =
        isCustomerLogin ? customerLoginChannelId : (channelId ?? 'orderkart_channel');
    final String effectiveChannelName =
        isCustomerLogin ? customerLoginChannelName : 'OrderKart Alerts';
    final String effectiveChannelDesc =
        isCustomerLogin ? customerLoginChannelDesc : 'Notifications for OrderKart';
    final int effectiveId = isCustomerLogin ? customerLoginNotificationId : id;
    final String? effectiveTag = isCustomerLogin ? customerLoginNotificationTag : tag;
    final bool effectivePlaySound = isCustomerLogin ? false : playSound;
    final bool effectiveEnableVibration = isCustomerLogin ? false : enableVibration;
    final Importance effectiveImportance =
        isCustomerLogin ? Importance.low : Importance.max;
    final Priority effectivePriority =
        isCustomerLogin ? Priority.low : Priority.high;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      effectiveChannelId,
      effectiveChannelName,
      channelDescription: effectiveChannelDesc,
      importance: effectiveImportance,
      priority: effectivePriority,
      playSound: effectivePlaySound,
      enableVibration: effectiveEnableVibration,
      vibrationPattern: effectiveEnableVibration
          ? Int64List.fromList([0, 1000, 500, 1000])
          : null,
      tag: effectiveTag,
      onlyAlertOnce: isCustomerLogin,
    );
    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      effectiveId,
      title,
      body,
      platformDetails,
      payload: payload,
    );
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
