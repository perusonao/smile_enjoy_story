---
id: SES-E2E-003
title: Real-UI E2E must not shortcut game state and must retain artifacts
scope: project
category: playwright
status: core-rule
confidence: high
observations: 3
last_verified: 2026-08-19
---

## Problem / Context

Headless simulations prove rules but cannot prove accessible UI navigation or
the player-visible recovery path.

## Evidence

`e2e/README.md` defines separate simulation, real-UI Playwright, and manual
play layers; it prohibits production debug APIs for the harness. The workflow
keeps videos/results even when runs fail, and replay packaging was added in
`e33ac21`.

## Decision / Pattern

Drive production UI through semantics, seed only existing deterministic engine
inputs, and retain result JSON, trace, screenshots, and video for diagnosis.

## When to use

Progression, navigation, visual/actionability, and failure recovery coverage.

## When NOT to use

Do not replace high-volume deterministic simulations with slow E2E.

## Related files

`e2e/README.md`, `e2e/helpers/`, `e2e/tests/`, `e2e/replay-viewer/`.

## Related PR/commit

`e33ac21`, `83f38c9`, `f504e1e`.

## Regression protection

CI artifact upload and replay package; scenario tests assert real UI outcomes.
