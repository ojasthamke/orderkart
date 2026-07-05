import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import 'settings_provider.dart';

class BusinessProfileScreen extends ConsumerStatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  ConsumerState<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends ConsumerState<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _businessNameCon;
  late TextEditingController _ownerNameCon;
  late TextEditingController _phoneCon;
  late TextEditingController _whatsAppCon;
  late TextEditingController _currencyCon;
  late TextEditingController _qrContentCon;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider).valueOrNull;
    _businessNameCon = TextEditingController(text: settings?.businessName ?? 'OrderKart');
    _ownerNameCon = TextEditingController(text: settings?.ownerName ?? '');
    _phoneCon = TextEditingController(text: settings?.phone ?? '');
    _whatsAppCon = TextEditingController(text: settings?.whatsApp ?? '');
    _currencyCon = TextEditingController(text: settings?.currency ?? '₹');
    _qrContentCon = TextEditingController(text: settings?.qrContent ?? '');
  }

  @override
  void dispose() {
    _businessNameCon.dispose();
    _ownerNameCon.dispose();
    _phoneCon.dispose();
    _whatsAppCon.dispose();
    _currencyCon.dispose();
    _qrContentCon.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    AppHaptics.buttonClick();

    final current = ref.read(settingsProvider).valueOrNull;
    if (current != null) {
      final updated = current.copyWith(
        businessName: _businessNameCon.text.trim(),
        ownerName: _ownerNameCon.text.trim(),
        phone: _phoneCon.text.trim(),
        whatsApp: _whatsAppCon.text.trim(),
        currency: _currencyCon.text.trim(),
        qrContent: _qrContentCon.text.trim(),
      );
      await ref.read(settingsProvider.notifier).update(updated);
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Business Profile updated successfully!');
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Business Profile',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.storefront_rounded, color: AppColors.primary, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Business & Invoice Branding',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _businessNameCon,
                decoration: const InputDecoration(
                  labelText: 'Business Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter business name' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _ownerNameCon,
                decoration: const InputDecoration(
                  labelText: 'Owner Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCon,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _whatsAppCon,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.chat_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _qrContentCon,
                decoration: const InputDecoration(
                  labelText: 'UPI Payment ID / QR String',
                  hintText: 'upi://pay?pa=owner@upi&pn=Store',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Business Profile', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
