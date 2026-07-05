// lib/features/settings/presentation/business_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/models/business_profile.dart';
import '../../../core/services/business_profile_service.dart';

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
  late TextEditingController _emailCon;
  late TextEditingController _addressCon;
  late TextEditingController _gstCon;
  late TextEditingController _upiCon;
  late TextEditingController _bankCon;
  late TextEditingController _supportCon;
  late TextEditingController _footerCon;
  late TextEditingController _termsCon;

  String _logoPath = '';
  bool _loading = true;
  BusinessProfile? _profile;

  @override
  void initState() {
    super.initState();
    _businessNameCon = TextEditingController();
    _ownerNameCon = TextEditingController();
    _phoneCon = TextEditingController();
    _whatsAppCon = TextEditingController();
    _emailCon = TextEditingController();
    _addressCon = TextEditingController();
    _gstCon = TextEditingController();
    _upiCon = TextEditingController();
    _bankCon = TextEditingController();
    _supportCon = TextEditingController();
    _footerCon = TextEditingController();
    _termsCon = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await BusinessProfileService.getProfile();
      if (mounted) {
        setState(() {
          _profile = p;
          _businessNameCon.text = p.businessName;
          _ownerNameCon.text = p.ownerName;
          _phoneCon.text = p.phone;
          _whatsAppCon.text = p.whatsapp;
          _emailCon.text = p.email;
          _addressCon.text = p.address;
          _gstCon.text = p.gstNumber;
          _upiCon.text = p.upiId;
          _bankCon.text = p.bankDetails;
          _supportCon.text = p.supportNumber;
          _footerCon.text = p.invoiceFooter;
          _termsCon.text = p.termsConditions;
          _logoPath = p.logoPath;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        SnackbarHelper.showError(context, 'Failed to load business profile: $e');
      }
    }
  }

  @override
  void dispose() {
    _businessNameCon.dispose();
    _ownerNameCon.dispose();
    _phoneCon.dispose();
    _whatsAppCon.dispose();
    _emailCon.dispose();
    _addressCon.dispose();
    _gstCon.dispose();
    _upiCon.dispose();
    _bankCon.dispose();
    _supportCon.dispose();
    _footerCon.dispose();
    _termsCon.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      final file = File(img.path);
      if (file.existsSync()) {
        final dir = Directory('${AppConstants.appDocsDir}/business_branding');
        if (!dir.existsSync()) {
          await dir.create(recursive: true);
        }
        final dest = File('${dir.path}/logo_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.copy(dest.path);
        setState(() {
          _logoPath = dest.path;
        });
        SnackbarHelper.showSuccess(context, 'Logo selected successfully');
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    AppHaptics.buttonClick();

    if (_profile == null) return;

    final updated = _profile!.copyWith(
      businessName: _businessNameCon.text.trim(),
      ownerName: _ownerNameCon.text.trim(),
      phone: _phoneCon.text.trim(),
      whatsapp: _whatsAppCon.text.trim(),
      email: _emailCon.text.trim(),
      address: _addressCon.text.trim(),
      gstNumber: _gstCon.text.trim(),
      upiId: _upiCon.text.trim(),
      bankDetails: _bankCon.text.trim(),
      supportNumber: _supportCon.text.trim(),
      invoiceFooter: _footerCon.text.trim(),
      termsConditions: _termsCon.text.trim(),
      logoPath: _logoPath,
      updatedAt: DateTime.now(),
    );

    try {
      await BusinessProfileService.saveProfile(updated);
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Business Profile updated successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save business profile: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Business Profile',
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return AppScaffold(
      title: 'Business Profile',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- BUSINESS LOGO BRANDING ---
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickLogo,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.primarySurface,
                        backgroundImage: _logoPath.isNotEmpty ? FileImage(File(_logoPath)) : null,
                        child: _logoPath.isEmpty
                            ? const Icon(Icons.add_a_photo_rounded, size: 36, color: AppColors.primary)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to change Business Logo',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _businessNameCon,
                decoration: const InputDecoration(
                  labelText: 'Business Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.storefront_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter business name' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ownerNameCon,
                      decoration: const InputDecoration(
                        labelText: 'Owner Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _gstCon,
                      decoration: const InputDecoration(
                        labelText: 'GST Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.percent_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCon,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone',
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
                        labelText: 'WhatsApp Phone',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.chat_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _emailCon,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Business Email Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_rounded),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _addressCon,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Business Physical Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_rounded),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Financial & Payment Branding',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _upiCon,
                decoration: const InputDecoration(
                  labelText: 'UPI Payment ID',
                  hintText: 'e.g. business@upi',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _bankCon,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Bank Account details',
                  hintText: 'Bank Name, A/C No, IFSC Code...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_rounded),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _supportCon,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Customer Support Helpdesk Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.contact_support_rounded),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _footerCon,
                decoration: const InputDecoration(
                  labelText: 'Receipt Invoice Footer Text',
                  hintText: 'e.g. Thank you for shopping with us!',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_rounded),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _termsCon,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Terms & Conditions',
                  hintText: 'e.g. Goods once sold cannot be returned...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.gavel_rounded),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Business Branding', style: TextStyle(fontWeight: FontWeight.w800)),
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
