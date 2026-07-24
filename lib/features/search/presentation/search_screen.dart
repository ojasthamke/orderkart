import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/vip_glow_avatar.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../customer/presentation/customer_provider.dart';
import '../domain/search_result.dart';
import 'search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _currentFilter = 'all';

  final _filters = [
    {'label': 'All', 'value': 'all'},
    {'label': 'Customers', 'value': 'customer'},
    {'label': 'Items', 'value': 'item'},
    {'label': 'Orders', 'value': 'order'},
    {'label': 'Areas', 'value': 'area'},
    {'label': 'Streets', 'value': 'street'},
  ];

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(searchProvider);

    return AppScaffold(
      title: 'Global Search',
      body: Column(
        children: [
          CustomSearchBar(
            hint: 'Search everything...',
            onChanged: (q) => ref.read(searchProvider.notifier).search(q),
          ),

          // Filters row
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = f['value'] == _currentFilter;
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return GestureDetector(
                  onTap: () => setState(() => _currentFilter = f['value']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withOpacity(0.3)
                          : (isDark
                              ? Colors.white.withOpacity(0.08)
                              : AppColors.gray100),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : (isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.transparent),
                      ),
                    ),
                    child: Text(
                      f['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : (isDark
                                ? Colors.white70
                                : AppColors.textSecondary),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Results
          Expanded(
            child: searchAsync.when(
              loading: () => const LoadingShimmer(count: 8),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (results) {
                final filtered = results.where((r) {
                  return _currentFilter == 'all' ||
                      r.type.name == _currentFilter;
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.search_off_rounded,
                    title: 'No Matches Found',
                    subtitle: 'Try searching with different terms',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final res = filtered[i];
                    return _SearchResultTile(
                      result: res,
                      onTap: () => _navigateToResult(res),
                    ).animate(delay: (i * 30).ms).fadeIn();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToResult(SearchResult res) {
    switch (res.type) {
      case SearchResultType.customer:
        Navigator.of(context).pushNamed(
          AppRoutes.customerProfile,
          arguments: {'customerId': res.id},
        );
        break;
      case SearchResultType.item:
        Navigator.of(context).pushNamed(
          AppRoutes.addEditItem,
          arguments: {'itemId': res.id},
        );
        break;
      case SearchResultType.order:
        Navigator.of(context).pushNamed(
          AppRoutes.orderDetail,
          arguments: {'orderId': res.id},
        );
        break;
      case SearchResultType.area:
        Navigator.of(context).pushNamed(
          AppRoutes.streets,
          arguments: {
            'areaId': res.id,
            'areaName': res.title,
          },
        );
        break;
      case SearchResultType.street:
        Navigator.of(context).pushNamed(
          AppRoutes.customers,
          arguments: {
            'streetId': res.id,
            'streetName': res.title,
          },
        );
        break;
      case SearchResultType.expense:
        Navigator.of(context).pushNamed(
          AppRoutes.expenses,
        );
        break;
    }
  }
}

class _SearchResultTile extends ConsumerWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _SearchResultTile({required this.result, required this.onTap});

  IconData get _icon {
    switch (result.type) {
      case SearchResultType.customer:
        return Icons.person_rounded;
      case SearchResultType.item:
        return Icons.inventory_2_rounded;
      case SearchResultType.order:
        return Icons.receipt_long_rounded;
      case SearchResultType.area:
        return Icons.map_rounded;
      case SearchResultType.street:
        return Icons.turn_slight_right_rounded;
      case SearchResultType.expense:
        return Icons.money_off_rounded;
    }
  }

  Color get _color {
    switch (result.type) {
      case SearchResultType.customer:
        return AppColors.primary;
      case SearchResultType.item:
        return AppColors.success;
      case SearchResultType.order:
        return AppColors.warning;
      case SearchResultType.area:
        return Colors.deepPurple;
      case SearchResultType.street:
        return Colors.teal;
      case SearchResultType.expense:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget leadingWidget = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(_icon, color: _color, size: 18),
    );

    if (result.type == SearchResultType.customer) {
      final customerAsync = ref.watch(customerDetailProvider(result.id));
      leadingWidget = customerAsync.when(
        data: (customer) => VipGlowAvatar(
          photoPath: customer?.photoPath ?? '',
          isVip: customer?.isVipActive ?? false,
          radius: 19,
        ),
        loading: () => const CircleAvatar(
          radius: 19,
          backgroundColor: AppColors.primarySurface,
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, __) =>
            const VipGlowAvatar(photoPath: '', isVip: false, radius: 19),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: ListTile(
        onTap: onTap,
        leading: leadingWidget,
        title: Text(
          result.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          result.subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right_rounded,
            size: 16, color: AppColors.gray400),
      ),
    );
  }
}
