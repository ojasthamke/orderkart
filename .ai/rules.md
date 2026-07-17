# Project Rules & Guidelines

## 1. Codebase Architecture
- Always respect Clean Architecture layering.
- Never write raw SQL directly in presentation widgets; restrict database operations to Data Access Objects (DAOs).

## 2. SQLite Constraint Management
- Never perform inserts or updates to the `customers` table without calling `DatabaseHelper.instance.ensureLegacyStreetAndAreaExists` first.
- Keep foreign keys active (`PRAGMA foreign_keys = ON`).

## 3. Import & Backup Verification
- Support raw SQLite database backups directly if the file begins with the `SQLite format 3` signature header.
- Always validate imports against strict Semantic Version checks (`PackageValidator.isVersionCompatible`) to prevent compatibility collisions.

## 4. UI/UX and Theme Consistency
- All new UI pages must use `AppScaffold` instead of raw `Scaffold`.
- Custom cards, rows, or detail elements must inherit frosted glass styling via `GlassContainer`.
- Avoid solid background fills or hardcoded grey borders. Use curated, translucent colors with thin white border lines.
- Always use `InkRipple.splashFactory` for touch feedback animation.

## 5. Haptics & User Feedback
- Use `Haptics` helper class to trigger sensory feedback on interactive actions:
  - `Haptics.success()` for successful submissions (e.g., customer saved, payment recorded).
  - `Haptics.warning()` / `Haptics.error()` for failures, form errors, or blocked paths.
  - `Haptics.selection()` for scrolling lists, picking options, or changing segments.

## 6. Responsive Adaptability
- Use `ResponsiveHelper` or `ResponsiveLayout` to support dual layouts (mobile and tablet formats).
- Ensure cards, forms, grid spans, and spacing scale adaptively rather than using fixed height/width values.

## 7. Smart Calculations
- Always use `SmartRounding` math functions when computing final checkout grand totals to ensure clear, even values under cash transactions.
- Respect `enableVipPriceMarkup` and `workerDiscountCap` rules when validating checkout items.

## 8. Documentation Maintenance
- Update matching `.ai/` documentation files upon introducing database migrations, new features, or architectural adjustments.
