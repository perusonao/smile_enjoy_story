# ISSUE-117 Implementation Result

## Repository State

- Base/main SHA: `145a445cefd3c57ba96ce06d380b492806362090`
- Implementation branch: `agent/issue-117-public-demo-skill-sheet` (PR #131 head branch)
- Final implementation HEAD SHA: `ecd3ca50144ecbbc8baece5784982e328cf10c42`
- PR number: [#131](https://github.com/perusonao/smile_enjoy_story/pull/131)

The final implementation SHA above is the scoped source-and-test commit. This
result report is committed separately as documentation so its own file can
record the implementation revision unambiguously.

## Investigation Confirmation

The reproduced #117 cause was in
`_S._addEngineerStageCandidate` and `ec` in
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`: both the HOME
Recommended Action and employee-card `SkillSheet確認` directly called
`_startSkillSheetReview`. That commits
`PublicDemoAggregate.startSkillSheetReview`, moving the engineer from
`PublicDemoSalesStage.waiting` to `PublicDemoSalesStage.skillSheet` before a
player has seen any SkillSheet content.

`_openSkillSheetReview` is now the shared presentation entry point. It reads
only `PublicDemoEngineerSales.name`, `summary`, and the already-owned
`PublicDemoInterviewProfile` values. It calls `_startSkillSheetReview` only
after the `内容を確認` result is true. `戻る`, barrier dismissal, and any other
non-confirmation result return without mutation.

## Implementation

- `waiting → inspect` opens a read-only dialog and stays at `waiting`.
- `waiting → inspect → 戻る` stays at `waiting`; the same action can be opened again.
- `waiting → inspect → 内容を確認` uses the existing
  `_startSkillSheetReview` / aggregate authority and advances to `skillSheet`.
- The existing `_beginSelling` / aggregate authority remains the sole
  `skillSheet → selling` transition.

This is minimal: no Public Demo domain model, accounting, trust/morale rule,
month progression rule, or SkillSheet editing/risk system was added.

## Changed Files

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — read-only
  inspect-before-confirm presentation, with existing authoritative commands
  retained.
- `e2e/tests/public-demo-fresh-start.spec.ts` — existing PR #131 browser
  coverage for inspect, cancel/reopen, confirm, and sales-start reachability.
- `test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart` — focused
  HOME/card inspection, cancel, reopen, explicit-confirmation, and selling
  coverage.
- `test/ui/public_demo/public_demo_01_success_playthrough_test.dart` — the
  existing successful path explicitly confirms the new required step.
- `test/ui/public_demo/public_demo_01_assignment_carryforward_test.dart`
  — existing real playthrough confirms SkillSheet before continuing.
- `test/ui/public_demo/public_demo_01_bankruptcy_ux_test.dart` — existing
  real playthrough confirms SkillSheet before financial assertions.
- `test/ui/public_demo/public_demo_01_completion_lock_ui_test.dart` — existing
  real playthrough confirms SkillSheet before terminal assertions.
- `test/ui/public_demo/public_demo_01_fiscal_year_progression_test.dart` —
  existing real playthrough confirms SkillSheet before calendar assertions.
- `test/ui/public_demo/public_demo_01_home_consolidation_test.dart` —
  existing real CTA/legacy-button checks explicitly confirm the new step.
- `test/ui/public_demo/public_demo_01_home_navigator_test.dart` — Navigator
  CTA checks now prove opening is read-only, then explicitly confirm.
- `test/ui/public_demo/public_demo_01_home_office_stage_test.dart` — existing
  HOME CTA contract now proves read-only opening before confirmation.
- `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart` —
  existing Recommended Action trajectories explicitly confirm only the new
  SkillSheet step.
- `test/ui/public_demo/public_demo_01_home_runtime_read_test.dart` — existing
  authority-bound CTA check now proves no mutation before confirmation.
- `test/ui/public_demo/public_demo_01_persistence_test.dart` — persistence
  trajectories explicitly perform the authoritative confirmation.
- `test/ui/public_demo/public_demo_01_suzuki_sales_lock_test.dart` — its
  real Sato trajectory explicitly confirms before testing Suzuki's lock.

## SkillSheet Flow

```text
waiting
  → inspect
  → cancel
  → waiting

waiting
  → inspect
  → explicit confirmation
  → skillSheet
  → 営業開始
  → selling
```

## Regression Failure Analysis

The reported test name, `action C — month close is absent when no employee
action is required`, was not found in the current PR #131 checkout and did
not appear in the failed-test group list for GitHub workflow `33362829785`.
It therefore could not be reproduced as stated on this revision.

The actual workflow log shows a different regression pattern: existing Public
Demo tests invoked `SkillSheet確認`, then immediately expected the workflow to
be `skillSheet` or expected `営業開始`. Examples include
`public_demo_01_home_navigator_test.dart` P3 (line 195 on the CI revision),
`public_demo_01_persistence_test.dart` line 225, and the shared April
playthrough helpers. The workflow remained `waiting` because the new dialog
correctly required confirmation. This is #117 test adaptation, not a change
to Recommended Action semantics, employee state, or month-close behavior.

Action taken: only those test paths were changed to press the actual
`内容を確認` control. Month-close production code and its assertions were left
unchanged.

## Tests

- `dart format --output=none <14 changed Dart files>; git diff --check` —
  PASS. Formatter reported the files formatted; diff check was clean.
- `flutter analyze` — PASS (exit status 0).
- `flutter test test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart`
  — PASS, 2 tests.
- `flutter test test/ui/public_demo/public_demo_01_success_playthrough_test.dart`
  — INCONCLUSIVE locally. The Windows Flutter child process continued after
  the command wrapper returned, so no final local result was captured; it is
  not counted as a pass.
- GitHub Actions run `33380012332`, `validate` — PASS: `flutter analyze`,
  full `flutter test`, release web build, and replay unit tests all passed.
- GitHub Actions run `33380012332`, `e2e-chromium` — PASS.
- GitHub Actions run `33380012332`, `e2e-webkit` — FAIL, but the dedicated
  `tests/public-demo-fresh-start.spec.ts` #117 browser scenario passed. The
  failure is described below and is outside #117.

## Test Integrity

No retry, timeout, skip, or sleep was added or increased. No assertion was
weakened or removed. Existing test trajectories now include the new explicit
player confirmation; additional assertions prove opening is read-only before
that confirmation.

## Issue #118 Boundary

No duplicate next-month/month-close CTA behavior was changed. The reported
month-close assertion could not be located on this revision, and no
month-close or progression rule was altered. Issue #118 remains untouched.

The sole fresh-CI failure is also not #118: WebKit failed in the pre-existing
Phase 3A recruitment scenario
`e2e/tests/beginner-mode-waiting-and-recruitment.spec.ts:493/589`, timing out
while looking for the `未面接` button. The #117 Public Demo fresh-start browser
scenario passed on WebKit. No retry, timeout, CTA, or month-close behavior was
changed to mask this unrelated failure.

## Remaining Verification

- Resolve or obtain a clean rerun for the unrelated WebKit Phase 3A
  recruitment-flow failure before the final merge gate.
- Deployed-screen or human UX review, if required by the release gate.

## Final Assessment

NOT MERGE READY

The scoped implementation, full Flutter validation, and Chromium E2E are
green, but the fresh WebKit suite is not fully green because of the unrelated
Phase 3A recruitment-flow failure. The PR must not merge until that required
gate is clean.
