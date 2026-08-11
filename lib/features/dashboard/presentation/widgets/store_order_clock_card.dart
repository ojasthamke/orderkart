import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';

class StoreOrderClockCard extends StatefulWidget {
  const StoreOrderClockCard({super.key});

  @override
  State<StoreOrderClockCard> createState() => _StoreOrderClockCardState();
}

class _StoreOrderClockCardState extends State<StoreOrderClockCard> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  bool _isAcceptingOrders = true;
  TimeOfDay _cutoffTime = const TimeOfDay(hour: 20, minute: 0); // Default 8:00 PM
  DateTime _cutoffDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  String _formatTwoDigits(int n) => n.toString().padLeft(2, '0');

  String _getLiveClockString() {
    final hh = _formatTwoDigits(_now.hour);
    final mm = _formatTwoDigits(_now.minute);
    final ss = _formatTwoDigits(_now.second);
    return '$hh:$mm:$ss';
  }

  String _getDateString() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dayName = days[_now.weekday - 1];
    final monthName = months[_now.month - 1];
    return '$dayName, ${_now.day} $monthName ${_now.year}';
  }

  Duration _getRemainingTime() {
    final deadline = DateTime(
      _cutoffDate.year,
      _cutoffDate.month,
      _cutoffDate.day,
      _cutoffTime.hour,
      _cutoffTime.minute,
    );
    if (_now.isAfter(deadline)) return Duration.zero;
    return deadline.difference(_now);
  }

  bool _isPastDeadline() {
    final deadline = DateTime(
      _cutoffDate.year,
      _cutoffDate.month,
      _cutoffDate.day,
      _cutoffTime.hour,
      _cutoffTime.minute,
    );
    return _now.isAfter(deadline);
  }

  void _showSetCutoffDialog() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _cutoffTime,
    );
    if (pickedTime != null) {
      setState(() {
        _cutoffTime = pickedTime;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order cutoff updated to ${_cutoffTime.format(context)}. Synced to Teacup!',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClosed = !_isAcceptingOrders || _isPastDeadline();
    final remaining = _getRemainingTime();

    final remainingString =
        '${_formatTwoDigits(remaining.inHours)}h ${_formatTwoDigits(remaining.inMinutes.remainder(60))}m ${_formatTwoDigits(remaining.inSeconds.remainder(60))}s';

    return GlassContainer(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Live Clock & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.access_time_filled_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getLiveClockString(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        _getDateString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isClosed ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isClosed ? Colors.red : Colors.green,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isClosed ? Colors.red : Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isClosed ? 'ORDERS CLOSED' : 'ACCEPTING ORDERS',
                      style: TextStyle(
                        color: isClosed ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Order Cutoff Details & Timer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Order Cutoff Deadline:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Today at ${_cutoffTime.format(context)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (!isClosed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '⏳ Closing In',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      Text(
                        remainingString,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.orange,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Control Controls Row: Toggle & Configure
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Accepting Orders Status',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _isAcceptingOrders ? 'Store receiving orders in Teacup' : 'Orders paused by owner',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  value: _isAcceptingOrders,
                  onChanged: (val) {
                    setState(() {
                      _isAcceptingOrders = val;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val
                              ? '🟢 Order acceptance activated! Teacup store is open.'
                              : '🔴 Order acceptance paused! Teacup store is closed.',
                        ),
                        backgroundColor: val ? Colors.green : Colors.red,
                      ),
                    );
                  },
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showSetCutoffDialog,
                icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                label: const Text('Set Cutoff'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
