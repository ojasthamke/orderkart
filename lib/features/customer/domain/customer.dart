/// Customer Model — belongs to a Street

class Customer {
  final String id;
  final String streetId;
  final String name;
  final String phone1;
  final String phone2;
  final String whatsapp;
  final String houseNumber;
  final String address;
  final String notes;
  final String mapsLocation;
  final String photoPath;
  final int    serialNo;
  final double outstandingBalance;
  final int    totalOrders;
  final double totalPaid;
  final double totalPending;
  final DateTime customerSince;
  final String  lastOrderDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  // VIP Membership Fields
  final bool   isVip;
  final String vipPlan;             // 'Gold', 'Platinum', 'Custom', etc.
  final String vipStartDate;        // ISO string
  final String vipExpiryDate;       // ISO string
  final double vipSubscriptionFee;
  final String vipNotes;
  final bool   vipAutoRenewal;
  final bool   vipFreeDelivery;
  final double vipDiscountPct;      // 5%, 10%, 15%, 20%, or Custom %
  final double vipMarkupPct;        // 5% price markup for 10% discount, 10% for 20%
  final bool   vipPriorityDelivery;

  const Customer({
    required this.id,
    required this.streetId,
    required this.name,
    required this.phone1,
    this.phone2         = '',
    this.whatsapp       = '',
    this.houseNumber    = '',
    this.address        = '',
    this.notes          = '',
    this.mapsLocation   = '',
    this.photoPath      = '',
    this.serialNo       = 0,
    this.outstandingBalance = 0,
    this.totalOrders    = 0,
    this.totalPaid      = 0,
    this.totalPending   = 0,
    required this.customerSince,
    this.lastOrderDate  = '',
    required this.createdAt,
    required this.updatedAt,
    // VIP Defaults
    this.isVip               = false,
    this.vipPlan             = 'Gold VIP',
    this.vipStartDate        = '',
    this.vipExpiryDate       = '',
    this.vipSubscriptionFee  = 0.0,
    this.vipNotes            = '',
    this.vipAutoRenewal      = false,
    this.vipFreeDelivery     = true,
    this.vipDiscountPct      = 10.0,
    this.vipMarkupPct        = 5.0,
    this.vipPriorityDelivery = true,
  });

  Customer copyWith({
    String? id,
    String? streetId,
    String? name,
    String? phone1,
    String? phone2,
    String? whatsapp,
    String? houseNumber,
    String? address,
    String? notes,
    String? mapsLocation,
    String? photoPath,
    int?    serialNo,
    double? outstandingBalance,
    int?    totalOrders,
    double? totalPaid,
    double? totalPending,
    DateTime? customerSince,
    String?   lastOrderDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool?   isVip,
    String? vipPlan,
    String? vipStartDate,
    String? vipExpiryDate,
    double? vipSubscriptionFee,
    String? vipNotes,
    bool?   vipAutoRenewal,
    bool?   vipFreeDelivery,
    double? vipDiscountPct,
    double? vipMarkupPct,
    bool?   vipPriorityDelivery,
  }) {
    return Customer(
      id:                 id                 ?? this.id,
      streetId:           streetId           ?? this.streetId,
      name:               name               ?? this.name,
      phone1:             phone1             ?? this.phone1,
      phone2:             phone2             ?? this.phone2,
      whatsapp:           whatsapp           ?? this.whatsapp,
      houseNumber:        houseNumber        ?? this.houseNumber,
      address:            address            ?? this.address,
      notes:              notes              ?? this.notes,
      mapsLocation:       mapsLocation       ?? this.mapsLocation,
      photoPath:          photoPath          ?? this.photoPath,
      serialNo:           serialNo           ?? this.serialNo,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      totalOrders:        totalOrders        ?? this.totalOrders,
      totalPaid:          totalPaid          ?? this.totalPaid,
      totalPending:       totalPending       ?? this.totalPending,
      customerSince:      customerSince      ?? this.customerSince,
      lastOrderDate:      lastOrderDate      ?? this.lastOrderDate,
      createdAt:          createdAt          ?? this.createdAt,
      updatedAt:          updatedAt          ?? this.updatedAt,
      isVip:               isVip               ?? this.isVip,
      vipPlan:             vipPlan             ?? this.vipPlan,
      vipStartDate:        vipStartDate        ?? this.vipStartDate,
      vipExpiryDate:       vipExpiryDate       ?? this.vipExpiryDate,
      vipSubscriptionFee:  vipSubscriptionFee  ?? this.vipSubscriptionFee,
      vipNotes:            vipNotes            ?? this.vipNotes,
      vipAutoRenewal:      vipAutoRenewal      ?? this.vipAutoRenewal,
      vipFreeDelivery:     vipFreeDelivery     ?? this.vipFreeDelivery,
      vipDiscountPct:      vipDiscountPct      ?? this.vipDiscountPct,
      vipMarkupPct:        vipMarkupPct        ?? this.vipMarkupPct,
      vipPriorityDelivery: vipPriorityDelivery ?? this.vipPriorityDelivery,
    );
  }

  Map<String, dynamic> toMap() => {
        'id':                  id,
        'street_id':           streetId,
        'name':                name,
        'phone1':              phone1,
        'phone2':              phone2,
        'whatsapp':            whatsapp,
        'house_number':        houseNumber,
        'address':             address,
        'notes':               notes,
        'maps_location':       mapsLocation,
        'photo_path':          photoPath,
        'serial_no':           serialNo,
        'outstanding_balance': outstandingBalance,
        'total_orders':        totalOrders,
        'total_paid':          totalPaid,
        'total_pending':       totalPending,
        'customer_since':      customerSince.toIso8601String(),
        'last_order_date':     lastOrderDate,
        'created_at':          createdAt.toIso8601String(),
        'updated_at':          updatedAt.toIso8601String(),
        'is_vip':               isVip ? 1 : 0,
        'vip_plan':             vipPlan,
        'vip_start_date':       vipStartDate,
        'vip_expiry_date':      vipExpiryDate,
        'vip_subscription_fee': vipSubscriptionFee,
        'vip_notes':            vipNotes,
        'vip_auto_renewal':      vipAutoRenewal ? 1 : 0,
        'vip_free_delivery':     vipFreeDelivery ? 1 : 0,
        'vip_discount_pct':      vipDiscountPct,
        'vip_markup_pct':        vipMarkupPct,
        'vip_priority_delivery': vipPriorityDelivery ? 1 : 0,
      };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id:                  map['id']                  as String,
        streetId:            map['street_id']           as String,
        name:                map['name']                as String,
        phone1:              map['phone1']              as String,
        phone2:              map['phone2']              as String? ?? '',
        whatsapp:            map['whatsapp']            as String? ?? '',
        houseNumber:         map['house_number']        as String? ?? '',
        address:             map['address']             as String? ?? '',
        notes:               map['notes']               as String? ?? '',
        mapsLocation:        map['maps_location']       as String? ?? '',
        photoPath:           map['photo_path']          as String? ?? '',
        serialNo:            map['serial_no']           as int?    ?? 0,
        outstandingBalance:  (map['outstanding_balance'] as num?)?.toDouble() ?? 0,
        totalOrders:         map['total_orders']        as int?    ?? 0,
        totalPaid:           (map['total_paid']          as num?)?.toDouble() ?? 0,
        totalPending:        (map['total_pending']        as num?)?.toDouble() ?? 0,
        customerSince:       DateTime.parse(map['customer_since'] as String),
        lastOrderDate:       map['last_order_date']     as String? ?? '',
        createdAt:           DateTime.parse(map['created_at']    as String),
        updatedAt:           DateTime.parse(map['updated_at']    as String),
        isVip:               (map['is_vip'] as int? ?? 0) == 1,
        vipPlan:             map['vip_plan']            as String? ?? 'Gold VIP',
        vipStartDate:        map['vip_start_date']       as String? ?? '',
        vipExpiryDate:       map['vip_expiry_date']      as String? ?? '',
        vipSubscriptionFee:  (map['vip_subscription_fee'] as num?)?.toDouble() ?? 0.0,
        vipNotes:            map['vip_notes']           as String? ?? '',
        vipAutoRenewal:      (map['vip_auto_renewal'] as int? ?? 0) == 1,
        vipFreeDelivery:     (map['vip_free_delivery'] as int? ?? 1) == 1,
        vipDiscountPct:      (map['vip_discount_pct'] as num?)?.toDouble() ?? 10.0,
        vipMarkupPct:        (map['vip_markup_pct'] as num?)?.toDouble() ?? 5.0,
        vipPriorityDelivery: (map['vip_priority_delivery'] as int? ?? 1) == 1,
      );

  String get serialLabel => serialNo > 0 ? '#$serialNo' : '';

  /// VIP Active Status calculation
  bool get isVipActive {
    if (!isVip) return false;
    if (vipExpiryDate.isEmpty) return true;
    final exp = DateTime.tryParse(vipExpiryDate);
    if (exp == null) return true;
    return exp.isAfter(DateTime.now());
  }

  /// Check if VIP membership is expiring within 7 days
  bool get isVipExpiringSoon {
    if (!isVipActive) return false;
    if (vipExpiryDate.isEmpty) return false;
    final exp = DateTime.tryParse(vipExpiryDate);
    if (exp == null) return false;
    final diff = exp.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 7;
  }

  int get daysUntilVipExpiry {
    if (vipExpiryDate.isEmpty) return 999;
    final exp = DateTime.tryParse(vipExpiryDate);
    if (exp == null) return 999;
    return exp.difference(DateTime.now()).inDays;
  }

  /// Tag Badge (VIP, Regular, New, Inactive)
  String get tag {
    if (isVipActive) return 'VIP';
    if (totalOrders >= 8 || totalPaid >= 5000) return 'VIP';
    if (totalOrders >= 3) return 'Regular';
    final now = DateTime.now();
    if (now.difference(customerSince).inDays <= 30) return 'New';
    if (lastOrderDate.isNotEmpty) {
      final lastDate = DateTime.tryParse(lastOrderDate);
      if (lastDate != null && now.difference(lastDate).inDays > 30) {
        return 'Inactive';
      }
    }
    return 'Regular';
  }

  double get advanceBalance => outstandingBalance < 0 ? outstandingBalance.abs() : 0.0;

  @override
  bool operator ==(Object other) => other is Customer && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
