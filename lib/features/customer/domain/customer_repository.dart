import 'customer.dart';

abstract class CustomerRepository {
  Future<List<Customer>> getCustomersByStreet(String streetId,
      {String? searchQuery});
  Future<List<Customer>> getGuestCustomers({String? searchQuery});
  Future<List<Customer>> getRegisteredCustomers(String streetId,
      {String? searchQuery});
  Future<Customer?> getCustomerById(String id);
  Future<String> addCustomer(Customer customer);
  Future<void> updateCustomer(Customer customer);
  Future<void> deleteCustomer(String id);
  Future<void> updateBalance(String customerId, double delta);
  Future<List<Customer>> searchCustomers(String query);
  Future<void> reorderCustomers(String streetId, List<String> orderedIds);
  Future<void> moveCustomers(List<String> customerIds, String newStreetId);
  Future<void> convertToRegisteredCustomer(String customerId, String newCustomerCode, {String? streetId});
  Future<List<Map<String, dynamic>>> getLoginLogs({int limit = 100, String? loginMethodFilter});
}

