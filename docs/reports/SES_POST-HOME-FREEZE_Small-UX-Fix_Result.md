# SES POST-HOME-FREEZE Small-UX-Fix — Result Report

## STATUS

PASS

## BASE SHA / HEAD SHA

- BASE SHA: `673a3c04aeef31f8a8c23eb7b20fd8046333187e` (`origin/main` at session start)
- HEAD SHA: `9f74f8c` (branch `claude/home-stale-status-fix-mmqtwt`)

The designated branch had no prior PR and carried only one stray commit
(`f4ca78f`, "Phase 0A/0B: SES domain models and random generators") which was
already an ancestor of `origin/main` (confirmed via `git merge-base
--is-ancestor`) — i.e. it contained no work of its own. The branch was reset
to `origin/main` before starting, per the "merged PR" restart procedure, since
it carried no unmerged work to preserve.

Note: the referenced `SES_POST-HOME-FREEZE_Parallel-Fresh-Audit.md` does not
exist anywhere in the repository (checked working tree and full `git log
--all`). This implementation proceeded directly from the concrete,
self-contained specification in the task request (exact function names,
exact desired behavior, exact test list), which was sufficient and verified
against the current code before editing.

## Root causes

### 1. Stale "翌月参画予定" (Office Stage)

`engineerStatus(e)` (`public_demo_01_placeholder_screen.dart`) maps
`PublicDemoSalesStage.ordered` to the fixed string `'翌月参画予定'`. Once an
engineer reaches `ordered` (via a genuine client-interview win →
`recordOrder`), there is no further production stage transition for them —
`ordered` is terminal in the `PublicDemoSalesStage` enum's own transition
graph. The actual "now on a project" fact lives elsewhere:
`PublicDemoWorkflowState.assignedEngineerIds(month:)`, built by
`assignOrderedForMay()` when **May's** close runs (not April's — confirmed by
reading `PublicDemoAggregate.closeMay`).

`_officeStageDisplay` read `engineerStatus(engineer)` directly for the HOME
Office Stage badge, so from the month the engineer's assignment is actually
built onward (June, in the April→May→June trajectory) through the rest of
the fiscal year, the badge kept showing "翌月参画予定" for an engineer who
was, in truth, already working on a project.

### 2. Empty "○月開始結果" heading (会計/Accounting tab)

`_buildAccountingTab` rendered `Text('${publicDemoMonthLabel(s.month)}開始結果', ...)`
unconditionally for `s.month >= 8 && s.month <= 14`, and again for
`s.month == 15 && !s.fiscalYearCompleted`. Only `s.month == 8` ever had a
body under that heading (the July payroll/summer-bonus recap). Every other
month in both conditions rendered a bold section heading with nothing
beneath it.

## Implemented fixes

### 1. Truthful Office Stage status

Added `_officeStageStatusFor(engineer)` in
`public_demo_01_placeholder_screen.dart`, used only by `_officeStageDisplay`:

```dart
String _officeStageStatusFor(PublicDemoEngineerSales engineer) {
  if (engineer.stage == PublicDemoSalesStage.ordered &&
      _currentlyAssignedEngineerIds.contains(engineer.id)) {
    return '参画中';
  }
  return engineerStatus(engineer);
}
```

- Reuses the existing `_currentlyAssignedEngineerIds` getter (itself
  `workflow.assignedEngineerIds(month: s.month)`, the same authority already
  used by the cash-forecast advice filter and the training eligibility
  check elsewhere on this screen) — no new domain authority.
- Scoped to the Office Stage only. `engineerStatus` itself, the 社員 tab's
  own `badge(engineerStatus(e))`, and the SkillSheet sheet's status label
  are all unchanged — an ordered-but-not-yet-assigned engineer still reads
  "翌月参画予定" everywhere, truthfully, until they are actually assigned.
- Updated the doc comments on `_officeStageDisplay` and
  `HomeOfficeStageMember.status` (in
  `lib/presentation/home/models/home_office_stage_display.dart`) to record
  the one case where the Office Stage's status now differs from the 社員
  tab's raw pipeline-stage label, and why.

### 2. Empty accounting heading removed (Fresh Audit Option 1)

Collapsed the two conditional blocks in `_buildAccountingTab` into one
`if (s.month == 8)` block carrying the heading and its existing body
together. The `s.month == 15 && !s.fiscalYearCompleted` heading-only branch
(which never had a body) was removed outright. No new per-month content was
added for any month.

## Changed files

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
- `lib/presentation/home/models/home_office_stage_display.dart` (doc-comment
  update only, no behavior change)
- `test/ui/public_demo/public_demo_01_home_office_stage_test.dart` (new
  group: 3 tests)
- `test/ui/public_demo/public_demo_01_accounting_tab_empty_heading_test.dart`
  (new file: 8 tests)

## Tests

New/updated focused tests (all against the real screen, driven through real
`PublicDemoAggregate` commands — no fixture shortcuts around production
code):

- `test/ui/public_demo/public_demo_01_home_office_stage_test.dart`,
  group "POST-HOME-FREEZE Small-UX-Fix: truthful ordered-vs-assigned status":
  - an ordered-but-not-yet-assigned engineer still truthfully shows
    "翌月参画予定" (pinned right after April's real order win, before
    May's close has run `assignOrderedForMay`).
  - once May's close actually builds the assignment (confirmed reached only
    after closing May into June — `assignOrderedForMay` runs inside
    `closeMay`, not `closeApril`), the same engineer shows "参画中", never
    the stale string.
  - a still-waiting engineer is unaffected by the fix ("待機" unchanged).
- `test/ui/public_demo/public_demo_01_accounting_tab_empty_heading_test.dart`
  (new file, using the existing `PublicDemoAggregate`-injection technique
  already established by `public_demo_01_home_cash_forecast_advice_test.dart`'s
  `_FixedSaveService` and `publicDemoAggregateAtMonth`):
  - August still shows its heading and its existing body.
  - months 9-14 each show no "開始結果" heading.
  - March (15) before fiscal-year completion shows no heading either, and
    the fiscal-year-complete card is correctly absent (not yet completed).

Full run:

```
flutter analyze
→ No issues found! (ran in 15.9s)

flutter test test/ui/public_demo/public_demo_01_home_office_stage_test.dart \
              test/ui/public_demo/public_demo_01_accounting_tab_empty_heading_test.dart
→ 27/27 passed

flutter test test/ui/public_demo/ test/presentation/home/ test/game/public_demo/
→ 976/976 passed

git diff --check
→ clean (no exit output, no whitespace errors)
```

(Flutter 3.44.9 was not pre-installed in this session's environment; it was
installed locally, matching the version this repo's CI workflows pin, to run
the checks above directly rather than relying on CI alone.)

## #167 conflict check

Issue #167 (Late Game Phase 1) is being implemented separately as PR #185
(`claude/first-fun-year-phase-1-tgd6sy`, based on the same `673a3c0` base).
Diffed that branch against `origin/main` for the one file both branches
touch (`public_demo_01_placeholder_screen.dart`):

- PR #185's hunks are at lines ~1568-1622 (new `founderFollowUp` method),
  ~1638-1658 (Month Guard exclusion), ~1927-1966, ~2241-2283, and
  ~3102-3127 — all additions of new methods/cards for the founder follow-up
  decision.
- This change's hunks are at `_officeStageDisplay`/`_officeStageStatusFor`
  (originally ~363-400) and `_buildAccountingTab`'s August block
  (originally ~3194-3212).
- No line-range overlap, and no textual reference to `engineerStatus`,
  `_officeStageDisplay`, `_buildAccountingTab`, or `開始結果` appears
  anywhere in PR #185's diff (checked directly). A future merge of both
  onto `main` should apply cleanly with no manual conflict resolution
  expected, though this was not test-merged since #185 has not landed yet.
- No Active Project Visibility, Late Game decision, domain, save/schema,
  Finance, month-transition, balance, or workflow code was touched by this
  change, consistent with the exclusions in this task's brief.

## Known Issues

- The referenced Fresh Audit document does not exist in the repository (see
  BASE/HEAD section above). If it exists elsewhere and specifies additional
  scope or a different Option, this implementation may need reconciling
  against it.
- This fix does not address whether the 社員 (Employees) tab's own
  `ec(i)` card has the same underlying staleness for an ordered-and-assigned
  engineer (it also reads `engineerStatus(e)` directly, unconditionally) —
  the task explicitly scoped this fix to "HOME Office Stage表示" only, so
  that tab's badge was deliberately left untouched.

## PR URL

https://github.com/perusonao/smile_enjoy_story/pull/186

(created below; not auto-merged, per instructions)

## Merge Readiness

READY FOR REVIEW — not auto-merged. `flutter analyze` clean, full targeted
regression (976 tests across `test/ui/public_demo/`, `test/presentation/home/`,
`test/game/public_demo/`) passes, `git diff --check` clean, no overlap found
with the in-flight #167 PR.
