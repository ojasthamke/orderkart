import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class OwnershipBadge extends StatelessWidget {
  final String createdBy;
  final String workerName;
  final double fontSize;
  final EdgeInsets padding;

  const OwnershipBadge({
    super.key,
    required this.createdBy,
    this.workerName = '',
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = createdBy.toLowerCase() == 'owner' || (createdBy.isEmpty && workerName.isEmpty);
    final label = isOwner
        ? 'Owner'
        : (workerName.isNotEmpty ? workerName : 'Worker');

    final color = isOwner ? AppColors.success : AppColors.primary;
    final bg = isOwner
        ? AppColors.success.withOpacity(0.12)
        : AppColors.primarySurface;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
