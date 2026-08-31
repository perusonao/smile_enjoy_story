---
id: SES-MOR-001
title: Morale and Company Trust are independent bounded dimensions
scope: project
category: people
status: verified-pattern
confidence: high
observations: 2
last_verified: 2026-08-19
---

## Problem / Context

People decisions need distinct employee sentiment and company confidence;
combining them erases meaningful consequences.

## Evidence

`Engineer` documents morale as independent from `companyTrust`. `MoraleEngine`
applies explicit deltas and clamps both values to 0..100; welfare and contract
decisions call it.

## Decision / Pattern

Keep Morale and Trust separate. Apply named, explicit deltas through the
engine and preserve bounds; do not use UI-only updates for either metric.

## When to use

Welfare, contracts, turnover, interview mismatch, and people-system work.

## When NOT to use

Do not infer a universal conversion between the two metrics.

## Related files

`lib/domain/models/engineer.dart`, `lib/game/engine/morale_engine.dart`,
`lib/game/engine/welfare_engine.dart`, `lib/game/engine/game_engine.dart`.

## Related PR/commit

Current code; Phase 3 plan preserves this behavior.

## Regression protection

Unit-test each decision's independent deltas and clamping.
