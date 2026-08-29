import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/area.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/constants/app_routes.dart';
import 'package:latlong2/latlong.dart';

class AddEditAreaDialog extends StatefulWidget {
  final Area? area;
  final Future<void> Function(
    String name,
    String description,
    int color,
    String photoPath,
    String mapsLocation,
    List<String> deliverySchedule,
    String cutoffTime,
    double deliveryCharge,
    double minOrderAmount,
    bool isActive,
  ) onSave;

  const AddEditAreaDialog({super.key, this.area, required this.onSave});

  @override
  State<AddEditAreaDialog> createState() => _AddEditAreaDialogState();
}

class _AddEditAreaDialogState extends State<AddEditAreaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCon = TextEditingController();
  final _descCon = TextEditingController();
  final _locationCon = TextEditingController();
  String _photoPath = '';
  int _color = 0xFF1565C0;
  bool _loading = false;

  // New settings fields
  List<String> _deliverySchedule = [];
  final _cutoffTimeCon = TextEditingController(text: '23:59');
  final _deliveryChargeCon = TextEditingController(text: '0.0');
  final _minOrderAmountCon = TextEditingController(text: '0.0');
  bool _isActive = true;

  final _colorOptions = [
    0xFF1565C0, // Blue
    0xFF2E7D32, // Green
    0xFFE65100, // Orange
    0xFFC62828, // Red
    0xFF6A1B9A, // Purple
    0xFF00838F, // Teal
    0xFF37474F, // Blue-grey
    0xFFF9A825, // Amber
  ];

  @override
  void initState() {
    super.initState();
    if (widget.area != null) {
      _nameCon.text = widget.area!.name;
      _descCon.text = widget.area!.description;
      _locationCon.text = widget.area!.mapsLocation;
      _photoPath = widget.area!.photoPath;
      _color = widget.area!.color;
      _deliverySchedule = List<String>.from(widget.area!.deliverySchedule);
      _cutoffTimeCon.text = widget.area!.cutoffTime;
      _deliveryChargeCon.text = widget.area!.deliveryCharge.toString();
      _minOrderAmountCon.text = widget.area!.minOrderAmount.toString();
      _isActive = widget.area!.isActive;
    }
  }

  @override
  void dispose() {
    _nameCon.dispose();
    _descCon.dispose();
    _locationCon.dispose();
    _cutoffTimeCon.dispose();
    _deliveryChargeCon.dispose();
    _minOrderAmountCon.dispose();
    super.dispose();
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
      final file = await ImageUtils.pickAndCompress(source: source);
      if (file != null) {
        setState(() => _photoPath = file.path);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.area != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Area' : 'Add Area'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Header Picker
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gray300),
                      image: (_photoPath.isNotEmpty &&
                              File(_photoPath).existsSync())
                          ? DecorationImage(
                              image: FileImage(File(_photoPath)),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child:
                        (_photoPath.isEmpty || !File(_photoPath).existsSync())
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_rounded,
                                      color: AppColors.gray500, size: 28),
                                  SizedBox(height: 4),
                                  Text('Add Photo',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.gray600)),
                                ],
                              )
                            : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameCon,
                decoration: const InputDecoration(
                  labelText: 'Area Name *',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                validator: (v) =>
                    AppValidators.nameField(v, field: 'Area name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCon,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _locationCon,
                      decoration: const InputDecoration(
                        labelText: 'Google Maps Location / Link',
                        hintText: 'e.g. https://maps.app.goo.gl/... or lat,lng',
                        prefixIcon: Icon(Icons.location_on_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.map_rounded),
                    tooltip: 'Pick on Map',
                    onPressed: () async {
                      LatLng? currentPos;
                      final text = _locationCon.text.trim();
                      if (text.isNotEmpty) {
                        final parts = text.split(',');
                        if (parts.length == 2) {
                          final lat = double.tryParse(parts[0]);
                          final lng = double.tryParse(parts[1]);
                          if (lat != null && lng != null) {
                            currentPos = LatLng(lat, lng);
                          }
                        }
                      }
                      final LatLng? picked = await Navigator.pushNamed(
                        context,
                        AppRoutes.mapPinPicker,
                        arguments: {'initialPosition': currentPos},
                      ) as LatLng?;
                      if (picked != null && mounted) {
                        setState(() {
                          _locationCon.text =
                              '${picked.latitude},${picked.longitude}';
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              const Text('Delivery Days Schedule *', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
                ].map((day) {
                  final isSelected = _deliverySchedule.contains(day);
                  return FilterChip(
                    label: Text(day.substring(0, 3)),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.primary : AppColors.gray800,
                    ),
                    onSelected: (_) {
                      setState(() {
                        if (isSelected) {
                          _deliverySchedule.remove(day);
                        } else {
                          _deliverySchedule.add(day);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _cutoffTimeCon,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Cutoff Time *',
                  hintText: 'Select Cutoff Time (e.g. 18:00)',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                onTap: () async {
                  int hour = 23;
                  int minute = 59;
                  final parts = _cutoffTimeCon.text.split(':');
                  if (parts.length >= 2) {
                    hour = int.tryParse(parts[0]) ?? 23;
                    minute = int.tryParse(parts[1]) ?? 59;
                  }
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: hour, minute: minute),
                  );
                  if (picked != null) {
                    setState(() {
                      _cutoffTimeCon.text = 
                          "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                    });
                  }
                },
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _deliveryChargeCon,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Delivery Charge (₹)',
                        prefixIcon: Icon(Icons.delivery_dining_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        if (double.tryParse(v) == null) return 'Must be a number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _minOrderAmountCon,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Min Order (₹)',
                        prefixIcon: Icon(Icons.shopping_bag_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        if (double.tryParse(v) == null) return 'Must be a number';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Area Active Status', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Enable/disable delivery and order placement for this area'),
                value: _isActive,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => _isActive = val);
                },
              ),
              const SizedBox(height: 16),

              Text('Colour', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: _colorOptions.map((c) {
                  final selected = c == _color;
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  final borderColor = isDark ? Colors.white : AppColors.gray800;
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: borderColor, width: 3)
                            : null,
                        boxShadow: selected ? AppColors.cardShadow : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(isEdit ? 'Update' : 'Add Area'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final charge = double.tryParse(_deliveryChargeCon.text.trim()) ?? 0.0;
      final minAmt = double.tryParse(_minOrderAmountCon.text.trim()) ?? 0.0;
      await widget.onSave(
        _nameCon.text.trim(),
        _descCon.text.trim(),
        _color,
        _photoPath,
        _locationCon.text.trim(),
        _deliverySchedule,
        _cutoffTimeCon.text.trim(),
        charge,
        minAmt,
        _isActive,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
