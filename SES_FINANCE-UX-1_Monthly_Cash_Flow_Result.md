# SES FINANCE-UX-1 — Monthly Cash Flow Explanation — Result Report

RECOMMENDED AI: Claude Code

## 1. Initial Git State

- Working tree at session start: clean, on branch `claude/monthly-cash-flow-explanation-a775dx`.
- That branch's own HEAD (`f4ca78f`, "Phase 0A/0B: SES domain models and random generators") was found to already be a fully-merged ancestor of `origin/main` — it carried no unmerged work of its own, matching the harness's "already merged" restart condition.

## 2. Base Main

- `git fetch origin main` confirmed `origin/main` at **`7bd51c91024a73c499f9ef96bfa3a8f9d38ab5a7`** — exactly the SHA handed off in the task ("known main"). No drift, no STOP condition triggered here.

## 3. Branch

- Restarted the designated branch from `origin/main` (`git checkout -B claude/monthly-cash-flow-explanation-a775dx origin/main`), per the harness's "merged PR" recovery flow — kept the same branch name, did not create `feature/public-demo-finance-ux-1-monthly-cash-flow` (the task text's own suggestion is superseded by the harness's explicit branch assignment).

## 4. Research

Read, in full, before writing any code:
- `public_demo_state.dart`, `public_demo_monthly_close.dart`, `public_demo_revenue.dart`, `public_demo_revenue_payment.dart`, `public_demo_salary.dart`, `public_demo_salary_finance.dart`, `public_demo_summer_bonus_payment.dart`, `public_demo_recruitment_transaction.dart`, `public_demo_internal_training_transaction.dart`, `public_demo_raise_transaction.dart`, `public_demo_recruitment_medium.dart`, `public_demo_monthly_growth.dart`, `public_demo_month_label.dart`, `public_demo_monthly_record.dart` (an existing, deliberately-unwired "immutable month-end record" — useful precedent for naming/shape, not reused directly since its fields don't match this task).
- `public_demo_01_placeholder_screen.dart` (1452 lines) in full — the single screen that owns all month-transition handlers and the `dashboard()` widget.
- `public_demo_growth_result_card.dart` / `public_demo_monthly_growth.dart` — the existing "attach a historical-fact result object to `PublicDemoState`, render it from `dashboard()`" pattern (EG-4), used as the direct precedent for this task's design.
- `lib/ui/theme.dart` / `lib/ui/widgets/expense_breakdown_sheet.dart` — the **main game's** (non-Public-Demo) existing finance summary sheet and its `formatYen` helper. Confirmed reusable (pure formatting utility, no domain coupling) and confirmed the Japanese terminology this task should match: 現預金, 売掛金, 今月入金予定, 現金増減.
- Existing test files for close/revenue/save conventions: `public_demo_monthly_close_test.dart`, `public_demo_monthly_close_revenue_test.dart`, `public_demo_revenue_payment_test.dart`, `public_demo_fiscal_year_save_test.dart`.

## 5. Cash Mutation Inventory

Exhaustively grepped `lib/game/public_demo` for every `cash:`/`cash +`/`cash -` assignment. Exactly **5 production sites** touch `PublicDemoState.cash`:

| # | Site | Trigger | Timing |
|---|---|---|---|
| 1 | `public_demo_recruitment_transaction.dart` | Recruitment-media purchase (¥0 free / ¥100,000 engineer) | Immediate, mid-month, player-initiated |
| 2 | `public_demo_internal_training_transaction.dart` | Internal training purchase (¥30,000) | Immediate, mid-month, player-initiated |
| 3 | `public_demo_state.dart` (`advanceToMay`/`advanceToJune`/`advanceToJuly`/`advanceToNextOrdinaryMonth`/`completeFiscalYear`) | Subtract `monthlyExpenses` (salary total) | Month-end close |
| 4 | `public_demo_revenue_payment.dart` (`PublicDemoRevenuePayment.apply`) | Add `revenueReceived` (prior month's billed revenue) | Month-end close, before #3 |
| 5 | `public_demo_summer_bonus_payment.dart` (July only) | Subtract `monthlyExpenses + bonusAmount` combined | Month-end close (July's variant of #3) |

Raises and salary offers never touch cash directly (they only change future salary, folded into `monthlyExpenses` at the next close). External training has no wired paid UI path in Public Demo 0.1. No other file in `lib/game/public_demo` or `lib/ui/public_demo` mutates cash.

## 6. Existing Accounting Contract

- `PublicDemoMonthlyClose` (façade) already runs `PublicDemoRevenuePayment.apply` before every month's transition, and already returns `cashBefore`/`cashAfter`/`cashMovement` on `PublicDemoMonthlyCloseResult` — but discarded `PublicDemoRevenuePaymentResult.revenueReceived`/`revenueRecognized` after using them, and had no notion of "opening cash of the month" (only "cash right before this specific close call," which already includes any mid-month training/recruitment spend).
- Revenue contract (from `PublicDemoRevenuePayment.apply`, unchanged): `cash += pendingRevenue` (prior month's billing, now collected); `pendingRevenue = monthlyRevenueForAssignedCount(engineersAssigned)` (this month's billing, fully replacing — not adding to — the old balance). Public Demo 0.1's single 30-day cycle means **revenue recognized this month == receivables carried == what next month's close will collect**, always exactly equal.

## 7. Design

Presented to the user before implementing (see conversation): add `PublicDemoMonthlyCashFlow`, an immutable value object `PublicDemoMonthlyClose` attaches to `PublicDemoState.latestMonthlyCashFlow` for every month it actually closes — mirroring the existing `latestGrowthResults` (EG-4) pattern exactly, so idempotency/atomicity come from `PublicDemoState`'s existing per-transition guards rather than new logic. Three small bookkeeping fields were added to `PublicDemoState` to make this possible without recomputing anything:

- `monthOpeningCash` — the cash balance the moment the *current* month began (a snapshot taken by the *previous* close/`aprilStart()`, not the value `PublicDemoMonthlyClose` receives as input, which may already reflect mid-month spend).
- `monthTrainingSpent` / `monthRecruitmentSpent` — running totals of the *actual* `chargedAmount` each transaction already computes, reset to 0 whenever the month advances.

## 8. Domain Changes

- **New file** `lib/game/public_demo/public_demo_monthly_cash_flow.dart` — `PublicDemoMonthlyCashFlow` (month, openingCash, cashReceived, salaryPaid, bonusPaid, trainingCost, recruitmentCost, closingCash, revenue, receivables; `totalOutflow`/`netCashMovement` getters; `toJson`/`fromJson`).
- `public_demo_state.dart` — added `monthOpeningCash`, `monthTrainingSpent`, `monthRecruitmentSpent`, `latestMonthlyCashFlow` (all threaded through the factory/`copyWith`/`toJson`/`fromJson`); every month-advancing method (`advanceToMay`/`advanceToJune`/`advanceToJuly`/`advanceToNextOrdinaryMonth`/`completeFiscalYear`) now also resets the three bookkeeping fields for the new month; added `recordTrainingSpend`/`recordRecruitmentSpend`/`recordMonthlyCashFlow` methods.
- `public_demo_internal_training_transaction.dart` / `public_demo_recruitment_transaction.dart` — one line each, calling the new `record*Spend` methods with the *same* `chargedAmount`/`medium.cost` they already computed (no new math).
- `public_demo_summer_bonus_payment.dart` — July's bonus-close path resets the three bookkeeping fields for August (it does its own `copyWith(month: 8, ...)` rather than going through `advanceToJuly`).
- `public_demo_monthly_close.dart` — every `closeX` method that actually closes a month now builds a `PublicDemoMonthlyCashFlow` from values it already has (the `PublicDemoRevenuePaymentResult` it already calls, the caller-supplied `monthlyExpenses`/bonus amount, `state.monthOpeningCash`/`monthTrainingSpent`/`monthRecruitmentSpent` from the pre-close state) and attaches it via `recordMonthlyCashFlow`. March goes through the exact same `closeOrdinaryMonth` code path as every other ordinary month.

## 9. UI Changes

- **New file** `lib/ui/public_demo/public_demo_monthly_cash_flow_card.dart` — `PublicDemoMonthlyCashFlowCard`, rendering only `PublicDemoMonthlyCashFlow`'s recorded facts (no recomputation). Always-visible: 月初現預金 / 入金 / 支出合計 / 月末現預金 (color-coded green/red) / 売上 / 売掛金（来月入金予定）, plus a one-line note when revenue was recognized. Itemized 給与/賞与/研修費/採用費 breakdown lives in a collapsed `ExpansionTile` ("支出の内訳を見る") — zero-amount items omitted. Uses the main game's existing `formatYen` (`lib/ui/theme.dart`) for comma-formatted, negative-safe currency.
- `public_demo_01_placeholder_screen.dart` — `dashboard()` renders the card whenever `s.latestMonthlyCashFlow != null`, placed right after the stat row (before growth results), following the same `if (...) ...[ ]` pattern as `latestGrowthResults`.
- **Unrelated fix required by this change**: the added card's height crossed a threshold that triggered a Flutter SliverList layout quirk in this SDK (3.44.8) — children past that cumulative height silently stopped mounting at all (confirmed independent of `cacheExtent`, tested up to 20000px). Wrapped the screen's existing `ListView` children in a single `Column` (keeping `ListView` as the outer widget so existing tests that find/scroll it by type still work) — this gives the sliver exactly one child, which Flutter always builds in full regardless of height. See §17 for the two existing tests this required updating.

## 10. Revenue Explanation

- 売上 (revenue) = this month's `revenueRecognized`.
- 売掛金（来月入金予定） (receivables / next-month collection) = the new `pendingRevenue`, exactly equal to 売上 under Public Demo 0.1's single-cycle model — both shown so the reader doesn't have to infer the 30-day relationship from one number playing two roles.
- 入金 (cash received) = `revenueReceived`, i.e. *last* month's 売掛金.
- One-line note ("今月の売上は来月に入金されます") shown only when this month's revenue > 0.
- Browser-verified (§19): May's card showed 売上 ¥500,000 / 売掛金（来月入金予定）¥500,000 with the note, distinct from 入金 +¥0 (April had no prior receivable to collect).

## 11. Cash Reconciliation

Enforced as a test assertion (§17, groups 1 and 8): `openingCash + cashReceived - salaryPaid - bonusPaid - trainingCost - recruitmentCost == closingCash`, and `closingCash == PublicDemoState.cash` after the close — checked directly against the real state transition output, not re-derived.

## 12. Negative Cash Handling

No game-over/bankruptcy/loan logic added. `formatYen` renders negative amounts as `-¥400,000`; the card's closing-cash row switches to red when negative, otherwise unchanged rendering. Covered by domain test group 8 and widget test "negative closing cash still renders correctly".

## 13. March Handling

March closes through the *same* `PublicDemoMonthlyClose.closeOrdinaryMonth` code path as every other month (no March-specific branch in the cash-flow logic) — its `PublicDemoMonthlyCashFlow` is recorded identically, and March's own newly recognized revenue correctly stays in `pendingRevenue` (never collected, since the fiscal year ends before it would be). Covered by domain test groups 9 and 10, and confirmed live via the existing `public_demo_01_fiscal_year_progression_test.dart` E2E-style widget test (April→March, 12 real month closes).

## 14. Atomicity

No new atomicity risk introduced: `recordMonthlyCashFlow` is a pure `copyWith` attached to the *same* `next` state object the close already produces — there is no separate write. July's existing cash-guard rollback (`isInsufficientCash` → return the original untouched `state`) is preserved unchanged; the cash-flow summary is only attached on the `isPaid` branch, so a rolled-back July never gets a partial/incorrect summary.

## 15. Idempotency

Every `closeX` method's cash-flow attachment is guarded by the *same* boolean (`isApril`/`isMay`/.../`isOrdinaryMonth`) that already gates the underlying state transition — a repeated or out-of-turn call hits `notApplicable` and neither the state nor the summary changes. Verified directly (domain test group 11: calling `closeOrdinaryMonth` twice against the same pre-close state does not double-count; calling it again against the *real* post-close state correctly processes the next month, not a duplicate) and indirectly via the pre-existing `public_demo_monthly_close_revenue_test.dart` idempotency test (still passing unmodified).

## 16. Save Compatibility

`PublicDemoState`'s `toJson`/`fromJson` were extended, not replaced. `monthOpeningCash` falls back to the saved `cash` value when absent (old saves have no historical "true opening cash," so this is the best available approximation, not a recomputation of a hidden rule); `monthTrainingSpent`/`monthRecruitmentSpent` default to 0; `latestMonthlyCashFlow` defaults to `null`. Verified: a fresh close's `latestMonthlyCashFlow` round-trips byte-for-byte through JSON, and an old save with none of the four new keys loads without error (domain test group 13). Public Demo 0.1's screen does not currently wire `toJson`/`fromJson` into any actual save mechanism (confirmed by inspection — no `SharedPreferences`/persistence call exists in `public_demo_01_placeholder_screen.dart`), so no save-schema migration was needed; the round-trip guarantee exists for forward-compatibility with whichever future task does wire it up.

## 17. Tests Added

**Domain** — `test/game/public_demo/public_demo_monthly_cash_flow_test.dart` (17 tests, all passing):
1. Core accounting contract (April + an ordinary month)
2. Revenue recognized ≠ cash received
3. Previous `pendingRevenue` becomes `cashReceived`
4. Current month revenue becomes next `receivables`
5. Salary reflected in cash outflow
6. Bonus month display (bonus>0 and bonus=0 cases)
7. Training/recruitment costs included (real transaction amounts, and accumulator reset on month advance)
8. Negative closing cash
9. March close (same contract)
10. March `pendingRevenue` maintained (not collected)
11. Monthly close idempotency
12. `fiscalYearCompleted` guard regression
13. Save compatibility (round trip + old-save fallback)

**UI** — `test/ui/public_demo/public_demo_monthly_cash_flow_card_test.dart` (13 tests, all passing): card renders; opening/closing cash shown; revenue shown; cash received shown; receivables + next-month label shown; total outflow shown; 30-day explanatory note conditional on revenue>0; itemized breakdown collapsed-by-default and reachable; zero-amount items omitted; negative cash renders; no-overflow at 360px/390px.

**Test infrastructure fix** (required by §9's SliverList fix, not new behavior): `test/ui/public_demo/public_demo_01_playthrough_test.dart`'s `tapAndSettle` helper and one raw `tester.tap` call now call `ensureVisible` before tapping — `scrollUntilVisible`'s existence-based loop became a no-op once the screen stopped virtualizing, so it needed an explicit scroll-into-view step it previously got "for free."

## 18. Quality Gate

Flutter SDK **3.44.8** (stable) — matched exactly to `.github/workflows/public-demo-validation.yml`'s pin (downloaded, SHA256-verified against the official release manifest, installed to `/opt/flutter-sdk`).

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed` (all changed files) | **PASS** (0 changed after applying format) |
| `flutter analyze` (whole repo) | **PASS** — 0 issues |
| Focused finance/revenue/monthly-close/save tests (11 files) | **PASS** — 127/127 |
| Public Demo tests (`test/game/public_demo` + `test/ui/public_demo`) | **PASS** — 284/284 |
| Full `flutter test` (entire repo) | **PASS** — 816/816 |
| `git diff --check` | **PASS** — no whitespace errors |
| `flutter build web --release` | **PASS** |

## 19. Browser Acceptance

Built `flutter build web --release`, served `build/web` locally, drove the real app with Playwright (Chromium at `/opt/pw-browsers`) via `?e2e=1#/public-demo-01` (the repo's own documented QA hook that force-enables Flutter Web's semantics tree for automation, per `lib/main.dart`). Played through a real order (SkillSheet確認 → 営業開始 → 案件紹介 → 上位会社面談 → 客先面談 → 受注 → April close → May close), screenshotting the actual rendered app at each step.

- **April → May**: May's screen shows "4月 月次決算：現預金の内訳" — 月初現預金 ¥3,000,000 / 入金 +¥0 / 支出合計 -¥800,000 / **月末現預金 ¥2,200,000** (green) — a first-time viewer can read April's ¥3,000,000→¥2,200,000 change directly off the screen, matching this task's specific playtest finding.
- **Revenue vs. cash received**: after May's close (June's screen), the card shows "5月 月次決算" — 売上 ¥500,000 / 売掛金（来月入金予定）¥500,000 / **入金 +¥0**, with the note "今月の売上は来月に入金されます" — the revenue-recognized-vs-cash-received distinction is directly visible, not inferred.
- The June screen also confirmed the itemized-breakdown `ExpansionTile` and the "6月終了→7月" close button both render correctly (verifying §9's SliverList fix live in a real browser, not just under `flutter test`).

No E2E spec file was added to `e2e/` (out of scope — "E2E infrastructure refactor" is explicitly excluded); this was a one-off Playwright script run against the built app, screenshots not included in this report but were visually reviewed during the session.

## 20. Changed Files

```
 lib/game/public_demo/public_demo_internal_training_transaction.dart |   1 +
 lib/game/public_demo/public_demo_monthly_cash_flow.dart             |  new file
 lib/game/public_demo/public_demo_monthly_close.dart                 | 178 ++++++++--
 lib/game/public_demo/public_demo_recruitment_transaction.dart       |   1 +
 lib/game/public_demo/public_demo_state.dart                         | 112 +++++-
 lib/game/public_demo/public_demo_summer_bonus_payment.dart          |  28 +-
 lib/ui/public_demo/public_demo_01_placeholder_screen.dart           | 298 ++++++++--------
 lib/ui/public_demo/public_demo_monthly_cash_flow_card.dart          |  new file
 test/game/public_demo/public_demo_monthly_cash_flow_test.dart       |  new file
 test/ui/public_demo/public_demo_01_playthrough_test.dart            |  13 +-
 test/ui/public_demo/public_demo_monthly_cash_flow_card_test.dart    |  new file
```

## 21. Commit

```
feat(public-demo): explain monthly cash flow
```
Full message in the commit itself explains the playtest finding, the design, and the SliverList fix. Single commit, `b20d5cb`.

## 22. Remote HEAD

`origin/claude/monthly-cash-flow-explanation-a775dx` = `b20d5cbbca00e4d66d1d7c962e1ca914c7976913` — matches local HEAD exactly.

## 23. Remaining Scope

Explicitly not implemented (per task scope): negative-cash game-over/bankruptcy/loan (FINANCE-FAILURE-1), Year 1 final report screen (YEAR-RESULT-1), any save-schema migration beyond the additive/backward-compatible fields above, and no PR was opened.

## 24. Final Verdict

**IMPLEMENTED / READY FOR INDEPENDENT REVIEW**
