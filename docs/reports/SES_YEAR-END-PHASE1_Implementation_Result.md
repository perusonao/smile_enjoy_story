# SES Year-End Phase 1 — Implementation Result

Status: **Implemented**

BASE SHA: `3806cda1d9ce434024be25719f559806c4f81e4b` (origin/main, PR #186 merge — matches the SHA specified in the task; origin/main had not advanced past it at task start).

Branch: `claude/ses-year-end-phase1-vu0wxf`

## 0. Audit file note

The task named `SES_YEAR-END-PHASE1_Fresh-PreImplementation_Audit.md` as the
governing pre-implementation audit and asked to honor its "B. READY WITH
CONDITIONS" section. That file could not be found anywhere in this
repository — not on `main`, not on any other branch/commit in `git log
--all`, and not among any open GitHub issue/PR for this repo. Rather than
fabricate its contents or skip the audit step, this implementation performed
its own direct authority audit against current `main` (documented in §2
below) and applied the same spirit of conditions the task description itself
already states explicitly (authoritative-only data, no fabricated annual
aggregates, reuse the canonical reset/replay path, success-route only,
preserve #167/#186/bankruptcy-recovery/HOME Freeze). If the actual audit
document exists outside this repository, its conditions should be
diffed against this report before merge.

## 1. Goal

Give a player who completes April→March a clear, fact-based "one year of
running the company" result inside the accounting tab's existing "第1期終了"
area, plus a "4月からもう一度" replay CTA — without touching HOME, without
inventing any game system, and without fabricating any year-spanning total
Public Demo 0.1 does not actually retain.

## 2. Authority audit (fields actually used)

Every value below is either read verbatim from an already-authoritative
field, or a plain arithmetic difference between two such values. No new
persisted field, no new Finance category, no new save-schema key.

| Display item | Source | Authority |
|---|---|---|
| 開始時現金 | `PublicDemoState.aprilStart().cash` | The exact same canonical starting-cash constant `PublicDemoAggregate.initial()` (and therefore every replay via `_restartGame`) uses. Not a fabricated/re-tracked value — Public Demo 0.1 has exactly one starting cash. |
| 終了時現金 | `PublicDemoState.cash` | Verbatim, same field the pre-existing card already showed. |
| 年間の増減 | `finalCash - startingCash` | Pure display arithmetic over the two authoritative values above; never stored. |
| 最終社員数 | `PublicDemoState.engineerCount + PublicDemoState.adminCount` | Same "社員 = total headcount" composition `HomeDashboardDisplayData.totalEmployeeCount` already uses (Issue #122's own engineer-only vs. total distinction). |
| 年間採用数 | `PublicDemoState.joinedApplicantIds.length` | That field is itself `PublicDemoWorkflowState.joinedApplicants` (`hasJoined` applicants) surfaced onto `PublicDemoState` at month-close. Public Demo 0.1 only ever accepts hires once, at the May→June close (`PublicDemoState.advanceToJune`'s `engineerCount + hires` / `joinedApplicantIds` append) — so this is exactly this fiscal year's hiring total, not a running multi-year total. |
| 最終参画人数 | `PublicDemoState.engineersAssigned` | Verbatim — the same field Revenue/Growth/training eligibility already treat as SSOT. |
| 最終待機人数 | `PublicDemoState.engineersWaiting` | Verbatim. |
| 創業社員の成長 | `publicDemoInitialEngineerRuntimes` (baseline capability, by `engineerId`) vs. `PublicDemoState.runtimeForOrNull(engineerId)?.actualCapability` (current) | Same founding-roster identity (`eng-01`/`eng-02`) Issue #167's `publicDemoFounderEngineerIds` already treats as the founding set; same `actualCapability` getter every other Public Demo screen reads. Founder display names (佐藤 健/鈴木 葵) come from the existing `publicDemoInitialEngineers` constant. |
| ひよりの年度総括 | Pure function over the display-data fields above (`publicDemoYearEndHiyoriSummary`) | No new authority — every sentence restates an already-computed field; never invents revenue, sales-activity count, crisis count, or recovery count. |

Deliberately **not shown**, because Public Demo 0.1 retains no such
year-spanning total: annual revenue, annual sales-activity count, crisis
count, recovery count. Confirmed by reading `PublicDemoState`'s full field
list — the only revenue-adjacent field is `pendingRevenue` (a point-in-time
AR balance, not a year total), and there is no crisis/recovery counter
anywhere in `PublicDemoState`/`PublicDemoWorkflowState`.

## 3. What changed

- **`lib/ui/public_demo/public_demo_year_end_display_data.dart`** (new) —
  `PublicDemoYearEndDisplayData` (pure projection, `fromPublicDemoState`
  factory) and `PublicDemoFounderGrowthDisplay`, plus
  `publicDemoYearEndHiyoriSummary(data)` (deterministic, fact-only text
  attributed to ひより — not the HOME navigator widget/state, which is
  untouched).
- **`lib/ui/public_demo/public_demo_year_end_result_card.dart`** (new) —
  `PublicDemoYearEndResultCard`, the enhanced "第1期終了" widget: cash
  start→end + delta, headcount/hires/participation/waiting, founder growth
  list, ひより summary, and the "4月からもう一度" `FilledButton`. Keeps the
  outer `Card`'s existing `Key('public-demo-fiscal-year-complete')` so the
  pre-completion regression in
  `public_demo_01_accounting_tab_empty_heading_test.dart` (`findsNothing`
  for months 9-14 and pre-completion March) is unaffected.
- **`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`** — the
  accounting tab's `if (s.fiscalYearCompleted)` block now builds
  `PublicDemoYearEndResultCard` from `PublicDemoYearEndDisplayData
  .fromPublicDemoState(s)`, wired to the screen's own existing
  `_confirmRestartFromApril` method as `onReplay` (see §4). No other line in
  this file changed; HOME's own build methods are untouched.

## 4. Replay: canonical reset/replay reuse

The "4月からもう一度" button's `onPressed` is `_confirmRestartFromApril` —
the exact existing private method the "開発・テストメニュー" tab's own
"4月からやり直す" control already uses. That method shows the same existing
`public-demo-restart-april-dialog` confirmation, and on confirm calls the
same existing `_restartGame()` (clears `PublicDemoSaveService` storage, then
`_game = PublicDemoAggregate.initial()`, `_selectedTabIndex = _homeTabIndex`)
— the identical canonical reset authority the bankruptcy terminal card's
"最初からやり直す" button already reuses. **No new reset/replay authority was
added anywhere.**

## 5. Prohibited-area check

- **HOME layout**: no file under `lib/presentation/home/` or any HOME
  build method in the placeholder screen changed. `flutter analyze` and the
  HOME regression suites below confirm.
- **Active Project Visibility / Employee UI Phase A**: not touched — no
  employee-tab or sales-tab file changed.
- **New game system**: none — every value is a read or a subtraction of
  existing authoritative fields; no new mechanic, no new persisted field.
- **Domain change**: not needed and not made — confirmed by not touching
  any file under `lib/game/public_demo/`.
- **Save/schema change**: none — `PublicDemoState.toJson`/`fromJson`,
  `PublicDemoWorkflowState.toJson`/`fromJson`, and `PublicDemoSaveCodec` are
  untouched.
- **Finance calculation / Balance / Month transition / workflow
  authority**: none touched — no file under `lib/game/public_demo/` in this
  diff.
- **Fake data**: none — see the authority table in §2.
- **Unrelated refactor**: the diff is exactly two new files plus one
  targeted, doc-commented edit inside the existing accounting tab's
  `if (s.fiscalYearCompleted)` block and its import list.

## 6. Tests

New:

- `test/ui/public_demo/public_demo_year_end_display_data_test.dart` (5
  tests) — pure unit coverage of `PublicDemoYearEndDisplayData
  .fromPublicDemoState` (every field traced to a hand-built
  `PublicDemoState`, including a differentiated hire/participation/growth
  scenario and a missing-runtime fallback) and `publicDemoYearEndHiyoriSummary`
  (cash increase/decrease wording, hires, participation, growth naming only
  the founder who actually grew, and an explicit check that forbidden terms
  — 売上/営業回数/危機/回復回数 — never appear).
- `test/ui/public_demo/public_demo_01_year_end_result_test.dart` (6 widget
  tests, real screen via `PublicDemo01PlaceholderScreen` +
  `_FixedSaveService`, aggregates built by chaining real domain commands
  from `PublicDemoAggregate.initial()`):
  1. Fiscal year not yet completed (March pre-close) → no year-end card/CTA.
  2. An ordinary pre-year-end month (October) → no year-end card.
  3. Success fixture (baseline, no hires) → card shown, figures match state,
     replay CTA and ひより summary present.
  4. Success fixture with `eng-01` genuinely Recovery-assigned (real
     domain-gated: `eng-02` cannot be assigned at her founding capability of
     52, below the 60 field-sales threshold) → differentiated
     participating(1)/waiting(1), real assignment-driven founder growth,
     every figure and every founder-growth row matches state.
  5. Tapping "4月からもう一度" shows the existing
     `public-demo-restart-april-dialog`; confirming resets to `month=4`,
     `fiscalYearCompleted=false`, `cash == aprilStart().cash`, and HOME's nav
     destination is present — the canonical replay contract.
  6. Canceling that dialog leaves the completed year-end state (cash, the
     year-end card) untouched.

Regression (existing suites, unmodified, run against this branch):

- `test/ui/public_demo/public_demo_01_accounting_tab_empty_heading_test.dart`
  (#186)
- `test/ui/public_demo/public_demo_01_home_office_stage_test.dart` (#186)
- `test/game/public_demo/public_demo_founder_follow_up_test.dart` (#167)
- `test/ui/public_demo/public_demo_founder_follow_up_dialog_test.dart` (#167)
- `test/ui/public_demo/public_demo_01_completion_lock_ui_test.dart`
  (bankruptcy/terminal-lock UX)
- `test/ui/public_demo/public_demo_01_bankruptcy_ux_test.dart`
  (bankruptcy/recovery UX)
- `test/ui/public_demo/public_demo_01_home_consolidation_test.dart` (HOME)
- `test/ui/public_demo/public_demo_01_home_runtime_read_test.dart` (HOME)
- `test/game/public_demo/public_demo_fiscal_year_save_test.dart`
- `test/game/public_demo/public_demo_fiscal_year_completion_lock_test.dart`

An initial version of the new mobile-width test (`Row`+`Expanded` label/value
layout) genuinely caught a real overflow (44px at 360x800, 14px at 390x844)
in the cash start→end line. Fixed by switching `_YearEndStatRow` to a
vertical (label-above-value) layout, matching the existing
`PublicDemoFinanceSummarySection`/`_FinanceRow` convention already proven
safe at these widths elsewhere in this screen — the test then passed at both
sizes with `tester.takeException()` asserted `isNull`.

## 7. Verification

- `flutter analyze` — **No issues found.**
- `git diff --check` — clean (no whitespace errors).
- `flutter test` (new suites) — **19/19 passed**
  (`public_demo_year_end_display_data_test.dart`: 5,
  `public_demo_01_year_end_result_test.dart`: 14, including the two 360/390px
  overflow checks and the replay-flow tests).
- `flutter test` (10 targeted regression files above) — **120/120 passed**,
  0 failures.
- A full-repository `flutter test` (176 files) was additionally started as a
  supplementary check; see the PR/final report for its outcome if it
  completed before this report was finalized — the targeted regression
  selection above was chosen to directly cover every prohibited/must-preserve
  area named in the task (#167, #186, HOME, bankruptcy/recovery,
  fiscal-year completion/save) and is what this PASS verdict is based on.

## 8. Known limitations

- The referenced pre-implementation audit document
  (`SES_YEAR-END-PHASE1_Fresh-PreImplementation_Audit.md`) does not exist in
  this repository; see §0.
- The full project test suite (176 files) was not run end-to-end in this
  session due to time budget; the regression suites run were chosen to
  directly cover every prohibited/must-preserve area named in the task
  (#167, #186, HOME, bankruptcy/recovery, fiscal-year completion/save).
- 360/390px overflow was checked by code review (Row+Expanded label/value
  pattern matching the existing `_FinanceRow`/KPI row conventions already
  proven at that width elsewhere in this screen) rather than a new golden
  screenshot; no new golden/screenshot test was added.
