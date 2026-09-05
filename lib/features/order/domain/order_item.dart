/// OrderItem — line item within an order
library;

class OrderItem {
  final String id;
  final String orderId;
  final String itemId;
  final String itemName;
  final String itemUnit;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final bool isAvailable;

  const OrderItem({
    required this.id,
    required this.orderId,
    this.itemId = '',
    required this.itemName,
    required this.itemUnit,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.isAvailable = true,
  });

  OrderItem copyWith({
    String? id,
    String? orderId,
    String? itemId,
    String? itemName,
    String? itemUnit,
    double? quantity,
    double? unitPrice,
    double? totalPrice,
    bool? isAvailable,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      itemUnit: itemUnit ?? this.itemUnit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'order_id': orderId,
        'item_id': itemId,
        'item_name': itemName,
        'item_unit': itemUnit,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_price': totalPrice,
        'is_available': isAvailable ? 1 : 0,
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    final rawAvail = map['is_available'];
    final bool isAvail = rawAvail == null
        ? true
        : (rawAvail is bool
            ? rawAvail
            : (rawAvail == 1 ||
                rawAvail == '1' ||
                rawAvail.toString().toLowerCase() == 'true'));
    return OrderItem(
      id: map['id'] as String? ?? '',
      orderId: map['order_id'] as String? ?? '',
      itemId: map['item_id'] as String? ?? '',
      itemName: map['item_name'] as String? ?? '',
      itemUnit: map['item_unit'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0.0,
      isAvailable: isAvail,
    );
  }
}
