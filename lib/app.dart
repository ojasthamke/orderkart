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
import 'features/location/presentation/location_detail_screen.dart';
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
import 'features/analytics/presentation/churn_risk_screen.dart';
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
import 'features/inventory/presentation/groceries_hub_screen.dart';
import 'features/inventory/presentation/medicines_hub_screen.dart';
import 'features/dashboard/presentation/owner_features_hub_screen.dart';
import 'features/inventory/presentation/catalog_showroom_screen.dart';
import 'features/inventory/presentation/quick_inventory_adjust_screen.dart';
import 'features/area_intelligence_map/presentation/area_intelligence_map_screen.dart';
import 'features/area_intelligence_map/presentation/map_pin_picker_screen.dart';
import 'package:latlong2/latlong.dart';

class OrderKartApp extends ConsumerStatefulWidget {
  const OrderKartApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

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
          child: SafeArea(
            child: child ?? const SizedBox.shrink(),
          ),
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
        return _slide(const AreaScreen(), settings);

      case AppRoutes.streets:
        final args = (settings.arguments as Map<String, dynamic>?) ?? {};
        return _slide(
            LocationDetailScreen(
              locationId: args['areaId'] as String? ?? '',
              locationName: args['areaName'] as String? ?? 'Location Details',
            ),
            settings);

      case AppRoutes.customers:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(
            CustomerListScreen(
              streetId: args?['streetId'] as String?,
              streetName: args?['streetName'] as String?,
            ),
            settings);

      case AppRoutes.customerProfile:
        final args = (settings.arguments as Map<String, dynamic>?) ?? {};
        return _slide(
            CustomerProfileScreen(
              customerId: args['customerId'] as String? ?? '',
            ),
            settings);

      case AppRoutes.addEditCustomer:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(
            AddEditCustomerScreen(
              streetId: args?['streetId'] as String?,
              customerId: args?['customerId'] as String?,
            ),
            settings);

      case AppRoutes.createOrder:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(
            CreateOrderScreen(
              customerId: args?['customerId'] as String? ?? '',
              customerName: args?['customerName'] as String? ?? '',
              orderId: args?['orderId'] as String?,
              initialDiscount: (args?['initialDiscount'] as num?)?.toDouble(),
            ),
            settings);

      case AppRoutes.orderManagement:
        return _slide(const OrderManagementScreen(), settings);

      case AppRoutes.orderDetail:
        final args = (settings.arguments as Map<String, dynamic>?) ?? {};
        return _slide(
            OrderDetailScreen(
              orderId: args['orderId'] as String? ?? '',
            ),
            settings);

      case AppRoutes.paymentDetails:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _slide(
            PaymentDetailsScreen(
              customerId: args['customerId'] as String? ?? '',
              remainingAmount:
                  (args['remainingAmount'] as num?)?.toDouble() ?? 0.0,
              grandTotal: (args['grandTotal'] as num?)?.toDouble() ?? 0.0,
              currency: args['currency'] as String? ?? '₹',
            ),
            settings);

      case AppRoutes.inventory:
        return _slide(const InventoryScreen(), settings);

      case AppRoutes.quickInventoryAdjust:
        return _slide(const QuickInventoryAdjustScreen(), settings);

      case AppRoutes.addEditItem:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(
            AddEditItemScreen(
              itemId: args?['itemId'] as String?,
            ),
            settings);

      case AppRoutes.stockAdjustment:
        final args = (settings.arguments as Map<String, dynamic>?) ?? {};
        return _slide(
            StockAdjustmentScreen(
              itemId: args['itemId'] as String? ?? '',
              itemName: args['itemName'] as String? ?? 'Item',
            ),
            settings);

      case AppRoutes.expenses:
        return _slide(const ExpenseScreen(), settings);

      case AppRoutes.addEditExpense:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(
            AddEditExpenseScreen(
              expenseId: args?['expenseId'] as String?,
            ),
            settings);

      case AppRoutes.analytics:
        return _slide(const AnalyticsScreen(), settings);

      case AppRoutes.profitLoss:
        return _slide(const ProfitLossScreen(), settings);

      case AppRoutes.settings:
        return _slide(const SettingsScreen(), settings);

      case AppRoutes.backupRestore:
        return _slide(const BackupRestoreScreen(), settings);

      case AppRoutes.search:
        return _slide(const SearchScreen(), settings);

      case AppRoutes.qrPreview:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _slide(
            QrFullScreenPreview(
              qrCustomImage: args['qrCustomImage'] as String?,
              qrContent: args['qrContent'] as String?,
            ),
            settings);

      case AppRoutes.notifications:
        return _slide(const NotificationCenterScreen(), settings);

      case AppRoutes.vipDashboard:
        return _slide(const VipDashboardScreen(), settings);

      case AppRoutes.notes:
        return _slide(const NotesListScreen(), settings);

      case AppRoutes.addEditNote:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(
            AddEditNoteScreen(existingNote: args?['note'] as AppNote?),
            settings);

      case AppRoutes.visits:
        return _slide(const VisitListScreen(), settings);

      case AppRoutes.addEditVisit:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(
            AddEditVisitScreen(visit: args?['visit'] as AppVisit?), settings);

      // Enterprise & Security
      case AppRoutes.modeSelection:
        return _slide(const ModeSelectionScreen(), settings);

      case AppRoutes.pinLock:
        return _slide(const PinLockScreen(), settings);

      case AppRoutes.welcome:
        final args = settings.arguments is WelcomeSplashScreenArgs
            ? settings.arguments as WelcomeSplashScreenArgs
            : WelcomeSplashScreenArgs(
                name: 'Owner', nextRoute: AppRoutes.dashboard);
        return _slide(WelcomeSplashScreen(args: args), settings);

      case AppRoutes.workers:
        return _slide(const WorkerManagementScreen(), settings);

      case AppRoutes.workerDashboard:
        return _slide(const WorkerDashboardScreen(), settings);

      case AppRoutes.pendingSync:
        return _slide(const PendingSyncScreen(), settings);

      case AppRoutes.importWizard:
        return _slide(const ImportWizardScreen(), settings);

      case AppRoutes.syncHistory:
        return _slide(const SyncHistoryScreen(), settings);

      case AppRoutes.activityTimeline:
        return _slide(const ActivityTimelineScreen(), settings);

      case AppRoutes.businessProfile:
        return _slide(const BusinessProfileScreen(), settings);

      case AppRoutes.workerAnalytics:
        return _slide(const WorkerAnalyticsScreen(), settings);

      case AppRoutes.workerSelfProfile:
        return _slide(const WorkerSelfProfileScreen(), settings);

      case AppRoutes.workerSyncActivity:
        return _slide(const WorkerSyncActivityScreen(), settings);

      case AppRoutes.callLogs:
        return _slide(const CallLogsScreen(), settings);

      case AppRoutes.workerPasscodeLock:
        final args = (settings.arguments as Map<String, dynamic>?) ?? {};
        return _slide(
            WorkerPasscodeLockScreen(
              workerId: args['workerId'] as String? ?? '',
              workerName: args['workerName'] as String? ?? 'Worker',
              forceLogoutOnCancel:
                  args['forceLogoutOnCancel'] as bool? ?? false,
            ),
            settings);

      case AppRoutes.orderQuestionsConfig:
        return _slide(const OrderQuestionsConfigScreen(), settings);

      case AppRoutes.groceriesHub:
        return _slide(const GroceriesHubScreen(), settings);

      case AppRoutes.medicinesHub:
        return _slide(const MedicinesHubScreen(), settings);

      case AppRoutes.ownerFeaturesHub:
        final args = settings.arguments as Map<String, dynamic>?;
        final initialTab = args?['initialTab'] as int? ?? 0;
        return _slide(
            OwnerFeaturesHubScreen(initialTab: initialTab), settings);

      case AppRoutes.catalogShowroom:
        return _slide(const CatalogShowroomScreen(), settings);

      case AppRoutes.churnRisk:
        return _slide(const ChurnRiskScreen(), settings);

      case AppRoutes.areaIntelligenceMap:
        final args = (settings.arguments as Map<String, dynamic>?) ?? {};
        return _slide(
            AreaIntelligenceMapScreen(
              areaId: args['areaId']?.toString() ?? '',
              areaName: args['areaName']?.toString() ?? 'Area Map',
            ),
            settings);

      case AppRoutes.mapPinPicker:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(
            MapPinPickerScreen(
              initialPosition: args?['initialPosition'] as LatLng?,
            ),
            settings);

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
        const begin = Offset(0.05, 0.0);
        const end = Offset.zero;
        const curve = Curves.fastOutSlowIn;
        final slideTween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final scaleTween = Tween<double>(begin: 0.97, end: 1.0)
            .chain(CurveTween(curve: curve));
        final fadeTween =
            Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(slideTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: ScaleTransition(
              scale: animation.drive(scaleTween),
              child: child,
            ),
          ),
        );
      },
      transitionDuration:
          instant ? Duration.zero : const Duration(milliseconds: 250),
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
    if (AppModeService.isOwnerSessionActive &&
        (AppStartupScreen.welcomeShown || _unlockedSession)) {
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
            final lastWorkerUnlock =
                prefs.getInt('last_worker_verification_time_$workerId');
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
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Initialization Error:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final data = snapshot.data ??
            {
              'initialized': false,
              'mode': AppMode.owner,
              'is10DayLocked': false,
              'isWorker10DayLocked': false,
              'workerId': '',
              'workerName': '',
            };

        final bool isWorker10DayLocked =
            data['isWorker10DayLocked'] as bool? ?? false;
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

        final nextRoute = (mode == AppMode.worker)
            ? AppRoutes.workerDashboard
            : AppRoutes.dashboard;
        final name = (mode == AppMode.owner)
            ? 'Nayan'
            : (WorkerSession.instance.currentWorkerName ?? 'Worker');

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
