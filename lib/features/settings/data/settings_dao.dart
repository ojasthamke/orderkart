import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../domain/app_settings.dart';
import '../../../core/constants/app_constants.dart';

class SettingsDao {
  Future<String?> getValue(String key) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<void> setValue(String key, String value) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AppSettings> loadAllSettings() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('settings');
    final m = <String, String>{};
    for (final row in maps) {
      m[row['key'] as String] = (row['value'] ?? '').toString();
    }
    return AppSettings(
      businessName:         m[AppConstants.keyBusinessName]    ?? 'My Business',
      ownerName:            m[AppConstants.keyOwnerName]       ?? 'Owner',
      phone:                m[AppConstants.keyPhone]           ?? '',
      whatsApp:             m[AppConstants.keyWhatsApp]        ?? '',
      deliveryCharge:       double.tryParse(m[AppConstants.keyDeliveryCharge] ?? '10') ?? 10,
      smartRounding:        (m[AppConstants.keySmartRounding]  ?? 'true') == 'true',
      currency:             m[AppConstants.keyCurrency]        ?? '₹',
      themeMode:            m[AppConstants.keyThemeMode]       ?? 'light',
      notificationsEnabled: (m[AppConstants.keyNotifications]  ?? 'true') == 'true',
      lowStockAlert:        (m[AppConstants.keyLowStockAlert]  ?? 'true') == 'true',
      pendingAlert:         (m[AppConstants.keyPendingAlert]   ?? 'true') == 'true',
      backupReminder:       (m[AppConstants.keyBackupReminder] ?? 'true') == 'true',
      qrContent:            m[AppConstants.keyQrContent]       ?? '',
      qrCustomImage:        m[AppConstants.keyQrCustomImage]   ?? '',
      staffWhatsApp:        m[AppConstants.keyStaffWhatsApp]   ?? '',
      lastDeliveryCharge:   double.tryParse(m[AppConstants.keyLastDeliveryCharge] ?? '10') ?? 10,
      notificationTime:     m[AppConstants.keyNotifTime]       ?? '06:00',
      enableVipPriceMarkup: (m[AppConstants.keyEnableVipPriceMarkup] ?? 'true') == 'true',
      language:             m[AppConstants.keyLanguage]        ?? 'en',
      workerDiscountCap:    double.tryParse(m[AppConstants.keyWorkerDiscountCap] ?? '10') ?? 10.0,
      notificationSound:    (m[AppConstants.keyNotifSound]     ?? 'true') == 'true',
      notificationVibration:(m[AppConstants.keyNotifVibration] ?? 'true') == 'true',
      enableDeliveryCharges:(m[AppConstants.keyEnableDeliveryCharges] ?? 'true') == 'true',
      meshTheme:             m[AppConstants.keyMeshTheme]       ?? 'sunset',
    );
  }
}
