/// Item (Inventory) Model
library;

class Item {
  final String id;
  final String name;
  final String category;
  final double costPrice;
  final double sellingPrice;
  final double marketPrice;   // Average Market Retail Price
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

  bool get isLowStock => stock <= minStock && minStock > 0;
  double get profitMargin => sellingPrice > 0 ? ((sellingPrice - costPrice) / sellingPrice) * 100 : 0;
  double get customerSavings => marketPrice > sellingPrice ? marketPrice - sellingPrice : 0.0;
  double get customerSavingsPct => marketPrice > 0 ? (customerSavings / marketPrice) * 100 : 0.0;

  const Item({
    required this.id,
    required this.name,
    required this.category,
    this.costPrice    = 0,
    this.sellingPrice = 0,
    this.marketPrice  = 0,
    this.stock        = 0,
    this.minStock     = 0,
    required this.unit,
    this.barcode      = '',
    required this.createdAt,
    required this.updatedAt,
    this.expiryDate   = '',
    this.batchNumber  = '',
    this.prescriptionRequired = false,
    this.dosageInfo   = '',
    this.bestBefore   = '',
    this.packDate     = '',
    this.weightPerPiece = 0.25,
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
  }) {
    return Item(
      id:           id           ?? this.id,
      name:         name         ?? this.name,
      category:     category     ?? this.category,
      costPrice:    costPrice    ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      marketPrice:  marketPrice  ?? this.marketPrice,
      stock:        stock        ?? this.stock,
      minStock:     minStock     ?? this.minStock,
      unit:         unit         ?? this.unit,
      barcode:      barcode      ?? this.barcode,
      createdAt:    createdAt    ?? this.createdAt,
      updatedAt:    updatedAt    ?? this.updatedAt,
      expiryDate:   expiryDate   ?? this.expiryDate,
      batchNumber:  batchNumber  ?? this.batchNumber,
      prescriptionRequired: prescriptionRequired ?? this.prescriptionRequired,
      dosageInfo:   dosageInfo   ?? this.dosageInfo,
      bestBefore:   bestBefore   ?? this.bestBefore,
      packDate:     packDate     ?? this.packDate,
      weightPerPiece: weightPerPiece ?? this.weightPerPiece,
    );
  }

  Map<String, dynamic> toMap() => {
        'id':            id,
        'name':          name,
        'category':      category,
        'cost_price':    costPrice,
        'selling_price': sellingPrice,
        'market_price':  marketPrice,
        'stock':         stock,
        'min_stock':     minStock,
        'unit':          unit,
        'barcode':       barcode,
        'created_at':    createdAt.toIso8601String(),
        'updated_at':    updatedAt.toIso8601String(),
        'expiry_date':   expiryDate,
        'batch_number':  batchNumber,
        'prescription_required': prescriptionRequired ? 1 : 0,
        'dosage_info':   dosageInfo,
        'best_before':   bestBefore,
        'pack_date':     packDate,
        'weight_per_piece': weightPerPiece,
      };

  factory Item.fromMap(Map<String, dynamic> map) => Item(
        id:           map['id']            as String,
        name:         map['name']          as String,
        category:     map['category']      as String,
        costPrice:    (map['cost_price']    as num?)?.toDouble() ?? 0,
        sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0,
        marketPrice:  (map['market_price']  as num?)?.toDouble() ?? 0,
        stock:        (map['stock']        as num?)?.toDouble() ?? 0,
        minStock:     (map['min_stock']    as num?)?.toDouble() ?? 0,
        unit:         map['unit']          as String,
        barcode:      map['barcode']       as String? ?? '',
        createdAt:    DateTime.parse(map['created_at'] as String),
        updatedAt:    DateTime.parse(map['updated_at'] as String),
        expiryDate:   map['expiry_date']   as String? ?? '',
        batchNumber:  map['batch_number']  as String? ?? '',
        prescriptionRequired: (map['prescription_required'] as int? ?? 0) == 1,
        dosageInfo:   map['dosage_info']   as String? ?? '',
        bestBefore:   map['best_before']   as String? ?? '',
        packDate:     map['pack_date']     as String? ?? '',
        weightPerPiece: (map['weight_per_piece'] as num?)?.toDouble() ?? 0.25,
      );

  @override
  bool operator ==(Object other) => other is Item && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
