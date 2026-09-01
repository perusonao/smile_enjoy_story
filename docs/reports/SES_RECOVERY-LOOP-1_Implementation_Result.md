# SES Recovery Loop Phase 1 — Implementation Result

## STATUS

IMPLEMENTATION COMPLETE (production + required tests + verification). No
commit, push, or PR was created, per instructions.

## BASE SHA

`81e3a1426c5af3ea2d2f93346b919f551e190642` (PR #138 merge commit).

## AUDITED ORIGIN/MAIN

Verified before any implementation work:

```
git fetch origin
git rev-parse origin/main   -> 81e3a1426c5af3ea2d2f93346b919f551e190642
git status --short          -> (empty)
```

`origin/main` matched the expected BASE SHA exactly. No `STOP — MAIN MOVED`
condition was triggered.

The designated branch `claude/recovery-loop-phase-1-b1ih9q` already existed
locally but pointed at a stale commit (`f4ca78f`, an ancestor of
`origin/main` with no unmerged commits of its own — a leftover from a
previous session, not in-progress work). It was reset to `origin/main`
(`81e3a142`) before starting, per the "already-merged branch" restart
instructions (no unmerged history existed to preserve).

## INITIAL WORKTREE STATUS

`git status --short` was empty at session start — no pre-existing
uncommitted changes, no untracked Markdown design docs. Nothing needed to
be preserved/protected beyond the general safety rule.

## SOURCE DOCUMENTS

None of the four named source-of-truth documents exist anywhere in this
repository (checked the working tree and full `git log --all` /
`git rev-list --all` history for every branch):

- `docs/design/SES_RECOVERY-LOOP-1_Final_Implementation_Spec.md` — absent
- `docs/reports/SES_RECOVERY-LOOP-1_PreImplementation_Review.md` — absent
- `docs/reports/SES_RECOVERY-LOOP-1_Implementation_Task_Breakdown.md` — absent
- `docs/design/SES_RECOVERY-LOOP-1_E2E_Phase1_Design.md` — absent
- `docs/design/SES_RECOVERY-HOME-1_Integration_Design.md` — also absent

Per the task's own fallback rule ("資料がrepositoryに存在しない場合は…今回与
えた確定仕様とcurrent codeで実装可能なら進めてよい"), implementation proceeded
directly from the detailed **FINAL SPEC — FIXED REQUIREMENTS** section
embedded in the task description itself, cross-checked against the current
domain code (`lib/game/public_demo/*.dart`). This was judged sufficient —
no reconstruction/guessing of the missing spec was needed, and no
information gap rose to the level of a hard STOP.

## FILES CHANGED

**Production (4 files, matching the stated Task Breakdown scope exactly):**

| File | Change |
|---|---|
| `lib/game/public_demo/public_demo_recovery.dart` | **NEW** — `PublicDemoRecoveryEligibility` (pure eligibility predicate) |
| `lib/game/public_demo/public_demo_workflow_state.dart` | **MODIFIED** — added `recoverLateYearAssignment` (employee-specific atomic upsert) |
| `lib/game/public_demo/public_demo_aggregate.dart` | **MODIFIED** — added `recoverAssignment` (the atomic domain transaction) |
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | **MODIFIED** — minimal presentation entry point (see below) |

**Tests (8 new files, matching the stated Task Breakdown scope, +1 shared
test-support helper following this suite's existing `test_support/`
convention, e.g. `public_demo_sales_test_helpers.dart`):**

| File | Focus |
|---|---|
| `test/game/public_demo/public_demo_recovery_eligibility_test.dart` | Pure `isEligible`/`isMonthEligible` matrix |
| `test/game/public_demo/public_demo_recovery_workflow_test.dart` | `recoverLateYearAssignment` upsert semantics |
| `test/game/public_demo/public_demo_recovery_aggregate_test.dart` | Full atomic transaction, count re-projection, persistence/schema |
| `test/game/public_demo/public_demo_recovery_finance_test.dart` | Revenue recognition / AR / 30-day collection |
| `test/game/public_demo/public_demo_recovery_regression_test.dart` | May-flow / non-Recovery-flow regression |
| `test/game/public_demo/public_demo_recovery_duplicate_protection_test.dart` | Double-tap / re-render / repeated-command idempotency |
| `test/game/public_demo/public_demo_recovery_month_boundary_test.dart` | Full 4–15 month matrix + terminal-status boundary |
| `test/game/public_demo/public_demo_recovery_training_interaction_test.dart` | Training ⇄ Recovery exclusion + persistence invariant |
| `test/game/public_demo/test_support/public_demo_recovery_test_helpers.dart` | Shared fixtures (not one of the 8 "required" files; an auxiliary helper, same role as this suite's other `test_support/*.dart` files) |

**Total: 59 new tests, all passing.**

## PRODUCTION CHANGES

### `public_demo_recovery.dart` (new)

`PublicDemoRecoveryEligibility` — a stateless, pure predicate class
(mirrors the shape of `PublicDemoInternalTrainingTransaction`'s calculation
half). `isMonthEligible(month)` fixes the window at internal month 7–14
inclusive. `isEligible({state, workflow, engineerId})` checks, in order:
month window and non-terminal (`!state.isCloseBlocked`); the engineer
exists, is at `PublicDemoSalesStage.ordered`, and carries a genuine
`hasGenuineInterviewRecord` (never `stage`/`lastInterviewScore` alone —
mirrors `assignOrderedForMay`'s own defense in depth); not currently
training-selected; runtime-ready
(`PublicDemoEngineerRuntime.isReadyForFieldSales`); not already counted
assigned this month (`workflow.assignedEngineerIds`).

### `public_demo_workflow_state.dart` (+`recoverLateYearAssignment`)

The single employee-specific APPEND/UPSERT into `assignments`. Re-checks
the same core preconditions as defense in depth. Builds the recovered
assignment from (in priority order): an already-existing entry for that
`engineerId` → the founding `publicDemoInitialAssignments` template →
`PublicDemoAssignment.forOrderedEngineer(...)`. Explicitly sets
`nextOrderStatus: accepted` / `replacementStage: ordered` via `copyWith`,
never relying on `PublicDemoAssignment`'s own constructor defaults. Every
other assignment in the list is carried forward completely untouched, by
construction (`for (final assignment in assignments) if (id matches)
recovered else assignment`) — this method never calls
`assignOrderedForMay` and never replaces the roster wholesale.

### `public_demo_aggregate.dart` (+`recoverAssignment`)

The single production entry point. Gates on
`PublicDemoRecoveryEligibility.isEligible`, then: calls
`workflow.recoverLateYearAssignment`; re-projects
`state.engineersAssigned`/`engineersWaiting` from
`workflow.assignedEngineerIds(month: state.month).length` (not a bare
+1/-1 delta); commits both as one new `PublicDemoAggregate`. Touches no
Finance field (`cash`, `pendingRevenue`) itself.

### `public_demo_01_placeholder_screen.dart` (minimal entry point)

Before this change, no month past June ever rendered an engineer card for
anyone still economically waiting (month 7's own section only lists
`workflow.assignments`, and `ec(i)` — the sales-pipeline card — was gated
to months 4 and 6 only), so a waiting engineer's existing sales-pipeline
buttons (`SkillSheet確認` → `営業開始` → `案件紹介` → the two interviews →
`受注`) had no on-screen path from July onward, and there was no way at all
to turn a re-`ordered` engineer into an assignment past May. Three minimal
additions close this gap without touching HOME's Recommended-Action
vocabulary (`home_recommended_action.dart`) or redesigning any screen:

1. A new `if (s.month >= 7 && s.month <= 14)` block renders `ec(i)` for
   every engineer not currently counted assigned — the existing sales
   pipeline becomes reachable again, exactly reusing the same buttons months
   4/6 already have.
2. `ec(i)` gained one new button, shown only when
   `PublicDemoRecoveryEligibility.isEligible` already holds for that
   engineer at the `ordered` stage: `案件へ復帰`, calling the new
   `_recoverAssignment(engineerId)` → `_game.recoverAssignment(engineerId)`.
3. `ec(i)` gained an optional `showTrainingCard` parameter (default `true`,
   unchanged for months 4/6) — passed `false` for the new month 7–14 block,
   because internal training already has its own unconditional,
   month-≥6 card for every engineer runtime elsewhere in `build()`;
   without this, the new block would have rendered a second
   `public-demo-internal-training-<id>`-keyed card and broken an existing
   widget test (caught and fixed during verification — see FLUTTER TEST
   RESULT).

HOME's Recommended-Action system (`_addEngineerStageCandidate`,
`HomeRecommendedActionKind`) was deliberately left untouched: it already
documents "one enum value per already-existing production button" as an
architectural boundary, and wiring Recovery into it would require adding a
new `HomeRecommendedActionKind` (a 5th production file,
`home_recommended_action.dart`) — outside the stated 4-file scope and
arguably into "HOME redesign" territory the task explicitly excludes.
Recovery is reachable only from the raw employee card, never promoted into
HOME's "next thing to do" slot, and Month Guard is untouched — matching
the task's own HOME section ("Recoveryを毎月必須行動にしない").

## DOMAIN TRANSACTION

`PublicDemoAggregate.recoverAssignment(engineerId)` implements the 9-step
conceptual transaction as one atomic Dart method (no intermediate state is
ever exposed to a caller):

1. **Eligibility validation** — `PublicDemoRecoveryEligibility.isEligible`
2. **Current assignment lookup** — inside `recoverLateYearAssignment`, via
   `assignments.where((a) => a.engineerId == engineerId).firstOrNull`
3. **Duplicate assignment protection** — checked twice: once in
   `isEligible` (`!assignedEngineerIds.contains(engineerId)`) and again,
   defense-in-depth, inside `recoverLateYearAssignment` itself
4. **Employee-specific append/upsert** — `recoverLateYearAssignment`
5. **`nextOrderStatus = accepted`** — explicit `copyWith`
6. **`replacementStage = ordered`** — explicit `copyWith`
7. **Engineer workflow/runtime state update** — none needed: the engineer
   already reached `ordered` (with a genuine interview record) through the
   pre-existing, unmodified sales pipeline before `recoverAssignment` is
   ever called; Recovery's own step is purely the assignment commit
8. **Count re-projection** — `engineersAssigned`/`engineersWaiting` are
   recomputed from `workflow.assignedEngineerIds(...).length` and
   `state.engineerCount`, not incremented/decremented
9. **Invariants validation** — not re-run inline (this mirrors every other
   `PublicDemoAggregate` command; `_validateForPersistence` runs at
   `fromJson`, and a dedicated test proves a Recovery-committed aggregate
   round-trips through it without throwing)

If eligibility fails, or `recoverLateYearAssignment` is itself a
structural no-op (`identical(nextWorkflow, workflow)`), `recoverAssignment`
returns `this` — the exact same object — so no half-applied state is ever
constructed, let alone exposed.

## ELIGIBILITY IMPLEMENTATION

`PublicDemoRecoveryEligibility.isEligible` — see PRODUCTION CHANGES above.
Deliberately reuses every existing authoritative fact (`isCloseBlocked`,
`hasGenuineInterviewRecord`, `trainingSelections`, `isReadyForFieldSales`,
`assignedEngineerIds`) rather than inventing a parallel Recovery-only
eligibility model.

## ASSIGNMENT UPSERT IMPLEMENTATION

`PublicDemoWorkflowState.recoverLateYearAssignment` — see PRODUCTION
CHANGES above. Verified by `public_demo_recovery_workflow_test.dart` and
the aggregate-level "CRITICAL ASSIGNMENT REQUIREMENT" test in
`public_demo_recovery_aggregate_test.dart`, which establishes a genuine
continuation assignment through the ordinary May→June→July flow for one
employee (`app-01`) and proves it survives, byte-for-byte, a Recovery
transaction for a completely different employee (`eng-01`).
`assignOrderedForMay` (the May wholesale-rebuild path) is never called by
Recovery and was not modified.

## COUNT REPROJECTION

`state.engineersAssigned`/`engineersWaiting` are recomputed from
`workflow.assignedEngineerIds(month: state.month)` on every successful
Recovery — the exact same projection
`PublicDemoAggregate._validateForPersistence` already requires to hold for
month ≥ 6. Verified directly (`public_demo_recovery_aggregate_test.dart`'s
"counts are re-projected … not a bare +1/-1 delta" test — recovering the
same engineer twice never over-counts) and via the persistence round-trip.

## FINANCE INVARIANTS

No Finance file (`public_demo_revenue.dart`, `public_demo_revenue_payment.dart`,
`public_demo_monthly_close.dart`, `public_demo_salary*.dart`) was touched.
`recoverAssignment` never writes `cash` or `pendingRevenue`. Verified in
`public_demo_recovery_finance_test.dart`:

- Cash and `pendingRevenue` are byte-identical immediately before/after
  `recoverAssignment`.
- The *next* month-end close (`closeOrdinaryMonth`) recognizes the
  Recovered engineer's revenue as pending AR via the unchanged
  `PublicDemoRevenue.monthlyRevenueForAssignedCount(state.engineersAssigned)`
  formula.
- Cash collection follows the existing 30-day contract: the close *after*
  the one that recognized the revenue is the one that turns it into cash
  (`PublicDemoRevenuePayment.apply`, untouched).
- `PublicDemoRevenue.ratePerAssignedEngineer`/`monthlyRevenueForAssignedCount`
  values themselves are asserted unchanged.

No starting-cash or balance-tuning change was made anywhere.

## PERSISTENCE INVARIANTS

No save-schema, codec, or migration change. `public_demo_recovery_aggregate_test.dart`
proves: (a) a Recovery-committed aggregate round-trips through real
`jsonEncode`/`jsonDecode` + `PublicDemoAggregate.fromJson` without
throwing (i.e. `_validateForPersistence` still holds); (b) the top-level
aggregate JSON keys stay exactly `{state, workflow}`; (c) the recovered
assignment's own JSON has exactly the pre-existing nine
`PublicDemoAssignment` fields, with no new key added.

## TRAINING INTERACTION

Training's own rules (`selectInternalTraining`/`cancelTraining`,
`PublicDemoInternalTrainingTransaction`) are unmodified.
`public_demo_recovery_training_interaction_test.dart` proves: a
training-selected engineer is excluded from Recovery even though every
other fact holds; cancelling training makes the same engineer eligible
again (no new Recovery-only training rule was invented); Recovery never
touches an unrelated engineer's training selection; the existing
persistence invariant ("a training selection can never name an assigned
engineer") still holds once Recovery has run for a different engineer in
the same month.

## MONTH / TERMINAL BOUNDARIES

`public_demo_recovery_month_boundary_test.dart` exercises every internal
month 4 through 15 individually at the full `PublicDemoAggregate` level
(not just the pure predicate), plus a dedicated terminal-status scenario
that reaches bankruptcy while `state.month` is still inside 7–14 (proving
the terminal guard, not merely the month guard, is what blocks Recovery
there). All 4/5/6 (before) and 15/fiscal-completed (after) cases are
confirmed structural no-ops (`identical` aggregate returned).

## DUPLICATE PROTECTION

Verified at three levels: `recoverLateYearAssignment` (workflow),
`recoverAssignment` (aggregate), and `public_demo_recovery_duplicate_protection_test.dart`'s
explicit double-tap / re-render-replay / stale-reference scenarios — in
every case, a second (or third, fourth, fifth) call against an
already-Recovered engineer returns the identical aggregate object, and the
assignment list never grows past one entry per engineer.

## TEST RESULTS

59 new Recovery tests across the 8 files, all passing:

```
flutter test test/game/public_demo/public_demo_recovery_*.dart
...
All tests passed! (59/59)
```

Full existing suite (1389 tests, includes the 59 new ones):

```
flutter test
...
All tests passed! (1389/1389)
```

One pre-existing widget test regressed during development
(`test/ui/public_demo/public_demo_01_completion_lock_ui_test.dart`, a
duplicate-key failure from the new month 7–14 rendering block also
re-rendering the already-unconditional training card) — this was diagnosed
and fixed (the `showTrainingCard: false` parameter described above) before
finishing, and the full suite is green as of the final run.

## FLUTTER ANALYZE RESULT

```
flutter analyze
...
No issues found!
```

(Run against Flutter 3.44.9 — the exact version this repository's own CI
pins in `.github/workflows/e2e.yml`/`public-demo-validation.yml` — since no
Flutter/Dart SDK was pre-installed in this session's container; it was
downloaded fresh for this task.)

## FLUTTER TEST RESULT

```
flutter test
...
+1389: All tests passed!
```

`dart format` was run on every file this task touched or created; the two
incidental reformats `dart format` produced in pre-existing, untouched
lines of `public_demo_workflow_state.dart` and
`public_demo_01_placeholder_screen.dart` (a formatter-version artifact,
unrelated to this change) were reverted by hand to keep the diff scoped to
Recovery only — confirmed via `git diff` showing zero unintended deletions
in any of the 3 modified production files.

## E2E READINESS

**E2E BLOCKED** (documentation gap, not a domain gap).

`docs/design/SES_RECOVERY-LOOP-1_E2E_Phase1_Design.md` does not exist
anywhere in this repository, so the confirmed E2E design this task asks to
be read/validated against is not available. Per the task's own instruction
("Task BreakdownがE2Eを別PR/次工程としているなら勝手にannual E2Eまでscopeを拡
大しない"), and since the Task Breakdown itself is also absent, no E2E spec
was authored this round — scope was kept to production + required tests.

For reference, the domain layer is demonstrably E2E-ready: the canonical
target the task names (`app-01` / 高橋 翔) was independently exercised in
`public_demo_recovery_aggregate_test.dart`'s "CRITICAL ASSIGNMENT
REQUIREMENT" test as the pre-existing continuation assignment a Recovery
transaction must preserve, using exactly the same May→June→July hire path
an E2E script would drive through the UI. `e2e/tests/public-demo-annual-route.spec.ts`
(Route B) already exists as a base to extend from. Existing Public Demo
E2E specs were not run in this session (no Playwright/browser E2E runner
was invoked — verification here was `dart format` / `flutter analyze` /
`flutter test` only, as scoped).

## SCOPE DEVIATIONS

None requiring escalation. Production scope stayed at exactly 4 files
(1 new, 3 modified) and required tests at exactly 8 files, matching the
task's stated Task Breakdown shape. One auxiliary test-support helper file
was added (`test_support/public_demo_recovery_test_helpers.dart`),
following this test suite's own pre-existing convention (e.g.
`public_demo_sales_test_helpers.dart`, `public_demo_offer_test_helpers.dart`)
— not counted as a 9th "required" test file, and not a production file.

One in-flight correction, not a scope deviation: the first version of the
month 7–14 UI rendering block duplicated an already-unconditional training
card (see FLUTTER TEST RESULT / MONTH / TERMINAL BOUNDARIES). This was
caught by the existing widget-test suite during verification and fixed
within the same `public_demo_01_placeholder_screen.dart` file already in
scope — it did not widen the file count.

## KNOWN ISSUES

- E2E design/spec for Recovery does not exist in this repository (see E2E
  READINESS). Recovery's own required unit/widget-level test coverage does
  not depend on it and is complete.
- The new "案件へ復帰" button and the month 7–14 waiting-engineer card
  section have no dedicated widget test of their own in this round (the 8
  required test files are all domain-level `PublicDemoAggregate`/
  `PublicDemoWorkflowState` tests, matching the Task Breakdown's stated
  file matrix); the existing widget-test suite's regression catch (see
  above) is the only UI-level signal this round produced. A follow-up
  widget test for the new button/card would be a reasonable, low-risk
  addition alongside a future E2E pass.

## BLOCKERS

None. No Opus-5 escalation condition was met: the atomic upsert works
without touching existing assignments, no Finance or save-schema change
was needed, no structural conflict with existing May flow was found, and
production scope did not expand beyond the stated 4 files.

## GIT STATUS

Final `git status --short` (this session's changes only — the worktree was
empty at session start, per INITIAL WORKTREE STATUS above; every line
below was written by this task):

```
 M lib/game/public_demo/public_demo_aggregate.dart
 M lib/game/public_demo/public_demo_workflow_state.dart
 M lib/ui/public_demo/public_demo_01_placeholder_screen.dart
?? lib/game/public_demo/public_demo_recovery.dart
?? test/game/public_demo/public_demo_recovery_aggregate_test.dart
?? test/game/public_demo/public_demo_recovery_duplicate_protection_test.dart
?? test/game/public_demo/public_demo_recovery_eligibility_test.dart
?? test/game/public_demo/public_demo_recovery_finance_test.dart
?? test/game/public_demo/public_demo_recovery_month_boundary_test.dart
?? test/game/public_demo/public_demo_recovery_regression_test.dart
?? test/game/public_demo/public_demo_recovery_training_interaction_test.dart
?? test/game/public_demo/public_demo_recovery_workflow_test.dart
?? test/game/public_demo/test_support/public_demo_recovery_test_helpers.dart
?? docs/reports/SES_RECOVERY-LOOP-1_Implementation_Result.md
```

`git diff --check` reports no whitespace errors (exit code 0).

Nothing was committed, pushed, or merged. This report itself is also left
uncommitted, per instructions.

## FINAL VERDICT

**A. IMPLEMENTATION COMPLETE — READY FOR E2E** (the domain/production side;
the E2E design document itself still needs to be authored before any E2E
script can be written against it — see E2E READINESS).

## NEXT ACTION

1. Author `docs/design/SES_RECOVERY-LOOP-1_E2E_Phase1_Design.md` (or
   confirm/locate it if it exists outside this repository), then implement
   the focused Recovery E2E spec (Option B: focused RECOVERY spec + annual
   Route B, Chromium/WebKit × 360×800/390×800) against
   `e2e/tests/public-demo-annual-route.spec.ts` as the base, using `app-01`
   / 高橋 翔 as the canonical target — no seed needed, per the task.
2. Optionally add a focused widget test for the new "案件へ復帰" button and
   the month 7–14 waiting-engineer card section (not required by the
   stated Task Breakdown, but a reasonable low-risk addition before E2E).
3. Review this report and the diff, then commit/push/PR when ready — none
   of those three actions were taken this round, per instructions.
