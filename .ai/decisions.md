# Decisions Registry

Significant architectural decisions recorded chronologically:

## Decision 1: Unified Locations Table (Migration 10)
- **Context**: Legacy database split locations into separate `areas` and `streets` tables, limiting hierarchy to Area > Street.
- **Decision**: Merged location structures into a single `locations` table with self-referencing `parent_location_id`, enabling deep-nested location nodes (e.g. Area > Sector > Road > Galli).
- **Consequence**: Maintained legacy `areas`/`streets` tables as read-only replicas to avoid breaking existing queries or foreign-key constraints on `customers` and `visits` tables.

## Decision 2: Apple-style Glassmorphism Visual Theme
- **Context**: App needed a premium, wow-factor look matching the Apple iPhone interface.
- **Decision**: Propagated translucent frosted containers (`GlassContainer`), customized app scaffold (`AppScaffold` with custom gradients), and added `InkRipple.splashFactory` globally.

## Decision 3: JIT Legacy Constraint Assertion
- **Context**: Worker devices provisioned without explicit `streets`/`areas` table rows crashed during customer creation due to legacy foreign key checks on `customers(street_id)`.
- **Decision**: Implemented `ensureLegacyStreetAndAreaExists` to JIT check and seed matching records in `streets` and `areas` tables prior to customer insertion/updates.
