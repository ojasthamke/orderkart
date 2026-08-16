import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/analytics_dao.dart';

final analyticsDaoProvider = Provider<AnalyticsDao>((ref) {
  return AnalyticsDao();
});

class DateWiseProfitParams {
  final int days;
  final String? startDate;
  final String? endDate;

  const DateWiseProfitParams({
    this.days = 7,
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateWiseProfitParams &&
          runtimeType == other.runtimeType &&
          days == other.days &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode => days.hashCode ^ startDate.hashCode ^ endDate.hashCode;
}

final dateWiseProfitProvider =
    FutureProvider.family<List<Map<String, dynamic>>, DateWiseProfitParams>(
        (ref, params) {
  final dao = ref.watch(analyticsDaoProvider);
  return dao.getDateWiseProfitBreakdown(
    days: params.days,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

final itemProfitabilityMatrixProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, days) {
  final dao = ref.watch(analyticsDaoProvider);
  return dao.getItemProfitabilityMatrix(days: days);
});

final customerProfitContributionProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  final dao = ref.watch(analyticsDaoProvider);
  return dao.getCustomerProfitContribution(limit: 50);
});

final peakSalesAnalyticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) {
  final dao = ref.watch(analyticsDaoProvider);
  return dao.getPeakSalesHourlyAndDayOfWeek();
});

final deadStockAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, deadStockDays) {
  final dao = ref.watch(analyticsDaoProvider);
  return dao.getDeadStockAndTurnover(deadStockDays: deadStockDays);
});

final cashflowDebtAgingProvider =
    FutureProvider<Map<String, dynamic>>((ref) {
  final dao = ref.watch(analyticsDaoProvider);
  return dao.getCashflowAndDebtAging();
});

final topWorkersAnalyticsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  final dao = ref.watch(analyticsDaoProvider);
  return dao.getTopWorkers();
});

final areaPerformanceAnalyticsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  final dao = ref.watch(analyticsDaoProvider);
  return dao.getAreaPerformance();
});

final todayVsYesterdayProfitProvider =
    FutureProvider<Map<String, dynamic>>((ref) {
  final dao = ref.watch(analyticsDaoProvider);
  return dao.getTodayVsYesterdayProfitSummary();
});
