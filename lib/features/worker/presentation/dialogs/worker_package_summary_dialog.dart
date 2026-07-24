// lib/features/worker/presentation/dialogs/worker_package_summary_dialog.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../worker/domain/worker.dart';

class WorkerPackageSummaryDialog extends StatelessWidget {
  final Worker worker;
  final int areasCount;
  final int streetsCount;
  final int customersCount;
  final int categoriesCount;
  final int itemsCount;
  final int routesCount;
  final double estimatedSizeMb;
  final VoidCallback onConfirmExport;

  const WorkerPackageSummaryDialog({
    super.key,
    required this.worker,
    required this.areasCount,
    required this.streetsCount,
    required this.customersCount,
    required this.categoriesCount,
    required this.itemsCount,
    required this.routesCount,
    required this.estimatedSizeMb,
    required this.onConfirmExport,
  });

  static void show(
    BuildContext context, {
    required Worker worker,
    required int areasCount,
    required int streetsCount,
    required int customersCount,
    required int categoriesCount,
    required int itemsCount,
    required int routesCount,
    required double estimatedSizeMb,
    required VoidCallback onConfirmExport,
  }) {
    showDialog(
      context: context,
      builder: (_) => WorkerPackageSummaryDialog(
        worker: worker,
        areasCount: areasCount,
        streetsCount: streetsCount,
        customersCount: customersCount,
        categoriesCount: categoriesCount,
        itemsCount: itemsCount,
        routesCount: routesCount,
        estimatedSizeMb: estimatedSizeMb,
        onConfirmExport: onConfirmExport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAreaError = areasCount == 0;
    final bool isBlocked = hasAreaError;

    final bool hasCustomerWarning = customersCount == 0;
    final bool hasItemWarning = itemsCount == 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: ResponsiveHelper.dialogConstraints(context),
        padding: ResponsiveHelper.pagePadding(context),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isBlocked
                          ? AppColors.errorSurface
                          : AppColors.primarySurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isBlocked
                          ? Icons.block_rounded
                          : Icons.mark_email_read_rounded,
                      color: isBlocked ? AppColors.error : AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Worker Package Summary',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        Text(
                          'Package File: WorkerPackage.orderkart',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- WORKER DETAILS CARD ---
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${worker.name} (${worker.employeeId.isEmpty ? worker.id.substring(0, 8) : worker.employeeId})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'v${worker.packageVersion + 1}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- VALIDATION ALERTS ---
              if (hasAreaError)
                _validationAlert(
                  isError: true,
                  title: 'No Areas Found',
                  message:
                      'You must add at least 1 Area before generating a worker provisioning package.',
                ),
              if (!hasAreaError && hasCustomerWarning)
                _validationAlert(
                  isError: false,
                  title: 'No Customers Found',
                  message:
                      'Worker will be provisioned with 0 customer records.',
                ),
              if (hasItemWarning)
                _validationAlert(
                  isError: false,
                  title: 'No Inventory Items Found',
                  message:
                      'Worker will not be able to add inventory line items to orders.',
                ),

              const Text(
                'Provisioned Scope & Payload Details',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.primary),
              ),
              const SizedBox(height: 8),

              // --- BREAKDOWN TABLE ---
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: Column(
                  children: [
                    _metricRow(Icons.map_rounded, 'Database Areas',
                        '$areasCount Areas'),
                    const Divider(height: 1),
                    _metricRow(Icons.add_road_rounded, 'Database Streets',
                        '$streetsCount Streets'),
                    const Divider(height: 1),
                    _metricRow(Icons.people_alt_rounded, 'Database Customers',
                        '$customersCount Customers'),
                    const Divider(height: 1),
                    _metricRow(Icons.category_rounded, 'Product Categories',
                        '$categoriesCount Categories'),
                    const Divider(height: 1),
                    _metricRow(Icons.inventory_2_rounded, 'Inventory Items',
                        '$itemsCount Items'),
                    const Divider(height: 1),
                    _metricRow(Icons.route_rounded, 'Route Visits',
                        '$routesCount Visits'),
                    const Divider(height: 1),
                    _metricRow(
                        Icons.sd_storage_rounded,
                        'Estimated Package Size',
                        '~${estimatedSizeMb.toStringAsFixed(1)} MB'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- SECURITY BADGE ---
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_rounded,
                        color: AppColors.success, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AES-256 Encrypted & HMAC-SHA256 Signed with Worker Secret Key.',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- ACTION BUTTONS ---
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: isBlocked
                          ? null
                          : () {
                              AppHaptics.buttonClick();
                              Navigator.pop(context);
                              onConfirmExport();
                            },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Generate & Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _validationAlert(
      {required bool isError, required String title, required String message}) {
    final color = isError ? AppColors.error : Colors.amber.shade800;
    final bg = isError ? AppColors.errorSurface : Colors.amber.shade50;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.warning_amber_rounded,
              color: color,
              size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: color)),
                const SizedBox(height: 2),
                Text(message,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.gray600),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ],
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
