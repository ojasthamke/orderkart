import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/order.dart';

class DeliveryTimeBottomSheet extends StatefulWidget {
  final AppOrder order;
  final bool isAccepting;
  final Future<void> Function(String durationStr, DateTime targetTime) onConfirm;

  const DeliveryTimeBottomSheet({
    super.key,
    required this.order,
    this.isAccepting = true,
    required this.onConfirm,
  });

  @override
  State<DeliveryTimeBottomSheet> createState() => _DeliveryTimeBottomSheetState();
}

class _DeliveryTimeBottomSheetState extends State<DeliveryTimeBottomSheet> {
  String _selectedPreset = '30 mins';
  int _selectedMinutes = 30;
  bool _isCustom = false;
  final _customController = TextEditingController();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _presets = [
    {'label': '15 mins', 'minutes': 15, 'icon': Icons.bolt_rounded},
    {'label': '30 mins', 'minutes': 30, 'icon': Icons.flash_on_rounded},
    {'label': '45 mins', 'minutes': 45, 'icon': Icons.timer_outlined},
    {'label': '1 hour', 'minutes': 60, 'icon': Icons.access_time_rounded},
    {'label': '1.5 hours', 'minutes': 90, 'icon': Icons.schedule_rounded},
    {'label': '2 hours', 'minutes': 120, 'icon': Icons.local_shipping_outlined},
    {'label': '3 hours', 'minutes': 180, 'icon': Icons.departure_board_rounded},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.order.estimatedDeliveryTime != null &&
        widget.order.estimatedDeliveryTime!.trim().isNotEmpty &&
        widget.order.estimatedDeliveryTime!.trim().toLowerCase() != 'null') {
      final existing = widget.order.estimatedDeliveryTime!;
      final match = _presets.firstWhere(
        (p) => p['label'].toString().toLowerCase() == existing.toLowerCase(),
        orElse: () => {'label': '', 'minutes': 0},
      );
      if (match['minutes'] != 0) {
        _selectedPreset = match['label'] as String;
        _selectedMinutes = match['minutes'] as int;
      } else {
        final numPart = int.tryParse(existing.replaceAll(RegExp(r'[^0-9]'), ''));
        if (numPart != null && numPart > 0) {
          _selectedPreset = existing;
          _selectedMinutes = numPart;
        }
      }
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  DateTime _computeTargetTime() {
    final now = DateTime.now();
    return now.add(Duration(minutes: _selectedMinutes));
  }

  String _formatTargetTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetTime = _computeTargetTime();
    final targetTimeFormatted = _formatTargetTime(targetTime);

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delivery_dining_rounded,
                    color: Color(0xFF059669), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isAccepting
                          ? 'Accept Order & Set Delivery Time'
                          : 'Change Delivery Time',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order ${widget.order.orderNoLabel} · ${widget.order.customerName ?? "Customer"}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Expected arrival preview banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.alarm_on_rounded,
                    color: Color(0xFF065F46), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                          color: const Color(0xFF065F46), fontSize: 13),
                      children: [
                        const TextSpan(text: 'Estimated Delivery: '),
                        TextSpan(
                          text: '$_selectedPreset ',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        TextSpan(
                          text: '(by ~$targetTimeFormatted)',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const Text(
            'Select Delivery Duration:',
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),

          // Preset Chips Grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._presets.map((preset) {
                final isSelected =
                    !_isCustom && _selectedPreset == preset['label'];
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(preset['icon'] as IconData,
                          size: 14,
                          color: isSelected ? Colors.white : AppColors.primary),
                      const SizedBox(width: 4),
                      Text(preset['label'] as String),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight:
                        isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _isCustom = false;
                        _selectedPreset = preset['label'] as String;
                        _selectedMinutes = preset['minutes'] as int;
                      });
                    }
                  },
                );
              }),
              ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_calendar_rounded,
                        size: 14,
                        color: _isCustom ? Colors.white : AppColors.primary),
                    const SizedBox(width: 4),
                    const Text('Custom'),
                  ],
                ),
                selected: _isCustom,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: _isCustom
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight:
                      _isCustom ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12.5,
                ),
                onSelected: (selected) {
                  setState(() {
                    _isCustom = true;
                  });
                },
              ),
            ],
          ),

          if (_isCustom) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Custom Minutes',
                      hintText: 'e.g. 25, 50, 75',
                      prefixIcon: const Icon(Icons.timer_outlined, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val.trim());
                      if (parsed != null && parsed > 0) {
                        setState(() {
                          _selectedMinutes = parsed;
                          _selectedPreset = '$parsed mins';
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() => _isLoading = true);
                      try {
                        final targetTime = _computeTargetTime();
                        await widget.onConfirm(_selectedPreset, targetTime);
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      }
                    },
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_rounded, color: Colors.white),
              label: Text(
                widget.isAccepting
                    ? 'Confirm & Accept Order'
                    : 'Save Delivery Time',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
