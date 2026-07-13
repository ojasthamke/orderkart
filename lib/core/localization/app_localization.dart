import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/presentation/settings_provider.dart';

class AppLocalization {
  AppLocalization._();

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'settings': 'Settings',
      'theme': 'Theme',
      'language': 'Language',
      'notifications': 'Notifications',
      'backup_report': 'Backup Report',
      'logout': 'Logout Worker Session',
      'appearance': 'Appearance',
      'exit_session': 'Exit Session',
      'data_export': 'Data Export',
      'save_settings': 'Save Settings',
      'enable_notifications': 'Enable Notifications',
      'system': 'System',
      'light': 'Light',
      'dark': 'Dark',
      'english': 'English',
      'hindi': 'Hindi',
      'backup_desc': 'Export Daily WorkerReport.orderkart',
      'logout_desc': 'End worker session and return to mode selection',
      'dashboard': 'Dashboard',
      'route_planner': 'Route Planner',
      'expenses': 'Expenses',
      'analytics': 'Analytics',
      'catalog_showroom': 'Catalog Showroom',
      'create_order': 'Create Order',
      'outstanding_balance': 'Outstanding Balance',
      'save_order': 'Save Order',
      'discount': 'Discount',
      'delivery_charge': 'Delivery Charge',
      'total_amount': 'Total Amount',
    },
    'hi': {
      'settings': 'सेटिंग्स (Settings)',
      'theme': 'थीम (Theme)',
      'language': 'भाषा (Language)',
      'notifications': 'सूचनाएं (Notifications)',
      'backup_report': 'बैकअप रिपोर्ट (Backup Report)',
      'logout': 'सत्र समाप्त करें (Logout)',
      'appearance': 'रूप-रंग (Appearance)',
      'exit_session': 'सत्र समाप्त करें',
      'data_export': 'डेटा निर्यात (Data Export)',
      'save_settings': 'सेटिंग्स सहेजें',
      'enable_notifications': 'सूचनाएं चालू करें',
      'system': 'सिस्टम (System)',
      'light': 'लाइट (Light)',
      'dark': 'डार्क (Dark)',
      'english': 'अंग्रेजी (English)',
      'hindi': 'हिन्दी (Hindi)',
      'backup_desc': 'दैनिक कार्यकर्ता रिपोर्ट निर्यात करें',
      'logout_desc': 'सत्र समाप्त करके मोड चयन स्क्रीन पर वापस जाएं',
      'dashboard': 'डैशबोर्ड (Dashboard)',
      'route_planner': 'मार्ग योजनाकार (Route Planner)',
      'expenses': 'व्यय (Expenses)',
      'analytics': 'विश्लेषण (Analytics)',
      'catalog_showroom': 'कैटलॉग शोरूम (Catalog Showroom)',
      'create_order': 'ऑर्डर बनाएं (Create Order)',
      'outstanding_balance': 'बकाया राशि (Outstanding Balance)',
      'save_order': 'ऑर्डर सहेजें (Save Order)',
      'discount': 'छूट (Discount)',
      'delivery_charge': 'डिलिवरी शुल्क (Delivery Charge)',
      'total_amount': 'कुल राशि (Total Amount)',
    }
  };

  static String translate(WidgetRef ref, String key, String defaultVal) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final lang = settings?.language ?? 'en';
    return _localizedValues[lang]?[key] ?? defaultVal;
  }
}
