import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();

  static Future<void> requestPermissions() async {
    // Request Notification Permission (Android 13+)
    final notifStatus = await Permission.notification.status;
    if (notifStatus.isDenied) {
      await Permission.notification.request();
    }

    // Request Exact Alarms Permission (Android 12+)
    final alarmStatus = await Permission.scheduleExactAlarm.status;
    if (alarmStatus.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }
}
