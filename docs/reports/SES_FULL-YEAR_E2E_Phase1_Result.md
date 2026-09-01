# SES Full-Year E2E Phase 1 Result

## Status

**DONE — test-infrastructure only, zero production code changes, all required local tests pass.**

This establishes a maintainable Public Demo-specific Playwright baseline that
answers: *"Can the currently implemented Public Demo traverse its intended
annual lifecycle (April→March) without an unintended dead end?"* — before any
Late-Year Recovery Loop work exists. It describes what `main` actually does
today; it does not implement or assert any future gameplay feature.

This work is isolated from PR #136 and Issue #119: the branch was reset onto
the latest `origin/main` (its prior single commit was already merged into
main under a different PR), no code from PR #136 was inspected or copied,
and the current-`main` SkillSheet screen was tested as-is.

## Base SHA

`25a2e9b6b401794090151cc86006e433c8d9a789` (`origin/main`, "Merge pull
request #135 from perusonao/claude/issue-118-single-monthly-cta-f3trqr").

The branch's prior commit (`f4ca78f`, "Phase 0A/0B: SES domain models and
random generators") was confirmed via `git merge-base` to already be an
ancestor of `origin/main` — i.e. already merged under a separate PR — so per
the session's own already-merged-branch instructions, the branch was reset
to `origin/main` (`git checkout -B <branch> origin/main`) before any Phase 1
work began, rather than stacked on that stale history.

## Final HEAD

`<filled in by the commit that adds this report — see the PR's head commit>`.

## Current Public Demo E2E Architecture

Confirmed by reading `e2e/README.md`, `e2e/playwright.config.ts`, and every
existing `e2e/tests/public-demo-*.spec.ts` file: this repository already runs
**two independent E2E stacks** against two independent screens/state
machines, and they share no runtime state:

| Stack | Screen / engine | Helper | Month model |
|---|---|---|---|
| Founding Prologue auto-player | `PrologueScreen`/`GameEngine` | `e2e/helpers/ses-player.ts`, `game-state.ts` | weeks (`prologueWeek`) |
| Public Demo | `PublicDemo01PlaceholderScreen`/`PublicDemoAggregate` | *(none, until this Phase — actions were duplicated per-spec)* | internal months 4-15 = April-March (`publicDemoMonthLabel`) |

Before this Phase, three Public Demo specs
(`public-demo-fresh-start.spec.ts`, `public-demo-july-restart.spec.ts`,
`public-demo-single-month-cta.spec.ts`) each hand-rolled their own
scroll-to-button / dialog-confirm logic. This Phase extracts and hardens
that duplicated logic into one helper, without changing any of those three
specs' own behavior (all three still pass unmodified — see "Existing
Regression Coverage").

## Helper Added

`e2e/helpers/public-demo-player.ts` — Public Demo-specific, deliberately
**not** a general framework and **not** a reuse of `ses-player.ts` (different
screen, different state machine, different month model; the two must not be
mixed, per this file's own header doc). Exposes:

- `openPublicDemo`, `snapshot` — open the route, read the live ARIA snapshot.
- `assertFreshStartInvariants`, `assertCalendarMonth` — fresh-start / month
  checkpoints.
- `scrollToButton`, `clickButton`, `waitForStableFrame` — safe scrolling +
  click, consolidating the near-identical `clickScrollableButton`/
  `scrollToButton` helpers that were previously duplicated in
  `public-demo-july-restart.spec.ts` and `public-demo-single-month-cta.spec.ts`.
- `dismissDialogIfPresent`, `waitAndDismissDialog` — stable dialog handling.
  This is a genuine robustness improvement the existing specs didn't need:
  several Public Demo actions (`ei()`/`ci()`/`april()`/order acceptance)
  `await` an event-image precache **before** `showDialog`, so a follow-up
  dialog can appear a tick after the triggering click returns; `clickButton`
  now absorbs that gap for every action, bounded and short-circuiting fast
  on the (common) no-dialog path so it doesn't cost real test time — see
  "Remaining Risks" for the tuning trade-off this made.
- `MONTHLY_PRIMARY_CTA_PATTERN`, `findMonthlyPrimaryCta`,
  `closeMonthlyPrimaryCta` — the canonical monthly CTA
  (`Key('public-demo-monthly-primary-cta')` in production;
  `PublicDemo01PlaceholderScreen._monthlyPrimaryAction`), matched by a
  pattern covering every month's current label (`Ｘ月を終了して(次月)へ` /
  `３月を終了して第１期を完了`) instead of one literal string per month, and
  never a legacy dash-arrow (`終了→`) control (Issue #118 already removed
  those).
- `restartFromApril` — the "テスト用操作" reset flow.
- `sellFoundingEngineerInApril`, `confirmJulyContinuation`,
  `decideNoSummerBonus` — the minimal, deterministic gameplay actions
  Phase 1's own annual route needs (see below).
- `isFinanciallyTerminal`, `readCashSummaryLine` — terminal-state /
  cash-checkpoint reads.

## Current Annual Route

Investigated by reading `lib/game/public_demo/*.dart` (all deterministic —
no `Random` anywhere in this game's domain layer, confirmed by grep) and then
empirically verified by driving the actual built `build/web` app with a
throwaway Playwright script before writing any test:

- Of the two founding engineers, only **佐藤 健** (`eng-01`, April
  `actualCapability` 78) clears
  `PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement` (60) in April.
  **鈴木 葵** (`eng-02`, capability 52) cannot begin field sales **at all**
  this fiscal year — `public_demo_01_placeholder_screen.dart`'s own comment
  on `readyForFieldSales`/the field-sales-lock card is explicit that the
  founding engineers' sales-stage buttons render only in their April join
  month, and "no later month offers this action again, no matter how much
  further capability training raises" it. This is deliberate, current,
  documented behavior — not a bug this harness works around.
- That caps this fiscal year's revenue capacity at **one** assigned engineer
  (¥500,000/month, `PublicDemoRevenue.ratePerAssignedEngineer`) against
  **fixed** monthly costs of ¥800,000 (`PublicDemoSalary.baselineMonthlyExpenses`
  = 佐藤 ¥300,000 + 鈴木 ¥250,000 + admin ¥200,000 + fixed ¥50,000) — 鈴木's
  salary is dead weight for the entire fiscal year under this route.
- `PublicDemoWorkflowState.assignedEngineerIds(month)`'s own doc confirms
  that **from July onward, revenue counts an assignment only once its
  `nextOrderStatus` is `accepted`** — a one-time June decision
  (`7月分の発注を確認` → `受注する`), not a monthly renewal. Skipping it (as
  the pre-existing `public-demo-july-restart.spec.ts` route does, since that
  spec never drives the sales pipeline at all) leaves revenue at ¥0 for the
  rest of the year even though 佐藤 was ordered in April.

**The smallest legitimate current route Phase 1 exercises:**

1. April: run 佐藤's full sales pipeline (SkillSheet → 営業開始 → 案件紹介 →
   上位会社面談 → 客先面談 → 受注).
2. May, June: close ordinarily.
3. June: confirm July contract continuation (`7月分の発注を確認` →
   `受注する`) — the one-time decision that carries revenue into July.
4. July: decide "no summer bonus" (`なし`), matching the existing
   `public-demo-july-restart.spec.ts` route.
5. August-February: close each ordinary month
   (`PublicDemoMonthlyClose.closeOrdinaryMonth`, one shared transition).
6. March: close the fiscal year.

This route **genuinely reaches and completes the March close** — every
month's canonical CTA is clickable, every dialog resolves, there is no
dead-end/stuck screen anywhere in the traversal. Per this task's own
explicit instruction, this route was **not falsified to force a "success"**:
under it, cash never recovers (¥500,000/month revenue vs. ¥800,000/month
fixed cost is structurally unable to average non-negative for a full fiscal
year from this starting cash), so the March close's real, deterministic,
current outcome is **bankruptcy** (`PublicDemoFinancialStatus.bankruptcy`).
That is recorded as the baseline fact this Phase establishes — not a false
success and not a soft-lock/dead-end bug.

## Monthly Checkpoints

Matrix for `tests/public-demo-annual-route.spec.ts`'s third scenario (the
full April→March traversal), current `main`, this route:

| Month | Current Action | Automated Check | Result |
|---|---|---|---|
| April | Open fresh start; sell 佐藤 (SkillSheet→営業→紹介→上位面談→客先面談→受注) | `assertFreshStartInvariants`, `assertCalendarMonth(4)`, snapshot contains `翌月参画予定` for 佐藤 and the field-sales-lock message for 鈴木 | ✅ reaches ordered |
| May | Close via canonical CTA | `assertCalendarMonth(5)` | ✅ |
| June | Close via canonical CTA; confirm July continuation | `assertCalendarMonth(6)`; June checkpoint asserts May's cash-flow line shows `売上 ¥500,000` | ✅ revenue recognized |
| July | Decide "no summer bonus"; close via canonical CTA | `assertCalendarMonth(7)` (before close), then `(8)` after | ✅ |
| August | Close via canonical CTA | `assertCalendarMonth(8)` | ✅ |
| September | Close via canonical CTA | `assertCalendarMonth(9)` | ✅ |
| October | Close via canonical CTA | `assertCalendarMonth(10)` | ✅ |
| November | Close via canonical CTA | `assertCalendarMonth(11)` | ✅ (cash shortage warning appears on-screen around here; not asserted as pass/fail, only later at the terminal check) |
| December | Close via canonical CTA | `assertCalendarMonth(12)` | ✅ |
| January | Close via canonical CTA | `assertCalendarMonth(1)` | ✅ |
| February | Close via canonical CTA | `assertCalendarMonth(2)` | ✅ |
| March | Close via canonical CTA (fiscal-year close) | `isFinanciallyTerminal(page)` must be `true`; snapshot must contain `最終決算月: 3月` and the `4月からやり直す` reset control | ✅ reaches and completes fiscal-year close; terminal = bankruptcy (current, documented) |

Each month above is its own `test.step` in the spec, so a future regression
in any single month's transition names exactly which month and which action
failed (per this task's own diagnosability requirement), independent of the
smaller, faster April-only and June-only scenarios that isolate those two
checkpoints on their own.

## Terminal State

At the March close, `financialStatus` resolves to
`PublicDemoFinancialStatus.bankruptcy` (the game entered March already in
the one-close `cashShortage` grace period — visible on-screen from
November onward in this route — and March's own close still produced
negative cash). The UI's `Key('public-demo-bankruptcy-card')` renders "倒産
このプレイスルーは終了しました。", the canonical monthly CTA disappears
(`isCloseBlocked`), and the pre-existing "テスト用操作 → 4月からやり直す"
reset control remains available and functional (confirmed reachable in the
final snapshot). No dead-end, no uncaught error, no stuck screen.

## Current vs Future Coverage

**Asserted (current, implemented):** annual month-label progression
April→March; the canonical monthly CTA's uniqueness/reachability at both
required viewports; 佐藤's April sales pipeline; June's one-time July
continuation decision and its revenue effect; July's bonus decision; the
March fiscal-year close and its current bankruptcy outcome; the reset
control's continued availability after a terminal close.

**Explicitly NOT asserted (future-only; do not exist on `main` today):**

- Late-Year Recovery Loop
- Jul-Feb waiting-engineer re-sales (鈴木 or any future waiting engineer)
- An enhanced year-end result screen beyond the current 倒産/年度完了 cards
- Future Sep-Feb management events
- A future HOME redesign

These are documented here as **future test lanes only** — see "Recommended
Phase 2".

## Existing Regression Coverage

All three pre-existing Public Demo specs still pass, unmodified, against
this branch:

- `public-demo-fresh-start.spec.ts`
- `public-demo-july-restart.spec.ts`
- `public-demo-single-month-cta.spec.ts` (both 360px and 390px)

## Production Code Impact

**NONE.** `git diff --stat` against `origin/main` touches exactly two new
files, both under `e2e/`:

```
e2e/helpers/public-demo-player.ts          | 342 +++++++++++++++++++++++++++++
e2e/tests/public-demo-annual-route.spec.ts | 183 +++++++++++++++
2 files changed, 525 insertions(+)
```

No file under `lib/` was changed. No production blocker was discovered that
would have required stopping — the current annual route is legitimately
reachable end-to-end (see "Current Annual Route"); its bankruptcy outcome is
a real, deterministic, already-intended finance model result
(`FINANCE-FAILURE-1A+1B`), not a soft-lock or defect.

## Domain Impact

NONE. No file under `lib/game/`, `lib/domain/`, or any other domain
directory was touched.

## Finance Impact

NONE. `PublicDemoSalary`, `PublicDemoRevenue`,
`PublicDemoFinancialStatus`, `PublicDemoMonthlyClose`, and every other
finance file were only *read*, never edited.

## Persistence Impact

NONE. `PublicDemoState.toJson`/`fromJson`, `PublicDemoAggregate.toJson`/
`fromJson`, and `PublicDemoWorkflowState.toJson`/`fromJson` were not
touched.

## Tests

### Flutter

```
flutter analyze   → No issues found! (ran in 13.9s)
flutter test      → All tests passed! (1324 tests)
```

Both run against this branch (Flutter 3.44.9, the version this repo's own
CI workflows pin) before any Playwright work began, confirming the branch
starts from a genuinely clean baseline.

### Playwright — full local Chromium suite

`npx playwright test --project=mobile-chromium` (all 71 existing + new
tests, both viewports where applicable): **71 passed** in 9.6 minutes,
including:

- The 3 new `public-demo-annual-route.spec.ts` scenarios × 2 viewports (6
  tests) — the slowest single file (5.4m total), expected for a full
  12-month traversal run twice.
- All 3 pre-existing Public Demo regression specs, unmodified.
- Every other existing spec in the suite (Founding Prologue auto-player,
  artifacts/allowlist unit tests, `game-state` parsing, seeds, dead-end
  stability, text quality, etc.) — confirming this Phase's helper file
  introduced no cross-suite regression.

## Chromium

Ran locally (pre-installed Chromium at `/opt/pw-browsers/chromium`, pinned
via `SES_E2E_CHROMIUM_PATH` since this sandbox's `@playwright/test`
resolved to a newer minor version than that pre-installed browser revision
targets — no browser download was performed, matching the environment's own
"do not run `playwright install`" guidance). Both `mobile-chromium`
360×800 and 390×800: **all green** (see "Tests" above).

## WebKit

**Not available in this sandbox** (`/opt/pw-browsers` has no WebKit
revision, and this environment has no network access to Playwright's WebKit
download host — consistent with prior findings recorded in `e2e/README.md`'s
own "WebKit note" sections). Per this task's explicit instruction, WebKit
was not skipped or disabled anywhere in repository configuration —
`playwright.config.ts`'s `mobile-webkit` project is untouched, and
`.github/workflows/e2e.yml`'s `e2e-webkit` job (which installs and runs real
WebKit) will exercise these same new tests unmodified on the PR. No retries
were added anywhere to paper over a WebKit-specific timing issue; none was
observed locally to paper over in the first place.

## Coverage Gaps

- WebKit-specific timing (Flutter Web semantics attach/settle timing is
  historically the more fragile browser per this repo's own README
  findings) is unverified until CI runs it.
- The annual route only exercises the **one** legitimate current path that
  reaches a fiscal-year-terminal outcome; it does not exercise:
  - The fully passive "close every month, sell nobody" route (would bankrupt
    materially earlier than March — not driven here, since Phase 1's
    purpose is annual *reachability*, not an exhaustive failure-mode survey;
    a dedicated Failure-lane test is a natural, small Phase 2 addition).
  - Recruitment-media-driven hiring during April-August (a legitimate
    current action this Phase's route deliberately does not need, to keep
    the baseline the *smallest* legitimate route).
  - The raise-request flow available from month 7 onward.
- No Persistence-lane coverage yet (save/restore round-trip through a
  partial-year Public Demo state) — flagged as a future lane per the task
  brief, not implemented here.

## Diff Audit

```
$ git diff --check
(clean — no output)

$ git diff origin/main...HEAD --stat
 e2e/helpers/public-demo-player.ts          | 342 +++++++++++++++++++++++++++++
 e2e/tests/public-demo-annual-route.spec.ts | 183 +++++++++++++++
 2 files changed, 525 insertions(+)
```

Expected production impact: **NONE** — confirmed. Domain: **NONE** —
confirmed. Finance: **NONE** — confirmed. Persistence schema: **NONE** —
confirmed.

## Remaining Risks

- `waitAndDismissDialog`'s bounded-polling budget (≈600ms grace before
  giving up on a click that never opens a dialog; 4s budget specifically
  for the canonical-CTA close, since April's new-applicant dialog depends on
  an awaited image precache) was tuned empirically against this sandbox's
  own (slow, software-rendered, single-core-contended) headless Chromium.
  A materially slower or faster CI runner could need this retuned — this is
  a timing constant, not a logic gap, and is isolated to
  `e2e/helpers/public-demo-player.ts`'s two named constants.
- The annual route's full traversal (~1.3-1.5 minutes per viewport locally)
  is the slowest spec in the suite. `test.setTimeout(180_000)` gives ample
  local headroom (observed 1.3-1.5m); CI capacity was not independently
  verified in this session — worth watching on the first real CI run.

## Recommended Phase 2

Extend `public-demo-player.ts` with small, named helpers per lane (following
this Phase's own precedent — never a generic action-runner) as each becomes
real:

- **Smoke**: already covered by the existing fresh-start spec; no new work
  needed.
- **Gameplay**: recruitment-media hiring flow, raise requests.
- **Finance**: a dedicated cash-flow-precision spec (this Phase only checks
  the cash-summary line's presence/content at named checkpoints, not a full
  month-by-month numeric reconciliation — Dart unit tests already own exact
  arithmetic correctness).
- **Failure**: the fully passive "sell nobody" route, to record how much
  earlier bankruptcy currently arrives without any sales action.
- **Recovery**: re-run this exact same annual-route baseline once the
  Late-Year Recovery Loop lands, and diff its terminal outcome against this
  report's recorded bankruptcy result — that diff *is* the Recovery Loop's
  acceptance check.
- **Persistence**: save/restore round-trip mid-fiscal-year.

## Merge Readiness

**Ready.** Test-infrastructure only; zero production/domain/finance/
persistence changes; clean `git diff --check`; all local Flutter and
Chromium Playwright tests green (existing + new); WebKit deferred to PR CI
per this task's own instruction (never skipped/disabled). No production
blocker was found or worked around.
