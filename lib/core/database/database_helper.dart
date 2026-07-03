/// DatabaseHelper — SQLite initialisation, schema creation and migrations
/// Uses singleton pattern for single database connection
/// Designed for future cloud sync — all IDs are UUIDs (string), not auto-increment

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/app_constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  /// Returns the open database, initialising it if needed
  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // Enable WAL mode for better concurrent performance
      onOpen: (db) => db.rawQuery('PRAGMA journal_mode=WAL'),
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
}
