# Features Registry

The features in OrderKart are divided into isolated modules:

## 1. Area & Locations Intelligence
- **Purpose**: Defines location scopes. Supports nested spatial hierarchy (Area > Sector > Road > Galli).
- **Files**: `lib/features/location/`
- **Integrations**: Linked to Customers and Visits.

## 2. Customer Profile & VIP Membership
- **Purpose**: Manage customer directories, ledger history, contact information, dietary choices, and VIP plan subscriptions.
- **VIP Plan**: Supports Gold, Platinum, Custom tier structures with markups, automatic priority deliveries, and discount percentages.
- **Files**: `lib/features/customer/`

## 3. Inventory Directory
- **Purpose**: Track product items, minimum stock alerts, and automated stock deductions/restorations on order generation/cancellation.
- **Files**: `lib/features/inventory/`

## 4. Order & Billing Ledger
- **Purpose**: Add, edit, dispatch orders. Generates professional WhatsApp receipts with store contacts separated at the bottom.
- **Files**: `lib/features/order/`, `lib/core/utils/bill_text_generator.dart`

## 5. Worker Provisioning & Management
- **Purpose**: Manage active worker list. Generate encrypted and signature-signed `.orderkart` configuration file scoped specifically to the worker's assignments to protect proprietary customer directories.
- **Files**: `lib/features/worker/`, `lib/core/services/worker_package_service.dart`

## 6. Financial Profit & Loss Analytics
- **Purpose**: Summarize total revenues, monthly summary expense tables, margins, ratios, and progress indicator bars.
- **Files**: `lib/features/analytics/`, `lib/features/expense/`
