import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../domain/app_settings.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _bizNameCon = TextEditingController();
  final _ownerCon   = TextEditingController();
  final _phoneCon   = TextEditingController();
  final _waCon      = TextEditingController();
  final _staffWaCon = TextEditingController();
  final _qrCon      = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _bizNameCon.dispose(); _ownerCon.dispose(); _phoneCon.dispose();
    _waCon.dispose(); _staffWaCon.dispose(); _qrCon.dispose();
    super.dispose();
  }

  void _init(AppSettings s) {
    if (_initialized) return;
    _bizNameCon.text = s.businessName;
    _ownerCon.text   = s.ownerName;
    _phoneCon.text   = s.phone;
    _waCon.text      = s.whatsApp;
    _staffWaCon.text = s.staffWhatsApp;
    _qrCon.text      = s.qrContent;
    _initialized     = true;
  }

  Future<void> _save(AppSettings current) async {
    await ref.read(settingsProvider.notifier).update(
          current.copyWith(
            businessName: _bizNameCon.text.trim(),
            ownerName:    _ownerCon.text.trim(),
            phone:        _phoneCon.text.trim(),
            whatsApp:     _waCon.text.trim(),
            staffWhatsApp:_staffWaCon.text.trim(),
            qrContent:    _qrCon.text.trim(),
          ),
        );
    if (mounted) SnackbarHelper.showSuccess(context, 'Settings saved');
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => const AppScaffold(
          title: 'Settings',
          showBack: true,
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => AppScaffold(
          title: 'Settings',
          body: Center(child: Text('Error: $e'))),
      data: (settings) {
        _init(settings);
        return AppScaffold(
          title: 'Settings',
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Business Info ───────────────────────────────────────
              _sectionHeader('Business Info', Icons.business_rounded),
              _card([
                _textTile('Business Name', _bizNameCon,
                    Icons.storefront_rounded),
                _textTile('Owner Name', _ownerCon, Icons.person_rounded),
                _textTile('Phone', _phoneCon, Icons.phone_rounded,
                    keyboardType: TextInputType.phone),
                _textTile('WhatsApp', _waCon, Icons.chat_rounded,
                    keyboardType: TextInputType.phone),
                _textTile('Staff WhatsApp Group', _staffWaCon,
                    Icons.groups_rounded,
                    keyboardType: TextInputType.phone),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _save(settings),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Business Info'),
                ),
              ),

              const SizedBox(height: 20),

              // ── Order Defaults ────────────────────────────────────
              _sectionHeader('Order Defaults', Icons.shopping_cart_rounded),
              _card([
                ListTile(
                  leading: const Icon(Icons.delivery_dining_rounded),
                  title: const Text('Default Delivery Charge'),
                  trailing: SizedBox(
                    width: 80,
                    child: TextField(
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textAlign: TextAlign.right,
                      controller: TextEditingController(
                          text: settings.deliveryCharge.toStringAsFixed(0)),
                      onChanged: (v) {
                        final d = double.tryParse(v);
                        if (d != null) {
                          ref.read(settingsProvider.notifier).update(
                              settings.copyWith(deliveryCharge: d));
                        }
                      },
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        prefixText: '₹',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.auto_fix_high_rounded),
                  title: const Text('Smart Bill Rounding'),
                  subtitle: const Text('Rounds bill to nearest 5/10'),
                  value: settings.smartRounding,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .update(settings.copyWith(smartRounding: v)),
                ),
              ]),

              const SizedBox(height: 20),

              // ── QR Code ──────────────────────────────────────────────
              _sectionHeader('Business QR Code', Icons.qr_code_rounded),
              _card([
                _textTile('QR Content (UPI / URL / Text)', _qrCon,
                    Icons.qr_code_2_rounded),
                const SizedBox(height: 8),
                if (settings.qrContent.isNotEmpty)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: QrImageView(
                        data: settings.qrContent,
                        version: QrVersions.auto,
                        size: 150.0,
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _save(settings),
                  icon: const Icon(Icons.qr_code_rounded),
                  label: const Text('Save QR Code'),
                ),
              ),

              const SizedBox(height: 20),

              // ── Theme ─────────────────────────────────────────────────
              _sectionHeader('Appearance', Icons.palette_rounded),
              _card([
                ListTile(
                  leading: const Icon(Icons.light_mode_rounded),
                  title: const Text('Theme'),
                  trailing: DropdownButton<String>(
                    value: settings.themeMode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'system', child: Text('System')),
                      DropdownMenuItem(value: 'light',  child: Text('Light')),
                      DropdownMenuItem(value: 'dark',   child: Text('Dark')),
                    ],
                    onChanged: (v) => ref
                        .read(settingsProvider.notifier)
                        .update(settings.copyWith(themeMode: v ?? 'system')),
                  ),
                ),
              ]),

              const SizedBox(height: 20),

              // ── Notifications ────────────────────────────────────────
              _sectionHeader('Notifications', Icons.notifications_rounded),
              _card([
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_rounded),
                  title: const Text('Enable Notifications'),
                  value: settings.notificationsEnabled,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .update(settings.copyWith(notificationsEnabled: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.warning_amber_rounded),
                  title: const Text('Low Stock Alert'),
                  value: settings.lowStockAlert,
                  onChanged: settings.notificationsEnabled
                      ? (v) => ref
                          .read(settingsProvider.notifier)
                          .update(settings.copyWith(lowStockAlert: v))
                      : null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.payments_rounded),
                  title: const Text('Pending Payment Alert'),
                  value: settings.pendingAlert,
                  onChanged: settings.notificationsEnabled
                      ? (v) => ref
                          .read(settingsProvider.notifier)
                          .update(settings.copyWith(pendingAlert: v))
                      : null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.backup_rounded),
                  title: const Text('Daily Backup Reminder'),
                  value: settings.backupReminder,
                  onChanged: settings.notificationsEnabled
                      ? (v) => ref
                          .read(settingsProvider.notifier)
                          .update(settings.copyWith(backupReminder: v))
                      : null,
                ),
              ]),

              const SizedBox(height: 20),

              // ── Backup & Restore ──────────────────────────────────
              _sectionHeader('Backup & Data', Icons.cloud_upload_rounded),
              _card([
                ListTile(
                  leading: const Icon(Icons.backup_rounded),
                  title: const Text('Backup & Restore'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.backupRestore),
                ),
              ]),

              const SizedBox(height: 20),

              // ── Cloud Sync (future) ──────────────────────────────
              _sectionHeader('Cloud Sync (Coming Soon)', Icons.cloud_sync_rounded),
              _card([
                _comingSoonTile('Enable Cloud Backup', Icons.cloud_upload_rounded),
                _comingSoonTile('Google Drive Backup', Icons.add_to_drive_rounded),
                _comingSoonTile('GitHub JSON Backup',  Icons.code_rounded),
                _comingSoonTile('Sync to Server',      Icons.sync_rounded),
              ]),

              const SizedBox(height: 20),

              // ── Account (future) ─────────────────────────────────
              _sectionHeader('Account (Coming Soon)', Icons.account_circle_rounded),
              _card([
                _comingSoonTile('Login / Sign Up', Icons.login_rounded),
                _comingSoonTile('Multi-Device Sync', Icons.devices_rounded),
              ]),

              const SizedBox(height: 20),

              // ── About & Privacy ─────────────────────────────────
              _sectionHeader('About', Icons.info_rounded),
              _card([
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About FreshFlow'),
                  subtitle: const Text('v1.0.0'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'FreshFlow • OrderKart',
                    applicationVersion: '1.0.0',
                    applicationLegalese:
                        '© 2024 FreshFlow. All rights reserved.',
                    children: [
                      const Text(
                          'An offline-first order management app for delivery businesses.'),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_rounded),
                  title: const Text('Privacy Policy'),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Privacy Policy'),
                      content: const SingleChildScrollView(
                        child: Text(
                          'FreshFlow stores all data locally on your device. No data is transmitted to any server unless you explicitly enable cloud sync. We do not collect any personal information.\n\nAll your business data including customers, orders, and inventory is stored in a local SQLite database on your device.\n\nFor questions, contact the developer.',
                        ),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close')),
                      ],
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 20),

              // ── Danger Zone ────────────────────────────────────────
              _sectionHeader('Danger Zone', Icons.warning_rounded,
                  color: AppColors.error),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.delete_forever_rounded,
                      color: AppColors.error),
                  title: const Text('Reset App',
                      style: TextStyle(color: AppColors.error)),
                  subtitle: const Text('Delete all data permanently'),
                  onTap: () async {
                    final ok = await ConfirmDeleteDialog.show(
                      context,
                      title: 'Reset App',
                      message:
                          'This will permanently delete ALL data (areas, streets, customers, orders, inventory, expenses). This cannot be undone!',
                      confirmLabel: 'Yes, Reset Everything',
                    );
                    if (!ok || !mounted) return;
                    await ref.read(settingsProvider.notifier).resetApp();
                    if (mounted)
                      SnackbarHelper.showSuccess(
                          context, 'App data reset successfully');
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color ?? AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _textTile(String label, TextEditingController con, IconData icon,
      {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: TextField(
        controller: con,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _comingSoonTile(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppColors.gray400),
      title: Text(title, style: const TextStyle(color: AppColors.gray500)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Soon',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.gray500,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
