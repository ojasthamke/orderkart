/// AppSettings — strongly-typed settings model
library;

class AppSettings {
  final String businessName;
  final String ownerName;
  final String phone;
  final String whatsApp;
  final double deliveryCharge;
  final bool   smartRounding;
  final String currency;
  final String themeMode;     // light / dark / system
  final bool   notificationsEnabled;
  final bool   lowStockAlert;
  final bool   pendingAlert;
  final bool   backupReminder;
  final String qrContent;
  final String qrCustomImage;
  final String staffWhatsApp;
  final double lastDeliveryCharge;
  final String notificationTime;
  final bool   enableVipPriceMarkup;

  const AppSettings({
    this.businessName      = 'My Business',
    this.ownerName         = 'Owner',
    this.phone             = '',
    this.whatsApp          = '',
    this.deliveryCharge    = 10.0,
    this.smartRounding     = true,
    this.currency          = '₹',
    this.themeMode         = 'light',
    this.notificationsEnabled = true,
    this.lowStockAlert     = true,
    this.pendingAlert      = true,
    this.backupReminder    = true,
    this.qrContent         = '',
    this.qrCustomImage     = '',
    this.staffWhatsApp     = '',
    this.lastDeliveryCharge= 10.0,
    this.notificationTime  = '06:00',
    this.enableVipPriceMarkup = true,
  });

  AppSettings copyWith({
    String? businessName,
    String? ownerName,
    String? phone,
    String? whatsApp,
    double? deliveryCharge,
    bool?   smartRounding,
    String? currency,
    String? themeMode,
    bool?   notificationsEnabled,
    bool?   lowStockAlert,
    bool?   pendingAlert,
    bool?   backupReminder,
    String? qrContent,
    String? qrCustomImage,
    String? staffWhatsApp,
    double? lastDeliveryCharge,
    String? notificationTime,
    bool?   enableVipPriceMarkup,
  }) {
    return AppSettings(
      businessName:       businessName       ?? this.businessName,
      ownerName:          ownerName          ?? this.ownerName,
      phone:              phone              ?? this.phone,
      whatsApp:           whatsApp           ?? this.whatsApp,
      deliveryCharge:     deliveryCharge     ?? this.deliveryCharge,
      smartRounding:      smartRounding      ?? this.smartRounding,
      currency:           currency           ?? this.currency,
      themeMode:          themeMode          ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      lowStockAlert:      lowStockAlert      ?? this.lowStockAlert,
      pendingAlert:       pendingAlert       ?? this.pendingAlert,
      backupReminder:     backupReminder     ?? this.backupReminder,
      qrContent:          qrContent          ?? this.qrContent,
      qrCustomImage:      qrCustomImage      ?? this.qrCustomImage,
      staffWhatsApp:      staffWhatsApp      ?? this.staffWhatsApp,
      lastDeliveryCharge: lastDeliveryCharge ?? this.lastDeliveryCharge,
      notificationTime:   notificationTime   ?? this.notificationTime,
      enableVipPriceMarkup: enableVipPriceMarkup ?? this.enableVipPriceMarkup,
    );
  }
}
