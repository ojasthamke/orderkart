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
  final double outstandingBalance;
  final int    totalOrders;
  final double totalPaid;
  final double totalPending;
  final DateTime customerSince;
  final String  lastOrderDate;   // ISO string, may be empty
  final DateTime createdAt;
  final DateTime updatedAt;

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
    this.outstandingBalance = 0,
    this.totalOrders    = 0,
    this.totalPaid      = 0,
    this.totalPending   = 0,
    required this.customerSince,
    this.lastOrderDate  = '',
    required this.createdAt,
    required this.updatedAt,
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
    double? outstandingBalance,
    int?    totalOrders,
    double? totalPaid,
    double? totalPending,
    DateTime? customerSince,
    String?   lastOrderDate,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      totalOrders:        totalOrders        ?? this.totalOrders,
      totalPaid:          totalPaid          ?? this.totalPaid,
      totalPending:       totalPending       ?? this.totalPending,
      customerSince:      customerSince      ?? this.customerSince,
      lastOrderDate:      lastOrderDate      ?? this.lastOrderDate,
      createdAt:          createdAt          ?? this.createdAt,
      updatedAt:          updatedAt          ?? this.updatedAt,
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
        'outstanding_balance': outstandingBalance,
        'total_orders':        totalOrders,
        'total_paid':          totalPaid,
        'total_pending':       totalPending,
        'customer_since':      customerSince.toIso8601String(),
        'last_order_date':     lastOrderDate,
        'created_at':          createdAt.toIso8601String(),
        'updated_at':          updatedAt.toIso8601String(),
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
        outstandingBalance:  (map['outstanding_balance'] as num?)?.toDouble() ?? 0,
        totalOrders:         map['total_orders']        as int?    ?? 0,
        totalPaid:           (map['total_paid']          as num?)?.toDouble() ?? 0,
        totalPending:        (map['total_pending']        as num?)?.toDouble() ?? 0,
        customerSince:       DateTime.parse(map['customer_since'] as String),
        lastOrderDate:       map['last_order_date']     as String? ?? '',
        createdAt:           DateTime.parse(map['created_at']    as String),
        updatedAt:           DateTime.parse(map['updated_at']    as String),
      );

  String get mainHouseNumber {
    if (houseNumber.contains('|')) {
      return houseNumber.split('|')[0].trim();
    }
    return '';
  }

  String get subHouseNumber {
    if (houseNumber.contains('|')) {
      return houseNumber.split('|')[1].trim();
    }
    return houseNumber;
  }

  @override
  bool operator ==(Object other) => other is Customer && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
