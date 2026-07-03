import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import 'package:path/path.dart' as p;
import '../../../core/database/database_helper.dart';
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
  final _serialNoCon = TextEditingController();  // replaces main house number
  final _houseCon    = TextEditingController();  // house/flat number
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
        _streetId         = customer.streetId;
        _nameCon.text     = customer.name;
        _phone1Con.text   = customer.phone1;
        _phone2Con.text   = customer.phone2;
        _waCon.text        = customer.whatsapp;
        _serialNoCon.text  = customer.serialNo > 0 ? '${customer.serialNo}' : '';
        _houseCon.text    = customer.houseNumber;
        _addressCon.text  = customer.address;
        _notesCon.text    = customer.notes;
        _mapsCon.text     = customer.mapsLocation;
        _photoPath        = customer.photoPath;
      });
    }
  }

  @override
  void dispose() {
    _nameCon.dispose(); _phone1Con.dispose(); _phone2Con.dispose();
    _waCon.dispose(); _serialNoCon.dispose(); _houseCon.dispose();
    _addressCon.dispose(); _notesCon.dispose(); _mapsCon.dispose();
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

              Row(
                children: [
                  // Serial Number
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: _serialNoCon,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Serial No.',
                        prefixIcon: Icon(Icons.format_list_numbered_rounded),
                        hintText: 'e.g. 1',
                      ),
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty) {
                          if (int.tryParse(v.trim()) == null || int.parse(v.trim()) < 1) {
                            return 'Must be ≥ 1';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _houseCon,
                      decoration: const InputDecoration(
                        labelText: 'House / Flat Number',
                        prefixIcon: Icon(Icons.home_rounded),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                ],
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mapsCon,
                      decoration: InputDecoration(
                        labelText: 'Location Coordinates (lat,lng) or Map Link',
                        prefixIcon: const Icon(Icons.location_on_rounded),
                        suffixIcon: _mapsCon.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: AppColors.error),
                                onPressed: () {
                                  setState(() {
                                    _mapsCon.clear();
                                  });
                                },
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.text,
                      onChanged: (v) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.gps_fixed_rounded),
                    tooltip: 'Set Coordinates',
                    onPressed: _showCoordinatesDialog,
                  ),
                ],
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
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final img = await picker.pickImage(source: source);
      if (img != null) {
        setState(() => _photoPath = img.path);
      }
    }
  }

  void _showCoordinatesDialog() {
    final latCon = TextEditingController();
    final lngCon = TextEditingController();
    
    final current = _mapsCon.text.trim();
    if (current.isNotEmpty && !current.startsWith('http')) {
      final parts = current.split(',');
      if (parts.length == 2) {
        latCon.text = parts[0];
        lngCon.text = parts[1];
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter GPS Coordinates'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latCon,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Latitude (e.g. 18.5204)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lngCon,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Longitude (e.g. 73.8567)',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final lat = double.tryParse(latCon.text.trim());
              final lng = double.tryParse(lngCon.text.trim());
              if (lat != null && lng != null) {
                setState(() {
                  _mapsCon.text = '$lat,$lng';
                });
                Navigator.pop(ctx);
              } else {
                SnackbarHelper.showError(ctx, 'Please enter valid coordinates');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
      final customerId = widget.customerId ?? const Uuid().v4();

      final db = await DatabaseHelper.instance.database;
      final phone = _phone1Con.text.trim();
      final duplicateCheck = await db.query(
        'customers',
        columns: ['name'],
        where: 'phone1 = ? AND id != ?',
        whereArgs: [phone, customerId],
      );
      if (duplicateCheck.isNotEmpty) {
        throw Exception('A customer named "${duplicateCheck.first['name']}" already has this phone number ($phone).');
      }

      String finalPhotoPath = _photoPath;
      if (_photoPath.isNotEmpty) {
        final file = File(_photoPath);
        if (file.existsSync()) {
          final photosDir = Directory('${AppConstants.appDocsDir}/customer_photos');
          if (!photosDir.existsSync()) {
            await photosDir.create(recursive: true);
          }
          if (!p.isWithin(photosDir.path, _photoPath)) {
            final ext = p.extension(_photoPath);
            final destFile = File('${photosDir.path}/$customerId$ext');
            await file.copy(destFile.path);
            finalPhotoPath = destFile.path;
          }
        }
      }

      final customer = Customer(
        id:                 customerId,
        streetId:           _streetId!,
        name:               _nameCon.text.trim(),
        phone1:             _phone1Con.text.trim(),
        phone2:             _phone2Con.text.trim(),
        whatsapp:           _waCon.text.trim(),
        houseNumber:        _houseCon.text.trim(),
        serialNo:           int.tryParse(_serialNoCon.text.trim()) ?? 0,
        address:            _addressCon.text.trim(),
        notes:              _notesCon.text.trim(),
        mapsLocation:       _mapsCon.text.trim(),
        photoPath:          finalPhotoPath,
        customerSince:      now,
        createdAt:          now,
        updatedAt:          now,
      );

      final notifier = ref.read(customerListProvider(_streetId!).notifier);
      if (_isEdit) {
        final existing = await ref.read(customerRepositoryProvider).getCustomerById(customerId);
        if (existing != null && existing.photoPath.isNotEmpty && existing.photoPath != finalPhotoPath) {
          final oldFile = File(existing.photoPath);
          if (oldFile.existsSync()) {
            try { oldFile.deleteSync(); } catch (_) {}
          }
          final fallbackOld = AppConstants.resolveFile(existing.photoPath);
          if (fallbackOld.existsSync()) {
            try { fallbackOld.deleteSync(); } catch (_) {}
          }
        }
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
