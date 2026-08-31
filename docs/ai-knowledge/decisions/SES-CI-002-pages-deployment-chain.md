---
id: SES-CI-002
title: Pages deployment is guarded in the same workflow chain by current main SHA
scope: project
category: github-actions
status: core-rule
confidence: high
observations: 2
last_verified: 2026-08-19
---

## Problem / Context

The former cross-workflow `workflow_run` deployment trigger never fired;
deploying a stale run could also roll Pages back over newer `main`.

## Evidence

`47645c7` unified E2E and deployment. Workflow comments record the absent
cross-workflow runs and show `check-latest`, same-run artifact packaging, and
a second check immediately before `deploy-pages`.

## Decision / Pattern

Keep build/deploy as dependent jobs in one workflow. Resolve the authoritative
main SHA and re-verify immediately before deployment; scope Pages/OIDC
permissions to build/deploy jobs.

## When to use

Pages workflow, deploy gating, permissions, or replay-artifact changes.

## When NOT to use

Do not make E2E failure green: artifacts may still be packaged, but test result
semantics remain independent from deployment policy.

## Related files

`.github/workflows/e2e.yml`, `e2e/scripts/check-latest-main.mjs`.

## Related PR/commit

`47645c7`, `a30da0f` (PR #7).

## Regression protection

Workflow's dual SHA checks and least-privilege job permissions.
