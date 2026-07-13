/// OrderKart App Root — Router and Theme configuration
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_routes.dart';
import 'core/security/app_mode_service.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/settings_provider.dart';
import 'features/dashboard/presentation/main_screen.dart';
import 'features/area/presentation/area_screen.dart';
import 'features/street/presentation/street_screen.dart';
import 'features/customer/presentation/customer_list_screen.dart';
import 'features/customer/presentation/vip_dashboard_screen.dart';
import 'features/customer/presentation/customer_profile_screen.dart';
import 'features/customer/presentation/add_edit_customer_screen.dart';
import 'features/order/presentation/create_order_screen.dart';
import 'features/order/presentation/order_management_screen.dart';
import 'features/order/presentation/order_detail_screen.dart';
import 'core/widgets/qr_full_screen_preview.dart';
import 'features/order/presentation/payment_details_screen.dart';
import 'features/inventory/presentation/inventory_screen.dart';
import 'features/inventory/presentation/add_edit_item_screen.dart';
import 'features/inventory/presentation/stock_adjustment_screen.dart';
import 'features/expense/presentation/expense_screen.dart';
import 'features/expense/presentation/add_edit_expense_screen.dart';
import 'features/analytics/presentation/analytics_screen.dart';
import 'features/analytics/presentation/profit_loss_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/settings/presentation/backup_restore_screen.dart';
import 'features/search/presentation/search_screen.dart';
import 'features/notification/presentation/notification_center_screen.dart';
import 'features/note/presentation/notes_list_screen.dart';
import 'features/note/presentation/add_edit_note_screen.dart';
import 'features/visit/presentation/visit_list_screen.dart';
import 'features/visit/presentation/add_edit_visit_screen.dart';
import 'features/note/domain/app_note.dart';
import 'features/visit/domain/app_visit.dart';
import 'features/auth/presentation/mode_selection_screen.dart';
import 'features/auth/presentation/pin_lock_screen.dart';
import 'features/auth/presentation/welcome_splash_screen.dart';
import 'features/auth/presentation/ten_day_lock_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/worker_session.dart';
import 'features/worker/presentation/worker_management_screen.dart';
import 'features/worker/presentation/worker_self_profile_screen.dart';
import 'features/dashboard/presentation/worker_dashboard_screen.dart';
import 'features/sync/presentation/pending_sync_screen.dart';
import 'features/settings/presentation/import_wizard_screen.dart';
import 'features/settings/presentation/sync_history_screen.dart';
import 'features/settings/presentation/activity_timeline_screen.dart';
import 'features/settings/presentation/business_profile_screen.dart';
import 'features/analytics/presentation/worker_analytics_screen.dart';
import 'features/worker/presentation/worker_sync_activity_screen.dart';
import 'features/customer/presentation/call_logs_screen.dart';
import 'features/auth/presentation/worker_passcode_lock_screen.dart';
import 'features/order/presentation/order_questions_config_screen.dart';

class OrderKartApp extends ConsumerStatefulWidget {
  const OrderKartApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  ConsumerState<OrderKartApp> createState() => _OrderKartAppState();
}

class _OrderKartAppState extends ConsumerState<OrderKartApp> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: OrderKartApp.navigatorKey,
      title: 'OrderKart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final clampedScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.8,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedScaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: '/',
      onGenerateRoute: (settings) => _generateRoute(settings),
    );
  }

  /// Central route generator — ensures every navigation is handled
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.dashboard:
        return _slide(const AppStartupScreen(), settings);

      case AppRoutes.areas:
        return _slide(const AreaScreen());

      case AppRoutes.streets:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(StreetScreen(
          areaId: args['areaId'] as String,
          areaName: args['areaName'] as String,
        ));

      case AppRoutes.customers:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(CustomerListScreen(
          streetId: args?['streetId'] as String?,
          streetName: args?['streetName'] as String?,
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
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(CreateOrderScreen(
          customerId: args?['customerId'] as String? ?? '',
          customerName: args?['customerName'] as String? ?? '',
          orderId: args?['orderId'] as String?,
        ));

      case AppRoutes.orderManagement:
        return _slide(const OrderManagementScreen());

      case AppRoutes.orderDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(OrderDetailScreen(
          orderId: args['orderId'] as String,
        ));

      case AppRoutes.paymentDetails:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _slide(PaymentDetailsScreen(
          customerId: args['customerId'] as String? ?? '',
          remainingAmount: args['remainingAmount'] as double? ?? 0.0,
          grandTotal: args['grandTotal'] as double? ?? 0.0,
          currency: args['currency'] as String? ?? '₹',
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

      case AppRoutes.profitLoss:
        return _slide(const ProfitLossScreen());

      case AppRoutes.settings:
        return _slide(const SettingsScreen());

      case AppRoutes.backupRestore:
        return _slide(const BackupRestoreScreen());

      case AppRoutes.search:
        return _slide(const SearchScreen());

      case AppRoutes.qrPreview:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _slide(QrFullScreenPreview(
          qrCustomImage: args['qrCustomImage'] as String?,
          qrContent: args['qrContent'] as String?,
        ));

      case AppRoutes.notifications:
        return _slide(const NotificationCenterScreen());

      case AppRoutes.vipDashboard:
        return _slide(const VipDashboardScreen());

      case AppRoutes.notes:
        return _slide(const NotesListScreen());

      case AppRoutes.addEditNote:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(AddEditNoteScreen(existingNote: args?['note'] as AppNote?));

      case AppRoutes.visits:
        return _slide(const VisitListScreen());

      case AppRoutes.addEditVisit:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(AddEditVisitScreen(visit: args?['visit'] as AppVisit?));

      // Enterprise & Security
      case AppRoutes.modeSelection:
        return _slide(const ModeSelectionScreen());

      case AppRoutes.pinLock:
        return _slide(const PinLockScreen());

      case AppRoutes.welcome:
        final args = settings.arguments as WelcomeSplashScreenArgs;
        return _slide(WelcomeSplashScreen(args: args));

      case AppRoutes.workers:
        return _slide(const WorkerManagementScreen());

      case AppRoutes.workerDashboard:
        return _slide(const WorkerDashboardScreen(), settings);

      case AppRoutes.pendingSync:
        return _slide(const PendingSyncScreen());

      case AppRoutes.importWizard:
        return _slide(const ImportWizardScreen());

      case AppRoutes.syncHistory:
        return _slide(const SyncHistoryScreen());

      case AppRoutes.activityTimeline:
        return _slide(const ActivityTimelineScreen());

      case AppRoutes.businessProfile:
        return _slide(const BusinessProfileScreen());

      case AppRoutes.workerAnalytics:
        return _slide(const WorkerAnalyticsScreen());

      case AppRoutes.workerSelfProfile:
        return _slide(const WorkerSelfProfileScreen());

      case AppRoutes.workerSyncActivity:
        return _slide(const WorkerSyncActivityScreen());

      case AppRoutes.callLogs:
        return _slide(const CallLogsScreen());

      case AppRoutes.workerPasscodeLock:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(WorkerPasscodeLockScreen(
          workerId: args['workerId'] as String,
          workerName: args['workerName'] as String,
          forceLogoutOnCancel: args['forceLogoutOnCancel'] as bool? ?? false,
        ));

      case AppRoutes.orderQuestionsConfig:
        return _slide(const OrderQuestionsConfigScreen());

      default:
        return _slide(const AppStartupScreen(), settings);
    }
  }

  /// Custom slide transition for smooth navigation
  PageRouteBuilder<T> _slide<T>(Widget page, [RouteSettings? settings]) {
    final args = settings?.arguments;
    final bool instant = (args is Map && args['instant'] == true);
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (instant) {
          return child;
        }
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
      transitionDuration: instant ? Duration.zero : const Duration(milliseconds: 280),
    );
  }
}

class AppStartupScreen extends ConsumerStatefulWidget {
  const AppStartupScreen({super.key});

  // Track if welcome screen was already shown in the current app session
  static bool welcomeShown = false;

  @override
  ConsumerState<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends ConsumerState<AppStartupScreen> {
  bool _unlockedSession = false;

  @override
  Widget build(BuildContext context) {
    // If Owner is already logged in for this run, bypass splash and show MainScreen directly
    if (AppModeService.isOwnerSessionActive && (AppStartupScreen.welcomeShown || _unlockedSession)) {
      return const MainScreen();
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: () async {
        final initialized = await AppModeService.isAppInitialized();
        final mode = await AppModeService.getAppMode();
        if (mode == AppMode.worker) {
          await WorkerSession.instance.load();
        }

        // 10-day lock check
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now().millisecondsSinceEpoch;
        bool is10DayLocked = false;
        bool isWorker10DayLocked = false;
        String workerId = '';
        String workerName = '';

        if (mode == AppMode.owner) {
          final lastUnlock = prefs.getInt('last_10day_unlock_time');
          if (lastUnlock == null) {
            await prefs.setInt('last_10day_unlock_time', now);
          } else {
            const tenDaysMs = 10 * 24 * 60 * 60 * 1000;
            if (now - lastUnlock >= tenDaysMs) {
              is10DayLocked = true;
            }
          }
        } else if (mode == AppMode.worker) {
          workerId = WorkerSession.instance.currentWorkerId ?? '';
          workerName = WorkerSession.instance.currentWorkerName ?? 'Worker';
          if (workerId.isNotEmpty) {
            final lastWorkerUnlock = prefs.getInt('last_worker_verification_time_$workerId');
            if (lastWorkerUnlock == null) {
              isWorker10DayLocked = true;
            } else {
              const tenDaysMs = 10 * 24 * 60 * 60 * 1000;
              if (now - lastWorkerUnlock >= tenDaysMs) {
                isWorker10DayLocked = true;
              }
            }
          }
        }

        return {
          'initialized': initialized,
          'mode': mode,
          'is10DayLocked': is10DayLocked,
          'isWorker10DayLocked': isWorker10DayLocked,
          'workerId': workerId,
          'workerName': workerName,
        };
      }(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final data = snapshot.data ?? {
          'initialized': false,
          'mode': AppMode.owner,
          'is10DayLocked': false,
          'isWorker10DayLocked': false,
          'workerId': '',
          'workerName': '',
        };

        final bool isWorker10DayLocked = data['isWorker10DayLocked'] as bool? ?? false;
        if (isWorker10DayLocked && !_unlockedSession) {
          return WorkerPasscodeLockScreen(
            workerId: data['workerId'] as String? ?? '',
            workerName: data['workerName'] as String? ?? 'Worker',
            forceLogoutOnCancel: true,
            onUnlocked: () {
              setState(() {
                _unlockedSession = true;
              });
            },
          );
        }

        final bool is10DayLocked = data['is10DayLocked'] as bool;
        if (is10DayLocked && !_unlockedSession) {
          return TenDayLockScreen(
            onUnlocked: () {
              setState(() {
                _unlockedSession = true;
              });
            },
          );
        }

        final bool initialized = data['initialized'] as bool;
        final AppMode mode = data['mode'] as AppMode;

        if (!initialized) {
          return const ModeSelectionScreen();
        }

        final nextRoute = (mode == AppMode.worker) ? AppRoutes.workerDashboard : AppRoutes.dashboard;
        final name = (mode == AppMode.owner) ? 'Nayan' : (WorkerSession.instance.currentWorkerName ?? 'Worker');

        if (mode == AppMode.owner) {
          AppModeService.loginOwnerSuccess();
        }

        return WelcomeSplashScreen(
          args: WelcomeSplashScreenArgs(name: name, nextRoute: nextRoute),
        );
      },
    );
  }
}
