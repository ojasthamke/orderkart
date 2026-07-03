import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customer_dao.dart';
import '../data/customer_repository_impl.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';
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

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final list =
          await _repo.getCustomersByStreet(streetId, searchQuery: _search);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _invalidateAll() {
    _ref.invalidate(customerListProvider);
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
    await load();
    _invalidateAll();
  }

  Future<void> update(Customer c) async {
    await _repo.updateCustomer(c);
    await load();
    _invalidateAll();
  }

  Future<void> delete(String id) async {
    await _repo.deleteCustomer(id);
    await load();
    _invalidateAll();
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
}

final customerListProvider = StateNotifierProvider.family<
    CustomerListNotifier, AsyncValue<List<Customer>>, String>((ref, streetId) {
  return CustomerListNotifier(ref, ref.read(customerRepositoryProvider), streetId);
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

// All customers list
final allCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final maps = await db.query('customers', orderBy: 'serial_no ASC');
  return maps.map(Customer.fromMap).toList();
});
