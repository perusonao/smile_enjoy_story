# SES PAYROLL-1B Integration Design

Status: Design only / implementation not started
Depends on: PAYROLL-1A (`PayrollEngine`) merged to `main`
Priority: Financial correctness / preserve existing behavior

## 1. Goal

PAYROLL-1B wires the pure legacy `PayrollEngine` introduced by PAYROLL-1A into the existing normal-game payroll call sites without changing player-visible payroll behavior.

The objective is architectural consolidation, not a new compensation system.

## 2. Current authority boundary

PAYROLL-1A establishes:

- `PayrollInput`
- `PayrollResult`
- `PayrollEngine.calculateMonthly()`
- legacy rule: every joined `Engineer` receives the full stored monthly `salary`, regardless of assignment/sales state
- active March prologue exception: a materialized pre-join engineer is excluded until the first prologue assignment has started
- General Affairs salary is calculated separately and included in total payroll

PAYROLL-1B must make this engine the single monthly salary calculation authority used by Finance/GameEngine while preserving all current settlement semantics.

## 3. Scope

PAYROLL-1B should only:

1. Replace duplicated monthly salary summation in `FinanceEngine` with a call to `PayrollEngine.calculateMonthly()`.
2. Reuse the same `PayrollResult` for month-end settlement in `GameEngine` where salary totals are currently recomputed.
3. Preserve existing `MonthlyClosing` values and historical-save interpretation.
4. Preserve HUD/month-end forecast values exactly.
5. Preserve the March founding payroll boundary exactly.

## 4. Explicit non-goals

Do not add in PAYROLL-1B:

- employment contracts
- contractor/freelancer compensation
- social insurance or pension contributions
- transportation allowance
- overtime/time-range settlement
- bonuses
- retirement allowance
- salary-linked billing-rate formulas
- raises or compensation-request integration beyond reading the already-stored `Engineer.salary`
- save-schema changes
- Public Demo rule changes

Those belong to later payroll/employment phases.

## 5. Proposed integration shape

Create one small adapter/helper at the Finance/GameState boundary if necessary. The adapter converts current state into `PayrollInput`:

- `engineers: state.engineers`
- `generalAffairsStaff: state.generalAffairsStaff`
- `isPrologueActive: state.prologueState.active`
- `hasStartedPrologueAssignment: state.activeAssignments.isNotEmpty` only where this exactly matches the existing founding rule; if the current code has a more precise existing predicate, preserve that predicate instead of broadening it

Then:

- `FinanceEngine.monthlySalaryTotal(state)` returns `PayrollEngine.calculateMonthly(input).totalSalary`
- any engineer-only salary display uses `engineerSalaryTotal`
- any General Affairs-only display uses `generalAffairsSalaryTotal`
- month-end settlement consumes the same result rather than separately folding salaries

Do not let UI widgets instantiate payroll rules directly.

## 6. Required invariants

PAYROLL-1B is accepted only if all of these stay true:

- `cashAfter - cashBefore == monthCashMovement`
- salary cash deduction occurs exactly once per monthly closing
- `MonthlyClosing.salaryExpense` (or equivalent stored salary field) stays equivalent for the same pre-change game state
- joined waiting/selling/interviewing/assigned engineers remain full-pay legacy employees
- PendingHire remains outside payroll until it becomes an Engineer
- active March prologue pre-join engineer remains excluded
- the same engineer becomes included at the existing April payroll/start boundary
- General Affairs salary remains included exactly once
- forecast/HUD payroll and actual closing payroll do not diverge because of separate formulas

## 7. Test plan

Add regression tests around the integration, not a second copy of PAYROLL-1A unit tests.

Minimum cases:

1. `FinanceEngine.monthlySalaryTotal` equals `PayrollEngine.totalSalary` for multiple engineers + General Affairs.
2. March prologue before assignment: engineer excluded, General Affairs included.
3. First April assignment started: engineer included.
4. Waiting/assigned/interview/selling status changes do not alter legacy salary total.
5. Month-end close deducts exactly the same salary as the HUD forecast for an unchanged state.
6. Existing monthly-closing/accounting regression suite stays green.
7. Existing save fixtures deserialize with no migration.

## 8. Implementation sequence

Recommended PR sequence:

### PAYROLL-1B.1 — Finance delegation

- wire `FinanceEngine.monthlySalaryTotal` to `PayrollEngine`
- add focused unit tests
- no GameEngine settlement rewrite yet if separation reduces risk

### PAYROLL-1B.2 — Month-end settlement reuse

- remove remaining duplicate salary fold/reconstruction from GameEngine
- ensure closing records use the same calculated result
- strengthen accounting invariant tests

If the repository currently has only one duplicated call site, 1B.1 and 1B.2 may be one PR, but keep the diff limited to payroll delegation and tests.

## 9. Merge gates

Blocking:

- `flutter analyze`
- `flutter test`
- accounting/replay unit tests
- Chromium E2E
- WebKit E2E according to the repository's current agreed gate policy

No test retry/skip/timeout increase solely to make PAYROLL-1B green.

## 10. Stop conditions

Stop and redesign instead of continuing if:

- delegating to `PayrollEngine` changes an existing closing amount
- a save-schema migration becomes necessary
- the correct March payroll predicate cannot be represented by the PAYROLL-1A input without ambiguity
- Public Demo has a separate salary authority that would accidentally be changed

## 11. Later phases unlocked by this work

After PAYROLL-1B is stable, future payroll work can add explicit payroll components behind `PayrollResult` without spreading formulas again. Suggested order:

PAYROLL-2A employment terms -> PAYROLL-2B statutory/company cost components -> PAYROLL-2C allowances/time settlement -> PAYROLL-2D contractor/freelancer payment models.
