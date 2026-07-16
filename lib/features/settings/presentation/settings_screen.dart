import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/worker_session.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../domain/app_settings.dart';
import 'settings_provider.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/localization/app_localization.dart';

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
  final _deliveryChargeCon = TextEditingController();
  final _workerDiscountCapCon = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _bizNameCon.dispose(); _ownerCon.dispose(); _phoneCon.dispose();
    _waCon.dispose(); _staffWaCon.dispose(); _qrCon.dispose();
    _deliveryChargeCon.dispose();
    _workerDiscountCapCon.dispose();
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
    _deliveryChargeCon.text = s.deliveryCharge.toStringAsFixed(0);
    _workerDiscountCapCon.text = s.workerDiscountCap.toStringAsFixed(0);
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

  Future<void> _pickQrImage(AppSettings current) async {
    final img = await ImageUtils.pickAndCompress(source: ImageSource.gallery);
    if (img != null) {
      // Delete old QR image to prevent bloat
      if (current.qrCustomImage.isNotEmpty) {
        final oldFile = File(current.qrCustomImage);
        if (oldFile.existsSync()) {
          try { oldFile.deleteSync(); } catch (_) {}
        }
      }

      final savedPath = await ImageUtils.saveImagePermanently(
        sourcePath: img.path,
        subFolder: 'qr_codes',
        fileName: 'qr_custom_image',
      );

      if (savedPath != null) {
        await ref.read(settingsProvider.notifier).update(
              current.copyWith(qrCustomImage: savedPath),
            );
        if (mounted) SnackbarHelper.showSuccess(context, 'QR Code image uploaded');
      }
    }
  }

  Future<void> _deleteQrImage(AppSettings current) async {
    final ok = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete QR Code Image',
      message: 'Are you sure you want to delete the business QR code image?',
    );
    if (!ok) return;

    if (current.qrCustomImage.isNotEmpty) {
      final file = AppConstants.resolveFile(current.qrCustomImage);
      if (file.existsSync()) {
        try { file.deleteSync(); } catch (_) {}
      }
    }

    await ref.read(settingsProvider.notifier).update(
          current.copyWith(qrCustomImage: ''),
        );
    if (mounted) SnackbarHelper.showSuccess(context, 'QR Code image deleted');
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
        final isWorker = WorkerSession.instance.isWorker;
        return AppScaffold(
          title: AppLocalization.translate(ref, 'settings', 'Settings'),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Business Info ───────────────────────────────────────
              _sectionHeader('Business Info', Icons.business_rounded),
              _card([
                _textTile('Business Name', _bizNameCon, Icons.storefront_rounded),
                _textTile('Owner Name', _ownerCon, Icons.person_rounded),
                _textTile('Phone', _phoneCon, Icons.phone_rounded, keyboardType: TextInputType.phone),
                _textTile('WhatsApp', _waCon, Icons.chat_rounded, keyboardType: TextInputType.phone),
                _textTile('Staff Telegram Link / Username', _staffWaCon, Icons.send_rounded, keyboardType: TextInputType.text),
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.right,
                      controller: _deliveryChargeCon,
                      onChanged: (v) {
                        final d = double.tryParse(v);
                        if (d != null) {
                          ref.read(settingsProvider.notifier).update(settings.copyWith(deliveryCharge: d));
                        }
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '0.0',
                        prefixText: settings.currency,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.calculate_rounded),
                  title: const Text('Smart Rounding'),
                  value: settings.smartRounding,
                  onChanged: (v) => ref.read(settingsProvider.notifier).update(settings.copyWith(smartRounding: v)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.monetization_on_rounded),
                  title: const Text('Currency Symbol'),
                  trailing: DropdownButton<String>(
                    value: settings.currency,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: '₹', child: Text('INR (₹)')),
                      DropdownMenuItem(value: '\$', child: Text('USD (\$)')),
                      DropdownMenuItem(value: '€', child: Text('EUR (€)')),
                      DropdownMenuItem(value: '£', child: Text('GBP (£)')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(settingsProvider.notifier).update(settings.copyWith(currency: v));
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.trending_up_rounded),
                  title: const Text('Enable VIP Price Markup (10%)'),
                  value: settings.enableVipPriceMarkup,
                  onChanged: (v) => ref.read(settingsProvider.notifier).update(settings.copyWith(enableVipPriceMarkup: v)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.percent_rounded),
                  title: const Text('Worker Allowed Discount Cap'),
                  trailing: SizedBox(
                    width: 80,
                    child: TextField(
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.right,
                      controller: _workerDiscountCapCon,
                      onChanged: (v) {
                        final val = double.tryParse(v);
                        if (val != null) {
                          ref.read(settingsProvider.notifier).update(settings.copyWith(workerDiscountCap: val));
                        }
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '10.0',
                        suffixText: '%',
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _save(settings),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Order Defaults'),
                ),
              ),

              const SizedBox(height: 20),

              // ── UPI Payments & QR Code ─────────────────────────────
              _sectionHeader('UPI Payments & QR Code', Icons.qr_code_rounded),
              _card([
                ListTile(
                  leading: const Icon(Icons.payment_rounded),
                  title: const Text('UPI ID (for payments)'),
                  trailing: SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _qrCon,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'merchant@upi',
                      ),
                      onSubmitted: (_) => _save(settings),
                    ),
                  ),
                ),
                const Divider(height: 1),
                if (settings.qrCustomImage.isNotEmpty) ...[
                  ListTile(
                    leading: const Icon(Icons.image_rounded),
                    title: const Text('Custom QR Image Uploaded'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                      onPressed: () => _deleteQrImage(settings),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.qrPreview,
                          arguments: {'qrCustomImage': settings.qrCustomImage},
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.gray200),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: Image.file(
                            AppConstants.resolveFile(settings.qrCustomImage),
                            width: 150,
                            height: 150,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Text('Broken Custom QR Image'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickQrImage(settings),
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Upload QR Image'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (settings.qrContent.isNotEmpty) ...[
                    const Center(
                      child: Text('Generated UPI QR Code:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.qrPreview,
                          arguments: {'qrContent': settings.qrContent},
                        ),
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
                    ),
                  ],
                ],
                const SizedBox(height: 12),
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

              // ── Notifications ────────────────────────────────────────
              _sectionHeader(AppLocalization.translate(ref, 'notifications', 'Notifications'), Icons.notifications_rounded),
              _card([
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_rounded),
                  title: Text(AppLocalization.translate(ref, 'enable_notifications', 'Enable Notifications')),
                  value: settings.notificationsEnabled,
                  onChanged: (v) => ref.read(settingsProvider.notifier).update(settings.copyWith(notificationsEnabled: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.warning_amber_rounded),
                  title: Text(AppLocalization.translate(ref, 'low_stock_alert', 'Low Stock Alert')),
                  value: settings.lowStockAlert,
                  onChanged: settings.notificationsEnabled
                      ? (v) => ref.read(settingsProvider.notifier).update(settings.copyWith(lowStockAlert: v))
                      : null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.payments_rounded),
                  title: Text(AppLocalization.translate(ref, 'pending_alert', 'Pending Payment Alert')),
                  value: settings.pendingAlert,
                  onChanged: settings.notificationsEnabled
                      ? (v) => ref.read(settingsProvider.notifier).update(settings.copyWith(pendingAlert: v))
                      : null,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.backup_rounded),
                  title: Text(AppLocalization.translate(ref, 'backup_reminder', 'Daily Backup Reminder')),
                  value: settings.backupReminder,
                  onChanged: settings.notificationsEnabled
                      ? (v) => ref.read(settingsProvider.notifier).update(settings.copyWith(backupReminder: v))
                      : null,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_rounded),
                  title: Text(AppLocalization.translate(ref, 'notification_sound', 'Notification Sound (Preview Tone)')),
                  value: settings.notificationSound,
                  onChanged: settings.notificationsEnabled
                      ? (v) => ref.read(settingsProvider.notifier).update(settings.copyWith(notificationSound: v))
                      : null,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration_rounded),
                  title: Text(AppLocalization.translate(ref, 'notification_vibration', 'Notification Vibration (Tactile Feel)')),
                  value: settings.notificationVibration,
                  onChanged: settings.notificationsEnabled
                      ? (v) => ref.read(settingsProvider.notifier).update(settings.copyWith(notificationVibration: v))
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

              // ── Cloud Sync (coming soon) ─────────────────────────
              _sectionHeader('Cloud Sync (Coming Soon)', Icons.cloud_sync_rounded),
              _card([
                _comingSoonTile('Enable Cloud Backup', Icons.cloud_upload_rounded),
                _comingSoonTile('Google Drive Backup', Icons.add_to_drive_rounded),
                _comingSoonTile('GitHub JSON Backup',  Icons.code_rounded),
                _comingSoonTile('Sync to Server',      Icons.sync_rounded),
              ]),

              const SizedBox(height: 20),

              // ── Account (coming soon) ────────────────────────────
              _sectionHeader('Account (Coming Soon)', Icons.account_circle_rounded),
              _card([
                _comingSoonTile('Login / Sign Up', Icons.login_rounded),
                _comingSoonTile('Multi-Device Sync', Icons.devices_rounded),
              ]),

              const SizedBox(height: 20),

              // ── Storage & Cache ──────────────────────────────────
              _sectionHeader('Storage & Cache', Icons.storage_rounded),
              _card([
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded, color: Colors.orange),
                  title: const Text('Clean Image Cache'),
                  subtitle: const Text('Free up local cache from temporary pick files'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () async {
                    await ImageUtils.clearImagePickerCache();
                    if (mounted) {
                      SnackbarHelper.showSuccess(context, 'Image picker cache cleaned successfully.');
                    }
                  },
                ),
              ]),



              const SizedBox(height: 20),

              // ── Danger Zone ────────────────────────────────────────
              _sectionHeader('Danger Zone', Icons.warning_rounded, color: AppColors.error),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                  title: const Text('Reset App', style: TextStyle(color: AppColors.error)),
                  subtitle: const Text('Delete all data permanently'),
                  onTap: () async {
                    final ok = await ConfirmDeleteDialog.show(
                      context,
                      title: 'Reset App',
                      message: 'This will permanently delete ALL data (areas, streets, customers, orders, inventory, expenses). This cannot be undone!',
                      confirmLabel: 'Yes, Reset Everything',
                    );
                    if (!ok || !mounted) return;
                    await ref.read(settingsProvider.notifier).resetApp();
                    if (mounted) {
                      SnackbarHelper.showSuccess(context, 'App data reset successfully');
                    }
                  },
                ),
              ),

              const SizedBox(height: 20),

              // ── Data Export & Exit Session (Worker only) ─────────
              if (isWorker) ...[
                _sectionHeader(AppLocalization.translate(ref, 'data_export', 'Data Export'), Icons.cloud_upload_rounded),
                _card([
                  ListTile(
                    leading: const Icon(Icons.backup_rounded, color: AppColors.primary),
                    title: Text(AppLocalization.translate(ref, 'backup_report', 'Backup Report')),
                    subtitle: Text(AppLocalization.translate(ref, 'backup_desc', 'Export Daily WorkerReport.orderkart')),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () async {
                      Navigator.pushNamed(context, AppRoutes.workerSelfProfile);
                    },
                  ),
                ]),
                const SizedBox(height: 20),

                _sectionHeader(AppLocalization.translate(ref, 'exit_session', 'Exit Session'), Icons.exit_to_app_rounded),
                _card([
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                    title: Text(AppLocalization.translate(ref, 'logout', 'Logout Worker Session')),
                    subtitle: Text(AppLocalization.translate(ref, 'logout_desc', 'End worker session and return to mode selection')),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      WorkerSession.instance.clear();
                      SnackbarHelper.showInfo(context, 'Worker logged out.');
                      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.modeSelection, (r) => false);
                    },
                  ),
                ]),
              ],
              const SizedBox(height: 32),

              // ── Official App Branding Footer ────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppColors.cardShadow,
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.local_mall_rounded,
                            color: AppColors.primary,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'OrderKart v1.0.0',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Smart Delivery Management System',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
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
    return GlassContainer(
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
