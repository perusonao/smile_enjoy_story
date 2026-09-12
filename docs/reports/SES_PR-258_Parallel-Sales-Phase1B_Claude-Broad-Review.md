# SES PR #258 — Parallel Sales Phase 1B — Claude Independent Broad Review

Status: **Independent review complete. One P1 correctness bug found, root-caused, and fixed in this same session (focused patch + focused regression test). No other P0/P1 found. One P2 scope gap (Issue #257's own "必須" `projectInterviewSessions` composite-key widening) is silently missing from this PR — documented here as a known limitation, not fixed in this session (out of the "safe, local fix" scope this review reserves for P0/P1).**

This report is the **sole** Broad Review for PR #258. The task's own instructions record that an earlier Codex Broad Review request failed on usage limits and produced no actual review content; this Claude Independent Broad Review is designated the one substitute, and is not to be repeated recursively.

## Reviewed base / HEAD

- **Reviewed base SHA (origin/main):** `3dffd5c78b5c956dfc4f0804eb12887d17042eb1` (PR #254's own merge commit) — confirmed via `git fetch origin` + `git rev-parse origin/main` at session start; matches the task's own stated confirmed base exactly. No drift.
- **Reviewed original PR #258 HEAD:** `2f6f367f216856521171f6bd0be7b7aa5037cd85` — confirmed via `pull_request_read` at session start; matches the task's own stated confirmed HEAD exactly. No drift.
- **Final HEAD after this session's fix:** see "Fixes made" below — recorded once pushed.

This review was performed in an isolated git worktree checked out at the PR HEAD commit above, not on this session's own designated review branch (`claude/ses-pr-258-phase-1b-review-slfcaw`) — per the task's own explicit instruction to fix (if needed) "同じPR branch上で", any code fix and this report are committed directly onto the PR's own branch (`claude/first-fun-year-phase-1b-2zy73j`).

## Scope note: environment

This session's container had no Flutter/Dart SDK preinstalled. Flutter 3.47.4 (stable channel) was fetched fresh via `git clone` for this review specifically so that `flutter analyze`/`flutter test`/reproduction tests could be run for real, rather than relying on the PR's own self-reported numbers. All test/analyze results below are from this session's own execution, not copied from the Phase 1B Result Report.

## Documents read in full

- `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Result.md` (Fresh Audit / design)
- `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Phase1a_Result.md` (Phase 1a domain foundation)
- `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Phase1B_Result.md` (this PR's own report)
- Issue #257 (full body), Issue #245 (full body, Finding #4 focus)
- PR #258 description/diff in full (`public_demo_offer_candidate.dart`, `public_demo_workflow_state.dart`, `public_demo_save_codec.dart`, the new test file, decisions doc)

## Authority review

Confirmed by direct code reading (not by trusting the Result Report's own claims):

- **`PublicDemoEngineerSales.stage`** remains the coarse, unmodified legacy scalar — `public_demo_sales.dart` has zero diff in this PR. `assignOrderedForMay`, `recoverLateYearAssignment`, and `PublicDemoAggregate.availableEngineersForMatching` are **byte-for-byte unchanged** (confirmed: `git diff` restricted to those three symbols across the whole `lib/` diff returns nothing) — they remain the sole gate for month-boundary assignment materialization and Matching-screen eligibility. `offerCandidates` is not yet read by any of them, exactly as documented.
- **`offerCandidates`** is now a live mirror synchronized from four real production entry points: `proposeMatch`→`withMatchingProposal` (candidate creation), the interactive Partner/Client Interview conclusion methods (`concludePartnerProjectInterview`/`concludeProjectInterview`, syncing an already-computed outcome, never a second evaluation), and `recordOrder` (candidate-aware order + atomic sibling decline). Confirmed via direct reading of each method body, not the report's prose.
- **`matchingProposals`** (single-slot per engineer) and **`projectInterviewSessions`** (single-slot per `employeeId`, unchanged — see P2 finding below) remain exactly as before; neither was widened to a composite key in this PR.
- Dual-authority precedence: for every genuine, real production path traced (propose → partner interview → client interview → order), the engineer-level legacy scalar and the per-candidate authority are written **atomically in the same `_copyWith` call** in every cutover site — confirmed no split-write windows exist. The one confirmed way the two authorities can legitimately *disagree* transiently is by design: a candidate for a project other than the engineer's current single matchingProposal is a real, independent history entry the coarse scalar can never speak to (this is the entire point of the feature) — not a bug.
- **Genuinely wrong-direction overwrite found:** see P1 finding below — under one specific, easily-reachable production sequence, the coarse legacy scalar's *unrelated-project* progress overwrites a brand-new candidate's own progress at creation time. This is exactly the "誤った方が正しい方を上書きしないか" failure mode the review brief asked to check for, just localized to *candidate creation* rather than to reconciliation itself (reconciliation's own upgrade/no-rewind logic, checked independently below, is correct).

## Reconciliation review (`_reconcileOfferCandidates`)

Read in full, traced by hand and cross-checked against the PR's own 8-scenario "Reconciliation" test group (all of which were re-run and pass in this session — see Tests below):

- Runs unconditionally on every `fromJson`, not gated on raw key presence/absence — confirmed the exact Codex PR #254 "key present ≠ migrated" gap is closed: a present-but-stale `offerCandidates` key (candidate stuck at `proposed` while the generic legacy path advanced the same engineer) is correctly upgraded on next load.
- **Never rewinds**: the upgrade branch only fires when `_offerCandidateStageRank(legacyStage) > _offerCandidateStageRank(current.stage)` AND `current.stage != declined` — verified by reading the exact guard, and by a direct test ("reconciliation never rewinds a candidate that is already AHEAD of legacy authority").
- **Never resurrects a decline**: `declined` candidates are structurally excluded from the upgrade branch's rank comparison (guarded separately) — verified by test and by code reading; legacy authority advancing arbitrarily far afterward never flips a `declined` candidate back to live.
- **Never loses an interview result**: every upgrade path (`upgradeFromLegacy`) preserves the candidate's own existing `partnerScore`/`clientScore` via `?? this.field` inside `copyWith` when the newly-derived legacy value is `null` for that leg — traced through `copyWith`'s implementation directly, not merely trusted from the doc comment.
- **Never rewinds an `ordered` sibling incorrectly**: when the reconciled/synthesized candidate for the one project legacy authority resolves to reaches `ordered`, every *other, live* sibling candidate for the same engineer (and only that engineer) is declined in the same reconciliation pass — verified by direct test ("an ordered engineer with a lagging live sibling candidate for a DIFFERENT project").
- **Does correctly follow legacy authority's progression**: every `PublicDemoSalesStage` value (including `introduced`→`proposed` and both `*Failed` legs, genuinely new coverage beyond Phase 1a's original `relevantStages`) maps 1:1 via `_legacyOfferCandidateStageFor` — confirmed exhaustive over the enum (a `switch` with no default branch, meaning the compiler itself would catch an added `PublicDemoSalesStage` value left unmapped).
- **Does not treat "offerCandidates key present" as "fully migrated"**: confirmed structurally — the reconciliation function receives whatever `existing` list was already decoded (`[]` for an absent key) and treats it identically to a present-but-incomplete one; there is no separate "already migrated" flag anywhere in this code path.
- **Idempotency**: `save → load → reconcile → save → reload` produces a byte-identical second result — verified by direct test AND by manually reasoning through why (every upgrade/decline in the reconciliation body is itself a no-op once already applied, since `upgradeFromLegacy` compares only against the CURRENT session's ranks, not a separate flag, and re-running finds nothing left to upgrade or decline).

No defect found in `_reconcileOfferCandidates` itself. The one defect this review found (below) is in a *different* candidate-creation path (`withMatchingProposal`) that reconciliation's own correctness does not cover.

## Save / security review

- `PublicDemoSaveCodec._withMigratedOfferCandidates`'s unconditional (not absence-gated) splice is a deliberate, well-justified, and correctly-scoped exception to this file's own per-field strict-round-trip convention — confirmed the accompanying doc comment's reasoning is accurate by re-deriving it independently: reconciliation is a real, repeatable content change, so gating the splice on key-absence (like every other field) would make the codec reject a save merely because reconciliation upgraded something the raw envelope already had a (stale) value for.
- `_hasConsistentAuthorityFacts`'s new checks — duplicate `(engineerId, projectId)` rejected, unknown `engineerId` rejected, an `ordered` candidate's own engineer must itself be genuinely `ordered`, a `clientInterviewPassed`/`ordered` candidate's `interviewRecord` identity must match its own pair AND `clientScore >= 60` — were each traced by hand against the actual evaluator's real score floor (`PublicDemoInterviewEvaluator`'s `passed = score >= 60`) rather than trusted from the doc. All correct.
- Verified via the PR's own test ("a raw save asserting `stage: ordered` on a candidate whose OWN engineer is not itself genuinely ordered is rejected") — re-ran, passes.
- **Forged states checked** (mapping to the review brief's own list): forged ordered candidate (rejected — engineer-stage cross-check), forged interview pass with no record (never orderable — `hasGenuineInterviewRecord` re-checked independently at every mutation site), mismatched engineer/project (structurally impossible — `id` is a derived getter, never stored/settable), unknown engineer (rejected, two independent layers: `fromJson` + `_validateForPersistence`), unknown project (documented as intentionally unchecked at persistence time — Public Demo has no closed project registry, consistent with the identical, pre-existing choice for `matchingProposals.projectId`), duplicate composite key (rejected, two independent layers), stale interview record (rejected — identity mismatch check on load), candidate ordered while its own engineer is not (rejected), candidate/matching-proposal mismatch for a *historical* (already-superseded) ordered cycle (deliberately tolerated — correctly reasoned as a legitimate multi-cycle save, not a forgery, in the PR's own self-hardening finding #2/#3, independently re-verified here), legacy save (round-trips, re-verified), partially-migrated save (the entire point of `_reconcileOfferCandidates` — re-verified), `offerCandidates` key present but stale (the headline fix this PR makes — re-verified), repeated load reconciliation (idempotency — re-verified).
- One theoretical, currently-**unreachable** dual-authority shape was identified and is worth flagging for Phase 1C's own hardening pass rather than blocking this PR: a `declined` candidate for the exact `(engineerId, projectId)` pair that legacy authority currently resolves to `ordered` is not proactively caught by either reconciliation (declines are deliberately never touched, by design) or `_hasConsistentAuthorityFacts` (which only checks the reverse direction — an `ordered` candidate needs its engineer to be ordered, not that an engineer being ordered needs its resolved candidate to not be declined). This is unreachable today because the only method that could produce it (`declineOfferCandidate`) has zero UI call sites (confirmed by grep) and no real production path ever auto-declines the *same* project's own candidate as a "sibling" of itself. Becomes relevant only once Phase 1C exposes a manual decline action — flagged here so that implementer does not have to rediscover it.

## P0/P1 Finding (found, root-caused, and fixed this session)

### P1 — `withMatchingProposal` fraudulently seeds a brand-new offer candidate at an UNRELATED project's already-earned interview stage/score, letting it skip its own mandatory interview step(s)

**Where:** `lib/game/public_demo/public_demo_workflow_state.dart`, `withMatchingProposal` (candidate-creation branch, Phase 1b Scope A).

**Mechanism:** When a brand-new `(engineerId, projectId)` candidate is created because none exists yet for that pair, the code seeds it via `_offerCandidateFromLegacy(engineer, projectId, proposedMonth, legacyStage: _legacyOfferCandidateStageFor(engineer.stage) ?? proposed)` — i.e. directly at the engineer's **current** coarse `PublicDemoEngineerSales.stage**, carrying over `partnerScore`/`clientScore` from `engineer.lastInterviewScore`. This is correct ONLY when this is the engineer's first-ever candidate (the coarse scalar can only then be attributed to this one project). It is **incorrect** the moment the engineer already has a genuine, real interview result recorded via a *different* project's candidate: the coarse scalar reflects that OTHER project's outcome, not this brand-new one's.

**Reachable via completely normal production gameplay — not a forged save:**

1. Propose engineer A for project 1 (`proposeMatch`).
2. Run the real interactive Partner Interview to a genuine pass for project 1 (`startPartnerInterview`/…/`concludePartnerInterview`). `engineer.stage` → `partnerInterviewPassed`, `candidate(A,1)` → `partnerInterviewPassed` (correct, genuine).
3. Propose the **same** engineer A for a **different**, never-interviewed project 2 (`proposeMatch`) — allowed by `withMatchingProposal`'s own guard, which only blocks `clientInterviewPassed`/`ordered`, not `partnerInterviewPassed`/`partnerInterviewFailed`/`clientInterviewFailed`. This also matches the real Matching-screen eligibility rule (`availableEngineersForMatching` excludes only `clientInterviewPassed`/`ordered`), so this is reachable through the actual UI, not just internal aggregate calls.
4. `candidate(A,2)` is created **already at `partnerInterviewPassed`**, with `partnerScore` copied from project 1's genuine score — even though **no partner interview was ever conducted for project 2**. The player can now go straight to a Client Interview for project 2, paying zero additional sales-slot cost for a leg (project 2's own partner interview) that was never actually attempted.

**Confirmed by direct reproduction** (not merely reasoned about): a standalone test built for this review (`test/game/public_demo/public_demo_parallel_sales_offer_candidate_seed_isolation_test.dart`) drove the exact sequence above through the real `PublicDemoAggregate.proposeMatch`/interactive interview API and observed `candidateB.stage == PublicDemoOfferCandidateStage.partnerInterviewPassed` with a copied-over `partnerScore`, confirming the leak before any fix.

**Why this matters:** this directly contradicts the PR's own stated invariant ("no forked engine... syncs the SAME already-computed outcome, never a second evaluation") and Issue #257's own explicit requirement ("partner pass/failをcandidate単位で保持", "既存engineと同一結果をcandidateへ同期しているか"): candidate 2's "result" here is not project 2's own result at all, it is project 1's, misattributed. It also undermines "二重評価していないか" from the opposite direction — not a double evaluation, but a **missing mandatory evaluation** silently waived. It is exactly the "1 engineer: project A pass, project B pass" scenario the review brief's Multiple-candidates section asks to verify — and under the pre-fix code, project B never gets its OWN genuine partner-interview pass at all; it inherits A's.

**Severity:** P1 (merge blocker per the task's own rubric) — reachable via completely ordinary "propose a second project" gameplay (arguably the single most natural way a player would exercise this whole feature), not merely a forged/edge save; bypasses a mandatory game step and its sales-slot cost; corrupts the "genuine per-candidate interview" invariant this entire Phase exists to establish.

### Fix applied (this session, same PR branch)

`withMatchingProposal`'s candidate-creation branch now only inherits the engineer's current legacy stage/score when this is the engineer's **first-ever** offer candidate (`offerCandidatesForEngineer(engineerId).isEmpty`) — the one case where the coarse scalar is unambiguously about the project being proposed, since nothing else has been proposed for this engineer yet to attribute it to instead. Every later sibling candidate (second, third, … project) now always starts fresh at `PublicDemoOfferCandidate.propose` (bare `proposed`), regardless of the engineer's current coarse stage.

This preserves the original self-hardening fix Phase 1B's own report documents (an engineer who advanced via the legacy, project-agnostic `recordEngineerInterviewResult` path *before ever being proposed to any project* still gets correctly seeded at their real current stage on that first proposal) while eliminating the cross-project leak for every subsequent proposal.

Diff (`lib/game/public_demo/public_demo_workflow_state.dart`):

```diff
       offerCandidates: offerCandidateFor(engineerId, projectId) != null
           ? offerCandidates
           : [
               ...offerCandidates,
-              _offerCandidateFromLegacy(
-                engineer: engineer,
-                projectId: projectId,
-                proposedMonth: month,
-                legacyStage:
-                    _legacyOfferCandidateStageFor(engineer.stage) ??
-                    PublicDemoOfferCandidateStage.proposed,
-              ),
+              offerCandidatesForEngineer(engineerId).isEmpty
+                  ? _offerCandidateFromLegacy(
+                      engineer: engineer,
+                      projectId: projectId,
+                      proposedMonth: month,
+                      legacyStage:
+                          _legacyOfferCandidateStageFor(engineer.stage) ??
+                          PublicDemoOfferCandidateStage.proposed,
+                    )
+                  : PublicDemoOfferCandidate.propose(
+                      engineerId: engineerId,
+                      projectId: projectId,
+                      proposedMonth: month,
+                    ),
             ],
```

A focused regression test was added: `test/game/public_demo/public_demo_parallel_sales_offer_candidate_seed_isolation_test.dart` — drives the real production sequence above via the seeded interactive engine (same style as the PR's own `public_demo_parallel_sales_phase1b_test.dart` fixtures) and asserts candidate B starts at `proposed`. Confirmed **failing** before the fix (reproducing the bug) and **passing** after.

## P2 finding (not fixed this session — documented, scope decision left to the user)

### P2 — Issue #257's own "必須" `projectInterviewSessions` composite-key widening is not implemented, and the Phase 1B Result Report does not mention this as a deferred item

Issue #257, section "PR #256 Review Carry-over — SELECTED CHANGES ONLY → A. `projectInterviewSessions` composite-key widening", marks widening `projectInterviewSessions` from `employeeId`-only to `(employeeId, projectId)` as **必須** ("同一engineerで複数projectのinteractive interview sessionが共存できる"), and Issue #257's own Verification section lists "same engineer × two projects can hold two in-flight sessions concurrently" as a required scenario.

Confirmed by direct code reading: `projectInterviewSessionFor`/`startProjectInterviewSession` in `public_demo_workflow_state.dart` are **completely unchanged** by this PR — sessions remain keyed by `employeeId` alone, replaced (not kept alongside) whenever a new session starts for the same engineer, regardless of project. Practically: if a player starts an interactive Partner or Client Interview for project A, then (before finishing A's session) switches Matching focus to project B and starts an interview there too, A's in-progress, unanswered session is silently discarded — not merely "paused."

**Why this is P2, not P1/blocker, in this reviewer's judgment:** Phase 1C (the comparison UI that would let a player actually see/act on multiple concluded candidates) is explicitly out of scope for this PR and remains unimplemented — no screen currently lets a player even attempt to juggle two concurrent in-flight interview sessions today, so this gap has **zero current player-facing impact**. It also does not corrupt any data or authority: a CONCLUDED interview result is still synced correctly and independently per `(engineerId, projectId)` candidate (verified above); the only loss is in-progress, unanswered session state for whichever project isn't currently "focused," which is itself the exact same self-healing "transient, not data loss" pattern the PR's own self-hardening findings use elsewhere.

**Recommendation:** this should be explicitly recorded as a known limitation in the Phase 1B Result Report (it currently is not mentioned there at all, silently, rather than being called out as intentionally deferred) and picked up either as a small, focused Phase 1B follow-up or bundled into Phase 1C's own work (which will need genuine concurrent interviewing to be fully useful). Not treated as a merge blocker for this PR given the zero-current-impact reasoning above — but flagged clearly so it is not lost.

## Interview authority review

- Caller cannot forge capability: the only production entry points into candidate interview evaluation (`concludePartnerProjectInterview`/`concludeProjectInterview`) apply an **already-computed** outcome derived from `PublicDemoProjectInterview.conclude` (real runtime/project/session state), never accept a caller-supplied `passed`/`score` from outside the engine. The Phase 1a "building block" methods that DO accept caller-supplied `profile`/`actualCapability` (`evaluatePartnerInterviewForCandidate`/`evaluateClientInterviewForCandidate` at the `PublicDemoWorkflowState` level) are confirmed (via grep) to have zero `lib/ui/` call sites — the safe `PublicDemoAggregate`-level wrappers (which derive from authoritative state and charge real slots) exist but are also unwired to any UI, matching the Result Report's own claim.
- Same engine reused, not forked: `concludePartnerProjectInterview`/`concludeProjectInterview` call `PublicDemoProjectInterview.conclude` exactly once and apply the SAME result object to both the engineer-level and candidate-level state in the same `_copyWith` — confirmed no second call, no duplicated RNG consumption.
- Sales-slot semantics: confirmed by direct test re-run — partner interview consumes exactly one slot on a genuinely new attempt, resuming an in-progress session never double-charges, client interview consumes zero additional slots, and capacity-exhausted is a total no-op (verified: neither `salesUsed` nor the candidate's own stage changes).
- Double-conclude/retry safety: every candidate transition method is precondition-gated on the *current* stage (never a caller-asserted one) and is a no-op otherwise — confirmed by reading every method (`evaluatePartnerInterview`/`evaluateClientInterview`/`applyPartnerInterviewResult`/`applyClientInterviewResult`/`markOrdered`/`decline`) and by the PR's own "double order / retry is safe" test, re-run and passing.
- Stale session / wrong project ID rejection: unchanged, pre-existing Codex P1/P2 guards (`session.projectId != project.id`, `session.startedWeek != currentMonth`) still gate both `concludeProjectInterview` and `concludePartnerProjectInterview` — confirmed present, unmodified.
- **The one genuine interview-authority defect found in this review is the P1 cross-project leak above** — everything else in this section checks out.

## Order review

- `recordOrder(engineerId)`'s candidate-aware cutover resolves the ordered project strictly from the engineer's own (locked) `matchingProposalFor`, never a caller-supplied project id — confirmed no UI/API surface for a caller to name an arbitrary project to order.
- Sibling live candidates (`proposed`/`partnerInterviewPassed`/`clientInterviewPassed`) for the same engineer are declined atomically in the same `_copyWith` call as the order — confirmed by direct test re-run ("ordering the passed candidate marks THAT candidate ordered and declines every other live sibling, atomically").
- Failed/declined candidates can never be ordered — `markOrdered`'s precondition requires `clientInterviewPassed` + genuine record, checked independently of the caller.
- Duplicate order (double-tap/retry) is a verified no-op (re-run test: "double order / retry is safe").
- `ordered != assigned`: confirmed by direct test re-run — `recordOrder`'s candidate mutation never appends to `assignments`; only `assignOrderedForMay`/`closeApril`'s downstream materialization does.
- Assignment authority is not pre-empted: `assignOrderedForMay`/`recoverLateYearAssignment` remain byte-identical and still gate exclusively on the legacy `stage`/`hasGenuineInterviewRecord`, never on `offerCandidates`.

## Multiple-candidates scenario verification

- 1 engineer / project A pass / project B pass, independently retained: **confirmed working correctly, once the P1 fix above is applied** — before the fix, project B's "pass" was not genuine (inherited from A). The PR's own test for this exact scenario (`public_demo_parallel_sales_phase1b_test.dart`, "two projects for the same engineer hold independent partner/client results") does not actually exercise the vulnerable path, because it uses the Phase 1a building block `proposeOfferCandidate` for project B instead of the real production `proposeMatch` — this is why the PR's own 977-test suite did not catch the bug this review found.
- A order → B decline: confirmed via re-run tests.
- A fail / B pass, A decline / B order, save/reload mid-sequence, month-boundary mid-sequence: all covered by the PR's own reconciliation test group, independently re-verified by re-running them in this session.
- Replacement sales: confirmed untouched (`PublicDemoReplacementStage`/`public_demo_assignment.dart` — zero diff).

## Regression review

- HOME: zero diff under `lib/ui/public_demo/public_demo_home_*` (confirmed: diff stat lists only `lib/game/public_demo/*`, `lib/game/persistence/*`, docs, and the new test).
- Finance/Payroll: zero diff (no `PublicDemoRevenue`/payroll file touched).
- Matching/Interview formulas: zero diff to `PublicDemoInterviewEvaluator`, `ClientInterviewEngine`, `ProjectInterviewEngine`, `PublicDemoMatchingFit`.
- `salesCapacity` semantics: unchanged mechanism, confirmed via re-run slot-consumption tests.
- April→March progression / month close: `assignOrderedForMay`/`recoverLateYearAssignment` byte-identical (confirmed above); existing month-boundary/full-suite tests re-run green.
- Existing single-project gameplay: the legacy, project-agnostic generic order path (no proposal at all) still succeeds at the engineer level with the candidate list correctly left empty — re-verified via re-run of the PR's own dedicated test for this.

## Tests (this session, run from a fresh Flutter 3.47.4 install, not copied from the PR's own report)

- `flutter analyze` (whole project): **No issues found** (after removing an unused import from this review's own new test file during iteration).
- `flutter test test/game/public_demo`: **978/978 passed** (977 pre-existing/PR-added + 1 new focused regression test from this review). Re-run AFTER the P1 fix — all pass, zero regression from the fix.
- `flutter test test/ui/public_demo`: **741/741 passed** — zero UI regression, confirmed by actually executing the suite (not assumed from "no `lib/ui/` file touched").
- `git diff --check` (against the original PR diff, base→original HEAD): clean.
- Reproduction test confirmed FAILING before the fix, PASSING after (see P1 finding above).

## Remaining known limitations (carried over from the PR's own report, independently re-verified as accurate, not re-litigated)

- Phase 1C comparison UI: unimplemented, as scoped.
- `availableEngineersForMatching` still gates on the coarse engineer scalar, not candidate authority — by design, deferred to Phase 1c.
- The generic, project-agnostic `recordEngineerInterviewResult` path remains uncut-over (no project identity to sync against) — unchanged, correctly documented.
- Declined-vs-legacy-advance: a manually `declined` candidate is never resurrected even if legacy authority later advances past it — deliberate, unchanged.
- Full ordered-project cross-check across historical order cycles: considered and correctly declined by the PR's own self-hardening reasoning, independently re-verified as sound in this review.

### New known limitations from this review

- **`projectInterviewSessions` composite-key widening (Issue #257's own "必須" item) is not implemented** — see P2 finding above. Zero current player impact (no UI to exercise it yet), but should be recorded explicitly and picked up before/alongside Phase 1C.
- The theoretical `declined`-candidate-vs-`ordered`-legacy dual-authority shape noted in the Save/security review above — unreachable today, worth a save-codec hardening pass once Phase 1C exposes manual decline.

## Phase 1C readiness

With the P1 fix applied, `offerCandidates` is now a genuinely trustworthy, per-project authority for every project a player actually proposes through the real production UI — Phase 1C's comparison screen can safely read it as-is. The one prerequisite Phase 1C (or an explicit sub-phase before it) still needs, per Issue #257's own original scope, is the `projectInterviewSessions` composite-key widening (P2 finding above) — without it, a player cannot productively juggle two *in-progress* interview sessions at once, even though concluded results for multiple projects now correctly coexist.

## FINAL VERDICT

**READY** (with the P1 fix in this session's final commit applied and merged as part of PR #258; the P2 session-widening gap does not block, given zero current player-facing impact with Phase 1C unshipped, but must be tracked and closed before or alongside Phase 1C).
