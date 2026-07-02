/// Item (Inventory) Model

class Item {
  final String id;
  final String name;
  final String category;
  final double costPrice;
  final double sellingPrice;
  final double stock;
  final double minStock;
  final String unit;
  final String barcode;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLowStock => stock <= minStock && minStock > 0;
  double get profitMargin => sellingPrice > 0 ? ((sellingPrice - costPrice) / sellingPrice) * 100 : 0;

  const Item({
    required this.id,
    required this.name,
    required this.category,
    this.costPrice    = 0,
    this.sellingPrice = 0,
    this.stock        = 0,
    this.minStock     = 0,
    required this.unit,
    this.barcode      = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Item copyWith({
    String? id,
    String? name,
    String? category,
    double? costPrice,
    double? sellingPrice,
    double? stock,
    double? minStock,
    String? unit,
    String? barcode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id:           id           ?? this.id,
      name:         name         ?? this.name,
      category:     category     ?? this.category,
      costPrice:    costPrice    ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stock:        stock        ?? this.stock,
      minStock:     minStock     ?? this.minStock,
      unit:         unit         ?? this.unit,
      barcode:      barcode      ?? this.barcode,
      createdAt:    createdAt    ?? this.createdAt,
      updatedAt:    updatedAt    ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id':            id,
        'name':          name,
        'category':      category,
        'cost_price':    costPrice,
        'selling_price': sellingPrice,
        'stock':         stock,
        'min_stock':     minStock,
        'unit':          unit,
        'barcode':       barcode,
        'created_at':    createdAt.toIso8601String(),
        'updated_at':    updatedAt.toIso8601String(),
      };

  factory Item.fromMap(Map<String, dynamic> map) => Item(
        id:           map['id']            as String,
        name:         map['name']          as String,
        category:     map['category']      as String,
        costPrice:    (map['cost_price']    as num?)?.toDouble() ?? 0,
        sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0,
        stock:        (map['stock']         as num?)?.toDouble() ?? 0,
        minStock:     (map['min_stock']     as num?)?.toDouble() ?? 0,
        unit:         map['unit']           as String,
        barcode:      map['barcode']        as String? ?? '',
        createdAt:    DateTime.parse(map['created_at'] as String),
        updatedAt:    DateTime.parse(map['updated_at'] as String),
      );

  @override
  bool operator ==(Object other) => other is Item && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
