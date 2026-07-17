# Performance & Optimization Specifications

OrderKart incorporates custom performance rules to maintain fluid 60fps rendering, speedy query cycles, and minimum battery consumption under continuous field usage.

## 1. Database WAL Mode
- **Configuration**:
  - The SQLite database is initialized with `PRAGMA journal_mode = WAL` (Write-Ahead Logging).
  - This separates concurrent reads and writes, preventing UI freezes during high-frequency inserts (e.g. bulk importing or synchronization routines).
- **WAL Checkpointing**:
  - Before backing up or exporting files, the app triggers a `PRAGMA wal_checkpoint(FULL);` block to write all cached pages back into the main database file, avoiding corrupted exports.

## 2. Spatial Mapping & Offline Tile Caching
- **Offline Maps**:
  - Leverages `flutter_map_tile_caching` (FMTC) to capture and cache map tile grids locally.
  - Workers can inspect map screens, trace streets, and check customer pin boundaries inside remote rural locations with zero cell network.
- **Dynamic Boundary Geofencing**:
  - Geofence calculations are pre-filtered inside the `locations` hierarchy depth limits to minimize memory allocations.

## 3. High-Performance Image Compression
- **Permanent Storage**:
  - Images captured on-site (customer profile photos, expense receipts) are resized and permanently saved to local documents storage.
  - This avoids loading bloated raw gallery images in memory, reducing runtime allocations and preventing Out-Of-Memory (OOM) crashes.

## 4. JIT File Path Resolution (`AppConstants.resolveFile`)
- **Concept**:
  - Absolute file paths stored in database columns (e.g. `photo_path` in `customers` or `photo_path` in `items`) from a sync partner or backup source can point to non-existent directories on the local target device.
- **Resolution Flow**:
  - The app dynamically intercepts path loads using `AppConstants.resolveFile`.
  - It extracts the file basename and checks specific local folders (`customer_photos`, `area_photos`, `street_photos`, `note_photos`, `attachments`, `item_photos`, `expense_receipts`) to find a matching file.
  - If a match is found, the path is resolved to the local file, avoiding broken image placeholders in the UI.
