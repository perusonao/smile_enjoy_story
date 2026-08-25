RECOMMENDED AI: Claude Code

ORIGINAL BASE: 2a9aaca48e13a88aea47649f295eca9f131b997a
FIX1: 2547e4225097af5be1d8f4957e18a0bbe058f47a
FIX2: 14d8de13bcc83d985414c8cf56d6c0838c8d570f
FIX3 BASE: 067e37e29cb0c236c5c3a6f8312711fbfdc192f8
BRANCH: claude/workflow-state-fix3-authority-a6ebqd
HEAD: 9de2e166c0766cc53efb25cca1dc065575a848ae
REMOTE HEAD: 9de2e166c0766cc53efb25cca1dc065575a848ae (origin/claude/workflow-state-fix3-authority-a6ebqd, confirmed via git ls-remote)
DIFF: 22 files changed, 1887 insertions(+), 938 deletions(-)

Ancestry verification (required before any implementation work): fetched
origin fresh and resolved `origin/claude/workflow-state-fix2-p1-ctaakf` to
067e37e29cb0c236c5c3a6f8312711fbfdc192f8, exactly as independent review
reported — NOT the stated FIX2 report SHA d186fea52298. Investigated: this
is not ancestry drift/ambiguity. `git log` shows 067e37e is exactly ONE
docs-only commit ("docs: record FIX2 commit SHAs in result report") directly
on top of d186fea ("docs: add WORKFLOW-STATE-1AB FIX2 result report"), which
sits directly on 14d8de1 (FIX2 IMPLEMENTATION). `git merge-base --is-ancestor
14d8de1 067e37e` and `... d186fea 067e37e` both confirm. The stated FIX2
IMPLEMENTATION SHA is unambiguously present in 067e37e's ancestry — no
divergent branch, no rewritten history. The task's designated local branch
(`claude/workflow-state-fix3-authority-a6ebqd`) was seeded at an unrelated
commit from main's own history (`f4ca78f`, "Phase 0A/0B: SES domain models
and random generators" — commit #280 of 280, i.e. near the start of main's
history, already fully contained in main); since nothing unique would be
lost (clean working tree, no remote branch existed yet under this name),
the local branch was re-pointed to 067e37e (the verified current FIX2 tip)
before any implementation work began.

AUTHORITATIVE ROOT: PublicDemoAggregate (lib/game/public_demo/public_demo_aggregate.dart) — new class
FINANCE OWNERSHIP: PublicDemoAggregate.state (PublicDemoState), atomically contained, never independently settable by the widget
WORKFLOW OWNERSHIP: PublicDemoAggregate.workflow (PublicDemoWorkflowState), atomically contained, never independently settable by the widget
ATOMIC ROOT COMMIT: YES — the widget (public_demo_01_placeholder_screen.dart) holds exactly one `PublicDemoAggregate _game` field; `s`/`workflow` are now read-only getters (`PublicDemoState get s => _game.state;` / `PublicDemoWorkflowState get workflow => _game.workflow;`) with no setter anywhere in the file. Every state-changing UI action does `setState(() => _game = _game.someCommand(...))`.

P1-1 INTERVIEW:
INTERVIEW AUTHORITY: PublicDemoAggregate.completeInterview(applicantId) — validates applicant exists, not already interviewed, and a genuine sales slot is available; consumes the slot and mints the interview record atomically, or changes nothing.
MARKINTERVIEWED BYPASS: CLOSED — PublicDemoApplicant.markInterviewed() no longer exists. Replaced by completeInterview(PublicDemoSalesSlotConsumptionProof proof): the proof's constructor is private to public_demo_state.dart, mintable only by PublicDemoState.useSalesSlotForInterview() when it genuinely consumes a slot. No zero-argument mint path remains anywhere.
WITHAPPLICANT BYPASS: CLOSED — withApplicant remains generic (needed for legitimate per-applicant updates), but nothing reachable from outside public_demo_state.dart/public_demo_recruitment.dart can construct a genuine proof, so no lambda passed to withApplicant can mint an interview record. Tested explicitly (public_demo_aggregate_test.dart).
OFFER AUTHORITY: UNCHANGED, retained — PublicDemoOfferAcceptance.accept still gates on applicant.hasBeenInterviewed (the unforgeable record), never the stage field.
BINDING OFFER: UNCHANGED, retained — private constructor confined to public_demo_binding_offer.dart, minted only by PublicDemoOfferAcceptance.accept.
DIRECT JOIN: UNCHANGED, retained — PublicDemoApplicant.join() re-validates offer identity + fiscal-close freshness itself; direct-call bypass already closed by FIX1/FIX2, verified still closed (public_demo_join_test.dart, unmodified assertions).
FISCAL VALIDITY: UNCHANGED, retained — join requires offer.fiscalCloseId == currentFiscalCloseId.
SALARY AUTHORITY: UNCHANGED, retained — join() resolves salary strictly from the BindingOffer, never from the separately-mutable acceptedMonthlySalary field; verified with a new adversarial test (tampered acceptedMonthlySalary is ignored at closeMay's join step).

P1-2 RECRUITMENT:
COMMAND INPUT: PublicDemoAggregate.recruit(medium, {candidateGenerator}) — takes the current aggregate implicitly (`this`), no separate state/workflow parameters.
COMMAND OUTPUT: PublicDemoRecruitmentTransactionResult.aggregate — a single `PublicDemoAggregate?` field (non-null only on success). The old `onCommitted(PublicDemoState, PublicDemoWorkflowState)` two-parameter callback is gone entirely.
FINANCE-ONLY COMMIT: IMPOSSIBLE — there is no field/callback shape that exposes a committed PublicDemoState without the paired PublicDemoWorkflowState; both are read from the same `result.aggregate`.
WORKFLOW-ONLY COMMIT: IMPOSSIBLE — same reasoning, symmetric.
FAILURE ATOMICITY: `result.aggregate == null` on any failure (insufficient cash / already used this month / generation failed); original aggregate provably unchanged (Dart immutability + tests assert `result.aggregate == null`).
SUCCESS ATOMICITY: cash deduction and generated-applicant append always land in the same new aggregate; tested for every PublicDemoRecruitmentMedium value.

P1-3 ASSIGNMENT:
WORKFLOW CONSTRUCTION: PublicDemoWorkflowState's public production factory (`PublicDemoWorkflowState({applicants, engineers})`) no longer has an `assignments` parameter at all — it always starts with `assignments: const []`. Only `PublicDemoWorkflowState.restore({applicants, engineers, assignments})` accepts one, and it is explicitly documented as a test-fixture/future-deserialization-only reconstruction boundary; the production command surface (PublicDemoAggregate, assignOrderedForMay) never calls it, so it is not reachable from the shipped UI.
ASSIGNMENT INJECTION: CLOSED at a second, independent layer — `withAssignment(id, updateFunction)` (FIX2's shape) let a caller's lambda ignore the real assignment and return an entirely fabricated `PublicDemoAssignment(...)`, substituting fake economic fields (budgetHealth/humanity/deliveryPressure/projectName/engineerName) for a real roster entry. Replaced by `withAssignmentUpdate(id, {nextOrderStatus, replacementStage, fieldEvaluation})`: named parameters only, mirroring PublicDemoAssignment.copyWith's own restricted field set — there is no argument through which a whole fabricated assignment can pass, and an unknown engineerId is a structural no-op (cannot append a new entry).
DOMAIN TRANSITION: assignOrderedForMay() unchanged — still the sole roster-computing method, reading only this workflow's own authoritative engineer/applicant stage facts; `_withAssignments` (wholesale replace) stays private to public_demo_workflow_state.dart.
INVALID ENGINEER: unchanged/retained — an engineer that never reached `ordered` never gets an assignment (existing test, still green).
DUPLICATE: unchanged/retained — assignOrderedForMay always replaces the roster wholesale from current facts, never appends (existing test, still green).
ASSIGNMENT AUTHORITY: closeMay (via PublicDemoAggregate.closeMay) is the only production caller of assignOrderedForMay; a fake roster injected via `.restore()` at test-fixture level does not survive a real closeMay call (new adversarial test).

P1-4 JOINED/PAYROLL:
MONTH CLOSE INPUT: PublicDemoMonthlyClose.closeMay now requires `workflow: PublicDemoWorkflowState` instead of `joinedApplicants: Iterable<PublicDemoApplicant>`. PublicDemoAggregate.closeMay(week, monthlyExpenses) — the widget's only entry point — takes no joined-applicant parameter of any kind.
JOINED DERIVATION: closeMay derives the joined set internally via `workflow.joinedApplicants` (itself `applicants.where((a) => a.hasJoined)`, backed by the unforgeable PublicDemoJoinRecord) and passes that complete set to PublicDemoState.advanceToJune.
OMISSION: STRUCTURALLY IMPOSSIBLE at the production boundary — there is no parameter through which a caller could hand closeMay a subset of the authoritative workflow's joined applicants. New test: two genuine joined applicants in the workflow both reach payroll; there is no argument to drop either one.
SUBSET: STRUCTURALLY IMPOSSIBLE, same reasoning.
STALE INPUT: closeMay always reads `workflow.joinedApplicants` from the SAME workflow value it is given at call time — PublicDemoAggregate.closeMay always passes `this.workflow` (the aggregate's own current, live workflow, updated by the same command's own join/assignment steps immediately before finance close), never a caller-held earlier reference. (PublicDemoMonthlyClose.closeMay and PublicDemoState.advanceToJune remain lower-level AUTHORITATIVE COMMAND-tier building blocks, individually unit-tested with caller-supplied fixtures exactly as PublicDemoState.advanceToJune already was pre-FIX3 — see BYPASS SEARCH COUNT / WORKFLOW SSOT below for the honest scope of this boundary.)
PAYROLL: unchanged/retained — advanceToJune dedupes within a single batch via a Set before appending to joinedApplicantIds (existing FIX2 test, still green); new test confirms duplicate identity in the workflow cannot duplicate payroll membership.
SALARY: unchanged/retained, additionally verified — join() resolves salary strictly from BindingOffer.acceptedMonthlySalary; new adversarial test tampers with the separately-mutable acceptedMonthlySalary field before closeMay and confirms the joined applicant's salary still comes from the real offer.
DUAL SSOT: CLOSED — PublicDemoState.joinedApplicantIds remains a compatibility field (documented as such), but it is now written ONLY from inside PublicDemoAggregate.closeMay's own derivation of the SAME workflow that command just finished updating; there is no second, independently-suppliable source feeding it.

WORKFLOW SSOT: PublicDemoWorkflowState.applicants (via hasJoined/hasBeenInterviewed/hasBindingOffer), composed under PublicDemoAggregate — unchanged design, now the aggregate's contained root instead of an independently-held widget field.
WIDGET AUTHORITY: NONE — public_demo_01_placeholder_screen.dart holds exactly one `PublicDemoAggregate _game` field; `s`/`workflow` are read-only getters over it with no setter in the file (verified: zero remaining `s = ` / `workflow = ` assignments outside the getters, confirmed by grep and by `flutter analyze` finding no unused-field warnings).
PUBLIC DOMAIN BYPASS: 0 (see search audit below)
BYPASS SEARCH COUNT: Full required-term search run against lib/game/public_demo + lib/ui/public_demo. Every occurrence classified: VALUE (e.g. PublicDemoAssignment's own public constructor, PublicDemoApplicant's cosmetic fields), READ ONLY (workflow.joinedApplicants, assignedEngineerIds getters), DERIVED (joinedApplicantIds), AUTHORITATIVE COMMAND (PublicDemoOfferAcceptance.accept, PublicDemoJoinTransaction.join, PublicDemoApplicant.join, PublicDemoState.advanceToJune/useSalesSlotForInterview, PublicDemoMonthlyClose.closeMay — each individually validated/tested, each reachable in production ONLY through PublicDemoAggregate), RESTORE ONLY (PublicDemoWorkflowState.restore, PublicDemoAggregate.restore — never called by the widget), TEST ONLY (fixtures in test/game/public_demo), or historical DOC PROSE (backtick-quoted mentions of removed method names in explanatory comments, e.g. `markInterviewed()`, `onCommitted`, kept as "here's what FIX3 closed and why" — confirmed none are live code references via `flutter analyze`/`flutter test`). BYPASS = 0.

SNAPSHOT: PublicDemoWorkflowSnapshot unchanged — remains immutable, capture() unchanged, all existing snapshot tests green.
SNAPSHOT LIVE PATH: NONE (as required — not implemented in FIX3).
FINANCE-FAILURE HANDOFF: PublicDemoAggregate is now the single consistent state boundary FINANCE-FAILURE's future monthly-close snapshot work can capture from: `PublicDemoWorkflowSnapshot.capture(aggregate.workflow, month: ...)` combined with `aggregate.state` gives one atomically-consistent (finance, workflow) pair at any point, rather than two independently-timed widget fields that could in principle be read mid-transition. No FINANCE-FAILURE behavior was implemented; this is documentation of the now-available boundary only, per instruction.

REVENUE: unchanged — no formula/timing touched; PublicDemoRevenuePayment untouched.
30-DAY AR: unchanged — pendingRevenue settlement timing untouched.
MARCH PENDING REVENUE: unchanged — closeOrdinaryMonth's March handling untouched.
GROWTH: unchanged — applyMonthlyGrowth untouched; PublicDemoAggregate.closeMay/closeJune/closeJuly/closeOrdinaryMonth reproduce the exact pre-FIX3 `_closeGrowth` timing (assignedEngineerIds from the post-transition workflow, moraleByEngineerId from the pre-transition workflow — verified by the full success-playthrough and fiscal-year-progression UI tests passing unchanged).
BONUS: unchanged — PublicDemoSummerBonusPayment untouched; PublicDemoAggregate.closeJuly is a thin wrapper reading workflow.joinedApplicants (already the full authoritative set).
RECRUITMENT ECONOMICS: unchanged — cost/applicantCount/candidate generation logic moved file (into public_demo_aggregate.dart) verbatim, not altered.
ASSIGNMENT ECONOMICS: unchanged — willOfferNextMonthFor/replacementPartnerScoreFor/replacementClientScoreFor formulas untouched.

P2 SCOPE: Investigated per instruction — searched the full diff from ORIGINAL BASE through FIX2 (`git diff` against base→FIX1, FIX1→FIX2, and the intermediate "refactor(public-demo): move workflow authority to domain" commit 4313a2b) for the two items independent review flagged as unrelated ("recruitment-month availability normalization", "cash-flow payroll/fixed-cost presentation changes").
UNRELATED FIX1 DIFF: NOT FOUND AS DESCRIBED. `_normalizedRecruitmentMediaMonth` (the recruitment-media month range 4-8) and the `salaryPaid`/`fixedCostsPaid` split in `PublicDemoMonthlyClose._cashFlow` both already exist verbatim in ORIGINAL BASE, attributed in their own doc comments to unrelated, already-merged prior fixes ("12MONTH-3-FIX1 P1-2" and a pre-existing FINANCE-UX-1-era fix respectively) — neither line changed in the base→FIX1 or FIX1→FIX2 diffs of this branch beyond mechanical touches (e.g. `result.state` → `result.state!` from the P1-2 nullability change, and a doc-comment class-name update). No economics/presentation formula or range was altered by FIX1 or FIX2 in this repository's actual history.
SEPARATION RECOMMENDATION: C — keep as is; there is nothing to separate. The specific unrelated content the independent review describes does not appear in this repository's FIX1/FIX2 diff. If the review was comparing against a different reference point or a different branch, that discrepancy should be raised with the reviewer rather than acted on speculatively here (STOP-and-report principle, section 17, applied to an ambiguous finding rather than a code path).

ADVERSARIAL TESTS: 17 new tests added directly targeting the four P1 closures at the PublicDemoAggregate boundary (test/game/public_demo/public_demo_aggregate_test.dart), plus updated/extended tests in public_demo_workflow_state_test.dart (P1-3: withAssignmentUpdate fabrication resistance, unknown-engineerId no-op), public_demo_monthly_close_test.dart (P1-4: workflow-based closeMay, two-genuine-joined-applicants case), public_demo_binding_offer_test.dart / public_demo_recruitment_workflow_transaction_test.dart / others (mechanical migration off removed APIs, assertions unchanged). All 17 required section-13 adversarial vectors walked through explicitly; see FULL TEST result below for the executed count. No existing test assertion was weakened or removed to force a pass.
FOCUSED DOMAIN: flutter test test/game/public_demo — 306/306 passed
FOCUSED UI: flutter test test/ui/public_demo — 35/35 passed
FULL TEST: flutter test — 890/890 passed (whole repository, not just Public Demo)
ANALYZE: flutter analyze — 0 issues (whole repository)
BUILD: flutter build web --release — succeeded (build/web produced)
DIFF CHECK: git diff --check — clean, no whitespace errors

P0: 0
P1: 0 (all four independent-review P1 findings closed at the PublicDemoAggregate/Domain boundary; adversarially tested)
P2: 0 (investigated per instruction; see P2 SCOPE — nothing found to separate in this repository's actual history)
P3: 0

CHANGED FILES: 22 (2 new: public_demo_aggregate.dart, public_demo_aggregate_test.dart; 1 deleted: public_demo_recruitment_workflow_transaction.dart, merged into the aggregate; 19 modified)
COMMIT: 9de2e166c0766cc53efb25cca1dc065575a848ae
REMOTE HEAD: 9de2e166c0766cc53efb25cca1dc065575a848ae

RESULT REPORT: SES_WORKFLOW-STATE-1AB_FIX3_Result.md

VERDICT: FIX3 IMPLEMENTED / READY FOR INDEPENDENT REREVIEW

NEXT: Codex independent FIX3 review

STOP
