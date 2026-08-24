# WORKFLOW-STATE-1A+B FIX2 — Codex P1 Rereview Closure — Implementation Result

## 1. Base Verification

`git fetch origin 2547e4225097af5be1d8f4957e18a0bbe058f47a claude/workflow-state-1ab-fix1-1ilyt3 4313a2b9b040eb15e47001d1d357099ea91b8eb3 2a9aaca48e13a88aea47649f295eca9f131b997a` succeeded. Confirmed:

- `git cat-file -t 2547e4225097af5be1d8f4957e18a0bbe058f47a` → `commit` (FIX1 TARGET exists).
- `git merge-base --is-ancestor 2547e42... origin/claude/workflow-state-1ab-fix1-1ilyt3` → true (FIX1 TARGET is on the FIX1 branch).
- `git merge-base --is-ancestor 4313a2b... 2547e42...` → true (FIX1 TARGET descends from the WORKFLOW-STATE-1A+B base).
- The session's designated branch (`claude/workflow-state-fix2-p1-ctaakf`) was pointed at `f4ca78f` ("Phase 0A/0B"), a pure ancestor of `2547e42...` (280+ commits behind, zero unique commits) — `git checkout -B claude/workflow-state-fix2-p1-ctaakf 2547e42...` is a fast-forward from the remote branch tip, no destructive reset, no work lost.
- `git status --short` was clean before any implementation work.

FIX2 starts from `2547e4225097af5be1d8f4957e18a0bbe058f47a` exactly, per the task's requirement.

## 2. Scope

Implemented only the four Codex P1 findings from the FIX1 rereview, plus their required adversarial tests. No FINANCE-FAILURE, no HOME-UI-1, no new features, no balance/probability/economics changes, no unified save/snapshot system.

## 3. Design Principle Applied

Per the task's own §6: making every public API private is not the goal — separating **immutable data representation** from **authoritative state transition** is. Where FIX1 gated authority on a *field* a caller could still set via public `copyWith` (`stage == interviewed`, `employeeMorale`/`employeeCompanyTrust` non-null), FIX2 replaces those checks with **unforgeable, identity-bound marker objects** — the same pattern the codebase already used for `PublicDemoBindingOffer` (private constructor, checked by identity, not just presence):

- `PublicDemoInterviewRecord` (new) — proof of a genuine interview, minted only by `PublicDemoApplicant.markInterviewed()`.
- `PublicDemoJoinRecord` (new) — proof of a genuine join, minted only by `PublicDemoApplicant.join()`.

Both mirror `PublicDemoBindingOffer`: constructor private to `public_demo_recruitment.dart`, carries the owning applicant's id, and is still (deliberately) settable via the public `copyWith` — reuse across applicants is caught by the identity check, exactly like the existing BindingOffer-reuse defense. This means `PublicDemoApplicant.copyWith`, `withApplicantStage`, and the generic `withApplicant` did **not** need to be made private: they remain exactly as generic as before, but no longer confer any exploitable authority, because the two commands that used to trust `stage`/morale-trust-presence now trust only the unforgeable records.

## 4. P1-1 — BindingOffer / Stage / Direct Join

**Finding:** `PublicDemoApplicant.copyWith(stage: interviewed)` / `withApplicantStage` let a caller fabricate the interview prerequisite; `PublicDemoOfferAcceptance.accept` trusted that field; `PublicDemoApplicant.join()` (public, callable directly) had no fiscal-close check.

**Fix** (`public_demo_recruitment.dart`, `public_demo_binding_offer.dart`, `public_demo_join.dart`, `public_demo_workflow_state.dart`, `public_demo_01_placeholder_screen.dart`):

- **A. Stage authority:** `PublicDemoWorkflowState.markApplicantInterviewed(applicantId)` is now the sole sanctioned way to reach `interviewed`, minting `PublicDemoInterviewRecord`. `withApplicantStage` asserts against being called with `interviewed` (debug/test-time contract signal); the real defense is B below, which holds even in release builds where the assert is stripped. The widget's `recruit()` now calls `markApplicantInterviewed` instead of the generic `as()`/`withApplicantStage`.
- **B. Offer authority:** `PublicDemoOfferAcceptance.accept` now checks `applicant.hasBeenInterviewed` (`interviewRecord?.applicantId == id`), not `stage`. A `copyWith(stage: interviewed)`-only fabrication still sets the display field but mints no record, so `accept` rejects it (`invalidStage`).
- **C. Fiscal-close identity:** unchanged from FIX1 — `PublicDemoBindingOffer.fiscalCloseId` is recorded at acceptance and checked at join.
- **D. Direct-join authority:** `PublicDemoApplicant.join()` now requires `currentFiscalCloseId` and duplicates the stale-close and wrong-applicant checks `PublicDemoJoinTransaction.join` already had — a caller bypassing the transaction and calling `.join()` directly can no longer skip fiscal validity.
- **E/F. Full verification + fabrication rejection:** join (direct or via the transaction) verifies applicant identity, offer identity, fiscal validity, not-already-joined, and always re-derives salary from the offer — all before FIX2, all still true after.

## 5. P1-2 — Recruitment Composite-Result Bypass

**Finding:** `PublicDemoRecruitmentWorkflowResult` exposed `.state` and `.workflow` as two independently assignable public fields — a caller could commit `result.state` (cash) while discarding `result.workflow` (generated applicants).

**Fix** (`public_demo_recruitment_workflow_transaction.dart`, widget): `PublicDemoRecruitmentWorkflowResult` is deleted. `execute()` now:

- Always returns `PublicDemoRecruitmentTransactionResult` — read-only facts (`status`, `medium`, `chargedAmount`, `generatedApplicants`) with **no** committed `PublicDemoState`/`PublicDemoWorkflowState` field at all.
- Accepts an optional `onCommitted(PublicDemoState, PublicDemoWorkflowState)` callback, invoked exactly once, synchronously, with both together, only on success.

The internal pure calculation's own result type (renamed `_PublicDemoRecruitmentCalculationResult`, carries `.state`) is private to the file — nothing outside it can read the committed cash-bearing state without going through `onCommitted`. The widget captures both callback arguments into local variables and applies them in a single `setState`.

## 6. P1-3 — Assignment Public Fabrication

**Finding:** `PublicDemoWorkflowState`'s public `copyWith(assignments: ...)` (a leftover generic setter, distinct from the already-privatized `_withAssignments`) let a caller replace the roster on an *existing* authoritative workflow instance wholesale.

**Fix** (`public_demo_workflow_state.dart`): the public `copyWith` no longer accepts an `assignments` parameter at all (`applicants`/`engineers` only). A new private `_copyWith` carries the full three-field version; `_withAssignments` and `withAssignment` (per-entry field update) now call `_copyWith` instead. `assignOrderedForMay()` remains the sole path that can populate `assignments` on an existing instance, unchanged from FIX1. `PublicDemoAssignment`'s public constructor and the `PublicDemoWorkflowState` factory constructor remain public (per §3's design principle: constructing a *standalone* value is not "injecting into an existing authoritative workflow" — nothing in `lib/` besides `.initial()`/`_copyWith` calls the factory constructor).

**ASSIGNMENT AUTHORITY = SINGLE** (`assignOrderedForMay`).

## 7. P1-4 — Joined Projection Fabricated Applicant Bypass

**Finding:** `advanceToJune`/`closeMay` take `Iterable<PublicDemoApplicant>`; `hasJoined` was `employeeMorale != null && employeeCompanyTrust != null` — both freely settable via public `copyWith`, so a caller could fabricate a "joined" record without ever calling `join()`.

**Fix** (`public_demo_recruitment.dart`, `public_demo_state.dart`): `hasJoined` now checks `joinRecord?.applicantId == id` — `PublicDemoJoinRecord`, private-constructor, minted only inside `PublicDemoApplicant.join()`. `copyWith(employeeMorale: ..., employeeCompanyTrust: ...)` alone no longer confers joined status. `advanceToJune`'s derivation is unchanged in shape (still derives from `hasJoined` on the applicants passed in) but is now provably unforgeable. Also fixed a real dedup bug found while auditing this path: `newlyJoinedIds` was deduped only against the *already-accumulated* `joinedApplicantIds`, not within the current batch itself, so passing the same genuinely-joined applicant twice in one call could double-add their id. Now deduped via a `Set` before the batch is appended.

## 8. Domain Design Rule Compliance

Per §6, checked both directions for all four:

- Value objects (`PublicDemoApplicant`, `PublicDemoAssignment`) remain freely publicly constructible/copyWithable — this is fine, verified harmless.
- No authoritative command (`PublicDemoOfferAcceptance.accept`, `PublicDemoApplicant.join`, `advanceToJune`, `assignOrderedForMay`, `PublicDemoRecruitmentWorkflowTransaction.execute`) trusts a caller-fabricated fact without an unforgeable marker or a structural (not merely field-shape) guarantee behind it.

## 9. Adversarial Self-Review (§11) — Executed Before Commit

All ten listed attacks were attempted and confirmed rejected (each now has a corresponding automated test — see §11 in the code, `public_demo_binding_offer_test.dart`, `public_demo_join_test.dart`, `public_demo_workflow_state_test.dart`, `public_demo_recruitment_workflow_transaction_test.dart`, `public_demo_monthly_close_test.dart`):

1. **Fake interviewed applicant** (`copyWith(stage: interviewed)`, then `accept`) → `hasBeenInterviewed` is false (no record) → `invalidStage`. CLOSED.
2. **Stale genuine BindingOffer** (accepted at month 5, joined at month 8, via `PublicDemoJoinTransaction` *and* direct `.join()`) → rejected both ways (`staleFiscalClose` / no-op). CLOSED.
3. **Wrong-applicant genuine BindingOffer** (`copyWith(bindingOffer: offerForSomeoneElse)`, via transaction *and* direct `.join()`) → rejected both ways (`wrongApplicant` / no-op). CLOSED.
4. **Direct `applicant.join()`** (bypassing `PublicDemoJoinTransaction` entirely) → now enforces identity + fiscal-close checks itself; no longer a bypass. CLOSED.
5. **Recruitment result finance-only retention** (`s = result.state`, discard workflow) → `result` (the read-only `PublicDemoRecruitmentTransactionResult`) has no `.state` field at all; the only path to the committed state pairs it with the committed workflow via `onCommitted`. CLOSED.
6. **Arbitrary `PublicDemoAssignment` injection** → constructible standalone, but no public path attaches it to an existing workflow's `assignments`. CLOSED.
7. **`workflow.copyWith(assignments: fake)`** → compile error (`copyWith` has no such parameter). CLOSED.
8. **Fabricated `hasJoined` applicant passed to close** (`copyWith(employeeMorale/employeeCompanyTrust)`, no `join()`) → `hasJoined` false (no `PublicDemoJoinRecord`) → excluded from the projection. CLOSED.
9. **Omit a genuine joined applicant from close input** → the projection is additive (`...joinedApplicantIds, ...newlyJoinedIds...`); a previously-recorded id is never dropped by a later call that doesn't repeat it — regression-tested (`5->6`/`6->7` equivalence groups, unmodified, still pass). CLOSED / not a bypass.
10. **Duplicate joined applicant/payroll** → the dedup bug (§7) is fixed; a batch with the same applicant twice adds the id once. CLOSED.

**FIX2 NOT READY criterion did not trigger: zero authority was changeable by any of the ten attacks.**

## 10. Search Audit (§12)

Grepped `lib/` for every listed pattern; classified every occurrence:

| Pattern | Location | Classification |
|---|---|---|
| `copyWith(stage:` | `public_demo_workflow_state.dart` (`withApplicantStage`, `withEngineerStage`) | AUTHORITATIVE — generic field-setter infrastructure; confers no exploitable authority since `stage` is no longer trusted by `accept()` (interview) — see §3/§4. |
| `withApplicantStage` | `public_demo_01_placeholder_screen.dart` (pre-entry pipeline stages only, never `interviewed`), `public_demo_workflow_state.dart` (definition, asserts against `interviewed`) | AUTHORITATIVE — remaining call sites transition non-workflow-significant stages only. |
| `PublicDemoOfferAcceptance` | `public_demo_binding_offer.dart` (sole minting entry), `public_demo_workflow_state.dart` (`acceptOffer`, resolves applicant from `this.applicants` by id) | AUTHORITATIVE — no direct-call bypass remains exploitable (gated on `hasBeenInterviewed`, an unforgeable record). |
| `.join(` | `public_demo_join.dart` (`PublicDemoJoinTransaction.join`, threads `currentFiscalCloseId` into the model method), `public_demo_workflow_state.dart` (`joinAndKeepOnly`) | AUTHORITATIVE — both the transaction and the model method itself now enforce every check. |
| `BindingOffer` | `public_demo_binding_offer.dart` (sole minting), `public_demo_recruitment.dart`/`public_demo_join.dart` (identity/freshness checks), `public_demo_workflow_snapshot.dart` (read-only projection) | AUTHORITATIVE — unchanged in kind from FIX1. |
| `PublicDemoRecruitmentWorkflowResult` | *(no occurrences — class deleted)* | CLOSED. |
| `PublicDemoAssignment(` | `public_demo_assignment.dart` (model/factory/initial pool, VALUE ONLY), `public_demo_workflow_state.dart:274` (`assignOrderedForMay`, AUTHORITATIVE) | No production construction path reaches an existing workflow's `assignments` outside `assignOrderedForMay`. |
| `copyWith(assignments:` | `public_demo_workflow_state.dart:250` (`_copyWith`, private) | AUTHORITATIVE/CLOSED — the public `copyWith` has no such parameter; only the private full-field version, reachable only from `_withAssignments`. |
| `withAssignments` | `public_demo_workflow_state.dart` (`_withAssignments`, private) | CLOSED — unchanged from FIX1, single internal caller. |
| `joinedApplicantIds` | `public_demo_state.dart` (storage/derivation), `public_demo_workflow_state.dart` (derived getter), `public_demo_01_placeholder_screen.dart` (read-only UI filters) | DERIVED — one-directional, workflow → projection; now backed by the unforgeable `PublicDemoJoinRecord`. |
| `advanceToJune(` | `public_demo_monthly_close.dart` (`closeMay`, sole caller), `public_demo_state.dart` (definition) | AUTHORITATIVE — no raw-id-list route exists; caller-supplied applicant records no longer confer joined status without a genuine record. |
| `closeMay(` | `public_demo_01_placeholder_screen.dart` (widget, passes `nextWorkflow.applicants.where((a) => a.hasJoined)`), `public_demo_monthly_close.dart` (definition) | AUTHORITATIVE. |

**BYPASS = 0.**

## 11. P2 Scope Contamination Check (§8)

Diffed `4313a2b..HEAD` (FIX1 + FIX2 combined) and separately reviewed the FIX2-only diff (`2547e42..HEAD`, this commit) file by file. No recruitment-month-availability or cash-flow-presentation changes were made or reintroduced in FIX2 — those were FIX1-era P2 findings, untouched here. FIX2's own diff touches only: `public_demo_recruitment.dart`, `public_demo_binding_offer.dart`, `public_demo_join.dart`, `public_demo_recruitment_workflow_transaction.dart`, `public_demo_state.dart` (one method + comment), `public_demo_workflow_state.dart`, `public_demo_01_placeholder_screen.dart` (two call sites), and their tests.

**No UNRELATED diff from FIX1 was found still open in this branch to flag** — this FIX2 commit is layered directly on the FIX1 commit and does not touch anything FIX1 changed outside the four P1 areas.

## 12. Regression Invariants (§9)

Unchanged: Revenue formula, 30-day AR, March pending Revenue, Growth formula, bonus rules, salary economics, recruitment cost/probability, assignment economics, fiscal calendar. Verified by every pre-existing Revenue/Growth/bonus/salary/recruitment-economics test passing unmodified (see §13).

## 13. Test Execution (§10)

Environment note: this session's container had no Flutter/Dart SDK preinstalled (`flutter`/`dart` not on PATH, no cached SDK anywhere under `/`). Network egress to `storage.googleapis.com`/GitHub was available, so Flutter 3.47.1 (stable channel) was cloned and bootstrapped locally (`/home/user/flutter_sdk`) to actually run every check below rather than only reasoning about the diff. `flutter pub get` bumped 4 transitive dev-dependency versions in `pubspec.lock` as a side effect of resolving against this freshly-bootstrapped SDK; that file was reverted (`git checkout -- pubspec.lock`) since it is unrelated to this task's scope.

- **formatter:** `dart format` on the repo showed 162 pre-existing files (including many outside this diff) needing reformatting under this SDK's formatter version — a pre-existing drift unrelated to this change, not touched. `dart format` was run only on this diff's own 24 changed files (7 lib + 17 test), which fixed formatting FIX2 itself introduced; no other file was reformatted.
- **flutter analyze:** No issues found (full repo).
- **focused public-demo domain + UI tests** (`test/game/public_demo/` + `test/ui/public_demo/`): 340 passed, 0 failed.
- **flutter test** (full suite): 872 passed, 0 failed, 0 skipped.
- **flutter build web --release:** succeeded (`✓ Built build/web`).
- **git diff --check:** clean (exit 0).

No test timeout was extended and no test expectation was weakened; the join/advanceToJune dedup fix in §7 was a genuine behavior fix (a real duplicate-id bug), not a loosened assertion, and its own new tests assert the stricter, correct behavior.

## 14. Snapshot (§7 of task)

Unchanged from FIX1: `PublicDemoWorkflowSnapshot` immutability-tested, unmodified. **SNAPSHOT LIVE PATH: DEFERRED TO FINANCE-FAILURE** (unchanged; not a P1, no historical-storage plumbing added).

## 15. RECOMMENDED AI

Claude Code

## 16. Report Fields

```
BASE:              2a9aaca48e13a88aea47649f295eca9f131b997a
FIX1:              2547e4225097af5be1d8f4957e18a0bbe058f47a
FIX2 BASE:         2547e4225097af5be1d8f4957e18a0bbe058f47a
BRANCH:            claude/workflow-state-fix2-p1-ctaakf
HEAD:              14d8de13bcc83d985414c8cf56d6c0838c8d570f
REMOTE HEAD:       see §17 below (populated after push)
DIFF:              25 files changed, 1041 insertions(+), 334 deletions(-)
                   (7 lib/, 18 test/, all within
                   lib/game/public_demo, lib/ui/public_demo,
                   test/game/public_demo, test/ui/public_demo)

P1-1 BINDING OFFER:
  STAGE AUTHORITY:    CLOSED — accept() gates on PublicDemoInterviewRecord
                       (identity-bound, private ctor), not `stage`
  OFFER AUTHORITY:    CLOSED — markApplicantInterviewed is the sole path
                       to a genuine record
  DIRECT JOIN:        CLOSED — PublicDemoApplicant.join() now enforces
                       identity + fiscal-close checks itself
  FISCAL VALIDITY:    CLOSED — checked at both transaction and model level
  SALARY AUTHORITY:   CLOSED — join() always re-derives from the offer
                       (unchanged from FIX1)
  FABRICATION BYPASS: CLOSED — copyWith(stage:)-only fabrication mints no
                       record, fails accept authority

P1-2 RECRUITMENT:
  RESULT AUTHORITY:   CLOSED — PublicDemoRecruitmentWorkflowResult deleted;
                       execute() returns read-only facts only
  ATOMIC COMMIT:      CLOSED — onCommitted invoked once with both
                       state+workflow, only on success
  FINANCE-ONLY BYPASS: CLOSED — no field on the result carries the
                       committed PublicDemoState at all
  FAILURE ROLLBACK:   CLOSED — onCommitted never fires on failure (proven
                       by test, not just value-equality)

P1-3 ASSIGNMENT:
  PUBLIC FABRICATION: CLOSED — PublicDemoAssignment remains constructible
                       (harmless per §6) but cannot reach an existing
                       workflow's assignments
  ROSTER INJECTION:   CLOSED — public copyWith has no `assignments` param
  DOMAIN COMMAND:     assignOrderedForMay (unchanged from FIX1)
  ASSIGNMENT AUTHORITY: SINGLE

P1-4 JOINED PROJECTION:
  CLOSE INPUT:        Iterable<PublicDemoApplicant> (unchanged shape,
                       now provably unforgeable)
  FABRICATED APPLICANT: CLOSED — hasJoined backed by PublicDemoJoinRecord
                       (identity-bound, private ctor)
  OMITTED APPLICANT:  N/A — projection is additive, never regresses
  DERIVATION:         advanceToJune derives ids from applicant.hasJoined,
                       deduped within-batch (bug fixed)
  PAYROLL AUTHORITY:  CLOSED
  DUAL SSOT:          CLOSED — one-directional workflow -> projection

WORKFLOW SSOT:      PublicDemoWorkflowState (unchanged)
WIDGET AUTHORITY:   NONE — widget constructs no domain-significant value,
                     only wires command results

SNAPSHOT:            PASS (unchanged, immutability-tested)
SNAPSHOT LIVE PATH:  DEFERRED TO FINANCE-FAILURE

REVENUE:             PASS (unmodified tests)
30-DAY AR:           PASS (unmodified tests)
MARCH PENDING REVENUE: PASS (unmodified tests)
GROWTH:              PASS (unmodified tests)
PAYROLL/BONUS:       PASS (unmodified tests, plus new P1-4 regression tests)

ADVERSARIAL TESTS:   ALL 10 EXECUTED AND CONFIRMED REJECTED (§9/§11)
FOCUSED TESTS:       340 passed, 0 failed (test/game/public_demo +
                     test/ui/public_demo)
UI TESTS:            included above (test/ui/public_demo)
FULL TEST:           872 passed, 0 failed, 0 skipped (flutter test)
ANALYZE:             No issues found (flutter analyze, full repo)
BUILD:               flutter build web --release succeeded (✓ Built build/web)
DIFF CHECK:          clean (git diff --check)

DIFF CLASSIFICATION:
AUTHORITY:           lib/game/public_demo/public_demo_binding_offer.dart,
                     public_demo_join.dart, public_demo_recruitment.dart,
                     public_demo_recruitment_workflow_transaction.dart,
                     public_demo_state.dart, public_demo_workflow_state.dart,
                     lib/ui/public_demo/public_demo_01_placeholder_screen.dart
TEST:                all 18 changed files under test/game/public_demo and
                     test/ui/public_demo
DOCUMENTATION:       this report (SES_WORKFLOW-STATE-1AB_FIX2_Result.md)
UNRELATED:           none found in this FIX2 commit; no open UNRELATED
                     diff carried over from FIX1 either (see §11)

P0: 0
P1: 0 (all four Codex rereview findings closed)
P2: 0 open (snapshot live path explicitly deferred, not an open finding)
P3: 0

CHANGED FILES:       25
COMMIT:              14d8de13bcc83d985414c8cf56d6c0838c8d570f
REMOTE HEAD:         see §17 below
```

## 17. Commit / Push

Committed as FIX2 on `claude/workflow-state-fix2-p1-ctaakf` (branch fast-forwarded to the FIX1 target `2547e42` prior to implementation, per §1). Commit `14d8de13bcc83d985414c8cf56d6c0838c8d570f`. Pushed to `origin/claude/workflow-state-fix2-p1-ctaakf` with `git push -u origin claude/workflow-state-fix2-p1-ctaakf` (no force). No PR created, no merge performed.

## 18. Verdict

**FIX2 IMPLEMENTED / READY FOR INDEPENDENT REREVIEW**

## 19. Next

Codex independent FIX2 rereview.

STOP
