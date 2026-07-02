/// AddEditAreaDialog — Form dialog to add or edit an area

import 'package:flutter/material.dart';
import '../../domain/area.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';

class AddEditAreaDialog extends StatefulWidget {
  final Area? area;
  final void Function(String name, String description, int color) onSave;

  const AddEditAreaDialog({super.key, this.area, required this.onSave});

  @override
  State<AddEditAreaDialog> createState() => _AddEditAreaDialogState();
}

class _AddEditAreaDialogState extends State<AddEditAreaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCon  = TextEditingController();
  final _descCon  = TextEditingController();
  int   _color    = 0xFF1565C0;
  bool  _loading  = false;

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
      _color        = widget.area!.color;
    }
  }

  @override
  void dispose() {
    _nameCon.dispose();
    _descCon.dispose();
    super.dispose();
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
              TextFormField(
                controller: _nameCon,
                decoration: const InputDecoration(
                  labelText: 'Area Name *',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                validator: (v) => AppValidators.nameField(v, field: 'Area name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCon,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Text('Colour', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: _colorOptions.map((c) {
                  final selected = c == _color;
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
                            ? Border.all(color: AppColors.gray800, width: 3)
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEdit ? 'Update' : 'Add Area'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    widget.onSave(_nameCon.text.trim(), _descCon.text.trim(), _color);
    Navigator.of(context).pop();
  }
}
