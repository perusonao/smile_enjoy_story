# SES FIRST-FUN-YEAR Monthly Management Report Polish — Claude Broad Review

Issue: #250 — FIRST-FUN-YEAR Monthly Management Report Polish — 固定費内訳・Hiyori・助言・One-Screen
PR: #251 (`perusonao/smile_enjoy_story`) — https://github.com/perusonao/smile_enjoy_story/pull/251

Reviewer: Claude (Sonnet 5), independent Broad Review — Codex broad review was skipped this round
due to a Codex usage-limit outage, per the task's own instructions.

## SHAs

- **Latest `origin/main` at review time**: `01829f30f00fc7e923bacd355c4e4ffca131cc4e`
  (Merge pull request #249 from `claude/ses-248-applicant-engineer-preservation-rlchfl`)
- **Reviewed PR HEAD** (as fetched from GitHub at review start): `fb300f3294777cf2c64c8b645976341ac15a1a8c`
  ("Issue #250 PR #251: record final HEAD SHA, PR URL, and full test tallies in Result Report")
- **Merge-base**(`origin/main`↔ PR head): `01829f30f00fc7e923bacd355c4e4ffca131cc4e` — identical to latest
  `origin/main`, i.e. the PR branch was already fast-forwardable / conflict-free against the current
  default branch at review time. No merge-conflict work was required.
- **Final HEAD after this review's fix** (pushed to the same PR branch,
  `claude/first-fun-year-report-polish-ql76ss`): see the commit pushed alongside this report.

## Scope reviewed

All 7 files the PR changes vs. `origin/main`:

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
- `lib/ui/public_demo/public_demo_monthly_report_dialog.dart`
- `lib/ui/public_demo/public_demo_monthly_report_display_data.dart`
- `test/ui/public_demo/public_demo_01_monthly_report_test.dart`
- `test/ui/public_demo/public_demo_monthly_report_dialog_test.dart` (new)
- `test/ui/public_demo/public_demo_monthly_report_display_data_test.dart`
- `docs/reports/SES_FIRST-FUN-YEAR_Monthly-Management-Report-Polish_Result.md` (new, the PR's own
  result report)

Confirmed **no** `lib/game/public_demo/**` file is touched, and no PR #247 (Partner Interview /
Parallel Sales / Trade Flow) content is present on this branch (branch was created directly from
`origin/main`).

## Checklist verification (per task instructions)

| Item | Verdict | Evidence |
|---|---|---|
| Monthly Report open/dismiss causes no mutation | **PASS** | `test/ui/public_demo/public_demo_01_monthly_report_test.dart` group 6 ("save/reload regression") asserts `service.saveCount` is unchanged by showing/dismissing the dialog — the one save already happened before the report appears. This test is pre-existing (from PR #237) and unmodified by #251; still green. |
| No monthly-close double execution | **PASS** | Same file, group 2 ("dismiss advances the month exactly once, never re-closes") — pre-existing, unmodified, still green. |
| `_recommendedActionSlot` is read-only, never invoked | **PASS** | Traced `_recommendedActionSlot` (`public_demo_01_placeholder_screen.dart:2977`) — a pure getter with no side effects; it only *constructs* `HomeRecommendedActionCandidate` closures (`add(...)`), it does not call `invoke`. The new `_maybeShowMonthlyReport` code reads the getter's return value (`recommendedAction.candidate.action.headline`) and never calls `.invoke`. No CTA/button is rendered for the "次に考えること" section (text only). |
| No impossible next-action shown for bankruptcy / March year-end | **PASS** | `_recommendedActionSlot` itself returns `HomeRecommendedActionSuppressed` whenever `s.isCloseBlocked` (`public_demo_state.dart:260`: `fiscalYearCompleted \|\| isFinanciallyTerminal`), and `isFinanciallyTerminal` covers both `bankruptcy` and `marchCashShortageFailure` (`public_demo_financial_status.dart`). Verified end-to-end in `public_demo_01_monthly_report_test.dart` groups 4 (Bankruptcy) and 5 (Year-End/March), which now assert the `public-demo-monthly-report-next-action` key is absent after a real bankruptcy close and after a real March fiscal-year-completion close. |
| 黒字/赤字・次月入社 use only existing authority | **PASS** | `netIncome` is `flow.netIncome` verbatim (pre-existing `PublicDemoMonthlyCashFlow` field, PR #234/#237); `nextMonthJoinNames` is pre-existing (unchanged by #251, sourced from `PublicDemoMonthlyReportSnapshot.confirmedNextMonthJoinApplicantIds`). No new derived/estimated accounting value was introduced. |
| 固定費 caption does not fabricate accounting authority | **PASS** | Caption text "（家賃・水道光熱費など）" matches the existing documented composition of `PublicDemoSalary.otherMonthlyFixedCost` (see `public_demo_monthly_close.dart`'s own comment: "misreports fixed costs (rent, utilities) as payroll"). No new per-category breakdown value was created — the caption is static copy over the existing single aggregate figure. |
| HOME Freeze maintained | **PASS** | No HOME-owned file (`public_demo_home_dashboard_section.dart`, `home_navigator_section.dart`, `home_recommended_action.dart`, etc.) appears in the diff. `_recommendedActionSlot` is defined in the Public Demo screen file (not a HOME file) and is only *read*, not modified. `HomeNavigatorIdentity.portraitAssetFor` is an existing shared asset resolver already reused outside HOME by `PublicDemoOpeningContextScreen`; this PR adds a second, equally-outside-HOME call site. |
| No save schema / Finance / Payroll change | **PASS** | Zero files under `lib/game/public_demo/**` touched. `PublicDemoMonthlyReportDisplayData`/`Dialog` are non-persisted, display-only classes (no `toJson`/`fromJson` on the changed classes). |
| 360×800 / 390×844, TextScaler 1.0 / 1.3 | **PASS** | `public_demo_monthly_report_dialog_test.dart` group 4 exercises all 4 combinations with `tester.takeException()` clean; `public_demo_01_monthly_report_test.dart` group 7 (pre-existing, unmodified) covers the same matrix end-to-end. |
| 通常月 no-scroll | **PASS** | New widget test asserts `ScrollableState.position.maxScrollExtent == 0` for the normal-case fixture (no bonus/training/recruitment/next-month-join) at 360×800/TextScaler 1.0. |
| Conflict / semantic regression vs. latest `main` | **PASS** | Merge-base equals latest `origin/main` — no conflict. No regression found in the surrounding Monthly Report wiring; all pre-existing groups (1, 2, 3, 4, 5, 6, 7) in `public_demo_01_monthly_report_test.dart` remain green and were extended, not altered in intent. |

## Findings

### P3 — test did not exercise what its own name/comment claimed (fixed in this review)

**File**: `test/ui/public_demo/public_demo_monthly_report_dialog_test.dart` (group 3, third test)

The test named *"bankruptcy (isFinanciallyTerminal) with a non-null nextActionHeadline still omits
the section — … the dialog never second-guesses a value it is handed either way"* called
`_fixture(isFinanciallyTerminal: true)` **without** passing `nextActionHeadline`, so the fixture's
`nextActionHeadline` silently defaulted to `null`. The test therefore exercised the same case as the
immediately preceding test ("a null nextActionHeadline omits the section") and never actually proved
the claim in its own name — that the dialog renders purely off the null-check regardless of the
`isFinanciallyTerminal` flag. Per the dialog's own documented rule (a plain `if (data.nextActionHeadline
!= null)` check, no re-derivation of the terminal gate), supplying a genuinely non-null headline in
this fixture should make the section **render**, not disappear.

This was a test-only defect — it does not indicate any production bug. The real terminal-gating
behavior (bankruptcy/March-failure/fiscal-year-completion → `null` headline) is independently and
correctly verified by the production end-to-end tests in `public_demo_01_monthly_report_test.dart`
groups 4 and 5, which drive the actual `_recommendedActionSlot` wiring rather than a hand-built
fixture. Classified P3 (test-coverage only, no progression/save/authority/data-integrity impact) —
not a merge blocker per the task's own criteria, but fixed in this session per "問題があれば同じ
セッションでまとめて修正".

**Fix applied**: the fixture now passes a real `nextActionHeadline: '佐藤 健のスキルシートを確認'`
alongside `isFinanciallyTerminal: true`, and the assertion now expects `find.text('次に考えること')`
to be `findsOneWidget` — actually proving the dialog is a dumb, non-second-guessing renderer, with
the real terminal gate confirmed to live in the owner screen (as the test's own comment already
said).

No other findings. No P0/P1 issues were identified.

## Tests executed (this review, after the fix above)

- `flutter analyze` (Flutter 3.44.9, matching this repo's CI pin) — **No issues found.**
- `flutter test test/game/public_demo` — **872/872 passed.**
- `flutter test test/ui/public_demo` — **703/703 passed** (includes the corrected dialog test).
- `git diff --check` (against `origin/main`, and again after this review's own fix) — **clean, no
  whitespace errors.**

## Unresolved items

None. All checklist items pass; the one finding was fixed and re-verified in the same session
(focused verification — full test/analyze suite re-run above, Broad Review not repeated from
scratch).

## VERDICT

**APPROVE** — no P0/P1 findings, one P3 test-only defect found and fixed, full test suite green
(872/872 game + 703/703 UI), `flutter analyze` clean, `git diff --check` clean, no conflict with
latest `origin/main`, HOME Freeze / save schema / Finance / Payroll authority all confirmed intact.

Per instructions, this PR was **not** merged — left open for the user's own merge decision.
