// test/worker_services_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/database/database_helper.dart';
import 'package:orderkart/core/models/worker.dart';
import 'package:orderkart/core/models/worker_permission.dart';
import 'package:orderkart/core/services/worker_service.dart';
import 'package:orderkart/core/services/worker_permission_service.dart';
import 'package:orderkart/core/services/worker_assignment_service.dart';
import 'package:orderkart/core/error/failures.dart';

void main() {
  // Initialize FFI for local SQLite tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Worker Database Services Tests', () {
    final workerId = 'worker-test-123';
    
    setUp(() async {
      await DatabaseHelper.instance.close();
      final dbPath = await databaseFactory.getDatabasesPath();
      final path = '$dbPath/orderkart.db';
      await databaseFactory.deleteDatabase(path);
    });

    test('Create, retrieve, update, delete worker', () async {
      final worker = Worker(
        id: workerId,
        name: 'John Doe',
        phone: '1234567890',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create
      await WorkerService.createWorker(worker);

      // Retrieve
      final retrieved = await WorkerService.getWorkerById(workerId);
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('John Doe'));
      expect(retrieved.phone, equals('1234567890'));

      // Update
      final updatedWorker = Worker(
        id: workerId,
        name: 'John Smith',
        phone: '0987654321',
        createdAt: worker.createdAt,
        updatedAt: DateTime.now(),
      );
      await WorkerService.updateWorker(updatedWorker);

      final retrievedUpdated = await WorkerService.getWorkerById(workerId);
      expect(retrievedUpdated, isNotNull);
      expect(retrievedUpdated!.name, equals('John Smith'));
      expect(retrievedUpdated.phone, equals('0987654321'));

      // Delete
      await WorkerService.deleteWorker(workerId);
      final retrievedDeleted = await WorkerService.getWorkerById(workerId);
      expect(retrievedDeleted, isNull);
    });

    test('WorkerPermission CRUD and checks', () async {
      final worker = Worker(
        id: workerId,
        name: 'Permission Worker',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await WorkerService.createWorker(worker);

      // Fetch default permissions (which inserts them)
      final perms = await WorkerPermissionService.getPermissionsForWorker(workerId);
      expect(perms, isNotNull);
      expect(perms.workerId, equals(workerId));
      expect(perms.orders, equals(PermissionLevel.full));
      expect(perms.analytics, equals(PermissionLevel.view));

      // Update permissions
      final updatedPerms = WorkerPermission(
        workerId: workerId,
        orders: PermissionLevel.hidden,
        analytics: PermissionLevel.full,
        updatedAt: DateTime.now(),
      );
      await WorkerPermissionService.savePermissions(updatedPerms);

      final retrievedPerms = await WorkerPermissionService.getPermissionsForWorker(workerId);
      expect(retrievedPerms.orders, equals(PermissionLevel.hidden));
      expect(retrievedPerms.analytics, equals(PermissionLevel.full));

      // Checks using hasPermission
      expect(await WorkerPermissionService.hasPermission(workerId, 'delete_customer'), isTrue);
      expect(await WorkerPermissionService.hasPermission(workerId, 'create_order'), isFalse);

      // checkPermissionOrThrow success and failure
      expect(
        () async => await WorkerPermissionService.checkPermissionOrThrow(workerId, 'delete_customer', 'delete customer'),
        returnsNormally,
      );

      expect(
        () async => await WorkerPermissionService.checkPermissionOrThrow(workerId, 'create_order', 'create order'),
        throwsA(isA<PermissionFailure>()),
      );
    });

    test('WorkerAssignment CRUD and query helpers', () async {
      final worker = Worker(
        id: workerId,
        name: 'Assignment Worker',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await WorkerService.createWorker(worker);

      // Assign Area 1
      final assignId = await WorkerAssignmentService.assignEntity(
        workerId: workerId,
        entityType: 'area',
        entityId: 'area-1',
      );
      expect(assignId, isNotEmpty);

      // Check assignment
      expect(await WorkerAssignmentService.isEntityAssigned(workerId, 'area', 'area-1'), isTrue);
      expect(await WorkerAssignmentService.isEntityAssigned(workerId, 'area', 'area-2'), isFalse);

      // Get assigned list
      final list = await WorkerAssignmentService.getAssignedEntityIds(workerId, 'area');
      expect(list, contains('area-1'));
      expect(list.length, equals(1));

      // Revoke assignment
      await WorkerAssignmentService.revokeAssignment(assignId);
      expect(await WorkerAssignmentService.isEntityAssigned(workerId, 'area', 'area-1'), isFalse);
    });
  });
}
