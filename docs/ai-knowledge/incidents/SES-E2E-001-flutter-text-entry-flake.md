---
id: SES-E2E-001
title: Flutter Web form entry needs keystrokes, blur, confirmation, and bounded retry
scope: project
category: playwright
status: incident
confidence: high
observations: 1
last_verified: 2026-08-19
---

## Problem / Context

Playwright `fill()` raced Flutter Web's `TextInputConnection`; DOM value
success did not prove the Flutter controller received the setup value.

## Evidence

`e2e/README.md` records a CPU-throttled reproduction: `fill()` succeeded
2/10 while per-character input plus Tab succeeded 10/10. `f504e1e` changed
the harness only, with diagnostics and one bounded retry.

## Decision / Pattern

Use real sequential key input, confirm the field, blur the final field, wait
for the specific transition, and allow at most one bounded retry with useful
diagnostics.

## When to use

Flutter Web editable text under Playwright, especially critical submissions.

## When NOT to use

Do not generalize this to arbitrary DOM apps without first reproducing their
input model; do not add unbounded submit retries.

## Related files

`e2e/helpers/ses-player.ts`, `e2e/README.md`.

## Related PR/commit

`f504e1e`.

## Regression protection

Founding E2E plus action-trace diagnostics on failure.
