# File Index

A comprehensive catalog of critical files, their responsibilities, modules, and system impacts.

## Core Infrastructure

### 1. [database_helper.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/core/database/database_helper.dart)
- **Module**: Core Database
- **Purpose**: Main SQLite connection singleton, database schema, upgrades/migrations, and JSON/Path topological merging logic.
- **Critical Level**: High
- **Impacts**: Database Compatibility (Schema migrations), Sync (Merge tables), Local Performance (WAL Mode).
- **When to Modify**: When adding new tables, altering column definitions, or upgrading `AppConstants.dbVersion`.

### 2. [app_theme.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/core/theme/app_theme.dart)
- **Module**: Core Theme
- **Purpose**: Global Material 3 light/dark style specifications. Incorporates global `InkRipple.splashFactory` and glassmorphic button definitions.
- **Critical Level**: Medium
- **Impacts**: UI.
- **When to Modify**: When tweaking button overlays, ripple styles, typography, or card borders.

### 3. [background_service.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/core/services/background_service.dart)
- **Module**: Core Services
- **Purpose**: Foreground alerts scheduler that compiles alerts about collections, low stock, and visits on app load.
- **Critical Level**: Medium
- **Impacts**: Notifications.
- **When to Modify**: When adding new summary categories or changing notification triggers.

### 4. [hotspot_sync_service.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/core/services/hotspot_sync_service.dart)
- **Module**: Core Services
- **Purpose**: Socket-based server/client wrapper that handshakes P2P synchronization over local hotspot connections.
- **Critical Level**: High
- **Impacts**: Sync.
- **When to Modify**: When altering sync packages, handshakes, socket ports, or network gateway discovery.

### 5. [worker_package_service.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/core/services/worker_package_service.dart)
- **Module**: Core Services
- **Purpose**: Compiles encrypted worker provisioning packages (`WorkerPackage.orderkart`) including SQLite scoping and image directories.
- **Critical Level**: High
- **Impacts**: Security, Sync.
- **When to Modify**: When updating worker encryption, scoping criteria, or adding new modules to provisioning databases.

### 6. [package_exporter.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/core/services/package_exporter.dart)
- **Module**: Core Services
- **Purpose**: Handles selective database cloning and pruning for manual backup exports.
- **Critical Level**: Medium
- **Impacts**: Backup/Restore.
- **When to Modify**: When adding new export tables or changing zip file layouts.

### 7. [package_validator.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/core/services/package_validator.dart)
- **Module**: Core Services
- **Purpose**: Verifies HMAC signatures, files structure, and hashes of imported ZIP files.
- **Critical Level**: High
- **Impacts**: Security, Backup/Restore.
- **When to Modify**: When altering HMAC validation, signature format, or hash checking logic.

---

## Spatial Mapping & GIS

### 8. [area_intelligence_map_screen.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/features/area_intelligence_map/presentation/area_intelligence_map_screen.dart)
- **Module**: GIS / Area Map
- **Purpose**: Main map view displaying locations, boundary editor overlay, and customer pin locations.
- **Critical Level**: Medium
- **Impacts**: UI, Maps/GPS.
- **When to Modify**: When editing layer layouts or map action buttons.

### 9. [map_pin_picker_screen.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/features/area_intelligence_map/presentation/map_pin_picker_screen.dart)
- **Module**: GIS / Area Map
- **Purpose**: Utility picker screen to capture custom latitude/longitude points and return them to screens.
- **Critical Level**: Medium
- **Impacts**: UI, Maps/GPS.
- **When to Modify**: When changing coordinate feedback loops or map picker overlays.

### 10. [map_view_widget.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/features/area_intelligence_map/presentation/widgets/map_view_widget.dart)
- **Module**: GIS / Area Map
- **Purpose**: Renders the offline map surface with FMTC cached tile integrations.
- **Critical Level**: High
- **Impacts**: Maps/GPS, Local Performance.
- **When to Modify**: When changing tiles URL source, caching configurations, or layer styling.

---

## Customers & Order Ledger

### 11. [customer.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/features/customer/domain/customer.dart)
- **Module**: Customers
- **Purpose**: Customer domain entity mapping ledger balances, VIP configurations, and dietary properties.
- **Critical Level**: High
- **Impacts**: Database Compatibility, Sync.
- **When to Modify**: When adding new fields to the customer database schema.

### 12. [customer_dao.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/features/customer/data/customer_dao.dart)
- **Module**: Customers
- **Purpose**: SQLite operations for Customer entries with auto legacy street/area foreign-key assertion JIT calls.
- **Critical Level**: High
- **Impacts**: Database Compatibility, Sync.
- **When to Modify**: When altering customer database queries, filter searches, or order lists sorting.

### 13. [add_edit_customer_screen.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/features/customer/presentation/add_edit_customer_screen.dart)
- **Module**: Customers
- **Purpose**: Customer creation and edit form handling photo picker, maps picker, and custom attributes.
- **Critical Level**: Medium
- **Impacts**: UI.
- **When to Modify**: When updating input fields, validators, or picker launchers.

### 14. [location_dao.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/features/location/data/location_dao.dart)
- **Module**: Locations
- **Purpose**: SQLite queries and inserts for hierarchy locations, synchronizing entries to legacy `areas`/`streets`.
- **Critical Level**: High
- **Impacts**: Database Compatibility, Sync.
- **When to Modify**: When updating tree walk-up algorithms or legacy sync logic.

### 15. [create_order_screen.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/features/order/presentation/create_order_screen.dart)
- **Module**: Orders
- **Purpose**: Main order creation ledger incorporating active checkout questions, stock level checks, and VIP discount/markup calculations.
- **Critical Level**: High
- **Impacts**: UI, Inventory, Orders.
- **When to Modify**: When changing subtotal maths, discount logic, stock verification, or question prompts.

### 16. [worker_analytics_screen.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/features/analytics/presentation/worker_analytics_screen.dart)
- **Module**: Analytics
- **Purpose**: Dashboard screen compiling workers collections (cash/online), sales, target metrics, and commission values.
- **Critical Level**: High
- **Impacts**: UI, Analytics.
- **When to Modify**: When altering SQL metrics aggregates, target formulas, or leaderboard rankings.

---

## Custom Core Widgets

### 17. [voice_search_dialog.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/core/widgets/voice_search_dialog.dart)
- **Module**: Core Widgets
- **Purpose**: Voice recognition speech search overlay.
- **Critical Level**: Low
- **Impacts**: UI.
- **When to Modify**: When modifying speech listeners, styling dialog overlays, or updating voice input callbacks.

### 18. [hotspot_sync_control_card.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/core/widgets/hotspot_sync_control_card.dart)
- **Module**: Core Widgets
- **Purpose**: Status dashboard displaying hotspot server state, client logs, and synchronization triggers.
- **Critical Level**: Medium
- **Impacts**: UI, Sync.
- **When to Modify**: When updating sync progress overlays, instructions, or buttons.

### 19. [smart_business_pulse_widget.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/core/widgets/smart_business_pulse_widget.dart)
- **Module**: Core Widgets
- **Purpose**: Ticker dashboard displaying outstanding totals, system notifications, and business graphs.
- **Critical Level**: Medium
- **Impacts**: UI, Analytics.
- **When to Modify**: When rearranging metrics columns or notifications displays.
