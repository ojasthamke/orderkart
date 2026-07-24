import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/worker_permission_service.dart';
import '../../../core/utils/security_helper.dart';
import '../domain/worker.dart';

class WorkerDao {
  final _uuid = const Uuid();
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Worker>> getAllWorkers() async {
    final db = await _db;
    final maps = await db.query('workers', orderBy: 'name ASC');
    final List<Worker> result = [];

    for (final m in maps) {
      final id = m['id'] as String;
      final custRes = await db.rawQuery(
          'SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "customer"',
          [id]);
      final areaRes = await db.rawQuery(
          'SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "area"',
          [id]);
      final streetRes = await db.rawQuery(
          'SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "street"',
          [id]);
      final catRes = await db.rawQuery(
          'SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "category"',
          [id]);
      final itemRes = await db.rawQuery(
          'SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "item"',
          [id]);
      final routeRes = await db.rawQuery(
          'SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "route"',
          [id]);
      final collRes = await db.rawQuery(
          'SELECT COALESCE(SUM(amount), 0) as v FROM payments p JOIN orders o ON p.order_id = o.id WHERE o.assigned_worker_id = ?',
          [id]);

      final custCount = (custRes.first['v'] as num?)?.toInt() ?? 0;
      final areaCount = (areaRes.first['v'] as num?)?.toInt() ?? 0;
      final streetCount = (streetRes.first['v'] as num?)?.toInt() ?? 0;
      final catCount = (catRes.first['v'] as num?)?.toInt() ?? 0;
      final itemCount = (itemRes.first['v'] as num?)?.toInt() ?? 0;
      final routeCount = (routeRes.first['v'] as num?)?.toInt() ?? 0;
      final collTotal = (collRes.first['v'] as num?)?.toDouble() ?? 0.0;

      final w = Worker.fromMap(m).copyWith(
        assignedCustomersCount: custCount,
        assignedAreasCount: areaCount,
        assignedStreetsCount: streetCount,
        assignedCategoriesCount: catCount,
        assignedItemsCount: itemCount,
        assignedRoutesCount: routeCount,
        totalCollection: collTotal,
      );
      result.add(w);
    }
    return result;
  }

  Future<Worker?> getWorkerById(String id) async {
    final db = await _db;
    final maps = await db.query('workers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;

    final m = maps.first;
    final custRes = await db.rawQuery(
        'SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "customer"',
        [id]);
    final areaRes = await db.rawQuery(
        'SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "area"',
        [id]);
    final streetRes = await db.rawQuery(
        'SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "street"',
        [id]);
    final catRes = await db.rawQuery(
        'SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "category"',
        [id]);
    final itemRes = await db.rawQuery(
        'SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "item"',
        [id]);
    final routeRes = await db.rawQuery(
        'SELECT COUNT(*) as v FROM worker_assignments WHERE worker_id = ? AND entity_type = "route"',
        [id]);
    final collRes = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as v FROM payments p JOIN orders o ON p.order_id = o.id WHERE o.assigned_worker_id = ?',
        [id]);

    return Worker.fromMap(m).copyWith(
      assignedCustomersCount: (custRes.first['v'] as num?)?.toInt() ?? 0,
      assignedAreasCount: (areaRes.first['v'] as num?)?.toInt() ?? 0,
      assignedStreetsCount: (streetRes.first['v'] as num?)?.toInt() ?? 0,
      assignedCategoriesCount: (catRes.first['v'] as num?)?.toInt() ?? 0,
      assignedItemsCount: (itemRes.first['v'] as num?)?.toInt() ?? 0,
      assignedRoutesCount: (routeRes.first['v'] as num?)?.toInt() ?? 0,
      totalCollection: (collRes.first['v'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Future<String> insertWorker(Worker worker) async {
    final db = await _db;
    final id = worker.id.isEmpty ? _uuid.v4() : worker.id;
    final now = DateTime.now().toIso8601String();

    await db.insert(
        'workers',
        {
          ...worker.toMap(),
          'id': id,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);

    // Auto-create worker security secret credential JIT
    final secret = SecurityHelper.generateOwnerSecret();
    await db.insert(
      'worker_security',
      {
        'worker_id': id,
        'worker_secret': secret,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return id;
  }

  Future<void> updateWorker(Worker worker) async {
    final db = await _db;
    final oldRecord = await getWorkerById(worker.id);

    if (oldRecord != null &&
        (oldRecord.commissionValue != worker.commissionValue ||
            oldRecord.commissionType != worker.commissionType)) {
      // Log commission rate change audit entry
      await db.insert('audit_logs', {
        'id': _uuid.v4(),
        'user_type': 'owner',
        'worker_id': worker.id,
        'action': 'COMMISSION_RATE_UPDATED',
        'entity_type': 'worker',
        'entity_id': worker.id,
        'old_value':
            '${oldRecord.commissionType.name}:${oldRecord.commissionValue}%',
        'new_value': '${worker.commissionType.name}:${worker.commissionValue}%',
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    await db.update(
      'workers',
      {...worker.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [worker.id],
    );
  }

  Future<void> deleteWorker(String id) async {
    final db = await _db;
    await db.delete('workers', where: 'id = ?', whereArgs: [id]);
    await db
        .delete('worker_assignments', where: 'worker_id = ?', whereArgs: [id]);
    await db.update('customers', {'assigned_worker_id': ''},
        where: 'assigned_worker_id = ?', whereArgs: [id]);
  }

  // ── Assignments ───────────────────────────────────────────────────────────
  Future<void> setWorkerAssignments({
    required String workerId,
    required String entityType,
    required List<String> entityIds,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'worker_assignments',
        where: 'worker_id = ? AND entity_type = ?',
        whereArgs: [workerId, entityType],
      );

      for (final id in entityIds) {
        await txn.insert('worker_assignments', {
          'id': _uuid.v4(),
          'worker_id': workerId,
          'entity_type': entityType,
          'entity_id': id,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (entityType == 'customer') {
        await txn.update(
          'customers',
          {'assigned_worker_id': ''},
          where: 'assigned_worker_id = ?',
          whereArgs: [workerId],
        );
        for (final custId in entityIds) {
          await txn.update(
            'customers',
            {'assigned_worker_id': workerId},
            where: 'id = ?',
            whereArgs: [custId],
          );
        }
      }

      // Mark worker package as outdated since assignments changed!
      await txn.update(
        'workers',
        {
          'is_package_outdated': 1,
          'updated_at': DateTime.now().toIso8601String()
        },
        where: 'id = ?',
        whereArgs: [workerId],
      );
    });
  }

  Future<void> markPackageGenerated(String workerId) async {
    final db = await _db;
    final w = await getWorkerById(workerId);
    if (w == null) return;

    final nextVer = w.packageVersion + 1;
    final nowStr = DateTime.now().toIso8601String();

    await db.update(
      'workers',
      {
        'package_version': nextVer,
        'last_package_generated': nowStr,
        'is_package_outdated': 0,
        'updated_at': nowStr,
      },
      where: 'id = ?',
      whereArgs: [workerId],
    );
  }

  Future<void> assignEntity(
      String workerId, String entityType, String entityId) async {
    final db = await _db;
    await db.insert(
        'worker_assignments',
        {
          'id': _uuid.v4(),
          'worker_id': workerId,
          'entity_type': entityType,
          'entity_id': entityId,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);

    if (entityType == 'customer') {
      await db.update('customers', {'assigned_worker_id': workerId},
          where: 'id = ?', whereArgs: [entityId]);
    }
  }

  Future<void> unassignEntity(
      String workerId, String entityType, String entityId) async {
    final db = await _db;
    await db.delete('worker_assignments',
        where: 'worker_id = ? AND entity_type = ? AND entity_id = ?',
        whereArgs: [workerId, entityType, entityId]);

    if (entityType == 'customer') {
      await db.update('customers', {'assigned_worker_id': ''},
          where: 'id = ? AND assigned_worker_id = ?',
          whereArgs: [entityId, workerId]);
    }
  }

  Future<List<String>> getAssignedEntityIds(
      String workerId, String entityType) async {
    final db = await _db;
    final res = await db.query('worker_assignments',
        columns: ['entity_id'],
        where: 'worker_id = ? AND entity_type = ?',
        whereArgs: [workerId, entityType]);
    return res.map((r) => r['entity_id'] as String).toList();
  }

  /// Transfer assignments from Worker A to Worker B
  Future<void> transferAssignments({
    required String fromWorkerId,
    required String toWorkerId,
    required String entityType, // 'area', 'street', 'customer'
  }) async {
    final db = await _db;
    if (entityType == 'customer') {
      await db.update('customers', {'assigned_worker_id': toWorkerId},
          where: 'assigned_worker_id = ?', whereArgs: [fromWorkerId]);
    }
    await db.update('worker_assignments', {'worker_id': toWorkerId},
        where: 'worker_id = ? AND entity_type = ?',
        whereArgs: [fromWorkerId, entityType]);
  }

  /// Worker Commission Calculation with historical snapshot protection
  Future<Map<String, double>> getWorkerCommissionSummary(
      String workerId) async {
    final db = await _db;
    final worker = await getWorkerById(workerId);
    if (worker == null) {
      return {'today': 0, 'monthly': 0, 'total': 0, 'pending': 0};
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // Calculate sum of snapshotted order commissions
    Future<double> calcHistoricalCommission(
        String? dateClause, List<dynamic> params) async {
      String sql =
          'SELECT grand_total, paid_amount, commission_rate FROM orders WHERE assigned_worker_id = ?';
      if (dateClause != null) sql += ' AND $dateClause';

      final orders = await db.rawQuery(sql, [workerId, ...params]);
      double total = 0.0;
      for (final o in orders) {
        final gt = (o['grand_total'] as num?)?.toDouble() ?? 0.0;
        final paid = (o['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final rate = (o['commission_rate'] as num?)?.toDouble();
        final effectiveRate =
            (rate != null && rate > 0) ? rate : worker.commissionValue;

        switch (worker.commissionType) {
          case CommissionType.fixed:
            total += effectiveRate;
            break;
          case CommissionType.pctCollection:
            total += (paid * effectiveRate) / 100.0;
            break;
          case CommissionType.pctOrder:
          case CommissionType.mixed:
          default:
            total += (gt * effectiveRate) / 100.0;
            break;
        }
      }
      return total;
    }

    final todayComm =
        await calcHistoricalCommission('DATE(created_at) = DATE(?)', [today]);
    final monComm = await calcHistoricalCommission(
        'strftime("%Y-%m", created_at) = ?', [month]);
    final totComm = await calcHistoricalCommission(null, []);

    return {
      'today': todayComm,
      'monthly': monComm,
      'total': totComm,
      'pending': totComm * 0.5,
    };
  }

  // ── Permissions ───────────────────────────────────────────────────────────
  Future<Map<String, bool>> getWorkerPermissions(String workerId) async {
    final wp = await WorkerPermissionService.getPermissionsForWorker(workerId);
    final map = wp.toMap();
    final Map<String, bool> perms = {};
    map.forEach((key, val) {
      if (val is int) {
        perms[key] = val > 0; // > 0 means granted (View, Edit, or Full)
      }
    });
    return perms;
  }

  Future<void> updateWorkerPermissions(
      String workerId, Map<String, bool> permissions) async {
    final db = await _db;
    final Map<String, dynamic> row = {
      'worker_id': workerId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    permissions.forEach((key, val) {
      row[key] = val ? 1 : 0;
    });

    await db.insert('worker_permissions', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
