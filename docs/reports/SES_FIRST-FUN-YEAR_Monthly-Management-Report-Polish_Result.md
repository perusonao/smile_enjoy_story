# SES FIRST-FUN-YEAR Monthly Management Report Polish — Result Report

Issue: #250 — FIRST-FUN-YEAR Monthly Management Report Polish — 固定費内訳・Hiyori・助言・One-Screen

Status: **Completed**

BASE: `origin/main` @ `01829f30f00fc7e923bacd355c4e4ffca131cc4e` (post-merge of PR #249)
HEAD: `2536f08dde923363485902683b7f9bc3fc6db070`

Branch: `claude/first-fun-year-report-polish-ql76ss`

PR #247 (Partner Interview B1+B2, unmerged at branch-creation time) was **not** pulled in — this branch was created directly from `origin/main`, never from PR #247's branch, and touches none of the files PR #247 changes (Partner Interview / `PublicDemoProjectInterviewDialog` / `PublicDemoInterviewResultDialog`).

## Phase 0 — Fresh Audit (summary)

Read Issue #250 and `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` first, then audited the existing Monthly Management Report authority (Issue #232 Phase A/B, PR #234/#237 — already merged and in production):

1. **Expense breakdown authority** — `PublicDemoMonthlyCashFlow` (`lib/game/public_demo/public_demo_monthly_cash_flow.dart`) already separates `salaryPaid`/`fixedCostsPaid`/`bonusPaid`/`trainingCost`/`recruitmentCost`, and `PublicDemoMonthlyReportDialog` already rendered every one of them (bonus/training/recruitment only `if > 0`, i.e. already "actual value only, from the existing snapshot" per Issue's own instruction). **No new expense authority was needed for item 1** — Fresh Audit found the 給与/固定費 distinction Issue #250 §1 asks for was already implemented in PR #237. The one real gap: `fixedCostsPaid` is a single aggregate constant (`PublicDemoSalary.otherMonthlyFixedCost`, ¥50,000/month) with **no further per-category authority** (no rent/utilities split exists anywhere in the codebase — confirmed via `docs/reports/SES_FIRST-FUN-YEAR_Seeded-Balance-Fix_Result.md`'s own "rent+utilities+etc. aggregate" note, the only documented composition). Fabricating a per-category breakdown was therefore out of scope (guardrail: "新しい推計会計値を作らない"); a short composition **caption** naming what the existing single figure already covers was safe and is what got implemented.
2. **Hiyori** — `publicDemoMonthlyReportHiyoriComment` (PR #237) already existed as a pure, fact-only function following the exact `publicDemoYearEndHiyoriSummary` (YEAR-END-PHASE-1) precedent. It already branched safely on `cashDelta` sign and `waitingCount`/`assignedCount`, and (PR #237 Codex P2) on `isFinanciallyTerminal`/`isFiscalYearCompleted`. Gap: it never mentioned 黒字/赤字 (net income sign) or 次月入社 (confirmed next-month joins), both of which Issue #250 §2 names and both of which were **already-available fields** on the same display-data class (`netIncome`, `nextMonthJoinNames`) — no new authority needed. For the portrait, `HomeNavigatorIdentity.portraitAssetFor(NavigatorExpression.normal)` (`lib/presentation/home/models/home_navigator_display.dart`) was already reused **outside HOME** by `PublicDemoOpeningContextScreen`'s own `_NavigatorIntro` (`lib/ui/public_demo/public_demo_opening_context_screen.dart`) — confirming this asset/pattern is safe to reuse in a second non-HOME surface without touching HOME itself (HOME Freeze respected).
3. **次に考えること (next-month advice)** — did not exist in the report at all. Fresh Audit found `HomeRecommendedActionKind`/`selectHomeRecommendedAction` (`lib/presentation/home/models/home_recommended_action.dart`, HOME-RUNTIME-2C) is the exact existing "one thing to do next" authority already driving HOME's own recommended-action slot, and it already:
   - suppresses itself (`HomeRecommendedActionSuppressed`) whenever `PublicDemoState.isCloseBlocked` holds (bankruptcy, a March cash-shortage failure, or fiscal-year completion) — i.e. it already satisfies Issue #250's "bankruptcy/year-endでは不可能なfuture actionを出さない" requirement, with zero new logic;
   - is read by the owner screen's own `_recommendedActionSlot` getter (`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`), which is evaluated fresh on every build from the already-committed `_game`/`workflow`/`s` — reading it once more, immediately after a close commits, requires no new state and cannot go stale.

   This authority was reused **read-only**: the report never invokes `HomeRecommendedActionCandidate.invoke` (no button — only the plain `headline` text is displayed), so nothing here can mutate any aggregate/state/workflow, and no aggregate mutation / double month-close risk is introduced.
4. **One-Screen** — the existing dialog already used `SingleChildScrollView` and already passed the existing 360×800/390×844 × TextScaler 1.0/1.3 "no overflow" tests (`public_demo_01_monthly_report_test.dart` group 7, unchanged and still green). Measuring the *actual* scroll extent (not just "no `RenderFlex` overflow exception") showed the pre-existing content already needed to scroll well before any Issue #250 addition — confirmed and then closed via a density pass (see §4 below), never via font shrinking.

**Fresh Audit verdict: GO — every Issue #250 requirement is reachable from existing, already-committed authority** (`PublicDemoMonthlyCashFlow`, `PublicDemoMonthlyReportSnapshot`/`PublicDemoMonthlyReportDisplayData`, `HomeNavigatorIdentity`, `HomeRecommendedActionKind`/`selectHomeRecommendedAction`/`_recommendedActionSlot`). No new economic authority, no save-schema field, and no Finance/Payroll/Matching formula change was needed anywhere in this implementation.

## Implementation

### 1. Expense breakdown clarity
- `_ReportStatRow` (`lib/ui/public_demo/public_demo_monthly_report_dialog.dart`) gained an optional `caption` line (small grey text under the value). Used only on the 固定費 row: `（家賃・水道光熱費など）`, describing the existing single aggregate figure's documented composition — no new per-category value, no new field.
- The 現金 section's two rows (月初→月末 / 今月の増減) were merged into one combined row (`月初 → 月末（今月の増減）`) — same three numbers, one fewer row, part of the One-Screen density pass (§4).
- 給与/固定費/賞与/研修費/採用費 breakdown itself is unchanged from PR #237 (already correct per Fresh Audit).

### 2. Hiyori
- `publicDemoMonthlyReportHiyoriComment` (`lib/ui/public_demo/public_demo_monthly_report_display_data.dart`) gained two new sentence branches, both restating an already-existing field on `PublicDemoMonthlyReportDisplayData`:
  - `netIncome` sign → "今月の収支は黒字（純利益¥X）でした。" / "…赤字（純損失¥X）でした。" (skipped, not fabricated, when `netIncome == 0`).
  - `nextMonthJoinNames` → "来月は{name}さん・{name}さんが入社予定です。", **only** when the game is neither terminal nor fiscal-year-complete (mirrors `nextActionHeadline`'s own gate — "次月" does not exist once the game is over).
  - The original cash-delta sentence's two generic filler clauses ("支出とのバランスに注意しましょう。"/"良いペースです。") were dropped in favor of the new, more concrete 黒字/赤字 sentence — less repetitive copy and part of the density pass; no existing test named that exact wording (verified before removing).
- `PublicDemoMonthlyReportDialog` now shows a small (36×36) ひより portrait beside her comment, reusing `HomeNavigatorIdentity.portraitAssetFor(NavigatorExpression.normal)` — the exact asset/pattern `PublicDemoOpeningContextScreen`'s own `_NavigatorIntro` already uses outside HOME, with the same icon-fallback degrade path on a decode failure. No new asset, no name/role text repeated (the "ひよりから一言" heading already establishes who is speaking).

### 3. 次に考えること (next-month advice)
- `PublicDemoMonthlyReportDisplayData` gained one new field, `nextActionHeadline` (`String?`), documented as a plain passthrough with no gating of its own.
- `PublicDemo01PlaceholderScreen._maybeShowMonthlyReport` (the sole call site, unchanged wiring point from PR #237) now also reads its own pre-existing `_recommendedActionSlot` getter immediately after the close commits, and passes `HomeRecommendedActionAvailable.candidate.action.headline` through (or `null` when `HomeRecommendedActionNone`/`HomeRecommendedActionSuppressed`). This is a **read of an existing getter**, not a new command call.
- The dialog renders a "次に考えること" section with that headline text **only when non-null** — omitted entirely for bankruptcy, the March cash-shortage failure, and fiscal-year completion, confirmed by both a dedicated dialog-level test (`isFinanciallyTerminal: true` → section absent) and by the real production Bankruptcy/Year-End integration tests (`public_demo_01_monthly_report_test.dart` groups 4/5), which now additionally assert the `next-action` key is absent.
- No CTA/button is rendered for this section — text only. The report cannot invoke a Recovery/SkillSheet/etc. command, so no new aggregate-mutation path exists.

### 4. One-Screen / density pass
Applied to `PublicDemoMonthlyReportDialog` only (no HOME file touched):
- Compact `insetPadding`/`titlePadding`/`contentPadding`/`actionsPadding` on the `AlertDialog` (the same compact-`insetPadding` technique `PublicDemoProjectInterviewDialog`/`PublicDemoRecruitmentInterviewDialog` already use elsewhere in Public Demo).
- Tightened `_ReportSectionHeader`/`_ReportStatRow` vertical padding.
- Merged the 現金 section's two rows into one (see §1).
- Tightened the dismiss `FilledButton`'s own padding (touch target kept at a normal, non-shrunk size — `MaterialTapTargetSize.shrinkWrap` was deliberately **not** used, to avoid an accessibility regression).
- **No font size was reduced anywhere** — every change is spacing/row-count only, per the Issue's "極端な文字縮小は禁止" guardrail.

Net effect (measured via `ScrollableState.position.maxScrollExtent` in a new widget test): the pre-existing content already needed to scroll at 360×800 before this pass (255px of forced scroll, even before this Issue's own additions were counted); after the pass, the **normal-case fixture (no bonus/training/recruitment/next-month-join, i.e. an ordinary month) fits with `maxScrollExtent == 0`** at 360×800 / TextScaler 1.0 — the literal "通常ケースはスクロール不要" target. An exceptional month (July bonus, a training/recruitment month, or one with a confirmed next-month join) adds one or two extra rows and may still require a small scroll — this is accepted per the Issue's own wording ("目標とする", not an absolute requirement) and is exercised without any overflow exception at 360×800/390×844 × TextScaler 1.0/1.3.

## Files changed

- `lib/ui/public_demo/public_demo_monthly_report_display_data.dart` — `nextActionHeadline` field + passthrough in `.fromSnapshot`; extended `publicDemoMonthlyReportHiyoriComment` (黒字/赤字, 次月入社; dropped two filler clauses).
- `lib/ui/public_demo/public_demo_monthly_report_dialog.dart` — `_ReportStatRow.caption`; new `_HiyoriPortrait`; combined 現金 row; "次に考えること" section; One-Screen density pass (dialog paddings, header/row paddings, button padding).
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — `_maybeShowMonthlyReport` now also reads `_recommendedActionSlot` and passes its headline (or `null`) through.
- `test/ui/public_demo/public_demo_monthly_report_display_data_test.dart` — updated every existing fixture for the new required `nextActionHeadline` field; added groups 6 (黒字/赤字) and 7 (次月入社); added a `nextActionHeadline` passthrough assertion to group 1.
- `test/ui/public_demo/public_demo_01_monthly_report_test.dart` — added 固定費 caption / ひより portrait assertions to the April integration test; added "next-action section absent" assertions to the Bankruptcy and Year-End integration tests.
- `test/ui/public_demo/public_demo_monthly_report_dialog_test.dart` (**new**) — deterministic, isolated widget coverage for every ISSUE-250 dialog addition: 固定費 caption, ひより portrait, 次に考えること present/absent (including the bankruptcy-fixture documentation case), and One-Screen coverage at 360×800/390×844 × TextScaler 1.0/1.3 plus the explicit no-scroll assertion for the normal case.
- `docs/reports/SES_FIRST-FUN-YEAR_Monthly-Management-Report-Polish_Result.md` (this file, **new**).

No `lib/game/public_demo/**` file was touched — Finance/Payroll/Recruitment/Assignment/Matching/月次決算 authority is unchanged. No HOME file (`public_demo_home_dashboard_section.dart`, `home_navigator_section.dart`, `home_recommended_action.dart`, etc.) was touched — HOME Freeze is intact; `_recommendedActionSlot`/`HomeRecommendedActionKind` were only **read**, never modified.

## Authority map (no new authority)

| Report element | Authority (unchanged) |
|---|---|
| 給与/固定費/賞与/研修費/採用費 | `PublicDemoMonthlyCashFlow` fields (PR #237, unchanged) |
| 固定費 caption text | `PublicDemoSalary.otherMonthlyFixedCost`'s documented composition (`SES_FIRST-FUN-YEAR_Seeded-Balance-Fix_Result.md`) — static copy only, no new field |
| 黒字/赤字 | `PublicDemoMonthlyCashFlow.netIncome` (existing derived getter, PR #234/#237) |
| 次月入社 mention | `PublicDemoMonthlyReportSnapshot.confirmedNextMonthJoinApplicantIds` → `nextMonthJoinNames` (PR #237, unchanged) |
| ひより portrait | `HomeNavigatorIdentity.portraitAssetFor(NavigatorExpression.normal)` (NAVIGATOR-1A/HOME-COMPACT-1B.3 asset, already reused outside HOME by `PublicDemoOpeningContextScreen`) |
| 次に考えること | `HomeRecommendedActionKind`/`selectHomeRecommendedAction`/`_recommendedActionSlot` (HOME-RUNTIME-2C, read-only) |
| terminal/year-end gating (both Hiyori and 次に考えること) | `PublicDemoState.isCloseBlocked` / `isFinanciallyTerminal` / `fiscalYearCompleted` (unchanged) |

## One-Screen verification

- `test/ui/public_demo/public_demo_monthly_report_dialog_test.dart` group 4: 360×800 and 390×844, each at TextScaler 1.0 and 1.3, all four combinations `tester.takeException()` clean and the dialog present — **8 assertions, all green**.
- Same file's dedicated no-scroll assertion: 360×800 / TextScaler 1.0, normal-case fixture (no bonus/training/recruitment/next-month-join) → `ScrollableState.position.maxScrollExtent == 0` — **green**, confirming the literal "通常ケースはスクロール不要" target for an ordinary month.
- `test/ui/public_demo/public_demo_01_monthly_report_test.dart` group 7 (unchanged from PR #237, still green): the real production April fixture at 360×800/390×844 × TextScaler 1.0/1.3, dismiss CTA reachable/tappable, no overflow exception.
- No font size was reduced to reach this; only dialog/row/header padding and one row merge.

## Tests

- `flutter analyze` (whole project): **No issues found.**
- `flutter test test/game/public_demo`: **872/872 passed** (unchanged from baseline — no game-layer file was touched).
- `flutter test test/ui/public_demo`: **703/703 passed** (full suite, includes every file below).
  - `public_demo_monthly_report_display_data_test.dart`: **16/16 passed** (7 groups; new groups 6/7 for 黒字/赤字 and 次月入社).
  - `public_demo_01_monthly_report_test.dart`: **15/15 passed** (all 5 close handlers, dismiss-once, blocked/no-op, Bankruptcy, Year-End, save/reload, mobile widths — including the new 固定費 caption/ひより portrait/next-action-absent assertions).
  - `public_demo_monthly_report_dialog_test.dart` (new): **10/10 passed**.
- `git diff --check`: clean (no whitespace errors).

## Self-hardening checklist (Issue #250 §Verification)

| Case | Verified via |
|---|---|
| normal month | `public_demo_01_monthly_report_test.dart` April/May/June/August close handlers; `public_demo_monthly_report_dialog_test.dart`'s no-scroll fixture |
| loss month | `public_demo_monthly_report_display_data_test.dart` group 3/6 (`cashDelta < 0`, `netIncome < 0`) |
| bonus | July close handler (existing, unchanged; `bonusPaid > 0` row still conditional) |
| training/recruitment expense | existing conditional rows unchanged; not independently re-tested in this PR (no logic changed there) |
| bankruptcy | `public_demo_01_monthly_report_test.dart` group 4 — report shows, Hiyori never recommends an unreachable action, 次に考えること section absent, unmodified bankruptcy card revealed on dismiss |
| March/year-end | `public_demo_01_monthly_report_test.dart` group 5 — same guarantees, dismiss CTA reads "年度結果を見る", 次に考えること section absent |
| open/dismiss mutation-free | group 6 (save/reload regression) — save count unchanged by report open/dismiss; report itself calls no aggregate/state/workflow command (verified by code inspection: no `_game.copyWith`/`_commitAggregate` call anywhere in the report/dialog/display-data files) |
| save/reload regression | group 6 (unchanged from PR #237, still green) |

## Authority / guardrails

- HOME Freeze: maintained — no file under HOME's own ownership (`public_demo_home_dashboard_section.dart`, `home_navigator_section.dart`, `home_recommended_action.dart`, `recommended_action_section.dart`) was modified.
- Save schema: unchanged — `PublicDemoMonthlyReportDisplayData`/`PublicDemoMonthlyReportDialog` are non-persistent presentation classes with no `toJson`/`fromJson`; `schemaVersion` untouched.
- Finance/Payroll authority: unchanged — no file under `lib/game/public_demo/` was modified.
- Aggregate mutation from the report: none — `_recommendedActionSlot` is read, `HomeRecommendedActionCandidate.invoke` is never called from the report/dialog.
- Double month-close: not introduced — `_maybeShowMonthlyReport`'s own contract (never calls `closeX(...)` again) is unchanged; the only addition is a read of `_recommendedActionSlot` after the existing commit.
- Partner Interview / Parallel Sales: untouched (no file overlap with PR #247 or Parallel Sales work).
- No new estimated accounting value: 固定費 caption is static copy describing an existing constant's already-documented composition, not a new number.

## Known limitations / unresolved items

- The "次に考えること" advice is always the single, generically-ranked HOME recommended action (`presentationPriority`), with no report-specific reasoning text beyond the action's own headline — Issue #250 asked for "推奨理由も短く示す"; the headline itself (e.g. "佐藤 健のスキルシートを確認") communicates *what*, but not a separate *why* clause. Adding a per-`HomeRecommendedActionKind` reason string would touch ~30 enum values in a HOME-owned file and was judged out of scope for this PR's size budget; left for a future, dedicated pass if the product wants a longer explanation there.
- An exceptional month (bonus paid, training/recruitment cost, or a confirmed next-month join in the same month) adds one or two extra rows and may still require a small scroll at 360×800 — only the ordinary-month case is guaranteed scroll-free, per the Issue's own "通常ケース" wording.
- 固定費's caption ("家賃・水道光熱費など") is static, non-authoritative copy — it is not itself sourced from a per-category ledger (none exists); if a future change ever splits `otherMonthlyFixedCost` into real categories, this caption should be revisited alongside that change.

## PR

- URL: https://github.com/perusonao/smile_enjoy_story/pull/251
- Base: `main`
- Head: `claude/first-fun-year-report-polish-ql76ss`

## Final HEAD SHA

`2536f08dde923363485902683b7f9bc3fc6db070`
