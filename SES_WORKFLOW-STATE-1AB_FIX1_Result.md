# WORKFLOW-STATE-1A+B FIX1 — Codex P1 Bypass Closure — Implementation Result

## 1. Base Verification

`git fetch origin --prune` succeeded. Confirmed:

- `git cat-file -t 4313a2b9b040eb15e47001d1d357099ea91b8eb3` → `commit` (target exists).
- `git branch -a --contains 4313a2b9b040eb15e47001d1d357099ea91b8eb3` → present on
  `remotes/origin/claude/workflow-state-1-atomic-cutover-y14m3g` and
  `remotes/origin/claude/workflow-state-1ab-cutover-8aajsm`.
- `git status --short` was clean before any implementation work.
- The session's designated branch (`claude/workflow-state-1ab-fix1-1ilyt3`) was
  pointed at `f4ca78f` ("Phase 0A/0B: SES domain models and random
  generators"), a pure ancestor of the target commit (`git log
  f4ca78f..4313a2b | wc -l` → 280 commits behind, zero unique commits on the
  branch). Fast-forwarded (`git merge --ff-only 4313a2b...`) — no destructive
  reset, no work lost, no untracked files touched.

## 2. Scope

Implemented only the four Codex P1 findings plus their required negative
tests. No FINANCE-FAILURE, no HOME-UI-1, no UI redesign, no balance/
probability changes, no new save system.

## 3. P1-1 — BindingOffer Authority

**Finding:** offer acceptance had no applicant-stage guard; join only
checked BindingOffer existence, not identity/validity/freshness; a caller
could fabricate join eligibility via `copyWith(bindingOffer: ...)`.

**Fix** (`public_demo_binding_offer.dart`, `public_demo_join.dart`,
`public_demo_recruitment.dart`):

- **Stage guard (B):** `PublicDemoOfferAcceptance.accept` now rejects
  (`PublicDemoOfferAcceptanceStatus.invalidStage`) any applicant not at
  `PublicDemoApplicantStage.interviewed`, checked after the existing
  idempotency guard.
- **Identity guard (C/D/F):** `PublicDemoJoinTransaction.join` now requires
  `applicant.bindingOffer!.applicantId == applicant.id`
  (`PublicDemoJoinStatus.wrongApplicant` otherwise) — closes the
  `applicantB.copyWith(bindingOffer: offerMintedForApplicantA)` reuse
  bypass. The same check is duplicated in `PublicDemoApplicant.join()`
  itself (defense in depth, matching the codebase's existing
  model+transaction guard convention).
- **Fiscal validity (C/E):** `PublicDemoJoinTransaction.join` now takes a
  required `currentFiscalCloseId` and rejects
  (`PublicDemoJoinStatus.staleFiscalClose`) when it doesn't match
  `bindingOffer.fiscalCloseId`. The widget threads
  `PublicDemoFiscalCloseId.forMonth(s.month)` through at the same call site
  the offer itself was minted at, so real gameplay is unaffected (offer and
  join both happen within the same month-5 close in Public Demo 0.1).
- **Authoritative salary (C/F):** `PublicDemoApplicant.join()` now
  overwrites `acceptedMonthlySalary` from `bindingOffer.acceptedMonthlySalary`
  at join time, instead of trusting the applicant's separately mutable
  `acceptedMonthlySalary` field. A caller who tampers with that field via
  `copyWith` before joining no longer gets that value onto payroll — proven
  by a new negative test.
- **Fabrication bypass (F):** closed at the join boundary via the identity
  guard above. `PublicDemoBindingOffer`'s constructor remains private to its
  file (unchanged from base) — a caller still cannot construct one from
  scratch, only reuse an existing genuine one across applicants, which the
  identity guard now rejects.

## 4. P1-2 — Recruitment Atomicity

**Finding:** `PublicDemoRecruitmentTransaction.execute` remained public,
letting any caller commit `result.state` (cash) while discarding
`result.generatedApplicants` — a structural cash-only bypass around the
atomic wrapper.

**Fix:** merged the pure calculation into
`public_demo_recruitment_workflow_transaction.dart` and renamed the class
to `_PublicDemoRecruitmentTransaction` — private to that file via Dart's
per-file library privacy. `PublicDemoRecruitmentWorkflowTransaction`
(unchanged public contract, still atomic) is now the only way, in
production or tests, to reach that calculation at all. Deleted
`public_demo_recruitment_transaction.dart` entirely; result/status types
(`PublicDemoRecruitmentTransactionResult`, `PublicDemoRecruitmentTransactionStatus`)
stayed public since the widget's message-switch and the wrapper's own
`.transactionResult` still need them.

Every test that used to construct `PublicDemoRecruitmentTransaction()`
directly (determinism, pool selection, month-range dead-end guard, JSON
compatibility, applicant-experience preservation) now goes through
`PublicDemoRecruitmentWorkflowTransaction`, asserting the same numbers via
`result.transactionResult`/`result.state`/`result.workflow` — same coverage,
reached only through the sanctioned entry.

## 5. P1-3 — Assignment Authority

**Finding:** the widget (`may()`) directly constructed `PublicDemoAssignment`
instances and called `workflow.withAssignments(...)` to replace the roster
wholesale — the widget held assignment authority, and `withAssignments` was
a public arbitrary-roster-replacement API.

**Fix** (`public_demo_workflow_state.dart`,
`public_demo_01_placeholder_screen.dart`):

- `withAssignments` renamed to `_withAssignments`, private to
  `public_demo_workflow_state.dart`.
- New domain method `PublicDemoWorkflowState.assignOrderedForMay()` moves
  the exact roster-computation logic (ordered engineers → their existing/
  fallback assignment, `juneOrdered` applicants → a new assignment) from the
  widget into the domain, reading only this workflow's own authoritative
  `engineers`/`applicants` stage facts. It replaces the roster wholesale
  each call (never appends), so a duplicate call structurally cannot
  duplicate an assignment.
- The widget's `may()` now calls `nextWorkflow.withJoinedEngineers(joinedNow).assignOrderedForMay()`
  and assigns the result straight to `workflow` — it constructs no
  `PublicDemoAssignment` and calls no roster-replacement method itself.

Verified the domain method is computed from the post-join workflow (not the
pre-join one the widget previously used) produces identical results, since
neither `joinAndKeepOnly` nor `withJoinedEngineers` mutate the `stage`
fields `assignOrderedForMay` filters on — confirmed by the unmodified
`public_demo_01_assignment_carryforward_test.dart` end-to-end widget test
still passing.

## 6. P1-4 — joinedApplicantIds Dual Authority

**Finding:** `PublicDemoState.advanceToJune(joinedApplicantIds: ...)` took a
caller-supplied `List<String>`, independent of the workflow's own join
state — a caller could pass ids with no actually-joined applicant behind
them.

**Fix** (`public_demo_state.dart`, `public_demo_monthly_close.dart`,
`public_demo_01_placeholder_screen.dart`): `advanceToJune`'s parameter is
now `Iterable<PublicDemoApplicant> joinedApplicants` — the authoritative
applicant records themselves. `joinedApplicantIds` is derived internally via
`.where((a) => a.hasJoined).map((a) => a.id)`; an id with no genuinely-joined
applicant behind it is silently dropped rather than trusted. `closeMay`
forwards the same shape. The widget passes `joinedNow` — the exact
`nextWorkflow.applicants.where((a) => a.hasJoined)` list already computed
earlier in `may()` — closing the caller-authority gap entirely. The
`PublicDemoState.joinedApplicantIds` field itself remains as the documented
compatibility projection (unchanged; still `List<String>` for existing
finance/monthly-close readers), now provably one-directional: workflow →
derived projection, never the reverse.

## 7. Snapshot (P2)

`PublicDemoWorkflowSnapshot` (from the base implementation) remains
immutability-tested and unchanged. **SNAPSHOT LIVE PATH: DEFERRED TO
FINANCE-FAILURE.** Wiring it into `PublicDemoMonthlyClose` now would add a
capture call with no real consumer — FINANCE-FAILURE's own close-command
design should decide what shape of snapshot it actually needs (which
`PublicDemoState` field(s) would carry it, at which close boundary) rather
than this fix guessing that shape without a consumer to validate it against.
This mirrors the base implementation's own §33 follow-up note and the task
brief's explicit "wenn snapshot 接続できるなら…そうでなければ待つ方が正しい" guidance.

## 8. Negative Tests Added

- **BindingOffer:** invalid-stage rejection (P1-1B).
- **Join:** wrong-applicant BindingOffer reuse rejection (P1-1D/F), stale
  fiscal-close rejection (P1-1E), fabricated-salary override proof (P1-1F).
  Existing no-BindingOffer / duplicate-join / no-salary-parameter tests
  retained and updated for the new `currentFiscalCloseId` parameter.
- **Recruitment:** legacy cash-only class is no longer importable/public —
  every prior direct-calculation test now runs exclusively through
  `PublicDemoRecruitmentWorkflowTransaction`, so passing coverage itself is
  the proof the bypass is unavailable. Insufficient-cash / generation-failure
  atomic no-op tests retained.
- **Assignment:** new `assignOrderedForMay` group — valid path, an
  unordered/waiting engineer is excluded, repeated calls never duplicate,
  and a compile-time note that `withAssignments` is no longer reachable
  outside the domain file.
- **Projection:** new group proving an id with no genuinely-joined applicant
  never appears, the May/June path derives ids from the applicant records
  passed in, and multiple applicants can't make the projection diverge from
  actual join state.
- **Regression:** all pre-existing Revenue 30-day AR, March pending Revenue,
  Growth, recruitment-economics, and payroll/bonus tests pass unmodified
  (see §12 below).

## 9. Self-Audit (Section 10)

Grepped production code (`lib/`) for every listed pattern; classified every
remaining occurrence:

| Pattern | Location | Classification |
|---|---|---|
| `bindingOffer:` (copyWith param) | `public_demo_recruitment.dart:114` | AUTHORITATIVE — the model's own generic field-setter infrastructure; every actual join/accept path gates on it, per §3. |
| `bindingOffer:` (all others) | `public_demo_binding_offer.dart` (accept/result) | AUTHORITATIVE — sole minting entry point, unchanged in kind from base. |
| `copyWith(bindingOffer` | doc comments only (recruitment.dart, join.dart) + the one real call inside `PublicDemoOfferAcceptance.accept` | AUTHORITATIVE / no live bypass call site remains. |
| `withApplicant(` | `public_demo_01_placeholder_screen.dart` (`raise()`) | AUTHORITATIVE — wraps `PublicDemoRaiseTransaction().execute(...).applicant`, unrelated to the P1 findings (raise flow untouched). |
| `withApplicant(` internal uses | `public_demo_workflow_state.dart` | AUTHORITATIVE — generic id-keyed setter used by `withApplicantStage`/`acceptOffer`. |
| `withAssignments(` | `public_demo_workflow_state.dart` (`_withAssignments`) | CLOSED — private, single internal caller (`assignOrderedForMay`). No production caller outside this file can reach it (compile error otherwise). |
| `PublicDemoAssignment(` | `public_demo_assignment.dart` (model/factory/initial pool) + `public_demo_workflow_state.dart:247` (`assignOrderedForMay`) | AUTHORITATIVE — no widget-level construction remains (was the P1-3 bypass; now closed). |
| `joinedApplicantIds:` | `public_demo_state.dart` only (constructor/copyWith/toJson/fromJson) | DERIVED — internal storage of the compatibility projection; the caller-facing API (`advanceToJune`/`closeMay`) no longer accepts a raw id list. |
| `PublicDemoRecruitmentTransaction.execute` | none remain public | CLOSED — class is now `_PublicDemoRecruitmentTransaction`, private to `public_demo_recruitment_workflow_transaction.dart`. |
| `advanceToJune(` | `public_demo_monthly_close.dart` (`closeMay`) + its own definition | AUTHORITATIVE/CLOSED — sole caller forwards the derived-applicants shape; no raw-id-list route exists. |

**No remaining production BYPASS for any of the four P1 findings.**

## 10. RECOMMENDED AI

Claude Code

## 11. Report Fields

```
BASE:              2a9aaca48e13a88aea47649f295eca9f131b997a
FIX1 BASE:         4313a2b9b040eb15e47001d1d357099ea91b8eb3
BRANCH:            claude/workflow-state-1ab-fix1-1ilyt3
HEAD:              (fast-forwarded to FIX1 BASE prior to implementation)
REMOTE HEAD:       see §13 below (populated after push)
DIFF:              22 files changed, 994 insertions(+), 570 deletions(-)
                   (2 new/legacy files deleted, all within
                   lib/game/public_demo, lib/ui/public_demo,
                   test/game/public_demo)

P1-1 BINDING OFFER:
  STAGE GUARD:       CLOSED — accept() requires stage == interviewed
  IDENTITY GUARD:    CLOSED — join() requires bindingOffer.applicantId == applicant.id
  FISCAL VALIDITY:   CLOSED — join() requires currentFiscalCloseId == bindingOffer.fiscalCloseId
  FABRICATION BYPASS: CLOSED — copyWith(bindingOffer:) reuse rejected at join by identity guard

P1-2 RECRUITMENT ATOMICITY:
  LEGACY API:        CLOSED — class made file-private, old file deleted
  CASH-ONLY BYPASS:  CLOSED — no public entry point can reach the calculation except the atomic wrapper

P1-3 ASSIGNMENT AUTHORITY:
  WIDGET ASSIGNMENT CREATION: CLOSED — widget constructs no PublicDemoAssignment
  WITHASSIGNMENTS BYPASS:     CLOSED — private, single authorized internal caller
  ASSIGNMENT AUTHORITY:       SINGLE (PublicDemoWorkflowState.assignOrderedForMay)

P1-4 JOINED PROJECTION:
  CALLER IDS:        CLOSED — advanceToJune/closeMay no longer accept a raw id list
  DERIVATION:        advanceToJune derives ids from applicant.hasJoined internally
  DUAL SSOT:         CLOSED — one-directional workflow -> derived projection

SNAPSHOT:
  SNAPSHOT LIVE PATH: DEFERRED TO FINANCE-FAILURE

REVENUE:
  30-DAY AR:          PASS (unmodified tests)
  MARCH PENDING REVENUE: PASS (unmodified tests)
  GROWTH:             PASS (unmodified tests)

NEGATIVE TESTS:      ADDED (see §8)
FOCUSED TESTS:       285 passed, 0 failed (test/game/public_demo)
PUBLIC DEMO TESTS:   320 passed, 0 failed (test/game/public_demo + test/ui/public_demo)
FULL TEST:           860 passed, 0 failed, 0 skipped (flutter test)
ANALYZE:             No issues found (flutter analyze, full repo)
BUILD:               flutter build web --release succeeded (✓ Built build/web)
DIFF CHECK:          clean (git diff --check)

P0: 0
P1: 0 (all four closed)
P2: 0 open (snapshot live path explicitly deferred, not an open finding)
P3: 0

CHANGED FILES:       22 (see §9/diff stat)
COMMIT:              see §13 below
REMOTE HEAD:         see §13 below
```

## 12. Regression Confirmation

`test/game/public_demo/public_demo_revenue_payment_test.dart`,
`public_demo_revenue_state_test.dart`,
`public_demo_monthly_close_revenue_test.dart` (30-day AR / March pending
Revenue), `public_demo_growth_engine_test.dart`,
`public_demo_monthly_growth_test.dart` (Growth),
`public_demo_recruitment_workflow_transaction_test.dart` (recruitment
economics, restructured but same assertions), and
`public_demo_summer_bonus_payment_test.dart`/`public_demo_salary_test.dart`
(payroll/bonus) all pass unmodified in behavior (only the last two's fixture
`stage:` was bumped to `interviewed`, per §3's stage-guard requirement).

## 13. Commit / Push

Committed as FIX1 on `claude/workflow-state-1ab-fix1-1ilyt3` (branch already
fast-forwarded to the FIX1 base `4313a2b`, per §1). Pushed to
`origin/claude/workflow-state-1ab-fix1-1ilyt3`. No PR created, no merge
performed.

## 14. Verdict

**FIX1 IMPLEMENTED / READY FOR INDEPENDENT REREVIEW**

## 15. Next

Codex independent FIX1 rereview.
