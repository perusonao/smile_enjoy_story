# Issue #122: HOME employee-count / role-label correction — Result

## Summary

Fixed HOME's "社員" (total employees) figures on the real Public Demo runtime
screen: they were silently reading `PublicDemoState.engineerCount` (engineers
only), omitting the one 総務/general-affairs employee (`adminCount`) every
Public Demo save starts with. Fixed at both places this figure is shown under
a "社員" (whole-company) label — the compact KPI row and the Office Stage
headcount pill — by introducing a new, additive `totalEmployeeCount`
projection field and wiring it to those two labels. `engineerCount` and the
existing `employeeCount` (engineer-only) field are unchanged in meaning and
every existing use.

## Base / branch / commit

- Base `main` SHA: `39d6f40e0d43561766f5cbf2c33a26ccbf9fd6f1`
  (`Merge pull request #161 from perusonao/claude/first-fun-year-cash-shortage-truth-4blgnw`)
- Branch: `claude/issue-122-employee-count-kwbf6y`
  (branch was stale/pre-dated main at session start — recreated from
  `origin/main` before any work; no PR existed for it yet, so no history was
  lost)
- Final commit SHA: recorded after commit/push below

## Issue #122 reproduction on current main

Reproduced, confirmed on `origin/main` before any change:

- `PublicDemoState.aprilStart()` starts with `engineerCount: 2` and
  `adminCount: 1` (`lib/game/public_demo/public_demo_state.dart`). `adminCount`
  is never changed by any transition in the game (verified: no other write
  site exists) — it models the one 総務 employee, given a face/name by
  `HomeNavigatorIdentity` (`lib/presentation/home/models/home_navigator_display.dart`),
  whose own doc already states "The Public Demo's founding team is two
  engineers plus one general-affairs employee... `PublicDemoState.adminCount`
  is 1 from `aprilStart()`".
- `HomeDashboardDisplayData.employeeCount` (`lib/presentation/home/models/home_dashboard_display_data.dart`)
  was `state.engineerCount` verbatim — never including `adminCount`.
- Two real-screen surfaces render this value under a "社員" (employees, i.e.
  whole company) label:
  1. The compact runtime KPI's row-B "社員" tile
     (`lib/presentation/home/widgets/kpi_section.dart`, `_compactRowsFor`) —
     showed `${data.employeeCount}名` = **2名** at April start.
  2. The Office Stage's aggregate headcount pill
     (`lib/presentation/home/widgets/home_office_stage_section.dart` /
     wired from `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`'s
     `_officeStageDisplay`) — showed `社員${employeeCount}名・待機${waitingCount}名`
     = **社員2名・待機2名** at April start, also from `s.engineerCount`.
- Both are on the real Public Demo HOME screen (`PublicDemo01PlaceholderScreen`,
  reached from the app's actual entry point), i.e. the true total headcount
  (3 — 2 engineers + 1 総務) was never shown; only the engineer-only count
  (2) was shown, mislabeled as "社員" (employees). This exactly reproduces
  Issue #122's complaint and violated its Acceptance Criteria ("No
  engineer-only count is labeled as total employees", "General affairs is
  not silently omitted from a total headcount label").
- The existing test suite even encoded the bug as expected behavior before
  this fix: `test/ui/public_demo/public_demo_01_home_consolidation_test.dart`
  asserted `kpiTileValue('employees', '2名')`, and
  `test/ui/public_demo/public_demo_01_home_office_stage_test.dart` asserted
  the pill text as `'社員${state.engineerCount}名・待機...'`.

Verdict: **not previously fixed** — reproduced on current `main`, code change
required.

## Root cause

`HomeDashboardDisplayData.fromPublicDemoState` and
`PublicDemo01PlaceholderScreen._officeStageDisplay` both derived every
"headcount" figure from `PublicDemoState.engineerCount` alone. That field is
correctly engineer-only by its own existing meaning and other consumers
(e.g. the non-runtime `KpiSection`'s "技術者数" tile), but two *different*
call sites reused it under a "社員" (whole-company) label without ever
folding in `PublicDemoState.adminCount`, the one real, salaried
総務/general-affairs employee the domain model already tracks separately.

## Changed files

- `lib/presentation/home/models/home_dashboard_display_data.dart` — added a
  new `totalEmployeeCount` field (`engineerCount + adminCount`), defaulting
  to `employeeCount` for any hand-built fixture that predates it (same
  pattern the existing HOME-RUNTIME-2A optional fields already use).
  `employeeCount` itself, its doc, and every existing construction site are
  unchanged.
- `lib/presentation/home/widgets/kpi_section.dart` — the compact runtime
  KPI's "社員" tile now reads `data.totalEmployeeCount` instead of
  `data.employeeCount`. The non-runtime default grid's "技術者数" tile
  (still `employeeCount`) is untouched — that label is already correctly
  engineer-only per Issue #122's own scope ("Use '技術者 2名' when the value
  is engineer-only").
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` —
  `_officeStageDisplay.employeeCount` now reads
  `_homeDashboardData.totalEmployeeCount` instead of `s.engineerCount`
  directly, so the Office Stage's "社員…名" pill cannot disagree with the
  KPI's own total. `waitingCount` (`s.engineersWaiting`) is unchanged — the
  総務 employee is not part of the assigned/waiting engineer concept.
- `lib/presentation/home/models/home_office_stage_display.dart` — doc-only:
  corrected the class-doc comment that had claimed
  `employeeCount`/`waitingCount` come from `PublicDemoState.engineerCount`
  (no longer true for `employeeCount`) to name the actual current source and
  explain the Issue #122 fix.
- `test/presentation/home/home_dashboard_display_data_test.dart` — new
  `totalEmployeeCount projection (Issue #122)` test group (see Tests below).
- `test/ui/public_demo/public_demo_01_home_consolidation_test.dart` —
  updated test 10 (real-screen KPI tile) to assert the corrected total and
  explicitly assert the old engineer-only value no longer renders under the
  社員 label.
- `test/ui/public_demo/public_demo_01_home_office_stage_test.dart` —
  updated the Office Stage headcount-pill test to assert the corrected
  total and explicitly assert the old engineer-only text no longer renders.

No change to `PublicDemoState`, any Domain model, Finance/save schema,
Public Demo routing/app-entry/persistence, or PR #164's areas. No
CI/E2E-infrastructure files touched.

## Tests added/updated (focused regression, Issue #122)

Both scenarios the task asked for, at both fixed surfaces:

- **Unit** (`home_dashboard_display_data_test.dart`, new group
  `totalEmployeeCount projection (Issue #122)`):
  - 技術者だけ (engineers only, `adminCount: 0`) → `totalEmployeeCount == 2 ==
    employeeCount`.
  - 技術者 + 総務社員 (the real starting state, `engineerCount: 2,
    adminCount: 1`) → `totalEmployeeCount == 3`, and explicitly
    `isNot(employeeCount)` so the engineer-only field can never silently
    stand in for the total.
  - A third case with a larger roster (`engineerCount: 5, adminCount: 2` →
    `7`) to pin the general `engineerCount + adminCount` formula, not just
    the two starting numbers.
- **Widget, real screen** (`public_demo_01_home_consolidation_test.dart`,
  test 10 — KPI's 社員 tile): at April start (2 engineers + 1 admin) asserts
  `kpiTileValue('employees', '3名')` renders and `'2名'` under that tile does
  not.
- **Widget, real screen** (`public_demo_01_home_office_stage_test.dart`,
  Office Stage headcount pill): asserts the pill renders
  `社員3名・待機2名` and that the old `社員2名・待機2名` text is gone.

## flutter analyze

```
flutter analyze
No issues found! (ran in 3.0s)
```

Ran with the CI-pinned Flutter 3.44.9 (downloaded fresh in-session; not
preinstalled in this environment).

## Focused test results

All green:

```
flutter test \
  test/presentation/home/home_dashboard_display_data_test.dart \
  test/presentation/home/home_dashboard_data_wiring_test.dart \
  test/presentation/home/home_office_stage_section_test.dart \
  test/presentation/home/office_stage_section_test.dart \
  test/presentation/home/home_shell_page_test.dart \
  test/ui/public_demo/public_demo_01_home_office_stage_test.dart \
  test/ui/public_demo/public_demo_01_home_consolidation_test.dart \
  test/ui/public_demo/public_demo_01_home_runtime_read_test.dart
...
+164: All tests passed!
```

This covers: the new Issue #122 unit tests, the HOME dashboard data-wiring
widget tests (default/non-runtime KPI grid — confirms "技術者数" is
untouched), the Office Stage component and real-screen suites, the full
HOME consolidation suite (25+ scenario groups, incl. layout/overflow at
360×390px and terminal financial states), and the HOME runtime-read
adversarial suite. `dart format` was applied to every line this change adds
(verified individually against this Flutter/Dart version's formatter); nothing
else in these files was reformatted — see "Formatting note" below.

`flutter test` (full suite) and Playwright/E2E were **not** run — out of
scope per the task instructions (focused + minimal-necessary existing tests
only; full E2E only if this change would clearly require it, which it does
not: no routing/persistence/save-schema/app-entry code was touched).

### Formatting note

This environment's Dart formatter (bundled with Flutter 3.44.9, matching the
version CI workflows pin) reformats some **pre-existing, unrelated** code in
two of the touched test files if run whole-file (an older/different
formatter style is currently checked into `main` in those files, and CI has
no repo-wide `dart format --set-exit-if-changed` gate — only one narrow
workflow formats a single unrelated file). To honor "no unrelated refactor",
those incidental reformatting hunks were reverted; every line this change
actually adds was verified individually to already match this formatter's
output. `dart format --set-exit-if-changed` therefore still reports these
two files as "would reformat" if run repo-wide — that pre-existing drift is
outside Issue #122's scope and was not introduced or worsened by this change.

## PR

- Number/URL: filled in after `create_pull_request` below.

## CI start status

- Filled in after PR creation — confirmed CI workflows triggered on the PR,
  not awaited to completion (per task instructions: do not spend the session
  waiting on CI).

## Remaining issues

- None known within Issue #122's scope. The pre-existing formatter-version
  drift noted above affects two test files but predates this change and is
  outside this issue's scope to fix.
- E2E/WebKit E2E were not run (not required; no routing/persistence/save
  code touched by this change).

## Issue #122 close readiness

The Acceptance Criteria this issue lists are met by this change:

- "No engineer-only count is labeled as total employees" — fixed at both
  identified "社員" sites (KPI tile, Office Stage pill).
- "General affairs is not silently omitted from a total headcount label" —
  fixed (`totalEmployeeCount = engineerCount + adminCount`).
- "Existing gameplay and staffing logic are unchanged" — no domain,
  finance, save, or workflow code touched; only a presentation projection
  and two display wiring sites.
- "360/390px layout remains readable without overflow" — covered by the
  existing responsive-layout test group in
  `public_demo_01_home_consolidation_test.dart`, which still passes (the
  text length change, "2名" → "3名", is not a widening regression).
- "Use '技術者 2名' when the value is engineer-only" — the one place this
  label already exists (`KpiSection`'s default/non-runtime grid) was
  already correct and is untouched.

Recommendation: **closable**, pending the issue owner's own Screen
Verification Gate sign-off (the issue explicitly asks not to close until
that manual confirmation happens).
