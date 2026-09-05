/// Item (Inventory) Model
library;

class Item {
  final String id;
  final String name;
  final String category;
  final double costPrice;
  final double sellingPrice;
  final double marketPrice; // Average Market Retail Price
  final double stock;
  final double minStock;
  final String unit;
  final String barcode;
  final DateTime createdAt;
  final DateTime updatedAt;

  // New V6 Fields for Groceries & Medicines
  final String expiryDate;
  final String batchNumber;
  final bool prescriptionRequired;
  final String dosageInfo;
  final String bestBefore;
  final String packDate;
  final double weightPerPiece;
  final String photoPath;
  final int sequenceNo;

  // Order Now Fields
  final double orderNowStock;
  final double orderNowSellingPrice;
  final double orderNowMrp;
  final double orderNowCostPrice;
  final bool isAvailable;
  final bool orderNowIsAvailable;

  bool get isLowStock => stock <= minStock && minStock > 0;
  double get profitMargin =>
      sellingPrice > 0 ? ((sellingPrice - costPrice) / sellingPrice) * 100 : 0;
  double get customerSavings =>
      marketPrice > sellingPrice ? marketPrice - sellingPrice : 0.0;
  double get customerSavingsPct =>
      marketPrice > 0 ? (customerSavings / marketPrice) * 100 : 0.0;

  const Item({
    required this.id,
    required this.name,
    required this.category,
    this.costPrice = 0,
    this.sellingPrice = 0,
    this.marketPrice = 0,
    this.stock = 0,
    this.minStock = 0,
    required this.unit,
    this.barcode = '',
    required this.createdAt,
    required this.updatedAt,
    this.expiryDate = '',
    this.batchNumber = '',
    this.prescriptionRequired = false,
    this.dosageInfo = '',
    this.bestBefore = '',
    this.packDate = '',
    this.weightPerPiece = 0.25,
    this.photoPath = '',
    this.sequenceNo = 0,
    this.orderNowStock = 0,
    this.orderNowSellingPrice = 0,
    this.orderNowMrp = 0,
    this.orderNowCostPrice = 0,
    this.isAvailable = true,
    this.orderNowIsAvailable = true,
  });

  Item copyWith({
    String? id,
    String? name,
    String? category,
    double? costPrice,
    double? sellingPrice,
    double? marketPrice,
    double? stock,
    double? minStock,
    String? unit,
    String? barcode,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? expiryDate,
    String? batchNumber,
    bool? prescriptionRequired,
    String? dosageInfo,
    String? bestBefore,
    String? packDate,
    double? weightPerPiece,
    String? photoPath,
    int? sequenceNo,
    double? orderNowStock,
    double? orderNowSellingPrice,
    double? orderNowMrp,
    double? orderNowCostPrice,
    bool? isAvailable,
    bool? orderNowIsAvailable,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      marketPrice: marketPrice ?? this.marketPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      unit: unit ?? this.unit,
      barcode: barcode ?? this.barcode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiryDate: expiryDate ?? this.expiryDate,
      batchNumber: batchNumber ?? this.batchNumber,
      prescriptionRequired: prescriptionRequired ?? this.prescriptionRequired,
      dosageInfo: dosageInfo ?? this.dosageInfo,
      bestBefore: bestBefore ?? this.bestBefore,
      packDate: packDate ?? this.packDate,
      weightPerPiece: weightPerPiece ?? this.weightPerPiece,
      photoPath: photoPath ?? this.photoPath,
      sequenceNo: sequenceNo ?? this.sequenceNo,
      orderNowStock: orderNowStock ?? this.orderNowStock,
      orderNowSellingPrice: orderNowSellingPrice ?? this.orderNowSellingPrice,
      orderNowMrp: orderNowMrp ?? this.orderNowMrp,
      orderNowCostPrice: orderNowCostPrice ?? this.orderNowCostPrice,
      isAvailable: isAvailable ?? this.isAvailable,
      orderNowIsAvailable: orderNowIsAvailable ?? this.orderNowIsAvailable,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'cost_price': costPrice,
        'selling_price': sellingPrice,
        'market_price': marketPrice,
        'stock': stock,
        'min_stock': minStock,
        'unit': unit,
        'barcode': barcode,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'expiry_date': expiryDate,
        'batch_number': batchNumber,
        'prescription_required': prescriptionRequired ? 1 : 0,
        'dosage_info': dosageInfo,
        'best_before': bestBefore,
        'pack_date': packDate,
        'weight_per_piece': weightPerPiece,
        'photo_path': photoPath,
        'sequence_no': sequenceNo,
        'order_now_stock': orderNowStock,
        'order_now_selling_price': orderNowSellingPrice,
        'order_now_mrp': orderNowMrp,
        'order_now_cost_price': orderNowCostPrice,
        'is_available': isAvailable ? 1 : 0,
        'order_now_is_available': orderNowIsAvailable ? 1 : 0,
      };

  static double _parseDouble(dynamic val, {double fallback = 0.0}) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().trim()) ?? fallback;
  }

  factory Item.fromMap(Map<String, dynamic> map) => Item(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        category: map['category'] as String? ?? 'General',
        costPrice: _parseDouble(map['cost_price']),
        sellingPrice: _parseDouble(map['selling_price']),
        marketPrice: _parseDouble(map['market_price']),
        stock: _parseDouble(map['stock']),
        minStock: _parseDouble(map['min_stock']),
        unit: map['unit'] as String? ?? 'unit',
        barcode: map['barcode'] as String? ?? '',
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
            DateTime.now(),
        expiryDate: map['expiry_date'] as String? ?? '',
        batchNumber: map['batch_number'] as String? ?? '',
        prescriptionRequired: map['prescription_required'] == true ||
            map['prescription_required'] == 1 ||
            map['prescription_required']?.toString().toLowerCase() == 'true' ||
            map['prescription_required']?.toString() == '1',
        dosageInfo: map['dosage_info'] as String? ?? '',
        bestBefore: map['best_before'] as String? ?? '',
        packDate: map['pack_date'] as String? ?? '',
        weightPerPiece: _parseDouble(map['weight_per_piece'], fallback: 0.25),
        photoPath: map['photo_path'] as String? ?? '',
        sequenceNo: (map['sequence_no'] as int?) ?? int.tryParse(map['sequence_no']?.toString() ?? '') ?? 0,
        orderNowStock: _parseDouble(map['order_now_stock']),
        orderNowSellingPrice: _parseDouble(map['order_now_selling_price']),
        orderNowMrp: _parseDouble(map['order_now_mrp']),
        orderNowCostPrice: _parseDouble(map['order_now_cost_price']),
        isAvailable: map['is_available'] == null
            ? true
            : (map['is_available'] == true ||
                map['is_available'] == 1 ||
                map['is_available']?.toString().toLowerCase() == 'true' ||
                map['is_available']?.toString() == '1'),
        orderNowIsAvailable: map['order_now_is_available'] == null
            ? true
            : (map['order_now_is_available'] == true ||
                map['order_now_is_available'] == 1 ||
                map['order_now_is_available']?.toString().toLowerCase() == 'true' ||
                map['order_now_is_available']?.toString() == '1'),
      );

  @override
  bool operator ==(Object other) => other is Item && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
