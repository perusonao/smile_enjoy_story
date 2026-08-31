---
id: SES-ARC-001
title: GameState is the UI truth; controller owns effects
scope: project
category: architecture
status: core-rule
confidence: high
observations: 3
last_verified: 2026-08-19
---

## Problem / Context

Gameplay changes must remain deterministic, serializable, and testable without
widgets while UI still needs persistence and rebuild notification.

## Evidence

`GameState` documents itself as the serializable single source of truth and
`GameEngine` returns new states. `GameController._apply` delegates mutations,
reconciles, notifies listeners, and autosaves. The same boundary is exercised
by engine tests and E2E. See `lib/game/models/game_state.dart`,
`lib/app/game_controller.dart`; architecture reinforced by `f3d4d5e`.

## Decision / Pattern

Put game rules in pure engines `GameState -> GameState`. Keep controller as the
UI-facing façade for state ownership, reconciliation, persistence, and
notifications. Widgets render and dispatch actions; do not make them another
state authority.

## When to use

New gameplay actions, saveable state, deterministic simulations, or regression
tests.

## When NOT to use

Do not force view-only animation or transient widget focus state into
`GameState` unless it affects gameplay or persistence.

## Related files

`lib/game/models/game_state.dart`, `lib/game/engine/game_engine.dart`,
`lib/app/game_controller.dart`.

## Related PR/commit

`f3d4d5e`, `a8d9479`.

## Regression protection

Engine/unit tests plus controller-mediated E2E paths; preserve immutable
`copyWith` transitions.
