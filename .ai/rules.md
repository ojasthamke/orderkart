# Project Rules & Guidelines

## 1. Codebase Architecture
- Always respect Clean Architecture layering.
- Never write raw SQL directly in presentation widgets; restrict database operations to Data Access Objects (DAOs).

## 2. SQLite Constraint Management
- Never perform inserts or updates to the `customers` table without calling `DatabaseHelper.instance.ensureLegacyStreetAndAreaExists` first.
- Keep foreign keys active (`PRAGMA foreign_keys = ON`).

## 3. UI/UX and Theme Consistency
- All new UI pages must use `AppScaffold` instead of raw `Scaffold`.
- Custom cards, rows, or detail elements must inherit frosted glass styling via `GlassContainer`.
- Avoid solid background fills or hardcoded grey borders. Use curated, translucent colors with thin white border lines.
- Always use `InkRipple.splashFactory` for touch feedback animation.

## 4. Documentation Maintenance
- Update matching `.ai/` documentation files upon introducing database migrations, new features, or architectural adjustments.
