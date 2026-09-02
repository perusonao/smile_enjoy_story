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

`.github/workflows/e2e.yml`, `.github/workflows/e2e-heavy.yml`, `e2e/playwright.config.ts`.

## Related PR/commit

`d9d4295` (PR #15). SES-CI-SPEED-1 (2026-09) split CI into Fast CI
(`e2e.yml`, chromium-only `smoke-e2e` job) and Heavy E2E (`e2e-heavy.yml`,
`e2e-heavy-chromium`/`e2e-heavy-webkit` jobs) — the per-browser job/runner
isolation this decision describes is preserved across both files.

## Regression protection

Separate per-browser workflow jobs and per-browser artifacts: `smoke-e2e`
(chromium) in `e2e.yml`; `e2e-heavy-chromium`/`e2e-heavy-webkit` in
`e2e-heavy.yml`.
