---
id: SES-FIN-003
title: Pending hires must not enter payroll before their start boundary
scope: project
category: finance
status: verified-pattern
confidence: high
observations: 2
last_verified: 2026-08-19
---

## Problem / Context

An accepted future hire can appear in the game before they are eligible for
salary, which makes HUD and month-end payroll easy to overstate.

## Evidence

The development plan makes the boundary explicit. `faf5a85` excluded the
future hire from March HUD totals; `f3d4d5e` added March→April accounting
coverage.

## Decision / Pattern

Model pending hire/start timing separately from active employment. Include the
employee in payroll only at the actual payroll/start boundary.

## When to use

Hiring, monthly salary, headcount summaries, and prologue transitions.

## When NOT to use

Do not hide a pending hire from all UI; their accepted status may still be
relevant as long as payroll semantics remain distinct.

## Related files

`lib/game/models/game_state.dart`, `lib/game/engine/prologue_engine.dart`,
`lib/game/engine/finance_engine.dart`, `test/game/march_april_boundary_test.dart`.

## Related PR/commit

`faf5a85`, `f3d4d5e`.

## Regression protection

Boundary tests should assert both March exclusion and April inclusion.
