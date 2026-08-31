---
id: SES-FIN-001
title: Immediate expenses must not be charged twice
scope: project
category: finance
status: core-rule
confidence: high
observations: 3
last_verified: 2026-08-19
---

## Problem / Context

Recruitment costs paid immediately were also at risk of being included in the
month-end cash deduction, causing a cash double charge.

## Evidence

The Phase 2 plan names the invariant and the March boundary suite. Follow-up
commits `e0b67b0` and `a8d9479` changed recruitment accounting and closing
semantics; `test/game/march_april_boundary_test.dart` protects the boundary.

## Decision / Pattern

Record the expense for accounting/profit reporting, but deduct cash at exactly
one event: payment time for immediate expenses. Month-end must report it
without deducting it again.

## When to use

Any new immediate cost, closing calculation, or expense breakdown.

## When NOT to use

Do not apply this as a shortcut for accrued costs that have not yet affected
cash; model their payment boundary explicitly.

## Related files

`lib/game/engine/game_engine.dart`, `lib/game/engine/prologue_engine.dart`,
`lib/game/models/monthly_closing.dart`, `test/game/march_april_boundary_test.dart`.

## Related PR/commit

`f3d4d5e`, `e0b67b0`, `a8d9479` (PRs #11 and #13).

## Regression protection

Assert cash delta and closing line items together at the March→April boundary.
