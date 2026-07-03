/// OrderKart (FreshFlow) — Main Entry Point
/// Offline-first Order Management Application
/// Author: FreshFlow Team
/// Version: 1.0.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app.dart';
import 'core/database/database_helper.dart';
import 'core/constants/app_constants.dart';
import 'package:path_provider/path_provider.dart';
import 'core/services/widget_service.dart';

import 'core/services/notification_service.dart';
import 'core/services/background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Lock orientation to portrait for better UX on phones
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Set system UI overlay style for sunlight-friendly white theme
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Initialize App Documents Directory path
    final docDir = await getApplicationDocumentsDirectory();
    AppConstants.appDocsDir = docDir.path;

    // Initialize SQLite database
    await DatabaseHelper.instance.database;

    // Initialize new robust Notification & Background Services
    await NotificationService.instance.init();
    await BackgroundService.instance.init();
    BackgroundService.instance.registerDailyTask();

    // Initialize Home Widget
    await WidgetService.init();
    await WidgetService.updateWidgetData();

    runApp(
      const ProviderScope(
        child: OrderKartApp(),
      ),
    );
  } catch (e, st) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Failed to initialize app:\n$e',
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

