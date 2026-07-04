import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import '../constants/app_routes.dart';
import '../database/database_helper.dart';
import 'background_service.dart';
import '../utils/formatters.dart';

class WidgetService {
  WidgetService._();
  
  static const String appGroupId = 'com.example.orderkart';
  static const String androidWidgetName = 'OrderKartWidgetProvider';
  static const String expenseWidgetName = 'ExpenseWidgetProvider';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(appGroupId);
  }

  static Future<void> checkWidgetLaunch(GlobalKey<NavigatorState> navigatorKey) async {
    try {
      void navigateToAddExpense() {
        int attempts = 0;
        void tryPush() {
          final state = navigatorKey.currentState;
          if (state != null) {
            state.pushNamed(AppRoutes.addEditExpense);
          } else if (attempts < 15) {
            attempts++;
            Future.delayed(const Duration(milliseconds: 200), tryPush);
          }
        }
        tryPush();
      }

      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (uri != null) {
        final uriStr = uri.toString().toLowerCase();
        if (uriStr.contains('expense') || uri.host.contains('expense')) {
          navigateToAddExpense();
        }
      }

      HomeWidget.widgetClicked.listen((uri) {
        if (uri != null) {
          final uriStr = uri.toString().toLowerCase();
          if (uriStr.contains('expense') || uri.host.contains('expense')) {
            navigateToAddExpense();
          }
        }
      });
    } catch (_) {}
  }

  static Future<void> updateWidgetData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final todayStr = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
      
      // Get today's orders count
      final orders = await db.rawQuery("SELECT COUNT(*) as count FROM orders WHERE strftime('%Y-%m-%d', created_at) = ?", [todayStr]);
      final todaysOrders = SqfliteUtils.firstIntValue(orders) ?? 0;

      // Get pending total
      final pendingCustomers = await db.rawQuery('SELECT SUM(outstanding_balance) as total FROM customers WHERE outstanding_balance > 0');
      final pendingTotal = (pendingCustomers.first['total'] as num?)?.toDouble() ?? 0.0;

      // Get low stock count
      final lowStockItems = await db.rawQuery('SELECT COUNT(*) as count FROM items WHERE stock <= min_stock');
      final lowStockCount = SqfliteUtils.firstIntValue(lowStockItems) ?? 0;

      await HomeWidget.saveWidgetData<String>('widget_orders', todaysOrders.toString());
      await HomeWidget.saveWidgetData<String>('widget_due', AppFormatters.currency(pendingTotal));
      await HomeWidget.saveWidgetData<String>('widget_stock', lowStockCount.toString());

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
      );
    } catch (e) {
      // Handle error gracefully
    }
  }
}
