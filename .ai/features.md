# Features Registry

The features in OrderKart are divided into 18 isolated modules matching the folder structure in `lib/features/`:

## 1. `analytics`
- **Purpose**: Compiles workers collection charts, revenue graphs, collection ratios, and commission values.
- **Data Model**: `lib/features/analytics/`

## 2. `area`
- **Purpose**: Legacy Area database replica module kept alive to prevent foreign-key constraints on customer entries.
- **Data Model**: `lib/features/area/`

## 3. `area_intelligence_map`
- **Purpose**: Offline GIS mapping using FMTC cached tiles, polygon geofence editing, and custom customer marker indicators.
- **Data Model**: `lib/features/area_intelligence_map/`

## 4. `auth`
- **Purpose**: Manages Owner PIN authentications, local lockout timelines, and activation code matching steps.
- **Data Model**: `lib/features/auth/`

## 5. `customer`
- **Purpose**: Stores customer profiles, photo pickers, outstanding dues ledgers, dietary choices, and Gold/Platinum VIP plans.
- **Data Model**: `lib/features/customer/`

## 6. `dashboard`
- **Purpose**: Displays outstanding balances summaries, system logs tickers, and general feature launch grids.
- **Data Model**: `lib/features/dashboard/`

## 7. `expense`
- **Purpose**: Tracks operational and worker-scoped business expenditures.
- **Data Model**: `lib/features/expense/`

## 8. `inventory`
- **Purpose**: Catalog of items, standard cost/selling prices, min-stock warning levels, and PDF export catalog utilities.
- **Data Model**: `lib/features/inventory/`

## 9. `location`
- **Purpose**: Unified spatial tree nodes (Area > Sector > Road > Galli) representing hierarchical territories.
- **Data Model**: `lib/features/location/`

## 10. `note`
- **Purpose**: Sticky checklist notes for driver remarks, general assignments, and instructions.
- **Data Model**: `lib/features/note/`

## 11. `notification`
- **Purpose**: System alerts listing page containing summaries of low-stock, due collections, or upcoming route plans.
- **Data Model**: `lib/features/notification/`

## 12. `order`
- **Purpose**: Billing ledger and order checkout dispatcher.
- **Data Model**: `lib/features/order/`

## 13. `search`
- **Purpose**: Speech-to-text voice recognition and query customer directory searches.
- **Data Model**: `lib/features/search/`

## 14. `settings`
- **Purpose**: UPI QR text setups, business profiles configuration, and global preferences.
- **Data Model**: `lib/features/settings/`

## 15. `street`
- **Purpose**: Legacy Street database replica table kept alive for foreign key consistency.
- **Data Model**: `lib/features/street/`

## 16. `sync`
- **Purpose**: Backup files exporter and imports merge wizard dialog interfaces.
- **Data Model**: `lib/features/sync/`

## 17. `visit`
- **Purpose**: Daily scheduled driver route visits linked to locations.
- **Data Model**: `lib/features/visit/`

## 18. `worker`
- **Purpose**: Worker directory, salary logs, targets, and scoped provisioning packages generator.
- **Data Model**: `lib/features/worker/`
