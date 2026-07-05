// lib/core/models/worker.dart

/// Represents a worker profile and commission settings.
class Worker {
  final String id; // UUID primary key
  final String name;
  final String? photoPath;
  final String? phone;
  final String? address;
  final String? joiningDate;
  final String? employeeId;
  final String status; // e.g., active, suspended
  final String? pinHash; // hashed PIN for worker actions (never plain text)
  final String commissionType; // 'fixed', 'percentage', 'collection'
  final double commissionValue;
  final double salary;
  final double bonus;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // New Fields
  final String? aadhaarId;
  final String? emergencyContact;
  final String? bankDetails;
  final double target;
  final double joiningSalary;
  final String? leaveStatus;
  final String? remarks;

  const Worker({
    required this.id,
    required this.name,
    this.photoPath,
    this.phone,
    this.address,
    this.joiningDate,
    this.employeeId,
    this.status = 'active',
    this.pinHash,
    this.commissionType = 'percentage',
    this.commissionValue = 5.0,
    this.salary = 0.0,
    this.bonus = 0.0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.aadhaarId,
    this.emergencyContact,
    this.bankDetails,
    this.target = 0.0,
    this.joiningSalary = 0.0,
    this.leaveStatus = 'active',
    this.remarks,
  });

  factory Worker.fromMap(Map<String, dynamic> map) {
    return Worker(
      id: map['id'] as String,
      name: map['name'] as String,
      photoPath: map['photo_path'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      joiningDate: map['joining_date'] as String?,
      employeeId: map['employee_id'] as String?,
      status: map['status'] as String? ?? 'active',
      pinHash: map['pin_hash'] as String?,
      commissionType: map['commission_type'] as String? ?? 'percentage',
      commissionValue: (map['commission_value'] as num?)?.toDouble() ?? 5.0,
      salary: (map['salary'] as num?)?.toDouble() ?? 0.0,
      bonus: (map['bonus'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      aadhaarId: map['aadhaar_id'] as String?,
      emergencyContact: map['emergency_contact'] as String?,
      bankDetails: map['bank_details'] as String?,
      target: (map['target'] as num?)?.toDouble() ?? 0.0,
      joiningSalary: (map['joining_salary'] as num?)?.toDouble() ?? 0.0,
      leaveStatus: map['leave_status'] as String? ?? 'active',
      remarks: map['remarks'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'photo_path': photoPath ?? '',
        'phone': phone ?? '',
        'address': address ?? '',
        'joining_date': joiningDate ?? '',
        'employee_id': employeeId ?? '',
        'status': status,
        'pin_hash': pinHash ?? '',
        'commission_type': commissionType,
        'commission_value': commissionValue,
        'salary': salary,
        'bonus': bonus,
        'notes': notes ?? '',
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'aadhaar_id': aadhaarId ?? '',
        'emergency_contact': emergencyContact ?? '',
        'bank_details': bankDetails ?? '',
        'target': target,
        'joining_salary': joiningSalary,
        'leave_status': leaveStatus ?? 'active',
        'remarks': remarks ?? '',
      };
}
