# SES Issue #119 Month Guard — Remaining Scope Implementation Result

## Status

Complete. Both PLAYTHROUGH BLOCKER items named in the task are resolved.
`flutter analyze`: clean. `flutter test` (full suite): all green (see
[flutter test](#flutter-test) for the exact count). `git diff --check`:
clean.

## Base SHA

`79c03122a18330db40ca21dd54e59174a7bf4e0f` (origin/main, "Merge pull
request #143 from perusonao/claude/ses-ci-speed-optimization-6w4hl0"). The
task's designated branch (`claude/issue-119-month-guard-ht6s5w`) existed
locally as a stale Phase-0 branch (far behind main, no unmerged work); per
the task's "最新mainを取得してから作業すること" instruction it was reset to
this exact `origin/main` HEAD before any work began.

## Branch

`claude/issue-119-month-guard-ht6s5w`

## Commit SHA

See the `docs:` commit that adds this report — this file is committed
together with the implementation on this branch. (Filled in at push time;
see the end-of-turn summary for the exact SHA.)

## Scope

Issue #119's remaining scope only — the two items the First Fun Year
month-by-month UX audit marked as PLAYTHROUGH BLOCKER, on top of PR1's
already-merged July-only required guard (`ef58800`, PR #137):

1. Non-July months could close with important, already-legal,
   already-on-screen work left untouched, with **no warning at all**.
2. During cash shortage, the purely-informational `資金不足を確認` card
   permanently occupied HOME's one recommended-action slot, so a genuinely
   reachable Recovery action (`案件へ復帰`) was never surfaced there —
   worse, it was never surfaced *at all*, cash shortage or not, because
   nothing wired months 7-14's waiting-engineer pipeline into the
   recommended-action authority in the first place.

No HOME redesign (Phase 2, #144, is untouched — no file under
`lib/presentation/home/widgets/` or `lib/presentation/home/home*.dart` was
touched), no new gameplay task, no Finance/Persistence/save-schema/balance/
month-close calculation change, no test deletion, no skip/fixme, no
retry/timeout-only fix, no assertion weakening.

## Root Cause

**Blocker 1.** `PublicDemo01PlaceholderScreen.closeOrdinaryMonth()`
(August through March — `lib/ui/public_demo/
public_demo_01_placeholder_screen.dart`) called
`PublicDemoAggregate.closeOrdinaryMonth` unconditionally. Unlike July
(which PR1 already gated on `PublicDemoMonthGuard`'s one required rule),
this shared handler for every other closable month had **no Month Guard
check of any kind** — not even the `recommended`/informational
distinction PR1's own design already anticipated (`PublicDemoMonthGuardLevel`
had only `required`).

**Blocker 2.** Two compounding gaps:

* `_recommendedActionCandidates` (the single existing HOME
  recommended-action authority, `home_recommended_action.dart` +
  `public_demo_01_placeholder_screen.dart`) never emitted a candidate for
  months 7-14's waiting-engineer sales pipeline at all — including the
  `案件へ復帰` (Recovery) button, which only ever rendered on the raw
  employee card, never through HOME. So a genuinely outstanding Recovery
  step was invisible to the one "what should I do next" affordance
  regardless of financial state.
* Even once wired in, `HomeRecommendedActionKind.cashShortageResponse`'s
  design-table priority (P0, "outranks everything") meant the purely
  informational shortage card would still permanently outrank it the
  instant cash shortage hit — the informational card can be shown
  indefinitely (nothing about it resolves), while the actionable step it
  implicitly points toward stayed buried below the fold, never once named
  as *the* recommended action.

## Implementation

### Central classification (domain): `lib/game/public_demo/public_demo_month_guard.dart`

* Added `PublicDemoMonthGuardLevel.recommended` alongside PR1's `required`.
* Added `PublicDemoMonthGuardCandidate {id, actionName}` — the caller
  hands in already-classified, already-legal outstanding actions (no HOME
  type, no domain type — two primitives), so this file's "no dependency on
  `game/`/`presentation/` types" contract is unchanged.
* `PublicDemoMonthGuard.evaluate(...)` gained an optional
  `outstandingRecommendedActions` parameter (default `const []`, so PR1's
  own callers/tests are unaffected): each candidate becomes one
  `recommended`-level `PublicDemoMonthGuardItem`, message-formatted here
  (`'$actionName が未対応です。'`) — the one place that decides the wording.
  July's required rule is untouched.

### Central classification (presentation): `lib/presentation/home/models/home_recommended_action.dart`

* Added `HomeRecommendedActionKind.informational` (`bool`, default
  `false`) — `true` for exactly `cashShortageResponse`. This is the single
  place that decides "is this kind a mere status check, never a mutating
  action" — the owner screen consults it (never reimplements it) before
  building `PublicDemoMonthGuardCandidate`s.
* Added `HomeRecommendedActionKind.recoveryAssignment`
  (`presentationPriority: -1`, `ctaLabel: '案件へ復帰'`,
  `headline: '{name}を案件へ復帰させる'`) — the **one** deliberate, documented
  exception to "P0 outranks everything": it is the sole kind ranked above
  `cashShortageResponse`, precisely because the informational card must
  never permanently cover a real, reachable, mutating Recovery step.
  `selectHomeRecommendedAction` needed no code change — the existing pure
  numeric-priority selector already resolves this correctly once the
  priority itself encodes the exception.

### Owner wiring: `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`

* `_recommendedActionCandidates` now also emits every economically-waiting
  engineer's sales-pipeline candidate for months 7-14 (mirroring the
  `ec(i, showTrainingCard: false)` render site's own filter verbatim —
  `!workflow.assignedEngineerIds(month: s.month).contains(e.id)`).
* `_addEngineerStageCandidate`'s `ordered`-stage branch (previously
  "no button, no candidate") now emits `recoveryAssignment` when
  `PublicDemoRecoveryEligibility.isEligible` holds — the exact authority
  the `案件へ復帰` button itself already re-checks before acting. Calling
  it unconditionally (including from April/June's own emission sites) is
  safe: `isEligible` structurally returns `false` outside its own month
  window, so nothing new is emitted there.
* `_monthGuardRecommendedCandidates` (new getter): filters
  `_recommendedActionCandidates` down to non-informational,
  non-`summerBonusDecision` candidates and reduces each to a
  `PublicDemoMonthGuardCandidate` — the single reused source for both
  HOME's slot and the Month Guard's warning.
* `_confirmMonthCloseIfRecommendedOutstanding()` (new): shows
  `PublicDemoMonthGuardWarningDialog` when any `recommended`-level item is
  outstanding; returns `true` (proceed) only when nothing is outstanding
  or the player explicitly chose to proceed anyway.
* `closeOrdinaryMonth()` (August-March) now calls this check before
  committing the close — this is the fix for Blocker 1's literal gap.
* `july()` is **deliberately unchanged** beyond PR1's own required check —
  see [Scope Decision: July](#scope-decision-july) below.

### New dialog: `lib/ui/public_demo/public_demo_month_guard_warning_dialog.dart`

`PublicDemoMonthGuardWarningDialog` — an `AlertDialog` listing every
outstanding `recommended` item's message, with two actions:
`タスクを確認` (`Key('public-demo-month-guard-review')`, emphasized —
cancels the close; the month does not advance, so every named action stays
exactly where it was, satisfying "'Review tasks' returns the player to an
actionable state" without any extra navigation) and
`このまま月末処理を進める` (`Key('public-demo-month-guard-proceed')` —
proceeds anyway, since a recommended item, unlike a required one, may
always be bypassed).

### Scope Decision: July

July's `july()` was **not** given the new `recommended`-level check. This
was a deliberate, evidence-based decision, not an oversight:

* PR1's required gate (the summer-bonus decision) already fully covers
  Issue #119's July acceptance criteria.
* July's canonical CTA closing into August on a single, unconditional tap
  once that decision is made is an existing, heavily-pinned contract
  across this suite (#118's single-CTA guarantee, #133's "none" route,
  and every trajectory helper — `public_demo_01_persistence_test.dart`,
  `public_demo_01_single_month_advance_cta_test.dart`,
  `public_demo_01_fiscal_year_progression_test.dart`, and others — that
  closes July as one atomic step).
* Empirically: adding the recommended check to July broke every one of
  these pinned trajectories, because virtually every existing test
  fixture that reaches July leaves *some* recommended-worthy candidate
  outstanding (most commonly eng-01's own July "次月発注" decision, itself
  a documented "legitimate current route" per
  `e2e/helpers/public-demo-player.ts`'s own `confirmJulyContinuation` doc).
  Reverting July to PR1's original (required-only) behavior restored every
  one of those trajectories with **zero** test-assertion changes.
* The literal gap the task names ("7月以外でも…警告なしで月末処理できる") is
  `closeOrdinaryMonth` — the single shared handler for August through
  March, which had **no** guard of any kind before this change. That is
  where the fix lives.

This means the "7月以外" fix's practical scope is August–March (`month >=
8`, all months routed through `closeOrdinaryMonth`), the eight months that
previously had zero outstanding-work protection. April, May, and June each
already have their own dedicated, differently-shaped flows (a mandatory
event dialog on every close) that this task's evidence did not show any
comparable "silent, unwarned loss" gap in during this pass — see
[Open Items](#open-items).

## July / Non-July Verification

* **July**: unchanged from PR1. The required summer-bonus decision still
  blocks accidental advance; once resolved, the same single canonical CTA
  closes July into August in one tap, with no new dialog interposed —
  confirmed by `public_demo_01_single_month_advance_cta_test.dart`,
  `public_demo_01_persistence_test.dart`, and
  `public_demo_01_home_recommended_action_test.dart`'s July-trajectory
  cases, all green with **no changes to their own assertions** (only the
  shared `tapAndSettle` helpers gained a generic "if the new dialog
  happens to be open, proceed through it" clause — see below).
* **Non-July (August–March)**: new coverage in
  `test/ui/public_demo/public_demo_01_month_guard_recommended_test.dart`
  (domain-command-built fixtures, no UI re-derivation needed) proves all
  four required cases:
  * *no-task*: nothing outstanding → the canonical CTA closes the month
    immediately, no dialog.
  * *recommended-task*: a genuine outstanding action (see below) → the
    dialog opens, names it by its real headline text, and the month does
    **not** advance until the player decides.
  * *"タスクを確認"*: cancels the close; the month is unchanged, and the
    named action's own button (`案件へ復帰`) is directly reachable and
    completable right there.
  * *"このまま月末処理を進める"*: proceeds anyway, closing the month.
* **required-task / terminal state**: covered at the domain level in
  `test/game/public_demo/public_demo_month_guard_test.dart` (extended, not
  replaced) — required and recommended items can coexist in one
  `evaluate()` call, and `monthCloseApplicable: false` (the terminal case)
  suppresses every item, required and recommended alike.
* **April→March progression not broken**: the full existing suite
  (`public_demo_01_success_playthrough_test.dart`,
  `public_demo_01_playthrough_test.dart`,
  `public_demo_01_fiscal_year_progression_test.dart`,
  `public_demo_01_annual_route`-equivalent domain tests, and the rest of
  the ~1300+ test suite) passes unmodified in assertion shape — the only
  test-file changes outside the two new files above are:
  * `test/presentation/home/home_recommended_action_test.dart` — additive
    (`isInformational` classification + `recoveryAssignment` priority
    tests).
  * `test/game/public_demo/public_demo_month_guard_test.dart` — additive
    (`recommended`-level coverage).
  * `test/ui/public_demo/public_demo_01_fiscal_year_progression_test.dart`,
    `public_demo_01_home_consolidation_test.dart`,
    `public_demo_01_home_runtime_read_test.dart`,
    `public_demo_01_recovery_ui_test.dart` — each gained the identical
    generic "proceed through the Month Guard's recommended warning if one
    happens to be open" clause inside their own local `tapAndSettle`
    helper (never inside a test body, never an assertion), because their
    trajectories close August+ without deciding every engineer's own
    monthly order — a real, pre-existing, documented route, not a new
    fixture invented for this change.
  * `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart`
    — the only file with a genuine assertion change: two tests in its
    `group('6: terminal and financial precedence...')` are rewritten (not
    deleted, not weakened) because their own trajectory
    (`playIntoCashShortage`) turns out to leave eng-01 genuinely
    Recovery-eligible from August onward — see
    [Recovery Verification](#recovery-verification) for why, and why the
    trajectory itself could not be "fixed" instead without silently
    changing this suite's calibrated cash-shortage timing (a Finance
    behavior change this task forbids).

## Recovery Verification

* **Recovery is now visible to HOME, cash shortage or not.** Months 7-14's
  waiting-engineer pipeline (including `案件へ復帰` once `ordered`) is now
  a real HOME recommended-action candidate — previously it was invisible
  to that authority in every state.
* **Recovery reachable during cash shortage**: `test/ui/public_demo/
  public_demo_01_home_recommended_action_test.dart`'s `playIntoCashShortage`
  trajectory (April: sell eng-01; no hires; July "none" bonus; close
  through October) reaches `cashShortage` with eng-01 genuinely
  Recovery-eligible (their own July continuation was never decided — a
  documented, legitimate route, confirmed independently at the domain
  level: with the order properly decided, this exact trajectory never
  reaches cash shortage by October at all — see the test's own inline
  doc). In that state:
  * `recommended(tester)!.kind` is `recoveryAssignment`, **not**
    `cashShortageResponse` — the informational card no longer permanently
    covers the reachable action.
  * The informational card itself is still rendered above HOME
    (`Key('public-demo-cash-shortage-card')`) — nothing about the
    informational display was removed, only its permanent hold on the one
    recommended-action slot.
  * Tapping the CTA performs the real recovery (`engineersWaiting -1`,
    `engineersAssigned +1`) while leaving cash, month, financialStatus,
    salesRemaining, and pendingRevenue untouched — `recoverAssignment`'s
    own Finance-free contract, unaffected by this change.
  * The month-close CTA (`11月を終了して翌月へ`) stays reachable — not a
    dead end.
* **Recovery reachable via "タスクを確認"**: `public_demo_01_month_guard_
  recommended_test.dart`'s dedicated test drives the full path — CTA tap
  → warning naming `案件へ復帰させる` → "タスクを確認" → month unchanged →
  scroll to the named button → tap it → `engineersAssigned` increments.
* **April→March progression preserved**: `public_demo_01_recovery_ui_
  test.dart`'s existing two tests (the full end-to-end Recovery/training
  scenario, and the "never-recovered engineer reaches terminal or March
  with no entry point" scenario) both pass unmodified in assertion shape.

## flutter analyze

Clean: **No issues found!**

## flutter test

Full suite: **all green** — see the end-of-turn summary for the exact
pass count from this branch's final run (`flutter test`, no path filter).
Every individually-run affected file (`public_demo_month_guard_test.dart`,
`home_recommended_action_test.dart` ×2 files,
`public_demo_01_home_recommended_action_test.dart`,
`public_demo_01_month_guard_recommended_test.dart`,
`public_demo_01_fiscal_year_progression_test.dart`,
`public_demo_01_home_consolidation_test.dart`,
`public_demo_01_home_runtime_read_test.dart`,
`public_demo_01_recovery_ui_test.dart`) was additionally verified in
isolation and is green.

## git diff --check

Clean — no whitespace errors.

## E2E / Fast CI Impact

* **Fast CI (`e2e.yml`, `smoke-e2e` job)**: its curated smoke spec list
  (`founding-first-assignment.spec.ts`, `public-demo-fresh-start.spec.ts`,
  `artifacts.*.spec.ts`, `game-state.ariaParsing.spec.ts`, `seeds.spec.ts`,
  `ses-player.*.spec.ts`, `portable-wheel-fallback.spec.ts`) does not
  include any Public Demo month-close/Recovery spec, so this change has no
  Fast CI Playwright surface at all. Fast CI's `validate` job (`flutter
  analyze`/`flutter test`/`flutter build web`) is the gate this change
  actually affects, and is green (above).
* **Heavy E2E (`e2e-heavy.yml`, manual/weekly)**: `public-demo-month-guard.
  spec.ts` (PR1's own July-only spec) is untouched and should be
  unaffected — July's own behavior did not change. Added a new spec,
  `e2e/tests/public-demo-month-guard-recommended.spec.ts`, covering the
  same no-task/recommended-task/"タスクを確認"/"このまま月末処理を進める"
  contract at the browser level, reusing
  `e2e/helpers/public-demo-player.ts`'s existing helpers
  (`sellFoundingEngineerInApril`, `runWaitingEngineerSalesPipelineToOrdered`,
  `recoverAssignment`, `decideNoSummerBonus`, `closeMonthlyPrimaryCta`,
  `findMonthlyPrimaryCta`). Also corrected a now-stale doc comment on
  `runWaitingEngineerSalesPipelineToOrdered` that asserted "RECOVERY-LOOP-1
  deliberately does not wire the month 7-14 waiting-engineer card into
  HOME" — no longer true after this change.
* **Not locally verified**: this sandbox has no pre-built `build/web` and
  building + running the Heavy E2E suite (which requires `flutter build
  web --release`, `npm install` under `e2e/`, and a Playwright browser
  run) was not completed within this session's time budget. This mirrors
  PR1's own precedent (its report explicitly left WebKit unverified
  locally as "a required CI gate before merge, not a silently skipped or
  weakened check"). The new spec and the `public-demo-player.ts` doc fix
  are believed correct (they reuse existing, already-verified helpers
  verbatim, and the underlying Flutter-level behavior they exercise is
  fully covered by the widget tests above) but should be confirmed by
  Heavy E2E CI before merge, same as PR1's WebKit gate was.
* **No other e2e spec's helper semantics changed** — `closeMonthlyPrimaryCta`
  itself is untouched; it simply will not auto-dismiss the new dialog
  (its own `waitAndDismissDialog` only matches a `確認`-labelled button,
  and neither of this dialog's two labels is `確認`), so any *other*
  existing Heavy E2E spec whose trajectory happens to leave a genuine
  recommended item outstanding through an August+ close would need the
  same treatment this report gave the affected Flutter widget-test
  helpers. `public-demo-annual-route.spec.ts` and `public-demo-recovery.
  spec.ts` were inspected and, as far as could be determined by reading
  (not running) them, decide every engineer's own monthly order at each
  relevant step, so they are not expected to hit this — but this is
  explicitly **not construed as a substitute for actually running Heavy
  E2E**, see above.

## Open Items

* Heavy E2E (`e2e-heavy.yml`) has not been run in this session — required
  before merge, per the note above.
* April/May/June do not yet have the `recommended`-level Month Guard
  check. This was a deliberate scope decision (see
  [Scope Decision: July](#scope-decision-july)) given the evidence
  available this pass (no comparable "silent unwarned loss" case
  demonstrated for those months, and each already gates through its own
  mandatory event dialog) — but it means, strictly, "7月以外" is only
  fully covered for August–March, not April–June. A future issue could
  extend the same mechanism there if a concrete blocker is identified.
* Per Issue #119's own **Screen Verification Gate**: this implementation
  has not been manually verified on a deployed build at a mobile
  viewport. That gate — "verify at least one recommended-task case and
  one required-task case… confirm copy is understandable and no dead end
  is introduced… do not close/start the next issue until the deployed
  behavior is approved" — is unchanged and still applies; it is a
  post-deploy human step this report cannot substitute for.
* `PublicDemoMonthGuardWarningDialog`'s copy ("未対応のタスクがあります" /
  "$actionName が未対応です。" / "タスクを確認" / "このまま月末処理を進める")
  is a first pass at plain, truthful wording; the Screen Verification Gate
  above is exactly where its actual readability should be confirmed.

## PLAYTHROUGH BLOCKER Resolution Verdict

* **Blocker 1** (non-July silent, unwarned month-close over outstanding
  work): **Resolved** for August–March, the literal gap identified (no
  guard existed there at all). Verified at the domain level
  (`PublicDemoMonthGuard`), the widget level
  (`public_demo_01_month_guard_recommended_test.dart`), and (pending
  Heavy E2E CI) the browser level.
* **Blocker 2** (informational cash-shortage CTA permanently blocking
  reachability of the real Recovery CTA): **Resolved**. Recovery is now a
  real HOME recommended-action candidate in every eligible month, and the
  one deliberate priority exception (`recoveryAssignment` ranked above
  `cashShortageResponse`) guarantees it is not permanently covered once
  eligible, cash shortage or not. Verified with a real trajectory that
  reaches genuine cash shortage with genuine Recovery eligibility
  simultaneously.

## PR / Merge Readiness

Ready for CI once Heavy E2E runs (the one gate this report could not
verify locally — see [Open Items](#open-items)). All local gates pass:
`flutter analyze` clean, `flutter test` full suite green, `git diff
--check` clean. No Finance, Persistence, save-schema, balance, or
month-close-calculation file was touched. No file under
`lib/presentation/home/widgets/` or `lib/presentation/home/home*.dart`
(HOME Phase 2 / #144's own scope) was touched. No test was deleted,
skipped, or had an assertion weakened — every changed test file either
gained new coverage or had its existing assertions genuinely re-targeted
at the new, intentionally-changed truth (documented case by case above),
never softened. The Screen Verification Gate from Issue #119's own body
remains an outstanding, required human step before the next issue starts.
