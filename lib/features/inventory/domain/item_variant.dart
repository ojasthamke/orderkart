/// Item Variant Model — represents a sub-product/version of a parent item
/// e.g., "Tata Salt 1kg" and "Tata Salt 500g" are variants of "Tata Salt"
library;

class ItemVariant {
  final String id;
  final String parentItemId;
  final String variantLabel; // e.g. "1kg Pack", "500g", "Family Pack"
  final double sellingPrice;
  final double costPrice;
  final double marketPrice;
  final double stock;
  final String unit;
  final String barcode;
  final String photoPath;
  final bool isAvailable;
  final int sequenceNo;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get profitMargin =>
      sellingPrice > 0 ? ((sellingPrice - costPrice) / sellingPrice) * 100 : 0;
  double get customerSavings =>
      marketPrice > sellingPrice ? marketPrice - sellingPrice : 0.0;

  const ItemVariant({
    required this.id,
    required this.parentItemId,
    required this.variantLabel,
    this.sellingPrice = 0,
    this.costPrice = 0,
    this.marketPrice = 0,
    this.stock = 0,
    this.unit = 'unit',
    this.barcode = '',
    this.photoPath = '',
    this.isAvailable = true,
    this.sequenceNo = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  ItemVariant copyWith({
    String? id,
    String? parentItemId,
    String? variantLabel,
    double? sellingPrice,
    double? costPrice,
    double? marketPrice,
    double? stock,
    String? unit,
    String? barcode,
    String? photoPath,
    bool? isAvailable,
    int? sequenceNo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemVariant(
      id: id ?? this.id,
      parentItemId: parentItemId ?? this.parentItemId,
      variantLabel: variantLabel ?? this.variantLabel,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      costPrice: costPrice ?? this.costPrice,
      marketPrice: marketPrice ?? this.marketPrice,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      barcode: barcode ?? this.barcode,
      photoPath: photoPath ?? this.photoPath,
      isAvailable: isAvailable ?? this.isAvailable,
      sequenceNo: sequenceNo ?? this.sequenceNo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'parent_item_id': parentItemId,
        'variant_label': variantLabel,
        'selling_price': sellingPrice,
        'cost_price': costPrice,
        'market_price': marketPrice,
        'stock': stock,
        'unit': unit,
        'barcode': barcode,
        'photo_path': photoPath,
        'image_path': photoPath,
        'is_available': isAvailable ? 1 : 0,
        'sequence_no': sequenceNo,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  static double _parseDouble(dynamic val, {double fallback = 0.0}) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().trim()) ?? fallback;
  }

  factory ItemVariant.fromMap(Map<String, dynamic> map) => ItemVariant(
        id: map['id'] as String? ?? '',
        parentItemId: map['parent_item_id'] as String? ?? '',
        variantLabel: map['variant_label'] as String? ?? '',
        sellingPrice: _parseDouble(map['selling_price']),
        costPrice: _parseDouble(map['cost_price']),
        marketPrice: _parseDouble(map['market_price']),
        stock: _parseDouble(map['stock']),
        unit: map['unit'] as String? ?? 'unit',
        barcode: map['barcode'] as String? ?? '',
        photoPath: (map['photo_path'] ?? map['image_path'] ?? '').toString(),
        isAvailable: map['is_available'] == null
            ? true
            : (map['is_available'] == true ||
                map['is_available'] == 1 ||
                map['is_available']?.toString().toLowerCase() == 'true' ||
                map['is_available']?.toString() == '1'),
        sequenceNo: (map['sequence_no'] as int?) ??
            int.tryParse(map['sequence_no']?.toString() ?? '') ??
            0,
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  @override
  bool operator ==(Object other) => other is ItemVariant && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
