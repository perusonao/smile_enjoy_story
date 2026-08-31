---
id: SES-E2E-002
title: A dead end is actionable only after semantics stabilizes
scope: project
category: playwright
status: core-rule
confidence: high
observations: 3
last_verified: 2026-08-19
---

## Problem / Context

WebKit can expose temporary empty or non-actionable accessibility frames during
Flutter transitions, which were falsely reported as game dead ends.

## Evidence

`05f7f6e` introduced bounded empty-semantics recovery; `6061d66` generalized
it to non-empty no-action frames and added real-Playwright stability tests.
The rationale and distinctions are documented in `e2e/README.md`.

## Decision / Pattern

Poll boundedly for a meaningful/actionable changed frame. Report a dead end
only when the no-action snapshot remains stable; never hide a stable failure
behind an unbounded retry or a symptom-specific string allowlist.

## When to use

Semantics-driven Flutter E2E, WebKit failures, and auto-player recovery logic.

## When NOT to use

Do not use fixed sleeps as a substitute for observing semantics stability.

## Related files

`e2e/helpers/ses-player.ts`, `e2e/helpers/game-state.ts`,
`e2e/tests/ses-player.deadEndStability.spec.ts`.

## Related PR/commit

`05f7f6e`, `6061d66`.

## Regression protection

Dead-end stability spec and seeded WebKit/Chromium E2E.
