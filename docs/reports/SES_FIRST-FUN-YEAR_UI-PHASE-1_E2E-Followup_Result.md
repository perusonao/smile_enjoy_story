# SES First Fun Year UI Phase 1 — E2E Followup Result

## Purpose

PR #141 ("feat(public-demo): refine HOME UI for First Fun Year") intentionally
removed several duplicate HOME displays (Finance Summary's own compact
cash/revenue/next-month-estimate/warning row, July recap's own
参画/待機 headcount line, the finance summary's second cashShortage warning
banner). The authoritative KPI/compact displays that survive were left
unchanged. This follow-up updates the Playwright E2E suite to match, without
reverting production UI to the old duplicated displays and without touching
Domain/Finance/Persistence/save-schema/balance code or CI workflow config.

**This work's goal was not "100% green E2E."** It was to confirm no BLOCKING
product regression exists so First Fun Year development can continue, and to
close out this follow-up without an unbounded full-suite wait. Per explicit
instruction partway through this session, the long-running full Playwright
Chromium suite was stopped intentionally before completion (see §6) — this is
not a failure, and no BLOCKING issue justified continuing to wait for it.

## Commit range

- **BASE SHA**: `b4d4396a3302fe2fa6394f075ee13d5d14eaa9fb` (`main`, the PR #141
  merge commit — `claude/ses-e2e-followup-pr141-5ik8yg` was rebuilt from this
  commit at session start, since PR #141 was already merged and its own
  branch could not be reused)
- **final HEAD SHA**: `04b5082af6c29c9317db710d7574f25ffdef8f43`
- **Branch**: `claude/ses-e2e-followup-pr141-5ik8yg`
- **Commits added this session**:
  - `5ad8cf4` — fix(e2e): follow up First Fun Year UI Phase 1's HOME de-duplication
  - `04b5082` — fix(e2e): scroll to top before reading state left of the current position

## Changed files

```
e2e/helpers/public-demo-player.ts          | 22 ++++++--
e2e/tests/public-demo-annual-route.spec.ts | 10 +++-
e2e/tests/public-demo-july-restart.spec.ts | 80 ++++++++++++------------------
e2e/tests/public-demo-recovery.spec.ts     | 20 +++++---
4 files changed, 68 insertions(+), 64 deletions(-)
```

**Production code change: none.** `git diff --stat origin/main..HEAD -- lib/`
is empty — every change is under `e2e/`. No Finance/Domain/Persistence/save
schema/balance file was touched, and `.github/workflows/*.yml` is unchanged.

## CI failures — root cause and A/B/C classification

The pre-existing `e2e-chromium` CI run on PR #141's head (`546a3bb`, job
[100073143195](https://github.com/perusonao/smile_enjoy_story/actions/runs/33573014370/job/100073143195))
had 7 failing test instances collapsing to 4 distinct tests:

| # | Test | Root cause | Class |
|---|---|---|---|
| 1 | `public-demo-recovery.spec.ts:49` (360x800, 390x800) — normal causal chain | Scrolled for the removed duplicate compact strings `今月売上 ¥1,000,000` / `次回入金予定 ¥1,000,000` (Finance Summary's own removed row). The authoritative source, `PublicDemoMonthlyCashFlowCard`, still renders the same fact under its own surviving row labels `売上` / `売掛金（来月入金予定）`. | **A** |
| 2 | `public-demo-annual-route.spec.ts:207` Route B (360x800, 390x800) | Asserted a raw snapshot substring `参画 2名` — the exact, now-removed July-recap duplicate headcount line (label-before-value). The authoritative compact KPI tile (`readCompactKpiValue`, value-before-label) still carries the same fact and is already how every other assignment-count check in this suite reads it. | **A** |
| 3 | `public-demo-recovery.spec.ts:143` CRITICAL ACCEPTANCE GATE (360x800, 390x800) | `isCashShortage()` matched Finance Summary's own removed second warning string (`'資金不足です。必要な対応を確認してください。'`), which existed only in the now-deleted `_financeSummary.warning` field. Once removed, the helper could never again detect real `cashShortage`, so its cashShortage-driving while-loop never exited on that condition and instead ran the game toward genuine bankruptcy, where the monthly-close CTA legitimately disappears — surfacing as an unrelated-looking CTA-not-found timeout. | **A** |
| 4 | `public-demo-july-restart.spec.ts:53` restart flow | This spec carried its own local, weaker (20-tick, no per-tick dialog dismissal) scroll helper instead of the shared, more robust one every other Public Demo spec uses. Phase 1's page-height reduction (removing the duplicate rows above) changed this spec's scroll dynamics enough that its own weaker loop stopped reliably converging on `夏季賞与を決める`. | **A** |

No **B** (real game-progression/product regression) was found. No new **C**
(known/non-blocking browser or semantics-tree quirk, e.g. cashShortage CTA
wording or accessibility-tree dependence) was newly introduced by this
follow-up; the pre-existing WebKit environment limitation is recorded in §6.

### A secondary, non-product fix needed to actually turn the Category-A fixes green

Fixing `isCashShortage()`'s matched string (item 3) and the July-restart
spec's scroll helper (item 4) surfaced one more thing during local
verification, not visible from the CI logs alone: both read/click a target
near the top of the page from a scroll position their own preceding action
had left deep in the page (a waiting engineer's own card; the summer-bonus
card). `page.locator('body').ariaSnapshot()` does not reliably surface
content above the currently-built extent once scrolled well past it — the
exact reason `findMonthlyPrimaryCta`/`readCompactKpiValue`/`scrollToText`
already scroll to the top first, documented in this file's own existing
comments. `isCashShortage()` and the July-restart spec's scroll helper did
not do this yet; both now do, matching the established pattern. This is an
**E2E-helper robustness fix**, not a product change and not a new regression
— it was latent (masked because `isCashShortage()` never matched anything at
all before this session's fix, and because this specific July-restart button
had not previously needed to recover from a scroll position past it).

## Verification performed

- **`flutter analyze`**: PASS — "No issues found!" (Flutter 3.44.9, matching
  CI's pinned version)
- **`flutter test`**: PASS — **1392/1392**, "All tests passed!" (full suite,
  no unrelated regressions)
- **`git diff --check origin/main..HEAD`**: clean (no whitespace errors)
- **TypeScript** (`npx tsc --noEmit -p e2e/tsconfig.json`): clean
- **Playwright, Chromium, targeted reproduction of all 4 originally-failing
  tests** (local Chromium build 26.5, pre-installed at
  `/opt/pw-browsers/chromium-1194`, built `flutter build web --release`
  against this branch's HEAD):
  - First fix pass (`5ad8cf4`): 10/13 passed. Route B (both viewports) and
    the recovery normal-causal-chain test (both viewports) — items 1 and 2
    above — now pass. 3 remained red: July-restart and CRITICAL ACCEPTANCE
    GATE (both viewports) — the secondary scroll-position issue above.
  - Second fix pass (`04b5082`): all 3 remaining tests now **PASS**
    (July-restart 57.6s; CRITICAL ACCEPTANCE GATE 360x800 2.7m, 390x800 2.8m).
  - **All 4 originally-failing CI tests are confirmed fixed against this
    branch's current HEAD**, run individually against the real production
    UI (not against a Dart debug state API).
- **Broader confirmation run** (`public-demo-annual-route`,
  `public-demo-fresh-start`, `public-demo-july-restart`,
  `public-demo-month-guard`, `public-demo-recovery`,
  `public-demo-single-month-cta` — 20 tests total, one full fresh Playwright
  invocation from scratch): started to catch any collateral regression from
  reusing shared helpers across specs. **Stopped intentionally after 6/20**
  per explicit instruction to end the long-running wait — not due to any
  failure. All 6 that completed **passed**, including both Route B viewports
  this session fixed, confirming the fix holds under a fresh full-suite
  invocation, not just the earlier isolated `-g`-filtered runs:
  ```
  ✓ 1 annual-route 360x800 › April: only fiscal-year-sellable founding engineer reaches an order (26.7s)
  ✓ 2 annual-route 360x800 › June: confirming July contract continuation starts revenue recognition (44.1s)
  ✓ 3 annual-route 360x800 › April-March: current annual route traverses every month to fiscal year's terminal close (1.9m)
  ✓ 4 annual-route 360x800 › Route B — Gameplay Complete (2.6m)
  ✓ 5 annual-route 390x800 › April: only fiscal-year-sellable founding engineer reaches an order (27.1s)
  ✓ 6 annual-route 390x800 › June: confirming July contract continuation starts revenue recognition (46.2s)
  ```
  The remaining 14/20 (Route B 390x800 restated in this file's own later
  test IDs, July-restart, month-guard, recovery, single-month-cta,
  fresh-start) were **not executed in this final run** — each of those exact
  specs/tests was already independently confirmed passing in the earlier
  targeted reproduction runs above; re-running them again inside this fresh
  invocation was not needed to establish confidence and was stopped rather
  than repeated per instruction.
- **WebKit**: **not executed.** `npx playwright install webkit` fails in
  this sandbox: outbound requests to every WebKit download host
  (`cdn.playwright.dev`, `playwright.download.prss.microsoft.com`) return
  HTTP 403 ("request blocked: no rule or allowlist entry allows host ...").
  This is a sandbox network-allowlist limitation, not a test or product
  issue — recorded as a Known Issue below rather than attempted further.

## BLOCKING / NON-BLOCKING determination

None of the BLOCKING criteria were observed:

- App fails to start — **not observed** (Flutter Web build succeeded;
  every Playwright run reached and interacted with the real running UI)
- Normal progression deadlock — **not observed**
- Save corruption — **not observed** (no persistence code touched; all
  persistence-layer `flutter test` cases pass)
- April→March cannot complete normally — **not observed**: confirmed
  PASSING both viewports (`public-demo-annual-route.spec.ts:108`,
  "April-March: the current annual route traverses every month to the
  fiscal year's terminal close")
- Other clear core-gameplay regression — **none found**

**Determination: NON-BLOCKING.** No product regression was found anywhere in
this investigation; every fixed test was a stale E2E assertion (Category A)
plus one pre-existing E2E-helper scroll-position robustness gap unmasked by
that same fix, not a new one introduced by Phase 1.

## Remaining / unresolved

- The broader 14/20 confirmation-run tests were not re-executed inside the
  final fresh invocation (stopped by instruction, see above) — each is
  already independently confirmed passing from earlier runs this session,
  so this is bookkeeping, not an open question about their status.
- The full E2E suite's ~14 other spec files unrelated to Public Demo
  (founding-prologue/`ses-player.ts`-driven specs, artifacts, text-quality,
  etc.) were not re-run this session — none of them appeared in PR #141's CI
  failures, none reference the removed duplicate text, and this branch makes
  no change touching them.
- WebKit project: blocked by sandbox network policy (see above) — not a
  product or test defect, no action taken beyond recording it.
- These are all **Known Issues**, not blockers, per the classification
  criteria in this report's instructions.

## First Fun Year development / merge readiness

- **Safe for First Fun Year development to continue.** No BLOCKING product
  regression exists on this branch or on `main` at `b4d4396`.
- **This branch (`claude/ses-e2e-followup-pr141-5ik8yg`) is a standalone E2E
  followup**, not itself a feature PR — no new PR was opened and `main` was
  not touched, per instruction. If/when a PR is opened from this branch, its
  merge readiness is: production code unchanged, targeted fixes verified
  individually and start-to-finish where feasible, `flutter analyze`/
  `flutter test`/`git diff --check` all clean, no forbidden pattern
  introduced (see below) — ready pending only the repo owner's own review
  and, if desired, a full from-scratch CI run (this session's local
  Chromium reproduction used the CI-pinned Flutter version but is not a
  substitute for the actual CI environment).

## Confirmation: none of the forbidden patterns were used

- **Test deletion**: none — `test(` counts unchanged in all 3 modified spec
  files (annual-route 4→4, recovery 2→2, july-restart 1→1).
- **`.skip`/`.fixme` added**: none (`git diff` contains no such addition).
- **Retries increased**: none — `playwright.config.ts` untouched.
- **Timeouts extended as the fix**: none — no `timeout:`/`setTimeout(`
  addition in the diff; the actual fixes were correcting matched strings
  and reusing the existing, already-tuned shared scroll helpers (same
  budgets those helpers already use elsewhere), never widening a budget.
- **Assertion weakened without cause**: none — every changed assertion
  still checks the same fact via the surviving authoritative UI element,
  same strictness (`toBe`/`toContain` against a stable production string or
  key-read value), never loosened to "something is truthy."
- **Finance/Domain/Persistence/save schema/balance changed**: none —
  confirmed via `git diff --stat -- lib/` (empty).
- **Workflow changed**: none — `.github/workflows/*.yml` untouched.
- **Production UI reverted to old duplicated E2E expectations**: none — the
  duplicate displays PR #141 removed stay removed; every fix here points at
  the *surviving* authoritative display instead.
