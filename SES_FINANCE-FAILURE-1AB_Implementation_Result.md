# SES FINANCE-FAILURE-1A+1B Implementation Result

RECOMMENDED AI: Claude Code
BASE: f089d63c8170be6e889fad8147b2892cb9403f8f (verified: `origin/main` matched exactly at session start)
BRANCH: claude/finance-failure-1ab-21sjr6
IMPLEMENTATION COMMIT: 6f019f4af72ffaf964ce82277b734eb61a1429a3
REPORT COMMIT: (this file's own commit, added after the implementation commit above)
REMOTE HEAD: 6f019f4af72ffaf964ce82277b734eb61a1429a3 (pushed to `origin/claude/finance-failure-1ab-21sjr6`)
DIFF: 15 files changed (13 modified, 2 new), 1420 insertions(+), 413 deletions(-); no unrelated files touched (see §"Legacy bypass audit" and "Scope control" below)

## FINANCIAL STATE

NORMAL: New `PublicDemoFinancialStatus` enum (`normal`, `cashShortage`, `bankruptcy`, `marchCashShortageFailure`) on `PublicDemoState.financialStatus` — the single authoritative source; nothing infers financial health from cash sign or `fiscalYearCompleted` alone.
SHORTAGE: First non-March negative close → `cashShortage`. Commits the negative cash (no rollback). Verified by domain tests A/N-U (`public_demo_financial_status_test.dart`) and widget tests (bankruptcy/completion-lock/carryforward/fiscal-year-progression).
RECOVERY: Shortage + next close ≥ 0 → back to `normal`, gameplay continues. Test B.
BANKRUPTCY: Shortage + next close < 0 → `bankruptcy` (terminal). The producing close still commits atomically (AR/expenses/cash all settle). Test C, F, K.
MARCH FAILURE: Normal entering March + negative close → `marchCashShortageFailure` (terminal), NOT annual success. Test J.
TERMINAL EXCLUSIVITY: `bankruptcy` and `marchCashShortageFailure` are mutually exclusive per entry status (previous `cashShortage` → bankruptcy path; previous `normal` → March-failure path in March, `cashShortage` in any other month) — see `PublicDemoFinancialStatus.afterClose`. Once either is reached, `PublicDemoState.isFinanciallyTerminal`/`isCloseBlocked` gate every further close; terminal transitions are idempotent (tests D/X).

## SINGLE CLOSE COMMAND

`PublicDemoAggregate.closeApril/closeMay/closeJune/closeJuly/closeOrdinaryMonth` remain the sole production month-end commands (unchanged public surface), now each gated by `state.month != <required> || state.isCloseBlocked` at entry, before Growth/AR/cash are touched — matching WORKFLOW-STATE's existing "one atomic aggregate transition" design. No new close API was introduced; no widget-local recomputation of accounting values was added (the widget's `monthlyExpenses` was already derived from the aggregate's own `workflow.joinedApplicants`, not an independent list, and remains so).

PRE-AR IDEMPOTENCY: Confirmed — every aggregate close command's guard runs before `_closeGrowth`/AR settlement/salary/bonus/cash mutation. A retry against a state that already advanced past the required month, or that has reached `isCloseBlocked`, is a structural no-op returning the exact same aggregate instance (no partial mutation). See tests D and X.

ATOMICITY: Verified via the existing `PublicDemoMonthlyCashFlow` reconciliation contract (`openingCash + cashReceived - salaryPaid - fixedCostsPaid - bonusPaid - trainingCost - recruitmentCost == closingCash`), which already supported negative `closingCash` without changes — see test W (folded into E2) and the pre-existing `public_demo_monthly_cash_flow_test.dart` §8.

## REVENUE

30-DAY AR: Unchanged. `PublicDemoRevenuePayment`/the 30-day collection contract was not touched; prior `pendingRevenue` still becomes cash exactly once per close, current-month revenue still becomes the next `pendingRevenue`. Regression-verified (`public_demo_revenue_payment_test.dart`, `public_demo_revenue_state_test.dart`, `public_demo_monthly_close_revenue_test.dart` all still pass unmodified in substance — only the two July "insufficient cash" tests changed, see JULY below).
MARCH PENDING REVENUE: Unchanged and explicitly re-verified under a shortage-entering March (test M): March's own newly recognized revenue stays pending, never collected same-close, even when the company is in `cashShortage` and recovers.

## JULY

JULY: The legacy insufficient-cash rollback is removed. `PublicDemoSummerBonusPayment.closeJuly` and the `PublicDemoMonthlyClose.closeJuly`/`PublicDemoMonthlyCloseStatus` facade no longer have an `insufficientCash` status at all (removed from both enums) — the mandatory close (AR settlement, salary, fixed costs) always commits, even to negative cash, which the financial-status transition then classifies as shortage/bankruptcy like any other month. Verified: E (enough cash, closes normally), E2 (NONE causing first shortage, no rollback), F (NONE from prior shortage → bankruptcy), G (prior AR settles exactly once, retry is a no-op).
JULY AR ATOMICITY: Confirmed — Revenue settles into cash before the bonus-affordability check, and is never rolled back regardless of the bonus outcome (test G, H).
JULY BONUS: Affordability gating is now scoped to the optional bonus alone — `closeJuly` pays the full requested bonus if `cash >= monthlyExpenses + bonus`, otherwise pays 0 (never partial), and the mandatory close proceeds either way. Regression-verified in `public_demo_summer_bonus_payment_test.dart` (rewrote the two tests that asserted the old rollback; added one for "mandatory expenses alone exceeding cash still completes with negative cash") and `public_demo_monthly_close_revenue_test.dart`. Test H is a targeted regression check of this exact contract.

## MARCH

FISCAL COMPLETION PRIORITY: `PublicDemoState.completeFiscalYear` now computes the resulting `financialStatus` from the actual closing cash before deciding `fiscalYearCompleted` — `fiscalYearCompleted = !nextStatus.isTerminal`. This encodes BANKRUPTCY (previous `cashShortage`, negative) and MARCH CASH-SHORTAGE FAILURE (previous `normal`, negative) as mutually exclusive by construction; SUCCESS is the only remaining case (previous `normal`/`cashShortage`, non-negative). Tests I/J/K/L cover all four cells; M covers the pending-revenue rule holding under a shortage-entering March too.

## RECRUITMENT MEDIA

RECRUITMENT MEDIA: `PublicDemoAggregate.recruit` now checks `state.isFinanciallyRestricted` (shortage or either terminal status) before any calculation runs — rejection is atomic: no cash mutation, no usage-month mutation, no applicant generation. New status `PublicDemoRecruitmentTransactionStatus.blockedByFinancialShortage`; the widget's existing exhaustive `switch` on that enum was extended with one Japanese message line (the only UI text added in this change). Test N; atomicity re-confirmed by inspecting `state.cash`/`workflow.applicants` before and after the rejected call.
FREE RECRUITMENT: Explicitly re-tested as blocked too (test O) — B'.1 finalized that zero cost does not exempt it, and the gate is on the shared `recruit()` entry point, not a per-medium branch, so this could not silently regress.

## OFFER ACCEPTANCE

OFFER ACCEPTANCE: `PublicDemoAggregate.acceptOffer` — the sole production commit path for a `PublicDemoBindingOffer` (see its own pre-existing class doc: `PublicDemoWorkflowState`/`PublicDemoOfferAcceptance` alone cannot commit anything as authoritative) — now returns `this` unchanged when `state.isFinanciallyRestricted`, checked before delegating to `workflow.acceptOffer`. Test P (a genuine, would-be-accepted offer is rejected, no BindingOffer minted, no workflow mutation at all — asserted via `same()` identity) and U (the same guard holds across every applicant in a real shortage aggregate, demonstrating there is no alternate commit path to bypass).
SALARY OBLIGATION: Confirmed structurally impossible to create during shortage through the sole commit path; no second provenance system was introduced.
BINDING OFFER PROVENANCE: Unchanged — reuses WORKFLOW-STATE's existing unforgeable `PublicDemoBindingOffer`/`PublicDemoInterviewRecord` provenance chain. Test R: an offer accepted while `normal`, then carried through real closes into `cashShortage`, keeps the exact same `PublicDemoBindingOffer` object (`same()` check) — shortage does not retroactively cancel it.
JOIN DEFENSE: `PublicDemoJoinTransaction`/`PublicDemoApplicant.join` untouched — remains defense in depth on top of the offer-acceptance boundary, as before.
TRAINING: `PublicDemoInternalTrainingTransaction.execute` gains the same `state.isFinanciallyRestricted` check, ordered before the assigned/already-selected/cash checks so a rejected purchase never charges cash or selects a training source. New status `PublicDemoInternalTrainingStatus.blockedByFinancialShortage`. Test Q, both at the transaction level directly and via the aggregate's `selectInternalTraining` (confirmed a no-op via `same()`).

## RECOVERY ACTIONS

RECOVERY ACTIONS: Sales/interview progression, existing assignment/order decisions, existing payroll, and AR settlement are unaffected by shortage — confirmed by test S (a zero-cost engineer sales-pipeline transition still progresses during shortage) and by P's own confirmation that `completeInterview` itself still succeeds during shortage (only the *offer acceptance* that would follow is blocked).
BLOCKED ACTIONS: Paid recruitment media, free recruitment media, new offer acceptance, paid internal training, and a summer-bonus plan above `none` (via `PublicDemoState.selectSummerBonus`'s new guard) — all rejected by domain authority, not merely a disabled UI control (the widget's own equivalent controls were left as-is per the P0 domain-first scope; see "UI/warning scope" below).

## WORKFLOW SNAPSHOT

WORKFLOW SNAPSHOT: Audited (§19/33 stop-condition check) — the live close path was already deriving every finance-relevant fact (payroll membership, assignment identities/count, joined-applicant facts, Growth's assigned-identity set) from the aggregate's own single, atomic `workflow` field at close time, never an independently-mutable widget list; `PublicDemoWorkflowSnapshot` (WORKFLOW-STATE-1 §21) exists as an equivalent point-in-time capture but was not previously wired into production. I did not force it into the close path — doing so would restructure an already-correct, already-tested data flow for no behavioral gain, which is out of this task's scope ("do not redesign WORKFLOW-STATE"). Test V instead cross-checks that `PublicDemoWorkflowSnapshot.capture(...)` agrees exactly with what the live close actually used (`assignedEngineerIds`, `joinedPayrollIds`), documenting the equivalence rather than changing the wiring. This was NOT a stop condition: the snapshot is sufficient, and no dual-authority gap exists.
PAYROLL AUTHORITY: Unchanged (`PublicDemoSalary`/`PublicDemoWorkflowState.joinedApplicants`).
ASSIGNMENT AUTHORITY: Unchanged (`PublicDemoWorkflowState.assignedEngineerIds`/`assignOrderedForMay`).
GROWTH: Unchanged calculation; the new pre-close guard (month check + `isCloseBlocked`) added to every aggregate close command is what prevents Growth from ever being applied twice on a genuine retry (previously a latent gap — see "Adversarial tests" below) or applied at all once terminal.

## CASH MUTATION INVENTORY

| Mutation family | Authoritative command | Allowed during shortage? | Atomicity |
|---|---|---|---|
| Monthly close (salary/fixed costs/AR) | `PublicDemoAggregate.closeApril/closeMay/closeJune/closeJuly/closeOrdinaryMonth` | Yes (mandatory; this is what *produces* shortage/bankruptcy) | Atomic per close; blocked entirely once terminal |
| Summer bonus | `PublicDemoSummerBonusPayment.closeJuly` (via `closeJuly`) | Bonus itself pays 0 if unaffordable; mandatory close still proceeds | Atomic — no partial bonus |
| Recruitment media (paid/free) | `PublicDemoAggregate.recruit` | **No** (new gate) | Atomic — rejection touches nothing |
| Internal training | `PublicDemoInternalTrainingTransaction`/`selectInternalTraining` | **No** (new gate) | Atomic — rejection touches nothing |
| Offer acceptance (creates future payroll) | `PublicDemoAggregate.acceptOffer` | **No** (new gate) | Atomic — rejection is a pure no-op |
| Raise | `PublicDemoRaiseTransaction` | Unchanged (gated only on `fiscalYearCompleted`, as before) | Unchanged |

Intentional difference from the previously-reviewed sanctioned families: recruitment/training/offer-acceptance now carry an additional financial-status precondition; no other family's authority, caller, or atomicity changed. Raises were deliberately left out of the new gate — B'.1's finalized BLOCK list (task §13) names recruitment media, offer acceptance, paid training, and bonus-above-none, not raises on existing employees; extending the gate to raises would have been scope expansion beyond the approved contract (task §16: "do not expand scope into a new general spending framework").
RECONCILIATION: `openingCash + cashReceived - salaryPaid - fixedCostsPaid - bonusPaid - trainingCost - recruitmentCost == closingCash == state.cash` re-verified explicitly for a negative closing cash (test E2) and holds unconditionally by construction (`PublicDemoMonthlyClose._cashFlow` always sets `closingCash: next.cash`).

## SAVE/JSON

SAVE/JSON: `PublicDemoState.financialStatus` added to `toJson`/`fromJson` with a `normal` default for any old save lacking the key or carrying a malformed value (`PublicDemoFinancialStatus.fromJson`). No save/load UI or runtime persistence was built or claimed — this is JSON/domain compatibility only, matching the existing `fiscalYearCompleted`/`pendingRevenue` precedent in the same file.
IDEMPOTENCY: Round-trip preserves shortage/terminal state exactly (test Y).
TERMINAL GUARDS: Unified under `PublicDemoState.isCloseBlocked` (= `fiscalYearCompleted || isFinanciallyTerminal`) for "may this close mutate" and `isFinanciallyRestricted` (= `cashShortage || isFinanciallyTerminal`) for "is this optional action rejected" — every new gate in this change reads one of these two getters rather than re-deriving cash-sign/status logic locally.

## TESTS ADDED

- `lib/game/public_demo/public_demo_financial_status.dart` (new domain type + `afterClose` transition function + JSON helper).
- `test/game/public_demo/public_demo_financial_status_test.dart` (new, 26 tests): full A-Y matrix from task §23 — shortage/recovery/bankruptcy (A-C), pre-AR idempotency and terminal retry (D, X), July P0 (E, E2, F, G, H), March priority (I-M), recruitment/offer/training gates built from a **real** aggregate trajectory rather than any state-injection shortcut (N-U — `PublicDemoAggregate` deliberately exposes no way to inject an arbitrary `PublicDemoState`, so shortage/bankruptcy fixtures are reached via genuine `closeApril→closeMay→closeJune→closeJuly` calls with zero orders, matching the class's own "build it by chaining real commands" convention), workflow-snapshot equivalence (V), and JSON round-trip (Y).
- Updated `public_demo_summer_bonus_payment_test.dart`, `public_demo_monthly_close_test.dart`, `public_demo_monthly_close_revenue_test.dart`: the three pre-existing tests that asserted the now-removed July rollback were rewritten to assert the new no-rollback/zero-bonus contract (not deleted, not weakened — same fixtures, corrected expected outcome).
- Updated `public_demo_monthly_close_ordinary_month_test.dart`: its "full fiscal year" test used a flat 800,000/month expense against a 3,000,000 starting cash with no revenue growth for 12 closes — mechanically insolvent under the new contract (triggers real bankruptcy partway through, per the fix). Raised its starting cash so it continues to validate what it always tested (month-by-month mechanics through March), documented inline.
- Updated three pre-existing widget tests (`public_demo_01_fiscal_year_progression_test.dart`, `public_demo_01_completion_lock_ui_test.dart`, `public_demo_01_assignment_carryforward_test.dart`): each drives a real single-engineer playthrough (revenue capped at 500,000/month against the founding team's fixed 800,000/month payroll+overhead) through many ordinary months with no further hiring — a real, structural deficit that now legitimately reaches CASH SHORTAGE then BANKRUPTCY before March, instead of the old unlimited-free-debt path to false fiscal "success". Rewrote each test's tail to assert the correct new terminal outcome at the exact month it occurs (verified against the real financial trajectory, not guessed) and, where the original test's purpose was a terminal-state UI/idempotency check, retargeted it at the bankruptcy terminal state instead of fiscal completion — which is at least as good a fixture for that purpose and additionally exercises a terminal path the old test never reached. Full reasoning and exact per-file trajectories are in each file's own updated class-doc comment.

ADVERSARIAL TESTS: Test U (direct-commit-path bypass across every applicant in a real shortage aggregate); test D/X (retry/terminal-retry structural no-op, which also closes a **latent pre-existing double-mutation gap**: before this change, `PublicDemoAggregate.closeApril/closeMay/closeJune/closeJuly/closeOrdinaryMonth` applied Growth via `_closeGrowth` unconditionally before delegating to the finance facade, so retrying a close command after it had already succeeded could re-apply Growth for the new current month even though the finance facade itself would reject the mismatched month — reachable directly, not through any UI path. The new `state.month != <required> || state.isCloseBlocked` guard added to the front of every one of these five commands closes that gap as a side effect of the required pre-AR-idempotency work; `public_demo_aggregate_test.dart`'s existing "TEST F: retrying the close/assignment command never duplicates the assignment" continues to pass, now for a stronger reason — the retried aggregate is `identical()` to the one before, not just assignment-deduplicated).

## VALIDATION

FORMAT: `dart format` clean on all 15 changed/added files (0 changes needed). A repo-wide `dart format` finds ~150 files with pre-existing formatting drift unrelated to this change (not touched — see Scope control).
ANALYZE: `flutter analyze` — No issues found (whole repo).
FOCUSED DOMAIN: `flutter test test/game/public_demo` — 369/369 passed.
FOCUSED UI: `flutter test test/ui/public_demo` — 35/35 passed.
FULL TEST: `flutter test` — 936/936 passed.
BUILD: `flutter build web --release` — succeeded.
DIFF CHECK: `git diff --check` — clean (no whitespace errors).
CHROMIUM: Not run this session — this environment has no browser/E2E harness available (Flutter SDK was bootstrapped from scratch for this session; Playwright/Chromium E2E infrastructure used by CI was out of reach here). Deferred to independent review per task §28 ("if E2E is practical after unit/widget validation") — it was not practical in this sandbox.
WEBKIT: Not run (same reason); the known WebKit baseline failure was explicitly out of scope for this implementation regardless (task §27).

## P0/P1/P2/P3

P0: 0 (open). The July insufficient-cash rollback — the task's named P0 — is removed and regression-tested (E/E2/F/G/H plus the three rewritten pre-existing tests).
P1: 0 (open).
P2: 0 (open).
P3: 0 (open).

## CHANGED FILES

```
 lib/game/public_demo/public_demo_aggregate.dart                       | 156 +++++++++----
 lib/game/public_demo/public_demo_financial_status.dart                (new)
 lib/game/public_demo/public_demo_internal_training_transaction.dart   |  13 ++
 lib/game/public_demo/public_demo_monthly_close.dart                   |  46 ++--
 lib/game/public_demo/public_demo_state.dart                           | 107 ++++++++-
 lib/game/public_demo/public_demo_summer_bonus_payment.dart            |  64 +++--
 lib/ui/public_demo/public_demo_01_placeholder_screen.dart             |  24 +-
 test/game/public_demo/public_demo_financial_status_test.dart          (new)
 test/game/public_demo/public_demo_monthly_close_ordinary_month_test.dart |  21 +-
 test/game/public_demo/public_demo_monthly_close_revenue_test.dart     |  43 ++--
 test/game/public_demo/public_demo_monthly_close_test.dart             |   8 +-
 test/game/public_demo/public_demo_summer_bonus_payment_test.dart      |  34 ++-
 test/ui/public_demo/public_demo_01_assignment_carryforward_test.dart  | 260 ++++++++++++---------
 test/ui/public_demo/public_demo_01_completion_lock_ui_test.dart       | 235 ++++++++++---------
 test/ui/public_demo/public_demo_01_fiscal_year_progression_test.dart  |  85 ++++---
```

## SCOPE CONTROL

No loans/capital injection/bank financing/interest/credit rating were implemented. No bankruptcy-result UI/redesign was built (domain data — `financialStatus`, closing cash, month — is all a future 1C screen would need; no new result-screen work was done). No save/load UI or runtime-persistence system was added — JSON compatibility only. No Revenue formula, Growth calculation, or balance constant (salary, fixed cost, revenue rate) was changed. No WebKit stabilization work was performed. The three widgets I edited (`public_demo_01_placeholder_screen.dart`) received exactly two one-line UI touches: a new snackbar message for the new recruitment-rejection status, and reusing the *existing* `!s.fiscalYearCompleted` terminal-hide pattern for the raise/training CTAs as `!s.isCloseBlocked` (extending an existing gate to an existing UI element — not a new UI surface). A repo-wide `dart format` run revealed ~150 files with pre-existing, unrelated formatting drift (not part of this change); I did not reformat them, to keep this diff scoped to FINANCE-FAILURE-1A+1B only.

## FINANCE-FAILURE EXIT

READY — implemented, tested, and pushed.

## VERDICT

FINANCE-FAILURE-1A+1B IMPLEMENTED / READY FOR INDEPENDENT REVIEW

## NEXT

Codex independent FINANCE-FAILURE-1A+1B review.
