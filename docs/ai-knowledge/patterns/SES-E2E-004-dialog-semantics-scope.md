---
id: SES-E2E-004
title: E2E dialog controls must be scoped to real dialog semantics
scope: project
category: playwright
status: verified-pattern
confidence: high
observations: 2
last_verified: 2026-08-19
---

## Problem / Context

A generic close-list selector could dismiss the wrong control when Flutter's
semantics tree contains matching text outside the intended modal.

## Evidence

`91e44fb` scopes dismissal to `dialog`/`alertdialog` semantics, updates parser
coverage, and adjusts affected real-UI specs.

## Decision / Pattern

Locate modal actions through their semantic dialog container, then interact
with the control inside it. Extend ARIA parsing tests when Flutter's snapshot
shape changes.

## When to use

Any Playwright modal/dialog interaction or accessibility parser change.

## When NOT to use

Do not use broad text-only selectors when the same label can exist in page
content or multiple overlays.

## Related files

`e2e/helpers/game-state.ts`, `e2e/helpers/beginner-mode-player.ts`,
`e2e/tests/game-state.ariaParsing.spec.ts`.

## Related PR/commit

`91e44fb`.

## Regression protection

ARIA parser unit tests and affected Fit/Beginner Mode E2E specs.
