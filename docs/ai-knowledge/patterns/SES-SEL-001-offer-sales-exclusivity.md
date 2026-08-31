---
id: SES-SEL-001
title: Accepted interview offers must resolve competing sales safely
scope: project
category: selection-flow
status: candidate-pattern
confidence: medium
observations: 1
last_verified: 2026-08-19
---

## Problem / Context

One employee can have competing opportunities when an interview offer turns
into a proposal; leaving stale activity can create contradictory sales state.

## Evidence

`GameEngine.acceptInterviewOffer` validates the offer/project then creates a
proposal and changes employee sales status. Current implementation is the
evidence; no dedicated historical regression commit was found in the reviewed
history.

## Decision / Pattern

Before changing offer/proposal behavior, trace all active proposals, offers,
and employee status transitions and make cancellation/expiry explicit.

## When to use

Offer acceptance, project closure, proposal limits, and SelectionFlow changes.

## When NOT to use

Do not assume all applications are exclusive: inspect the current parallel
proposal rules first.

## Related files

`lib/game/engine/game_engine.dart`, `lib/domain/models/selection_flow.dart`,
`lib/game/models/game_state.dart`.

## Related PR/commit

Current-code observation only.

## Regression protection

Add a focused engine test before promoting this candidate pattern.
