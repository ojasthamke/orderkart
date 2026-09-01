import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../data/customer_dao.dart';
import '../data/customer_repository_impl.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';
import '../../location/domain/location.dart';
import '../../street/presentation/street_provider.dart';
import '../../area/presentation/area_provider.dart';
import '../../order/presentation/order_provider.dart';
import '../../search/presentation/search_provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/customer_order_sync_service.dart';

final customerRepositoryProvider = Provider<CustomerRepository>(
    (ref) => CustomerRepositoryImpl(CustomerDao()));

// List provider per street
class CustomerListNotifier extends StateNotifier<AsyncValue<List<Customer>>> {
  final Ref _ref;
  final CustomerRepository _repo;
  final String streetId;
  String _search = '';

  CustomerListNotifier(this._ref, this._repo, this.streetId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }
    try {
      final list =
          await _repo.getCustomersByStreet(streetId, searchQuery: _search);
      state = AsyncValue.data(list);
    } catch (e, st) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void _invalidateAll() {
    _ref.invalidate(customerDetailProvider);
    _ref.invalidate(streetProviderFamily);
    _ref.invalidate(areaProvider);
    _ref.invalidate(analyticsSummaryProvider);
    _ref.invalidate(searchProvider);
    _ref.invalidate(pendingCustomersProvider);
    _ref.invalidate(allCustomersProvider);
    _ref.invalidate(orderManagementProvider);
    _ref.invalidate(orderDetailProvider);
    _ref.invalidate(customerOrdersProvider);
  }

  void search(String q) {
    _search = q;
    load();
  }

  Future<void> add(Customer c) async {
    await _repo.addCustomer(c);
    await load(silent: true);
    _ref.invalidate(customerDetailProvider(c.id));
    _ref.invalidate(searchProvider);
    _ref.invalidate(allCustomersProvider);
    Future.microtask(() async {
      try {
        await CustomerOrderSyncService.instance.syncSingleCustomer(c);
      } catch (_) {}
    });
  }

  Future<void> update(Customer c) async {
    await _repo.updateCustomer(c);
    await load(silent: true);
    _ref.invalidate(customerDetailProvider(c.id));
    _ref.invalidate(customerOrdersProvider(c.id));
    _ref.invalidate(searchProvider);
    _ref.invalidate(allCustomersProvider);
    Future.microtask(() async {
      try {
        await CustomerOrderSyncService.instance.syncSingleCustomer(c);
      } catch (_) {}
    });
  }

  Future<void> delete(String id) async {
    final customer = await _repo.getCustomerById(id);
    if (customer != null && customer.photoPath.isNotEmpty) {
      final file = File(customer.photoPath);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
      final fallback = AppConstants.resolveFile(customer.photoPath);
      if (fallback.existsSync()) {
        try {
          fallback.deleteSync();
        } catch (_) {}
      }
    }
    await _repo.deleteCustomer(id);
    await load();
    _invalidateAll();
    _ref.invalidate(customerDetailProvider(id));
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;
    final list = List<Customer>.from(currentData);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = AsyncValue.data(list);

    final ids = list.map((c) => c.id).toList();
    await _repo.reorderCustomers(streetId, ids);
    _invalidateAll();
  }

  Future<void> recalcBalance(String customerId) async {
    await _repo.updateBalance(customerId, 0);
    await load();
    _invalidateAll();
  }

  Future<void> moveCustomers(
      List<String> customerIds, String newStreetId) async {
    await _repo.moveCustomers(customerIds, newStreetId);
    await load();
    _invalidateAll();
    _ref.invalidate(customerListProvider(newStreetId));
  }
}

final customerListProvider = StateNotifierProvider.family<CustomerListNotifier,
    AsyncValue<List<Customer>>, String>((ref, streetId) {
  return CustomerListNotifier(
      ref, ref.read(customerRepositoryProvider), streetId);
});

// Single customer provider
final customerDetailProvider =
    FutureProvider.family<Customer?, String>((ref, customerId) async {
  final repo = ref.read(customerRepositoryProvider);
  return repo.getCustomerById(customerId);
});

// All customers who have outstanding balance > 0
final pendingCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  final dao = CustomerDao();
  return dao.getCustomersWithDue();
});

// All customers who have advance / overpaid balance > 0 (remaining money to return)
final overpaidCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  final dao = CustomerDao();
  return dao.getCustomersWithOverpayment();
});

// All customers list
final allCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  return CustomerDao().getAllCustomers();
});

// Same house / multi-family customers provider
final sameHouseCustomersProvider = FutureProvider.family<
    List<Customer>,
    ({
      String houseNumber,
      String streetId,
      String customerId
    })>((ref, args) async {
  if (args.houseNumber.trim().isEmpty) return [];
  final dao = CustomerDao();
  return dao.getCustomersInSameHouse(
    args.houseNumber,
    streetId: args.streetId,
    excludeCustomerId: args.customerId,
  );
});

// Location info provider (Street, Area, and Full Hierarchy Address: Area, Road, Sub-Road, Sub-Sub-Road)
final customerLocationProvider =
    FutureProvider.family<Map<String, String>, String>((ref, locationId) async {
  if (locationId.isEmpty) {
    return {
      'street': '',
      'area': '',
      'fullAddress': '',
      'areaName': '',
      'roadName': '',
      'subRoadName': '',
      'subSubRoadName': '',
    };
  }
  try {
    final db = await DatabaseHelper.instance.database;
    // Query location breadcrumbs recursively from leaf to root
    final list = <Map<String, dynamic>>[];
    String? currentId = locationId;

    while (currentId != null) {
      final rows = await db.query('locations',
          columns: ['id', 'parent_location_id', 'name', 'location_kind'],
          where: 'id = ?',
          whereArgs: [currentId],
          limit: 1);
      if (rows.isEmpty) break;
      list.insert(0, rows.first);
      currentId = rows.first['parent_location_id'] as String?;
    }

    if (list.isEmpty) {
      // Fallback to legacy tables
      final streetRows = await db.query('streets',
          where: 'id = ?', whereArgs: [locationId], limit: 1);
      if (streetRows.isEmpty) {
        return {
          'street': '',
          'area': '',
          'fullAddress': '',
          'areaName': '',
          'roadName': '',
          'subRoadName': '',
          'subSubRoadName': '',
        };
      }
      final streetName = streetRows.first['name']?.toString() ?? '';
      final areaId = streetRows.first['area_id']?.toString() ?? '';
      String areaName = '';
      if (areaId.isNotEmpty) {
        final areaRows = await db.query('areas',
            where: 'id = ?', whereArgs: [areaId], limit: 1);
        if (areaRows.isNotEmpty) {
          areaName = areaRows.first['name']?.toString() ?? '';
        }
      }
      final parts = [areaName, streetName]
          .where((p) => p.trim().isNotEmpty)
          .toList();
      return {
        'street': streetName,
        'area': areaName,
        'fullAddress': parts.join(', '),
        'areaName': areaName,
        'roadName': streetName,
        'subRoadName': '',
        'subSubRoadName': '',
      };
    }

    final leafName = list.last['name']?.toString() ?? '';
    final fullAddress = list
        .map((l) => l['name']?.toString().trim() ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');

    String parentPath = '';
    if (list.length > 1) {
      parentPath = list
          .take(list.length - 1)
          .map((l) => l['name']?.toString().trim() ?? '')
          .where((n) => n.isNotEmpty)
          .join(' > ');
    }

    final String areaName = list.isNotEmpty ? (list[0]['name']?.toString() ?? '') : '';
    final String roadName = list.length > 1 ? (list[1]['name']?.toString() ?? '') : '';
    final String subRoadName = list.length > 2 ? (list[2]['name']?.toString() ?? '') : '';
    final String subSubRoadName = list.length > 3 ? (list[3]['name']?.toString() ?? '') : '';

    return {
      'street': leafName,
      'area': parentPath.isNotEmpty ? parentPath : areaName,
      'fullAddress': fullAddress,
      'areaName': areaName,
      'roadName': roadName,
      'subRoadName': subRoadName,
      'subSubRoadName': subSubRoadName,
    };
  } catch (_) {
    return {
      'street': '',
      'area': '',
      'fullAddress': '',
      'areaName': '',
      'roadName': '',
      'subRoadName': '',
      'subSubRoadName': '',
    };
  }
});

final areaDescendantLocationsProvider =
    FutureProvider.family<List<Location>, String>((ref, areaId) async {
  final db = await DatabaseHelper.instance.database;
  final res = await db.query(
    'locations',
    where:
        '(parent_location_id = ? OR materialized_path LIKE ?) AND location_kind != ? AND is_archived = 0',
    whereArgs: [areaId, '/$areaId/%', 'area'],
    orderBy: 'materialized_path ASC, name ASC',
  );
  return res.map(Location.fromMap).toList();
});

// ── GUEST CUSTOMERS PROVIDER ────────────────────────────────────────────────
class GuestCustomersNotifier extends StateNotifier<AsyncValue<List<Customer>>> {
  final Ref _ref;
  final CustomerRepository _repo;
  String _searchQuery = '';

  GuestCustomersNotifier(this._ref, this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }
    try {
      final list = await _repo.getGuestCustomers(searchQuery: _searchQuery);
      state = AsyncValue.data(list);
    } catch (e, st) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void search(String q) {
    _searchQuery = q;
    load();
  }

  Future<bool> convertGuest({
    required String customerId,
    required String newCustomerCode,
    String? streetId,
  }) async {
    try {
      await _repo.convertToRegisteredCustomer(customerId, newCustomerCode, streetId: streetId);
      final customer = await _repo.getCustomerById(customerId);
      if (customer != null) {
        Future.microtask(() async {
          try {
            await CustomerOrderSyncService.instance.syncSingleCustomer(customer);
          } catch (_) {}
        });
      }
      await load(silent: true);
      _ref.invalidate(allCustomersProvider);
      return true;
    } catch (e) {
      return false;
    }
  }
}

final guestCustomersProvider =
    StateNotifierProvider<GuestCustomersNotifier, AsyncValue<List<Customer>>>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  return GuestCustomersNotifier(ref, repo);
});

// ── CUSTOMER LOGIN LOGS PROVIDER ────────────────────────────────────────────
class CustomerLoginLogsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final CustomerRepository _repo;
  String? _methodFilter;

  CustomerLoginLogsNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }
    try {
      // Sync fresh logs from Supabase first if online
      try {
        await CustomerOrderSyncService.instance.pullLoginLogs();
      } catch (_) {}

      final logs = await _repo.getLoginLogs(limit: 100, loginMethodFilter: _methodFilter);
      state = AsyncValue.data(logs);
    } catch (e, st) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void filterByMethod(String? method) {
    _methodFilter = method;
    load();
  }
}

final customerLoginLogsProvider =
    StateNotifierProvider<CustomerLoginLogsNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  return CustomerLoginLogsNotifier(repo);
});

