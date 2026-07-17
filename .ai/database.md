# Database Architecture and Schemas

OrderKart uses SQLite (via `sqflite`) with foreign keys enabled (`PRAGMA foreign_keys = ON`).

## Core Table Schemas

### 1. `customers`
- `id` (TEXT PRIMARY KEY) - UUID string.
- `street_id` (TEXT NOT NULL, REFERENCES streets(id)) - Legacy street reference.
- `location_id` (TEXT DEFAULT '') - Unified locations hierarchy link.
- `name` (TEXT NOT NULL) - Customer name.
- `phone1` (TEXT NOT NULL) - Primary contact phone.
- `phone2` (TEXT DEFAULT '') - Alternate contact.
- `whatsapp` (TEXT DEFAULT '') - WhatsApp contact.
- `house_number` (TEXT DEFAULT '') - House/building indicator.
- `address` (TEXT DEFAULT '') - Complete text address.
- `notes` (TEXT DEFAULT '') - Special notes.
- `maps_location` (TEXT DEFAULT '') - Lat,Long coordinate string.
- `photo_path` (TEXT DEFAULT '') - Local storage photo path.
- `serial_no` (INTEGER DEFAULT 0) - Sorting sequence serial.
- `outstanding_balance` (REAL DEFAULT 0) - Total remaining balance.
- `total_orders` (INTEGER DEFAULT 0) - Lifetime order count.
- `total_paid` (REAL DEFAULT 0) - Lifetime paid amount.
- `total_pending` (REAL DEFAULT 0) - Current pending collections.
- `customer_since` (TEXT NOT NULL) - Timestamp when created.
- `last_order_date` (TEXT DEFAULT '') - Timestamp of last purchase.
- `created_at` (TEXT NOT NULL) - Creation timestamp.
- `updated_at` (TEXT NOT NULL) - Modification timestamp.
- `dietary_preference` (TEXT DEFAULT '') - 'veg', 'non_veg', or ''.
- **VIP fields**: `is_vip`, `vip_plan`, `vip_start_date`, `vip_expiry_date`, `vip_subscription_fee`, `vip_notes`, `vip_auto_renewal`, `vip_free_delivery`, `vip_discount_pct`, `vip_markup_pct`, `vip_priority_delivery`.

### 2. `orders`
- `id` (TEXT PRIMARY KEY) - UUID string.
- `customer_id` (TEXT NOT NULL, REFERENCES customers(id)) - Customer order target.
- `subtotal` (REAL NOT NULL DEFAULT 0) - Cost sum of order items.
- `discount` (REAL DEFAULT 0) - Flat or percentage deduction.
- `delivery_charge` (REAL DEFAULT 0) - Cost of shipping.
- `smart_rounded_amount` (REAL DEFAULT 0) - Adjusted rounded grand total.
- `grand_total` (REAL NOT NULL DEFAULT 0) - Final order total.
- `paid_amount` (REAL DEFAULT 0) - Payments collected on checkout.
- `remaining_amount` (REAL NOT NULL DEFAULT 0) - Dues left to pay.
- `delivery_status` (TEXT NOT NULL DEFAULT 'pending') - 'pending', 'delivered', 'cancelled'.
- `notes` (TEXT DEFAULT '') - Delivery driver notes.
- `savings` (REAL DEFAULT 0) - Savings value shown to customer.
- `created_at` (TEXT NOT NULL) - Creation timestamp.
- `updated_at` (TEXT NOT NULL) - Modification timestamp.

### 3. `order_items`
- `id` (TEXT PRIMARY KEY) - UUID string.
- `order_id` (TEXT NOT NULL, REFERENCES orders(id)) - Parent order link.
- `item_id` (TEXT DEFAULT '') - Catalog item link.
- `item_name` (TEXT NOT NULL) - Snapshot name of product.
- `item_unit` (TEXT NOT NULL) - Product unit (e.g. 'kg', 'pcs').
- `quantity` (REAL NOT NULL DEFAULT 1) - Quantity purchased.
- `unit_price` (REAL NOT NULL DEFAULT 0) - Unit selling rate.
- `total_price` (REAL NOT NULL DEFAULT 0) - Cost of line item.

### 4. `payments`
- `id` (TEXT PRIMARY KEY) - UUID string.
- `order_id` (TEXT NOT NULL, REFERENCES orders(id)) - Target order.
- `customer_id` (TEXT NOT NULL) - Payer customer link.
- `amount` (REAL NOT NULL DEFAULT 0) - Payment transaction value.
- `method` (TEXT NOT NULL DEFAULT 'cash') - 'cash', 'online', 'upi', 'card'.
- `notes` (TEXT DEFAULT '') - Additional comments.
- `created_at` (TEXT NOT NULL) - Transaction timestamp.

### 5. `expenses`
- `id` (TEXT PRIMARY KEY) - UUID string.
- `name` (TEXT NOT NULL) - Expense name/description.
- `category` (TEXT NOT NULL DEFAULT 'Other') - Category classification.
- `amount` (REAL NOT NULL DEFAULT 0) - Financial amount spent.
- `date` (TEXT NOT NULL) - Log date.
- `notes` (TEXT DEFAULT '') - Expense comments.
- `payment_method` (TEXT NOT NULL DEFAULT 'cash') - 'cash', 'online', 'card', 'upi'.
- `created_at` (TEXT NOT NULL) - Creation timestamp.
- `updated_at` (TEXT NOT NULL) - Modification timestamp.

### 6. `items`
- `id` (TEXT PRIMARY KEY) - UUID string.
- `name` (TEXT NOT NULL) - Product name.
- `category` (TEXT NOT NULL) - vegetables, fruits, groceries, medicines.
- `cost_price` (REAL NOT NULL DEFAULT 0) - Procurement cost.
- `selling_price` (REAL NOT NULL DEFAULT 0) - Standard selling rate.
- `stock` (REAL DEFAULT 0) - Current catalog quantity.
- `min_stock` (REAL DEFAULT 0) - Alert threshold quantity.
- `unit` (TEXT NOT NULL DEFAULT 'kg') - kg, g, pcs, ltr, ml, box, pack.
- `barcode` (TEXT DEFAULT '') - Barcode/QR string scanner.
- `weight_per_piece` (REAL DEFAULT 0.25) - Standard weight per piece.
- `photo_path` (TEXT DEFAULT '') - Local catalog image.
- `sequence_no` (INTEGER DEFAULT 0) - Sorting hierarchy number.
- `created_at` (TEXT NOT NULL) - Creation timestamp.
- `updated_at` (TEXT NOT NULL) - Modification timestamp.

### 7. `workers`
- `id` (TEXT PRIMARY KEY) - UUID string.
- `name` (TEXT NOT NULL) - Full name.
- `photo_path` (TEXT DEFAULT '') - Photo link.
- `phone` (TEXT DEFAULT '') - Contact phone.
- `address` (TEXT DEFAULT '') - Complete home address.
- `joining_date` (TEXT DEFAULT '') - Hired date.
- `employee_id` (TEXT DEFAULT '') - Staff ID string.
- `status` (TEXT NOT NULL DEFAULT 'active') - active/inactive.
- `pin_hash` (TEXT DEFAULT '') - Salted owner check PIN hash.
- `commission_type` (TEXT NOT NULL DEFAULT 'pct_order') - fixed/pct_order.
- `commission_value` (REAL DEFAULT 5.0) - Payout value.
- `salary` (REAL DEFAULT 0) - Monthly base wage.
- `bonus` (REAL DEFAULT 0) - Active incentives.
- `notes` (TEXT DEFAULT '') - Admin feedback.
- `aadhaar_id` (TEXT DEFAULT '') - National ID card string.
- `emergency_contact` (TEXT DEFAULT '') - Emergency contact number.
- `bank_details` (TEXT DEFAULT '') - Payment transfer details.
- `target` (REAL DEFAULT 0.0) - Monthly collection goals.
- `joining_salary` (REAL DEFAULT 0.0) - Initial hire wage.
- `leave_status` (TEXT DEFAULT 'active') - Active status state.
- `remarks` (TEXT DEFAULT '') - Notes remarks.
- `created_at` (TEXT NOT NULL) - Creation timestamp.
- `updated_at` (TEXT NOT NULL) - Modification timestamp.

### 8. `visits`
- `id` (TEXT PRIMARY KEY) - UUID string.
- `date` (TEXT NOT NULL) - Scheduled date.
- `area_id` (TEXT NOT NULL) - Route area destination.
- `street_id` (TEXT DEFAULT '') - Route street destination.
- `location_id` (TEXT DEFAULT '') - Hierarchy location link.
- `notes` (TEXT DEFAULT '') - Instructions for driver.
- `priority` (INTEGER DEFAULT 0) - Sort priority.
- `status` (TEXT NOT NULL DEFAULT 'pending') - pending/completed/skipped.
- `created_at` (TEXT NOT NULL) - Creation timestamp.

### 9. `settings`
- `key` (TEXT PRIMARY KEY) - Unique settings identifier.
- `value` (TEXT NOT NULL) - String value.

### 10. `locations` (Unified Hierarchy table)
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

### 11. `areas` (Legacy Replica)
- `id` (TEXT PRIMARY KEY)
- `name` (TEXT NOT NULL)
- `description` (TEXT DEFAULT '')
- `color` (INTEGER DEFAULT 0)
- `created_at` (TEXT NOT NULL)
- `updated_at` (TEXT NOT NULL)

### 12. `streets` (Legacy Replica)
- `id` (TEXT PRIMARY KEY)
- `area_id` (TEXT NOT NULL, REFERENCES areas(id))
- `name` (TEXT NOT NULL)
- `description` (TEXT DEFAULT '')
- `created_at` (TEXT NOT NULL)
