---
id: SES-CI-001
title: Chromium and WebKit E2E run on separate CI runners
scope: project
category: github-actions
status: core-rule
confidence: high
observations: 2
last_verified: 2026-08-19
---

## Problem / Context

Two mobile browser projects running with workers on the same two-core runner
competed for CPU and created CI instability.

## Evidence

`d9d4295` split the jobs after CI investigation. `.github/workflows/e2e.yml`
documents the CPU contention and preserves two workers only within each
single-browser job.

## Decision / Pattern

Keep browser engines in separate jobs/runners; merge their output only after
execution for replay packaging.

## When to use

Workflow or Playwright parallelism changes.

## When NOT to use

Do not collapse them simply to reduce YAML duplication without re-measuring
resource contention and artifact behavior.

## Related files

`.github/workflows/e2e.yml`, `e2e/playwright.config.ts`.

## Related PR/commit

`d9d4295` (PR #15).

## Regression protection

Separate `e2e-chromium` and `e2e-webkit` workflow jobs and per-browser artifacts.
