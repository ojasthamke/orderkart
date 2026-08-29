import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class RunningMonthDateStrip extends StatelessWidget {
  final String selectedFilter;
  final Function(String filterValue) onFilterSelected;
  final Map<String, int> dateCounts;
  final VoidCallback? onCustomRangeTap;

  const RunningMonthDateStrip({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
    this.dateCounts = const {},
    this.onCustomRangeTap,
  });

  List<Map<String, dynamic>> _generateFilters() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final filters = <Map<String, dynamic>>[
      {'value': 'all', 'label': 'All Orders', 'badge': null},
      {'value': 'today', 'label': 'Today (${today.day})', 'badge': dateCounts[todayStr]},
    ];

    // Find the last day of the current running month
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final lastDayOfMonth = nextMonth.subtract(const Duration(days: 1)).day;

    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Generate chips for all remaining days of the current running month (starting tomorrow)
    for (int day = today.day + 1; day <= lastDayOfMonth; day++) {
      final date = DateTime(now.year, now.month, day);
      final dStr = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final dayName = weekDays[date.weekday - 1];
      final count = dateCounts[dStr];

      filters.add({
        'value': 'date:$dStr',
        'label': '$day $dayName',
        'badge': count,
      });
    }

    // Yesterday
    final yesterday = today.subtract(const Duration(days: 1));
    final yestStr = "${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
    filters.add({
      'value': 'yesterday',
      'label': 'Yesterday (${yesterday.day})',
      'badge': dateCounts[yestStr],
    });

    filters.add({'value': 'week', 'label': 'This Week', 'badge': null});
    filters.add({'value': 'month', 'label': 'This Month', 'badge': null});
    filters.add({'value': 'custom', 'label': 'Custom', 'badge': null});

    return filters;
  }

  @override
  Widget build(BuildContext context) {
    final filters = _generateFilters();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        itemCount: filters.length,
        itemBuilder: (ctx, i) {
          final f = filters[i];
          final val = f['value'] as String;
          final label = f['label'] as String;
          final badge = f['badge'] as int?;
          final selected = val == selectedFilter || (selectedFilter == 'today' && val == 'today');

          return GestureDetector(
            onTap: () {
              if (val == 'custom' && onCustomRangeTap != null) {
                onCustomRangeTap!();
              } else {
                onFilterSelected(val);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF1E293B) : AppColors.gray100),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : (isDark ? Colors.white.withOpacity(0.12) : AppColors.gray300),
                  width: selected ? 1.5 : 1.0,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : (isDark ? Colors.white70 : AppColors.textSecondary),
                    ),
                  ),
                  if (badge != null && badge > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badge',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: selected ? AppColors.primary : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
