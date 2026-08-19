---
id: SES-PRO-001
title: Reconcile prologue progression from durable state to preserve recovery
scope: project
category: progression
status: core-rule
confidence: high
observations: 3
last_verified: 2026-08-19
---

## Problem / Context

Tutorial flags or old saves can lag real achievements and strand a player on an
already-passed step.

## Evidence

`GameController` reconciles after load and every mutation. Its comments cite
the prologue repair ordering; `PrologueEngine` contains reconciliation and
recovery paths. `f3d4d5e` introduced related ghost-transition fixes.

## Decision / Pattern

Derive/reconcile progression from durable game facts at one central boundary.
Every negative outcome must leave an actionable recovery path rather than
requiring the prior exact success sequence.

## When to use

Prologue, beginner milestones, load migration, and failure-recovery changes.

## When NOT to use

Do not infer hidden player choices that are not represented in durable state.

## Related files

`lib/app/game_controller.dart`, `lib/game/engine/prologue_engine.dart`,
`lib/game/engine/progression_engine.dart`, `e2e/tests/failure-recovery.spec.ts`.

## Related PR/commit

`f3d4d5e`, `f21ca9c`.

## Regression protection

Failure-recovery E2E and deterministic prologue engine/widget tests.
