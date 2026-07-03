/// App Constants — Global configuration values

class AppConstants {
  AppConstants._();

  // App Documents Directory Path (initialized at startup)
  static String appDocsDir = '';

  // App Info
  static const String appName = 'OrderKart';
  static const String appTagline = 'Smart Delivery Management';
  static const String appVersion = '1.0.0';
  static const String appBuild = '1';

  // Database
  static const String dbName = 'orderkart.db';
  static const int dbVersion = 2;

  // Defaults
  static const double defaultDeliveryCharge = 10.0;
  static const String defaultCurrency = '₹';
  static const bool defaultSmartRounding = true;

  // Smart Rounding thresholds
  static const double roundingThreshold = 0.5; // round up if >= x.50

  // Order Status
  static const String statusPending   = 'pending';
  static const String statusDelivered = 'delivered';
  static const String statusCancelled = 'cancelled';

  // Payment Methods
  static const String paymentCash   = 'cash';
  static const String paymentOnline = 'online';
  static const String paymentUPI    = 'upi';
  static const String paymentCard   = 'card';

  // Item Categories
  static const String catVegetables = 'Vegetables';
  static const String catFruits     = 'Fruits';
  static const String catGroceries  = 'Groceries';
  static const String catMedicines  = 'Medicines';

  static const List<String> itemCategories = [
    catVegetables,
    catFruits,
    catGroceries,
    catMedicines,
  ];

  // Item Units
  static const String unitKg     = 'kg';
  static const String unitGram   = 'gram';
  static const String unitLiter  = 'liter';
  static const String unitDozen  = 'dozen';
  static const String unitPiece  = 'piece';
  static const String unitPacket = 'packet';

  static const List<String> itemUnits = [
    unitKg,
    unitGram,
    unitLiter,
    unitDozen,
    unitPiece,
    unitPacket,
  ];

  // Expense Categories
  static const String expTransport   = 'Transport';
  static const String expSalary      = 'Salary';
  static const String expUtilities   = 'Utilities';
  static const String expPackaging   = 'Packaging';
  static const String expMaintenance = 'Maintenance';
  static const String expOther       = 'Other';

  static const List<String> expenseCategories = [
    expTransport,
    expSalary,
    expUtilities,
    expPackaging,
    expMaintenance,
    expOther,
  ];

  // Quantity presets for order creation
  static const List<double> quantityPresets = [
    0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 5.0,
  ];

  // Settings Keys (stored in DB settings table)
  static const String keyBusinessName    = 'business_name';
  static const String keyOwnerName       = 'owner_name';
  static const String keyPhone           = 'phone';
  static const String keyWhatsApp        = 'whatsapp';
  static const String keyDeliveryCharge  = 'delivery_charge';
  static const String keySmartRounding   = 'smart_rounding';
  static const String keyCurrency        = 'currency';
  static const String keyThemeMode       = 'theme_mode';
  static const String keyQrContent       = 'qr_content';
  static const String keyQrCustomImage   = 'qr_custom_image';
  static const String keyNotifications   = 'notifications_enabled';
  static const String keyLowStockAlert   = 'low_stock_alert';
  static const String keyPendingAlert    = 'pending_alert';
  static const String keyBackupReminder  = 'backup_reminder';
  static const String keyStaffWhatsApp   = 'staff_whatsapp';
  static const String keyLastDeliveryCharge = 'last_delivery_charge';

  // Pagination
  static const int pageSize = 30;

  // Notification IDs
  static const int notifLowStock  = 1001;
  static const int notifPending   = 1002;
  static const int notifBackup    = 1003;
}
