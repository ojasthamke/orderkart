/// Payment Model

class Payment {
  final String id;
  final String orderId;
  final String customerId;
  final double amount;
  final String method;  // cash / online / upi / card
  final String notes;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.amount,
    required this.method,
    this.notes    = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id':          id,
        'order_id':    orderId,
        'customer_id': customerId,
        'amount':      amount,
        'method':      method,
        'notes':       notes,
        'created_at':  createdAt.toIso8601String(),
      };

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id:         map['id']          as String,
        orderId:    map['order_id']    as String,
        customerId: map['customer_id'] as String,
        amount:     (map['amount']     as num).toDouble(),
        method:     map['method']      as String,
        notes:      map['notes']       as String? ?? '',
        createdAt:  DateTime.parse(map['created_at'] as String),
      );
}
