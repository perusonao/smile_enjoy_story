# S.E.S. Public Demo 0.1 — POST-12MONTH-1: Fiscal Year Completion Action Lock — Result

## 1. Base main

```
199e2a3af20b1cdb4116589561058f610328ccca
```

Confirmed as the actual latest `origin/main` at session start (`git fetch origin` + `git rev-parse origin/main`), matching the handoff value in the task brief. Local `git status` was clean; no tracked working-tree changes, no stash touched, no untracked files touched.

## 2. Branch

```
feature/public-demo-post12month-1-completion-lock
```

Created fresh from `origin/main` (199e2a3).

## 3. Start HEAD

```
199e2a3af20b1cdb4116589561058f610328ccca
```

## 4. Mutation inventory

Searched `fiscalYearCompleted`, `PublicDemoMonthlyClose`, `closeOrdinaryMonth`, raise/salary/training/recruitment/assignment/sales/interview/bonus, and every Public Demo domain/UI file for `onPressed`/`enabled`/`disabled`. Findings, classified per the task's A/B/C scheme:

| # | Mutation | Class | Notes |
|---|---|---|---|
| 1 | Raise decision (`PublicDemoApplicant.decideRaise` via the `昇給要求を確認` CTA in `employeeConditionCard`) | **A — UI-reachable** | `employeeConditionCard` renders for every joined applicant whenever `s.month >= 7`, which stays true forever once the fiscal year completes (month freezes at 15). The CTA's guard, `canRequestRaiseIn(month)`, only checked `month >= 6 && raiseDecision == null` — never `fiscalYearCompleted`. **Fixed.** |
| 2 | Internal training selection (`PublicDemoInternalTrainingTransaction` via the `研修する` CTA in `internalTrainingCard`) | **A — UI-reachable** | `internalTrainingCard` renders for every unassigned engineer runtime whenever `s.month >= 6` — also permanently true post-completion. The CTA was only disabled by `affordable` (cash check), never by `fiscalYearCompleted`. **Fixed.** |
| 3 | `PublicDemoState.selectExternalTraining` / `cancelTraining` | **B — domain-API only** | No UI caller exists for either; reachable only by calling the state method directly. **Fixed** (defense in depth, same SSOT guard as #2). |
| 4 | `PublicDemoState.useSalesSlot()` | **B — domain-API only** | UI only calls this from within month-exact-gated code paths (April/May/June/July sections), which never render past month 15. Still directly callable via the domain API and matches the contract's forbidden "sales action" category. **Fixed.** |
| 5 | `PublicDemoState.selectSummerBonus()` | **B — domain-API only** | UI only calls this (`decideSummerBonus()`) from the month==7 section. Directly callable via the domain API and matches the contract's forbidden "bonus decision" category. **Fixed.** |
| 6 | Recruitment media (`markRecruitmentMediaUsed`, `PublicDemoRecruitmentTransaction`) | **C — already guarded** | `canUseRecruitmentMediaInMonth` normalizes valid months to 4-8 only; since `completeFiscalYear`/`advanceToNextOrdinaryMonth` never advance `month` past 15, and 15 is outside 4-8, this is unconditionally false once the year is over. No UI section renders the recruitment-media card past month 7 either. No change needed. |
| 7 | Monthly Close re-execution (`PublicDemoMonthlyClose.closeOrdinaryMonth`, `completeFiscalYear`, `advanceToNextOrdinaryMonth`, `advanceToMay/June/July`) | **C — already guarded** | `closeOrdinaryMonth` explicitly excludes `fiscalYearCompleted` from what counts as an ordinary month; `completeFiscalYear` itself is idempotent; the per-month `advanceToX` methods are gated by exact month equality, which month 15 (frozen) never satisfies for April/May/June. Existing test (`public_demo_monthly_close_ordinary_month_test.dart`: "closing March a second time is a no-op") already covers this. No change needed. |
| 8 | Summer bonus payment (`PublicDemoSummerBonusPayment.closeJuly` / `markSummerBonusPaid`) | **C — already guarded** | Both check `state.month != 7`, which is never true again once month freezes at 15. No change needed. |
| 9 | Sales-stage / interview / offer / assignment-order UI actions (`ei`, `recruit`, `offer`, `pi`, `decideOrder`, `acceptOrder`, `replacementPartner`, `replacementClient`, `es`, `as`, `ars`) | **C — already guarded** | Every card that exposes these (`ec`, `ac`, `assignmentCard`) is rendered only inside `if (s.month == 4/5/6)` blocks in the build method, which cannot be true once the year is over. No change needed. |

No other same-shaped gap was found. The scope stayed inside the small, itemized set above — no large refactor was needed or attempted.

## 5. Existing guards

Already-safe patterns found and relied upon rather than rebuilt:
- `PublicDemoMonthlyClose.closeOrdinaryMonth`'s `isOrdinaryMonth` check already excludes `fiscalYearCompleted`.
- `PublicDemoState.completeFiscalYear` is self-idempotent (`if (month != 15 || fiscalYearCompleted) return this;`).
- `PublicDemoState.advanceToMay/June/July` and `advanceToNextOrdinaryMonth` are all gated by exact/bounded month checks that month 15 (frozen forever post-completion) cannot re-enter.
- `PublicDemoSummerBonusPayment.closeJuly` / `markSummerBonusPaid` are gated by `month != 7`.
- `canUseRecruitmentMediaInMonth` is gated to months 4-8.
- Every result type in this codebase already uses a status-enum + unchanged-state pattern for rejected transactions (`PublicDemoInternalTrainingStatus`, `PublicDemoRecruitmentTransactionStatus`, `PublicDemoMonthlyCloseStatus`, `PublicDemoSummerBonusPaymentStatus`). New guards below reuse this pattern instead of inventing a new failure framework.

## 6. Raise

- `PublicDemoApplicant.canRequestRaiseIn(int month, {bool fiscalYearCompleted = false})` — new optional named parameter, defaulting to `false` so every pre-existing caller (all in-repo tests) keeps its exact prior behavior. Now returns `false` whenever `fiscalYearCompleted` is true, regardless of month.
- `PublicDemoApplicant.decideRaise({..., bool fiscalYearCompleted = false})` — same optional-parameter approach; forwards into `canRequestRaiseIn`, so a rejected call returns the untouched applicant (existing no-op pattern, same as the "second tap" idempotency it already had).
- UI (`public_demo_01_placeholder_screen.dart`): both the CTA's visibility condition and the `raise()` handler's `decideRaise` call now pass `s.fiscalYearCompleted` — the button is **hidden** (not just disabled) once the year is complete, since `canRequestRaiseIn` already governs whether the button renders at all (existing pattern, unchanged shape).
- Pre-completion behavior is byte-for-byte identical (verified by regression tests in section 16D and the full raise/salary/summer-bonus suites).

## 7. Training

- `PublicDemoInternalTrainingTransaction.execute` — added a `fiscalYearCompleted` check on `state`, checked **before** the cash-deduction branch, returning a new `PublicDemoInternalTrainingStatus.fiscalYearCompleted` failure (same shape as the four existing failure statuses: `unknownEngineer`, `assigned`, `alreadySelected`, `insufficientCash`). Cash is never touched on this path.
- `PublicDemoState._selectTraining` (the single implementation both `selectInternalTraining` and `selectExternalTraining` delegate to) and `PublicDemoState.cancelTraining` now short-circuit to `return this` when `fiscalYearCompleted` — this is the SSOT guard, since `PublicDemoState` is the only place that actually knows `fiscalYearCompleted`.
- UI: the `研修する` CTA and its "現預金 after training" preview text are now **hidden** (not shown disabled) once `s.fiscalYearCompleted`, since the "第1期終了" card elsewhere on the same screen already makes the reason self-evident (per the task's explicit allowance to skip new explanatory copy). The card itself (engineer name, training cost) stays visible as read-only info.
- Pre-completion behavior is unchanged (verified by the existing `public_demo_internal_training_transaction_test.dart` suite plus new regression tests).

## 8. Recruitment

No code change. `canUseRecruitmentMediaInMonth` already restricts valid months to 4-8, and month is frozen at 15 forever after completion — the guard is airtight without any new code, and no UI section renders the recruitment-media card past month 7 either. This intentionally leaves the pre-existing month-7 recruitment gap (`12MONTH-3-FIX1 P1-2`) exactly as-is, per scope.

## 9. Monthly Close

No code change needed; already fully idempotent (see section 5). Verified by the existing `public_demo_monthly_close_ordinary_month_test.dart` "closing March a second time is a no-op" test (still passing) — cash, `pendingRevenue`, and Growth (`growthAppliedMonths`) all stay unchanged on a repeat close.

## 10. Other mutations

- `PublicDemoState.useSalesSlot()` now returns `this` unchanged when `fiscalYearCompleted`, in addition to its existing `salesRemaining <= 0` guard.
- `PublicDemoState.selectSummerBonus()` now returns `this` unchanged when `fiscalYearCompleted`, in addition to its existing `summerBonusPaid` / same-plan guards.
- Both are domain-API-only (Category B) fixes — no UI change was needed since no CTA reaches either past completion — kept in scope because they match the contract's explicit "sales action" / "bonus decision" prohibitions and the fix is a one-line, same-pattern guard.

## 11. Domain guards

Every guard added follows the codebase's existing "check first, return unchanged `this`/`state` on failure" idiom — no new failure framework:
- `lib/game/public_demo/public_demo_raise.dart` — `canRequestRaiseIn`/`decideRaise` gain an optional `fiscalYearCompleted` parameter.
- `lib/game/public_demo/public_demo_state.dart` — `_selectTraining`, `cancelTraining`, `useSalesSlot`, `selectSummerBonus` all gain an internal `if (fiscalYearCompleted) return this;`/equivalent early-return.
- `lib/game/public_demo/public_demo_internal_training_transaction.dart` — new `fiscalYearCompleted` failure status, checked before the cash-deduction branch.

## 12. UI guards

`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`:
- Raise CTA (`employeeConditionCard`): hidden once completed (via `canRequestRaiseIn(..., fiscalYearCompleted: s.fiscalYearCompleted)`), and the `raise()` handler also forwards `fiscalYearCompleted` into `decideRaise` for defense in depth even if some other path ever taps it.
- Training CTA (`internalTrainingCard`): hidden once completed, along with its cash-preview text; the card's read-only info (name, cost) stays visible.
- No new explanatory text was added — the existing "第1期終了" card (unconditionally shown once `s.fiscalYearCompleted`) already makes the reason clear on the same screen, per the task's explicit allowance.

## 13. Read-only navigation

Not restricted. Employee condition text (motivation/trust labels, relationship history reason), training card info, dashboard stats (cash, assigned/waiting counts), and the "第1期終了"/final-cash card all remain visible and scrollable after completion — only the CTAs that mutate state were touched.

## 14. Reset/restart

No reset/restart flow exists anywhere in Public Demo 0.1's current implementation (confirmed by search — no such widget, route, or domain method). Per the task's own instruction not to invent functionality that doesn't exist, nothing was added or changed here.

## 15. Changed files

```
lib/game/public_demo/public_demo_internal_training_transaction.dart | 12 ++
lib/game/public_demo/public_demo_raise.dart                         | 20 ++-
lib/game/public_demo/public_demo_state.dart                         | 43 +++--
lib/ui/public_demo/public_demo_01_placeholder_screen.dart           | 18 ++-
test/game/public_demo/public_demo_fiscal_year_completion_lock_test.dart | 179 (new)
test/ui/public_demo/public_demo_01_completion_lock_ui_test.dart         | 173 (new)
```
6 files changed, 426 insertions(+), 19 deletions(-).

## 16. Focused tests

New file `test/game/public_demo/public_demo_fiscal_year_completion_lock_test.dart` (9 tests):
- **A. Raise**: `canRequestRaiseIn` false once completed even in-window; `decideRaise` is a no-op (identical object returned; salary/morale/trust/history all unchanged).
- **B. Training**: `PublicDemoInternalTrainingTransaction` rejects with the new `fiscalYearCompleted` status, cash/selections unchanged; `PublicDemoState.selectInternalTraining/selectExternalTraining/cancelTraining` are all no-ops (direct domain-API defense-in-depth check).
- **Other mutations**: `useSalesSlot` and `selectSummerBonus` are no-ops once completed.
- **D. Pre-completion regression**: raise, internal training, `useSalesSlot`, and `selectSummerBonus` all still work exactly as before when `fiscalYearCompleted` is false.

New file `test/ui/public_demo/public_demo_01_completion_lock_ui_test.dart` (1 widget test, reusing the proven April→March real-widget path from `public_demo_01_assignment_carryforward_test.dart`):
- **E**: confirms the training CTA (`public-demo-internal-training-action-eng-02`) is present pre-completion, then **gone** (not merely disabled) post-completion, while the training card itself and every "…終了→…" close button are also gone.
- **F**: confirms the "第1期終了" card, "最終現預金" text, and the page's scrollability remain available post-completion, and that cash/training-selections are provably unchanged after interacting with the terminal-state screen.

Monthly Close's own idempotency (Category C) was deliberately not re-tested here since `public_demo_monthly_close_ordinary_month_test.dart` already covers it end-to-end ("closing March a second time is a no-op").

All 10 new tests pass. All pre-existing tests in `public_demo_raise_test.dart`, `public_demo_training_state_test.dart`, `public_demo_internal_training_transaction_test.dart`, `public_demo_salary_test.dart`, `public_demo_summer_bonus_payment_test.dart`, and `public_demo_monthly_close_ordinary_month_test.dart` continue to pass unmodified.

## 17. Public Demo tests

`flutter test test/game/public_demo/ test/ui/public_demo/` → **248/248 PASS**.

## 18. Full test

`flutter test` → **780/780 PASS** (baseline 770 + 10 new tests = 780; no other count change, no regressions).

## 19. Format

`dart format --output=none --set-exit-if-changed` on every touched/new file:
- `lib/game/public_demo/public_demo_state.dart`, `lib/game/public_demo/public_demo_internal_training_transaction.dart`, `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`, and both new test files: **clean** (no diff).
- `lib/game/public_demo/public_demo_raise.dart`: the locally available Flutter 3.44.9 formatter reports this file as needing a reformat — but a `git stash` control test proved this same file, **completely unmodified from `origin/main`**, already reports "Changed" under this exact formatter before any edit of mine (the pre-existing code uses an older `switch`-expression indentation style the bundled `dart_style` version wants to rewrite). Repo-wide, this same drift pre-exists in 158 of 283 files, entirely unrelated to this task. I did not add or touch any of the drifted lines beyond what I needed to change, and did not run a whole-file reformat that would have cascaded unrelated changes into this diff. This is a pre-existing formatter/environment condition on `origin/main`, not a regression introduced by this branch.

## 20. Analyze

`flutter analyze` (full repo) → **No issues found!**

## 21. Diff check

`git diff --check` → clean (no whitespace errors).

## 22. Browser smoke

Built `flutter build web --release` successfully with these changes (no compile errors). Served the build locally and loaded `/#public-demo-01` in headless Chromium (Playwright-provided binary): the app boots and renders correctly — confirmed visually via screenshot (April dashboard, engineer cards, training CTA all render as expected).

Full interactive automation through the entire April→March flow inside the real browser was not completed: Flutter Web's default CanvasKit renderer paints everything to a `<canvas>`, so button text is not addressable DOM until Flutter's own accessibility/semantics layer is explicitly activated by a **trusted** user gesture on the semantics placeholder — a synthetic `dispatchEvent` click did not activate it, and building real trusted-gesture automation (or an HTML-renderer build) around that is exactly the kind of E2E-infrastructure work the task said not to take on. The equivalent, more precise proof already exists via `test/ui/public_demo/public_demo_01_completion_lock_ui_test.dart`, which exercises the same April→March path through Flutter's real widget tree and tap-dispatch machinery (the sanctioned way to test Flutter UI without a live browser), so no further browser-side effort was spent past confirming the production build boots cleanly.

## 23. Commit

```
29f4c7d48925d2089f449bdaa7564942da4d9aa5
fix(public-demo): lock mutations after fiscal year completion
```
Normal push (no force, no history rewrite). This result report file itself was intentionally **not** included in the commit, per instructions.

## 24. Remote HEAD

```
origin/feature/public-demo-post12month-1-completion-lock @ 29f4c7d48925d2089f449bdaa7564942da4d9aa5
```
Matches local HEAD — push confirmed.

## 25. Remaining follow-ups

Untouched, exactly as scoped:
1. Ordinary Monthly Close negative cash.
2. Month 7 recruitment dead-end.
3. Month-8 direct-domain recruitment hardening.
4. Save impossible-state validation.
5. Revenue / year-end visualization.
6. Formal assignment lifecycle (contract renewal/termination/next-project sales).
7. FINANCE (financing/cash-short/bankruptcy).

## 26. Final verdict

**PASS** — see the Final Display block in the chat response for the structured summary and the Codex hand-off note.
