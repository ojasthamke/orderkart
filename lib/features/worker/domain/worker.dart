// lib/features/worker/domain/worker.dart

enum CommissionType { fixed, pctOrder, pctCollection, salary, bonus, mixed }

class Worker {
  final String id;
  final String name;
  final String photoPath;
  final String phone;
  final String address;
  final String joiningDate;
  final String employeeId;
  final String status; // 'active', 'suspended'
  final String pinHash; // hashed PIN for worker actions (never plain text)
  final CommissionType commissionType;
  final double commissionValue;
  final double salary;
  final double bonus;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // New Fields
  final String aadhaarId;
  final String emergencyContact;
  final String bankDetails;
  final double target;
  final double joiningSalary;
  final String leaveStatus;
  final String remarks;

  // Computed/Joined
  final int assignedCustomersCount;
  final int assignedAreasCount;
  final int assignedStreetsCount;
  final double totalCollection;
  final double totalCommissionEarned;

  const Worker({
    required this.id,
    required this.name,
    this.photoPath = '',
    this.phone = '',
    this.address = '',
    this.joiningDate = '',
    this.employeeId = '',
    this.status = 'active',
    this.pinHash = '',
    this.commissionType = CommissionType.pctOrder,
    this.commissionValue = 5.0,
    this.salary = 0.0,
    this.bonus = 0.0,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    this.aadhaarId = '',
    this.emergencyContact = '',
    this.bankDetails = '',
    this.target = 0.0,
    this.joiningSalary = 0.0,
    this.leaveStatus = 'active',
    this.remarks = '',
    this.assignedCustomersCount = 0,
    this.assignedAreasCount = 0,
    this.assignedStreetsCount = 0,
    this.totalCollection = 0.0,
    this.totalCommissionEarned = 0.0,
  });

  Worker copyWith({
    String? id,
    String? name,
    String? photoPath,
    String? phone,
    String? address,
    String? joiningDate,
    String? employeeId,
    String? status,
    String? pinHash,
    CommissionType? commissionType,
    double? commissionValue,
    double? salary,
    double? bonus,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? aadhaarId,
    String? emergencyContact,
    String? bankDetails,
    double? target,
    double? joiningSalary,
    String? leaveStatus,
    String? remarks,
    int? assignedCustomersCount,
    int? assignedAreasCount,
    int? assignedStreetsCount,
    double? totalCollection,
    double? totalCommissionEarned,
  }) {
    return Worker(
      id: id ?? this.id,
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      joiningDate: joiningDate ?? this.joiningDate,
      employeeId: employeeId ?? this.employeeId,
      status: status ?? this.status,
      pinHash: pinHash ?? this.pinHash,
      commissionType: commissionType ?? this.commissionType,
      commissionValue: commissionValue ?? this.commissionValue,
      salary: salary ?? this.salary,
      bonus: bonus ?? this.bonus,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      aadhaarId: aadhaarId ?? this.aadhaarId,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      bankDetails: bankDetails ?? this.bankDetails,
      target: target ?? this.target,
      joiningSalary: joiningSalary ?? this.joiningSalary,
      leaveStatus: leaveStatus ?? this.leaveStatus,
      remarks: remarks ?? this.remarks,
      assignedCustomersCount: assignedCustomersCount ?? this.assignedCustomersCount,
      assignedAreasCount: assignedAreasCount ?? this.assignedAreasCount,
      assignedStreetsCount: assignedStreetsCount ?? this.assignedStreetsCount,
      totalCollection: totalCollection ?? this.totalCollection,
      totalCommissionEarned: totalCommissionEarned ?? this.totalCommissionEarned,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'photo_path': photoPath,
        'phone': phone,
        'address': address,
        'joining_date': joiningDate,
        'employee_id': employeeId,
        'status': status,
        'pin_hash': pinHash,
        'commission_type': commissionType.name,
        'commission_value': commissionValue,
        'salary': salary,
        'bonus': bonus,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'aadhaar_id': aadhaarId,
        'emergency_contact': emergencyContact,
        'bank_details': bankDetails,
        'target': target,
        'joining_salary': joiningSalary,
        'leave_status': leaveStatus,
        'remarks': remarks,
      };

  factory Worker.fromMap(Map<String, dynamic> map) {
    CommissionType parseType(String val) {
      switch (val) {
        case 'fixed': return CommissionType.fixed;
        case 'pctCollection':
        case 'pct_collection': return CommissionType.pctCollection;
        case 'salary': return CommissionType.salary;
        case 'bonus': return CommissionType.bonus;
        case 'mixed': return CommissionType.mixed;
        case 'pctOrder':
        case 'pct_order':
        default: return CommissionType.pctOrder;
      }
    }

    return Worker(
      id: map['id'] as String,
      name: map['name'] as String,
      photoPath: map['photo_path'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      joiningDate: map['joining_date'] as String? ?? '',
      employeeId: map['employee_id'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      pinHash: map['pin_hash'] as String? ?? '',
      commissionType: parseType(map['commission_type'] as String? ?? 'pct_order'),
      commissionValue: (map['commission_value'] as num?)?.toDouble() ?? 5.0,
      salary: (map['salary'] as num?)?.toDouble() ?? 0.0,
      bonus: (map['bonus'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      aadhaarId: map['aadhaar_id'] as String? ?? '',
      emergencyContact: map['emergency_contact'] as String? ?? '',
      bankDetails: map['bank_details'] as String? ?? '',
      target: (map['target'] as num?)?.toDouble() ?? 0.0,
      joiningSalary: (map['joining_salary'] as num?)?.toDouble() ?? 0.0,
      leaveStatus: map['leave_status'] as String? ?? 'active',
      remarks: map['remarks'] as String? ?? '',
      assignedCustomersCount: map['assigned_customers_count'] as int? ?? 0,
      assignedAreasCount: map['assigned_areas_count'] as int? ?? 0,
      assignedStreetsCount: map['assigned_streets_count'] as int? ?? 0,
      totalCollection: (map['total_collection'] as num?)?.toDouble() ?? 0.0,
      totalCommissionEarned: (map['total_commission'] as num?)?.toDouble() ?? 0.0,
    );
  }

  double get monthlyTarget => target > 0 ? target : (salary > 0 ? salary : 10000.0);
}
