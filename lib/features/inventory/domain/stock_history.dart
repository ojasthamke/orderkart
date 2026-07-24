/// StockHistory — records every stock change
library;

class StockHistory {
  final String id;
  final String itemId;
  final String itemName;
  final double changeAmount;
  final String reason; // order / manual / adjustment
  final String orderId;
  final DateTime createdAt;

  const StockHistory({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.changeAmount,
    this.reason = 'manual',
    this.orderId = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'item_id': itemId,
        'item_name': itemName,
        'change_amount': changeAmount,
        'reason': reason,
        'order_id': orderId,
        'created_at': createdAt.toIso8601String(),
      };

  factory StockHistory.fromMap(Map<String, dynamic> map) => StockHistory(
        id: map['id'] as String,
        itemId: map['item_id'] as String,
        itemName: map['item_name'] as String,
        changeAmount: (map['change_amount'] as num).toDouble(),
        reason: map['reason'] as String? ?? 'manual',
        orderId: map['order_id'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
