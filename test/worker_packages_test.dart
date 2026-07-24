// test/worker_packages_test.dart

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/core/constants/app_constants.dart';
import 'package:orderkart/core/services/worker_package_service.dart';
import 'package:orderkart/core/services/package_exporter.dart';
import 'package:orderkart/core/services/package_validator.dart';
import 'package:orderkart/core/utils/security_helper.dart';
import 'package:orderkart/features/area/data/area_dao.dart';
import 'package:orderkart/features/area/domain/area.dart';
import 'package:orderkart/features/street/data/street_dao.dart';
import 'package:orderkart/features/street/domain/street.dart';
import 'package:orderkart/features/customer/data/customer_dao.dart';
import 'package:orderkart/features/customer/domain/customer.dart';
import 'package:orderkart/features/order/data/order_dao.dart';
import 'package:orderkart/features/order/domain/order.dart';
import 'package:orderkart/features/order/domain/payment.dart';
import 'package:orderkart/features/expense/data/expense_dao.dart';
import 'package:orderkart/features/expense/domain/expense.dart';
import 'package:orderkart/features/note/data/note_dao.dart';
import 'package:orderkart/features/note/domain/app_note.dart';
import 'package:orderkart/features/visit/data/visit_dao.dart';
import 'package:orderkart/features/visit/domain/app_visit.dart';

void main() {
  // Initialize FFI for local SQLite tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Worker Packages & Backup Serialization Tests', () {
    const workerId = 'test-worker-id';
    const workerName = 'Test Worker';
    late Directory tempDocsDir;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      DatabaseHelper.dbNameOverride = 'orderkart_test_packages.db';

      // Mock Share channel
      const MethodChannel('dev.fluttercommunity.plus/share')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        return null;
      });

      // Mock Path Provider
      const MethodChannel('plugins.flutter.io/path_provider')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory' ||
            methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDocsDir.path;
        }
        return null;
      });
    });

    setUp(() async {
      tempDocsDir = Directory.systemTemp.createTempSync('orderkart_test_docs');
      AppConstants.appDocsDir = tempDocsDir.path;

      await DatabaseHelper.instance.close();
      final dbPath = await databaseFactory.getDatabasesPath();
      final path = '$dbPath/${DatabaseHelper.dbNameOverride}';
      await databaseFactory.deleteDatabase(path);

      // Initialize DB & generate owner secrets
      final db = await DatabaseHelper.instance.database;
      await SecurityHelper.getOrInitializeOwnerSecret();

      // Seed worker with PIN details
      await db.insert('workers', {
        'id': workerId,
        'name': workerName,
        'phone': '1234567890',
        'status': 'active',
        'pin_hash': SecurityHelper.hashPin('123456'),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final workerSecret = SecurityHelper.generateOwnerSecret();
      await db.insert('worker_security', {
        'worker_id': workerId,
        'worker_secret': workerSecret,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Seed mock business profile
      await db.insert('business_profile', {
        'id': 'profile-1',
        'business_name': 'OrderKart Test Business',
        'gst_number': '1234567890',
        'phone': '9999999999',
        'address': 'Test Address',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    });

    tearDown(() {
      try {
        if (tempDocsDir.existsSync()) {
          tempDocsDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('Provisioning Package Generation & Validation', () async {
      final db = await DatabaseHelper.instance.database;

      // Seed Area, Street, Customer, Item
      await db.insert('areas', {
        'id': 'area-1',
        'name': 'North Area',
        'description': '',
        'color': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert('streets', {
        'id': 'street-1',
        'area_id': 'area-1',
        'name': 'Main Street',
        'description': '',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('customers', {
        'id': 'cust-1',
        'street_id': 'street-1',
        'name': 'John Customer',
        'phone1': '9876543210',
        'address': '123 Main St',
        'customer_since': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert('worker_permissions', {
        'worker_id': workerId,
        'create_order': 1,
        'edit_order': 1,
        'add_customer': 1,
        'edit_customer': 1,
        'receive_payment': 1,
        'add_expenses': 1,
        'export_data': 1,
        'view_reports': 1,
        'edit_notes': 1,
        'manage_vip': 0,
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert('worker_assignments', {
        'id': 'assign-1',
        'worker_id': workerId,
        'entity_type': 'area',
        'entity_id': 'area-1',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Generate provisioning package
      await WorkerPackageService.generateWorkerProvisioningPackage(
        workerId: workerId,
        workerName: workerName,
      );

      final packageFile = File('${tempDocsDir.path}/WorkerPackage.orderkart');
      expect(packageFile.existsSync(), isTrue);

      // Validate provisioning package
      final validationResult =
          await PackageValidator.validatePackage(packageFile.path);
      expect(validationResult.isValid, isTrue);
      expect(validationResult.manifest['package_type'], equals('provisioning'));

      // Check validation DB contents
      final valDb = await openDatabase(validationResult.dbPath, readOnly: true);
      final workersVal = await valDb.query('workers');
      expect(workersVal.length, equals(1));
      expect(workersVal.first['name'], equals(workerName));

      final areasVal = await valDb.query('areas');
      expect(areasVal.length, equals(1));
      expect(areasVal.first['name'], equals('North Area'));

      final customersVal = await valDb.query('customers');
      expect(customersVal.length, equals(1));
      expect(customersVal.first['name'], equals('John Customer'));

      await valDb.close();
    });

    test(
        'Worker Provisioning with Granular Assignments (Area, Street, Customer)',
        () async {
      final db = await DatabaseHelper.instance.database;

      // Clean existing assignments, areas, streets, customers
      await db.delete('worker_assignments');
      await db.delete('customers');
      await db.delete('streets');
      await db.delete('areas');

      // Seed Area-1 and its Street-1 and Customer-1
      await db.insert('areas', {
        'id': 'area-1',
        'name': 'North Area',
        'description': '',
        'color': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await db.insert('streets', {
        'id': 'street-1',
        'area_id': 'area-1',
        'name': 'Main Street',
        'description': '',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('customers', {
        'id': 'cust-1',
        'street_id': 'street-1',
        'name': 'John Customer',
        'phone1': '9876543210',
        'address': '123 Main St',
        'customer_since': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Seed Area-2 and its Street-2 and Customer-2
      await db.insert('areas', {
        'id': 'area-2',
        'name': 'South Area',
        'description': '',
        'color': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await db.insert('streets', {
        'id': 'street-2',
        'area_id': 'area-2',
        'name': 'Second Street',
        'description': '',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('customers', {
        'id': 'cust-2',
        'street_id': 'street-2',
        'name': 'Jane Customer',
        'phone1': '9876543211',
        'address': '456 Second St',
        'customer_since': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Seed Area-3 and its Street-3 and Customer-3
      await db.insert('areas', {
        'id': 'area-3',
        'name': 'West Area',
        'description': '',
        'color': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await db.insert('streets', {
        'id': 'street-3',
        'area_id': 'area-3',
        'name': 'Third Street',
        'description': '',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('customers', {
        'id': 'cust-3',
        'street_id': 'street-3',
        'name': 'Jim Customer',
        'phone1': '9876543212',
        'address': '789 Third St',
        'customer_since': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Assign Area-1, Street-2, and Customer-3 to the worker
      await db.insert('worker_assignments', {
        'id': 'assign-1',
        'worker_id': workerId,
        'entity_type': 'area',
        'entity_id': 'area-1',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('worker_assignments', {
        'id': 'assign-2',
        'worker_id': workerId,
        'entity_type': 'street',
        'entity_id': 'street-2',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('worker_assignments', {
        'id': 'assign-3',
        'worker_id': workerId,
        'entity_type': 'customer',
        'entity_id': 'cust-3',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Generate provisioning package
      await WorkerPackageService.generateWorkerProvisioningPackage(
        workerId: workerId,
        workerName: workerName,
      );

      final packageFile = File('${tempDocsDir.path}/WorkerPackage.orderkart');
      expect(packageFile.existsSync(), isTrue);

      final validationResult =
          await PackageValidator.validatePackage(packageFile.path);
      expect(validationResult.isValid, isTrue);

      // Verify validation DB contents
      final valDb = await openDatabase(validationResult.dbPath, readOnly: true);

      // Areas check: Should contain Area-1, Area-2, and Area-3
      final areasVal = await valDb.query('areas');
      expect(areasVal.length, equals(3));
      final areaIds = areasVal.map((e) => e['id'].toString()).toSet();
      expect(areaIds, containsAll(['area-1', 'area-2', 'area-3']));

      // Streets check: Should contain Street-1, Street-2, and Street-3
      final streetsVal = await valDb.query('streets');
      expect(streetsVal.length, equals(3));
      final streetIds = streetsVal.map((e) => e['id'].toString()).toSet();
      expect(streetIds, containsAll(['street-1', 'street-2', 'street-3']));

      // Customers check: Should contain Customer-1, Customer-2, and Customer-3
      final customersVal = await valDb.query('customers');
      expect(customersVal.length, equals(3));
      final customerIds = customersVal.map((e) => e['id'].toString()).toSet();
      expect(customerIds, containsAll(['cust-1', 'cust-2', 'cust-3']));

      await valDb.close();
    });

    test('Worker Report Generation & Validation', () async {
      final db = await DatabaseHelper.instance.database;

      // Seed Area, Street, Customer first (for orders foreign key)
      await db.insert('areas', {
        'id': 'area-1',
        'name': 'North Area',
        'description': '',
        'color': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert('streets', {
        'id': 'street-1',
        'area_id': 'area-1',
        'name': 'Main Street',
        'description': '',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('customers', {
        'id': 'cust-1',
        'street_id': 'street-1',
        'name': 'John Customer',
        'phone1': '9876543210',
        'address': '123 Main St',
        'customer_since': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Seed reports/orders
      const orderId = 'order-1';
      await db.insert('orders', {
        'id': orderId,
        'customer_id': 'cust-1',
        'subtotal': 250.0,
        'discount': 0.0,
        'delivery_charge': 0.0,
        'smart_rounded_amount': 0.0,
        'grand_total': 250.0,
        'paid_amount': 250.0,
        'remaining_amount': 0.0,
        'delivery_status': 'delivered',
        'notes': '',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await db.insert('payments', {
        'id': 'pay-1',
        'order_id': orderId,
        'customer_id': 'cust-1',
        'amount': 250.0,
        'method': 'cash',
        'notes': '',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Generate report package
      await WorkerPackageService.generateWorkerReportPackage(
        workerId: workerId,
        workerName: workerName,
      );

      final reportFile = File('${tempDocsDir.path}/WorkerReport.orderkart');
      expect(reportFile.existsSync(), isTrue);

      // Validate report package
      final validationResult =
          await PackageValidator.validatePackage(reportFile.path);
      expect(validationResult.isValid, isTrue);
      expect(validationResult.manifest['package_type'], equals('report'));

      // Check validation DB contents
      final valDb = await openDatabase(validationResult.dbPath, readOnly: true);
      final ordersVal = await valDb.query('orders');
      expect(ordersVal.length, equals(1));
      expect(ordersVal.first['id'], equals(orderId));

      final paymentsVal = await valDb.query('payments');
      expect(paymentsVal.length, equals(1));
      expect(paymentsVal.first['amount'], equals(250.0));

      await valDb.close();
    });

    test('Full Business Backup Export & Validation', () async {
      // Generate full backup
      await PackageExporter.exportPackage(
        selectedModules: ['entire_db', 'photos', 'settings'],
      );

      final backupFile = File('${tempDocsDir.path}/BusinessBackup.orderkart');
      expect(backupFile.existsSync(), isTrue);

      // Validate backup package
      final validationResult =
          await PackageValidator.validatePackage(backupFile.path);
      expect(validationResult.isValid, isTrue);
      expect(validationResult.manifest['package_type'], equals('backup'));

      // Check validation DB contents
      final valDb = await openDatabase(validationResult.dbPath, readOnly: true);
      final workersVal = await valDb.query('workers');
      expect(workersVal.length, equals(1));
      expect(workersVal.first['name'], equals(workerName));

      await valDb.close();
    });

    test('Worker Mode Entity Insertion and Visibility Scoping', () async {
      final db = await DatabaseHelper.instance.database;

      // Clean existing assignments, areas, streets, customers
      await db.delete('worker_assignments');
      await db.delete('customers');
      await db.delete('streets');
      await db.delete('areas');
      await db.delete('settings');

      // Set worker mode and active worker ID
      await db.insert('settings', {'key': 'app_mode', 'value': 'worker'});
      await db
          .insert('settings', {'key': 'active_worker_id', 'value': workerId});

      // 1. Test Area insertion under worker mode
      const areaId = 'worker-area-1';
      final area = Area(
        id: areaId,
        name: 'Worker Added Area',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await AreaDao().insertArea(area);

      // Verify the area shows up in getAllAreas()
      final areas = await AreaDao().getAllAreas();
      expect(areas.length, equals(1));
      expect(areas.first.name, equals('Worker Added Area'));

      // Verify assignment was automatically created
      final areaAssigns = await db.query(
        'worker_assignments',
        where: 'worker_id = ? AND entity_type = ? AND entity_id = ?',
        whereArgs: [workerId, 'area', areaId],
      );
      expect(areaAssigns.length, equals(1));

      // 2. Test Street insertion under worker mode
      const streetId = 'worker-street-1';
      final street = Street(
        id: streetId,
        areaId: areaId,
        name: 'Worker Added Street',
        createdAt: DateTime.now(),
      );
      await StreetDao().insertStreet(street);

      // Verify street assignment was automatically created
      final streetAssigns = await db.query(
        'worker_assignments',
        where: 'worker_id = ? AND entity_type = ? AND entity_id = ?',
        whereArgs: [workerId, 'street', streetId],
      );
      expect(streetAssigns.length, equals(1));

      // 3. Test Customer insertion under worker mode
      const customerId = 'worker-cust-1';
      final customer = Customer(
        id: customerId,
        streetId: streetId,
        name: 'Worker Added Customer',
        phone1: '9876543210',
        customerSince: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await CustomerDao().insertCustomer(customer);

      // Verify customer assignment was automatically created
      final customerAssigns = await db.query(
        'worker_assignments',
        where: 'worker_id = ? AND entity_type = ? AND entity_id = ?',
        whereArgs: [workerId, 'customer', customerId],
      );
      expect(customerAssigns.length, equals(1));

      // 4. Test Order & Payment insertion under worker mode
      const orderId = 'WK12345';
      final order = AppOrder(
        id: orderId,
        customerId: customerId,
        subtotal: 100.0,
        grandTotal: 100.0,
        remainingAmount: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await OrderDao().insertOrder(order);

      final orderRow =
          await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(orderRow.first['created_by'], equals(workerId));

      const paymentId = 'worker-pay-1';
      final payment = Payment(
        id: paymentId,
        orderId: orderId,
        customerId: customerId,
        amount: 100.0,
        method: 'cash',
        createdAt: DateTime.now(),
      );
      await OrderDao().insertPayment(payment);

      final paymentRow =
          await db.query('payments', where: 'id = ?', whereArgs: [paymentId]);
      expect(paymentRow.first['created_by'], equals(workerId));

      // 5. Test Expense insertion under worker mode
      const expenseId = 'worker-exp-1';
      final expense = Expense(
        id: expenseId,
        name: 'Lunch',
        amount: 15.0,
        category: 'Food',
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ExpenseDao().insertExpense(expense);

      final expenseRow =
          await db.query('expenses', where: 'id = ?', whereArgs: [expenseId]);
      expect(expenseRow.first['created_by'], equals(workerId));

      // 6. Test Note insertion under worker mode
      const noteId = 'worker-note-1';
      final note = AppNote(
        id: noteId,
        title: 'Call customer',
        content: 'Call john',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await NoteDao().insert(note);

      final noteRow =
          await db.query('notes', where: 'id = ?', whereArgs: [noteId]);
      expect(noteRow.first['created_by'], equals(workerId));

      // 7. Test Visit insertion under worker mode
      const visitId = 'worker-visit-1';
      final visit = AppVisit(
        id: visitId,
        areaId: areaId,
        date: '2026-07-07',
        status: 'pending',
        notes: 'Delivery visit',
        createdAt: DateTime.now(),
      );
      await VisitDao().insert(visit);

      final visitRow =
          await db.query('visits', where: 'id = ?', whereArgs: [visitId]);
      expect(visitRow.first['created_by'], equals(workerId));

      // Revert settings to default
      await db.delete('settings');
    });
  });
}
