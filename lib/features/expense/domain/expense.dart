/// Expense Model
library;

class Expense {
  final String id;
  final String name;
  final String category;
  final double amount;
  final DateTime date;
  final String notes;
  final String paymentMethod; // cash / online
  final DateTime createdAt;
  final DateTime updatedAt;
  final String receiptPhotoPath;

  const Expense({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
    required this.date,
    this.notes = '',
    this.paymentMethod = 'cash',
    required this.createdAt,
    required this.updatedAt,
    this.receiptPhotoPath = '',
  });

  Expense copyWith({
    String? id,
    String? name,
    String? category,
    double? amount,
    DateTime? date,
    String? notes,
    String? paymentMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? receiptPhotoPath,
  }) {
    return Expense(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      receiptPhotoPath: receiptPhotoPath ?? this.receiptPhotoPath,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'notes': notes,
        'payment_method': paymentMethod,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'receipt_photo_path': receiptPhotoPath,
      };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        category: map['category'] as String? ?? 'General',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        date:
            DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
        notes: map['notes'] as String? ?? '',
        paymentMethod: map['payment_method'] as String? ?? 'cash',
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
            DateTime.now(),
        receiptPhotoPath: map['receipt_photo_path'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) => other is Expense && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
