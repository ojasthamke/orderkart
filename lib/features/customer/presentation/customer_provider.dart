import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customer_dao.dart';
import '../data/customer_repository_impl.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>(
    (ref) => CustomerRepositoryImpl(CustomerDao()));

// List provider per street
class CustomerListNotifier extends StateNotifier<AsyncValue<List<Customer>>> {
  final CustomerRepository _repo;
  final String streetId;
  String _search = '';

  CustomerListNotifier(this._repo, this.streetId)
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

  void search(String q) {
    _search = q;
    load();
  }

  Future<void> add(Customer c) async {
    await _repo.addCustomer(c);
    await load();
  }

  Future<void> update(Customer c) async {
    await _repo.updateCustomer(c);
    await load();
  }

  Future<void> delete(String id) async {
    await _repo.deleteCustomer(id);
    await load();
  }

  Future<void> recalcBalance(String customerId) async {
    await _repo.updateBalance(customerId, 0);
    await load();
  }
}

final customerListProvider = StateNotifierProvider.family<
    CustomerListNotifier, AsyncValue<List<Customer>>, String>((ref, streetId) {
  return CustomerListNotifier(ref.read(customerRepositoryProvider), streetId);
});

// Single customer provider
final customerDetailProvider =
    FutureProvider.family<Customer?, String>((ref, customerId) async {
  final repo = ref.read(customerRepositoryProvider);
  return repo.getCustomerById(customerId);
});
