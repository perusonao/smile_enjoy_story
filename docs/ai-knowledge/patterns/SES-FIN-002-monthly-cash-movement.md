---
id: SES-FIN-002
title: Monthly cash movement uses an explicit month-start baseline
scope: project
category: finance
status: core-rule
confidence: high
observations: 3
last_verified: 2026-08-19
---

## Problem / Context

Closing-only arithmetic can omit cash changes that happen before the close,
especially March-to-April transitions.

## Evidence

The plan specifies `cashAfter - cashBefore == monthCashMovement`. `a8d9479`
added robust `monthStartCash`/migration handling and tests in
`march_april_boundary_test.dart`, `monthly_closing_migration_test.dart`, and
`weekly_simulation_test.dart`.

## Decision / Pattern

Persist a month-start cash baseline and derive monthly movement from the
whole-month cash delta, rather than summing only selected closing rows.

## When to use

Monthly closing, dashboards, cash-flow reporting, and save migration.

## When NOT to use

Do not replace line-item profit/accounting calculations with this cash metric;
cash movement and profit serve different questions.

## Related files

`lib/game/models/game_state.dart`, `lib/game/models/monthly_closing.dart`,
`lib/game/engine/game_engine.dart`.

## Related PR/commit

`f3d4d5e`, `a8d9479`.

## Regression protection

Keep the whole-month delta invariant in deterministic boundary and migration tests.
