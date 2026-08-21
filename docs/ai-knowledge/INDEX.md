# S.E.S. AI Knowledge Base

This is a small router, not a standing prompt. Classify the task, find the
matching entry below, read only that entry, then verify it against the current
code and tests. Entries are historical evidence; current code and tests win.

## Lifecycle

`incident` → `candidate-pattern` → `verified-pattern` → `core-rule`.
Promotion requires independent evidence. `observations` counts evidence sources,
not repeated wording in one PR.

## Router

| ID | Category | Short description | Confidence | Path |
| --- | --- | --- | --- | --- |
| SES-ARC-001 | architecture | State is rendered from immutable GameState; controller owns effects | high | [entry](patterns/SES-ARC-001-state-and-controller-boundary.md) |
| SES-FIN-001 | finance | Immediate recruitment costs reduce cash exactly once | high | [entry](incidents/SES-FIN-001-immediate-expense-double-charge.md) |
| SES-FIN-002 | finance | Monthly cash movement uses an explicit month-start baseline | high | [entry](patterns/SES-FIN-002-monthly-cash-movement.md) |
| SES-FIN-003 | finance | Pending hires join payroll only at their start boundary | high | [entry](patterns/SES-FIN-003-pending-hire-payroll-boundary.md) |
| SES-SAVE-001 | persistence | Missing compatible fields migrate; incompatible schemas reset safely | high | [entry](decisions/SES-SAVE-001-schema-compatibility.md) |
| SES-PRO-001 | prologue | Reconcile loaded/mutated state to prevent tutorial dead ends | high | [entry](patterns/SES-PRO-001-prologue-reconciliation.md) |
| SES-SEL-001 | selection | An accepted interview offer must invalidate competing sales safely | medium | [entry](patterns/SES-SEL-001-offer-sales-exclusivity.md) |
| SES-MOR-001 | people | Morale and Trust are separate, bounded dimensions | high | [entry](patterns/SES-MOR-001-morale-trust-independence.md) |
| SES-UI-001 | flutter-ui | Capture NavigatorState before delayed callbacks | high | [entry](incidents/SES-UI-001-stale-build-context-navigation.md) |
| SES-UI-002 | flutter-ui | Dialog image headers must follow Dialog clipping/constraints | medium | [entry](patterns/SES-UI-002-dialog-image-clipping.md) |
| SES-E2E-001 | playwright | Flutter text entry needs real keystrokes, blur, and bounded retry | high | [entry](incidents/SES-E2E-001-flutter-text-entry-flake.md) |
| SES-E2E-002 | playwright | Treat transient semantics/no-action frames as unsettled, boundedly | high | [entry](patterns/SES-E2E-002-stable-dead-end-detection.md) |
| SES-E2E-003 | playwright | Test only real UI and retain replay artifacts | high | [entry](decisions/SES-E2E-003-real-ui-artifacts.md) |
| SES-CI-001 | github-actions | Run Chromium and WebKit on separate runners | high | [entry](decisions/SES-CI-001-browser-runner-isolation.md) |
| SES-CI-002 | github-pages | Deploy only the current main SHA from the same workflow chain | high | [entry](decisions/SES-CI-002-pages-deployment-chain.md) |
| SES-E2E-004 | playwright | Scope dialog controls to real dialog semantics | high | [entry](patterns/SES-E2E-004-dialog-semantics-scope.md) |

## Search hints

- Accounting, month close, cash, payroll: `SES-FIN-*`
- Save, migration, load/restart: `SES-SAVE-001`, `SES-PRO-001`
- Prologue, selection, offers, recovery: `SES-PRO-001`, `SES-SEL-001`
- Morale, Trust, welfare, retention: `SES-MOR-001`
- Flutter routes, dialogs, layout: `SES-UI-*`
- Playwright, WebKit, artifacts, flaky CI: `SES-E2E-*`, `SES-CI-001`
- Pages/replay workflow: `SES-CI-002`, `SES-E2E-003`
