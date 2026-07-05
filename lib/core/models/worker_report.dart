// lib/core/models/worker_report.dart

/// Represents a periodic report generated for a worker.
class WorkerReport {
  final String id; // UUID primary key
  final String workerId;
  final String reportDate; // ISO date string or YYYY-MM-DD
  final int ordersCount;
  final double salesTotal;
  final double collectionTotal;
  final double pendingTotal;
  final double commissionEarned;
  final double expensesTotal;
  final int customersAdded;
  final DateTime createdAt;

  const WorkerReport({
    required this.id,
    required this.workerId,
    required this.reportDate,
    this.ordersCount = 0,
    this.salesTotal = 0.0,
    this.collectionTotal = 0.0,
    this.pendingTotal = 0.0,
    this.commissionEarned = 0.0,
    this.expensesTotal = 0.0,
    this.customersAdded = 0,
    required this.createdAt,
  });

  factory WorkerReport.fromMap(Map<String, dynamic> map) {
    return WorkerReport(
      id: map['id'] as String,
      workerId: map['worker_id'] as String,
      reportDate: map['report_date'] as String,
      ordersCount: map['orders_count'] as int? ?? 0,
      salesTotal: (map['sales_total'] as num?)?.toDouble() ?? 0.0,
      collectionTotal: (map['collection_total'] as num?)?.toDouble() ?? 0.0,
      pendingTotal: (map['pending_total'] as num?)?.toDouble() ?? 0.0,
      commissionEarned: (map['commission_earned'] as num?)?.toDouble() ?? 0.0,
      expensesTotal: (map['expenses_total'] as num?)?.toDouble() ?? 0.0,
      customersAdded: map['customers_added'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'worker_id': workerId,
        'report_date': reportDate,
        'orders_count': ordersCount,
        'sales_total': salesTotal,
        'collection_total': collectionTotal,
        'pending_total': pendingTotal,
        'commission_earned': commissionEarned,
        'expenses_total': expensesTotal,
        'customers_added': customersAdded,
        'created_at': createdAt.toIso8601String(),
      };
}
