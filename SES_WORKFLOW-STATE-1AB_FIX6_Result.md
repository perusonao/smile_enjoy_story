# WORKFLOW-STATE-1A+B FIX6 — Final Public Workflow Mutation Boundary Closure — Result

## RECOMMENDED AI
Codex (independent focused review, as requested by the task — this report is the implementation side).

## BASE
FIX4: `34df0bcb05c409ef1fe49d06d07f8a55be2b5638`

## FIX5
- IMPLEMENTATION: `99b6ccf2bdd7d5ac13576c9b5c2aabbf1773cc05` — confirmed as an ancestor of the branch worked on.
- REPORT: `944fe5d782cb5c63d1a2f5b05cac3adbbf317787`
- Independent review's reported remote head `af2f014e7d123d68abdfe1f382fd353219cd38ec` — confirmed exact match: `origin/claude/workflow-state-fix5-assignment-authority-z4vf48` pointed at this SHA at fetch time, and it is the same SHA `git log` shows as this session's own last FIX5 commit (`docs: record confirmed FIX5 remote head in result report`). No drift between remote/report/implementation ancestry.

## BRANCH
`claude/workflow-state-fix6-final-boundary`, created directly on top of the verified FIX5 head (`af2f014e7d123d68abdfe1f382fd353219cd38ec`) via `git checkout -b`.

## IMPLEMENTATION COMMIT
`5f3cec274b85e2f000d7a69dacb2b7c45974da61` (`fix(public-demo): close WORKFLOW-STATE-1A+B generic workflow mutation authority (FIX6)`)

## REPORT COMMIT
`ff8e5ae12c2d47e748b65b996880c922c14e5e9b` (`docs: add WORKFLOW-STATE-1AB FIX6 result report`)

## REMOTE HEAD
`ff8e5ae12c2d47e748b65b996880c922c14e5e9b` (`origin/claude/workflow-state-fix6-final-boundary`, confirmed pushed and matching local HEAD)

## DIFF
6 files changed: 3 production files, 2 test files modified, 1 new test-support helper file. No UI file changed (`public_demo_01_placeholder_screen.dart` untouched — the widget already called only named domain commands after FIX5; none of those command signatures changed).

## WITHENGINEER
CLOSED. `PublicDemoWorkflowState.withEngineer` is now `_withEngineer` (private). Zero production call sites outside `public_demo_workflow_state.dart` remain — `public_demo_aggregate.dart` no longer references it at all (verified: `grep -rn "\.withEngineer(" lib/` returns nothing outside the private definition and historical doc comments).

## WITHAPPLICANT
CLOSED. `PublicDemoWorkflowState.withApplicant` is now `_withApplicant` (private), for the identical reason. Same verification: zero live call sites outside `public_demo_workflow_state.dart`.

## GENERIC CALLBACK MUTATOR
CLOSED, and not reintroduced under any name. No `mutateEngineer`/`updateEngineer`/`transformEngineer`-shaped method exists anywhere. Every former `withEngineer`/`withApplicant` call site was migrated to a named method on `PublicDemoWorkflowState` (`recordInterviewCompletion`, `recordEngineerInterviewResult`, `recordPreEntryPartnerInterviewResult`, `recordPreEntryClientInterviewResult`, `applyRaiseDecision`) — each takes only identifiers, enums, or unforgeable proof values, never a closure or a whole caller-supplied entity, and each internally re-checks its own precondition (current stage) before mutating.

## WORKFLOW CONSTRUCTOR
Unchanged (still public): `PublicDemoWorkflowState({applicants, engineers})`. Audited and intentionally left open — see rationale below (ENGINEER CONSTRUCTOR INJECTION). It is never called anywhere in production `lib/` except by `PublicDemoWorkflowState.initial()` itself (verified by grep); the wider test suite relies on it extensively as a fixture constructor (per FIX3/FIX4's own documented design — "test fixture construction" is a legitimately separate category from production authority).

## ENGINEER CONSTRUCTOR INJECTION
CLOSED at the only place it can matter (assignment eligibility), without restricting the constructor itself. A caller can still construct `PublicDemoEngineerSales(stage: ordered, lastInterviewScore: 80, ...)` directly and place it into a `PublicDemoWorkflowState` via the public factory — but `assignOrderedForMay` no longer trusts `stage`/`lastInterviewScore` for that engineer: it requires `hasGenuineInterviewRecord`, which checks the new unforgeable `PublicDemoEngineerInterviewRecord` (constructor private to `public_demo_sales.dart`, mintable only by `PublicDemoEngineerSales.recordInterviewOutcome`, which no caller outside that file can invoke with a fabricated `passed`/`score` that didn't come from a real `PublicDemoInterviewEvaluator.evaluate` call inside `PublicDemoWorkflowState.recordEngineerInterviewResult`). Verified in TEST A/TEST I (below): a fabricated engineer never produces an assignment, with or without `withEngineer` in the mix.

## APPLICANT CONSTRUCTOR INJECTION
Already CLOSED (no change needed). `assignOrderedForMay` has required `PublicDemoApplicant.hasJoined` since FIX5 — the unforgeable `PublicDemoJoinRecord`, mintable only by a genuine `PublicDemoJoinTransaction.join`. A directly-constructed `PublicDemoApplicant(stage: juneOrdered, ...)` has `joinRecord == null`, so `hasJoined` is false regardless of `stage`. Verified in TEST I.

## ENGINEER STAGE AUTHORITY
Unchanged from FIX5, reverified: `waiting → skillSheet → selling → introduced → (partner interview) → partnerInterviewPassed/Failed → (client interview) → clientInterviewPassed/Failed → ordered`, each transition precondition-gated, no caller-chosen target stage anywhere. `recordEngineerInterviewResult`'s stage/score derivation now lives in `PublicDemoWorkflowState` (moved out of `PublicDemoAggregate`, which is a thin passthrough that still separately owns the sales-slot-consumption decision, since only it holds `PublicDemoState`).

## ENGINEER INTERVIEW PROVENANCE
NEW, closing the FIX6 P1: `PublicDemoEngineerInterviewRecord` (`public_demo_sales.dart`) — constructor private to that file, minted only by `PublicDemoEngineerSales.recordInterviewOutcome` when `type == client && passed == true`, checked by identity (`interviewRecord?.engineerId == id`, mirroring `PublicDemoApplicant.hasBeenInterviewed`/`PublicDemoJoinRecord`'s own reuse-across-identities defense). `lastInterviewScore` remains a plain field (harmless, unread by any eligibility check now) — kept rather than removed, since nothing else depended on removing it and doing so would have been an unrelated-scope field deletion.

## ENGINEER ORDER AUTHORITY
Unchanged: `recordOrder` still requires `clientInterviewPassed` as precondition; `ordered` is reachable only through the full precondition chain.

## ENGINEER ASSIGNMENT ELIGIBILITY
`assignOrderedForMay` now requires `engineer.stage == ordered && engineer.hasGenuineInterviewRecord` (was `stage == ordered && lastInterviewScore != null` under FIX5). This is the exact P1 closure this fix targets.

## APPLICANT STAGE AUTHORITY
Unchanged from FIX5, reverified: `applied → resumeReviewed → interviewed → offerAccepted → preEntrySkillSheet → preEntrySelling → preEntryIntroduced → (partner interview) → preEntryPartnerPassed/Failed → (client interview) → preEntryClientPassed/Failed → juneOrdered`.

## APPLICANT JOIN AUTHORITY
Unchanged: `PublicDemoJoinTransaction.join` remains the sole mint path for `PublicDemoJoinRecord`.

## APPLICANT ASSIGNMENT ELIGIBILITY
Unchanged from FIX5: `applicant.stage == juneOrdered && applicant.hasJoined`.

## ATTACK A
The confirmed review attack — `workflow.withEngineer(id, (e) => e.copyWith(stage: ordered, lastInterviewScore: 80)).assignOrderedForMay()` — CLOSED. `withEngineer` no longer compiles from outside `public_demo_workflow_state.dart` (structural/compile-time closure). The equivalent-effect fabrication reachable through the remaining public surface (constructing the same engineer directly, then `PublicDemoWorkflowState(engineers: [...]).assignOrderedForMay()`) is also verified to produce no assignment (TEST A), because `hasGenuineInterviewRecord` is false.

## ATTACK B
(Applicant stage spoof, FIX4/FIX5) — remains CLOSED. `recordJuneOrder` still requires `preEntryClientPassed`; verified again in TEST B-equivalent coverage carried over unmodified from FIX5's own adversarial group (still passing).

## ATTACK C
(Applicant join-failure defense, FIX5) — remains CLOSED. `assignOrderedForMay`'s `hasJoined` requirement is untouched; FIX5's own TEST C (stale-fiscal-close join failure) is unmodified and still passes.

## ENGINEER HAPPY PATH
GREEN. TEST C (new FIX6 group) and FIX5's own TEST D (unmodified) both confirm a genuine partner+client interview pass through `PublicDemoAggregate.recordEngineerInterviewResult` still produces exactly one assignment, and the resulting engineer's `hasGenuineInterviewRecord` is true.

## APPLICANT HAPPY PATH
GREEN, unmodified — FIX5's own TEST E still passes as-is.

## DUPLICATE PROTECTION
GREEN, unmodified — FIX5's own TEST F (retry `closeMay`, no duplicate assignment) still passes as-is; `assignOrderedForMay` continues to replace the roster wholesale from current facts every call.

## AUTHORITATIVE ROOT
SINGLE (unchanged). No new public method on `PublicDemoAggregate` accepts a caller-supplied `PublicDemoState`/`PublicDemoWorkflowState`.

## FINANCE-ONLY COMMIT
CLOSED (unchanged); reverified in TEST H.

## WORKFLOW-ONLY COMMIT
CLOSED (unchanged); reverified in TEST H (same assertion covers both — `recruit()`'s cash and generated-applicants always move together).

## INTERVIEW AUTHORITY
Unchanged — `PublicDemoAggregate.completeInterview` remains the sole `PublicDemoInterviewRecord` mint path; its own workflow-level step is now `PublicDemoWorkflowState.recordInterviewCompletion` (moved out from directly calling the now-private `_withApplicant`), behavior identical.

## OFFER AUTHORITY
Unchanged — `PublicDemoOfferAcceptance.accept` still requires `hasBeenInterviewed`, never trusts `stage`.

## BINDING OFFER
Unchanged.

## JOIN AUTHORITY
Unchanged.

## SALARY AUTHORITY
Unchanged — still resolved from the authoritative `BindingOffer`.

## RECRUITMENT ATOMICITY
Unchanged; reverified in TEST H.

## CLOSE AUTHORITY
Unchanged.

## PAYROLL AUTHORITY
Unchanged.

## PUBLIC DOMAIN BYPASS
Audited (section 10):
- `withEngineer`/`withApplicant`: private, zero live occurrences outside definition — CLASSIFIED: was BYPASS, now INTERNAL.
- `copyWith` (Engineer/Applicant): remains public (needed cross-file by `public_demo_workflow_state.dart`) — CLASSIFIED: VALIDATED-COMMAND building block, not itself reachable to re-commit to the authoritative root (no caller-suppliable-closure path left to it).
- `PublicDemoWorkflowState(applicants:, engineers:)`: remains public — CLASSIFIED: TEST-ONLY in practice (zero production call sites besides `.initial()`), DERIVED-safe (its output can never reach `PublicDemoAggregate`).
- `PublicDemoEngineerSales(...)` / `PublicDemoApplicant(...)` constructors: remain public — CLASSIFIED: READ-ONLY value construction; authority-significant facts (`interviewRecord`/`joinRecord`/`bindingOffer`) are unforgeable regardless of what a caller passes for `stage`/`lastInterviewScore`.
- `stage:`, `lastInterviewScore`, `ordered`, `juneOrdered`: CLASSIFIED DERIVED/non-authoritative on their own, corroborated by unforgeable records everywhere they gate an assignment.
- `assignOrderedForMay`: CLASSIFIED VALIDATED COMMAND — sole assignment-roster mutator, defense-in-depth checks reconfirmed.
- `restore` / `withState` / `withWorkflow`: zero occurrences anywhere in `lib/` (grep-confirmed) — remain fully removed since FIX4, not reintroduced.

## BYPASS COUNT
0

## REVENUE
Unaffected — no code in this fix touches revenue calculation.

## 30-DAY AR
Unaffected.

## MARCH
Unaffected.

## GROWTH
Unaffected.

## SALARY/BONUS
Unaffected.

## ADVERSARIAL TESTS
New group in `test/game/public_demo/public_demo_aggregate_test.dart`: `WORKFLOW-STATE-1AB FIX6 P1: generic-mutator and constructor-injection adversarial tests`:
- TEST A — the confirmed review attack, reproduced via the equivalent remaining public surface (standalone `PublicDemoWorkflowState` construction, since `withEngineer` no longer compiles) → assignment NOT created. PASS
- TEST I — public `PublicDemoWorkflowState` factory constructor cannot inject an authoritative fabricated roster (fabricated ordered engineer + fabricated juneOrdered applicant, together) → assignment NOT created for either. PASS
- TEST B — engineer sales pipeline still cannot be skipped through the aggregate (`recordOrder` alone, no genuine progression) → assignment NOT created. PASS
- TEST C — genuine engineer happy path → assignment created exactly once, `hasGenuineInterviewRecord` true. PASS
- TEST H — no finance-only/workflow-only bypass reintroduced (`recruit()` still atomic). PASS

FIX5's own adversarial group (TEST A–F, unmodified) continues to cover Applicant Attack B/C, applicant happy path, and duplicate protection — all still passing, satisfying this task's TEST D/E/F/G requirements without duplication.

Also added/updated in `public_demo_workflow_state_test.dart`:
- `reviewResume`/`recordOrder` pipeline-cannot-be-skipped coverage (unmodified from FIX5).
- New/strengthened "stage (and, for engineers, a fabricated lastInterviewScore) alone is not proof" test — an engineer with both `stage: ordered` and `lastInterviewScore: 80` set directly (the exact literal shape of the confirmed attack), but no `interviewRecord`, is rejected by `assignOrderedForMay`.
- `workflowWithGenuineAssignment`/`orderedEngineersWorkflow`/`orderedEngineer` fixtures updated to mint a genuine `PublicDemoEngineerInterviewRecord` via the new `recordTestClientInterviewPass` test helper (`test_support/public_demo_sales_test_helpers.dart`, mirroring `completeTestInterview`'s existing pattern) instead of setting `lastInterviewScore` directly.

## ANALYZE
`flutter analyze` (whole project): **No issues found.**

## FOCUSED DOMAIN
`flutter test test/game/public_demo`: **338 tests, all passed** (5 more than FIX5's 333).

## FOCUSED UI
`flutter test test/ui/public_demo`: **35 tests, all passed**, unchanged — confirms the widget still works end-to-end through the real button flows (no UI file was touched).

## FULL TEST
`flutter test`: **905 tests, all passed** (5 more than FIX5's 900).

## BUILD
`flutter build web --release`: **succeeded** (`✓ Built build/web`).

## DIFF CHECK
`git diff --check`: clean, no whitespace errors.

Environment note: this session's container again had no Flutter/Dart toolchain preinstalled; Flutter 3.35.5 (stable) — already downloaded to the session scratchpad during FIX5 — was reused for all validation above. No `pubspec.lock` drift this time (no `pub get` was re-run). No Windows Developer Mode / symlink issues encountered (Linux container). No timeout or config changes were made.

## P0
0

## P1
0 (the one open P1 from FIX5 review — `withEngineer`/`withApplicant` as public generic mutators, plus the insufficient `lastInterviewScore`-alone corroboration — is closed by this fix)

## P2
0 changed by this fix (out of scope per FIX6's instructions).

## P3
0

## CHANGED FILES
- `lib/game/public_demo/public_demo_workflow_state.dart` — `withEngineer`/`withApplicant` privatized; new named methods (`recordInterviewCompletion`, `recordEngineerInterviewResult`, `recordPreEntryPartnerInterviewResult`, `recordPreEntryClientInterviewResult`, `applyRaiseDecision`); `assignOrderedForMay` engineer check switched to `hasGenuineInterviewRecord`.
- `lib/game/public_demo/public_demo_sales.dart` — new `PublicDemoEngineerInterviewRecord`; `PublicDemoEngineerSales` gains `interviewRecord`/`hasGenuineInterviewRecord`/`recordInterviewOutcome`.
- `lib/game/public_demo/public_demo_aggregate.dart` — `completeInterview`/`recordEngineerInterviewResult`/`recordPreEntryPartnerInterviewResult`/`recordPreEntryClientInterviewResult`/`applyRaiseDecision` now call the new named `PublicDemoWorkflowState` methods instead of `withApplicant`/`withEngineer` directly.
- `test/game/public_demo/public_demo_aggregate_test.dart` — updated two tests that called `workflow.withApplicant` directly (now impossible); added the FIX6 adversarial group (TEST A/I/B/C/H).
- `test/game/public_demo/public_demo_workflow_state_test.dart` — engineer-eligibility fixtures updated to mint genuine interview records; strengthened stage-alone-is-not-proof test.
- `test/game/public_demo/test_support/public_demo_sales_test_helpers.dart` — new, `recordTestClientInterviewPass` helper.

No UI file, no balance numbers, no recruitment game rules, no save system, no unrelated file changed.

## VERDICT
WORKFLOW-STATE-1A+B FIX6 IMPLEMENTED /
READY FOR FINAL INDEPENDENT REREVIEW

## NEXT
Codex final FIX6 focused rereview
