/// Order Model

class AppOrder {
  final String id;
  final String customerId;
  final double subtotal;
  final double discount;
  final double deliveryCharge;
  final double smartRoundedAmount;
  final double grandTotal;
  final double paidAmount;
  final double remainingAmount;
  final String deliveryStatus;  // pending / delivered / cancelled
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? orderNumber;       // Sequential rowid from SQLite

  // Joined / computed fields
  final String? customerName;
  final String? customerAddress;
  final String? customerPhone;
  final List<dynamic> items;  // List<OrderItem>
  final List<dynamic> payments; // List<Payment>

  final String assignedWorkerId;
  final String createdBy;
  final String workerName;
  final String deviceName;
  final double commissionRate;
  final String commissionType;

  String get orderNoLabel {
    return id;
  }

  const AppOrder({
    required this.id,
    required this.customerId,
    required this.subtotal,
    this.discount           = 0,
    this.deliveryCharge     = 0,
    this.smartRoundedAmount = 0,
    required this.grandTotal,
    this.paidAmount         = 0,
    required this.remainingAmount,
    this.deliveryStatus     = 'pending',
    this.notes              = '',
    required this.createdAt,
    required this.updatedAt,
    this.orderNumber,
    this.customerName,
    this.customerAddress,
    this.customerPhone,
    this.assignedWorkerId   = '',
    this.createdBy          = 'owner',
    this.workerName         = '',
    this.deviceName         = '',
    this.commissionRate     = 0.0,
    this.commissionType     = '',
    this.items    = const [],
    this.payments = const [],
  });

  AppOrder copyWith({
    String? id,
    String? customerId,
    double? subtotal,
    double? discount,
    double? deliveryCharge,
    double? smartRoundedAmount,
    double? grandTotal,
    double? paidAmount,
    double? remainingAmount,
    String? deliveryStatus,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? orderNumber,
    String? customerName,
    String? customerAddress,
    String? customerPhone,
    String? assignedWorkerId,
    String? createdBy,
    String? workerName,
    String? deviceName,
    double? commissionRate,
    String? commissionType,
    List<dynamic>? items,
    List<dynamic>? payments,
  }) {
    return AppOrder(
      id:                  id                  ?? this.id,
      customerId:          customerId          ?? this.customerId,
      subtotal:            subtotal            ?? this.subtotal,
      discount:            discount            ?? this.discount,
      deliveryCharge:      deliveryCharge      ?? this.deliveryCharge,
      smartRoundedAmount:  smartRoundedAmount  ?? this.smartRoundedAmount,
      grandTotal:          grandTotal          ?? this.grandTotal,
      paidAmount:          paidAmount          ?? this.paidAmount,
      remainingAmount:     remainingAmount     ?? this.remainingAmount,
      deliveryStatus:      deliveryStatus      ?? this.deliveryStatus,
      notes:               notes               ?? this.notes,
      createdAt:           createdAt           ?? this.createdAt,
      updatedAt:           updatedAt           ?? this.updatedAt,
      orderNumber:         orderNumber         ?? this.orderNumber,
      customerName:        customerName        ?? this.customerName,
      customerAddress:     customerAddress     ?? this.customerAddress,
      customerPhone:       customerPhone       ?? this.customerPhone,
      assignedWorkerId:    assignedWorkerId    ?? this.assignedWorkerId,
      createdBy:          createdBy           ?? this.createdBy,
      workerName:         workerName          ?? this.workerName,
      deviceName:         deviceName          ?? this.deviceName,
      commissionRate:      commissionRate      ?? this.commissionRate,
      commissionType:      commissionType      ?? this.commissionType,
      items:               items               ?? this.items,
      payments:            payments            ?? this.payments,
    );
  }

  Map<String, dynamic> toMap() => {
        'id':                   id,
        'customer_id':          customerId,
        'subtotal':             subtotal,
        'discount':             discount,
        'delivery_charge':      deliveryCharge,
        'smart_rounded_amount': smartRoundedAmount,
        'grand_total':          grandTotal,
        'paid_amount':          paidAmount,
        'remaining_amount':     remainingAmount,
        'delivery_status':      deliveryStatus,
        'notes':                notes,
        'created_at':           createdAt.toIso8601String(),
        'updated_at':           updatedAt.toIso8601String(),
        'assigned_worker_id':   assignedWorkerId,
        'created_by':          createdBy,
        'worker_name':         workerName,
        'device_name':         deviceName,
        'commission_rate':      commissionRate,
        'commission_type':      commissionType,
      };

  factory AppOrder.fromMap(Map<String, dynamic> map) => AppOrder(
        id:                  map['id']                   as String,
        customerId:          map['customer_id']          as String,
        subtotal:            (map['subtotal']            as num).toDouble(),
        discount:            (map['discount']            as num?)?.toDouble() ?? 0,
        deliveryCharge:      (map['delivery_charge']     as num?)?.toDouble() ?? 0,
        smartRoundedAmount:  (map['smart_rounded_amount']as num?)?.toDouble() ?? 0,
        grandTotal:          (map['grand_total']         as num).toDouble(),
        paidAmount:          (map['paid_amount']         as num?)?.toDouble() ?? 0,
        remainingAmount:     (map['remaining_amount']    as num).toDouble(),
        deliveryStatus:      map['delivery_status']      as String? ?? 'pending',
        notes:               map['notes']                as String? ?? '',
        createdAt:           DateTime.parse(map['created_at'] as String),
        updatedAt:           DateTime.parse(map['updated_at'] as String),
        orderNumber:         map['order_number']         as int?,
        customerName:        map['customer_name']        as String?,
        customerAddress:     map['customer_address']     as String?,
        customerPhone:       map['customer_phone']       as String?,
        assignedWorkerId:    (map['assigned_worker_id'] ?? map['worker_id']) as String? ?? '',
        createdBy:           map['created_by']           as String? ?? 'owner',
        workerName:          map['worker_name']          as String? ?? '',
        deviceName:          map['device_name']          as String? ?? '',
        commissionRate:      (map['commission_rate']     as num?)?.toDouble() ?? 0.0,
        commissionType:      map['commission_type']      as String? ?? '',
      );

  @override
  bool operator ==(Object other) => other is AppOrder && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
