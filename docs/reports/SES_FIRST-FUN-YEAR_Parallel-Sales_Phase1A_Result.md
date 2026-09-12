# SES First Fun Year — Parallel Sales Phase 1A: Offer Candidate Authority / Legacy Migration (Issue #255)

Status: **Complete — domain-only, additive. No UI/aggregate caller cutover (Phase 1B/1C deferred, as scoped).**

## Audited explicit main SHA

- `git fetch origin` performed at session start.
- `origin/main` HEAD confirmed exactly `e6717b8c0f237d1c6ae86f2deebdb823bcbfb728` (PR #253's merge commit) — the exact SHA Issue #255 itself names as its audited base. No drift.
- The designated branch `claude/issue-255-parallel-sales-phase1a-dbxknc` existed locally but only carried the repository's very first commit (`f4ca78f`, "Phase 0A/0B"), already an ancestor of `origin/main` (857 commits behind, 0 ahead) — no unmerged prior work to preserve. Reset to start cleanly from `origin/main` (`git reset --hard origin/main`).

## Governing documents read

- `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Result.md` (PR #253's Fresh Audit / Phase B design) — the design this implements.
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` (priority SSOT).
- PR #253's Codex review (2 threads): P1 "every legacy in-flight stage must migrate" and P2 "preserve the zero-slot client interview" — both addressed explicitly below.

## Scope actually implemented (Phase 1A only)

Per Issue #255's own scope, this session implemented **only**:

1. A new, purely additive `PublicDemoOfferCandidate`/`PublicDemoOfferCandidateStage`/`PublicDemoOfferInterviewRecord` domain model (`lib/game/public_demo/public_demo_offer_candidate.dart`, new file).
2. A new additive top-level list, `PublicDemoWorkflowState.offerCandidates`, with backward-compatible `toJson`/`fromJson`.
3. Load-time legacy migration (absent-key case) synthesizing candidates from the existing per-engineer scalar authority.
4. A full parallel (engineer, project)-keyed domain API (propose / partner interview start-conclude / client interview start-conclude / order-with-sibling-decline / decline) on `PublicDemoWorkflowState`.
5. `PublicDemoAggregate._validateForPersistence` extensions for the new list's identity invariants.

**Nothing in `PublicDemoAggregate`'s existing production methods or any UI screen was changed to call any of the new methods.** `PublicDemoEngineerSales.stage`/`interviewRecord` and every existing production call path (`recordOrder`, `recordEngineerInterviewResult`, `startPartnerInterview`, `startProjectInterview`, `concludePartnerInterview`, `concludeProjectInterview`, `assignOrderedForMay`, `recoverLateYearAssignment`, `availableEngineersForMatching`, `proposeMatch`, ...) are **byte-for-byte unmodified**. The two authorities coexist read-only side by side, exactly as the governing design's Phase split specifies — Phase 1B (caller cutover) and Phase 1C (comparison UI) are explicitly **not** implemented this session.

## Authority before / after

| | Before (legacy, unchanged) | After (new, additive, dormant) |
|---|---|---|
| Progress cursor | `PublicDemoEngineerSales.stage` — one scalar per **engineer** | `PublicDemoOfferCandidate.stage` — one scalar per **(engineer, project) pair** |
| Order/assign proof | `PublicDemoEngineerSales.interviewRecord` (`engineerId`, optional `projectId`) | `PublicDemoOfferCandidate.interviewRecord` (`engineerId` **and** `projectId`, both required, both identity-checked against the owning candidate) |
| Max concurrent projects per engineer | 1 (`matchingProposals`/`projectInterviewSessions` each replace the prior entry for that `employeeId`) | N (`offerCandidates` — at most one per `(engineerId, projectId)` pair, unlimited pairs per engineer) |
| Order → sibling handling | N/A (only one candidate ever existed) | `recordOfferCandidateOrder` atomically declines every other non-declined sibling in the same `_copyWith` call |

## Added model / state fields

- New file `lib/game/public_demo/public_demo_offer_candidate.dart`:
  - `enum PublicDemoOfferCandidateStage { proposed, partnerInterviewPassed, partnerInterviewFailed, clientInterviewPassed, clientInterviewFailed, ordered, declined }`
  - `class PublicDemoOfferInterviewRecord { engineerId, projectId }` — constructor private to the file; mintable only by `PublicDemoOfferCandidate.applyClientInterviewResult` (a genuine pass) or `.migrateFromLegacyStage` (reconstructing an already-proven legacy fact).
  - `class PublicDemoOfferCandidate { engineerId, projectId, proposedMonth, stage, partnerScore, clientScore, interviewRecord }` — `id` is derived (`'$engineerId::$projectId'`), never a separate persisted field.
- `PublicDemoWorkflowState.offerCandidates: List<PublicDemoOfferCandidate>` — additive field, `toJson`/`fromJson`/`_copyWith` wired through.
- New `PublicDemoWorkflowState` methods (all new, none replacing/modifying an existing method): `offerCandidateFor`, `offerCandidatesForEngineer`, `proposeOfferCandidate`, `offerInterviewSessionFor`, `startOfferInterviewSession`, `updateOfferInterviewSession`, `concludeOfferPartnerInterview`, `concludeOfferClientInterview`, `recordOfferCandidateOrder`, `declineOfferCandidate`, and the private `_migrateLegacyOfferCandidates`/`_withOfferCandidate` helpers.
- `PublicDemoAggregate._validateForPersistence` gained: `(engineerId, projectId)` uniqueness, per-candidate `interviewRecord` identity match, candidate→known-engineer existence, and "at most one genuinely `ordered` candidate per engineer" — all additive checks alongside the pre-existing per-engineer ones, never replacing them.

## Existing interview engine reuse (Issue requirement #9)

No fork. `concludeOfferPartnerInterview`/`concludeOfferClientInterview` call the **exact same** `PublicDemoProjectInterview.conclude`/`.start`/`.chooseFollowUp`/`.isReadyToConclude` (`ClientInterviewEngine`/`ProjectInterviewEngine` adapter) the legacy pipeline's `concludePartnerProjectInterview`/`concludeProjectInterview` already use — same `ClientInterviewSession` type, same shared `projectInterviewSessions` list. Only the **lookup/replace key** is generalized: new `startOfferInterviewSession`/`offerInterviewSessionFor`/`updateOfferInterviewSession` key by `(employeeId, projectId)` instead of `employeeId` alone, so two different projects' sessions for one engineer coexist in the same list — verified by a dedicated test (`two candidates for the same engineer can have genuinely parallel in-progress interview sessions at once`). The legacy single-key methods (`startProjectInterviewSession`, `projectInterviewSessionFor`, `updateProjectInterviewSession`) are completely untouched, so old-pipeline "resume, don't double-execute" behavior is provably unaffected.

## Legacy migration table

Migration runs in `PublicDemoWorkflowState.fromJson` **only** when the raw JSON has no `offerCandidates` key at all (a save written before this Phase); a save that already carries the key — including one this same code just wrote — never re-migrates (verified by the idempotency test below).

| Legacy `engineer.stage` | Proposal on file? | Genuine record? | Candidate synthesized | Candidate `stage` | `projectId` source |
|---|---|---|---|---|---|
| `waiting` / `skillSheet` | any | any | **No** — sales not started | — | — |
| `selling` | No | No | **No** — nothing project-specific decided yet | — | — |
| `selling` | Yes | No | Yes | `proposed` | proposal |
| `introduced` | No | No | Yes | `proposed` | **legacy compatibility placeholder** (`legacy-project-for-<engineerId>`) |
| `introduced` | Yes | No | Yes | `proposed` | proposal |
| `partnerInterviewPassed` / `partnerInterviewFailed` | Yes/No | No | Yes | mirrors legacy stage name | proposal, else placeholder |
| `clientInterviewPassed` | Yes/No | **Yes** (project-bound Phase 6 pass) | Yes | `clientInterviewPassed` | genuine record's own `projectId` (highest priority) |
| `clientInterviewFailed` | Yes/No | No | Yes | `clientInterviewFailed` | proposal, else placeholder |
| `ordered` | Yes/No | **Yes**, project-bound | Yes | `ordered` | genuine record's own `projectId` |
| `ordered` | No | **Yes**, generic (no project bound) | Yes | `ordered` | existing `PublicDemoAssignment.projectId` if one exists, else placeholder |

The explicit project-agnostic compatibility path (PR #253 Codex P1) is `PublicDemoOfferCandidate.legacyCompatibilityProjectId(engineerId)` → `'legacy-project-for-<engineerId>'`, a stable, non-`project-`-prefixed id that can never collide with a real `PublicDemoSeededProjectGenerator`-minted id (`project-<month>-<slot>`).

`lastInterviewScore` is carried forward into `partnerScore` (partner-stage outcomes) or `clientScore` (client-stage outcomes) as informational history — never used for any new authority check. `projectInterviewSessions` presence/absence has **no effect** on migration output (verified directly by test) — the old session list round-trips completely untouched, since it carries no authority the legacy engineer scalar/proposal/assignment facts don't already carry more directly.

## PR #253 P1/P2 review corrections applied

- **P1 (every legacy in-flight stage must migrate):** `_migrateLegacyOfferCandidates` now derives a candidate from every in-flight stage from `selling` (with a proposal) through `ordered` — not just saves with a `PublicDemoEngineerInterviewRecord`. Both the proposal-present and proposal-absent/project-agnostic cases are covered, with the explicit compatibility path for the latter. See the migration table above and the corresponding tests.
- **P2 (preserve the zero-slot client interview):** Verified directly against the current `origin/main` code (not the design doc's own now-corrected citation) that `PublicDemoAggregate.startProjectInterview` (client leg, lines ~713–729) is genuinely zero-slot, while `startPartnerInterview` (lines ~827–850) is the one that charges a slot — the design doc's citation of "907–922" was confirmed to actually be `recordPreEntryPartnerInterviewResult` (a different, applicant pre-entry pipeline), exactly as Codex's review stated. This Phase's new `concludeOfferClientInterview`/`startOfferInterviewSession`/`updateOfferInterviewSession` methods never reference `PublicDemoState` at all (`public_demo_workflow_state.dart` has no such dependency), so the client leg is zero-slot **by construction**, not by convention — confirmed by a dedicated test asserting `salesUsed` is unchanged after a full genuine client-interview flow driven purely through the new methods.

## Genuine order safety / `ordered != assigned`

- `recordOfferCandidateOrder` requires `candidate.stage == clientInterviewPassed && candidate.hasGenuineInterviewRecord` (identity-checked against both `engineerId` **and** `projectId`) — a fake/forged `stage` alone (verified by a direct test constructing a `clientInterviewPassed` candidate with no `interviewRecord`) cannot order.
- On success, every other non-declined candidate for the same `engineerId` is atomically declined in the same `_copyWith` call — verified by test, and re-asserted as a hard save-level invariant in `_validateForPersistence` ("at most one genuinely `ordered` candidate per engineer"), not merely a convention the mutator happens to follow.
- `recordOfferCandidateOrder` never appends to `workflow.assignments` — verified directly by test (`assignments` list identical before/after ordering). Materializing an actual assignment remains exclusively `assignOrderedForMay`/`recoverLateYearAssignment`'s job, both **completely untouched** by this Phase.
- Double-order / duplicate calls are idempotent (verified by test): calling `recordOfferCandidateOrder` again for an already-`ordered` candidate, or for a second candidate once one is already genuinely ordered for that engineer, is a no-op.
- `declineOfferCandidate` never operates on an already-`ordered` candidate (releasing an order back for re-sale is explicitly out of this Phase's scope).

## Zero-slot client interview verification

Confirmed both by code inspection (new client-leg methods never reference `PublicDemoState`) and by a dedicated test: a full genuine client-interview flow driven purely through `startOfferInterviewSession`/`updateOfferInterviewSession`/`concludeOfferClientInterview` leaves `PublicDemoState.salesUsed` at `0`.

## `ordered != assigned` verification

Confirmed by the dedicated `ordering never appends to workflow.assignments` test — `recordOfferCandidateOrder`'s only effect is on `offerCandidates`; `assignments` is provably identical before and after.

## Save compatibility

- Fully additive: absent `offerCandidates` key → migrated (never empty-and-lost) on load; present key → decoded, with duplicate `(engineerId, projectId)` pairs canonicalized (first occurrence wins) rather than rejecting the whole save.
- `save → load → migrate → save → reload` idempotency verified directly by test: a legacy save migrates once, the resulting JSON carries the `offerCandidates` key, and a second/third reload of that JSON reproduces the identical candidate set without re-migrating or duplicating.
- `PublicDemoAggregate._validateForPersistence` rejects (throws, forcing discard) only genuinely corrupt data that could not arise from any real code path in this Phase: a candidate naming an unknown engineer, an `interviewRecord` whose identity doesn't match its own candidate, or two genuinely `ordered` candidates for one engineer. A same-pair duplicate never reaches this layer at all — the workflow-level decode step canonicalizes it first (verified end-to-end through a full `PublicDemoAggregate.fromJson` in a dedicated test).

## Guardrails confirmed unchanged

- Finance/Payroll: no file under those areas touched.
- Matching score formula (`PublicDemoInterviewEvaluator`) / interview outcome formula (`ClientInterviewEngine`/`ProjectInterviewEngine`): not touched; the new methods call the identical existing functions.
- `salesCapacity` semantics: `PublicDemoState`/`salesUsed`/`salesCapacity` are never referenced by any new code in this Phase.
- HOME: no file under `lib/ui/public_demo/public_demo_home_*` touched.
- Main Game / Public Demo unification: none — no import from `lib/game/models/project_proposal.dart` or any Main Game type; `PublicDemoOfferCandidate` is its own, independent Public Demo type, per Issue #245/#255's own non-goal.
- 1-turn-1-week: not touched, not relevant to this Phase.

## Tests

- New: `test/game/public_demo/public_demo_issue255_offer_candidate_test.dart` — **35 tests**, covering: fresh-save parallel coexistence, duplicate-proposal idempotency, unknown-engineer no-op, independent partner pass/fail per project, genuine client-pass record minting, zero-slot verification, session resume/no-double-execution, two genuinely parallel in-progress sessions, order-with-sibling-decline, decline-then-order-a-different-sibling, forged-stage-cannot-order, double-order idempotency, `ordered != assigned`, one-engineer-never-two-ordered, save/reload round-trips (proposed and passed), duplicate-pair canonicalization, and the full legacy-migration matrix (every `PublicDemoSalesStage` from `waiting` through `ordered`, proposal present/absent, genuine record present/absent, project-bound vs. project-agnostic, assignment-fallback, session-presence-irrelevance, two-engineers-in-one-load, and full round-trip idempotency), plus `_validateForPersistence`'s new invariants (duplicate canonicalization end-to-end, forged interview-record identity rejection, double-ordered rejection, unknown-engineer rejection, and the well-formed-save acceptance paths).
- Existing: **1 pre-existing test updated** (`public_demo_recovery_aggregate_test.dart`, "Recovery introduces no new save-schema keys") — its exact workflow-JSON key-set assertion needed the new, intentionally-additive `offerCandidates` key added to the expected set (mirrors this same test's own existing pattern of listing each prior additive key with a comment explaining why it's there).
- `flutter analyze` (project-wide): **No issues found.**
- `flutter test test/game/public_demo` (full suite, including the new file and the one updated test): **924 tests, all passed.**
- `git diff --check`: clean.

## Final HEAD / PR

- Base: `origin/main` @ `e6717b8c0f237d1c6ae86f2deebdb823bcbfb728`.
- Branch: `claude/issue-255-parallel-sales-phase1a-dbxknc`.
- Final HEAD SHA and PR URL: see this session's final chat response (recorded after push/PR creation, which happens after this report is committed).

## Unresolved / Phase 1B+ items (explicitly deferred, per Issue #255 scope)

- **Phase 1B (caller cutover):** `PublicDemoAggregate`'s production methods (`proposeMatch`, `recordEngineerInterviewResult`, `startPartnerInterview`/`startProjectInterview`, `concludePartnerInterview`/`concludeProjectInterview`, `recordOrder`, `availableEngineersForMatching`, `assignOrderedForMay`, `recoverLateYearAssignment`) still read/write only the legacy `PublicDemoEngineerSales.stage`/`interviewRecord`/`matchingProposals`/`projectInterviewSessions` authority. The new `offerCandidates` authority is fully built and tested but **dormant** — nothing in production gameplay populates or reads it yet.
- **Phase 1C (comparison UI):** No UI screen exists yet for viewing/ordering among multiple parallel candidates.
- `PublicDemoEngineerSales.stage`'s narrowing to a coarse status (removing `interviewRecord`/`genuineInterviewProjectId`) — the one genuinely breaking rename the governing design calls out — is intentionally **not** done this Phase; the legacy scalar remains fully intact.
- A "release an already-ordered candidate back for re-sale" capability does not exist yet (`declineOfferCandidate` explicitly refuses an `ordered` candidate) — out of this Phase's scope per the Issue's own guardrails.
- Sibling-decline currently declines every non-declined candidate for the engineer, including ones already at `partnerInterviewFailed`/`clientInterviewFailed`; this is harmless (both are already non-order-eligible terminal-ish states) but Phase 1B should confirm this matches the eventual UI's own "残り" semantics.
