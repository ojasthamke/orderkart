// lib/core/models/worker_permission.dart

enum PermissionLevel {
  hidden, // 0
  view,   // 1
  edit,   // 2
  full;   // 3

  static PermissionLevel fromInt(int val) {
    if (val <= 0) return PermissionLevel.hidden;
    if (val == 1) return PermissionLevel.view;
    if (val == 2) return PermissionLevel.edit;
    return PermissionLevel.full;
  }

  int toInt() {
    switch (this) {
      case PermissionLevel.hidden: return 0;
      case PermissionLevel.view:   return 1;
      case PermissionLevel.edit:   return 2;
      case PermissionLevel.full:   return 3;
    }
  }
}

/// Represents the permission set granted to a worker.
class WorkerPermission {
  final String workerId;
  final PermissionLevel customers;
  final PermissionLevel orders;
  final PermissionLevel payments;
  final PermissionLevel expenses;
  final PermissionLevel sellingPrice;
  final PermissionLevel costPrice;
  final PermissionLevel stock;
  final PermissionLevel items;
  final PermissionLevel vip;
  final PermissionLevel reports;
  final PermissionLevel notes;
  final PermissionLevel export;
  final PermissionLevel import;
  final PermissionLevel settings;
  final PermissionLevel analytics;
  final DateTime updatedAt;

  const WorkerPermission({
    required this.workerId,
    this.customers = PermissionLevel.full,
    this.orders = PermissionLevel.full,
    this.payments = PermissionLevel.full,
    this.expenses = PermissionLevel.full,
    this.sellingPrice = PermissionLevel.full,
    this.costPrice = PermissionLevel.hidden,
    this.stock = PermissionLevel.full,
    this.items = PermissionLevel.view,
    this.vip = PermissionLevel.hidden,
    this.reports = PermissionLevel.view,
    this.notes = PermissionLevel.full,
    this.export = PermissionLevel.full,
    this.import = PermissionLevel.hidden,
    this.settings = PermissionLevel.hidden,
    this.analytics = PermissionLevel.view,
    required this.updatedAt,
  });

  factory WorkerPermission.fromMap(Map<String, dynamic> map) {
    return WorkerPermission(
      workerId: map['worker_id'] as String,
      customers: PermissionLevel.fromInt(map['add_customer'] as int? ?? 3),
      orders: PermissionLevel.fromInt(map['create_order'] as int? ?? 3),
      payments: PermissionLevel.fromInt(map['receive_payment'] as int? ?? 3),
      expenses: PermissionLevel.fromInt(map['add_expenses'] as int? ?? 3),
      sellingPrice: PermissionLevel.fromInt(map['edit_selling_price'] as int? ?? 3),
      costPrice: PermissionLevel.fromInt(map['edit_cost_price'] as int? ?? 0),
      stock: PermissionLevel.fromInt(map['edit_stock_quantity'] as int? ?? 3),
      items: PermissionLevel.fromInt(map['add_new_item'] as int? ?? 1),
      vip: PermissionLevel.fromInt(map['manage_vip'] as int? ?? 0),
      reports: PermissionLevel.fromInt(map['view_reports'] as int? ?? 1),
      notes: PermissionLevel.fromInt(map['edit_notes'] as int? ?? 3),
      export: PermissionLevel.fromInt(map['export_data'] as int? ?? 3),
      import: PermissionLevel.fromInt(map['import_data'] as int? ?? 0),
      settings: PermissionLevel.fromInt(map['backup_restore'] as int? ?? 0),
      analytics: PermissionLevel.fromInt(map['delete_customer'] as int? ?? 1),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'worker_id': workerId,
        'add_customer': customers.toInt(),
        'create_order': orders.toInt(),
        'receive_payment': payments.toInt(),
        'add_expenses': expenses.toInt(),
        'edit_selling_price': sellingPrice.toInt(),
        'edit_cost_price': costPrice.toInt(),
        'edit_stock_quantity': stock.toInt(),
        'add_new_item': items.toInt(),
        'manage_vip': vip.toInt(),
        'view_reports': reports.toInt(),
        'edit_notes': notes.toInt(),
        'export_data': export.toInt(),
        'import_data': import.toInt(),
        'backup_restore': settings.toInt(),
        'delete_customer': analytics.toInt(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
