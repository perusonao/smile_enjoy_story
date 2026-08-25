# WORKFLOW-STATE-1A+B FIX4 — Public Domain Authority Boundary Closure — Result Report

RECOMMENDED AI: Claude (Sonnet 5, Claude Code)

BASE: `2a9aaca` (`Merge pull request #63 from perusonao/fix/e2e-recruitment-loop-navigation`, origin/main at session start)

FIX3: implementation `9de2e16` / report `b090650` (`claude/workflow-state-fix3-authority-a6ebqd`) — already merged into this branch's history (FIX4 builds directly on top of it, no redesign).

BRANCH: `claude/workflow-state-fix4-domain-boundary`

IMPLEMENTATION COMMIT: `34df0bc` (`fix(public-demo): close WORKFLOW-STATE-1A+B Public Domain authority bypasses (FIX4)`)

REPORT COMMIT: `bd35178` (`docs: add WORKFLOW-STATE-1AB FIX4 result report`)

REMOTE HEAD: `2630031` (`origin/claude/workflow-state-fix4-domain-boundary`, confirmed via `git ls-remote`)

DIFF: 10 files changed, 705 insertions(+), 616 deletions(-) — 4 `lib/` files (`public_demo_aggregate.dart`, `public_demo_state.dart`, `public_demo_workflow_state.dart`, `public_demo_01_placeholder_screen.dart`), 6 `test/` files. No files outside `lib/game/public_demo`, `lib/ui/public_demo`, and `test/game/public_demo` were touched.

## Authority boundary status

AUTHORITATIVE ROOT: SINGLE — `PublicDemoAggregate` (unchanged from FIX3: one `state` + one `workflow` field, one `_copyWith`).

FINANCE-ONLY COMMIT: CLOSED — `PublicDemoAggregate.withState` removed entirely (see WITHSTATE below); no method on the class accepts a caller-supplied whole `PublicDemoState` and commits it alone. Proven by adversarial test A.

WORKFLOW-ONLY COMMIT: CLOSED — `PublicDemoAggregate.restore` removed entirely (see AGGREGATE RESTORE below); no method accepts a caller-supplied whole `PublicDemoWorkflowState` and commits it alone. Proven by adversarial test B.

WITHSTATE: REMOVED. `PublicDemoAggregate.withState(PublicDemoState)` (FIX3's raw finance-replacement API) no longer exists anywhere in `lib/`. The one legitimate caller (the UI's internal-training purchase flow) was replaced with a new named command, `PublicDemoAggregate.selectInternalTraining(String engineerId)`, which computes eligibility from the aggregate's own `state`/`workflow` internally and commits atomically — the caller supplies only an id, never a `PublicDemoState` value.

AGGREGATE RESTORE: REMOVED. `PublicDemoAggregate.restore(state:, workflow:)` no longer exists. Grep across `lib/` confirms zero occurrences of `.restore(` or a `restore` factory on `PublicDemoAggregate`; the only remaining text is doc-comment prose describing why it was removed.

WORKFLOW RESTORE: REMOVED. `PublicDemoWorkflowState.restore(...)` no longer exists. The public wholesale `copyWith(applicants:, engineers:)` this file used to expose alongside it is also gone — only a private `_copyWith(applicants?, engineers?, assignments?)` remains, reachable solely by the named, field-specific methods in the same file (`withApplicant`, `withApplicantStage`, `withGeneratedApplicants`, `joinAndKeepOnly`, `withEngineer`, `withEngineerStage`, `withJoinedEngineers`, `withAssignmentUpdate`, `assignOrderedForMay`). The safe production factory `PublicDemoWorkflowState({applicants, engineers})` (no `assignments` parameter, from FIX3) is unchanged and remains the only public wholesale constructor.

ASSIGNMENT RESTORE: STILL CLOSED (unchanged from FIX1/FIX3, re-verified this pass). No public factory or `copyWith` accepts an `assignments:` list. `_withAssignments` (wholesale roster replacement) is private to `public_demo_workflow_state.dart` and is called only by `assignOrderedForMay`, which computes the roster itself from the workflow's own authoritative engineer/applicant stage facts. `withAssignmentUpdate` takes three named value parameters (`nextOrderStatus`, `replacementStage`, `fieldEvaluation`) — not a closure — so a caller cannot substitute a fabricated `PublicDemoAssignment` for a real one on the roster; every other field (identity + economic fields) is untouchable through it. `PublicDemoAssignment` itself remains a freely constructible public value object (by design — see below), but nothing in `PublicDemoWorkflowState`'s public surface accepts a caller-constructed one as authoritative. Proven by adversarial test C.

MONTHLY CLOSE ENTRY: SINGLE COMMAND — `PublicDemoAggregate.closeMay({required int week, required int monthlyExpenses})`. No `state`/`workflow`/`joinedApplicants`/`joinedApplicantIds` parameter exists on it; every one of those values is derived internally from `this.state`/`this.workflow` inside the method body (`workflow.applicants.where(accepted)`, `workflow.joinAndKeepOnly(applicantIds: joinIds, ...)`, `PublicDemoFiscalCloseId.forMonth(state.month)`).

RAW CLOSE BYPASS: CLOSED. `PublicDemoMonthlyClose.closeMay(state:, workflow:, ...)` remains public (INTERNAL HELPER tier — see rationale below), but there is no `PublicDemoAggregate` method that forwards a caller-supplied `state`/`workflow` pair into it, or that accepts its raw `PublicDemoState` result as a whole-root commit. `PublicDemoAggregate.closeMay` always calls it with `state`/`workflow` read from `this`.

ADVANCE TO JUNE BYPASS: CLOSED. `PublicDemoState.advanceToJune(...)` remains public (same INTERNAL HELPER tier), but `PublicDemoState.copyWith` — the one production entry point a caller could otherwise use to inject its `joinedApplicantIds` output as if authoritative — was split: the public `copyWith` deliberately has **no** `joinedApplicantIds` parameter; only a private `_copyWith` (used solely by `advanceToJune` itself, same file) can set it.

JOINED DERIVATION: `joinedApplicantIds`/the May-close joined set is derived entirely from `workflow.applicants` inside `PublicDemoAggregate.closeMay` (via the `accepted(...)` stage predicate and `workflow.joinAndKeepOnly`), never taken from a caller-supplied list. Proven by adversarial test G (arbitrary `joinedApplicantIds` cannot be committed — the public `copyWith` has no such parameter at all) and test D/G (two genuinely-joined applicants both derive into the projection without any caller selection).

JOINED OMISSION: CLOSED. There is no API surface for a caller to drop a genuinely-accepted applicant from May's join set — `closeMay` computes `joinIds` from every applicant whose `stage` is in the accepted set, unconditionally. Proven by adversarial test E.

JOINED SUBSET: CLOSED. Same mechanism — `joinIds` is the full accepted set, not a caller-chosen subset. When two applicants (A and B) are both genuinely accepted, both are included; test D/G asserts both end up joined, in the workflow, and reflected in `state.joinedApplicantIds` after `closeMay`.

STALE INPUT: CLOSED. `closeMay` never accepts a workflow parameter at all — it always reads `this.workflow` (the aggregate's own current, live value) at call time, so a caller cannot substitute a stale/earlier workflow snapshot. Proven by adversarial test F: an applicant recruited and hired strictly after the aggregate reached May still appears in `closed.state.joinedApplicantIds` after `closeMay`, which could only happen if `closeMay` used the live post-recruitment workflow, not a value captured earlier.

PAYROLL AUTHORITY: unchanged from FIX2/FIX3 — payroll eligibility is gated on `PublicDemoApplicant.hasJoined` (`joinRecord?.applicantId == id`, an unforgeable capability minted only by `PublicDemoApplicant.join`), never on the separately, publicly settable `employeeMorale`/`employeeCompanyTrust` fields.

## FIX3 invariants re-verified green (not touched by FIX4)

INTERVIEW: `PublicDemoAggregate.completeInterview` — sales-slot consumption and `PublicDemoInterviewRecord` minting remain atomic (one `_copyWith(state:, workflow:)` call); the unforgeable `PublicDemoSalesSlotConsumptionProof` parameter requirement on `PublicDemoApplicant.completeInterview` is unchanged.

OFFER: `PublicDemoOfferAcceptance.accept` still gates on `hasBeenInterviewed` (interview-record identity), never the `stage` field alone.

BINDING OFFER: `PublicDemoBindingOffer` minting (applicant-identity binding + fiscal-close binding) unchanged.

JOIN: `PublicDemoApplicant.join`/`PublicDemoJoinTransaction` still require a matching `bindingOffer.applicantId`, reject a stale `fiscalCloseId`, and reject a duplicate join (`hasJoined` guard) — unchanged.

SALARY AUTHORITY: `join()` still overwrites `acceptedMonthlySalary` from `offer.acceptedMonthlySalary` at join time, not from any pre-join `copyWith`-set value.

All of the above are exercised by the pre-existing FIX2/FIX3 test files (`public_demo_interview_test.dart`, `public_demo_binding_offer_test.dart`, `public_demo_join_test.dart`, and the P1-1 group in `public_demo_aggregate_test.dart`), all still passing.

## recruit() — command + whole-API atomicity

RECRUITMENT INPUT: `recruit(PublicDemoRecruitmentMedium medium, {candidateGenerator})` — no raw state/workflow parameter.

RECRUITMENT OUTPUT: `PublicDemoRecruitmentTransactionResult` carries `aggregate` (null on failure) plus display facts (`medium`, `chargedAmount`, `generatedApplicants`, `status`); the caller cannot commit anything from a failed result.

SUCCESS ATOMICITY: cash charge (`state`) and generated applicants (`workflow`) are written together in one `_copyWith(state:, workflow:)` call — test J.

FAILURE ATOMICITY: on any failure path (insufficient cash, already used this month, generation failure), `aggregate` is null and the original aggregate reference is untouched — cash and the applicant list are structurally unreachable from the result, not merely numerically unchanged — tests I and the dedicated "commits nothing: cash and applicants are structurally unreachable" test.

Beyond command-level atomicity, the calculation itself (`PublicDemoRecruitmentCalculation`, promoted from private to a public INTERNAL HELPER — see rationale below) operates only on raw `PublicDemoState` values and is never accepted back into `PublicDemoAggregate` as a whole-state commit, so there is no way to combine it with a separate workflow-only write to defeat `recruit()`'s atomicity at the whole-API level — this was FIX4's core P1-2-adjacent concern and is closed the same way as the monthly-close bypass.

ASSIGNMENT AUTHORITY: `assignOrderedForMay` remains the sole validated transition that produces an assignment roster; see ASSIGNMENT RESTORE above for why no other path (roster injection, `copyWith(assignments:)`, UI-created assignment, caller-created-assignment-to-root injection) exists. `PublicDemoAssignment` stays a freely constructible public value object, but "constructible" and "authority-committable" are structurally separate: constructing one accomplishes nothing on its own, since no workflow-level API accepts one from outside `assignOrderedForMay`.

## Section 10 — Public Domain bypass audit

Grep performed across all of `lib/` for: `PublicDemoAggregate`, `withState`, `restore`, `copyWith`, `withApplicant`, `withApplicantStage`, `assignments:`, `joinedApplicantIds`, `joinedApplicants`, `advanceToJune`, `closeMay`, `PublicDemoMonthlyClose`, `PublicDemoWorkflowState`, `PublicDemoState`. Every authority-significant occurrence classified:

| Symbol | Classification | Why |
|---|---|---|
| `PublicDemoAggregate.withState` | **REMOVED** | Deleted in FIX4 (was BYPASS in FIX3's own self-audit gap). |
| `PublicDemoAggregate.restore` | **REMOVED** | Deleted in FIX4. |
| `PublicDemoWorkflowState.restore` | **REMOVED** | Deleted in FIX4. |
| `PublicDemoWorkflowState.copyWith(applicants:, engineers:)` (public wholesale) | **REMOVED** | Deleted in FIX4; had zero external callers before removal. |
| `PublicDemoState.copyWith(joinedApplicantIds:)` | **REMOVED from public signature** | Split into private `_copyWith`; public `copyWith` no longer has this parameter. |
| `PublicDemoAggregate._copyWith` | INTERNAL HELPER (private) | Sole state/workflow-pair writer; unreachable outside the file. |
| `PublicDemoWorkflowState._copyWith` / `_withAssignments` | INTERNAL HELPER (private) | Unreachable outside the file. |
| `PublicDemoState._copyWith` | INTERNAL HELPER (private) | Unreachable outside the file. |
| `PublicDemoAggregate.withApplicantStage` / `withEngineerStage` / `withAssignmentUpdate` / `consumeSlotAndSetApplicantStage` / `applyEngineerInterviewResult` / `consumeSlotAndSetReplacementStage` / `applyRaiseDecision` / `acceptOffer` / `selectSummerBonus` / `selectInternalTraining` | AUTHORITATIVE COMMAND | Each is a named, fixed-shape transition on the single root; none accepts a caller-supplied whole `PublicDemoState`/`PublicDemoWorkflowState`. |
| `PublicDemoAggregate.closeApril/closeMay/closeJune/closeJuly/closeOrdinaryMonth` | AUTHORITATIVE COMMAND | Each derives all inputs from `this.state`/`this.workflow`; none takes `state`/`workflow`/`joinedApplicants`/`assignments` as a parameter. |
| `PublicDemoWorkflowState.withApplicant` / `withEngineer` (closure-taking) | INTERNAL HELPER (public, but structurally inert) | Reachable via `aggregate.workflow` (a read getter), but (a) both call sites inside `PublicDemoAggregate` use fixed, hardcoded closures, never a caller-supplied one; (b) `PublicDemoApplicant`/`PublicDemoEngineerSales`'s own authority fields (`interviewRecord`, `joinRecord`, `bindingOffer`) cannot be forged through `copyWith` — private constructors confine minting to their own files; (c) there is no aggregate API that accepts an externally-produced `PublicDemoWorkflowState` back as authoritative. A caller can build a detached, tampered `PublicDemoWorkflowState` value from `aggregate.workflow`, but it commits nothing. |
| `PublicDemoWorkflowState.withApplicantStage` | INTERNAL HELPER | Asserts against setting `stage: interviewed` (that transition requires `completeInterview`'s proof); `stage` alone is documented, and verified by test, to be non-authoritative for offer/join eligibility. |
| `PublicDemoApplicant.copyWith` | READ/DERIVED-SAFE | Can set `stage` and other cosmetic/relationship fields, and can pass through (not fabricate) already-obtained genuine `bindingOffer`/`interviewRecord`/`joinRecord` objects; identity checks in `join()`/`hasBeenInterviewed`/`hasJoined` reject a record whose own `applicantId` doesn't match the applicant it's attached to, closing the "reassign a genuine capability to a different applicant" path (unchanged from FIX1/FIX2). |
| `PublicDemoAssignment` constructor/`copyWith` | READ/DERIVED-SAFE (constructible, not committable) | Freely constructible value object; no `PublicDemoWorkflowState` API accepts a caller-built one as authoritative (see ASSIGNMENT RESTORE). |
| `PublicDemoMonthlyClose.closeApril/closeMay/closeJune/closeJuly/closeOrdinaryMonth` | INTERNAL HELPER | Pure `PublicDemoState`-in/`PublicDemoState`-out static functions; only `PublicDemoAggregate`'s own month-close methods call them, always with `state`/`workflow` read from `this`. |
| `PublicDemoState.advanceToJune` | INTERNAL HELPER | Pure, takes/returns only `PublicDemoState`; only called from `PublicDemoMonthlyClose.closeMay`, same file. |
| `PublicDemoRecruitmentCalculation` (renamed from private) | INTERNAL HELPER | Pure `PublicDemoState`-in/out; only `PublicDemoAggregate.recruit` feeds its result back in, via `_copyWith` after checking `isSuccess`. |
| `PublicDemoState` constructors/`copyWith`/`advanceToJune` etc. | READ/DERIVED-SAFE | `PublicDemoState` remains legitimately freely constructible on its own (it always was, even pre-FIX3) — the boundary that matters is that `PublicDemoAggregate` never accepts one back as a whole-root commit. |
| `joinedApplicants`/`joinedApplicantIds` getters on `PublicDemoWorkflowState`/`PublicDemoState` | DERIVED | Read-only projections, not settable inputs (aside from the removed `PublicDemoState._copyWith` internal path). |

PUBLIC DOMAIN BYPASS: **0**

BYPASS COUNT: **0** (P0: 0, P1: 0)

ADVERSARIAL TESTS: A–J all present and passing in `test/game/public_demo/public_demo_aggregate_test.dart` (labels `A:`, `B:`, `C:`, `D/G:`, `E:`, `F:`, `I:`, `J:`, plus an unlabeled unforgeable-lambda test covering the same ground as G from a second angle); H covered by the pre-existing, still-green FIX2/FIX3 regression files (`public_demo_interview_test.dart`, `public_demo_binding_offer_test.dart`, `public_demo_join_test.dart`) and the P1-1 group in `public_demo_aggregate_test.dart`.

## Regression invariants (unchanged, re-verified via full suite)

REVENUE: unchanged (`public_demo_monthly_close_revenue_test.dart` green).
30-DAY AR: unchanged (same file, green).
MARCH: unchanged (March pending-Revenue behavior untouched — no March-specific code was modified).
GROWTH: unchanged (`public_demo_growth_engine.dart` not modified; growth tests green).
SALARY/BONUS: unchanged economics (`public_demo_salary_offer.dart`, `public_demo_summer_bonus_payment.dart` not modified; salary/bonus tests green).

## Verification

ANALYZE: `flutter analyze` — **No issues found!**

FOCUSED DOMAIN: `flutter test test/game/public_demo` — **325/325 passed**.

FOCUSED UI: `flutter test test/ui/public_demo` — **35/35 passed**.

FULL TEST: `flutter test` — **892/892 passed**, 0 failures.

BUILD: `flutter build web --release` — **succeeded** (`✓ Built build/web`).

DIFF CHECK: `git diff --check` — clean, no output, exit 0.

FORMAT: `dart format --output=none --set-exit-if-changed` on the 10 files this change touches — **0 changed** (already correctly formatted). Note: running the same check across the whole repo reports 154 pre-existing unformatted files unrelated to this change; per the section-13 scope restriction (no unrelated refactor), these were left untouched.

P0: 0
P1: 0
P2: 0 (no new P2s identified; FIX3's own P2 note about unrelated pre-existing diff noise does not apply here — this diff is scoped to the same 4 `lib/` files FIX3 already touched, plus tests)
P3: 0

CHANGED FILES:
- `lib/game/public_demo/public_demo_aggregate.dart`
- `lib/game/public_demo/public_demo_state.dart`
- `lib/game/public_demo/public_demo_workflow_state.dart`
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
- `test/game/public_demo/public_demo_aggregate_test.dart`
- `test/game/public_demo/public_demo_monthly_cash_flow_test.dart`
- `test/game/public_demo/public_demo_monthly_close_test.dart`
- `test/game/public_demo/public_demo_recruitment_workflow_transaction_test.dart`
- `test/game/public_demo/public_demo_workflow_snapshot_test.dart`
- `test/game/public_demo/public_demo_workflow_state_test.dart`

VERDICT: WORKFLOW-STATE-1A+B FIX4 IMPLEMENTED / READY FOR INDEPENDENT REREVIEW

NEXT: Codex independent FIX4 review
