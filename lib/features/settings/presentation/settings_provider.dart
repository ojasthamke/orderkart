import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/settings_dao.dart';
import '../domain/app_settings.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';

class SettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  final SettingsDao _dao;

  SettingsNotifier(this._dao) : super(const AsyncValue.loading()) {
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
    state = AsyncValue.data(settings);
  }

  Future<void> updateLastDeliveryCharge(double charge) async {
    await _dao.setValue(AppConstants.keyLastDeliveryCharge, charge.toString());
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(lastDeliveryCharge: charge));
    }
  }

  Future<void> resetApp() async {
    await DatabaseHelper.instance.resetDatabase();
    await load();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AsyncValue<AppSettings>>(
        (ref) => SettingsNotifier(SettingsDao()));

final themeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider).value;
  switch (settings?.themeMode) {
    case 'light':  return ThemeMode.light;
    case 'dark':   return ThemeMode.dark;
    default:       return ThemeMode.system;
  }
});
