# Database Architecture and Schemas

OrderKart uses SQLite (via `sqflite`) with foreign keys enabled.

## Schema Table Definitions

### 1. `locations` (Unified Hierarchy table)
- `id` (TEXT PRIMARY KEY) - UUID string.
- `parent_location_id` (TEXT) - Parent node ID.
- `name` (TEXT) - Location name.
- `description` (TEXT) - Optional description.
- `location_kind` (TEXT) - 'area', 'section', 'road', 'galli', etc.
- `sequence_key` (TEXT) - Sorting key (padded string e.g. '001000').
- `depth` (INTEGER) - Depth level in tree.
- `materialized_path` (TEXT) - Nested path (e.g. `/parent/child/`).
- `photo_path` (TEXT) - Local image path.
- `maps_location` (TEXT) - Coordinates or URL.
- `color` (INTEGER) - Associated color hex value.
- `created_by` (TEXT) - Assigned creator ID.
- `assigned_worker_id` (TEXT) - Worker ID assigned to this location.
- `worker_name` (TEXT) - Assigned worker's name.
- `device_name` (TEXT) - Source device name.
- `is_archived` (INTEGER) - 0 or 1.

### 2. `customers`
- `id` (TEXT PRIMARY KEY)
- `street_id` (TEXT NOT NULL, FOREIGN KEY REFERENCES streets(id))
- `location_id` (TEXT DEFAULT '')
- `name` (TEXT)
- `phone1` (TEXT)
- `phone2` (TEXT)
- `whatsapp` (TEXT)
- `house_number` (TEXT)
- `address` (TEXT)
- `notes` (TEXT)
- `maps_location` (TEXT)
- `photo_path` (TEXT)
- `serial_no` (INTEGER)
- `outstanding_balance` (REAL)
- `total_orders` (INTEGER)
- `total_paid` (REAL)
- `total_pending` (REAL)
- `customer_since` (TEXT)
- `last_order_date` (TEXT)
- `created_at` (TEXT)
- `updated_at` (TEXT)
- `dietary_preference` (TEXT)
- VIP fields: `is_vip`, `vip_plan`, `vip_start_date`, `vip_expiry_date`, `vip_subscription_fee`, `vip_notes`, `vip_auto_renewal`, `vip_free_delivery`, `vip_discount_pct`, `vip_markup_pct`, `vip_priority_delivery`.

### 3. `orders`
- `id` (TEXT PRIMARY KEY)
- `customer_id` (TEXT NOT NULL, FOREIGN KEY REFERENCES customers(id))
- `subtotal` (REAL)
- `discount` (REAL)
- `delivery_charge` (REAL)
- `smart_rounded_amount` (REAL)
- `grand_total` (REAL)
- `paid_amount` (REAL)
- `remaining_amount` (REAL)
- `delivery_status` (TEXT)
- `notes` (TEXT)
- `savings` (REAL)
- `created_at` (TEXT)
- `updated_at` (TEXT)

### 4. `order_items`
- `id` (TEXT PRIMARY KEY)
- `order_id` (TEXT NOT NULL, FOREIGN KEY REFERENCES orders(id))
- `item_id` (TEXT)
- `item_name` (TEXT)
- `item_unit` (TEXT)
- `quantity` (REAL)
- `unit_price` (REAL)
- `total_price` (REAL)

### 5. `payments`
- `id` (TEXT PRIMARY KEY)
- `order_id` (TEXT NOT NULL, FOREIGN KEY REFERENCES orders(id))
- `customer_id` (TEXT NOT NULL)
- `amount` (REAL)
- `method` (TEXT)
- `notes` (TEXT)
- `created_at` (TEXT)

### Legacy Sync Tables (Keep Foreign Key Constraints Alive)
- `areas` (id, name, description, color, created_at, updated_at)
- `streets` (id, area_id, name, description, created_at, FOREIGN KEY references areas(id))
