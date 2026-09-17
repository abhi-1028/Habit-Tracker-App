# Core data architecture

This version uses `LocalStorageService` as the single persistence layer for habits and profile data. `HabitStore` is the in-memory state layer and is the only place screens should mutate habits.

## Storage v2

Habit storage is a versioned JSON document in Hive. Version 2 persists pause history as well as completions, notes, schedules, and habit metadata. The loader remains backward-compatible with the previous unversioned list format and migrates it automatically on the next save.

## Important guarantees

- Pause history survives app restart.
- Completion notes are preserved when today's measurable progress changes.
- Completion writes are awaited before progress mutation methods finish.
- A malformed individual habit/pause does not discard all other valid data.
- The old duplicate `HabitDatabase` service has been removed; do not introduce a second persistence path.
