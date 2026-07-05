import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/snackbar_helper.dart';
import '../../domain/worker.dart';

class AddEditWorkerDialog extends StatefulWidget {
  final Worker? worker;

  const AddEditWorkerDialog({super.key, this.worker});

  static Future<Worker?> show(BuildContext context, {Worker? worker}) async {
    return await showDialog<Worker>(
      context: context,
      builder: (ctx) => AddEditWorkerDialog(worker: worker),
    );
  }

  @override
  State<AddEditWorkerDialog> createState() => _AddEditWorkerDialogState();
}

class _AddEditWorkerDialogState extends State<AddEditWorkerDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCon;
  late TextEditingController _phoneCon;
  late TextEditingController _addressCon;
  late TextEditingController _empIdCon;
  late TextEditingController _commValCon;
  late TextEditingController _salaryCon;
  late TextEditingController _targetCon;
  late TextEditingController _notesCon;

  CommissionType _commType = CommissionType.pctOrder;
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    final w = widget.worker;
    _nameCon = TextEditingController(text: w?.name ?? '');
    _phoneCon = TextEditingController(text: w?.phone ?? '');
    _addressCon = TextEditingController(text: w?.address ?? '');
    _empIdCon = TextEditingController(text: w?.employeeId ?? '');
    _commValCon = TextEditingController(text: (w?.commissionValue ?? 5.0).toString());
    _salaryCon = TextEditingController(text: (w?.salary ?? 0.0).toString());
    _targetCon = TextEditingController(text: '50000');
    _notesCon = TextEditingController(text: w?.notes ?? '');
    if (w != null) {
      _commType = w.commissionType;
      _status = w.status;
    }
  }

  @override
  void dispose() {
    _nameCon.dispose();
    _phoneCon.dispose();
    _addressCon.dispose();
    _empIdCon.dispose();
    _commValCon.dispose();
    _salaryCon.dispose();
    _targetCon.dispose();
    _notesCon.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    AppHaptics.buttonClick();

    final now = DateTime.now();
    final newWorker = Worker(
      id: widget.worker?.id ?? '',
      name: _nameCon.text.trim(),
      phone: _phoneCon.text.trim(),
      address: _addressCon.text.trim(),
      employeeId: _empIdCon.text.trim(),
      status: _status,
      commissionType: _commType,
      commissionValue: double.tryParse(_commValCon.text.trim()) ?? 5.0,
      salary: double.tryParse(_salaryCon.text.trim()) ?? 0.0,
      notes: _notesCon.text.trim(),
      createdAt: widget.worker?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.of(context).pop(newWorker);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.worker != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.badge_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit Worker Profile' : 'Add New Worker',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameCon,
                decoration: const InputDecoration(
                  labelText: 'Worker Full Name *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter worker name' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCon,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _empIdCon,
                      decoration: const InputDecoration(
                        labelText: 'Employee ID',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _addressCon,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Commission & Earnings Rule',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 8),

              DropdownButtonFormField<CommissionType>(
                value: _commType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: CommissionType.pctOrder, child: Text('% of Order Sales')),
                  DropdownMenuItem(value: CommissionType.pctCollection, child: Text('% of Payment Collections')),
                  DropdownMenuItem(value: CommissionType.fixed, child: Text('Fixed Per Order Amount')),
                  DropdownMenuItem(value: CommissionType.salary, child: Text('Fixed Monthly Salary')),
                  DropdownMenuItem(value: CommissionType.mixed, child: Text('Base Salary + % Sales Commission')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _commType = val);
                },
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _commValCon,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _commType == CommissionType.fixed ? 'Amount (₹)' : 'Rate (%)',
                        prefixIcon: const Icon(Icons.percent_rounded),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _targetCon,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Target (₹)',
                        prefixIcon: Icon(Icons.flag_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Status:', style: TextStyle(fontWeight: FontWeight.w700)),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'active', label: Text('Active')),
                      ButtonSegment(value: 'inactive', label: Text('Inactive')),
                    ],
                    selected: {_status},
                    onSelectionChanged: (set) => setState(() => _status = set.first),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isEdit ? 'Save Changes' : 'Create Worker'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
