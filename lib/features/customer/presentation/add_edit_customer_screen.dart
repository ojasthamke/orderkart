import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../domain/customer.dart';
import '../../../core/constants/app_routes.dart';
import 'customer_provider.dart';
import '../../../core/utils/image_utils.dart';

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
  String _dietaryPreference = '';

  // Custom Fields state
  List<Map<String, dynamic>> _customFields = [];
  final Map<String, TextEditingController> _customFieldControllers = {};

  @override
  void initState() {
    super.initState();
    _streetId = widget.streetId;
    _loadCustomFields();
    if (widget.customerId != null) {
      _isEdit = true;
      _loadCustomer();
    }
  }

  Future<void> _loadCustomFields() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final fields = await db.query('custom_fields', where: 'entity_type = ?', whereArgs: ['customer']);
      
      final Map<String, String> values = {};
      if (widget.customerId != null) {
        final existingValues = await db.query(
          'custom_field_values',
          where: 'entity_id = ?',
          whereArgs: [widget.customerId],
        );
        for (final row in existingValues) {
          values[row['field_id'] as String] = row['value'] as String;
        }
      }

      if (mounted) {
        setState(() {
          _customFields = fields;
          for (final f in fields) {
            final fid = f['id'] as String;
            _customFieldControllers[fid] = TextEditingController(text: values[fid] ?? '');
          }
        });
      }
    } catch (_) {}
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
        _dietaryPreference = customer.dietaryPreference;
      });
    }
  }

  @override
  void dispose() {
    _nameCon.dispose(); _phone1Con.dispose(); _phone2Con.dispose();
    _waCon.dispose(); _serialNoCon.dispose(); _houseCon.dispose();
    _addressCon.dispose(); _notesCon.dispose(); _mapsCon.dispose();
    for (final controller in _customFieldControllers.values) {
      controller.dispose();
    }
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
              const SizedBox(height: 16),

              // Dietary Preference (Optional Veg / Non-Veg)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Dietary Preference (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _dietaryPreference = _dietaryPreference == 'veg' ? '' : 'veg';
                        });
                      },
                      icon: Icon(
                        _dietaryPreference == 'veg' ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: _dietaryPreference == 'veg' ? Colors.green : Colors.grey,
                      ),
                      label: const Text('Veg'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _dietaryPreference == 'veg' ? Colors.green : Colors.grey.shade300,
                          width: _dietaryPreference == 'veg' ? 2 : 1,
                        ),
                        foregroundColor: _dietaryPreference == 'veg' ? Colors.green.shade700 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _dietaryPreference = _dietaryPreference == 'non_veg' ? '' : 'non_veg';
                        });
                      },
                      icon: Icon(
                        _dietaryPreference == 'non_veg' ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: _dietaryPreference == 'non_veg' ? Colors.red : Colors.grey,
                      ),
                      label: const Text('Non-Veg'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _dietaryPreference == 'non_veg' ? Colors.red : Colors.grey.shade300,
                          width: _dietaryPreference == 'non_veg' ? 2 : 1,
                        ),
                        foregroundColor: _dietaryPreference == 'non_veg' ? Colors.red.shade700 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Custom Fields Section
              if (_customFields.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Additional Custom Attributes',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                ..._customFields.map((field) {
                  final fid = field['id'] as String;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _customFieldControllers[fid],
                      decoration: InputDecoration(
                        labelText: field['field_name'] ?? '',
                        prefixIcon: const Icon(Icons.star_outline_rounded),
                      ),
                    ),
                  );
                }),
              ],
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
      final img = await ImageUtils.pickAndCompress(source: source);
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
        final savedPath = await ImageUtils.saveImagePermanently(
          sourcePath: _photoPath,
          subFolder: 'customer_photos',
          fileName: customerId,
        );
        if (savedPath != null) {
          finalPhotoPath = savedPath;
        }
      }

      final existing = _isEdit
          ? await ref.read(customerRepositoryProvider).getCustomerById(customerId)
          : null;

      final customer = existing != null
          ? existing.copyWith(
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
              dietaryPreference:  _dietaryPreference,
              updatedAt:          now,
            )
          : Customer(
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
              dietaryPreference:  _dietaryPreference,
              customerSince:      now,
              createdAt:          now,
              updatedAt:          now,
            );

      final notifier = ref.read(customerListProvider(_streetId!).notifier);
      if (_isEdit) {
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

      // Save custom field values
      for (final entry in _customFieldControllers.entries) {
        final fieldId = entry.key;
        final val = entry.value.text.trim();
        if (val.isNotEmpty) {
          await db.insert('custom_field_values', {
            'entity_id': customerId,
            'field_id': fieldId,
            'value': val,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          await db.delete('custom_field_values',
              where: 'entity_id = ? AND field_id = ?',
              whereArgs: [customerId, fieldId]);
        }
      }

      if (!mounted) return;
      if (!mounted) return;
      if (_isEdit) {
        SnackbarHelper.showSuccess(context, 'Customer details updated');
        Navigator.of(context).pop();
      } else {
        SnackbarHelper.showSuccess(context, 'Customer added successfully');

        // Offer Copy Name & Dial Directly
        final dialContact = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.phone_enabled_rounded, color: AppColors.primary, size: 26),
                SizedBox(width: 10),
                Text('Copy Name & Dial?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
            content: Text(
              'Copy ${_nameCon.text.trim()} to clipboard and open your phone dialer for ${_phone1Con.text.trim()}?',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Skip'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.phone_enabled_rounded, size: 18),
                label: const Text('Copy & Dial'),
              ),
            ],
          ),
        );

        if (dialContact == true && mounted) {
          final cName = _nameCon.text.trim();
          final cPhone = _phone1Con.text.trim();

          // Copy name to clipboard
          await Clipboard.setData(ClipboardData(text: cName));

          // Log the call in our Call Logs table
          await DatabaseHelper.instance.insertCallLog(
            customerId: customerId,
            customerName: cName,
            phone: cPhone,
          );

          // Open dialpad directly
          final cleanPhone = cPhone.replaceAll(RegExp(r'[^\d+]'), '');
          final telUri = Uri.parse('tel:$cleanPhone');
          if (await canLaunchUrl(telUri)) {
            await launchUrl(telUri);
          } else {
            SnackbarHelper.showError(context, 'Could not open dialpad');
          }
        }

        if (!mounted) return;

        // Offer VIP upgrade for new customers
        final upgradeToVip = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 28),
                SizedBox(width: 10),
                Text('Upgrade to VIP?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
            content: Text(
              'Would you like to enroll ${_nameCon.text.trim()} in a VIP membership plan?\n\nVIP members enjoy exclusive discounts, free delivery, and priority handling.',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not Now'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                label: const Text('Yes, Upgrade!'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        if (upgradeToVip == true) {
          Navigator.of(context).pushNamed(AppRoutes.vipDashboard);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save customer: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
