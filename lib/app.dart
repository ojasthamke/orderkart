/// OrderKart App Root — Router and Theme configuration

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/settings_provider.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/area/presentation/area_screen.dart';
import 'features/street/presentation/street_screen.dart';
import 'features/customer/presentation/customer_list_screen.dart';
import 'features/customer/presentation/customer_profile_screen.dart';
import 'features/customer/presentation/add_edit_customer_screen.dart';
import 'features/order/presentation/create_order_screen.dart';
import 'features/order/presentation/order_management_screen.dart';
import 'features/order/presentation/order_detail_screen.dart';
import 'features/inventory/presentation/inventory_screen.dart';
import 'features/inventory/presentation/add_edit_item_screen.dart';
import 'features/inventory/presentation/stock_adjustment_screen.dart';
import 'features/expense/presentation/expense_screen.dart';
import 'features/expense/presentation/add_edit_expense_screen.dart';
import 'features/analytics/presentation/analytics_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/settings/presentation/backup_restore_screen.dart';
import 'features/search/presentation/search_screen.dart';

class OrderKartApp extends ConsumerWidget {
  const OrderKartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'OrderKart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      initialRoute: AppRoutes.dashboard,
      onGenerateRoute: (settings) => _generateRoute(settings),
    );
  }

  /// Central route generator — ensures every navigation is handled
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.dashboard:
        return _slide(const DashboardScreen());

      case AppRoutes.areas:
        return _slide(const AreaScreen());

      case AppRoutes.streets:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(StreetScreen(
          areaId: args['areaId'] as String,
          areaName: args['areaName'] as String,
        ));

      case AppRoutes.customers:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(CustomerListScreen(
          streetId: args['streetId'] as String,
          streetName: args['streetName'] as String,
        ));

      case AppRoutes.customerProfile:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(CustomerProfileScreen(
          customerId: args['customerId'] as String,
        ));

      case AppRoutes.addEditCustomer:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(AddEditCustomerScreen(
          streetId: args?['streetId'] as String?,
          customerId: args?['customerId'] as String?,
        ));

      case AppRoutes.createOrder:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(CreateOrderScreen(
          customerId: args['customerId'] as String,
          customerName: args['customerName'] as String,
          orderId: args['orderId'] as String?,
        ));

      case AppRoutes.orderManagement:
        return _slide(const OrderManagementScreen());

      case AppRoutes.orderDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(OrderDetailScreen(
          orderId: args['orderId'] as String,
        ));

      case AppRoutes.inventory:
        return _slide(const InventoryScreen());

      case AppRoutes.addEditItem:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(AddEditItemScreen(
          itemId: args?['itemId'] as String?,
        ));

      case AppRoutes.stockAdjustment:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(StockAdjustmentScreen(
          itemId: args['itemId'] as String,
          itemName: args['itemName'] as String,
        ));

      case AppRoutes.expenses:
        return _slide(const ExpenseScreen());

      case AppRoutes.addEditExpense:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(AddEditExpenseScreen(
          expenseId: args?['expenseId'] as String?,
        ));

      case AppRoutes.analytics:
        return _slide(const AnalyticsScreen());

      case AppRoutes.settings:
        return _slide(const SettingsScreen());

      case AppRoutes.backupRestore:
        return _slide(const BackupRestoreScreen());

      case AppRoutes.search:
        return _slide(const SearchScreen());

      default:
        return _slide(const DashboardScreen());
    }
  }

  /// Custom slide transition for smooth navigation
  PageRouteBuilder<T> _slide<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 280),
    );
  }
}
