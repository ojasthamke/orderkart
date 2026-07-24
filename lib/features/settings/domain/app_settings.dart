/// AppSettings — strongly-typed settings model
library;

class AppSettings {
  final String businessName;
  final String ownerName;
  final String phone;
  final String whatsApp;
  final double deliveryCharge;
  final bool smartRounding;
  final String currency;
  final String themeMode; // light / dark / system
  final bool notificationsEnabled;
  final bool lowStockAlert;
  final bool pendingAlert;
  final bool backupReminder;
  final String qrContent;
  final String qrCustomImage;
  final String staffWhatsApp;
  final double lastDeliveryCharge;
  final String notificationTime;
  final bool enableVipPriceMarkup;
  final String language;
  final double workerDiscountCap;
  final bool notificationSound;
  final bool notificationVibration;

  final bool enableDeliveryCharges;
  final String meshTheme;
  final String invoiceDisclaimer;

  const AppSettings({
    this.businessName = 'My Business',
    this.ownerName = 'Owner',
    this.phone = '',
    this.whatsApp = '',
    this.deliveryCharge = 10.0,
    this.smartRounding = true,
    this.currency = '₹',
    this.themeMode = 'dark',
    this.notificationsEnabled = true,
    this.lowStockAlert = true,
    this.pendingAlert = true,
    this.backupReminder = true,
    this.qrContent = '',
    this.qrCustomImage = '',
    this.staffWhatsApp = '',
    this.lastDeliveryCharge = 10.0,
    this.notificationTime = '06:00',
    this.enableVipPriceMarkup = true,
    this.language = 'en',
    this.workerDiscountCap = 10.0,
    this.notificationSound = true,
    this.notificationVibration = true,
    this.enableDeliveryCharges = true,
    this.meshTheme = 'sunset',
    this.invoiceDisclaimer =
        'Thank you for shopping with us! Fresh quality items delivered directly to your doorstep. Please inspect your order upon delivery.',
  });

  AppSettings copyWith({
    String? businessName,
    String? ownerName,
    String? phone,
    String? whatsApp,
    double? deliveryCharge,
    bool? smartRounding,
    String? currency,
    String? themeMode,
    bool? notificationsEnabled,
    bool? lowStockAlert,
    bool? pendingAlert,
    bool? backupReminder,
    String? qrContent,
    String? qrCustomImage,
    String? staffWhatsApp,
    double? lastDeliveryCharge,
    String? notificationTime,
    bool? enableVipPriceMarkup,
    String? language,
    double? workerDiscountCap,
    bool? notificationSound,
    bool? notificationVibration,
    bool? enableDeliveryCharges,
    String? meshTheme,
    String? invoiceDisclaimer,
  }) {
    return AppSettings(
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      whatsApp: whatsApp ?? this.whatsApp,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      smartRounding: smartRounding ?? this.smartRounding,
      currency: currency ?? this.currency,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      lowStockAlert: lowStockAlert ?? this.lowStockAlert,
      pendingAlert: pendingAlert ?? this.pendingAlert,
      backupReminder: backupReminder ?? this.backupReminder,
      qrContent: qrContent ?? this.qrContent,
      qrCustomImage: qrCustomImage ?? this.qrCustomImage,
      staffWhatsApp: staffWhatsApp ?? this.staffWhatsApp,
      lastDeliveryCharge: lastDeliveryCharge ?? this.lastDeliveryCharge,
      notificationTime: notificationTime ?? this.notificationTime,
      enableVipPriceMarkup: enableVipPriceMarkup ?? this.enableVipPriceMarkup,
      language: language ?? this.language,
      workerDiscountCap: workerDiscountCap ?? this.workerDiscountCap,
      notificationSound: notificationSound ?? this.notificationSound,
      notificationVibration:
          notificationVibration ?? this.notificationVibration,
      enableDeliveryCharges:
          enableDeliveryCharges ?? this.enableDeliveryCharges,
      meshTheme: meshTheme ?? this.meshTheme,
      invoiceDisclaimer: invoiceDisclaimer ?? this.invoiceDisclaimer,
    );
  }
}
