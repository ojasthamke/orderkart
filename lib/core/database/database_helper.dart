/// DatabaseHelper — SQLite initialisation, schema creation and migrations
/// Uses singleton pattern for single database connection
/// Designed for future cloud sync — all IDs are UUIDs (string), not auto-increment

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/app_constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static String? dbNameOverride;

  Database? _db;

  /// Returns the open database, initialising it if needed
  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  /// Sets up full schema on any target database (e.g. temporary in-memory database)
  Future<void> createSchema(Database db) async {
    await _createTables(db);
    await _createIndexes(db);
    await _createV3Tables(db);
    await _createV4Tables(db);
    await _ensureVipColumns(db);
    await _ensurePriceHistoryTables(db);
    await _ensureAreaAndStreetColumns(db);
    await _ensureV4Columns(db);
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final name = dbNameOverride ?? AppConstants.dbName;
    final path = join(dbPath, name);

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await _ensureVipColumns(db);
        await _ensurePriceHistoryTables(db);
        await _ensureAreaAndStreetColumns(db);
        await _createV4Tables(db);
        await _ensureV4Columns(db);
        await _runStartupHealthCheck(db);
        await _runAutoCleanup(db);
      },
    );
  }

  /// Creates all tables and indexes on first run
  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _createIndexes(db);
    await _seedDefaultSettings(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add serial_no column (integer, default 0 = unset)
      await db.execute(
          'ALTER TABLE customers ADD COLUMN serial_no INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      await _createV3Tables(db);
    }
    if (oldVersion < 4) {
      await _createV4Tables(db);
    }
  }

  Future<void> _createV3Tables(Database db) async {
    // Notifications
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id           TEXT PRIMARY KEY,
        title        TEXT NOT NULL,
        body         TEXT NOT NULL,
        category     TEXT NOT NULL,
        related_id   TEXT DEFAULT '',
        is_read      INTEGER DEFAULT 0,
        priority     INTEGER DEFAULT 0,
        created_at   TEXT NOT NULL
      )
    ''');

    // Notes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id           TEXT PRIMARY KEY,
        title        TEXT NOT NULL,
        content      TEXT NOT NULL,
        remind_at    TEXT DEFAULT '',
        priority     INTEGER DEFAULT 0,
        color_label  INTEGER DEFAULT 0,
        is_pinned    INTEGER DEFAULT 0,
        is_completed INTEGER DEFAULT 0,
        is_archived  INTEGER DEFAULT 0,
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL
      )
    ''');

    // Visits (Route Planner)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS visits (
        id           TEXT PRIMARY KEY,
        date         TEXT NOT NULL,
        area_id      TEXT NOT NULL,
        street_id    TEXT DEFAULT '',
        notes        TEXT DEFAULT '',
        priority     INTEGER DEFAULT 0,
        status       TEXT NOT NULL DEFAULT 'pending',
        created_at   TEXT NOT NULL
      )
    ''');
    
    // V3 Indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_created ON notes(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_visits_date ON visits(date)');
  }

  Future<void> createTablesForDatabase(Database db) async {
    await _createTables(db);
    await _ensureVipColumns(db);
    await _ensureV4Columns(db);
  }

  Future<void> _createTables(Database db) async {
    // Areas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS areas (
        id           TEXT PRIMARY KEY,
        name         TEXT NOT NULL,
        description  TEXT DEFAULT '',
        color        INTEGER DEFAULT 0,
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL
      )
    ''');

    // Streets
    await db.execute('''
      CREATE TABLE IF NOT EXISTS streets (
        id           TEXT PRIMARY KEY,
        area_id      TEXT NOT NULL,
        name         TEXT NOT NULL,
        description  TEXT DEFAULT '',
        created_at   TEXT NOT NULL,
        FOREIGN KEY(area_id) REFERENCES areas(id) ON DELETE CASCADE
      )
    ''');

    // Customers
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id                  TEXT PRIMARY KEY,
        street_id           TEXT NOT NULL,
        name                TEXT NOT NULL,
        phone1              TEXT NOT NULL,
        phone2              TEXT DEFAULT '',
        whatsapp            TEXT DEFAULT '',
        house_number        TEXT DEFAULT '',
        address             TEXT DEFAULT '',
        notes               TEXT DEFAULT '',
        maps_location       TEXT DEFAULT '',
        photo_path          TEXT DEFAULT '',
        serial_no           INTEGER DEFAULT 0,
        outstanding_balance REAL DEFAULT 0,
        total_orders        INTEGER DEFAULT 0,
        total_paid          REAL DEFAULT 0,
        total_pending       REAL DEFAULT 0,
        customer_since      TEXT NOT NULL,
        last_order_date     TEXT DEFAULT '',
        created_at          TEXT NOT NULL,
        updated_at          TEXT NOT NULL,
        FOREIGN KEY(street_id) REFERENCES streets(id) ON DELETE CASCADE
      )
    ''');

    // Items (Inventory)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS items (
        id            TEXT PRIMARY KEY,
        name          TEXT NOT NULL,
        category      TEXT NOT NULL,
        cost_price    REAL NOT NULL DEFAULT 0,
        selling_price REAL NOT NULL DEFAULT 0,
        stock         REAL DEFAULT 0,
        min_stock     REAL DEFAULT 0,
        unit          TEXT NOT NULL DEFAULT 'kg',
        barcode       TEXT DEFAULT '',
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL
      )
    ''');

    // Orders
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id                   TEXT PRIMARY KEY,
        customer_id          TEXT NOT NULL,
        subtotal             REAL NOT NULL DEFAULT 0,
        discount             REAL DEFAULT 0,
        delivery_charge      REAL DEFAULT 0,
        smart_rounded_amount REAL DEFAULT 0,
        grand_total          REAL NOT NULL DEFAULT 0,
        paid_amount          REAL DEFAULT 0,
        remaining_amount     REAL NOT NULL DEFAULT 0,
        delivery_status      TEXT NOT NULL DEFAULT 'pending',
        notes                TEXT DEFAULT '',
        created_at           TEXT NOT NULL,
        updated_at           TEXT NOT NULL,
        FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
      )
    ''');

    // Order Items (line items within an order)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
        id          TEXT PRIMARY KEY,
        order_id    TEXT NOT NULL,
        item_id     TEXT DEFAULT '',
        item_name   TEXT NOT NULL,
        item_unit   TEXT NOT NULL,
        quantity    REAL NOT NULL DEFAULT 1,
        unit_price  REAL NOT NULL DEFAULT 0,
        total_price REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE
      )
    ''');

    // Payments
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id          TEXT PRIMARY KEY,
        order_id    TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        amount      REAL NOT NULL DEFAULT 0,
        method      TEXT NOT NULL DEFAULT 'cash',
        notes       TEXT DEFAULT '',
        created_at  TEXT NOT NULL,
        FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE
      )
    ''');

    // Expenses
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id             TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        category       TEXT NOT NULL DEFAULT 'Other',
        amount         REAL NOT NULL DEFAULT 0,
        date           TEXT NOT NULL,
        notes          TEXT DEFAULT '',
        payment_method TEXT NOT NULL DEFAULT 'cash',
        created_at     TEXT NOT NULL,
        updated_at     TEXT NOT NULL
      )
    ''');

    // Stock History
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_history (
        id            TEXT PRIMARY KEY,
        item_id       TEXT NOT NULL,
        item_name     TEXT NOT NULL,
        change_amount REAL NOT NULL DEFAULT 0,
        reason        TEXT NOT NULL DEFAULT 'manual',
        order_id      TEXT DEFAULT '',
        created_at    TEXT NOT NULL,
        FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE CASCADE
      )
    ''');

    // Settings (key-value store)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _createV3Tables(db);
  }

  Future<void> _createIndexes(Database db) async {
    // Performance indexes for large datasets (10k+ customers, 50k+ orders)
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_created  ON orders(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_status   ON orders(delivery_status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_street ON customers(street_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_streets_area    ON streets(area_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_order  ON payments(order_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_customer ON payments(customer_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_item      ON stock_history(item_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_date   ON expenses(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_items_category  ON items(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_customer_created ON orders(customer_id, created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_serial ON customers(serial_no)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_outstanding ON customers(outstanding_balance)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id)');
  }

  /// Seeds default settings on fresh install
  Future<void> _seedDefaultSettings(Database db) async {
    final defaults = {
      AppConstants.keyBusinessName:   'My Business',
      AppConstants.keyOwnerName:      'Owner',
      AppConstants.keyPhone:          '',
      AppConstants.keyWhatsApp:       '',
      AppConstants.keyDeliveryCharge: '10.0',
      AppConstants.keySmartRounding:  'true',
      AppConstants.keyCurrency:       '₹',
      AppConstants.keyThemeMode:      'system',
      AppConstants.keyNotifications:  'true',
      AppConstants.keyDailySummary:   'true',
      AppConstants.keyLowStockAlert:  'true',
      AppConstants.keyPendingAlert:   'true',
      AppConstants.keyVisitAlert:     'true',
      AppConstants.keyNoteReminders:  'true',
      AppConstants.keyNotifTime:      '06:00',
      AppConstants.keyNotifSound:     'true',
      AppConstants.keyNotifVibration: 'true',
      AppConstants.keyBackupReminder: 'true',
      AppConstants.keyQrContent:      '',
      AppConstants.keyStaffWhatsApp:  '',
      AppConstants.keyLastDeliveryCharge: '10.0',
    };

    for (final entry in defaults.entries) {
      await db.insert(
        'settings',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// Wipes all data — used by Reset App feature
  Future<void> resetDatabase() async {
    final db = await database;
    await db.execute('DELETE FROM payments');
    await db.execute('DELETE FROM order_items');
    await db.execute('DELETE FROM orders');
    await db.execute('DELETE FROM stock_history');
    await db.execute('DELETE FROM customers');
    await db.execute('DELETE FROM streets');
    await db.execute('DELETE FROM areas');
    await db.execute('DELETE FROM items');
    await db.execute('DELETE FROM expenses');
    // Re-seed defaults but keep settings
  }

  /// Closes the database connection
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  Future<void> _ensureVipColumns(Database db) async {
    final cols = [
      'ALTER TABLE customers ADD COLUMN is_vip INTEGER DEFAULT 0',
      "ALTER TABLE customers ADD COLUMN vip_plan TEXT DEFAULT 'Gold VIP'",
      "ALTER TABLE customers ADD COLUMN vip_start_date TEXT DEFAULT ''",
      "ALTER TABLE customers ADD COLUMN vip_expiry_date TEXT DEFAULT ''",
      'ALTER TABLE customers ADD COLUMN vip_subscription_fee REAL DEFAULT 0',
      "ALTER TABLE customers ADD COLUMN vip_notes TEXT DEFAULT ''",
      'ALTER TABLE customers ADD COLUMN vip_auto_renewal INTEGER DEFAULT 0',
      'ALTER TABLE customers ADD COLUMN vip_free_delivery INTEGER DEFAULT 1',
      'ALTER TABLE customers ADD COLUMN vip_discount_pct REAL DEFAULT 10.0',
      'ALTER TABLE customers ADD COLUMN vip_markup_pct REAL DEFAULT 5.0',
      'ALTER TABLE customers ADD COLUMN vip_priority_delivery INTEGER DEFAULT 1',
    ];
    for (final col in cols) {
      try {
        await db.execute(col);
      } catch (_) {
        // Column already exists, ignore
      }
    }
  }

  Future<void> _ensurePriceHistoryTables(Database db) async {
    try {
      await db.execute('ALTER TABLE items ADD COLUMN market_price REAL DEFAULT 0');
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS item_price_history (
        id            TEXT PRIMARY KEY,
        item_id       TEXT NOT NULL,
        date          TEXT NOT NULL,
        selling_price REAL NOT NULL,
        market_price  REAL DEFAULT 0,
        created_at    TEXT NOT NULL,
        FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_price_hist_date ON item_price_history(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_price_hist_item ON item_price_history(item_id)');
  }

  Future<void> _ensureAreaAndStreetColumns(Database db) async {
    try {
      await db.execute("ALTER TABLE areas ADD COLUMN photo_path TEXT DEFAULT ''");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE areas ADD COLUMN maps_location TEXT DEFAULT ''");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE streets ADD COLUMN photo_path TEXT DEFAULT ''");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE streets ADD COLUMN maps_location TEXT DEFAULT ''");
    } catch (_) {}
  }

  /// Helper to check if a table is selected for modular import
  bool _isTableSelected(String table, List<String>? selectedModules) {
    if (selectedModules == null || selectedModules.isEmpty) return true;
    if (selectedModules.contains('entire_db')) return true;

    switch (table) {
      case 'areas':
        return selectedModules.contains('areas') || selectedModules.contains('entire_db');
      case 'streets':
        return selectedModules.contains('streets') || selectedModules.contains('entire_db');
      case 'customers':
      case 'vip_membership':
        return selectedModules.contains('customers') || selectedModules.contains('entire_db');
      case 'items':
      case 'item_price_history':
        return selectedModules.contains('items') || selectedModules.contains('entire_db');
      case 'orders':
      case 'order_items':
      case 'payments':
        return selectedModules.contains('orders') || selectedModules.contains('entire_db');
      case 'expenses':
        return selectedModules.contains('expenses') || selectedModules.contains('entire_db');
      case 'notes':
        return selectedModules.contains('notes') || selectedModules.contains('entire_db');
      case 'visits':
        return selectedModules.contains('visits') || selectedModules.contains('streets') || selectedModules.contains('entire_db');
      case 'notifications':
        return selectedModules.contains('notifications') || selectedModules.contains('entire_db');
      case 'workers':
      case 'worker_assignments':
      case 'worker_permissions':
      case 'worker_reports':
      case 'commission_history':
        return selectedModules.contains('workers') || selectedModules.contains('entire_db');
      case 'business_profile':
      case 'settings':
        return selectedModules.contains('settings') || selectedModules.contains('entire_db');
      default:
        return false;
    }
  }

  /// Smart Non-Destructive Merge Import Specification:
  /// Performs topological merge across database tables with LWW (Last-Write-Wins) timestamp conflict resolution.
  /// Returns a detailed map per table: {'inserted': int, 'updated': int, 'skipped': int, 'conflicted': int}.
  Future<Map<String, Map<String, int>>> mergeDatabaseFromPath(
    String incomingDbPath, {
    List<String>? selectedModules,
    bool dryRun = false,
    Function(double progress, int processed, int total)? onProgress,
  }) async {
    final targetDb = await database;
    final incomingDb = await openDatabase(incomingDbPath, readOnly: true);

    // Topological dependency order: Parents before Children
    final tables = [
      'areas',
      'streets',
      'customers',
      'vip_membership',
      'items',
      'item_price_history',
      'orders',
      'order_items',
      'payments',
      'expenses',
      'notes',
      'visits',
      'notifications',
      'workers',
      'worker_assignments',
      'worker_permissions',
      'worker_reports',
      'commission_history',
      'business_profile',
      'settings'
    ];

    // First count total rows to calculate progress
    int totalRows = 0;
    final Map<String, List<Map<String, dynamic>>> incomingData = {};
    for (final table in tables) {
      if (!_isTableSelected(table, selectedModules)) continue;
      try {
        final rows = await incomingDb.query(table);
        incomingData[table] = rows;
        totalRows += rows.length;
      } catch (_) {}
    }

    final Map<String, Map<String, int>> resultStats = {};
    int processedRows = 0;
    final safeTotalRows = totalRows == 0 ? 1 : totalRows;

    Future<void> runMerge(DatabaseExecutor dbExecutor) async {
      for (final table in tables) {
        int inserted = 0;
        int updated = 0;
        int skipped = 0;
        int conflicted = 0;

        if (!_isTableSelected(table, selectedModules)) {
          resultStats[table] = {
            'inserted': 0,
            'updated': 0,
            'skipped': 0,
            'conflicted': 0,
          };
          continue;
        }

        final incomingRows = incomingData[table] ?? [];
        for (final row in incomingRows) {
          final id = row['id']?.toString() ?? 
                     row['key']?.toString() ?? 
                     row['worker_id']?.toString() ?? '';
          if (id.isEmpty) {
            skipped++;
            processedRows++;
            onProgress?.call(processedRows / safeTotalRows, processedRows, totalRows);
            continue;
          }

          List<Map<String, dynamic>> existing;
          if (table == 'settings') {
            final key = id.toLowerCase();
            const protectedKeys = {
              'app_mode',
              'owner_pin_hash',
              'owner_pin_salt',
              'app_initialized',
              'active_worker_id',
              'owner_secret',
              'owner_secret_v1',
              'owner_secret_v2',
              'owner_failed_pin_attempts',
              'owner_pin_lockout_until',
            };
            if (protectedKeys.contains(key)) {
              skipped++;
              processedRows++;
              onProgress?.call(processedRows / safeTotalRows, processedRows, totalRows);
              continue; // Protect local session keys from being overwritten!
            }
            existing = await dbExecutor.query(table, where: 'key = ?', whereArgs: [id]);
          } else if (table == 'worker_permissions') {
            existing = await dbExecutor.query(table, where: 'worker_id = ?', whereArgs: [id]);
          } else {
            existing = await dbExecutor.query(table, where: 'id = ?', whereArgs: [id]);
          }

          if (existing.isEmpty) {
            try {
              if (!dryRun) {
                await dbExecutor.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
              }
              inserted++;
            } catch (_) {
              conflicted++;
            }
          } else {
            // Compare values or timestamps (LWW - Last-Write-Wins)
            if (table == 'settings') {
              final existingVal = existing.first['value']?.toString() ?? '';
              final incomingVal = row['value']?.toString() ?? '';
              if (existingVal != incomingVal) {
                if (!dryRun) {
                  await dbExecutor.update(table, row, where: 'key = ?', whereArgs: [id]);
                }
                updated++;
              } else {
                skipped++;
              }
              processedRows++;
              onProgress?.call(processedRows / safeTotalRows, processedRows, totalRows);
              continue;
            }

            final existingUpdated = existing.first['updated_at']?.toString() ?? existing.first['created_at']?.toString() ?? '';
            final incomingUpdated = row['updated_at']?.toString() ?? row['created_at']?.toString() ?? '';

            if (incomingUpdated.isNotEmpty && existingUpdated.isNotEmpty) {
              final incDt = DateTime.tryParse(incomingUpdated);
              final exDt  = DateTime.tryParse(existingUpdated);

              if (incDt != null && exDt != null && incDt.isAfter(exDt)) {
                if (!dryRun) {
                  if (table == 'settings') {
                    await dbExecutor.update(table, row, where: 'key = ?', whereArgs: [id]);
                  } else if (table == 'worker_permissions') {
                    await dbExecutor.update(table, row, where: 'worker_id = ?', whereArgs: [id]);
                  } else {
                    await dbExecutor.update(table, row, where: 'id = ?', whereArgs: [id]);
                  }
                }
                updated++;
              } else {
                skipped++;
              }
            } else {
              skipped++;
            }
          }
          processedRows++;
          onProgress?.call(processedRows / safeTotalRows, processedRows, totalRows);
        }

        resultStats[table] = {
          'inserted': inserted,
          'updated': updated,
          'skipped': skipped,
          'conflicted': conflicted,
        };
      }
    }

    if (dryRun) {
      await runMerge(targetDb);
    } else {
      await targetDb.transaction((txn) async {
        await runMerge(txn);
        await _runRecalculations(txn);
      });
    }

    await incomingDb.close();
    return resultStats;
  }

  /// Recalculates outstanding balances, VIP memberships, worker stats/commissions upon import
  Future<void> _runRecalculations(DatabaseExecutor db) async {
    // 1. Recalculate customer statistics
    await db.rawUpdate('''
      UPDATE customers SET
        total_orders = (
          SELECT COUNT(*) FROM orders 
          WHERE orders.customer_id = customers.id AND delivery_status != 'cancelled'
        ),
        total_paid = (
          SELECT COALESCE(SUM(paid_amount), 0) FROM orders 
          WHERE orders.customer_id = customers.id AND delivery_status != 'cancelled'
        ),
        total_pending = (
          SELECT COALESCE(SUM(remaining_amount), 0) FROM orders 
          WHERE orders.customer_id = customers.id AND delivery_status != 'cancelled'
        ),
        outstanding_balance = (
          SELECT COALESCE(SUM(remaining_amount), 0) FROM orders 
          WHERE orders.customer_id = customers.id AND delivery_status != 'cancelled'
        ),
        last_order_date = COALESCE((
          SELECT MAX(created_at) FROM orders 
          WHERE orders.customer_id = customers.id AND delivery_status != 'cancelled'
        ), '')
    ''');

    // 2. Recalculate Worker Reports and Worker Commissions
    final workers = await db.query('workers');
    for (final w in workers) {
      final workerId = w['id'] as String;
      final commTypeStr = w['commission_type'] as String? ?? 'pct_order';
      final commValue = (w['commission_value'] as num?)?.toDouble() ?? 5.0;

      final datesResult = await db.rawQuery('''
        SELECT DISTINCT DATE(created_at) as d FROM orders WHERE assigned_worker_id = ?
        UNION
        SELECT DISTINCT DATE(created_at) as d FROM payments WHERE order_id IN (SELECT id FROM orders WHERE assigned_worker_id = ?)
      ''', [workerId, workerId]);

      for (final dr in datesResult) {
        final dateStr = dr['d'] as String?;
        if (dateStr == null || dateStr.isEmpty) continue;

        final ordersRes = await db.rawQuery('''
          SELECT COUNT(*) as count, SUM(grand_total) as sales, SUM(paid_amount) as paid, SUM(remaining_amount) as pending
          FROM orders
          WHERE assigned_worker_id = ? AND DATE(created_at) = DATE(?) AND delivery_status != 'cancelled'
        ''', [workerId, dateStr]);

        final paymentsRes = await db.rawQuery('''
          SELECT SUM(amount) as collected
          FROM payments
          WHERE order_id IN (SELECT id FROM orders WHERE assigned_worker_id = ?) AND DATE(created_at) = DATE(?)
        ''', [workerId, dateStr]);

        final expensesRes = await db.rawQuery('''
          SELECT SUM(amount) as expenses FROM expenses WHERE assigned_worker_id = ? AND date = ?
        ''', [workerId, dateStr]);

        final customersRes = await db.rawQuery('''
          SELECT COUNT(*) as count FROM customers WHERE created_by = ? AND DATE(created_at) = DATE(?)
        ''', [workerId, dateStr]);

        final ordersCount = (ordersRes.first['count'] as num?)?.toInt() ?? 0;
        final salesTotal = (ordersRes.first['sales'] as num?)?.toDouble() ?? 0.0;
        final collectionTotal = (paymentsRes.first['collected'] as num?)?.toDouble() ?? 0.0;
        final pendingTotal = (ordersRes.first['pending'] as num?)?.toDouble() ?? 0.0;
        final expensesTotal = (expensesRes.first['expenses'] as num?)?.toDouble() ?? 0.0;
        final customersAdded = (customersRes.first['count'] as num?)?.toInt() ?? 0;

        double commissionEarned = 0.0;
        if (commTypeStr == 'fixed') {
          commissionEarned = ordersCount * commValue;
        } else if (commTypeStr == 'pct_collection') {
          commissionEarned = (collectionTotal * commValue) / 100.0;
        } else {
          commissionEarned = (salesTotal * commValue) / 100.0;
        }

        final reportId = '${workerId}_$dateStr';
        await db.insert('worker_reports', {
          'id': reportId,
          'worker_id': workerId,
          'report_date': dateStr,
          'orders_count': ordersCount,
          'sales_total': salesTotal,
          'collection_total': collectionTotal,
          'pending_total': pendingTotal,
          'commission_earned': commissionEarned,
          'expenses_total': expensesTotal,
          'customers_added': customersAdded,
          'created_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  Future<void> _createV4Tables(Database db) async {
    // Workers
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workers (
        id                TEXT PRIMARY KEY,
        name              TEXT NOT NULL,
        photo_path        TEXT DEFAULT '',
        phone             TEXT DEFAULT '',
        address           TEXT DEFAULT '',
        joining_date      TEXT DEFAULT '',
        employee_id       TEXT DEFAULT '',
        status            TEXT NOT NULL DEFAULT 'active',
        pin_hash          TEXT DEFAULT '',
        commission_type   TEXT NOT NULL DEFAULT 'pct_order',
        commission_value  REAL DEFAULT 5.0,
        salary            REAL DEFAULT 0,
        bonus             REAL DEFAULT 0,
        notes             TEXT DEFAULT '',
        aadhaar_id        TEXT DEFAULT '',
        emergency_contact TEXT DEFAULT '',
        bank_details      TEXT DEFAULT '',
        target            REAL DEFAULT 0.0,
        joining_salary    REAL DEFAULT 0.0,
        leave_status      TEXT DEFAULT 'active',
        remarks           TEXT DEFAULT '',
        created_at        TEXT NOT NULL,
        updated_at        TEXT NOT NULL
      )
    ''');

    // Worker Security (isolated key storage)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS worker_security (
        worker_id     TEXT PRIMARY KEY,
        worker_secret TEXT NOT NULL,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL,
        FOREIGN KEY(worker_id) REFERENCES workers(id) ON DELETE CASCADE
      )
    ''');

    // Worker Assignments
    await db.execute('''
      CREATE TABLE IF NOT EXISTS worker_assignments (
        id          TEXT PRIMARY KEY,
        worker_id   TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id   TEXT NOT NULL,
        created_at  TEXT NOT NULL
      )
    ''');

    // Worker Reports
    await db.execute('''
      CREATE TABLE IF NOT EXISTS worker_reports (
        id                TEXT PRIMARY KEY,
        worker_id         TEXT NOT NULL,
        report_date       TEXT NOT NULL,
        orders_count      INTEGER DEFAULT 0,
        sales_total       REAL DEFAULT 0,
        collection_total  REAL DEFAULT 0,
        pending_total     REAL DEFAULT 0,
        commission_earned REAL DEFAULT 0,
        expenses_total    REAL DEFAULT 0,
        customers_added   INTEGER DEFAULT 0,
        created_at        TEXT NOT NULL
      )
    ''');

    // Sync History
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_history (
        id              TEXT PRIMARY KEY,
        worker_id       TEXT DEFAULT '',
        worker_name     TEXT DEFAULT '',
        device_name     TEXT DEFAULT '',
        sync_date       TEXT NOT NULL,
        customers_count INTEGER DEFAULT 0,
        orders_count    INTEGER DEFAULT 0,
        payments_count  INTEGER DEFAULT 0,
        expenses_count  INTEGER DEFAULT 0,
        photos_count    INTEGER DEFAULT 0,
        status          TEXT NOT NULL DEFAULT 'success',
        duration_ms     INTEGER DEFAULT 0,
        errors          TEXT DEFAULT '',
        metadata_json   TEXT DEFAULT '{}'
      )
    ''');

    // Audit Logs / Activity Logs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id          TEXT PRIMARY KEY,
        user_type   TEXT NOT NULL DEFAULT 'owner',
        worker_id   TEXT DEFAULT '',
        action      TEXT NOT NULL,
        entity_type TEXT DEFAULT '',
        entity_id   TEXT DEFAULT '',
        old_value   TEXT DEFAULT '',
        new_value   TEXT DEFAULT '',
        device_name TEXT DEFAULT '',
        created_at  TEXT NOT NULL
      )
    ''');

    // Pending Sync Queue
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_sync (
        id           TEXT PRIMARY KEY,
        entity_type  TEXT NOT NULL,
        entity_id    TEXT NOT NULL,
        action_type  TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at   TEXT NOT NULL,
        status       TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    // Worker Devices
    await db.execute('''
      CREATE TABLE IF NOT EXISTS worker_devices (
        id          TEXT PRIMARY KEY,
        worker_id   TEXT NOT NULL,
        device_name TEXT NOT NULL,
        android_id  TEXT DEFAULT '',
        app_version TEXT DEFAULT '',
        last_sync   TEXT DEFAULT '',
        created_at  TEXT NOT NULL
      )
    ''');

    // Business Profile
    await db.execute('''
      CREATE TABLE IF NOT EXISTS business_profile (
        id               TEXT PRIMARY KEY,
        business_name    TEXT NOT NULL DEFAULT 'OrderKart',
        owner_name       TEXT DEFAULT '',
        phone            TEXT DEFAULT '',
        whatsapp         TEXT DEFAULT '',
        email            TEXT DEFAULT '',
        address          TEXT DEFAULT '',
        gst_number       TEXT DEFAULT '',
        upi_id           TEXT DEFAULT '',
        logo_path        TEXT DEFAULT '',
        qr_path          TEXT DEFAULT '',
        invoice_footer   TEXT DEFAULT '',
        bank_details     TEXT DEFAULT '',
        support_number   TEXT DEFAULT '',
        terms_conditions TEXT DEFAULT '',
        created_at       TEXT NOT NULL,
        updated_at       TEXT NOT NULL
      )
    ''');

    // VIP Membership / Subscriptions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vip_membership (
        id                TEXT PRIMARY KEY,
        customer_id       TEXT NOT NULL,
        plan_name         TEXT NOT NULL DEFAULT 'Gold VIP',
        start_date        TEXT NOT NULL,
        expiry_date       TEXT NOT NULL,
        fee               REAL DEFAULT 0,
        discount_pct      REAL DEFAULT 10.0,
        markup_pct        REAL DEFAULT 5.0,
        free_delivery     INTEGER DEFAULT 1,
        priority_delivery INTEGER DEFAULT 1,
        status            TEXT NOT NULL DEFAULT 'active',
        created_at        TEXT NOT NULL
      )
    ''');

    // Commission History
    await db.execute('''
      CREATE TABLE IF NOT EXISTS commission_history (
        id                TEXT PRIMARY KEY,
        worker_id         TEXT NOT NULL,
        period_start      TEXT NOT NULL,
        period_end        TEXT NOT NULL,
        gross_sales       REAL DEFAULT 0,
        collection_amount REAL DEFAULT 0,
        commission_type   TEXT NOT NULL,
        rate              REAL DEFAULT 0,
        calculated_amount REAL DEFAULT 0,
        status            TEXT NOT NULL DEFAULT 'unpaid',
        paid_date         TEXT DEFAULT '',
        created_at        TEXT NOT NULL
      )
    ''');

    // Repair Logs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS repair_logs (
        id           TEXT PRIMARY KEY,
        date         TEXT NOT NULL,
        issue_type   TEXT NOT NULL,
        details      TEXT DEFAULT '',
        action_taken TEXT DEFAULT ''
      )
    ''');

    // Export History
    await db.execute('''
      CREATE TABLE IF NOT EXISTS export_history (
        id           TEXT PRIMARY KEY,
        package_id   TEXT NOT NULL,
        package_type TEXT NOT NULL,
        modules      TEXT DEFAULT '',
        exported_at  TEXT NOT NULL,
        destination  TEXT DEFAULT '',
        record_count INTEGER DEFAULT 0,
        status       TEXT DEFAULT 'success',
        error_log    TEXT DEFAULT ''
      )
    ''');

    // Import History
    await db.execute('''
      CREATE TABLE IF NOT EXISTS import_history (
        id           TEXT PRIMARY KEY,
        package_id   TEXT NOT NULL,
        imported_at  TEXT NOT NULL,
        worker_name  TEXT DEFAULT '',
        device_name  TEXT DEFAULT '',
        record_count INTEGER DEFAULT 0,
        status       TEXT DEFAULT 'success',
        error_log    TEXT DEFAULT ''
      )
    ''');

    // Worker Permissions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS worker_permissions (
        worker_id           TEXT PRIMARY KEY,
        add_customer        INTEGER DEFAULT 1,
        edit_customer       INTEGER DEFAULT 1,
        delete_customer     INTEGER DEFAULT 0,
        create_order        INTEGER DEFAULT 1,
        edit_order          INTEGER DEFAULT 1,
        cancel_order        INTEGER DEFAULT 0,
        receive_payment     INTEGER DEFAULT 1,
        edit_stock_quantity INTEGER DEFAULT 1,
        edit_selling_price  INTEGER DEFAULT 1,
        edit_cost_price     INTEGER DEFAULT 0,
        add_new_item        INTEGER DEFAULT 0,
        delete_item         INTEGER DEFAULT 0,
        add_expenses        INTEGER DEFAULT 1,
        export_data         INTEGER DEFAULT 1,
        import_data         INTEGER DEFAULT 0,
        view_reports        INTEGER DEFAULT 1,
        edit_notes          INTEGER DEFAULT 1,
        manage_vip          INTEGER DEFAULT 0,
        backup_restore      INTEGER DEFAULT 0,
        updated_at          TEXT NOT NULL
      )
    ''');

    // Indexes for V4 performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_worker_assign_wid ON worker_assignments(worker_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_worker_rep_wid ON worker_reports(worker_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pending_sync_status ON pending_sync(status)');
  }

  Future<void> _ensureV4Columns(Database db) async {
    final customerCols = [
      "ALTER TABLE customers ADD COLUMN assigned_worker_id TEXT DEFAULT ''",
      "ALTER TABLE customers ADD COLUMN created_by TEXT DEFAULT 'owner'",
      "ALTER TABLE customers ADD COLUMN updated_by TEXT DEFAULT 'owner'",
      "ALTER TABLE customers ADD COLUMN device_id TEXT DEFAULT ''",
      "ALTER TABLE customers ADD COLUMN is_archived INTEGER DEFAULT 0",
    ];
    for (final col in customerCols) {
      try { await db.execute(col); } catch (_) {}
    }

    final orderCols = [
      "ALTER TABLE orders ADD COLUMN created_by TEXT DEFAULT 'owner'",
      "ALTER TABLE orders ADD COLUMN assigned_worker_id TEXT DEFAULT ''",
      "ALTER TABLE orders ADD COLUMN device_name TEXT DEFAULT ''",
      "ALTER TABLE orders ADD COLUMN order_source TEXT DEFAULT 'owner'",
      "ALTER TABLE orders ADD COLUMN commission_rate REAL DEFAULT 0.0",
      "ALTER TABLE orders ADD COLUMN commission_type TEXT DEFAULT ''",
      "ALTER TABLE orders ADD COLUMN is_archived INTEGER DEFAULT 0",
    ];
    for (final col in orderCols) {
      try { await db.execute(col); } catch (_) {}
    }

    final itemCols = [
      "ALTER TABLE items ADD COLUMN assigned_worker_id TEXT DEFAULT ''",
      "ALTER TABLE items ADD COLUMN updated_by TEXT DEFAULT 'owner'",
      "ALTER TABLE items ADD COLUMN is_archived INTEGER DEFAULT 0",
    ];
    for (final col in itemCols) {
      try { await db.execute(col); } catch (_) {}
    }

    final expenseCols = [
      "ALTER TABLE expenses ADD COLUMN created_by TEXT DEFAULT 'owner'",
      "ALTER TABLE expenses ADD COLUMN assigned_worker_id TEXT DEFAULT ''",
      "ALTER TABLE expenses ADD COLUMN is_archived INTEGER DEFAULT 0",
    ];
    for (final col in expenseCols) {
      try { await db.execute(col); } catch (_) {}
    }

    final otherCols = [
      "ALTER TABLE areas ADD COLUMN is_archived INTEGER DEFAULT 0",
      "ALTER TABLE streets ADD COLUMN is_archived INTEGER DEFAULT 0",
    ];
    for (final col in otherCols) {
      try { await db.execute(col); } catch (_) {}
    }

    final workerCols = [
      "ALTER TABLE workers ADD COLUMN aadhaar_id TEXT DEFAULT ''",
      "ALTER TABLE workers ADD COLUMN emergency_contact TEXT DEFAULT ''",
      "ALTER TABLE workers ADD COLUMN bank_details TEXT DEFAULT ''",
      "ALTER TABLE workers ADD COLUMN target REAL DEFAULT 0.0",
      "ALTER TABLE workers ADD COLUMN joining_salary REAL DEFAULT 0.0",
      "ALTER TABLE workers ADD COLUMN leave_status TEXT DEFAULT 'active'",
      "ALTER TABLE workers ADD COLUMN remarks TEXT DEFAULT ''",
      "ALTER TABLE workers ADD COLUMN pin_hash TEXT DEFAULT ''",
      "ALTER TABLE workers ADD COLUMN last_package_generated TEXT DEFAULT ''",
      "ALTER TABLE workers ADD COLUMN package_version INTEGER DEFAULT 0",
      "ALTER TABLE workers ADD COLUMN is_package_outdated INTEGER DEFAULT 1",
    ];
    for (final col in workerCols) {
      try { await db.execute(col); } catch (_) {}
    }

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS worker_security (
          worker_id     TEXT PRIMARY KEY,
          worker_secret TEXT NOT NULL,
          created_at    TEXT NOT NULL,
          updated_at    TEXT NOT NULL,
          FOREIGN KEY(worker_id) REFERENCES workers(id) ON DELETE CASCADE
        )
      ''');
    } catch (_) {}

    final permissionCols = [
      "ALTER TABLE worker_permissions ADD COLUMN edit_stock_quantity INTEGER DEFAULT 1",
      "ALTER TABLE worker_permissions ADD COLUMN edit_selling_price INTEGER DEFAULT 1",
      "ALTER TABLE worker_permissions ADD COLUMN edit_cost_price INTEGER DEFAULT 0",
      "ALTER TABLE worker_permissions ADD COLUMN add_new_item INTEGER DEFAULT 0",
      "ALTER TABLE worker_permissions ADD COLUMN delete_item INTEGER DEFAULT 0",
    ];
    for (final col in permissionCols) {
      try { await db.execute(col); } catch (_) {}
    }

    final businessProfileCols = [
      "ALTER TABLE business_profile ADD COLUMN bank_details TEXT DEFAULT ''",
      "ALTER TABLE business_profile ADD COLUMN support_number TEXT DEFAULT ''",
      "ALTER TABLE business_profile ADD COLUMN terms_conditions TEXT DEFAULT ''",
    ];
    for (final col in businessProfileCols) {
      try { await db.execute(col); } catch (_) {}
    }

    await _ensureOwnershipColumns(db);
  }

  Future<void> _ensureOwnershipColumns(Database db) async {
    final tables = ['areas', 'streets', 'customers', 'orders', 'payments', 'expenses', 'notes', 'visits', 'items'];
    for (final table in tables) {
      try {
        await db.execute("ALTER TABLE $table ADD COLUMN created_by TEXT DEFAULT 'owner'");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE $table ADD COLUMN assigned_worker_id TEXT DEFAULT ''");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE $table ADD COLUMN worker_id TEXT DEFAULT ''");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE $table ADD COLUMN worker_name TEXT DEFAULT ''");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE $table ADD COLUMN device_name TEXT DEFAULT ''");
      } catch (_) {}
    }
  }

  Future<void> _runStartupHealthCheck(Database db) async {
    try {
      // 1. Check integrity
      final List<Map<String, dynamic>> integrityRes = await db.rawQuery('PRAGMA integrity_check(10)');
      String integrityStatus = 'ok';
      if (integrityRes.isNotEmpty) {
        final firstVal = integrityRes.first.values.first?.toString() ?? '';
        if (firstVal.toLowerCase() != 'ok') {
          integrityStatus = integrityRes.map((r) => r.values.join(',')).join('; ');
        }
      }
      
      if (integrityStatus != 'ok') {
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        await db.insert('repair_logs', {
          'id': 'integrity_$id',
          'date': DateTime.now().toIso8601String(),
          'issue_type': 'Integrity Violation',
          'details': 'Integrity check failed: $integrityStatus',
          'action_taken': 'Logged'
        });
      }

      // 2. Check foreign keys
      final List<Map<String, dynamic>> fkRes = await db.rawQuery('PRAGMA foreign_key_check');
      if (fkRes.isNotEmpty) {
        final details = fkRes.map((r) => 'Table: ${r['table']}, Rowid: ${r['rowid']}, Parent: ${r['parent']}, Fkid: ${r['fkid']}').join('; ');
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        await db.insert('repair_logs', {
          'id': 'fk_$id',
          'date': DateTime.now().toIso8601String(),
          'issue_type': 'Foreign Key Violation',
          'details': details,
          'action_taken': 'Logged'
        });
      }
    } catch (e) {
      print('Database health check failed: $e');
    }
  }

  Future<void> _runAutoCleanup(Database db) async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      
      // Clean old audit logs
      await db.delete('audit_logs', where: 'created_at < ?', whereArgs: [cutoffDate]);
      
      // Clean old sync history
      await db.delete('sync_history', where: 'sync_date < ?', whereArgs: [cutoffDate]);
      
      // Clean old repair logs
      await db.delete('repair_logs', where: 'date < ?', whereArgs: [cutoffDate]);
      
      // Clean temporary ZIP files in getTemporaryDirectory
      try {
        final tempDir = await getTemporaryDirectory();
        if (tempDir.existsSync()) {
          final List<FileSystemEntity> files = tempDir.listSync();
          for (final file in files) {
            if (file is File && file.path.endsWith('.zip')) {
              // Delete old zip files (older than 1 day)
              final lastMod = file.lastModifiedSync();
              if (DateTime.now().difference(lastMod).inDays >= 1) {
                file.deleteSync();
              }
            }
          }
        }
      } catch (_) {
        // Silent catch — temporary directory may not be initialized in unit tests
      }
    } catch (e) {
      print('Auto-cleanup database error: $e');
    }
  }
}



