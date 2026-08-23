# SES 12MONTH-1 — Common Monthly Close Scaffold — Result

## 1. Base main

`origin/main` at session start: `220f6b45bb38bf2265031f725273de26de2d88a3`
("feat(public-demo): add revenue and 30-day payment domain (#58)").

This matches the "12MONTH-0調査時のmain" hash given in the task, so `origin/main`
had not moved since the 12MONTH-0 investigation. No STOP condition triggered here.

Note: the referenced report `SES_12MONTH-0_Architecture_Research_ClaudeCode_Report.md`
does not exist anywhere in this repository (checked working tree, all branches'
history, and the filesystem). It was never committed. Since there is nothing to
compare against, this is not treated as a main-vs-report contradiction (which
would require a STOP); instead, all Step 2 research below was done directly
against the current `origin/main` source, as the task's Step 2 already asks for.

## 2. Branch / HEAD

- Branch created from `origin/main`: `feature/public-demo-12month-1-monthly-close-scaffold`
- Base commit: `220f6b45bb38bf2265031f725273de26de2d88a3`
- The container's pre-existing branch (`claude/monthly-close-scaffold-838v6d`,
  HEAD `f4ca78f...`) was an unrelated stale ancestor of `main` with a clean
  working tree; it was left untouched and the new branch was created directly
  from `origin/main` per the task's Step 1.

## 3. Current transition APIs (as re-confirmed on latest main)

`lib/game/public_demo/public_demo_state.dart`:

- `advanceToMay({monthlyExpenses, orderedEngineers})` — guarded by `month == 4`;
  clamps `orderedEngineers` to `[0, engineerCount]`, **overwrites**
  `engineersAssigned`/`engineersWaiting`, resets `salesUsed`, deducts
  `monthlyExpenses` from cash.
- `advanceToJune({monthlyExpenses, acceptedHires, hiredWithOrders, joinedApplicantIds})`
  — guarded by `month == 5`; **adds** `hires` to `engineerCount`, **adds**
  `ordered` to `engineersAssigned` (additive, unlike April/June's overwrite),
  merges `joinedApplicantIds` de-duplicated.
- `advanceToJuly({monthlyExpenses, assignedInJuly})` — guarded by `month == 6`;
  clamps and **overwrites** `engineersAssigned`/`engineersWaiting` again (same
  shape as April).
- `advanceToAugust({monthlyExpenses, applicants})` — thin wrapper that calls
  `PublicDemoSummerBonusPayment.closeJuly(state: this, ...)`, which atomically
  settles `monthlyExpenses + bonusAmount` against cash, or leaves state
  untouched (`insufficientCash`) if it can't.

These four APIs, plus `applyMonthlyGrowth`, are called from the UI
(`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`) as
`_closeGrowth(assignedIds).advanceToX(...)` chains inside each month's
`april()/may()/june()/july()` handler — confirmed unchanged from the
description in the task brief.

## 4. Common Close design

Chosen shape: `PublicDemoMonthlyClose`, a static facade class in
`lib/game/public_demo/public_demo_monthly_close.dart`, with one method per
month being closed (`closeApril`, `closeMay`, `closeJune`, `closeJuly`) —
naming intentionally mirrors the existing `PublicDemoSummerBonusPayment.closeJuly`
convention ("close<Month>" = the month being closed, not the month being
entered).

Each method is a **thin delegator**: it takes the exact same parameters the
corresponding `advanceToX`/`closeJuly` call already takes, calls that existing
method unchanged, and wraps the returned `PublicDemoState` (or, for July, the
existing `PublicDemoSummerBonusPaymentResult`) in one common result type,
`PublicDemoMonthlyCloseResult`. No transition logic, cash rule, clamp/overwrite
behavior, or ordering was reimplemented — the facade calls the pre-existing
code, it does not duplicate it.

This directly follows the task's "最重要原則": common API → existing logic,
not a rewrite. The four month-specific parameter signatures were intentionally
kept **separate** rather than merged into one universal request object, per
the "無理に巨大な万能parameterへ一度に変換しない" instruction — each `closeX`
method's parameters are exactly what its wrapped `advanceToX`/`closeJuly`
method already needs, nothing more.

Growth (`applyMonthlyGrowth`) was deliberately **not** folded into the facade.
See §16.

## 5. Added files

- `lib/game/public_demo/public_demo_monthly_close.dart` — the facade
  (`PublicDemoMonthlyClose`, `PublicDemoMonthlyCloseResult`,
  `PublicDemoMonthlyCloseStatus`).
- `test/game/public_demo/public_demo_monthly_close_test.dart` — 10 equivalence
  tests (§9–12).
- `SES_12MONTH-1_Common_Monthly_Close_Result.md` — this report.

## 6. Modified files

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — the four
  month-end handlers (`april()`, `may()`, `june()`, `july()`) now call
  `PublicDemoMonthlyClose.closeApril/closeMay/closeJune/closeJuly(...).state`
  instead of calling `advanceToMay/advanceToJune/advanceToJuly/advanceToAugust`
  directly. `_closeGrowth(...)` (the growth step) is unchanged and still runs
  in the UI, immediately before the facade call, in the same order as before.
  No screen text, CTA label, dialog, or per-month UI branch was touched.

## 7. API

```dart
class PublicDemoMonthlyClose {
  static PublicDemoMonthlyCloseResult closeApril({
    required PublicDemoState state,
    required int monthlyExpenses,
    required int orderedEngineers,
  });

  static PublicDemoMonthlyCloseResult closeMay({
    required PublicDemoState state,
    required int monthlyExpenses,
    required int acceptedHires,
    required int hiredWithOrders,
    List<String> joinedApplicantIds = const [],
  });

  static PublicDemoMonthlyCloseResult closeJune({
    required PublicDemoState state,
    required int monthlyExpenses,
    required int assignedInJuly,
  });

  static PublicDemoMonthlyCloseResult closeJuly({
    required PublicDemoState state,
    required int monthlyExpenses,
    required Iterable<PublicDemoApplicant> applicants,
  });
}
```

Each method delegates 1:1 to its existing counterpart
(`state.advanceToMay(...)`, `state.advanceToJune(...)`, `state.advanceToJuly(...)`,
`PublicDemoSummerBonusPayment.closeJuly(...)`).

## 8. Result model

```dart
class PublicDemoMonthlyCloseResult {
  final PublicDemoState state;
  final PublicDemoMonthlyCloseStatus status; // closed | insufficientCash | notApplicable
  final int cashBefore;
  final int closedMonth;
  bool get isClosed;
  bool get isInsufficientCash;
  int get cashAfter;    // state.cash
  int get cashMovement; // cashAfter - cashBefore
}
```

Kept to the task's stated minimum (`state`, `status`) plus the explicitly
allowed extras (`cashBefore`, `cashAfter`, `closedMonth`). No speculative
future-facing fields were added.

## 9. 4→5 equivalence

`test/game/public_demo/public_demo_monthly_close_test.dart`, group
`"4->5 equivalence (April close)"` — 3 tests: normal order path, zero-order
path, and wrong-month no-op path. Each compares `state.advanceToMay(...)`
directly against `PublicDemoMonthlyClose.closeApril(...).state` field-by-field
(month, cash, salesUsed, engineerCount, engineersAssigned, engineersWaiting,
joinedApplicantIds, summer-bonus fields, trainingSelections,
growthAppliedMonths, engineerRuntimes JSON, pendingRevenue). **PASS.**

## 10. 5→6 equivalence

Group `"5->6 equivalence (May close)"` — 2 tests: hire-with-order path and
wrong-month no-op path, same field comparison as §9. **PASS.**

## 11. 6→7 equivalence

Group `"6->7 equivalence (June close)"` — 2 tests: single-assignment path and
wrong-month no-op path, same field comparison. **PASS.**

## 12. 7→8 equivalence

Group `"7->8 equivalence (July close)"` — 3 tests: normal atomic paid path,
insufficient-cash path (state must stay `identical()`/`same()` on both sides),
and wrong-month no-op path. Also asserts `cashMovement`/`cashAfter` match the
legacy `PublicDemoSummerBonusPaymentResult`. **PASS.**

All 10 equivalence tests pass; see §20/§21.

## 13. Cash behavior

Unchanged. `closeApril/closeMay/closeJune` still just call
`cash - monthlyExpenses` inside the wrapped `advanceToX` methods (no new
arithmetic in the facade). `closeJuly` still calls
`PublicDemoSummerBonusPayment.closeJuly`, so `monthlyExpenses + bonusAmount`
still settles atomically (both change or neither does) exactly as before.
Recruitment-media and internal-training immediate charges are untouched (they
are not part of any `advanceToX`/`closeJuly` call and were not touched by this
change).

## 14. Salary behavior

Untouched. `PublicDemoSalaryFinance.monthlyExpenses(...)` is still computed in
the UI exactly as before and passed in as `monthlyExpenses` — the facade does
not compute or alter it.

## 15. Bonus behavior

Untouched. `closeJuly` calls the existing `PublicDemoSummerBonusPayment.closeJuly`
unchanged; bonus calculation, eligibility, and the paid/insufficientCash/
notApplicable statuses are the same, just re-exposed through
`PublicDemoMonthlyCloseStatus`.

## 16. Growth behavior

`applyMonthlyGrowth` (the Growth calculation itself) was **not** modified, and
was deliberately **not folded into the facade**. Growth needs
`assignedEngineerIds`/`moraleByEngineerId`, which are derived from UI-only,
non-`PublicDemoState` collections (`engineers`, `applicants`, `assignments`).
Wrapping Growth into `PublicDemoMonthlyClose` was considered — it would not
have required any state-model move — but was judged to add call-surface
complexity (a facade method with both growth and transition parameters,
edging toward the "巨大な万能parameter" the task warns against) without a
concrete need in this scaffold. The existing UI order
(`_closeGrowth(...)` → `PublicDemoMonthlyClose.closeX(...)`) is preserved
exactly, so growth-then-transition ordering is unchanged; only the second half
of that chain now goes through the facade. This is a scoping decision, not a
STOP — it can be revisited in a later phase if a concrete need arises.

## 17. Revenue isolation

`PublicDemoRevenuePayment.apply(...)` is not imported, referenced, or called
anywhere in `public_demo_monthly_close.dart` or in the UI's migrated handlers.
Grep-confirmed: no reference to `PublicDemoRevenuePayment` exists outside its
own file and its own test file.

## 18. pendingRevenue

Every equivalence test explicitly asserts `pendingRevenue` is identical
between the legacy path and the facade path, and that it is `0` after each
April/May/June close (starting state's default) — i.e. unaffected by the
facade. Confirmed unchanged.

## 19. UI migration

Completed (not deferred to 12MONTH-1B). All four month-end handlers
(`april()`, `may()`, `june()`, `july()`) now call the common facade. The diff
was small and mechanical (see §6) — no screen text, CTA, dialog, or per-month
branch changed. Verified end-to-end via the existing widget test
`test/ui/public_demo/public_demo_01_success_playthrough_test.dart`, which
presses the real month-end buttons through July and passed unchanged.

## 20. Tests

- New: `test/game/public_demo/public_demo_monthly_close_test.dart` (10 tests,
  §9–12), all passing.
- Full Public Demo suite (`test/game/public_demo/` + `test/ui/public_demo/`):
  **188/188 passing**, including Revenue 1–3 pure tests
  (`public_demo_revenue_state_test.dart`, `public_demo_revenue_payment_test.dart`),
  salary, summer bonus, recruitment media, training, growth, JUNIOR/applicant
  experience, JSON round-trip tests, and the UI playthrough widget test.

## 21. Full test

`flutter test` (whole repo): **720/720 passing.** No regressions outside
Public Demo either (guided-founding widget tests, project interview,
UX guidance, applicant generator, etc.).

## 22. Diff check

`git diff --check`: clean, no whitespace errors.

## 23. Remote HEAD

Not yet pushed at time of writing this section; see final push step. Branch:
`feature/public-demo-12month-1-monthly-close-scaffold`.

## 24. Remaining blockers

None for this scaffold's own scope. Notable pre-existing repo condition found
during the quality gate, unrelated to this change: `dart format --set-exit-if-changed .`
reports ~165 files across the repo (mostly `test/ui/*`, `tool/*`, unrelated to
Public Demo) as not matching this session's Dart SDK's formatter output. This
predates this branch (confirmed: none of those files were touched here) and
was left untouched per the "unrelated cleanup禁止" rule. Every file this
change added or touched (`public_demo_monthly_close.dart`,
`public_demo_monthly_close_test.dart`,
`public_demo_01_placeholder_screen.dart`) is itself correctly formatted.

Also note: this sandbox had no Flutter SDK preinstalled. Flutter 3.44.8
(matching `public-demo-validation.yml`'s pinned CI version) was fetched via
`git clone --branch 3.44.8 https://github.com/flutter/flutter.git` into
`/home/user/flutter-sdk` (outside the repo) to run the quality gate below.

## 25. 12MONTH-2 handoff

- `PublicDemoMonthlyClose` now exists as the single call surface for
  April–July closes; September onward can add new `closeX` methods to the
  same facade without touching `advanceToMay/June/July` or
  `PublicDemoSummerBonusPayment`.
- REVENUE-4 (wiring `PublicDemoRevenuePayment.apply(...)` into the close path)
  is the natural next step for this facade: each `closeX` method's result
  already carries `cashBefore`/`cashAfter`, so a revenue-aware close could be
  added as a new composed step (e.g. `closeX(...)` then apply revenue, or a
  revenue-aware wrapper) without touching the four wrapped legacy methods.
  Not attempted here — out of scope per the task.
- The `engineersAssigned` overwrite-vs-additive asymmetry between
  April/June (overwrite) and May (additive) is preserved as-is inside the
  wrapped methods; unifying it is explicitly deferred, as instructed.
- `engineers`/`applicants`/`assignments` still live outside `PublicDemoState`
  in UI-only lists; Growth still requires UI-supplied `assignedEngineerIds`/
  `moraleByEngineerId`. This remains a prerequisite for any future attempt to
  fold Growth into the facade, or for save/load — both explicitly out of
  scope for 12MONTH-1.

---

## Summary

```
BASE MAIN: 220f6b45bb38bf2265031f725273de26de2d88a3
BRANCH: feature/public-demo-12month-1-monthly-close-scaffold
HEAD: (set after commit, see push confirmation)
COMMON CLOSE API: PublicDemoMonthlyClose (closeApril/closeMay/closeJune/closeJuly) — lib/game/public_demo/public_demo_monthly_close.dart
UI MIGRATED: YES (all 4 month-end handlers in public_demo_01_placeholder_screen.dart)
4→5: PASS (3 tests)
5→6: PASS (2 tests)
6→7: PASS (2 tests)
7→8: PASS (3 tests)
CASH REGRESSION: NONE
SALARY REGRESSION: NONE
BONUS REGRESSION: NONE
GROWTH REGRESSION: NONE
REVENUE CONNECTED: NO
PENDING REVENUE CHANGED: NO
FORMAT: PASS (all added/modified files; ~165 pre-existing unrelated files left untouched)
ANALYZE: PASS (No issues found!)
FOCUSED: PASS (10/10 public_demo_monthly_close_test.dart)
PUBLIC DEMO: PASS (188/188)
FULL TEST: PASS (720/720)
DIFF CHECK: PASS
REMOTE HEAD: (set after push, see push confirmation)

VERDICT:
PASS

NEXT:
12MONTH-2 / REVENUE-4
```
