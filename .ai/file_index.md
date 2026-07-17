# File Index

An index of critical files in the codebase to expedite future navigation:

## Core Layer
- [database_helper.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/core/database/database_helper.dart)
  - **Purpose**: Main SQLite initializer, migration manager, and JSON/Path topological merging logic.
- [app_theme.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/core/theme/app_theme.dart)
  - **Purpose**: Global Material 3 theme configuration containing Apple-style Glassmorphic translucent button styling and InkRipple configurations.
- [worker_package_service.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/core/services/worker_package_service.dart)
  - **Purpose**: Generates encrypted provisioning packages (`database.enc`, json files, photos) scoped to worker.
- [hotspot_sync_service.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/core/services/hotspot_sync_service.dart)
  - **Purpose**: Handshakes P2P synchronization over local Wi-Fi hotspot socket servers.

## Feature Layer
- [customer.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/features/customer/domain/customer.dart)
  - **Purpose**: Customer data model containing serial, location, and VIP configuration definitions.
- [customer_dao.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/features/customer/data/customer_dao.dart)
  - **Purpose**: SQLite operations for Customer entries with auto legacy street/area foreign-key assertion JIT calls.
- [add_edit_customer_screen.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/features/customer/presentation/add_edit_customer_screen.dart)
  - **Purpose**: Customer creation form handling.
- [location_dao.dart](file:///c:/Users/ojast/Downloads/Asset-Manager/orderkart/lib/features/location/data/location_dao.dart)
  - **Purpose**: DAO class managing multi-level location trees and synchronizing legacy fallback areas/streets.
