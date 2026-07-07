// lib/core/database/database_seeder.dart

import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';

class DatabaseSeeder {
  DatabaseSeeder._();

  static const _uuid = Uuid();
  static final _random = Random(42); // Seeded for deterministic generation

  /// Seeds 30 Vegetables, 10 Fruits, 10 Areas, 50 Streets, 500 Customers, 200 VIP Memberships
  static Future<Map<String, int>> seedAll({bool clearExisting = false}) async {
    final db = await DatabaseHelper.instance.database;

    if (clearExisting) {
      await db.delete('vip_membership');
      await db.delete('customers');
      await db.delete('streets');
      await db.delete('areas');
      await db.delete('items');
    }

    await _seedAreasAndStreetsAndCustomers(db);
    final int itemsCount = await _seedVegetablesAndFruits(db);

    return {
      'areas': 10,
      'streets': 50,
      'customers': 500,
      'vip': 200,
      'vegetables': 30,
      'fruits': 10,
      'total_items': itemsCount,
    };
  }

  // ── 1. VEGETABLES (30) & FRUITS (10) ──────────────────────────────────────
  static Future<int> _seedVegetablesAndFruits(Database db) async {
    final now = DateTime.now().toIso8601String();

    final vegetables = [
      {'name': 'Potato (Aloo)', 'unit': 'kg', 'cost': 22.0, 'price': 30.0, 'stock': 150.0},
      {'name': 'Tomato (Tamatar)', 'unit': 'kg', 'cost': 35.0, 'price': 45.0, 'stock': 120.0},
      {'name': 'Onion (Pyaz)', 'unit': 'kg', 'cost': 28.0, 'price': 38.0, 'stock': 180.0},
      {'name': 'Spinach (Palak)', 'unit': 'bunch', 'cost': 15.0, 'price': 25.0, 'stock': 60.0},
      {'name': 'Carrot (Gajar)', 'unit': 'kg', 'cost': 40.0, 'price': 55.0, 'stock': 85.0},
      {'name': 'Cauliflower (Phool Gobi)', 'unit': 'pc', 'cost': 30.0, 'price': 42.0, 'stock': 70.0},
      {'name': 'Cabbage (Patta Gobi)', 'unit': 'kg', 'cost': 20.0, 'price': 32.0, 'stock': 90.0},
      {'name': 'Brinjal (Baingan)', 'unit': 'kg', 'cost': 32.0, 'price': 45.0, 'stock': 65.0},
      {'name': 'Okra (Bhindi)', 'unit': 'kg', 'cost': 45.0, 'price': 60.0, 'stock': 75.0},
      {'name': 'Bottle Gourd (Lauki)', 'unit': 'kg', 'cost': 25.0, 'price': 35.0, 'stock': 55.0},
      {'name': 'Bitter Gourd (Karela)', 'unit': 'kg', 'cost': 40.0, 'price': 58.0, 'stock': 45.0},
      {'name': 'Cucumber (Kheera)', 'unit': 'kg', 'cost': 30.0, 'price': 40.0, 'stock': 95.0},
      {'name': 'Capsicum (Shimla Mirch)', 'unit': 'kg', 'cost': 60.0, 'price': 85.0, 'stock': 50.0},
      {'name': 'Ginger (Adrak)', 'unit': 'kg', 'cost': 120.0, 'price': 160.0, 'stock': 30.0},
      {'name': 'Garlic (Lahsun)', 'unit': 'kg', 'cost': 180.0, 'price': 240.0, 'stock': 40.0},
      {'name': 'Green Chilli (Hari Mirch)', 'unit': 'kg', 'cost': 50.0, 'price': 70.0, 'stock': 35.0},
      {'name': 'Coriander (Dhania)', 'unit': 'bunch', 'cost': 10.0, 'price': 20.0, 'stock': 100.0},
      {'name': 'Mint (Pudina)', 'unit': 'bunch', 'cost': 12.0, 'price': 22.0, 'stock': 80.0},
      {'name': 'Radish (Mooli)', 'unit': 'kg', 'cost': 25.0, 'price': 36.0, 'stock': 60.0},
      {'name': 'Beetroot (Chukandar)', 'unit': 'kg', 'cost': 35.0, 'price': 50.0, 'stock': 50.0},
      {'name': 'Sweet Potato (Shakarkandi)', 'unit': 'kg', 'cost': 40.0, 'price': 55.0, 'stock': 40.0},
      {'name': 'Pumpkin (Kaddu)', 'unit': 'kg', 'cost': 20.0, 'price': 30.0, 'stock': 80.0},
      {'name': 'Ridge Gourd (Turai)', 'unit': 'kg', 'cost': 38.0, 'price': 52.0, 'stock': 45.0},
      {'name': 'Snake Gourd (Chichinda)', 'unit': 'kg', 'cost': 35.0, 'price': 48.0, 'stock': 35.0},
      {'name': 'Drumstick (Sahjan)', 'unit': 'kg', 'cost': 70.0, 'price': 95.0, 'stock': 30.0},
      {'name': 'Green Peas (Matar)', 'unit': 'kg', 'cost': 80.0, 'price': 110.0, 'stock': 65.0},
      {'name': 'Broccoli', 'unit': 'kg', 'cost': 90.0, 'price': 140.0, 'stock': 25.0},
      {'name': 'Zucchini', 'unit': 'kg', 'cost': 100.0, 'price': 150.0, 'stock': 20.0},
      {'name': 'Button Mushroom', 'unit': 'packet', 'cost': 45.0, 'price': 65.0, 'stock': 40.0},
      {'name': 'Red & Yellow Bell Peppers', 'unit': 'kg', 'cost': 150.0, 'price': 220.0, 'stock': 18.0},
    ];

    final fruits = [
      {'name': 'Apple (Shimla Premium)', 'unit': 'kg', 'cost': 120.0, 'price': 160.0, 'stock': 100.0},
      {'name': 'Banana (Robusta)', 'unit': 'dozen', 'cost': 35.0, 'price': 50.0, 'stock': 150.0},
      {'name': 'Mango (Alphonso)', 'unit': 'dozen', 'cost': 300.0, 'price': 450.0, 'stock': 80.0},
      {'name': 'Orange (Nagpur Fresh)', 'unit': 'kg', 'cost': 60.0, 'price': 90.0, 'stock': 90.0},
      {'name': 'Papaya (Ripe)', 'unit': 'kg', 'cost': 30.0, 'price': 45.0, 'stock': 70.0},
      {'name': 'Grape (Black Seedless)', 'unit': 'kg', 'cost': 80.0, 'price': 120.0, 'stock': 60.0},
      {'name': 'Watermelon (Sweet Red)', 'unit': 'pc', 'cost': 50.0, 'price': 80.0, 'stock': 40.0},
      {'name': 'Pomegranate (Anar)', 'unit': 'kg', 'cost': 140.0, 'price': 190.0, 'stock': 50.0},
      {'name': 'Pineapple (Queen)', 'unit': 'pc', 'cost': 60.0, 'price': 90.0, 'stock': 35.0},
      {'name': 'Guava (Allahabad Pink)', 'unit': 'kg', 'cost': 45.0, 'price': 65.0, 'stock': 60.0},
    ];

    int insertedCount = 0;

    for (final v in vegetables) {
      await db.insert('items', {
        'id': _uuid.v4(),
        'name': v['name'],
        'category': 'Vegetables',
        'cost_price': v['cost'],
        'selling_price': v['price'],
        'stock': v['stock'],
        'min_stock': 10.0,
        'unit': v['unit'],
        'barcode': 'VEG-${_random.nextInt(89999) + 10000}',
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      insertedCount++;
    }

    for (final f in fruits) {
      await db.insert('items', {
        'id': _uuid.v4(),
        'name': f['name'],
        'category': 'Fruits',
        'cost_price': f['cost'],
        'selling_price': f['price'],
        'stock': f['stock'],
        'min_stock': 10.0,
        'unit': f['unit'],
        'barcode': 'FRU-${_random.nextInt(89999) + 10000}',
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      insertedCount++;
    }

    return insertedCount;
  }

  // ── 2. AREAS (10), STREETS (50), CUSTOMERS (500), VIP (200) ───────────────
  static Future<int> _seedAreasAndStreetsAndCustomers(Database db) async {
    final now = DateTime.now().toIso8601String();
    final oneYearLater = DateTime.now().add(const Duration(days: 365)).toIso8601String();

    final areaNames = [
      'North Zone Sector 1',
      'South Point Colony',
      'East Ridge Heights',
      'West End Enclave',
      'Central Business Hub',
      'Metro Greens Phase 1',
      'Riverside Boulevard',
      'Sunrise Gardens',
      'Royal Palms Estate',
      'Valley View Towers',
    ];

    final streetPrefixes = [
      'Market Road',
      'MG Road',
      'Station Street',
      'Park Avenue',
      'Green Lane',
      'Lake View Road',
      'Church Street',
      'Sunset Boulevard',
      'Temple Road',
      'Commercial Street',
    ];

    final firstNames = [
      'Ramesh', 'Suresh', 'Priya', 'Ananya', 'Vikram', 'Rajesh', 'Sunita', 'Amit',
      'Deepak', 'Neha', 'Pooja', 'Sanjay', 'Rahul', 'Kavita', 'Manish', 'Vijay',
      'Anita', 'Geeta', 'Arun', 'Sneha', 'Ajay', 'Meena', 'Rohan', 'Swati',
    ];

    final lastNames = [
      'Sharma', 'Verma', 'Gupta', 'Patel', 'Kumar', 'Singh', 'Joshi', 'Mehta',
      'Rao', 'Nair', 'Deshmukh', 'Kulkarni', 'Jain', 'Agarwal', 'Reddy', 'Chawla',
    ];

    final vipPlans = ['Gold VIP', 'Platinum VIP', 'Diamond VIP'];

    int customerIndex = 1;
    int vipCount = 0;

    await db.transaction((txn) async {
      for (int a = 0; a < 10; a++) {
        final areaId = 'area-${a + 1}';
        await txn.insert('areas', {
          'id': areaId,
          'name': areaNames[a],
          'description': 'Geographic territory ${a + 1}',
          'color': 0xFF1565C0 + (a * 0x112233),
          'created_at': now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        for (int s = 0; s < 5; s++) {
          final streetId = 'street-${a + 1}-${s + 1}';
          final streetName = '${streetPrefixes[s]} ${a + 1}';

          await txn.insert('streets', {
            'id': streetId,
            'area_id': areaId,
            'name': streetName,
            'description': 'Street under ${areaNames[a]}',
            'created_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          for (int c = 0; c < 10; c++) {
            final custId = 'cust-$customerIndex';
            final fn = firstNames[_random.nextInt(firstNames.length)];
            final ln = lastNames[_random.nextInt(lastNames.length)];
            final name = '$fn $ln';
            final phone = '98${_random.nextInt(89999999) + 10000000}';
            final houseNo = '#${_random.nextInt(300) + 101}, Block ${_random.nextInt(8) + 1}';

            final bool isVip = vipCount < 200;
            final String vipPlan = isVip ? vipPlans[vipCount % vipPlans.length] : '';

            await txn.insert('customers', {
              'id': custId,
              'street_id': streetId,
              'name': name,
              'phone1': phone,
              'phone2': '',
              'whatsapp': phone,
              'house_number': houseNo,
              'address': '$houseNo, $streetName, ${areaNames[a]}',
              'notes': isVip ? 'VIP Customer Subscription Active' : 'Regular Customer',
              'maps_location': '',
              'photo_path': '',
              'serial_no': customerIndex,
              'outstanding_balance': (customerIndex % 7 == 0) ? (_random.nextInt(500) + 50).toDouble() : 0.0,
              'total_orders': _random.nextInt(20) + 1,
              'total_paid': (_random.nextInt(5000) + 500).toDouble(),
              'total_pending': 0.0,
              'customer_since': DateTime.now().subtract(Duration(days: _random.nextInt(365))).toIso8601String(),
              'last_order_date': DateTime.now().subtract(Duration(days: _random.nextInt(30))).toIso8601String(),
              'is_vip': isVip ? 1 : 0,
              'vip_plan': vipPlan,
              'created_at': now,
              'updated_at': now,
            }, conflictAlgorithm: ConflictAlgorithm.replace);

            if (isVip) {
              await txn.insert('vip_membership', {
                'id': 'vip-$custId',
                'customer_id': custId,
                'plan_name': vipPlan,
                'start_date': now,
                'expiry_date': oneYearLater,
                'fee': vipPlan == 'Diamond VIP' ? 1499.0 : (vipPlan == 'Platinum VIP' ? 999.0 : 499.0),
                'discount_pct': vipPlan == 'Diamond VIP' ? 15.0 : (vipPlan == 'Platinum VIP' ? 10.0 : 5.0),
                'markup_pct': 0.0,
                'free_delivery': 1,
                'priority_delivery': 1,
                'status': 'active',
                'created_at': now,
              }, conflictAlgorithm: ConflictAlgorithm.replace);

              vipCount++;
            }

            customerIndex++;
          }
        }
      }
    });

    return customerIndex - 1;
  }
}
