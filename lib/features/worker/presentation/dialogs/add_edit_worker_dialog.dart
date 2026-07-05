// lib/features/worker/presentation/dialogs/add_edit_worker_dialog.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/haptics.dart';
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
  
  // New Controllers
  late TextEditingController _aadhaarCon;
  late TextEditingController _emergencyContactCon;
  late TextEditingController _bankDetailsCon;
  late TextEditingController _joiningSalaryCon;
  late TextEditingController _remarksCon;

  CommissionType _commType = CommissionType.pctOrder;
  String _status = 'active';
  String _leaveStatus = 'active';

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
    _targetCon = TextEditingController(text: (w?.target ?? 50000.0).toStringAsFixed(0));
    _notesCon = TextEditingController(text: w?.notes ?? '');
    
    _aadhaarCon = TextEditingController(text: w?.aadhaarId ?? '');
    _emergencyContactCon = TextEditingController(text: w?.emergencyContact ?? '');
    _bankDetailsCon = TextEditingController(text: w?.bankDetails ?? '');
    _joiningSalaryCon = TextEditingController(text: (w?.joiningSalary ?? 0.0).toString());
    _remarksCon = TextEditingController(text: w?.remarks ?? '');

    if (w != null) {
      _commType = w.commissionType;
      _status = w.status;
      _leaveStatus = w.leaveStatus;
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
    _aadhaarCon.dispose();
    _emergencyContactCon.dispose();
    _bankDetailsCon.dispose();
    _joiningSalaryCon.dispose();
    _remarksCon.dispose();
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
      pinHash: widget.worker?.pinHash ?? '',
      commissionType: _commType,
      commissionValue: double.tryParse(_commValCon.text.trim()) ?? 5.0,
      salary: double.tryParse(_salaryCon.text.trim()) ?? 0.0,
      notes: _notesCon.text.trim(),
      aadhaarId: _aadhaarCon.text.trim(),
      emergencyContact: _emergencyContactCon.text.trim(),
      bankDetails: _bankDetailsCon.text.trim(),
      target: double.tryParse(_targetCon.text.trim()) ?? 0.0,
      joiningSalary: double.tryParse(_joiningSalaryCon.text.trim()) ?? 0.0,
      leaveStatus: _leaveStatus,
      remarks: _remarksCon.text.trim(),
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
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _aadhaarCon,
                      decoration: const InputDecoration(
                        labelText: 'Aadhaar ID / Govt Card',
                        prefixIcon: Icon(Icons.credit_card_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _emergencyContactCon,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Emergency Contact',
                        prefixIcon: Icon(Icons.contact_phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _bankDetailsCon,
                decoration: const InputDecoration(
                  labelText: 'Bank Account Details / UPI ID',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
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
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _joiningSalaryCon,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Joining Salary (₹)',
                        prefixIcon: Icon(Icons.monetization_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _remarksCon,
                      decoration: const InputDecoration(
                        labelText: 'Remarks',
                        prefixIcon: Icon(Icons.edit_note_outlined),
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
                  const Text('Account Status:', style: TextStyle(fontWeight: FontWeight.w700)),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'active', label: Text('Active')),
                      ButtonSegment(value: 'inactive', label: Text('Suspended')),
                    ],
                    selected: {_status},
                    onSelectionChanged: (set) => setState(() => _status = set.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Leave Status:', style: TextStyle(fontWeight: FontWeight.w700)),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'active', label: Text('On Duty')),
                      ButtonSegment(value: 'leave', label: Text('On Leave')),
                    ],
                    selected: {_leaveStatus},
                    onSelectionChanged: (set) => setState(() => _leaveStatus = set.first),
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
