# S.E.S. Public Demo 0.1 — POST-12MONTH-1-FIX1: Fiscal Completion Domain Guard Fixes — Result

## 1. Git state

```
BASE:                199e2a3af20b1cdb4116589561058f610328ccca
SOURCE HEAD:         0e15e50e629dacacbb224528dbb91b7648813cf0 (matched the reviewed remote target)
BRANCH:              feature/public-demo-post12month-1-completion-lock-fix1 (created from the above)
```
`git fetch origin` + `git status` confirmed a clean working tree with no tracked changes before starting; no stash was touched; no untracked files existed to touch.

## 2. P1-1 reproduction

Before any fix, `PublicDemoApplicant.decideRaise` accepted `fiscalYearCompleted` as an **optional named parameter defaulting to `false`**:

```dart
PublicDemoApplicant decideRaise({
  required int decisionMonth,
  required int week,
  required PublicDemoRaiseDecision decision,
  bool fiscalYearCompleted = false,   // caller-supplied, defaults to "not completed"
})
```

Any caller that simply didn't pass `fiscalYearCompleted` — or passed `false` — got the pre-lock behavior back, **even against a `PublicDemoState` where `fiscalYearCompleted` was actually `true`**, because the applicant object has no reference to the state at all; it only trusted whatever the caller told it. This is exactly the shape Codex flagged: UI happened to pass the flag correctly, but the guard's real authority was the caller, not the state.

## 3. Raise root cause

`PublicDemoApplicant` is a plain domain value object with no `PublicDemoState` reference. The previous fix (POST-12MONTH-1) tried to make it "know" about completion by threading a bool through every call, which structurally cannot be an authoritative guard — a bool parameter can always be omitted, defaulted, or (in theory) misreported by a future caller. The actual authority — `state.fiscalYearCompleted` — was never consulted directly at the point of mutation.

## 4. Raise design

Per the task's explicit design principle ("APIがPublicDemoState自身を参照してstate.fiscalYearCompletedをauthorityにする"), the fix moves the check to a layer that **must** hold the real state:

- `PublicDemoApplicant.canRequestRaiseIn`/`decideRaise` are reverted to their pre-lock signatures (no `fiscalYearCompleted` parameter at all) — they remain a pure in-window/already-decided check, nothing more, and are documented as *not* the terminal-state gate.
- A new `PublicDemoRaiseTransaction` (`lib/game/public_demo/public_demo_raise_transaction.dart`) is the single sanctioned entry point. Its `execute()` takes `required PublicDemoState state` and reads `state.fiscalYearCompleted` directly as its first check — there is no separate flag to omit, default, or override. This mirrors the exact shape of the codebase's existing state-authoritative transactions (`PublicDemoInternalTrainingTransaction`, `PublicDemoRecruitmentTransaction`).

This was **not** "flip the default to `true`" (forbidden by the task) — the bool parameter is gone entirely, and **not** a UI-only fix (forbidden) — the domain layer (`PublicDemoRaiseTransaction`) is the actual enforcement point; the UI change is only to call through it instead of the old direct method.

## 5. Raise fix

- `lib/game/public_demo/public_demo_raise.dart`: `canRequestRaiseIn(int month)` and `decideRaise({required decisionMonth, required week, required decision})` — both back to their exact pre-lock signatures, with doc comments now explicitly pointing callers to `PublicDemoRaiseTransaction`.
- `lib/game/public_demo/public_demo_raise_transaction.dart` (new): `PublicDemoRaiseTransaction.execute({required state, required applicant, required decisionMonth, required week, required decision})` → `PublicDemoRaiseTransactionResult` with `status` ∈ `{success, notEligible, fiscalYearCompleted}` (same enum-status/unchanged-value pattern the other transactions already use).
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`: `raise()` now calls `const PublicDemoRaiseTransaction().execute(state: s, applicant: a, ...).applicant` instead of `a.decideRaise(..., fiscalYearCompleted: s.fiscalYearCompleted)`. The CTA visibility check in `employeeConditionCard` now reads `!s.fiscalYearCompleted && a.canRequestRaiseIn(s.month)` — `s.fiscalYearCompleted` is read directly off the actual state in scope, not funneled through a defaultable parameter.

Pre-completion raise behavior (eligible month, decision, salary update, morale, trust, effective timing) is byte-identical — verified by a new test asserting `PublicDemoRaiseTransaction` produces the exact same result as the old direct `decideRaise` call when not completed (section 6).

## 6. P1-1 regression tests

`test/game/public_demo/public_demo_fiscal_year_completion_lock_test.dart`, group **A**:
- `PublicDemoRaiseTransaction` rejects with `fiscalYearCompleted` status when `state.fiscalYearCompleted == true`, even for an applicant that is fully in-window and eligible — applicant object comes back `identical()` (no mutation): `raiseDecision`, `raisedMonthlySalary`, `employeeMorale`, `employeeCompanyTrust`, `relationshipHistory`, and `salaryForMonth` are all unchanged.
- The transaction API has **no flag to override**: passing an otherwise-identical but *not*-completed state (`copyWith(fiscalYearCompleted: false)`) succeeds normally — proving the prior rejection came from `state.fiscalYearCompleted`, not some other condition, and that there is no bypass parameter to find.

Group **D** (pre-completion regression):
- `PublicDemoRaiseTransaction` produces the exact same result as calling `decideRaise` directly when not completed (salary, decision, `salaryForMonth`).
- `PublicDemoRaiseTransaction` still respects the pre-existing eligibility window (`notEligible` status for a too-early month) when not completed.

## 7. P1-2 reproduction

`PublicDemoRevenuePayment.apply` had **no completion check whatsoever**:

```dart
static PublicDemoRevenuePaymentResult apply({required PublicDemoState state}) {
  final revenueReceived = state.pendingRevenue;
  final revenueRecognized = PublicDemoRevenue.monthlyRevenueForAssignedCount(state.engineersAssigned);
  return PublicDemoRevenuePaymentResult._(
    state: state.copyWith(cash: state.cash + revenueReceived, pendingRevenue: revenueRecognized),
    ...
  );
}
```

Calling this directly against a `PublicDemoState` with `fiscalYearCompleted: true`, `cash: 4,000,000`, `pendingRevenue: 1,000,000`, `engineersAssigned: 2` moved cash to 5,000,000 and `pendingRevenue` to 1,000,000 — a clean domain bypass, confirmed by a new test before the fix (then re-asserted as fixed afterward; see section 11).

## 8. Revenue root cause

Unlike the raise API, `PublicDemoRevenuePayment.apply` already took `PublicDemoState` as its one required parameter — so, unlike P1-1, there was never a caller-suppliable flag to worry about. The gap was simpler: the method just never consulted `state.fiscalYearCompleted` at all before mutating.

## 9. March Revenue ordering

Traced the real call sequence in `PublicDemoMonthlyClose.closeOrdinaryMonth` (`lib/game/public_demo/public_demo_monthly_close.dart`) for the March-close path (`closedMonth == 15`):

```dart
final isOrdinaryMonth = closedMonth >= 8 && closedMonth <= 15 && !state.fiscalYearCompleted;
final revenueApplied = isOrdinaryMonth
    ? PublicDemoRevenuePayment.apply(state: state).state   // ← Revenue settles here
    : state;
final next = closedMonth == 15
    ? revenueApplied.completeFiscalYear(monthlyExpenses: monthlyExpenses)  // ← flag set here
    : revenueApplied.advanceToNextOrdinaryMonth(monthlyExpenses: monthlyExpenses);
```

At the moment `PublicDemoRevenuePayment.apply` runs during March's own close, `state.fiscalYearCompleted` is still `false` (that's what makes `isOrdinaryMonth` true in the first place) — `completeFiscalYear` only sets the flag *afterward*, on the already-Revenue-applied state. This confirms the task's "safe" ordering: **Revenue settles first, completion flag second.** A guard added directly inside `apply()` cannot suppress March's own settlement — it can only ever reject a call made *after* the flag is already `true`.

## 10. Revenue fix

`lib/game/public_demo/public_demo_revenue_payment.dart`: `apply()` now starts with

```dart
if (state.fiscalYearCompleted) {
  return PublicDemoRevenuePaymentResult._(state: state, revenueReceived: 0, revenueRecognized: 0);
}
```

before doing anything else. `state` is a required parameter, not an optional flag — there is nothing for a caller to omit or override; the actual state object is the only thing consulted. The class's docstring was updated to describe this terminal-state behavior rather than inventing a new exception/failure framework — same "return the unchanged value" pattern already used throughout this codebase.

## 11. P1-2 regression tests

`test/game/public_demo/public_demo_revenue_payment_test.dart`, new group **"terminal state guard (POST-12MONTH-1-FIX1 P1-2)"**:
- A direct call once completed leaves `cash` and `pendingRevenue` unchanged (`identical(result.state, state)`), even with non-zero pending revenue and assigned engineers that would otherwise move both; `revenueReceived`/`revenueRecognized` both report `0`.
- An otherwise-identical **not**-completed state still settles normally (cash +1,000,000, pendingRevenue recomputed) — proving the guard is specifically `fiscalYearCompleted`, not some other field.
- March close still settles Revenue correctly end-to-end: previous `pendingRevenue` (1,000,000) becomes cash, March's own 2-assigned-engineer revenue (1,000,000) becomes the new `pendingRevenue`, and *then* `completeFiscalYear` sets `fiscalYearCompleted = true` — pinning the exact ordering section 9 relies on, without duplicating the full `closeOrdinaryMonth` suite already in `public_demo_monthly_close_ordinary_month_test.dart`.

## 12. Domain mutation audit

Searched `fiscalYearCompleted`, `= false`, `optional bool`, `apply(`, `execute(`, `decide(`, `select(`, `use(`, `copyWith(` across `lib/game/public_demo/` and `lib/ui/public_demo/`. After the two fixes above:
- `grep -rn "fiscalYearCompleted" lib/` shows the flag now only appears in `public_demo_state.dart` (its home), `public_demo_raise_transaction.dart`, `public_demo_revenue_payment.dart`, `public_demo_internal_training_transaction.dart`, `public_demo_01_placeholder_screen.dart`, and `public_demo_monthly_close.dart` — every occurrence reads `state.fiscalYearCompleted` (or `this.fiscalYearCompleted` inside `PublicDemoState` itself) directly off a real state object; **no other caller-suppliable boolean parameter of this shape exists anywhere in the codebase.**
- `PublicDemoState._selectTraining`, `cancelTraining`, `useSalesSlot`, `selectSummerBonus` (existing POST-12MONTH-1 guards) all check `this.fiscalYearCompleted` as instance methods — structurally immune to the P1-1-style bypass since there is no parameter to pass at all.
- No further same-shaped issue was found. Nothing required an architecture change, so nothing was escalated to STOP.

## 13. Changed files

```
lib/game/public_demo/public_demo_raise.dart                              |  30 ++---
lib/game/public_demo/public_demo_raise_transaction.dart (new)            |  65 ++++++++
lib/game/public_demo/public_demo_revenue_payment.dart                    |  17 ++-
lib/ui/public_demo/public_demo_01_placeholder_screen.dart                |  27 ++--
test/game/public_demo/public_demo_fiscal_year_completion_lock_test.dart  | 111 ++++++++----
test/game/public_demo/public_demo_revenue_payment_test.dart              |  65 ++++++++
```
6 files changed, 258 insertions(+), 57 deletions(-).

## 14. Completion tests

`public_demo_fiscal_year_completion_lock_test.dart` (10 tests, up from 9 — the old caller-flag-based raise tests were replaced with transaction-based ones, and 2 net tests were added to groups A and D) and `public_demo_01_completion_lock_ui_test.dart` (1 test, unchanged) both pass. The UI test's coverage of the training CTA and read-only navigation was untouched by this fix (P1-1/P1-2 are both domain-layer issues; no UI CTA bypass was found).

## 15. Revenue tests

`public_demo_revenue_payment_test.dart`: 17 pre-existing tests unchanged + 3 new terminal-state-guard tests = 20/20 pass.

## 16. Monthly Close tests

`public_demo_monthly_close_ordinary_month_test.dart` and `public_demo_monthly_close_test.dart` — unmodified, all pass, including "closing March a second time is a no-op" and the full "4 → 5 → 6 → 7 → 8 → ... → 15 → fiscal year complete" progression.

## 17. Public Demo tests

`flutter test test/game/public_demo/ test/ui/public_demo/` → **253/253 PASS**.

## 18. Full tests

`flutter test` → **785/785 PASS** (prior baseline 780 + 5 net new tests; no regressions).

## 19. Format

`dart format --output=none --set-exit-if-changed` on every file this fix touched:
- `lib/game/public_demo/public_demo_raise_transaction.dart` (new), `lib/game/public_demo/public_demo_revenue_payment.dart`, `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`, both test files: **clean** (0 changed) after running `dart format` once.
- `lib/game/public_demo/public_demo_raise.dart`: still reports "Changed" under the locally available Flutter 3.44.9 formatter — this is the **same pre-existing repo-wide formatter/environment drift** already documented in the POST-12MONTH-1 result report (confirmed there via a `git stash` control test: this exact file, unmodified from `origin/main`, already reports "Changed" before any edit). My edit reverted this file's raise-related code to its pre-lock shape and did not introduce any new drift beyond what already existed.

## 20. Analyze

`flutter analyze` (full repo) → **No issues found!**

## 21. Diff check

`git diff --cached --check` → clean (no whitespace errors).

## 22. Commit

```
5c68007b6f5200383615a8d2a9d2f2802a365837
fix(public-demo): enforce terminal state in domain mutations
```
Normal push, no force, no history rewrite. This result report is intentionally **not** included in this commit.

## 23. Remote HEAD

```
origin/feature/public-demo-post12month-1-completion-lock-fix1 @ 5c68007b6f5200383615a8d2a9d2f2802a365837
```
Matches local HEAD.

## 24. Remaining findings

None outstanding from this round's scoped audit (section 12). Everything already listed as a follow-up in the original POST-12MONTH-1 result report (ordinary Monthly Close negative cash, month-7 recruitment dead-end, month-8 recruitment hardening, save impossible-state validation, Revenue/year-end visualization, formal assignment lifecycle, FINANCE) remains untouched and out of scope here.

## 25. Final verdict

**PASS** — see the Final Display block in the chat response.
