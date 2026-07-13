/// App Routes — Named routes for all screens
/// Centralised to avoid typos and simplify navigation
library;

class AppRoutes {
  AppRoutes._();

  static const String dashboard = '/';
  static const String areas = '/areas';
  static const String streets = '/streets';
  static const String customers = '/customers';
  static const String vipDashboard = '/vip-dashboard';
  static const String customerProfile = '/customer-profile';
  static const String addEditCustomer = '/add-edit-customer';
  static const String createOrder = '/create-order';
  static const String orderManagement = '/order-management';
  static const String orderDetail = '/order-detail';
  static const String paymentDetails = '/payment-details';
  static const String inventory = '/inventory';
  static const String addEditItem = '/add-edit-item';
  static const String stockAdjustment = '/stock-adjustment';
  static const String expenses = '/expenses';
  static const String addEditExpense = '/add-edit-expense';
  static const String analytics = '/analytics';
  static const String profitLoss = '/profit-loss';
  static const String settings = '/settings';
  static const String backupRestore = '/backup-restore';
  static const String search = '/search';
  static const String qrPreview = '/qr-preview';

  // Notes
  static const String notes         = '/notes';
  static const String addEditNote   = '/add-edit-note';

  // Visits
  static const String visits        = '/visits';
  static const String addEditVisit  = '/add-edit-visit';

  // Enterprise & Security
  static const String modeSelection   = '/mode-selection';
  static const String workers         = '/workers';
  static const String workerDashboard = '/worker-dashboard';
  static const String pendingSync     = '/pending-sync';
  static const String importWizard    = '/import-wizard';
  static const String syncHistory     = '/sync-history';
  static const String activityTimeline= '/activity-timeline';
  static const String businessProfile = '/business-profile';

  static const String workerAnalytics = '/worker-analytics';
  static const String workerSelfProfile = '/worker-self-profile';
  static const String workerSyncActivity = '/worker-sync-activity';

  // Notifications
  static const String notifications   = '/notifications';
  static const String pinLock         = '/pin-lock';
  static const String welcome         = '/welcome';
  static const String callLogs        = '/call-logs';
  static const String workerPasscodeLock = '/worker-passcode-lock';
  static const String orderQuestionsConfig = '/order-questions-config';
}
