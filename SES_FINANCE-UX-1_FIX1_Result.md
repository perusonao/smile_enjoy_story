# SES FINANCE-UX-1 FIX1 — Monthly Expense Label Correctness — Result Report

RECOMMENDED AI: Claude Code

## 1. Target

- Repository: `perusonao/smile_enjoy_story`
- Existing PR: **#62** ("feat(public-demo): explain monthly cash flow")
- Target branch: `claude/monthly-cash-flow-explanation-a775dx`
- Handed-off HEAD: `55d3fc6c36484c488bec43d4fd280ad359509074` — confirmed via `git fetch origin` to be the actual remote state (no drift).

## 2. P2 Finding

Codex's PR #62 review comment (thread `PRRT_kwDOT2htY86bg-QA`, on `lib/game/public_demo/public_demo_monthly_close.dart:310`): every live monthly close's `monthlyExpenses` bundles payroll with `PublicDemoSalary.otherMonthlyFixedCost` (baseline: ¥750,000 salary + ¥50,000 fixed cost = ¥800,000), but the whole amount was stored as `salaryPaid`, so the new cash-flow card displayed the entire ¥800,000 as "給与". Cash reconciliation itself was correct throughout — only the expense *classification* was wrong, which contradicts FINANCE-UX-1's own goal of letting a player explain a cash change correctly from the screen alone.

## 3. Root Cause

`lib/game/public_demo/public_demo_monthly_close.dart`'s private `_cashFlow` helper (added in the FINANCE-UX-1 PR) set `salaryPaid: monthlyExpenses` verbatim — it never separated the fixed-cost portion `PublicDemoSalaryFinance.monthlyExpenses`/`PublicDemoSalary.baselineMonthlyExpenses` had already folded in.

## 4. Existing Accounting Contract

Traced every call site of `monthlyExpenses:` in `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (April/May pass `expense` = `PublicDemoSalary.baselineMonthlyExpenses` directly; June onward pass `PublicDemoSalaryFinance.monthlyExpenses(baselineExpenses: expense, hires: ..., month: ...)`). `PublicDemoSalary.baselineMonthlyExpenses = initialTotalMonthlySalary + otherMonthlyFixedCost`, and `PublicDemoSalaryFinance.monthlyExpenses` only ever *adds* hire salaries on top of that baseline — it never touches `otherMonthlyFixedCost` again. Confirmed: **every** `monthlyExpenses` value that ever reaches `PublicDemoMonthlyClose`, in every month (April through March, including July's bonus close), equals payroll plus exactly the `otherMonthlyFixedCost` constant (¥50,000). This makes `fixedCostsPaid = PublicDemoSalary.otherMonthlyFixedCost` / `salaryPaid = monthlyExpenses - otherMonthlyFixedCost` a safe, exact split — not an approximation, and not a recomputation of payroll from employee/applicant data.

## 5. Chosen Fix

Preferred contract adopted (domain-level split, not a UI-only relabel):
- `PublicDemoMonthlyCashFlow` gained a new required field `fixedCostsPaid`.
- `PublicDemoMonthlyClose._cashFlow` (the single helper every `closeApril`/`closeMay`/`closeJune`/`closeJuly`/`closeOrdinaryMonth` call funnels through) now sets `salaryPaid: monthlyExpenses - PublicDemoSalary.otherMonthlyFixedCost` and `fixedCostsPaid: PublicDemoSalary.otherMonthlyFixedCost`.
- `totalOutflow` extended to include `fixedCostsPaid`; `toJson`/`fromJson` extended (old-shape JSON without the key defaults to 0, matching this codebase's existing save-compatibility convention).
- `PublicDemoMonthlyCashFlowCard` now renders a `固定費` row alongside `給与` in the itemized breakdown (both unconditionally shown, matching the existing display convention for `給与`).

No "alternative aggregate label" fallback was needed — the domain-level split was directly achievable within existing SSOT data, with no scope increase.

## 6. Salary

`salaryPaid` is now `monthlyExpenses - PublicDemoSalary.otherMonthlyFixedCost` — the same payroll total the domain already computed (no re-derivation from `PublicDemoSalary`/`PublicDemoSalaryFinance`'s employee-level functions), just no longer polluted by the fixed-cost constant. For the April→May case: ¥800,000 − ¥50,000 = **¥750,000**.

## 7. Fixed Costs

`fixedCostsPaid` is the `PublicDemoSalary.otherMonthlyFixedCost` constant (¥50,000), applied identically every month (it is a flat constant, not month-dependent). Shown unconditionally in the breakdown (never omitted, unlike bonus/training/recruitment which are hidden when zero — fixed cost is never zero).

## 8. Reconciliation

Contract updated by one term: `openingCash + cashReceived - salaryPaid - fixedCostsPaid - bonusPaid - trainingCost - recruitmentCost == closingCash`, and `closingCash == state.cash` unchanged. `totalOutflow` (used by the always-visible 支出合計 row) sums all five outflow categories, so the aggregate figure shown at the top of the card is byte-for-byte unchanged (still ¥800,000 for the April→May case) — only the itemized breakdown's `給与` row changed, from ¥800,000 to ¥750,000, with a new ¥50,000 `固定費` row alongside it. No double-counting: `fixedCostsPaid` is carved out of the same `monthlyExpenses` total `salaryPaid` used to include in full, not an additional charge.

## 9. Revenue Regression

Not touched. `PublicDemoRevenuePayment`/the 30-day contract (`cashReceived` = prior `pendingRevenue`; `revenue`/`receivables` = this month's newly recognized billing) received zero changes. Existing revenue tests (`public_demo_monthly_close_revenue_test.dart`, `public_demo_revenue_payment_test.dart`) pass unmodified.

## 10. July Regression

`PublicDemoMonthlyClose.closeJuly` still combines `monthlyExpenses + bonusAmount` for the cash guard/deduction exactly as before (untouched) — the fix only changes how the *already-computed* `monthlyExpenses` figure is split for the summary's `salaryPaid`/`fixedCostsPaid`, after the real cash movement has already happened. Verified: bonus month test now asserts `salaryPaid`/`fixedCostsPaid` split correctly and `totalOutflow == salaryPaid + fixedCostsPaid + bonusPaid`.

## 11. March Regression

March closes through the same `closeOrdinaryMonth` → `_cashFlow` path as every other month, so the split applies identically. Verified: March close test now asserts `salaryPaid`/`fixedCostsPaid` explicitly, `fiscalYearCompleted` still becomes `true`, and the reconciliation formula (extended with `fixedCostsPaid`) still holds.

## 12. UI

`PublicDemoMonthlyCashFlowCard`'s itemized breakdown (`支出の内訳を見る`, collapsed `ExpansionTile`) now shows:
```
給与    -¥750,000
固定費  -¥50,000
```
in place of the old single `給与 -¥800,000` row. The always-visible top-line 支出合計 (-¥800,000) is unchanged. Browser-verified (§14).

## 13. Tests

`test/game/public_demo/public_demo_monthly_cash_flow_test.dart` (18 tests, was 17 — net +1 test, several rewritten):
1. Reconciliation formula updated to include `fixedCostsPaid` (group 1).
2. `salaryPaid` no longer includes `otherMonthlyFixedCost`, asserted `isNot(monthlyExpenses)` (group 5).
3. `fixedCostsPaid` present and equal to the constant — proves it doesn't disappear from the summary (group 5).
4. `salaryPaid + fixedCostsPaid == monthlyExpenses` and `totalOutflow == monthlyExpenses` for a bonus-free month (group 5).
5. **New**: exact April→May regression from the P2 review comment — ¥3,000,000 opening, ¥0 received, ¥750,000 salary, ¥50,000 fixed cost, ¥2,200,000 closing (group 5).
6. July bonus regression updated: `salaryPaid`/`fixedCostsPaid` split asserted, `totalOutflow == salaryPaid + fixedCostsPaid + bonusPaid` (group 6).
7. March regression updated: `salaryPaid`/`fixedCostsPaid` asserted alongside the existing `fiscalYearCompleted`/reconciliation checks (group 9).
8. Negative-cash regression (group 8) — untouched, still uses `totalOutflow` generically, still passes.
9. 30-day revenue regression (groups 2–4) — untouched, still passes.
10. Reconciliation (group 1) — updated formula, still passes for April and an ordinary month.

`test/ui/public_demo/public_demo_monthly_cash_flow_card_test.dart` (15 tests, was 13 — net +2 new tests):
- Fixture (`flow()`) defaults changed to a realistic ¥750,000/¥50,000 split.
- "shows total outflow" / "itemized breakdown is collapsed but reachable" updated to the split figures.
- **New**: "salary and fixed costs are shown separately, not merged (FIX1)" — proves `給与` reads ¥750,000 (not ¥800,000) with `固定費` shown separately, while the aggregate ¥800,000 still appears once as 支出合計.
- **New**: "fixed costs are always shown, never omitted like a zero item" — proves `固定費` isn't accidentally gated by the same zero-guard as bonus/training/recruitment.

No existing test's *expectation* was changed to accommodate a wrong value — the fixture defaults were corrected to a realistic split (750k/50k instead of one opaque 800k), and assertions were updated to check the *now-correct* classification, matching the task's prohibition on "adjusting tests to match new wrong expectations."

## 14. Browser Acceptance

Built `flutter build web --release` (fresh build off HEAD `86fa536`), served it locally, drove the real app with Playwright (Chromium at `/opt/pw-browsers`) via `?e2e=1#/public-demo-01`, played through the same order → April close → May screen route as the original FINANCE-UX-1 acceptance run, then tapped "支出の内訳を見る" to expand the breakdown and screenshotted the live rendered card:

```
4月 月次決算：現預金の内訳
月初現預金          ¥3,000,000
入金                    +¥0
支出合計           -¥800,000
─────────────────────────
月末現預金          ¥2,200,000
売上                    ¥0
売掛金（来月入金予定）    ¥0
支出の内訳を見る (expanded)
  給与              -¥750,000
  固定費             -¥50,000
```

This is exactly the relationship required by the task's UI Acceptance section: 月初現預金 ¥3,000,000 / 入金 ¥0 / 給与 ¥750,000 / 固定費 ¥50,000 / 月末現預金 ¥2,200,000, readable directly off the screen. Not UNVERIFIED — real browser confirmed.

## 15. Quality Gate

Flutter SDK 3.44.8 (same installation used for the FINANCE-UX-1 session, matched to `.github/workflows/public-demo-validation.yml`'s pin).

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed` (5 changed files) | **PASS** (0 changed after formatting) |
| `flutter analyze` (whole repo) | **PASS** — 0 issues |
| Focused finance/Public Demo tests (11 files) | **PASS** — 130/130 |
| Public Demo suite (`test/game/public_demo` + `test/ui/public_demo`) | **PASS** — 287/287 |
| Full `flutter test` (entire repo) | **PASS** — 819/819 (was 816 before this fix — net +3 tests) |
| `flutter build web --release` | **PASS** |
| `git diff --check` | **PASS** — no whitespace errors |

## 16. Changed Files

```
 lib/game/public_demo/public_demo_monthly_cash_flow.dart          | 24 ++++++--
 lib/game/public_demo/public_demo_monthly_close.dart               | 14 ++++-
 lib/ui/public_demo/public_demo_monthly_cash_flow_card.dart        |  1 +
 test/game/public_demo/public_demo_monthly_cash_flow_test.dart     | 66 ++++++++++++++++----
 test/ui/public_demo/public_demo_monthly_cash_flow_card_test.dart  | 45 +++++++++++--
 5 files changed, 130 insertions(+), 20 deletions(-)
```

No new files. No unrelated files touched.

## 17. Commit

```
fix(public-demo): separate fixed costs from salary cash flow
```
Single commit, `86fa536`, on top of `55d3fc6` (the existing PR #62 HEAD at handoff).

## 18. Remote HEAD

`origin/claude/monthly-cash-flow-explanation-a775dx` = `86fa5363545e906bb574751df2a1a3639b42da09` — matches local HEAD exactly. Pushed with a plain `git push` (fast-forward, no force needed).

## 19. PR #62 Status

- New commit pushed to the existing PR branch (no new PR created).
- Replied to the P2 review thread (`PRRT_kwDOT2htY86bg-QA`) pointing at commit `86fa536`, and **resolved** the thread.
- Posted a summary comment to the PR with root cause, fix, reconciliation, tests, browser acceptance, and quality-gate results.
- Subscribed this session to PR #62 activity and monitored CI on the new HEAD (`86fa536`) after pushing.
- **Not merged. Deploy not triggered by this session.**

## 20. Final Verdict

**FIX IMPLEMENTED / READY FOR CODEX REREVIEW**
