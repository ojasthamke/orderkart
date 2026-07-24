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
  }

  void search(String q) {
    _search = q;
    load();
  }

  Future<void> add(Customer c) async {
    await _repo.addCustomer(c);
    await load(silent: true);
    _invalidateAll();
  }

  Future<void> update(Customer c) async {
    await _repo.updateCustomer(c);
    await load(silent: true);
    _invalidateAll();
    _ref.invalidate(customerDetailProvider(c.id));
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

// Location info provider (Street and Area name / Breadcrumbs path)
final customerLocationProvider =
    FutureProvider.family<Map<String, String>, String>((ref, locationId) async {
  if (locationId.isEmpty) return {'street': '', 'area': ''};
  try {
    final db = await DatabaseHelper.instance.database;
    // Query location breadcrumbs recursively
    final list = <Map<String, dynamic>>[];
    String? currentId = locationId;

    while (currentId != null) {
      final rows = await db.query('locations',
          columns: ['id', 'parent_location_id', 'name'],
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
      if (streetRows.isEmpty) return {'street': '', 'area': ''};
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
      return {'street': streetName, 'area': areaName};
    }

    final leafName = list.last['name']?.toString() ?? '';
    if (list.length == 1) {
      return {'street': leafName, 'area': ''};
    }
    final parentPath = list
        .take(list.length - 1)
        .map((l) => l['name']?.toString() ?? '')
        .join(' > ');
    return {'street': leafName, 'area': parentPath};
  } catch (_) {
    return {'street': '', 'area': ''};
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
