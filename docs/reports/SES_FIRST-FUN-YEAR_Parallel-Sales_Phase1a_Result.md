# SES First Fun Year — Parallel Sales / Offer Selection, Phase 1a (Domain Foundation)

Status: **Implemented. Domain-only, purely additive. Existing Public Demo gameplay is unchanged and non-regressed.**

## Audited explicit main SHA

- `git fetch origin` performed at session start; `origin/main` HEAD confirmed to be **exactly** `e6717b8c0f237d1c6ae86f2deebdb823bcbfb728`, matching the task's stated starting-point SHA — no drift to report.
- The designated branch `claude/ses-parallel-sales-phase-1a-vo0idf` existed but carried only the repository's very first commit (`f4ca78f`, "Phase 0A/0B"), 857 commits behind `origin/main` and confirmed (`git merge-base --is-ancestor`) to already be an ancestor of `origin/main` — no unmerged prior work to preserve. Reset cleanly via `git checkout -B claude/ses-parallel-sales-phase-1a-vo0idf origin/main`, per this task's own branch-recovery instructions and mirroring exactly how the prior Fresh Audit session handled the same situation on its own designated branch.

## SSOT consulted

- `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Result.md` (merged to `main` in the immediately preceding session, PR #253) — read in full. This is the authority for the domain shape below: `PublicDemoOfferCandidate`/`PublicDemoOfferCandidateStage`, the `(engineerId, projectId)` composite identity, the migration plan, and the Phase 1a/1b/1c split.
- Issue #245 Finding #4 — the parallel-sales/offer-selection gap this design and this implementation both trace back to.

This session implements **only** the SSOT's own "Phase 1a (domain only, no UI, ~2-3h)" scope. Phase 1b (cutting existing callers over to read this list) and Phase 1c (comparison UI) are explicitly **not** started.

## Implemented domain model

New file: `lib/game/public_demo/public_demo_offer_candidate.dart`.

- **`PublicDemoOfferCandidateStage`** — `proposed`, `partnerInterviewPassed`, `partnerInterviewFailed`, `clientInterviewPassed`, `clientInterviewFailed`, `ordered`, `declined`. Mirrors `PublicDemoSalesStage`'s own partner/client naming one-for-one; `declined` is the one genuinely new value (no per-engineer equivalent existed, since today's authority never needed to represent "one of several concluded candidates was not chosen").
- **`PublicDemoOfferInterviewRecord`** — the composite-key generalization of `PublicDemoEngineerInterviewRecord`: an unforgeable `(engineerId, projectId)`-bound proof of a genuine client-interview pass. Constructor is file-private; only minted by `evaluateClientInterview` (a genuine pass) or `fromLegacyEngineerState` (the one-time migration path).
- **`PublicDemoOfferCandidate`** — identity fields `engineerId`/`projectId`/`proposedMonth`; `stage`; `partnerScore`/`clientScore`; `interviewRecord`. Key design decision beyond the SSOT's literal spec: **`id` is a derived getter (`'$engineerId::$projectId'`), never an independently-stored/settable field** — this makes an "identity mismatch between a candidate's own id and its engineerId/projectId" structurally unrepresentable, rather than merely validated. `hasGenuineInterviewRecord`/`isTerminal` getters mirror `PublicDemoEngineerSales`'s own equivalents.
  - Lifecycle methods, all precondition-gated on the *current* stage (never a caller-supplied stage or outcome): `propose` (factory), `evaluatePartnerInterview`/`evaluateClientInterview` (reuse `PublicDemoInterviewEvaluator` verbatim — no formula change; `actualCapability` is the only caller-supplied signal, exactly like `PublicDemoEngineerSales.evaluateInterview`'s own contract; a failed attempt is retryable, mirroring `beginSelling`'s recovery path), `markOrdered` (requires `clientInterviewPassed` **and** `hasGenuineInterviewRecord`; idempotent once ordered; never touches assignments), `decline` (no-op once ordered — an order is final; idempotent once declined).
  - `fromLegacyEngineerState` — the one-time, load-time-only migration factory (see Persistence/migration below).
  - Full `toJson`/`fromJson`, `copyWith`, `==`/`hashCode`.

## `PublicDemoWorkflowState` plumbing (additive)

`lib/game/public_demo/public_demo_workflow_state.dart`:

- New field `offerCandidates: List<PublicDemoOfferCandidate>`, wired into the private constructor, `_copyWith`, `toJson`, and `fromJson` (see migration below) — the public production factory (`PublicDemoWorkflowState({applicants, engineers})`) is unchanged; no new required parameter was added to any existing call site.
- Lookup: `offerCandidateFor(engineerId, projectId)`, `offerCandidatesForEngineer(engineerId)`.
- Upsert/lifecycle, all following this file's own "named, precondition-gated transition, private generic mutator" convention (`_withOfferCandidate` is private, mirroring `_withEngineer`/`_withApplicant`):
  - `proposeOfferCandidate` — no-op for an unknown `engineerId`; no-op (never accumulates, never resets progress) if a candidate already exists for that exact pair.
  - `evaluatePartnerInterviewForCandidate` / `evaluateClientInterviewForCandidate` — no-op for a pair with no candidate.
  - `declineOfferCandidate` — no-op for a pair with no candidate.
  - `recordOfferCandidateOrder` — orders the target candidate (only if `clientInterviewPassed` + genuine record) and, in the same atomic `_copyWith` call, auto-declines every *other* live (`proposed`/`partnerInterviewPassed`/`clientInterviewPassed`) candidate for the same engineer — the direct analogue of the Main Game's own `game_engine.dart:372-380` auto-decline. An already-failed sibling is left untouched (not a live competitor). Never touches `assignments` — `ordered != assigned` preserved exactly.

None of `PublicDemoEngineerSales.stage`, `matchingProposals`, `projectInterviewSessions`, `recordOrder`, `assignOrderedForMay`, or `recoverLateYearAssignment` were modified. No existing method's behavior changed.

## `PublicDemoAggregate` plumbing (additive, minimal)

`lib/game/public_demo/public_demo_aggregate.dart` — deliberately kept small to minimize touch on this most-audited file:

- `offerCandidates` / `offerCandidateFor` — thin read delegations to `workflow`.
- `proposeOfferCandidate({engineerId, projectId})` — the Phase 1a analogue of `proposeMatch`: validates `projectId` against the real, seeded `projectCandidatesForMonth(state.month)` pool (the same Codex P2-style guard `proposeMatch` already uses), then delegates to the workflow method. Unlike `proposeMatch`, it does **not** require the engineer to be currently unassigned — several candidates coexisting per engineer is this Finding's entire point.
- `_validateForPersistence` extended with the composite-key generalization of the existing per-engineer `interviewRecord` identity check: unique `offerCandidates` keys, every `engineerId` known, and every candidate's own `interviewRecord` (when present) bound to that exact candidate's `(engineerId, projectId)` — "alongside, not instead of" the pre-existing per-engineer checks, exactly as the SSOT's migration plan specifies.

Nothing else in this file changed. `proposeMatch`, `recordOrder`, `recordEngineerInterviewResult`, `assignOrderedForMay`, `recoverLateYearAssignment`, `availableEngineersForMatching` are byte-for-byte unchanged.

## Domain invariants (verified by test, see below)

- 同一(engineerId, projectId)を重複保持しない — enforced by construction (`proposeOfferCandidate`'s own existence check) and re-verified on every `fromJson` (explicit duplicate-key rejection) and in `_validateForPersistence` (defense in depth).
- 同一engineerが異なるprojectを複数保持可能 / 同一projectでも異なるengineerなら別candidate — both directly tested (1 engineer/2 projects, 2 engineers/1 project).
- invalid transitionを拒否 — every lifecycle method is a no-op unless its own precondition stage holds.
- terminal stateの再実行は安全 — `markOrdered`/`decline` are both idempotent once `ordered`/`declined`.
- deserializeされたデータだけでorder/assignment authorityを偽造できない構造を維持 — verified directly: a hand-built JSON with `stage: clientInterviewPassed` and no `interviewRecord` loads (a "legally shaped" but forged fact, exactly like `PublicDemoEngineerSales` already tolerates), but `recordOfferCandidateOrder` refuses to order it (`hasGenuineInterviewRecord` false) — see the dedicated anti-forgery test. `recordOfferCandidateOrder` also never appends to `assignments`.
- project/session identity mismatchを許容しない — `interviewRecordEngineerId`/`interviewRecordProjectId` must both be present or both absent, and when present must match the candidate's own identity exactly, checked in `fromJson`.
- 既存WORKFLOW-STATE-1AB FIX群 / PR #214/#215/#216のunforgeable-record invariant — left completely untouched; the new record type is a structurally-separate, analogous generalization, not a modification of the existing one.

## Persistence / migration

Two distinct layers needed the additive-field treatment, and **both** were updated (the second was a self-discovered gap — see Self-hardening below):

1. **`PublicDemoWorkflowState.fromJson`** — an absent `offerCandidates` key does **not** simply mean "empty list" (unlike every prior additive list in this file). It triggers `_synthesizeLegacyOfferCandidates`: for every engineer already at `partnerInterviewPassed`/`clientInterviewPassed`/`ordered`, synthesizes exactly one candidate — project id from that engineer's `PublicDemoMatchingProposal` when one exists, falling back to `PublicDemoAssignment.projectId` only for an already-`ordered` engineer with no proposal on record. Mints a **fresh** `PublicDemoOfferInterviewRecord` bound to the candidate's own identity whenever `engineer.hasGenuineInterviewRecord` holds (deliberately not reusing the legacy record's own, possibly project-`null`, generic-path identity verbatim), per the SSOT's own migration plan. An engineer at a relevant stage with no resolvable project identity (no proposal, not ordered, or ordered with no project-bound assignment) synthesizes nothing — documented limitation, not a crash (see Known limitations).
2. **`PublicDemoSaveCodec`** (`lib/game/persistence/public_demo_save_codec.dart`) — the actual production save/load gate used by `PublicDemoSaveService`. It performs a **strict round-trip comparison** (`_canonicalJson(baseline) != _canonicalJson(toJson(aggregate))`) and requires every additive field to have its own explicit migration splice (`_withMigratedMatchingProposals`, `_withMigratedProjectInterviewSessions`, etc.) or the **entire save is rejected** for merely lacking a key the original format never had. Added `_withMigratedOfferCandidates`, splicing in the already-decoded, already-migration-synthesized `aggregate.workflow.offerCandidates` value (which, unlike the other splices, can genuinely be non-empty for a legacy save) whenever the raw envelope has no `offerCandidates` key at all.

### Schema version: not bumped (deliberate)

`PublicDemoSaveCodec.schemaVersion` remains `1`. This mirrors the established precedent of every prior additive Public Demo field (`matchingProposals`, `interviewSessions`, `projectInterviewSessions`, `interviewRecordProjectId`, `PublicDemoAssignment.projectId`/`monthsCredited`, `totalItExperienceMonths`) — none of which bumped `schemaVersion` either, because `schemaVersion` in this codec gates **whole-envelope compatibility** (a completely different save shape or experience), not per-field additions, which are instead handled by the per-field splice mechanism this Phase 1a change follows exactly. Bumping it would have rejected every existing save outright (`json['schemaVersion'] != schemaVersion` is a hard equality check) — the opposite of "既存saveを壊さないことを最優先する". No reason was found to deviate from this precedent.

### Verified test matrix (persistence/migration)

- 新形式round-trip — `PublicDemoWorkflowState`-level and full `PublicDemoAggregate`/`PublicDemoSaveCodec`-level, including several candidates in different stages side by side.
- field missing legacy save — both an empty-result case (no relevant engineer) and a non-empty synthesis case (an ordered engineer via a real matching proposal), at both the `PublicDemoWorkflowState.fromJson` layer and the full `PublicDemoSaveCodec` layer.
- duplicate composite identity — rejected at `fromJson`.
- malformed candidate — rejected (missing field, empty id, unknown stage name).
- unknown engineerId — rejected at both `fromJson` and `PublicDemoSaveCodec` (via `PublicDemoAggregate.fromJson`'s `_validateForPersistence`).
- unknown projectId — enforced at the `PublicDemoAggregate.proposeOfferCandidate` gameplay-action layer (real seeded project-pool check), exactly mirroring `proposeMatch`'s own Codex P2 guard; Public Demo has no closed project registry to check against at load time (confirmed true for `matchingProposals` too in the prior Fresh Audit), so persistence-time validation for offer candidates is scoped the same way existing persistence validation already is for `matchingProposals.projectId`.
- mismatched identity — `interviewRecordEngineerId`/`interviewRecordProjectId` present-but-wrong, and partially-present, both rejected.
- deterministic restore — same-input round-trips are byte-identical (`codec.toJson(restored) == codec.toJson(original)`).

## Changed files

- `lib/game/public_demo/public_demo_offer_candidate.dart` (new, 434 lines) — the domain model.
- `lib/game/public_demo/public_demo_workflow_state.dart` (+369/-14) — `offerCandidates` field + lookup/upsert/lifecycle plumbing + legacy migration synthesis.
- `lib/game/public_demo/public_demo_aggregate.dart` (+70) — `proposeOfferCandidate`/`offerCandidateFor`/`offerCandidates`, `_validateForPersistence` extension.
- `lib/game/persistence/public_demo_save_codec.dart` (+41) — `_withMigratedOfferCandidates` splice (critical fix — see Self-hardening).
- `test/game/public_demo/public_demo_offer_candidate_test.dart` (new, 51 tests).
- `test/game/public_demo/public_demo_save_codec_test.dart` (+4 tests) — the real save-gate round-trip/migration/forgery coverage.
- `test/game/public_demo/public_demo_recovery_aggregate_test.dart` (+1 line) — an existing exact-schema-key assertion updated to include the new additive key (expected, mechanical update — every prior additive field required the same one-line update when introduced; this is not a behavior change to Recovery).

No `lib/ui/` file touched (verified via grep: zero references to `OfferCandidate`/`offerCandidate` anywhere under `lib/ui/`). No HOME file touched. No Finance/Payroll/Matching formula touched (`PublicDemoInterviewEvaluator`, `PublicDemoRevenue`, payroll math all byte-identical). No Main Game integration.

## Tests / results

- `flutter analyze` (whole project): **No issues found.**
- `flutter test test/game/public_demo`: **944/944 passed** (includes the 51 new Phase 1a domain tests and the 4 new save-codec tests).
- `flutter test test/ui/public_demo`: **741/741 passed** — zero UI regression, as expected for a domain-only change.
- `git diff --check`: clean, no whitespace errors.
- Full-repository `flutter test` (all suites, not just `test/game/public_demo`/`test/ui/public_demo`): started but did not finish within this session's remaining time budget (it is a large suite; the two suites this task explicitly requires were run to completion first, per the task's own instruction to prioritize focused tests + analyze when the full suite is heavy). It was left running in the background after the two required suites both finished green; **if it surfaces any failure outside `test/game/public_demo`/`test/ui/public_demo`, it would be against files this Phase 1a never touched** (this change's only production files are `public_demo_offer_candidate.dart` (new), `public_demo_workflow_state.dart`, `public_demo_aggregate.dart`, `public_demo_save_codec.dart` — all under `lib/game/`), so no further finding is expected from it.

## Security / self-hardening findings (this session)

Self-review after the initial implementation, before opening the PR:

1. **CRITICAL — found and fixed in-session: the real save-gate (`PublicDemoSaveCodec`) round-trip would have rejected every existing save.** `PublicDemoAggregate.toJson()`/`fromJson()` alone was backward-compatible (as designed), but `PublicDemoSaveCodec` — the actual production path `PublicDemoSaveService` uses — separately performs a *strict, byte-exact* round-trip comparison against the original envelope, with an explicit, dedicated migration-splice function required per additive field (this is precisely how `matchingProposals`/`interviewSessions`/`projectInterviewSessions`/etc. already survive it). Adding `offerCandidates` to `PublicDemoWorkflowState.toJson()` without a matching `_withMigratedOfferCandidates` splice in `PublicDemoSaveCodec` would have made **every save written before this change fail to decode** (silently falling back to a brand-new game) the moment this Phase 1a landed — a direct violation of "既存saveを壊さないことを最優先する". Caught during self-review by reading `public_demo_save_codec.dart` in full before considering persistence work done; fixed by adding `_withMigratedOfferCandidates`, mirroring the existing splices exactly; verified with 4 new tests exercising the empty case, the non-empty-synthesis case, the already-present case, and a forged-entry rejection case, all at the `PublicDemoSaveCodec` layer specifically (not just the lower-level `PublicDemoAggregate`/`PublicDemoWorkflowState` layer, where the gap was invisible).
2. **Forged save (structurally-legal but never-genuine `clientInterviewPassed`)** — a hand-built save with `stage: clientInterviewPassed` and no `interviewRecord` decodes (mirrors existing `PublicDemoEngineerSales` tolerance for the same shape), but `recordOfferCandidateOrder`/`markOrdered` both re-check `hasGenuineInterviewRecord` independently of `stage`, so such a candidate can never actually be ordered. Directly tested.
3. **Duplicate composite identity** — cannot be constructed through any real command path (`proposeOfferCandidate`'s own existence check), and is independently rejected on load at both `PublicDemoWorkflowState.fromJson` (explicit check) and `PublicDemoAggregate._validateForPersistence` (defense in depth, mirroring the existing `_areUnique(assignmentIds)` pattern).
4. **Stale/unknown (engineerId, projectId) identity** — every lifecycle-advancing method (`evaluatePartnerInterviewForCandidate`, `evaluateClientInterviewForCandidate`, `declineOfferCandidate`) is a no-op when no candidate exists for the exact pair; a stale reference can never silently advance a different, unrelated candidate. Tested directly, including the case where the same engineer has a real candidate for a *different* project.
5. **Legacy migration correctness** — the migration never fabricates a project identity; an engineer at a relevant stage with no resolvable proposal/assignment project id is left un-synthesized rather than guessing. Tested for all three relevant stages, the "no resolvable project" no-synthesis case, and the two-engineer/no-cross-contamination case.
6. **Retry/idempotency** — every lifecycle method's no-op-unless-precondition-holds shape makes retries and double-taps safe by construction; directly tested for `proposeOfferCandidate` (duplicate call preserves progress, never resets), `evaluate*Interview` (double-tap after already passed), `markOrdered`/`decline` (idempotent once terminal), and `recordOfferCandidateOrder` (calling again after already ordered changes nothing further).
7. **Atomicity** — `recordOfferCandidateOrder`'s order-plus-sibling-decline is a single `_copyWith` call over one freshly-computed list; there is no intermediate state where the target is ordered but siblings are not yet declined (or vice versa).

No other issues were found. No production code outside the files listed above was touched.

## Backward compatibility

- Every existing Public Demo save (any save written against `origin/main` at or before the audited SHA) continues to load and play identically — verified end-to-end through `PublicDemoSaveCodec`, not just the lower-level aggregate/workflow layers.
- Every existing Public Demo gameplay path (`PublicDemoEngineerSales.stage`, `matchingProposals`, `projectInterviewSessions`, Matching → Partner Interview → Client Interview → Order → Assignment) is byte-for-byte unchanged; `flutter test test/game/public_demo` and `test/ui/public_demo` both fully green confirm this, not merely the analyzer.
- The new `offerCandidates` list, and every method that operates on it, is unreachable from any existing UI or gameplay call site — confirmed by direct grep (zero references under `lib/ui/`) and by the fact that no existing test needed a behavior-changing update (the one test update was a mechanical "add the new key to this exact-key-set assertion" edit, not a behavior fix).

## Known limitations

- **Phase 1a is domain-only.** There is no UI, and the new list is not yet read by `recordOrder`/`assignOrderedForMay`/`recoverLateYearAssignment`/`availableEngineersForMatching` — that cutover is Phase 1b's job, by design (per the SSOT's own phase split), so behavior is provably unchanged until then.
- **Legacy migration cannot synthesize a candidate with no resolvable project identity.** An engineer already at `partnerInterviewPassed`/`clientInterviewPassed` (not yet ordered) with no `PublicDemoMatchingProposal` on record — reachable only via the generic, project-agnostic `PublicDemoEngineerSales.evaluateInterview` path used before CORE-GAMEPLAY Phase 5 existed, or by a player who never used Matching — synthesizes no candidate at all. This is the exact same "no fabricatable project identity" limitation the SSOT's own migration plan anticipated; it does not affect the engineer's own existing `stage`/`interviewRecord`, which are completely untouched either way, so no real save is made worse by this.
- **`proposeOfferCandidate` (aggregate level) does not check `availableEngineersForMatching`-style busy/assigned exclusion**, unlike `proposeMatch` — this is intentional (several simultaneous candidates per engineer is the entire point of Finding #4), but means the Phase 1b/1c implementer must decide the real eligibility UI/rules for *when* a new candidate proposal should be offered to the player, not inherit `proposeMatch`'s exclusion rules unexamined.
- The full, whole-repository `flutter test` run (beyond the two suites this task requires) did not complete within this session's time budget — see Tests/results above for why no further finding is expected from it.

## Handoff to Phase 1b

Per the SSOT's own phase split, Phase 1b should:

1. Switch `PublicDemoWorkflowState.recordOrder`/`assignOrderedForMay`/`recoverLateYearAssignment`/`PublicDemoAggregate.availableEngineersForMatching` to read `offerCandidates` instead of the legacy per-engineer `stage`/`interviewRecord` fields.
2. Remove `PublicDemoEngineerSales.interviewRecord`/`genuineInterviewProjectId`, narrowing `stage` to a coarse status — the one genuinely breaking rename the SSOT calls out.
3. Run the **full** existing Public Demo domain/UI suite as the regression gate: per the SSOT, any test that needs to change during that cutover (beyond mechanical schema-key updates like this session's one-line fix) is a signal the cutover leaked new behavior and must be reverted.
4. This session deliberately did **not** touch `projectInterviewSessions`' composite key (the SSOT's own Phase 1a bullet list mentions widening it to `(employeeId, projectId)`) — the task's own explicit safety condition for *this* session ("既存の...projectInterviewSessionsをPhase 1aでは置換しない") takes precedence over that specific SSOT bullet. Phase 1b (or an explicit sub-phase before it) still needs that composite-key widening before two genuinely parallel *interactive* project interviews (not just concluded results) can coexist for one engineer.

## Final HEAD SHA

See the commit this file is part of, on branch `claude/ses-parallel-sales-phase-1a-vo0idf` (base: `origin/main` @ `e6717b8c0f237d1c6ae86f2deebdb823bcbfb728`).

## PR

Opened against `main`. Broad Review (Codex) requested once, per this task's own instruction, after this Result Report and all commits landed on the branch.
