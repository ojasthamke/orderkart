import 'order.dart';
import 'order_item.dart';
import 'payment.dart';

abstract class OrderRepository {
  Future<List<AppOrder>> getAllOrders({
    String? status,
    String? filter,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<AppOrder?> getOrderById(String id);
  Future<List<OrderItem>> getOrderItems(String orderId);
  Future<List<Payment>> getOrderPayments(String orderId);
  Future<String> createOrder(AppOrder order, List<OrderItem> items);
  Future<void> updateOrder(AppOrder order);
  Future<void> deleteOrder(String id);
  Future<void> updateDeliveryStatus(String orderId, String status);
  Future<void> addPayment(Payment payment);
  Future<void> updateOrderPayment(String orderId, double paidAmount, double remainingAmount);
  Future<Map<String, dynamic>> getAnalyticsSummary();
}
