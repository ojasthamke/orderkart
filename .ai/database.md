# Database Architecture and Schemas

OrderKart uses SQLite (via `sqflite`) with foreign keys enabled (`PRAGMA foreign_keys = ON`).

## Schema Table Definitions

### 1. Core ERP Data
- **`customers`**: Store customer directory, outstanding balance ledger, dietary preferences, and GPS coordinates (`latitude`, `longitude`), linked to legacy `streets`. Contains extensive VIP configuration columns (`is_vip`, `vip_plan`, `vip_start_date`, `vip_expiry_date`, `vip_subscription_fee`, `vip_notes`, `vip_auto_renewal`, `vip_free_delivery`, `vip_discount_pct`, `vip_markup_pct`, `vip_priority_delivery`).
- **`orders`**: Tracks order subtotals, discounts, delivery charge, smart rounding adjustments, grand totals, remaining/paid amounts, and delivery status.
- **`order_items`**: Line items within an order tracking item ID, name, unit, quantity, rate, and total price.
- **`payments`**: Records customer payments applied to orders (amount, payment method, date).
- **`expenses`**: Tracks company/worker-scoped expenses (amount, category, payment method, assigned worker).
- **`items`**: Catalog of product inventory (cost price, selling price, current stock, min stock, unit, photo_path, weight_per_piece, sequence_no).
- **`item_price_history`**: Historic product base selling rates.
- **`stock_history`**: Audit trail of manual or order-triggered inventory changes.
- **`settings`**: Key-value pair configuration settings for app initialization, P2P secrets, active worker, and app mode.

### 2. Location & GIS Data
- **`locations`**: Unified spatial hierarchy tree structure supporting nested spatial nodes (`parent_location_id`, `location_kind`, `sequence_key`, `depth`, `materialized_path`, etc.).
- **`geo_boundaries`**: Coordinates bounding specific area sectors.
- **`geo_boundary_points`**: Latitude/longitude vertices for the boundaries.
- **`visits`**: Route planner visits linked to locations.
- **`areas`** & **`streets`**: Legacy location replica tables kept to prevent foreign key errors on customer and visit constraints.

### 3. Worker Scoping & Security
- **`workers`**: Directory of workers, role details, role, salary, target, joining date, joining salary, and commission rates.
- **`worker_security`**: Encrypted security hashes mapping worker credentials (`worker_secret`).
- **`worker_assignments`**: Scoped areas, streets, or customers assigned to specific worker IDs to filter synced payloads.
- **`worker_permissions`**: Action permission mappings allowed for specific worker IDs.
- **`worker_reports`**: Historic worker performance outputs.
- **`worker_devices`**: Device tracking records.
- **`commission_history`**: Worker payout commission logs.

### 4. Custom Attributes & Questions
- **`order_questions`**: Questions configured by owner to prompt during checkouts.
- **`customer_question_answers`**: Customer responses to attribute questions.
- **`order_question_answers`**: Checkout responses to checkout questions.
- **`custom_fields`**: Dynamic custom attributes metadata for entities.
- **`custom_field_values`**: Values for dynamic custom attributes.

### 5. Extended Logistics & Procurement
- **`item_warehouses`**: Stock allocations inside different store branches or warehouses.
- **`suppliers`**: Supplier contact directories.
- **`supplier_ledger`**: Transaction and ledger logs with third-party suppliers.
- **`supplier_price_tracker`**: Historic procurement rates of product items from suppliers.
- **`purchase_orders`** & **`purchase_order_items`**: Supplier procurement orders and line items.

### 6. Logs & Sync Metadata
- **`notifications`**: Local notification queue.
- **`notes`**: Local sticky note tasks.
- **`call_logs`**: Dialer call triggers.
- **`sync_history`**: P2P sync logs.
- **`pending_sync`**: Outbox queue of offline actions.
- **`audit_logs`**: Internal action logs.
- **`repair_logs`**: DB recovery attempts.
- **`export_history`** & **`import_history`**: Backup/restore triggers.
