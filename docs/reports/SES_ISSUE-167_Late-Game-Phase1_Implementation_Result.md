# SES Issue #167 FIRST-FUN-YEAR-LATE-GAME-1 Phase 1 — Implementation Result

## STATUS

**Implemented, tested, pushed. PR created, not merged (no auto-merge per policy).**

## Audited BASE SHA

- `origin/main` fetched fresh at the start of this session.
- **BASE SHA: `673a3c04aeef31f8a8c23eb7b20fd8046333187e`** — the PR #184 merge
  commit ("SES HOME Final Touch" — HOME One-Screen Final Fit). This is the
  latest `main` at session start; it post-dates every condition Issue #167's
  design-audit comment required before production implementation:
  - #166 (Public Demo persistence P0) — merged via PR #169
    (`test-harness-only, no production bug` verdict).
  - #147 / HOME UI (Final Density → Final Polish → One-Screen Final Fit,
    PR #184) — merged, and per this task's explicit instruction, **HOME is
    now Frozen**: no additional HOME layout change was made or is planned
    by this work.
  - #168 (Onboarding/Finding B) — already completed per the governing
    priority document's own history.

The branch `claude/first-fun-year-phase-1-tgd6sy` this task was assigned to
was stale (based on a pre-Phase-0 commit not in `main`'s history, no open
PR). Per the branch-handling instructions for an unmerged-but-stale branch,
it was restarted from `origin/main` (`git checkout -B
claude/first-fun-year-phase-1-tgd6sy origin/main`) before any new work.

## Design-audit basis

No `docs/reports/SES_FIRST-FUN-YEAR_LATE-GAME-1_Design_Audit.md` file exists
anywhere in git history (`git log --all` finds nothing under that name) —
the audit session's report was apparently never committed. The audit's full
conclusion is preserved verbatim in **Issue #167's own comment**
(`READY WITH CONDITIONS`, 2026-09-04), which this implementation follows:

- Treat the problem as a missing recurring/state-dependent management
  decision, not seven scripted events.
- Recommended Phase 1 direction: **participating-employee follow-up
  investment** — a cash-vs-employee/future-growth trade-off, reusing
  existing morale/trust-equivalent authorities, triggered from real state,
  explained after the choice, no single obviously-correct answer, ~2-3h
  Claude Code slice.
- Explicit boundary: do not turn this into the future contract-renewal
  system, and do not build a full employee-dialogue system.
- All five numbered conditions (166/147/168 merged, fresh audit against
  actual `main`, confirm whether additive persistence is needed, check
  issue overlap, keep the slice narrow) — addressed below.

## Final HEAD SHA

See the "Commit / branch / PR" section at the end of this report (the head
commit this report itself is part of).

## Implemented gameplay loop — "founder follow-up"

A small, state-driven decision for a **founding engineer**
(`publicDemoInitialEngineers`: 佐藤 健 `eng-01`, 鈴木 葵 `eng-02` — never a
later recruitment hire) who has been continuously participating in a client
project without any company follow-up during the August-February stretch
the full-year playtest audit (merged in PR #164) found became a passive
month-advance loop.

This deliberately reuses **`PublicDemoEngineerSales.mental`/`.trust`** —
fields that already existed (constructed at 50/50, read only for
`PublicDemoCompanySnapshot`'s company-wide averages) but, before this
change, were **never written by any gameplay action** — confirmed by
grepping the whole `lib/` tree before implementation. No new
morale/trust/relationship system was introduced.

### Trigger condition (`PublicDemoFounderFollowUp.isEligible`)

All of the following, checked against real, already-authoritative state:

1. The engineer is one of the two founding engineers
   (`publicDemoFounderEngineerIds`, derived from `publicDemoInitialEngineers`
   itself — never a duplicated id literal).
2. `month` is inside internal months 8-14 (August-February).
3. The engineer is genuinely currently assigned this month
   (`PublicDemoWorkflowState.assignedEngineerIds(month:)` — the same SSOT
   Revenue/Growth/training eligibility already agree on).
4. `PublicDemoEngineerSales.founderFollowUpMonth` is still `null` (not yet
   decided this fiscal year).

This is genuinely state-dependent, not calendar-only: an engineer who is
economically waiting, replaced, or has already decided this year produces
no candidate at all.

### Choices / trade-off (`PublicDemoFounderFollowUpDecision`)

| Choice | Cost | Mental Δ | Trust Δ |
|---|---:|---:|---:|
| そのまま任せる (`holdBack`) | ¥0 | −2 | −2 |
| 声をかける (`checkIn`) | ¥0 | +3 | +2 |
| 支援に投資する (`investSupport`) | ¥50,000 | +6 | +5 |

No single obviously-correct answer: `checkIn` is free and positive (a safe
default), `investSupport` costs cash for a larger effect (a genuine
cash-vs-relationship trade-off across different play strategies —
cash-conservative vs. people-investment), and `holdBack` has a real
(small) downside, mirroring the existing raise-decision's own "declining
has a cost" shape (`public_demo_raise.dart`).

### State changes

- `PublicDemoEngineerSales.mental`/`.trust` update by the table above,
  clamped to `[0, 100]`.
- `PublicDemoEngineerSales.founderFollowUpMonth` is set to the current
  month — the one-time guard.
- For `investSupport` only: `PublicDemoState.cash` decreases by ¥50,000,
  booked via the existing `PublicDemoState.recordTrainingSpend` bucket (see
  "Persistence/schema impact" below for why).
- No change to Finance truth's core invariants, month progression, save
  schema shape (beyond the one new field), Recommended Action eligibility
  for any other kind, or any other engineer/applicant/assignment record.

### Explaining the result after choosing

`founderFollowUp(...)` in `public_demo_01_placeholder_screen.dart` shows a
result dialog (`PublicDemoEventDialog`, reusing the existing
event-company-management asset) stating the reason
(`PublicDemoFounderFollowUp.reasonFor`) and the exact mental/trust delta
(and cash cost, when paid) — never shown if the commit was silently
rejected (`identical(next, _game)` check), so the player is never told an
effect happened when it did not.

### One-time guard against illegitimate repetition

`PublicDemoEngineerSales.founderFollowUpMonth` is checked at three
independent layers (defense in depth, matching this codebase's existing
convention for every other gated transition):

1. `PublicDemoFounderFollowUp.isEligible` (pure predicate).
2. `PublicDemoWorkflowState.applyFounderFollowUpDecision` (re-validates
   before mutating).
3. `PublicDemoAggregate.applyFounderFollowUpDecision` (re-validates before
   touching cash).

A second attempt for the same engineer, same fiscal year, is a structural
no-op at every layer — proven by test (see below).

### Save/reload safety

- `founderFollowUpMonth` round-trips through `toJson`/`fromJson` and through
  the actual production save path (`PublicDemoSaveCodec`), including its
  strict save-consistency re-encoding check.
- A legacy save with no `founderFollowUpMonth` key decodes it as `null`
  (not-yet-decided) — proven by test.

### Month-transition / HOME Recommended Action integration

- A new `HomeRecommendedActionKind.founderFollowUp` was added, following
  the file's own "extend without contradicting the design table" pattern
  (documented inline).
- The same eligibility check backs three call sites that must never drift:
  the HOME recommended-action candidate, the Employee-tab card's button,
  and the card's own render condition — none of which is a HOME layout
  change (the new card lives on the Employee/社員 tab, not HOME; HOME
  itself only gained one more possible Recommended Action *value*, not a
  new section).
- **Deliberately excluded from the Month Guard's "outstanding recommended
  action" warning** (`_monthGuardRecommendedCandidates`). This decision
  stays eligible across the entire multi-month window by design ("does not
  need to be a forced modal every month" — Issue #167's own design
  principle #1); including it in the Guard would nag the player on every
  single month-close attempt for up to 7 months whenever the founding
  engineer stays continuously assigned — exactly the passive-loop-adjacent
  friction this feature exists to fix, not add. This exclusion was
  discovered as a genuine regression against two existing tests during
  implementation (see "Known Issues" / test results below) and fixed before
  finishing, not left as a residual risk.

## Persistence/schema impact

- **One new nullable field**: `PublicDemoEngineerSales.founderFollowUpMonth`
  (`int?`, default `null`). `fromJson` defaults it to `null` when absent —
  full backward compatibility with every existing save, proven by test.
- **No new top-level schema key, no new domain concept class beyond one
  small value-object file** (`public_demo_founder_follow_up.dart`: an enum,
  two small constants, and a stateless calculator/eligibility class —
  mirrors the existing `public_demo_raise.dart` shape exactly).
- **Finance truth**: the one-time ¥50,000 `investSupport` cost is booked
  through the **existing** `PublicDemoState.recordTrainingSpend` bucket
  (the same one `PublicDemoInternalTrainingTransaction` already uses)
  rather than a new tracked-spend category. This was a deliberate choice
  made after discovering, via a failing save/reload test, that
  `PublicDemoSaveCodec._hasConsistentAuthorityFacts` requires every
  discretionary cash deduction within a month to reconcile against
  `cash == monthOpeningCash - monthTrainingSpent - monthRecruitmentSpent`.
  Adding a **third** tracked bucket (and updating that consistency check,
  `PublicDemoMonthlyCashFlow`, and the cash-flow card) would have been the
  more "semantically pure" fix but is exactly the kind of Finance-adjacent
  schema/domain expansion this task was instructed to avoid; reusing the
  existing bucket keeps Finance truth's invariants completely unchanged.
  **Known cosmetic side effect**: the monthly cash-flow breakdown
  (`public_demo_monthly_cash_flow_card.dart`) labels this bucket "研修費"
  (training cost); an `investSupport` follow-up choice will show its
  ¥50,000 under that label rather than a dedicated "フォロー費" line. The
  yen amount itself is fully accurate; only the row's Japanese label is
  imprecise. Documented here as a Known Issue rather than expanded.
- No change to `PublicDemoAggregate.toJson`/`fromJson`'s top-level shape
  (still exactly `{state, workflow}`).

## Changed files

Production:
- `lib/game/public_demo/public_demo_sales.dart` — `founderFollowUpMonth`
  field + copyWith/toJson/fromJson.
- `lib/game/public_demo/public_demo_founder_follow_up.dart` (new) —
  decision enum, calculator, eligibility.
- `lib/game/public_demo/public_demo_workflow_state.dart` —
  `applyFounderFollowUpDecision` (defense-in-depth re-validation +
  mental/trust/guard mutation).
- `lib/game/public_demo/public_demo_aggregate.dart` —
  `applyFounderFollowUpDecision` (fiscal-year/cash/finance guards, the only
  place cash is touched for this decision).
- `lib/presentation/home/models/home_recommended_action.dart` — new
  `HomeRecommendedActionKind.founderFollowUp`.
- `lib/presentation/home/models/home_navigator_display.dart` — fixed
  educational copy for the new kind (exhaustive switch).
- `lib/ui/public_demo/public_demo_founder_follow_up_dialog.dart` (new) —
  the 3-choice decision dialog.
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` —
  `founderFollowUp(...)` entry point, HOME candidate emission
  (`_addFounderFollowUpCandidate`), Employee-tab card
  (`founderFollowUpCard`), and the Month Guard exclusion.

Tests:
- `test/game/public_demo/public_demo_founder_follow_up_test.dart` (new, 20
  tests) — trigger/non-trigger conditions, choice trade-offs, one-time
  guard (workflow and aggregate level), clamping, persistence backward
  compatibility, cash-insufficiency guard, month-transition regression,
  save/reload via `PublicDemoSaveCodec`.
- `test/ui/public_demo/public_demo_founder_follow_up_dialog_test.dart`
  (new, 2 tests) — dialog choices render and return the tapped decision;
  the paid choice disables when unaffordable.

Docs:
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` — SSOT sync (HOME
  Freeze, next-order, #148/#183 notes; see its own new Update history
  entry).
- This report.

## Tests / results

```
flutter analyze
  → No issues found!

flutter test test/game/public_demo/public_demo_founder_follow_up_test.dart
  → 20/20 passed

flutter test test/ui/public_demo/public_demo_founder_follow_up_dialog_test.dart
  → 2/2 passed

flutter test test/game/public_demo test/ui/public_demo test/app
  → 803/803 passed (full run confirmed complete; see Known Issues for the
    one regression found and fixed mid-implementation)

git diff --check
  → clean
```

**A genuine regression was found and fixed before finishing**: the first
full-suite run failed
`test/ui/public_demo/public_demo_01_bankruptcy_ux_test.dart` (all 4 cases)
and `test/ui/public_demo/public_demo_01_assignment_carryforward_test.dart`
(1 case) — both drive a founding engineer continuously assigned through
August-February without ever addressing a Month Guard "recommended"
warning, exactly the scenario the new candidate now makes eligible. Fixed
by excluding `HomeRecommendedActionKind.founderFollowUp` from
`_monthGuardRecommendedCandidates` (see "Month-transition / HOME
Recommended Action integration" above). Both files pass individually and
the full re-run is clean.

## 360/390px

No new HOME layout was added (HOME Freeze respected). The new UI surface is:
- One `AlertDialog` (`PublicDemoFounderFollowUpDialog`) — same shape/widget
  types as the existing `PublicDemoRaiseDialog`, already verified operable
  at 360/390px.
- One `Card` + `FilledButton` on the Employee (社員) tab
  (`founderFollowUpCard`) — the same `Card`/`Padding`/`Column`/`FilledButton`
  structure as the adjacent, already-verified `employeeConditionCard`.

No new fixed widths, no new horizontal `Row`s, and button label text
（フォローする, そのまま任せる, 声をかける, 支援に投資する）is short relative to
existing verified labels (e.g. 案件へ復帰, 昇給要求を確認する). Given the
structural equivalence to already-screen-verified widgets and this task's
E2E policy (non-blocking for viewport-only concerns; do not stop
implementation for full E2E stabilization), this was not re-verified via a
fresh Playwright/screenshot pass. **Known gap**: no dedicated 360/390px
screenshot was captured for this specific card/dialog this session.

## Known Issues

1. Monthly cash-flow breakdown labels the `investSupport` charge "研修費"
   (training cost) rather than a dedicated follow-up-cost label — see
   "Persistence/schema impact" above. Cosmetic only; the yen amount is
   accurate.
2. No dedicated 360/390px screenshot captured this session (see above);
   relies on structural equivalence to already-verified widgets.
3. `PublicDemoAggregate.applyFounderFollowUpDecision`'s
   `state.fiscalYearCompleted` guard is exercised only indirectly (via the
   `isEligible`/no-op tests); reaching genuine fiscal-year completion in a
   unit test requires simulating the full March close, which was out of
   this Phase 1 slice's scope. The guard's logic is a single, simple
   boolean check mirroring every other terminal guard in this codebase.
4. Design-audit report file (`SES_FIRST-FUN-YEAR_LATE-GAME-1_Design_Audit.md`)
   referenced by Issue #167's own comment does not exist in the repository;
   this implementation relied on the comment's full verbatim text instead
   (see "Design-audit basis" above).

## SSOT update

`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` updated:
- HOME Freeze recorded (One-Screen Final Fit / PR #184).
- Current execution order and Prioritized backlog table reordered to:
  #167 Phase 1 (this work, done) → Year-End Phase 1 → Active Project
  Visibility → stale small UX fixes → Employee UI Phase A re-evaluation →
  April→March human replay.
- #148's additional production work explicitly not treated as next P0;
  #183 recorded as a separate dev-efficiency line, not ahead of gameplay.
- New Update history entry dated 2026-09-06.

## PR URL

See the final chat message for the pushed branch/PR URL (created after this
report was committed).

## Merge Readiness

**Ready for review.** `flutter analyze` clean, full relevant test suite
(`test/game/public_demo`, `test/ui/public_demo`, `test/app`) passes,
`git diff --check` clean, no Finance/save-schema/HOME-layout/domain-scope
violation identified. Auto-merge intentionally not performed per policy.
