# Project Changelog

## 2026-07-17
### Added
- Created permanent project brain and documentation vault in `.ai/` directory.
- Created `security.md`, `performance.md`, and `workflows.md` to document worker scoping encryption, SQLite WAL optimizations, P2P sync socket sequence, and dynamic checkout questions.
- Prepend product sequence numbers (e.g. #1, #2) to item names in the owner's inventory screen, while keeping them hidden on the customer checkout order sheet.
- Display unit cost price alongside selling price in inventory screens and ordering sheets.
- Created `customer_item_prices` database table to support customer-specific custom price overrides during checkout.
- Added interactive price scope choice dialog (General vs This Customer vs Temporary) when manual unit price changes are made during checkout.
- Added all missing feature links (Expenses, Visits, Area Intelligence Map, Groceries Hub, Medicines Hub, Catalog Showroom, Churn Risk Alerts, and Notifications) to the AppDrawer list menu.
- Implemented manual Serial No. (Sequence) input form field in AddEditItemScreen to custom-arrange items in the inventory, matching the customer shuffle sorting comparator logic.
- Implemented custom premium Royal Midnight Dark Theme (deep royal blue base, emerald brand accents, and frosted dark card styling) and set it as the default app theme fallback.

### Fixed
- Fixed customer saving exception in the worker app due to legacy foreign key checks on `customers.street_id` referencing empty `streets` tables (JIT constraint assertion added).
- Fixed worker provisioning package generation by query-serializing the unified `locations` table.
- Fixed SQLite database exception on the Worker Analytics & Performance screen by matching parameter count and arguments list length (reduced from 6 to 5 values).
- Fixed P2P hotspot sync handshake token mismatch when worker devices (lacking the owner's master secret) attempt connection with owner devices by allowing fallback token validation.

## 2026-07-16
### Added
- Set up `InkRipple.splashFactory` globally for liquid press animations.
- Themed Elevated, Outlined, and Text buttons with glassmorphic translucency.
- Propagated Apple-style Glassmorphism throughout all remaining screens in the codebase.
