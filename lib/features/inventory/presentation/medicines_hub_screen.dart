import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/security/app_mode_service.dart';
import '../domain/item.dart';
import '../domain/stock_history.dart';
import '../data/item_dao.dart';
import 'inventory_provider.dart';

class MedicinesHubScreen extends ConsumerStatefulWidget {
  const MedicinesHubScreen({super.key});

  @override
  ConsumerState<MedicinesHubScreen> createState() => _MedicinesHubScreenState();
}

class _MedicinesHubScreenState extends ConsumerState<MedicinesHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _adjustStock(Item item, double change) async {
    AppHaptics.buttonClick();
    try {
      final dao = ItemDao();
      await dao.adjustStock(item.id, change);
      await dao.insertStockHistory(StockHistory(
        id: '',
        itemId: item.id,
        itemName: item.name,
        changeAmount: change,
        reason: 'manual',
        createdAt: DateTime.now(),
      ));
      ref.invalidate(inventoryProvider);
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Medicine stock adjusted');
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryProvider);
    final isWorker = ref.watch(appModeProvider).value == AppMode.worker;

    return AppScaffold(
      title: 'Medicines Hub',
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: const [
          Tab(icon: Icon(Icons.medical_services_rounded), text: 'Medical Stock'),
          Tab(icon: Icon(Icons.notifications_active_rounded), text: 'Expiry Radar'),
          Tab(icon: Icon(Icons.rule_folder_rounded), text: 'Rx Compliance'),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allItems) {
          final medicines = allItems.where((i) => i.category == AppConstants.catMedicines).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildStockTab(medicines, isWorker),
              _buildExpiryTab(medicines),
              _buildRxTab(medicines),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStockTab(List<Item> items, bool isWorker) {
    if (items.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.medical_services_outlined,
        title: 'No Medicines Registered',
        subtitle: 'Create medicines from the standard Inventory panel',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isLow = item.isLowStock;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.prescriptionRequired)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.error.withOpacity(0.3)),
                              ),
                              child: const Text(
                                'Rx',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (item.dosageInfo.isNotEmpty)
                        Text(
                          item.dosageInfo,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLow ? AppColors.errorSurface : AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Stock: ${item.stock} ${item.unit}',
                              style: TextStyle(
                                color: isLow ? AppColors.error : AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (item.batchNumber.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Batch: ${item.batchNumber}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.remove_rounded),
                      onPressed: item.stock <= 0 ? null : () => _adjustStock(item, -1),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => _adjustStock(item, 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: -0.05, end: 0);
      },
    );
  }

  Widget _buildExpiryTab(List<Item> items) {
    final datedItems = items.where((i) => i.expiryDate.isNotEmpty).toList();

    if (datedItems.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.calendar_month_outlined,
        title: 'No Expiry Dates Set',
        subtitle: 'Configure medicine expiration dates during item edits',
      );
    }

    datedItems.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final limitDate = DateTime.now().add(const Duration(days: 30));
    final limitStr = limitDate.toIso8601String().substring(0, 10);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: datedItems.length,
      itemBuilder: (context, index) {
        final item = datedItems[index];
        final isExpired = item.expiryDate.compareTo(todayStr) < 0;
        final isExpiringSoon = !isExpired && item.expiryDate.compareTo(limitStr) <= 0;

        Color cardBorderColor = Colors.transparent;
        Color badgeColor = AppColors.success;
        String badgeText = 'SAFE';

        if (isExpired) {
          cardBorderColor = AppColors.error;
          badgeColor = AppColors.error;
          badgeText = 'EXPIRED';
        } else if (isExpiringSoon) {
          cardBorderColor = Colors.orange;
          badgeColor = Colors.orange;
          badgeText = 'EXPIRING SOON';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cardBorderColor, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: badgeColor.withOpacity(0.12),
                  child: Icon(
                    isExpired ? Icons.warning_rounded : (isExpiringSoon ? Icons.access_time_filled_rounded : Icons.check_rounded),
                    color: badgeColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          decoration: isExpired ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Expiry: ${item.expiryDate} (Batch: ${item.batchNumber.isNotEmpty ? item.batchNumber : "N/A"})',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (index * 50).ms);
      },
    );
  }

  Widget _buildRxTab(List<Item> items) {
    final rxItems = items.where((i) => i.prescriptionRequired).toList();

    return Column(
      children: [
        // Warnings Checklist header
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withOpacity(0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text(
                    'Rx Prescription Compliance Guide',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error.withOpacity(0.9)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '1. Verify the customer doctor note during order delivery.\n'
                '2. Check and record customer signatures/drawings on receipt checkout.\n'
                '3. Keep expired medical batches isolated from active stocks.',
                style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.error.withOpacity(0.85)),
              ),
            ],
          ),
        ),

        Expanded(
          child: rxItems.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.shield_outlined,
                  title: 'No Rx Medicines',
                  subtitle: 'No items in catalog currently require doctor prescriptions',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: rxItems.length,
                  itemBuilder: (context, index) {
                    final item = rxItems[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.offline_pin_rounded, color: AppColors.error),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Batch: ${item.batchNumber.isNotEmpty ? item.batchNumber : "N/A"} • Composition: ${item.dosageInfo.isNotEmpty ? item.dosageInfo : "N/A"}'),
                      ),
                    ).animate().fadeIn(delay: (index * 50).ms);
                  },
                ),
        ),
      ],
    );
  }
}
