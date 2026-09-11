# SES First Fun Year — Monthly Management Report Phase B: Dialog/UI Integration — Result Report

Status: **Implemented — Phase B (Dialog/UI + 5 close-handler integration), plus Codex Broad Review P2 follow-up (2 findings, both fixed). Builds directly on Phase A's `PublicDemoMonthlyReportSnapshot` authority (PR #234). No save-schema change, no new domain authority, no Finance/Payroll/Recruitment/Assignment/Month Guard change.**

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
    isFiscalYearCompleted: s.fiscalYearCompleted,
    isFinanciallyTerminal: s.isFinanciallyTerminal,
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
| `test/ui/public_demo/public_demo_monthly_report_display_data_test.dart` | **New**, then +3 tests in the Codex P2 follow-up (group 5: terminal Hiyori branches). 11 focused presenter/Hiyori tests total. |
| `test/ui/public_demo/public_demo_01_monthly_report_test.dart` | **New**, then updated in the Codex P2 follow-up (CTA-label + terminal-Hiyori assertions added to the existing April/Bankruptcy/Year-End tests, no new test cases). 15 focused wiring/presentation tests total. |
| `test/ui/public_demo/public_demo_tab_test_helpers.dart` | +`dismissMonthlyReportIfPresent`; `switchPublicDemoTab`/`dismissMonthGuardIfPresent` now also call it. |
| 17 other `test/ui/public_demo/*.dart` files | Each file's own local `tapAndSettle`/`dismiss`/`_dismissAnyMonthCloseDialogs`-equivalent helper gained one additional, no-op-safe call to `dismissMonthlyReportIfPresent` — see §11 finding 1. No assertion, fixture, or production-facing behavior changed in any of these files. |
| `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` | +1 Update-history entry recording this phase. |
| `docs/reports/SES_FIRST-FUN-YEAR_Monthly-Management-Report_PhaseB_Result.md` | **New** — this report. |

### Codex Broad Review P2 follow-up (this update)

| file | change |
|---|---|
| `lib/ui/public_demo/public_demo_monthly_report_display_data.dart` | +2 required fields (`isFiscalYearCompleted`, `isFinanciallyTerminal`) on `PublicDemoMonthlyReportDisplayData`, both read verbatim from the caller's already-committed `PublicDemoState`; `publicDemoMonthlyReportHiyoriComment` gains 2 new branches (terminal/year-end) checked before the existing waiting/assigned branch. |
| `lib/ui/public_demo/public_demo_monthly_report_dialog.dart` | Dismiss button's label is now `_isYearEndClose ? '年度結果を見る' : '翌月へ進む'`, where `_isYearEndClose` reads `data.closedMonth == 15` — no new field needed for this one, since `closedMonth` was already exposed. |
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | The single `PublicDemoMonthlyReportDisplayData.fromSnapshot` call site now also passes `isFiscalYearCompleted: s.fiscalYearCompleted` / `isFinanciallyTerminal: s.isFinanciallyTerminal` — both already-existing `PublicDemoState` getters, read from the same already-committed aggregate every other field already comes from. |
| `test/ui/public_demo/public_demo_monthly_report_display_data_test.dart` | +1 new group (3 tests): bankruptcy+waiting never recommends sales, year-end+waiting never recommends sales, an ordinary month+waiting keeps the existing sales advice unchanged. |
| `test/ui/public_demo/public_demo_01_monthly_report_test.dart` | The existing April test (group 1) gained a CTA-label assertion (`'翌月へ進む'` present, `'年度結果を見る'` absent); the existing Bankruptcy test (group 4) and Year-End test (group 5) each gained an assertion that the visible Hiyori comment text contains no Sales-tab wording, plus the Year-End test gained the CTA-label assertion in the other direction. |

No Finance/Payroll/Recruitment/Sales/Assignment/monthly-close/Month-Guard/`PublicDemoSaveCodec`/HOME file was touched, in either the initial submission or this follow-up.

## 3. UI architecture

Two new files, mirroring the Year-End precedent (`PublicDemoYearEndDisplayData`/`PublicDemoYearEndResultCard`) exactly:

- `lib/ui/public_demo/public_demo_monthly_report_display_data.dart` — `PublicDemoMonthlyReportDisplayData` (pure presenter, built once from an already-`isReady` snapshot) + `publicDemoMonthlyReportHiyoriComment` (pure function).
- `lib/ui/public_demo/public_demo_monthly_report_dialog.dart` — `PublicDemoMonthlyReportDialog`, a `StatelessWidget` wrapping a plain `AlertDialog` with a `SingleChildScrollView` body. Calls no aggregate/state/workflow command; its only action pops the route (`Navigator.of(context).pop()`), labeled "翌月へ進む" for every ordinary month and "年度結果を見る" for March (`closedMonth == 15`) — see the Codex Broad Review P2 follow-up in §2.1/§11.

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
| ひよりから一言 | 1〜2文 | `publicDemoMonthlyReportHiyoriComment` — branches on `cashDelta` sign, `waitingCount`/`assignedCount` (the exact safe authorities Issue #232 §6 names), and — since the Codex Broad Review P2 follow-up — `isFinanciallyTerminal`/`isFiscalYearCompleted` (both already-existing `PublicDemoState` authority, see §6/§11) |

## 5. Excluded fields (unsafe — per Issue #232 §5 / Fresh Audit GAP)

- 今月の採用人数・今月の受注人数・今月新規参画人数 (no "when did this happen" field exists on `PublicDemoApplicant`/`PublicDemoAssignment`)
- 参画人数の前月比/増加/安定 (no historical snapshot retained between months)
- `joinedApplicantIds`の累積値を「今月の採用人数」として使わない

No new economic threshold was introduced anywhere in this phase.

## 6. Hiyori comment

`publicDemoMonthlyReportHiyoriComment` (`public_demo_monthly_report_display_data.dart`) is a pure function, no AI generation, directly modeled on `publicDemoYearEndHiyoriSummary`'s own precedent. It branches only on:
- `cashDelta < 0` / `> 0` / `== 0` (mirrors `PublicDemoMonthlyCashFlow.netCashMovement`'s own sign — not a new threshold)
- `isFinanciallyTerminal` (Codex Broad Review P2 follow-up — checked before the two branches below)
- `isFiscalYearCompleted` (same follow-up, checked next)
- `waitingCount > 0`
- `assignedCount > 0` (when `waitingCount == 0`)

The cash-movement sentence (first bullet above) is unconditional and unchanged by the P2 follow-up — it is still a true statement about the month regardless of terminal status. Only the *second* sentence's content is now gated: a terminal or year-end-complete close no longer reaches the "営業タブから案件参画を進めましょう" wording at all (see §11).

`PublicDemoCashStatusPresentation`'s forward-looking cash-danger presenter was deliberately **not** integrated in this phase (see §12 Known Limitations) — it requires a separately-built `PublicDemoCashForecastResult` the snapshot does not carry, and Issue #232 explicitly forbids inventing a new economic threshold to substitute for it.

## 7. Bankruptcy / Year-End

Both existing terminal surfaces (`_bankruptcyTerminalCard()`, gated by `s.isFinanciallyTerminal`, and `PublicDemoYearEndResultCard`, gated by `s.fiscalYearCompleted`) are purely state-driven inside `build()` — neither is called imperatively from any close handler. The Report dialog never suppresses or duplicates either: once dismissed, the screen's normal `build()` re-evaluates the same unchanged conditions and shows the terminal card exactly as before this phase. Verified directly by widget tests (§9).

**Codex Broad Review P2 follow-up (this update):** the Report itself did not originally acknowledge a terminal close at all — its dismiss CTA always read "翌月へ進む" even for March/year-end (where dismissing never advances a month), and its Hiyori comment could recommend "営業タブから案件参画を進めましょう" even after bankruptcy or fiscal-year completion, when the Sales tab's own next-action slot is itself already suppressed for the same reason (`HomeRecommendedActionSuppressed`). Both are fixed — see §2.1/§6/§11 — without introducing any new terminal-detection logic: both fixes read `PublicDemoState.isFinanciallyTerminal`/`fiscalYearCompleted`, the exact same authority `_bankruptcyTerminalCard`/`PublicDemoYearEndResultCard` already gate on.

## 8. Save schema

Unchanged (`schemaVersion` stays `1`). `PublicDemoMonthlyReportDisplayData` and `PublicDemoMonthlyReportDialog` have no `toJson`/`fromJson` — both are transient, presentation-only classes, matching `PublicDemoMonthlyReportSnapshot`'s own Phase A precedent. No `PublicDemoSaveCodec` file was touched.

## 9. Tests

Flutter 3.44.9 (stable), same as Phase A.

### New focused tests

- `test/ui/public_demo/public_demo_monthly_report_display_data_test.dart` (11 tests): presenter mapping (every `PublicDemoMonthlyReportDisplayData` field agrees field-for-field with the underlying `PublicDemoMonthlyCashFlow`/snapshot; `nextMonthJoinNames` resolves real applicant names), all four ordinary-month `publicDemoMonthlyReportHiyoriComment` branches (cash delta `<0`/`>0`/`==0`, `waitingCount>0`, `waitingCount==0 && assignedCount>0`, and an explicit assertion the comment never claims an in-month delta), plus (Codex P2 follow-up) 3 terminal-state branches: `isFinanciallyTerminal`+waiting never recommends Sales-tab action, `isFiscalYearCompleted`+waiting never recommends Sales-tab action, and an ordinary month+waiting keeps the pre-existing sales advice unchanged.
- `test/ui/public_demo/public_demo_01_monthly_report_test.dart` (15 tests): all 5 close handlers (april/may/june/july/closeOrdinaryMonth) show the report with the correct title and field values, and (Codex P2 follow-up) the April test now also asserts the dismiss CTA reads "翌月へ進む" (not "年度結果を見る"); dismissing the report advances the month exactly once and never re-closes; a blocked/no-op close (Month Guard cancel, an unconfirmed summer-bonus decision) never shows a report; a close that commits bankruptcy shows the report first (now also asserting the visible Hiyori text contains no Sales-tab wording and does contain the backward-looking bankruptcy line), then dismissing it reveals the unmodified, unduplicated bankruptcy terminal card; March's close completing the fiscal year shows the report first (now also asserting the dismiss CTA reads "年度結果を見る" and the visible Hiyori text contains no Sales-tab wording), then dismissing it reveals the unmodified Year-End result card on the accounting tab; a save/reload regression proving the report itself never triggers an extra save (exactly one save per close, matching pre-Phase-B behavior); and 4 mobile-width/text-scale tests (360×800, 390×844, each at TextScaler 1.0 and 1.3) with no overflow (`tester.takeException()` asserted null throughout).

```
flutter test test/ui/public_demo/public_demo_01_monthly_report_test.dart \
              test/ui/public_demo/public_demo_monthly_report_display_data_test.dart
```
→ **26/26 passed.**

### Full regression

```
flutter test test/ui/public_demo
```
→ **586/586 passed**, 0 failed — the entire Public Demo UI suite, including every named regression target: Month Guard (`public_demo_01_month_guard_april_may_june_test.dart`, `public_demo_01_month_guard_recommended_test.dart`), single-month advance (`public_demo_01_single_month_advance_cta_test.dart`), Bankruptcy (`public_demo_01_bankruptcy_ux_test.dart`), Year-End (`public_demo_01_year_end_result_test.dart`, `public_demo_year_end_display_data_test.dart`), and Employee clarity/roster (`public_demo_issue231_employee_skillsheet_clarity_test.dart` — Issue #231/PR #233, `public_demo_employee_roster_phase_b1_test.dart` — Issue #235/PR #236, plus `public_demo_employee_ui_phase1_test.dart`/`public_demo_employee_visual_complete_test.dart`).

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

No P0/P1/P2 findings remained unresolved at the end of this pass — this initial self-hardening pass itself found **0 P2s** (its checklist covered close-order/snapshot/dialog/terminal/save/mobile/authority/threshold correctness, none of which caught the two copy-truthfulness gaps below).

### Codex Broad Review P2 findings (found after the initial submission, both fixed in this update)

PR #237's Codex Broad Review, requested after the above self-hardening pass and initial submission, found 2 P2s that self-hardening's own checklist had not covered — both about the Report's *copy* staying truthful once the close it describes is terminal, not about mutation/authority correctness:

4. **P2-1 — Year-End CTA said "翌月へ進む" even when dismissing never advances a month.** March's close (`closedMonth == 15`) sets `fiscalYearCompleted` (or, on a March cash-shortage failure, `isFinanciallyTerminal`) and never advances the internal month past 15 — dismissing the report instead reveals the Year-End result or the bankruptcy-style terminal card. The dismiss button's label is now conditional: `data.closedMonth == 15` → "年度結果を見る", every other month → unchanged "翌月へ進む". Read directly off `PublicDemoMonthlyReportDisplayData.closedMonth`, already exposed — no new field or domain authority needed. Fixed in `public_demo_monthly_report_dialog.dart` (`_isYearEndClose`).
   - Review thread: https://github.com/perusonao/smile_enjoy_story/pull/237#discussion_r3982798693 (replied and resolved).
5. **P2-2 — Terminal Hiyori comment recommended an action the player could no longer take.** Once a close committed bankruptcy or completed the fiscal year, `publicDemoMonthlyReportHiyoriComment` could still tell a player with waiting engineers to "営業タブから案件参画を進めましょう" — but `s.isCloseBlocked` is now true and the Sales tab's own next-action slot is itself already suppressed for that exact reason. Fixed by threading two new, already-existing `PublicDemoState` facts (`isFiscalYearCompleted`, `isFinanciallyTerminal`) onto `PublicDemoMonthlyReportDisplayData` (read from the same already-committed aggregate every other field already comes from — no new authority, no new economic threshold) and checking them first in the Hiyori function: terminal → "今月の結果を振り返り、次の経営に活かしましょう。"; year-end-complete → "1年間の経営結果を確認しましょう。"; otherwise the pre-existing waiting/assigned branches run completely unchanged. The cash-movement sentence (this function's first sentence) is untouched in every case.
   - Review thread: https://github.com/perusonao/smile_enjoy_story/pull/237#discussion_r3982798702 (replied and resolved).

No Broad Review was re-requested for this follow-up, per instruction. No P0/P1/P2 remained unresolved after this update.

## 12. PR / review status

PR: https://github.com/perusonao/smile_enjoy_story/pull/237
Codex Broad Review: already completed before this update — not re-requested, per instruction. Both P2 findings fixed (§11) and replied to on their own review threads, then resolved via `resolve_review_thread`.
No PR was merged by this task, as instructed — left open for the repository owner to review and merge.

---

_Generated by [Claude Code](https://claude.ai/code)_
