import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../domain/app_visit.dart';
import 'visit_provider.dart';

class AddEditVisitScreen extends ConsumerStatefulWidget {
  final AppVisit? visit;
  const AddEditVisitScreen({super.key, this.visit});

  @override
  ConsumerState<AddEditVisitScreen> createState() => _AddEditVisitScreenState();
}

class _AddEditVisitScreenState extends ConsumerState<AddEditVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  
  String _areaId = '';
  String _streetId = '';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.visit != null) {
      _areaId = widget.visit!.areaId;
      _streetId = widget.visit!.streetId;
      _notesController.text = widget.visit!.notes;
      _selectedDate = DateTime.parse(widget.visit!.date);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_areaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an Area')),
      );
      return;
    }

    final visit = AppVisit(
      id: widget.visit?.id ?? const Uuid().v4(),
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      areaId: _areaId,
      streetId: _streetId,
      notes: _notesController.text.trim(),
      priority: widget.visit?.priority ?? 0,
      status: widget.visit?.status ?? 'pending',
      createdAt: widget.visit?.createdAt ?? DateTime.now(),
    );

    if (widget.visit == null) {
      ref.read(visitListProvider.notifier).addVisit(visit);
    } else {
      ref.read(visitListProvider.notifier).updateVisit(visit);
    }

    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.visit == null ? 'Schedule Visit' : 'Edit Visit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            onPressed: _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.borderColor(context)),
                ),
                child: ListTile(
                  title: const Text('Visit Date'),
                  subtitle: Text(AppFormatters.date(_selectedDate), 
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.calendar_today_rounded),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(height: 24),
              // Area ID and Street ID should ideally be dropdowns loaded from AreaDao/StreetDao.
              // We'll use simple text fields for now to get the feature running, but they should 
              // be replaced with DropdownButtonFormField.
              TextFormField(
                initialValue: _areaId,
                decoration: InputDecoration(
                  labelText: 'Area Name',
                  hintText: 'Enter area to visit',
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => _areaId = val,
                validator: (val) => AppValidators.required(val, field: 'Area'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _streetId,
                decoration: InputDecoration(
                  labelText: 'Street Name (Optional)',
                  hintText: 'Specific street',
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => _streetId = val,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Visit Notes',
                  hintText: 'Any special instructions...',
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Save Schedule', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
