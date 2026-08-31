---
id: SES-UI-001
title: Delayed navigation callbacks must not re-resolve a stale BuildContext
scope: project
category: flutter-ui
status: verified-pattern
confidence: high
observations: 2
last_verified: 2026-08-19
---

## Problem / Context

An Upper Company Interview continuation callback captured a context that was
removed after game-state mutation, leading to a release null dereference and a
stranded route.

## Evidence

The reproduced root cause and fix are documented in `e2e/README.md`. The fix
captures `NavigatorState` before the delayed callback and checks `mounted`.

## Decision / Pattern

For callbacks that run after a state-changing async/route interaction, capture
the required `NavigatorState` while the context is valid; guard its mounted
state before use.

## When to use

Dialogs, pushed routes, result callbacks, and callbacks that mutate game state.

## When NOT to use

Do not treat this as a replacement for ordinary immediate `Navigator.of(context)`
calls where the context cannot become stale before use.

## Related files

`lib/ui/prologue/prologue_screen.dart`, `e2e/README.md`.

## Related PR/commit

Documented in the original E2E effort; commit history includes `f504e1e`.

## Regression protection

Founding-to-assignment E2E across fixed seeds.
