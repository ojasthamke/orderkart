import '../domain/customer.dart';
import '../domain/customer_repository.dart';
import 'customer_dao.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final CustomerDao _dao;
  CustomerRepositoryImpl(this._dao);

  @override
  Future<List<Customer>> getCustomersByStreet(String streetId, {String? searchQuery}) =>
      _dao.getCustomersByStreet(streetId, searchQuery: searchQuery);

  @override
  Future<Customer?> getCustomerById(String id) => _dao.getCustomerById(id);

  @override
  Future<String> addCustomer(Customer customer) => _dao.insertCustomer(customer);

  @override
  Future<void> updateCustomer(Customer customer) => _dao.updateCustomer(customer);

  @override
  Future<void> deleteCustomer(String id) => _dao.deleteCustomer(id);

  @override
  Future<void> updateBalance(String customerId, double delta) async {
    // Recalc from source of truth (orders table)
    await _dao.recalcCustomerTotals(customerId);
  }

  @override
  Future<List<Customer>> searchCustomers(String query) =>
      _dao.searchCustomers(query);

  @override
  Future<void> reorderCustomers(String streetId, List<String> orderedIds) =>
      _dao.saveCustomerOrder(streetId, orderedIds);
}
