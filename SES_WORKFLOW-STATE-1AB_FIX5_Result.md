# WORKFLOW-STATE-1A+B FIX5 — Assignment Stage Authority Closure — Result

## BASE
- FIX4 IMPLEMENTATION: `34df0bcb05c409ef1fe49d06d07f8a55be2b5638`
- FIX4 REPORT HEAD: `fbf88c36009c4e99adfc3451777c6b508a8bb837`
- BRANCH: `claude/workflow-state-fix5-assignment-authority-z4vf48`
  (rebuilt directly on the FIX4 report head; the branch's prior local state
  was a stale, no-unique-work pointer into unrelated early repo history and
  was reset — `git checkout -B` onto `fbf88c36009c4e99adfc3451777c6b508a8bb837`)
- IMPLEMENTATION COMMIT: `99b6ccf` (`fix(public-demo): close WORKFLOW-STATE-1A+B assignment stage authority bypass (FIX5)`)
- REPORT COMMIT: this file's own commit (see `git log`)
- REMOTE HEAD: pushed to `origin/claude/workflow-state-fix5-assignment-authority-z4vf48`
- DIFF: 6 files changed (implementation + tests), no UI/balance changes

## ENGINEER GENERIC STAGE SETTER
REMOVED. `PublicDemoWorkflowState.withEngineerStage(engineerId, stage)` and
`PublicDemoAggregate.withEngineerStage(engineerId, stage)` no longer exist.

## APPLICANT GENERIC STAGE SETTER
REMOVED. `PublicDemoWorkflowState.withApplicantStage(applicantId, stage)` and
`PublicDemoAggregate.withApplicantStage(applicantId, stage)` no longer exist.

Also removed (same shape, one level down — a caller-suppliable target stage
with no precondition check): `PublicDemoAggregate.consumeSlotAndSetApplicantStage`
and `PublicDemoAggregate.applyEngineerInterviewResult` (its `stage`/`score`
parameters). Neither was renamed-and-kept; both are gone.

## ENGINEER TRANSITION AUTHORITY
`PublicDemoWorkflowState` now exposes named, precondition-gated sales-pipeline
transitions instead of a stage setter:
- `startSkillSheetReview` (`waiting` → `skillSheet`)
- `beginSelling` (`skillSheet` | `partnerInterviewFailed` | `clientInterviewFailed` → `selling`)
- `introduceProject` (`selling` → `introduced`)
- `recordOrder` (`clientInterviewPassed` → `ordered`)

`PublicDemoAggregate.recordEngineerInterviewResult(engineerId, type)` derives
both the resulting stage and the score itself from the engineer's own
`interviewProfile`/`actualCapability` via `PublicDemoInterviewEvaluator` —
`stage`/`score` are no longer caller parameters. It requires the engineer to
already be at `introduced` (partner) / `partnerInterviewPassed` (client), and
for a partner interview only consumes a sales slot when one is genuinely
available (checked before consumption, so a rejected attempt never partially
consumes budget). Every transition is a no-op — state and workflow both
unchanged — when its precondition isn't met.

`ordered` is reachable only via `recordOrder`, which requires
`clientInterviewPassed` — itself set only by a genuine passed client
interview, gated on a genuine passed partner interview before that. There is
no path from `waiting` to `ordered` that skips either interview.

## APPLICANT TRANSITION AUTHORITY
`PublicDemoWorkflowState` now exposes:
- `reviewResume` (`applied` → `resumeReviewed`)
- `beginPreEntrySkillSheet` (`offerAccepted` + `canEnterPreJoinSales` → `preEntrySkillSheet`)
- `beginPreEntrySelling` (`preEntrySkillSheet` → `preEntrySelling`)
- `introducePreEntryProject` (`preEntrySelling` → `preEntryIntroduced`)
- `recordJuneOrder` (`preEntryClientPassed` → `juneOrdered`)

`PublicDemoAggregate.recordPreEntryPartnerInterviewResult(applicantId)` and
`.recordPreEntryClientInterviewResult(applicantId)` derive pass/fail
themselves from the applicant's own `salesSkillFit` (thresholds 60/65,
unchanged from the pre-cutover widget) — no `stage` or score parameter.
Partner interview consumes a sales slot (checked before consumption); client
interview does not, matching the original widget's `ci()` handler exactly.

`juneOrdered` is reachable only via `recordJuneOrder`, itself gated on
`preEntryClientPassed`, gated on a genuinely passed pre-entry partner
interview, gated on a genuine `offerAccepted` — which only
`PublicDemoOfferAcceptance.accept` can mint, and only for an applicant with a
genuine `PublicDemoInterviewRecord` (minted only by
`PublicDemoAggregate.completeInterview`). There is no path from `applied` to
`juneOrdered` that skips any of these.

## ENGINEER ASSIGNMENT ELIGIBILITY
`assignOrderedForMay` no longer trusts `stage == ordered` alone: it also
requires a genuine `lastInterviewScore` (non-null, set only by
`recordEngineerInterviewResult` when it actually evaluates a client
interview). Defense in depth per FIX5 §5 — even a future bug that lets
`stage` alone drift out of sync cannot mint an assignment for an engineer
with no real interview record.

## APPLICANT ASSIGNMENT ELIGIBILITY
`assignOrderedForMay` also requires `applicant.hasJoined` (the unforgeable
`PublicDemoJoinRecord`, mintable only by a genuine
`PublicDemoJoinTransaction.join`) alongside `stage == juneOrdered`. `stage`
alone is never sufficient.

## JOIN REQUIREMENT
Confirmed structurally: `PublicDemoJoinRecord`'s constructor is private to
`public_demo_recruitment.dart`; no caller outside that file (including this
repo's own test files) can fabricate one via a literal or `copyWith`. The
only way to obtain `hasJoined == true` is a genuine
`PublicDemoJoinTransaction.join` call succeeding.

## JOIN FAILURE
`joinAndKeepOnly` (unchanged behavior, doc comment updated): a join failure
leaves the applicant's pre-existing `stage` untouched (e.g. still
`juneOrdered`) but never sets `hasJoined`. Because `assignOrderedForMay` now
requires `hasJoined` in addition to `stage`, a join failure can never reach
an assignment regardless of which stage employment authority left behind —
verified end-to-end (TEST C) via a genuinely-reachable staleFiscalClose case.

## DUPLICATE ASSIGNMENT
Unchanged, reverified: `assignOrderedForMay` always replaces the assignment
roster wholesale from current stage facts — never appends. TEST F confirms
retrying `closeMay` on an already-closed aggregate does not duplicate the
assignment.

## ATTACK A
`PublicDemoAggregate.withEngineerStage(id, PublicDemoSalesStage.ordered)`
followed by `closeMay()`. Method removed entirely; no equivalent-shaped
replacement exists (`recordOrder` requires `clientInterviewPassed`, verified
as a no-op otherwise). CLOSED — reproduced end-to-end in TEST A.

## ATTACK B
`PublicDemoAggregate.withApplicantStage(id, PublicDemoApplicantStage.juneOrdered)`
on a non-joined applicant, followed by `closeMay()`. Method removed entirely;
`recordJuneOrder` requires `preEntryClientPassed`, verified as a no-op
otherwise, and `assignOrderedForMay` additionally requires `hasJoined` even
if `stage` were somehow set. CLOSED — reproduced end-to-end in TEST B.

## ATTACK C
(FIX5-identified defense-in-depth case, section 5/6): a genuinely
`juneOrdered` applicant whose join fails (stale fiscal close) reaching an
assignment via `stage` alone. CLOSED — `assignOrderedForMay`'s `hasJoined`
check rejects it; verified end-to-end in TEST C using a genuinely-reachable
production path (real interview/offer/pre-entry chain, offer accepted
against an earlier fiscal close than `closeMay`'s), not a fabricated object.

## AUTHORITATIVE ROOT
SINGLE (unchanged from FIX4 — `PublicDemoAggregate` remains the sole
authoritative root; no new public method accepts a caller-supplied
`PublicDemoState`/`PublicDemoWorkflowState` value).

## FINANCE-ONLY COMMIT
CLOSED (unchanged from FIX4; no new code path introduced one).

## WORKFLOW-ONLY COMMIT
CLOSED (unchanged from FIX4; no new code path introduced one).

## PUBLIC DOMAIN BYPASS
Audited (section 9): `grep -rn "withEngineerStage\|withApplicantStage\|consumeSlotAndSetApplicantStage\|applyEngineerInterviewResult" lib/`
returns comments only (historical references explaining the closure) — zero
live-code occurrences. No new generic setter was introduced under any name;
every replacement method is precondition-gated and named for one real
domain event.

## BYPASS COUNT
0

## INTERVIEW
Unchanged — `PublicDemoAggregate.completeInterview` remains the sole way to
mint a `PublicDemoInterviewRecord`; still required before `acceptOffer`.

## OFFER
Unchanged — `PublicDemoOfferAcceptance.accept` still requires
`hasBeenInterviewed`, never trusts `stage` alone (doc comment updated to
reflect FIX5's removal of `withApplicantStage`, same reasoning preserved).

## BINDING OFFER
Unchanged — identity/fiscal validity checks untouched.

## JOIN
Unchanged mechanically; `assignOrderedForMay` now also consumes its result
(`hasJoined`) as an assignment-eligibility gate (see above).

## SALARY
Unchanged — still resolved from the authoritative `BindingOffer`, never a
caller-tampered `acceptedMonthlySalary`.

## RECRUITMENT ATOMICITY
Unchanged — `recruit()` still commits cash + generated applicants together
or not at all.

## CLOSE AUTHORITY
PASS — `closeMay` still computes its own roster/join set from the
aggregate's own current workflow; no `workflow:`/`assignments:` parameter
exists.

## PAYROLL AUTHORITY
PASS — unchanged.

## REVENUE / 30-DAY AR / MARCH / GROWTH
Unchanged — no code in this fix touches finance/monthly-close calculation
logic; regression covered by the full test suite (see FULL TEST below).

## ADVERSARIAL TESTS
Added to `test/game/public_demo/public_demo_aggregate_test.dart`, group
`WORKFLOW-STATE-1AB FIX5 P1: assignment-authority adversarial tests`:
- TEST A — engineer stage spoof (recordOrder skip-ahead) → assignment NOT created. PASS
- TEST B — applicant stage spoof (recordJuneOrder skip-ahead) → assignment NOT created. PASS
- TEST C — genuine juneOrdered applicant, join fails (stale fiscal close) → assignment NOT created. PASS
- TEST D — genuine engineer happy path → assignment created exactly once. PASS
- TEST E — genuine applicant happy path (interview → offer → BindingOffer → join → order) → assignment created exactly once. PASS
- TEST F — retry closeMay → no duplicate assignment. PASS

Also added to `public_demo_workflow_state_test.dart`: a stage-alone rejection
test at the `assignOrderedForMay` level (unproven engineer / unjoined
applicant, both rejected) and a "sales pipeline cannot be skipped" test for
`recordOrder`.

## ANALYZE
`flutter analyze` (whole project): **No issues found.**

## FOCUSED DOMAIN
`flutter test test/game/public_demo`: **333 tests, all passed.**

## FOCUSED UI
`flutter test test/ui/public_demo`: **35 tests, all passed.**

## FULL TEST
`flutter test`: **900 tests, all passed.**

## BUILD
`flutter build web --release`: **succeeded** (`✓ Built build/web`).

## DIFF CHECK
`git diff --check`: clean, no whitespace errors.

Environment note: this session's container had no Flutter/Dart toolchain
preinstalled; Flutter 3.35.5 (stable) was downloaded to the session
scratchpad and used for all validation above. `flutter pub get` downgraded
several transitive dependencies in `pubspec.lock` to satisfy this SDK's
resolver — that file change was reverted (`git checkout -- pubspec.lock`)
before committing, since it is unrelated to this fix.

## P0
0

## P1
0 (the one open P1 from FIX4 — the engineer/applicant generic stage
setters — is closed by this fix)

## P2
0 changed by this fix (FIX4's P2 was out of scope per FIX5's instructions —
"残っているP1だけを最小修正してください" — and was not touched)

## P3
0

## CHANGED FILES
- `lib/game/public_demo/public_demo_workflow_state.dart`
- `lib/game/public_demo/public_demo_aggregate.dart`
- `lib/game/public_demo/public_demo_binding_offer.dart` (comment only)
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (call-site wiring only — no UI/behavior change)
- `test/game/public_demo/public_demo_workflow_state_test.dart`
- `test/game/public_demo/public_demo_aggregate_test.dart`

## VERDICT
WORKFLOW-STATE-1A+B FIX5 IMPLEMENTED /
READY FOR FINAL FOCUSED REREVIEW

## NEXT
Codex final focused FIX5 review
