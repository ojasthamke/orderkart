# Project Changelog

## 2026-07-17
### Added
- Created permanent project brain and documentation vault in `.ai/` directory.
- Created `security.md`, `performance.md`, and `workflows.md` to document worker scoping encryption, SQLite WAL optimizations, P2P sync socket sequence, and dynamic checkout questions.

### Fixed
- Fixed customer saving exception in the worker app due to legacy foreign key checks on `customers.street_id` referencing empty `streets` tables (JIT constraint assertion added).
- Fixed worker provisioning package generation by query-serializing the unified `locations` table.
- Fixed SQLite database exception on the Worker Analytics & Performance screen by matching parameter count and arguments list length (reduced from 6 to 5 values).

## 2026-07-16
### Added
- Set up `InkRipple.splashFactory` globally for liquid press animations.
- Themed Elevated, Outlined, and Text buttons with glassmorphic translucency.
- Propagated Apple-style Glassmorphism throughout all remaining screens in the codebase.
