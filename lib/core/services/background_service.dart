import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import 'notification_service.dart';
import '../constants/app_constants.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == 'dailySummaryTask') {
        final prefs = await SharedPreferences.getInstance();
        final db = await DatabaseHelper.instance.database;

        // Check if settings allow
        final summaryEnabled = (await db.query('settings', where: 'key = ?', whereArgs: [AppConstants.keyDailySummary])).firstOrNull?['value'] == 'true';
        if (!summaryEnabled) return Future.value(true);

        final targetTime = (await db.query('settings', where: 'key = ?', whereArgs: [AppConstants.keyNotifTime])).firstOrNull?['value'] as String? ?? '06:00';
        final targetHour = int.tryParse(targetTime.split(':')[0]) ?? 6;
        final targetMinute = int.tryParse(targetTime.split(':')[1]) ?? 0;

        final now = DateTime.now();
        
        // Ensure we only trigger around the target time (and prevent duplicate triggers on the same day)
        final lastRunDate = prefs.getString('last_summary_run_date') ?? '';
        final todayStr = '${now.year}-${now.month}-${now.day}';

        if (lastRunDate == todayStr) return Future.value(true); // Already ran today
        
        // Check if it's the right time (allow a 1-hour window to handle doze mode delays)
        if (now.hour < targetHour || now.hour > targetHour + 1) return Future.value(true);

        // --- Execute Payload ---

        // 1. Pending Payments
        final pendingCustomers = await db.rawQuery('SELECT COUNT(*) as count, SUM(outstanding_balance) as total FROM customers WHERE outstanding_balance > 0');
        final pendingCount = SqfliteUtils.firstIntValue(pendingCustomers) ?? 0;
        final pendingTotal = (pendingCustomers.first['total'] as num?)?.toDouble() ?? 0.0;

        // 2. Low Stock
        final lowStockItems = await db.rawQuery('SELECT COUNT(*) as count FROM items WHERE stock <= min_stock');
        final lowStockCount = SqfliteUtils.firstIntValue(lowStockItems) ?? 0;

        // 3. Today's Visits
        final visits = await db.rawQuery('SELECT COUNT(*) as count FROM visits WHERE date = ?', [todayStr]);
        final visitCount = SqfliteUtils.firstIntValue(visits) ?? 0;

        // Create Summary Notification Body
        final buf = StringBuffer();
        if (pendingCount > 0) buf.writeln('• $pendingCount Customers have pending payments (Total: ₹${pendingTotal.toStringAsFixed(0)})');
        if (lowStockCount > 0) buf.writeln('• $lowStockCount Low Stock Items');
        if (visitCount > 0) buf.writeln('• $visitCount Scheduled Visits Today');

        if (buf.isEmpty) buf.writeln('No alerts for today. Have a great day!');

        // Insert into Notifications Table
        await db.insert('notifications', {
          'id': const Uuid().v4(),
          'title': 'Today\'s Summary',
          'body': buf.toString(),
          'category': 'system',
          'is_read': 0,
          'priority': 2,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Fire Local Notification
        final playSound = (await db.query('settings', where: 'key = ?', whereArgs: [AppConstants.keyNotifSound])).firstOrNull?['value'] == 'true';
        final vibrate = (await db.query('settings', where: 'key = ?', whereArgs: [AppConstants.keyNotifVibration])).firstOrNull?['value'] == 'true';

        await NotificationService.instance.showNotification(
          id: 9999,
          title: 'OrderKart - Today\'s Summary',
          body: buf.toString(),
          payload: 'summary',
          playSound: playSound,
          enableVibration: vibrate,
        );

        // Mark as ran today
        await prefs.setString('last_summary_run_date', todayStr);
      }
    } catch (e) {
      // Background task failed
    }
    return Future.value(true);
  });
}

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._();
  static BackgroundService get instance => _instance;
  
  BackgroundService._();

  Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  void registerDailyTask() {
    Workmanager().registerPeriodicTask(
      'orderkart_daily_summary',
      'dailySummaryTask',
      frequency: const Duration(minutes: 15), // Checks every 15 mins
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep, // Keep existing to avoid resetting timer
    );
  }
}

class SqfliteUtils {
  static int? firstIntValue(List<Map<String, dynamic>> list) {
    if (list.isNotEmpty && list.first.values.isNotEmpty) {
      return list.first.values.first as int?;
    }
    return null;
  }
}
