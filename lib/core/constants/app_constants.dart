import 'dart:io';
import 'package:path/path.dart' as p;

/// App Constants — Global configuration values

class AppConstants {
  AppConstants._();

  // App Documents Directory Path (initialized at startup)
  static String appDocsDir = '';

  static File resolveFile(String originalPath) {
    if (originalPath.isEmpty) return File('');
    final file = File(originalPath);
    if (file.existsSync()) return file;
    if (appDocsDir.isNotEmpty) {
      final filename = p.basename(originalPath);
      final fallbackFile = File('$appDocsDir/customer_photos/$filename');
      if (fallbackFile.existsSync()) {
        return fallbackFile;
      }
    }
    return file;
  }

  // App Info
  static const String appName = 'OrderKart';
  static const String appTagline = 'Smart Delivery Management';
  static const String appVersion = '1.0.0';
  static const String appBuild = '2';

  // Database
  static const String dbName = 'orderkart.db';
  static const int dbVersion = 9;

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
  static const String expTransport      = 'Transport';
  static const String expSalary         = 'Salary';
  static const String expUtilities      = 'Utilities';
  static const String expPackaging      = 'Packaging';
  static const String expMaintenance    = 'Maintenance';
  static const String expFreight        = '🚚 Freight & Tempo';
  static const String expSpoilageLoss   = '🍏 Spoilage & Damaged Goods';
  static const String expMandiFees      = '🏪 Mandi Tax & APMC Fees';
  static const String expStoreUtilities = '💡 Electricity & Store Rent';
  static const String expPackagingCrates= '📦 Packaging, Bags & Crates';
  static const String expOther          = 'Other';

  static const List<String> expenseCategories = [
    expTransport,
    expSalary,
    expUtilities,
    expPackaging,
    expMaintenance,
    expFreight,
    expSpoilageLoss,
    expMandiFees,
    expStoreUtilities,
    expPackagingCrates,
    expOther,
  ];

  // Quantity presets for order creation
  static const List<double> quantityPresets = [
    0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 5.0,
  ];

  static List<double> getPresetsForUnit(String unit) {
    final normalized = unit.trim().toLowerCase();
    switch (normalized) {
      case 'kg':
      case 'kilo':
      case 'kilogram':
      case 'kilograms':
      case 'gram':
      case 'grams':
      case 'g':
        return [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 3.0, 5.0, 10.0];
        
      case 'liter':
      case 'litre':
      case 'liters':
      case 'litres':
      case 'l':
      case 'ml':
      case 'ltr':
      case 'ltrs':
        return [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 5.0, 10.0];

      case 'dozen':
      case 'dozens':
      case 'dz':
        return [0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 10.0];

      case 'piece':
      case 'pieces':
      case 'pc':
      case 'pcs':
      case 'packet':
      case 'packets':
      case 'pkt':
      case 'box':
      case 'boxes':
      case 'unit':
      case 'units':
      case 'bottle':
      case 'bottles':
      case 'can':
      case 'cans':
        return [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 10.0, 12.0, 15.0, 20.0, 25.0];

      default:
        return [1.0, 2.0, 3.0, 4.0, 5.0, 10.0, 15.0, 20.0];
    }
  }

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
  
  // Notification Settings Keys
  static const String keyNotifications   = 'notifications_enabled';
  static const String keyDailySummary    = 'daily_summary_enabled';
  static const String keyLowStockAlert   = 'low_stock_alert';
  static const String keyPendingAlert    = 'pending_alert';
  static const String keyVisitAlert      = 'visit_alert_enabled';
  static const String keyNoteReminders   = 'note_reminders_enabled';
  static const String keyNotifTime       = 'notification_time';
  static const String keyNotifSound      = 'notification_sound';
  static const String keyNotifVibration  = 'notification_vibration';
  static const String keyBackupReminder  = 'backup_reminder';
  
  static const String keyStaffWhatsApp   = 'staff_whatsapp';
  static const String keyLastDeliveryCharge = 'last_delivery_charge';
  static const String keyEnableVipPriceMarkup = 'enable_vip_price_markup';
  static const String keyOwnerSecret = 'owner_secret';
  static const String keyLanguage = 'language';
  static const String keyWorkerDiscountCap = 'worker_discount_cap';

  // Pagination
  static const int pageSize = 30;

  // Notification IDs
  static const int notifLowStock  = 1001;
  static const int notifPending   = 1002;
  static const int notifBackup    = 1003;
}
