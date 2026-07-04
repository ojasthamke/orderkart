import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/settings_dao.dart';
import '../domain/app_settings.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../order/presentation/order_provider.dart';
import '../../area/presentation/area_provider.dart';
import '../../street/presentation/street_provider.dart';
import '../../customer/presentation/customer_provider.dart';
import '../../inventory/presentation/inventory_provider.dart';

class SettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  final Ref _ref;
  final SettingsDao _dao;

  SettingsNotifier(this._ref, this._dao) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final settings = await _dao.loadAllSettings();
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _invalidateAll() {
    _ref.invalidate(settingsProvider);
    _ref.invalidate(themeModeProvider);
    _ref.invalidate(analyticsSummaryProvider);
    _ref.invalidate(areaProvider);
    _ref.invalidate(streetProviderFamily);
    _ref.invalidate(customerListProvider);
    _ref.invalidate(customerDetailProvider);
    _ref.invalidate(orderManagementProvider);
    _ref.invalidate(customerOrdersProvider);
    _ref.invalidate(orderDetailProvider);
    _ref.invalidate(inventoryProvider);
    _ref.invalidate(lowStockProvider);
    _ref.invalidate(stockHistoryProvider);
    _ref.invalidate(topCustomersProvider);
    _ref.invalidate(dashboardOrdersProvider);
  }

  Future<void> update(AppSettings settings) async {
    await _dao.setValue(AppConstants.keyBusinessName,       settings.businessName);
    await _dao.setValue(AppConstants.keyOwnerName,          settings.ownerName);
    await _dao.setValue(AppConstants.keyPhone,              settings.phone);
    await _dao.setValue(AppConstants.keyWhatsApp,           settings.whatsApp);
    await _dao.setValue(AppConstants.keyDeliveryCharge,     settings.deliveryCharge.toString());
    await _dao.setValue(AppConstants.keySmartRounding,      settings.smartRounding.toString());
    await _dao.setValue(AppConstants.keyCurrency,           settings.currency);
    await _dao.setValue(AppConstants.keyThemeMode,          settings.themeMode);
    await _dao.setValue(AppConstants.keyNotifications,      settings.notificationsEnabled.toString());
    await _dao.setValue(AppConstants.keyLowStockAlert,      settings.lowStockAlert.toString());
    await _dao.setValue(AppConstants.keyPendingAlert,       settings.pendingAlert.toString());
    await _dao.setValue(AppConstants.keyBackupReminder,     settings.backupReminder.toString());
    await _dao.setValue(AppConstants.keyQrContent,          settings.qrContent);
    await _dao.setValue(AppConstants.keyQrCustomImage,      settings.qrCustomImage);
    await _dao.setValue(AppConstants.keyStaffWhatsApp,      settings.staffWhatsApp);
    await _dao.setValue(AppConstants.keyLastDeliveryCharge, settings.lastDeliveryCharge.toString());
    await _dao.setValue(AppConstants.keyNotifTime,          settings.notificationTime);
    await _dao.setValue(AppConstants.keyEnableVipPriceMarkup, settings.enableVipPriceMarkup.toString());
    state = AsyncValue.data(settings);
    _invalidateAll();
  }

  Future<void> updateLastDeliveryCharge(double charge) async {
    await _dao.setValue(AppConstants.keyLastDeliveryCharge, charge.toString());
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(lastDeliveryCharge: charge));
    }
    _invalidateAll();
  }

  Future<void> resetApp() async {
    await DatabaseHelper.instance.resetDatabase();
    await load();
    _invalidateAll();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AsyncValue<AppSettings>>(
        (ref) => SettingsNotifier(ref, SettingsDao()));

final themeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings == null) return ThemeMode.light;
  switch (settings.themeMode) {
    case 'dark':   return ThemeMode.dark;
    case 'system': return ThemeMode.system;
    case 'light':
    default:       return ThemeMode.light;
  }
});
