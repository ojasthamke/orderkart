import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../domain/customer.dart';
import 'customer_provider.dart';

class AddEditCustomerScreen extends ConsumerStatefulWidget {
  final String? streetId;
  final String? customerId;

  const AddEditCustomerScreen({
    super.key,
    this.streetId,
    this.customerId,
  });

  @override
  ConsumerState<AddEditCustomerScreen> createState() =>
      _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends ConsumerState<AddEditCustomerScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCon     = TextEditingController();
  final _phone1Con   = TextEditingController();
  final _phone2Con   = TextEditingController();
  final _waCon        = TextEditingController();
  final _houseCon    = TextEditingController();
  final _addressCon  = TextEditingController();
  final _notesCon    = TextEditingController();
  final _mapsCon     = TextEditingController();

  String? _streetId;
  String _photoPath = '';
  bool   _loading   = false;
  bool   _isEdit    = false;

  @override
  void initState() {
    super.initState();
    _streetId = widget.streetId;
    if (widget.customerId != null) {
      _isEdit = true;
      _loadCustomer();
    }
  }

  Future<void> _loadCustomer() async {
    final customer = await ref
        .read(customerRepositoryProvider)
        .getCustomerById(widget.customerId!);
    if (customer != null && mounted) {
      setState(() {
        _streetId        = customer.streetId;
        _nameCon.text    = customer.name;
        _phone1Con.text  = customer.phone1;
        _phone2Con.text  = customer.phone2;
        _waCon.text       = customer.whatsapp;
        _houseCon.text   = customer.houseNumber;
        _addressCon.text = customer.address;
        _notesCon.text   = customer.notes;
        _mapsCon.text    = customer.mapsLocation;
        _photoPath       = customer.photoPath;
      });
    }
  }

  @override
  void dispose() {
    _nameCon.dispose(); _phone1Con.dispose(); _phone2Con.dispose();
    _waCon.dispose(); _houseCon.dispose(); _addressCon.dispose();
    _notesCon.dispose(); _mapsCon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? 'Edit Customer' : 'Add Customer',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Photo picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryLight, width: 2),
                    image: _photoPath.isNotEmpty
                        ? DecorationImage(
                            image: _photoPath.startsWith('http')
                                ? NetworkImage(_photoPath) as ImageProvider
                                : FileImage(File(_photoPath)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _photoPath.isEmpty
                      ? const Icon(Icons.camera_alt_rounded,
                          size: 32, color: AppColors.primary)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _photoPath.isEmpty ? 'Add Photo' : 'Change Photo',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameCon,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (v) => AppValidators.nameField(v, field: 'Name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Phone 1
              TextFormField(
                controller: _phone1Con,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Primary Phone *',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
                validator: AppValidators.phoneRequired,
              ),
              const SizedBox(height: 16),

              // Phone 2
              TextFormField(
                controller: _phone2Con,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Secondary Phone (optional)',
                  prefixIcon: Icon(Icons.phone_iphone_rounded),
                ),
                validator: AppValidators.phone,
              ),
              const SizedBox(height: 16),

              // WhatsApp
              TextFormField(
                controller: _waCon,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp Number (optional)',
                  prefixIcon: Icon(Icons.chat_rounded),
                ),
                validator: AppValidators.phone,
              ),
              const SizedBox(height: 16),

              // House number
              TextFormField(
                controller: _houseCon,
                decoration: const InputDecoration(
                  labelText: 'House / Flat Number',
                  prefixIcon: Icon(Icons.home_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Address
              TextFormField(
                controller: _addressCon,
                decoration: const InputDecoration(
                  labelText: 'Address Details',
                  prefixIcon: Icon(Icons.location_on_rounded),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Google Maps Location
              TextFormField(
                controller: _mapsCon,
                decoration: InputDecoration(
                  labelText: 'Google Maps Link (optional)',
                  prefixIcon: const Icon(Icons.map_rounded),
                  suffixIcon: _mapsCon.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, color: AppColors.primary),
                          onPressed: () async {
                            final url = Uri.tryParse(_mapsCon.text.trim());
                            if (url != null && await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            } else {
                              if (mounted) SnackbarHelper.showError(context, 'Invalid map link');
                            }
                          },
                        )
                      : null,
                ),
                keyboardType: TextInputType.url,
                onChanged: (v) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesCon,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes / Landmark',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _save,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_isEdit ? 'Update Customer' : 'Add Customer'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => _photoPath = img.path);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_streetId == null || _streetId!.isEmpty) {
      SnackbarHelper.showError(context, 'Street is required');
      return;
    }
    setState(() => _loading = true);

    try {
      final now = DateTime.now();
      final customer = Customer(
        id:                 widget.customerId ?? const Uuid().v4(),
        streetId:           _streetId!,
        name:               _nameCon.text.trim(),
        phone1:             _phone1Con.text.trim(),
        phone2:             _phone2Con.text.trim(),
        whatsapp:           _waCon.text.trim(),
        houseNumber:        _houseCon.text.trim(),
        address:            _addressCon.text.trim(),
        notes:              _notesCon.text.trim(),
        mapsLocation:       _mapsCon.text.trim(),
        photoPath:          _photoPath,
        customerSince:      now,
        createdAt:          now,
        updatedAt:          now,
      );

      final notifier = ref.read(customerListProvider(_streetId!).notifier);
      if (_isEdit) {
        await notifier.update(customer);
      } else {
        await notifier.add(customer);
      }

      if (!mounted) return;
      SnackbarHelper.showSuccess(
          context, _isEdit ? 'Customer details updated' : 'Customer added');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted)
        SnackbarHelper.showError(context, 'Failed to save customer: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
