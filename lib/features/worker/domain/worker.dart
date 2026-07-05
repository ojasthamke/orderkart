enum CommissionType { fixed, pctOrder, pctCollection, salary, bonus, mixed }

class Worker {
  final String id;
  final String name;
  final String photoPath;
  final String phone;
  final String address;
  final String joiningDate;
  final String employeeId;
  final String status; // 'active', 'inactive'
  final String pin;
  final CommissionType commissionType;
  final double commissionValue;
  final double salary;
  final double bonus;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

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
    this.pin = '',
    this.commissionType = CommissionType.pctOrder,
    this.commissionValue = 5.0,
    this.salary = 0.0,
    this.bonus = 0.0,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
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
    String? pin,
    CommissionType? commissionType,
    double? commissionValue,
    double? salary,
    double? bonus,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      pin: pin ?? this.pin,
      commissionType: commissionType ?? this.commissionType,
      commissionValue: commissionValue ?? this.commissionValue,
      salary: salary ?? this.salary,
      bonus: bonus ?? this.bonus,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
        'pin': pin,
        'commission_type': commissionType.name,
        'commission_value': commissionValue,
        'salary': salary,
        'bonus': bonus,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
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
      pin: map['pin'] as String? ?? '',
      commissionType: parseType(map['commission_type'] as String? ?? 'pct_order'),
      commissionValue: (map['commission_value'] as num?)?.toDouble() ?? 5.0,
      salary: (map['salary'] as num?)?.toDouble() ?? 0.0,
      bonus: (map['bonus'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      assignedCustomersCount: map['assigned_customers_count'] as int? ?? 0,
      assignedAreasCount: map['assigned_areas_count'] as int? ?? 0,
      assignedStreetsCount: map['assigned_streets_count'] as int? ?? 0,
      totalCollection: (map['total_collection'] as num?)?.toDouble() ?? 0.0,
      totalCommissionEarned: (map['total_commission'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
