---
id: SES-SAVE-001
title: Compatible missing save fields migrate; incompatible schemas reset safely
scope: project
category: persistence
status: core-rule
confidence: high
observations: 3
last_verified: 2026-08-19
---

## Problem / Context

Save shape evolves while existing players must not crash or be stranded.

## Evidence

`GameState` documents schema version 6 and the compatible missing
`foundingProgress` default. `a8d9479` added legacy `MonthlyClosing` migration
tests. Controller boot reconciles a loaded state.

## Decision / Pattern

For additive, semantically safe fields, provide explicit defaults/migration.
For an incompatible schema, let `SaveService` reset to a new game instead of
attempting an unsafe partial load. Reconcile after load.

## When to use

Every serialized model change or gameplay state repair.

## When NOT to use

Do not silently default a missing field when that invents a gameplay fact or
breaks accounting; make a migration or incompatible-version decision instead.

## Related files

`lib/game/models/game_state.dart`, `lib/game/models/monthly_closing.dart`,
`lib/game/persistence/save_service.dart`, `lib/app/game_controller.dart`.

## Related PR/commit

`a8d9479`, `f3d4d5e`.

## Regression protection

`test/game/monthly_closing_migration_test.dart` and load/reconciliation paths.
