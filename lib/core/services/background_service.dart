/// BackgroundService — Schedules daily summary notifications using
/// flutter_local_notifications periodic scheduling only.
/// Does NOT use workmanager or any native background worker.
/// Fully offline-first. Works without any internet or background services.
library;

import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import 'notification_service.dart';
import '../constants/app_constants.dart';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._();
  static BackgroundService get instance => _instance;

  BackgroundService._();

  Future<void> init() async {
    // No-op: notification scheduling is handled by NotificationService.
    // Background workers (workmanager) are not needed for an offline app.
  }

  /// Called on app launch — checks if the daily summary should run today.
  void registerDailyTask() {
    _maybeRunDailySummary();
  }

  /// Runs the daily summary check. Called from the foreground on app launch.
  /// Persists the last-run date so it only fires once per day.
  static Future<void> _maybeRunDailySummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month}-${now.day}';
      final lastRunDate = prefs.getString('last_summary_run_date') ?? '';

      if (lastRunDate == todayStr) return; // Already ran today

      final db = await DatabaseHelper.instance.database;

      // Check if daily summary is enabled in settings
      final summaryEnabled =
          (await db.query('settings', where: 'key = ?', whereArgs: [AppConstants.keyDailySummary]))
                  .firstOrNull?['value'] ==
              'true';
      if (!summaryEnabled) return;

      // Check scheduled notification time
      final targetTime =
          (await db.query('settings', where: 'key = ?', whereArgs: [AppConstants.keyNotifTime]))
                  .firstOrNull?['value'] as String? ??
              '06:00';
      final targetHour = int.tryParse(targetTime.split(':')[0]) ?? 6;

      // Only show in the morning window (within 1 hour of configured time)
      if (now.hour < targetHour || now.hour > targetHour + 1) return;

      // --- Build summary payload ---
      final pendingCustomers = await db.rawQuery(
          'SELECT COUNT(*) as count, SUM(outstanding_balance) as total FROM customers WHERE outstanding_balance > 0');
      final pendingCount = _firstInt(pendingCustomers) ?? 0;
      final pendingTotal = (pendingCustomers.first['total'] as num?)?.toDouble() ?? 0.0;

      final lowStockItems = await db
          .rawQuery('SELECT COUNT(*) as count FROM items WHERE stock <= min_stock');
      final lowStockCount = _firstInt(lowStockItems) ?? 0;

      final visits = await db
          .rawQuery('SELECT COUNT(*) as count FROM visits WHERE date = ?', [todayStr]);
      final visitCount = _firstInt(visits) ?? 0;

      final buf = StringBuffer();
      if (pendingCount > 0) {
        buf.writeln(
            '• $pendingCount customers have pending payments (₹${pendingTotal.toStringAsFixed(0)})');
      }
      if (lowStockCount > 0) buf.writeln('• $lowStockCount low stock items');
      if (visitCount > 0) buf.writeln('• $visitCount scheduled visits today');
      if (buf.isEmpty) buf.writeln('No alerts for today. Have a great day!');

      // Save to DB notifications table
      await db.insert('notifications', {
        'id': 'summary_${todayStr.replaceAll('-', '')}',
        'title': "Today's Summary",
        'body': buf.toString(),
        'category': 'system',
        'is_read': 0,
        'priority': 2,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Show local notification
      final playSound =
          (await db.query('settings', where: 'key = ?', whereArgs: [AppConstants.keyNotifSound]))
                  .firstOrNull?['value'] ==
              'true';
      final vibrate =
          (await db.query('settings', where: 'key = ?', whereArgs: [AppConstants.keyNotifVibration]))
                  .firstOrNull?['value'] ==
              'true';

      await NotificationService.instance.showNotification(
        id: 9999,
        title: "OrderKart — Today's Summary",
        body: buf.toString(),
        payload: 'summary',
        playSound: playSound,
        enableVibration: vibrate,
      );

      await prefs.setString('last_summary_run_date', todayStr);
    } catch (_) {
      // Silent failure — never crash the app due to background summary
    }
  }

  static int? _firstInt(List<Map<String, dynamic>> list) {
    if (list.isNotEmpty && list.first.values.isNotEmpty) {
      return list.first.values.first as int?;
    }
    return null;
  }
}
