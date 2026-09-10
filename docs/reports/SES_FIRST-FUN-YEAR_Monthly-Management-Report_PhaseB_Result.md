# SES First Fun Year — Monthly Management Report Phase B: Dialog/UI Integration — Result Report

Status: **Implemented — Phase B (Dialog/UI + 5 close-handler integration). Builds directly on Phase A's `PublicDemoMonthlyReportSnapshot` authority (PR #234). No save-schema change, no new domain authority, no Finance/Payroll/Recruitment/Assignment/Month Guard change.**

## 0. Metadata

| item | value |
|---|---|
| Base `origin/main` SHA | `da29e97d8b122c448abe0e04e126fa569c6cb2a6` |
| Branch | `claude/monthly-management-report-phase-b-8k6k0j` |
| Scope | Phase B only: pure presenter (`PublicDemoMonthlyReportDisplayData`), read-only Hiyori comment function, `StatelessWidget` dialog (`PublicDemoMonthlyReportDialog`), integration into all five monthly-close handlers (`april`/`may`/`june`/`july`/`closeOrdinaryMonth`) in `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`. No new domain authority, no save-schema change, no Finance/Payroll/Recruitment/Assignment/Month Guard/HOME-redesign change. |

## 1. Goal

Complete First Fun Year's monthly feedback loop: 今月やること → 行動 → 月末処理 → **今月の経営結果** → 会社への影響を理解 → 来月考えることを理解 → 翌月HOME. Phase A's `PublicDemoMonthlyReportSnapshot` (PR #234, already on `origin/main`) is used verbatim as the sole authority — this phase adds no new domain fact and calls no aggregate/state/workflow command.

## 2. Report flow

For all five close handlers, the flow is now:

```
既存 Month Guard → 既存 event dialog (April/May only) → 既存 closeX()
  → _commitAggregate(...)
  → NEW: _maybeShowMonthlyReport(closedMonth)   ← reads only, never closes again
  → dismiss
  → _resetMonthScroll()
  → 既存 HOME
```

`final closedMonth = s.month;` is captured immediately before each `_commitAggregate(...)` call, in `april()`, `may()`, `june()`, `july()`, and `closeOrdinaryMonth()`. After commit, `_maybeShowMonthlyReport(closedMonth)`:

```dart
Future<void> _maybeShowMonthlyReport(int closedMonth) async {
  final snapshot = PublicDemoMonthlyReportSnapshot.fromAggregate(
    _game,
    closedMonth: closedMonth,
  );
  if (!snapshot.isReady) return;
  if (!mounted) return;
  final data = PublicDemoMonthlyReportDisplayData.fromSnapshot(
    snapshot,
    applicants: workflow.applicants,
  );
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PublicDemoMonthlyReportDialog(data: data),
  );
}
```

Only `PublicDemoMonthlyReportSnapshot.isReady` (i.e. `status == ready`) shows the report; `notYetRecorded`/`staleClosedMonth` are silent no-ops (Phase A's own type-level guard, reused verbatim — Fresh Audit §4/§12). This method never calls `closeX(...)` again — it only reads the already-committed `_game`.

A blocked/no-op close never reaches this method at all: every one of the five handlers already returns early, before its own commit, when the close itself did not happen — Month Guard cancel (`_confirmMonthCloseIfRecommendedOutstanding` returning `false`) and July's outstanding summer-bonus decision (`decideSummerBonus(); return;`) both exit before `_commitAggregate` is ever called.

## 2.1 Changed files

| file | change |
|---|---|
| `lib/ui/public_demo/public_demo_monthly_report_display_data.dart` | **New.** `PublicDemoMonthlyReportDisplayData` + `publicDemoMonthlyReportHiyoriComment`. |
| `lib/ui/public_demo/public_demo_monthly_report_dialog.dart` | **New.** `PublicDemoMonthlyReportDialog`. |
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | +`_maybeShowMonthlyReport` (~40 lines incl. doc comment) and 5×2-line insertions (`closedMonth` capture + `await _maybeShowMonthlyReport(...)`) into `april()`/`may()`/`june()`/`july()`/`closeOrdinaryMonth()`. No other line changed. |
| `test/ui/public_demo/public_demo_monthly_report_display_data_test.dart` | **New.** 8 focused presenter/Hiyori tests. |
| `test/ui/public_demo/public_demo_01_monthly_report_test.dart` | **New.** 15 focused wiring/presentation tests. |
| `test/ui/public_demo/public_demo_tab_test_helpers.dart` | +`dismissMonthlyReportIfPresent`; `switchPublicDemoTab`/`dismissMonthGuardIfPresent` now also call it. |
| 17 other `test/ui/public_demo/*.dart` files | Each file's own local `tapAndSettle`/`dismiss`/`_dismissAnyMonthCloseDialogs`-equivalent helper gained one additional, no-op-safe call to `dismissMonthlyReportIfPresent` — see §11 finding 1. No assertion, fixture, or production-facing behavior changed in any of these files. |
| `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` | +1 Update-history entry recording this phase. |
| `docs/reports/SES_FIRST-FUN-YEAR_Monthly-Management-Report_PhaseB_Result.md` | **New** — this report. |

No Finance/Payroll/Recruitment/Sales/Assignment/monthly-close/Month-Guard/`PublicDemoSaveCodec`/HOME file was touched.

## 3. UI architecture

Two new files, mirroring the Year-End precedent (`PublicDemoYearEndDisplayData`/`PublicDemoYearEndResultCard`) exactly:

- `lib/ui/public_demo/public_demo_monthly_report_display_data.dart` — `PublicDemoMonthlyReportDisplayData` (pure presenter, built once from an already-`isReady` snapshot) + `publicDemoMonthlyReportHiyoriComment` (pure function).
- `lib/ui/public_demo/public_demo_monthly_report_dialog.dart` — `PublicDemoMonthlyReportDialog`, a `StatelessWidget` wrapping a plain `AlertDialog` with a `SingleChildScrollView` body. Calls no aggregate/state/workflow command; its only action is "翌月へ進む" (`Navigator.of(context).pop()`).

No display logic was added directly to the ~5,500-line `public_demo_01_placeholder_screen.dart` beyond the ~35-line `_maybeShowMonthlyReport` call-site method and the five one-line `closedMonth`/await-call insertions into the existing handlers.

## 4. Displayed fields (safe authority only)

| Section | Fields | Source |
|---|---|---|
| 対象月 | `closedMonth` | `snapshot.requestedMonth` |
| 現金 | 月初→月末、増減 | `cashFlow.openingCash`/`closingCash`/`netCashMovement` |
| 売上・入金 | 売上、入金、売掛金 | `cashFlow.revenue`/`cashReceived`/`receivables` |
| 支出 | 合計、給与、固定費、賞与、研修費、採用費 | `cashFlow.totalOutflow`/`salaryPaid`/`fixedCostsPaid`/`bonusPaid`/`trainingCost`/`recruitmentCost` |
| 純利益相当 | `revenue - totalOutflow` | `cashFlow.netIncome` (Phase A getter) |
| 社員 | 参画人数、待機人数 | `snapshot.assignedEngineers.length`/`waitingEngineers.length` |
| 翌月入社予定 | 氏名一覧 | `snapshot.confirmedNextMonthJoinApplicantIds` resolved against `workflow.applicants` (name lookup only, no new judgment) |
| ひよりから一言 | 1〜2文 | `publicDemoMonthlyReportHiyoriComment` — branches only on `cashDelta` sign and `waitingCount`/`assignedCount` (the exact safe authorities Issue #232 §6 names) |

## 5. Excluded fields (unsafe — per Issue #232 §5 / Fresh Audit GAP)

- 今月の採用人数・今月の受注人数・今月新規参画人数 (no "when did this happen" field exists on `PublicDemoApplicant`/`PublicDemoAssignment`)
- 参画人数の前月比/増加/安定 (no historical snapshot retained between months)
- `joinedApplicantIds`の累積値を「今月の採用人数」として使わない

No new economic threshold was introduced anywhere in this phase.

## 6. Hiyori comment

`publicDemoMonthlyReportHiyoriComment` (`public_demo_monthly_report_display_data.dart`) is a pure function, no AI generation, directly modeled on `publicDemoYearEndHiyoriSummary`'s own precedent. It branches only on:
- `cashDelta < 0` / `> 0` / `== 0` (mirrors `PublicDemoMonthlyCashFlow.netCashMovement`'s own sign — not a new threshold)
- `waitingCount > 0`
- `assignedCount > 0` (when `waitingCount == 0`)

`PublicDemoCashStatusPresentation`'s forward-looking cash-danger presenter was deliberately **not** integrated in this phase (see §12 Known Limitations) — it requires a separately-built `PublicDemoCashForecastResult` the snapshot does not carry, and Issue #232 explicitly forbids inventing a new economic threshold to substitute for it.

## 7. Bankruptcy / Year-End

Both existing terminal surfaces (`_bankruptcyTerminalCard()`, gated by `s.isFinanciallyTerminal`, and `PublicDemoYearEndResultCard`, gated by `s.fiscalYearCompleted`) are purely state-driven inside `build()` — neither is called imperatively from any close handler. The Report dialog never suppresses or duplicates either: once dismissed, the screen's normal `build()` re-evaluates the same unchanged conditions and shows the terminal card exactly as before this phase. Verified directly by widget tests (§9).

## 8. Save schema

Unchanged (`schemaVersion` stays `1`). `PublicDemoMonthlyReportDisplayData` and `PublicDemoMonthlyReportDialog` have no `toJson`/`fromJson` — both are transient, presentation-only classes, matching `PublicDemoMonthlyReportSnapshot`'s own Phase A precedent. No `PublicDemoSaveCodec` file was touched.

## 9. Tests

Flutter 3.44.9 (stable), same as Phase A.

### New focused tests

- `test/ui/public_demo/public_demo_monthly_report_display_data_test.dart` (8 tests): presenter mapping (every `PublicDemoMonthlyReportDisplayData` field agrees field-for-field with the underlying `PublicDemoMonthlyCashFlow`/snapshot; `nextMonthJoinNames` resolves real applicant names), and all four `publicDemoMonthlyReportHiyoriComment` branches (cash delta `<0`/`>0`/`==0`, `waitingCount>0`, `waitingCount==0 && assignedCount>0`, and an explicit assertion the comment never claims an in-month delta).
- `test/ui/public_demo/public_demo_01_monthly_report_test.dart` (15 tests): all 5 close handlers (april/may/june/july/closeOrdinaryMonth) show the report with the correct title and field values; dismissing the report advances the month exactly once and never re-closes; a blocked/no-op close (Month Guard cancel, an unconfirmed summer-bonus decision) never shows a report; a close that commits bankruptcy shows the report first, then dismissing it reveals the unmodified, unduplicated bankruptcy terminal card; March's close completing the fiscal year shows the report first, then dismissing it reveals the unmodified Year-End result card on the accounting tab; a save/reload regression proving the report itself never triggers an extra save (exactly one save per close, matching pre-Phase-B behavior); and 4 mobile-width/text-scale tests (360×800, 390×844, each at TextScaler 1.0 and 1.3) with no overflow (`tester.takeException()` asserted null throughout).

```
flutter test test/ui/public_demo/public_demo_01_monthly_report_test.dart \
              test/ui/public_demo/public_demo_monthly_report_display_data_test.dart
```
→ **23/23 passed.**

### Full regression

```
flutter test test/ui/public_demo
```
→ **583/583 passed**, 0 failed — the entire Public Demo UI suite, including every named regression target: Month Guard (`public_demo_01_month_guard_april_may_june_test.dart`, `public_demo_01_month_guard_recommended_test.dart`), single-month advance (`public_demo_01_single_month_advance_cta_test.dart`), Bankruptcy (`public_demo_01_bankruptcy_ux_test.dart`), Year-End (`public_demo_01_year_end_result_test.dart`, `public_demo_year_end_display_data_test.dart`), and Employee clarity/roster (`public_demo_issue231_employee_skillsheet_clarity_test.dart` — Issue #231/PR #233, `public_demo_employee_roster_phase_b1_test.dart` — Issue #235/PR #236, plus `public_demo_employee_ui_phase1_test.dart`/`public_demo_employee_visual_complete_test.dart`).

```
flutter test test/game/public_demo
```
→ **858/858 passed**, 0 failed — unchanged from before this phase (no domain file was touched).

### `flutter analyze`

```
Analyzing smile_enjoy_story...
No issues found!
```

### `git diff --check`

Exit code `0` — no trailing-whitespace/conflict-marker issues.

### Incidental cleanup

`flutter test` regenerated 4 unrelated visual-regression PNGs under `docs/reports/screenshots/` (a pre-existing golden-image side effect of an unrelated test, same as Phase A's own report notes). Reverted (`git checkout --`) before committing — this PR's diff never includes them.

## 10. Known Limitations

1. **Report-open-during-reload**: if the app reloads while the Monthly Management Report is open, the Report itself is lost (it is not part of saved state) — the underlying domain state/save result is unaffected and correct. Accepted per Issue #232 §8 as an explicit Phase B known limitation (no save-schema benefit to persisting a "report seen" flag).
2. **No forward-looking cash-danger integration**: `PublicDemoCashStatusPresentation`'s forecast-based risk presenter was not wired into the Hiyori comment (see §6) — a future phase could add this without a new threshold, by building the same `PublicDemoCashForecastResult` HOME's own cash-shortage card already computes.
3. **No month-over-month comparison** ("前月比"): the current `PublicDemoMonthlyReportSnapshot` only carries a single closed month's figures; a "vs. last month" comparison would need either a new domain fact or a caller-held prior snapshot, both out of this phase's scope.

## 11. Self-hardening

Checked directly against the diff and confirmed by the widget test suite:

- **Close double-execution**: `_maybeShowMonthlyReport` never calls `closeX(...)`; it only reads `_game` after `_commitAggregate` already ran. No handler calls `_commitAggregate` twice.
- **Wrong-month/stale snapshot**: `closedMonth` is captured via `final closedMonth = s.month;` immediately before each `_commitAggregate(...)` — the exact value the snapshot is asked to confirm against `latestMonthlyCashFlow.month`.
- **Dialog duplication**: exactly one `showDialog` call site (`_maybeShowMonthlyReport`), gated by `snapshot.isReady`; `test 2` (dismiss advances the month exactly once) and `test 3` (blocked/no-op close never shows a report) both assert this directly.
- **Terminal regression**: `_bankruptcyTerminalCard()`/`PublicDemoYearEndResultCard` stay purely `build()`-driven; `test 4`/`test 5` prove the report never skips or duplicates either.
- **Save regression**: `test 6` proves exactly one save occurs per close (before the report ever appears) and dismissing the report triggers no further save.
- **Mobile overflow**: `test 7` (4 cases: 360×800/390×844 × TextScaler 1.0/1.3) asserts `tester.takeException()` is null throughout, including with the dialog open and after dismissing it.
- **Authority duplication**: the presenter reads only `PublicDemoMonthlyReportSnapshot`'s own already-computed fields (and `workflow.applicants` for a name lookup) — no Finance/Payroll/Recruitment/Assignment fact is recomputed.
- **Hardcoded finance threshold**: `publicDemoMonthlyReportHiyoriComment` branches only on `cashDelta`'s sign and plain headcount comparisons (`>0`/`==0`) — no new numeric threshold anywhere in this phase.

### Findings fixed before commit

1. **Test-suite regression from inserting a new modal into the existing close flow.** Wiring the Report dialog into all five close handlers meant every *existing* test that drives a month close through the real UI CTA and then continues interacting with the screen would otherwise hit the new dialog's modal barrier and fail a hit-test. Fixed by adding a shared `dismissMonthlyReportIfPresent` helper to `public_demo_tab_test_helpers.dart` (and wiring it into `switchPublicDemoTab`/`dismissMonthGuardIfPresent`), then adding the same no-op-safe dismissal call to each affected file's own local `tapAndSettle`/`dismiss` helper (17 test files touched, all additive — no assertion or production behavior was changed, only make each helper also dismiss a just-appeared report before continuing). Verified by the full 583/583 green run in §9.
2. **Infinite loop in this PR's own new Year-End test fixture.** The first draft of the Year-End test built its March fixture with the real `PublicDemoSalary.baselineMonthlyExpenses` and zero revenue across 11 months — the same zero-engagement trajectory the Bankruptcy test deliberately uses to reach bankruptcy by October. Driven all the way to month 15, that trajectory goes `isCloseBlocked` (bankrupt) long before March, so `closeOrdinaryMonth` becomes a permanent no-op and the fixture-building `while (aggregate.state.month < 15)` loop never terminates (a genuine, CPU-spinning infinite loop, confirmed via `ps` — a `flutter_tester` process pinned at ~100% CPU for minutes with no I/O wait). Fixed by using a small, flat `monthlyExpenses` (`10000`, matching the existing `publicDemoAggregateAtMonth` test-helper precedent) for this fixture's own loop, plus an `expect(aggregate.state.isCloseBlocked, isFalse)` assertion inside the loop as defense-in-depth against the same bug class recurring after a future balance-tuning change.
3. **A test helper's own trailing auto-dismiss silently eating the report before this PR's own assertions could see it.** After fix 1 above, `dismissMonthGuardIfPresent` (used everywhere else in the suite) also dismisses a just-appeared report as a safety net — but this PR's own `public_demo_01_monthly_report_test.dart` needs to assert the report is genuinely showing *before* deliberately dismissing it, so calling that same shared helper there would defeat its own tests. Fixed with a file-local `_proceedPastGuardOnly` (proceeds past the Month Guard only, no report side-effect) used throughout that one file instead.

No P0/P1/P2 findings remained unresolved at the end of this pass.

## 12. PR / review status

PR: https://github.com/perusonao/smile_enjoy_story/pull/237
No PR was merged by this task, as instructed — left open for the repository owner to review and merge.

---

_Generated by [Claude Code](https://claude.ai/code)_
