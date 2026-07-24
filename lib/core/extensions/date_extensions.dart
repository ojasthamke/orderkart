/// Date Extensions
library;

extension DateTimeExtensions on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  bool get isThisWeek {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return isAfter(weekStart.subtract(const Duration(seconds: 1)));
  }

  bool get isThisMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  /// Returns date-only string for grouping: '2024-01-15'
  String get dateKey =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  /// Start of day
  DateTime get startOfDay => DateTime(year, month, day);

  /// End of day
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59);
}
