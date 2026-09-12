# SES First Fun Year — Parallel Sales Phase 1B (Production Cutover / Dual Authority Reconciliation)

Status: **Implemented, independently reviewed, and hardened. Production Public Demo sales/interview/order flow cut over to `(engineerId, projectId)` candidate authority, with real, repeatable legacy reconciliation, and `projectInterviewSessions` widened to the same composite key. Comparison UI (Phase 1C) is explicitly out of scope and remains unimplemented.**

## Audited explicit main SHA

- `git fetch origin` performed at session start; `origin/main` HEAD confirmed to be **exactly** `3dffd5c78b5c956dfc4f0804eb12887d17042eb1` (PR #254's own merge commit), matching Issue #257's own stated starting-point SHA — no drift to report.
- The designated branch `claude/first-fun-year-phase-1b-2zy73j` existed but carried no commits ahead of `origin/main` and was missing everything back through `f4ca78f` (857+ commits behind) — confirmed (`git log origin/claude/...-2zy73j..origin/main`) to be a stale leftover with no unmerged work. Reset via `git reset --hard origin/main`, mirroring this task's own branch-recovery instructions and every prior session's identical handling of the same situation.
- Governing docs read in full before any code change: `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Result.md` (Fresh Audit / design), `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Phase1a_Result.md` (Phase 1a domain foundation + its own Codex review responses), `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`, Issue #257, and PR #254's Codex review threads (all four findings and their resolutions).
- **Note on Issue #257 scope drift:** Issue #257's body was edited after this session's initial research pass (adding a "PR #256 Review Carry-over" section — PR #256 was an independent, since-closed duplicate implementation of PR #254's own Issue #255, whose reviewable ideas were selectively carried into Issue #257). The initial implementation and PR #258 did not reflect that addition. An independent Claude Broad Review session (see "Independent Broad Review" below) caught this gap directly from the then-current issue body and it was closed out in a follow-up commit on this same branch — see "PR #256 selected-change extraction summary" below.

## Independent Broad Review (Codex unavailable)

Per this task's own review policy ("実装 → Claude self-hardening → 一回だけの broad Codex review → P0/P1 + relevant P2 fixes"), a Codex Broad Review was requested on PR #258 but returned only a usage-limit notice — no actual review content. A separate Claude session then performed an **independent broad review** of PR #258 against the live repository (its own fresh Flutter install, not this session's numbers) and is the designated one-time substitute for the Codex review this task calls for. Its own report is `docs/reports/SES_PR-258_Parallel-Sales-Phase1B_Claude-Broad-Review.md`; it found and fixed one P1 (see below) directly on this branch, and flagged one P2 (`projectInterviewSessions` composite-key widening) which this session subsequently closed out as full scope (see below), not merely documented.

### P1 (found + fixed by the independent review, commit `e7996e2`)

`withMatchingProposal`'s candidate-creation branch fraudulently seeded a **brand-new** offer candidate at an unrelated project's already-earned interview stage/score whenever the engineer already held a genuine result for a *different* project — reachable via ordinary `proposeMatch(A) → interview → proposeMatch(B)` gameplay, not a forged save, and it let candidate B skip its own mandatory interview step and sales-slot cost. Fixed by restricting the "inherit legacy stage" behavior (`_offerCandidateFromLegacy`) to only the engineer's very **first-ever** candidate (`offerCandidatesForEngineer(engineerId).isEmpty`) — every later sibling candidate now always starts fresh at `proposed`, regardless of the engineer's current coarse stage. A dedicated regression test, `test/game/public_demo/public_demo_parallel_sales_offer_candidate_seed_isolation_test.dart`, reproduces the exact sequence and was confirmed failing before the fix, passing after.

## Authority before/after

### Before (post-Phase-1a, pre-Phase-1B)

- `PublicDemoWorkflowState.offerCandidates` existed as a purely additive, dormant list. **No production caller** (`proposeMatch`, `startPartnerInterview`/`concludePartnerInterview`, `startProjectInterview`/`concludeProjectInterview`, `recordOrder`) read or wrote it.
- The sole authority for real gameplay remained the coarse per-engineer scalar: `PublicDemoEngineerSales.stage`/`lastInterviewScore`/`interviewRecord`, together with the single-slot `PublicDemoMatchingProposal` and the single-session `projectInterviewSessions`/`ClientInterviewSession`.
- The only way `offerCandidates` ever gained content was `PublicDemoWorkflowState.fromJson`'s one-shot `_synthesizeLegacyOfferCandidates`, gated on the raw `offerCandidates` key being **entirely absent**. PR #254's own Codex review (finding #1, P1) had already identified that this gate can never fire again once any Phase-1a-era save writes a present (even empty) key — "key present" was never proof of "fully migrated". This was documented as a known limitation, explicitly left for Phase 1B to fix.
- An engineer could only ever pursue **one** project at a time in any way visible to the game (Matching excludes a `clientInterviewPassed`/`ordered` engineer from `availableEngineersForMatching` entirely).

### After (Phase 1B)

- `offerCandidates` is now a **live-synchronized mirror** of the real production sales/interview/order flow for every project a player actually proposes:
  - `PublicDemoAggregate.proposeMatch` → `PublicDemoWorkflowState.withMatchingProposal` now also creates/keeps the matching `(engineerId, projectId)` candidate, atomically.
  - The interactive Partner Interview (`startPartnerInterview`/`concludePartnerInterview`) and Client Interview (`startProjectInterview`/`concludeProjectInterview`) production flows now sync the same already-computed pass/fail outcome onto the matching candidate, atomically alongside the existing engineer-level update — **no second evaluation, no forked engine**.
  - `PublicDemoAggregate.recordOrder` → `PublicDemoWorkflowState.recordOrder` is now candidate-aware: it resolves the ordered project from the engineer's own (locked) `PublicDemoMatchingProposal`, marks that one candidate `ordered`, and atomically declines every other live sibling candidate for the same engineer — all in the same `_copyWith` call as the legacy engineer-level `stage: ordered` transition.
- `offerCandidates` reconciliation (`_reconcileOfferCandidates`) now runs **unconditionally on every `PublicDemoWorkflowState.fromJson` call** — whether the raw `offerCandidates` key is absent, present-and-empty, or present-and-stale — closing the exact Codex PR #254 finding.
- `PublicDemoEngineerSales.stage` remains the coarse, necessary-minimum compatibility layer this task's guardrail requires (`PublicDemoAggregate.recordOrder`/`assignOrderedForMay`/`recoverLateYearAssignment`/`availableEngineersForMatching` are all **unchanged**, still reading the legacy scalar) — nothing was deleted or narrowed. `offerCandidates` is the per-project authority layered alongside it, in lockstep by construction for the one project the coarse scalar currently/finally tracks.
- One engineer can now genuinely hold multiple, independently-progressing candidates across different projects simultaneously (verified by test — see below); ordering one atomically closes every other live one.

## Reconciliation strategy

Replaces Phase 1a's `_synthesizeLegacyOfferCandidates` (one-shot, key-absence-gated) with `PublicDemoWorkflowState._reconcileOfferCandidates` (always-on, present-or-absent-agnostic), invoked from `fromJson` before returning the decoded workflow.

For every engineer whose coarse `PublicDemoSalesStage` maps to a resolvable `PublicDemoOfferCandidateStage` (`_legacyOfferCandidateStageFor` — `waiting`/`skillSheet`/`selling` map to `null`, i.e. no committed project identity yet; every other stage, **including `introduced`→`proposed` and the two `*Failed` stages, which Phase 1a's original synthesis never handled at all**, maps 1:1) with a resolvable project id (that engineer's current `PublicDemoMatchingProposal`, or — only when already `ordered` with no proposal on record — the matching `PublicDemoAssignment.projectId`):

1. **No candidate yet for that exact pair** → synthesize one fresh, directly at legacy authority's current stage/score/record (`PublicDemoOfferCandidate.fromLegacyEngineerState`, unchanged from Phase 1a).
2. **A candidate already exists for that pair, and legacy authority's own stage genuinely outranks it** (`_offerCandidateStageRank`: `proposed` < `partner{Passed,Failed}` < `client{Passed,Failed}` < `ordered`) → **upgrade it in place** (`PublicDemoOfferCandidate.upgradeFromLegacy`) — this is the actual fix for the Codex-flagged staleness gap.
3. **A candidate already exists and is at least as advanced as, or is `declined`** → left **completely untouched**. `declined` is a deliberate, terminal, candidate-level decision legacy authority knows nothing about and must never resurrect, regardless of how far legacy authority later advances.
4. **Every other candidate this engineer holds, for every other project** → left completely untouched, unconditionally — legacy authority is a single scalar that can only ever speak to the ONE project it currently/finally resolves to; every sibling for a different project is exactly the multi-candidate state this Finding exists to preserve.
5. **If the reconciled/synthesized candidate for the one resolved project is now `ordered`** → every other **live** (`proposed`/`partnerInterviewPassed`/`clientInterviewPassed`) sibling candidate for the same engineer is declined in the same pass — the identical rule `recordOrder`/`recordOfferCandidateOrder` themselves encode live, so a legacy-`ordered` engineer reconciled for the first time can never leave a contradictory "ordered + still-live sibling" state behind.

`PublicDemoWorkflowState.withMatchingProposal` reuses the same `_offerCandidateFromLegacy` derivation for a **brand-new** candidate, seeding it at the engineer's current legacy stage (not always the bare `proposed` entry point) — this closes the one place a freshly-created candidate could otherwise start transiently one stage behind the very engineer it belongs to (an engineer who already passed/failed a partner interview through the legacy, project-agnostic path *before* this exact project was ever proposed), without waiting for the next save/reload's reconciliation pass to catch it up. `withMatchingProposal`'s own precondition already excludes `clientInterviewPassed`/`ordered` legacy stages from ever reaching this path, so it can never fabricate a client-pass or an order for a project never actually interviewed for.

**Idempotency**: a second reconciliation pass over its own output finds every resolvable candidate already at least as advanced as legacy authority (upgrade becomes a no-op) and every sibling already declined (decline is a no-op) — proven directly by test (save → load → reconcile → save → reload, second reload byte-identical to the first).

**Persistence round-trip**: `PublicDemoSaveCodec._withMigratedOfferCandidates` is the one deliberate exception to every other per-field splice in that file — it now **unconditionally** splices in the already-reconciled resolved value, rather than only when the raw key is absent. This is necessary because reconciliation is a real, repeatable content change that can differ from the raw envelope even when the key was already present — exactly the class of change the codec's strict byte-exact round-trip comparison exists to reject for every *other* field. `offerCandidates`' own integrity is instead enforced by `_hasConsistentAuthorityFacts` (raw-level: structural shape, duplicate/unknown-identity rejection, score-plausibility floor, and a new cross-check that an `ordered` candidate's own engineer must itself be genuinely `ordered`) and `PublicDemoAggregate._validateForPersistence` (post-decode: unique keys, known engineers, record-identity agreement) — both unchanged in strictness and still run on whatever the final reconciled value is.

## Production caller cutover map

| Legacy production entry point | Cutover |
|---|---|
| `PublicDemoAggregate.proposeMatch` → `PublicDemoWorkflowState.withMatchingProposal` | Also creates/keeps the `(engineerId, projectId)` candidate atomically (Scope A) |
| `PublicDemoAggregate.startPartnerInterview`/`concludePartnerInterview` → `PublicDemoWorkflowState.concludePartnerProjectInterview` | Also applies the same already-computed outcome to the matching candidate (Scope B) — reuses `PublicDemoProjectInterview.conclude`'s one call, no fork |
| `PublicDemoAggregate.startProjectInterview`/`concludeProjectInterview` → `PublicDemoWorkflowState.concludeProjectInterview` | Same, for the client leg (Scope C) — zero additional sales slot, unchanged |
| `PublicDemoAggregate.recordOrder` → `PublicDemoWorkflowState.recordOrder` | Candidate-aware: orders the one candidate matching the engineer's locked `PublicDemoMatchingProposal`, atomically declining every other live sibling (Scope D) |
| `PublicDemoAggregate.recordEngineerInterviewResult` (the legacy, project-agnostic generic path) | **Unchanged, deliberately not cut over** — no project identity exists to sync a candidate against; this is the same "no fabricatable project identity" limitation Phase 1a's own migration already documented |
| `PublicDemoWorkflowState.assignOrderedForMay`/`recoverLateYearAssignment`/`PublicDemoAggregate.availableEngineersForMatching` | **Unchanged** — reuse existing month-boundary/recovery/matching-eligibility authority verbatim, per this task's own instruction; `PublicDemoEngineerSales.stage`/`hasGenuineInterviewRecord` remain their gate |

No `lib/ui/` file was touched. Every cutover above lives entirely inside `PublicDemoWorkflowState`/`PublicDemoAggregate` methods the existing UI already calls with the exact same signatures — the production UI's own call sites (`proposeMatch`, `recordOrder`, `startPartnerInterview`/`_openProjectInterview`, `recordEngineerInterviewResult`) are unmodified and automatically pick up the cutover.

## PR #256 selected-change extraction summary

PR #256 was an independent, duplicate implementation of PR #254's own Issue #255, closed without merge (merge conflict + missing `SaveCodec` hardening). Issue #257 carries forward five selected ideas from its review; each is addressed here:

| Item | Disposition |
|---|---|
| **A. `projectInterviewSessions` composite-key widening** | **Implemented this session** (see "Session-keying verification" below) — `PublicDemoWorkflowState.projectInterviewSessionFor` is now keyed by `(employeeId, projectId)`, and `startProjectInterviewSession`'s replace logic only ever removes the entry for that exact pair, never a sibling project's session. `PublicDemoAggregate.projectInterviewSessionFor(engineerId)`'s public signature is unchanged (resolves the engineer's current proposal's project internally), so no UI/test call site needed to change. |
| **B. Existing interview engine reuse** | Already satisfied by the original cutover, re-verified after the widening: `concludeProjectInterview`/`concludePartnerProjectInterview` still call `PublicDemoProjectInterview.conclude` exactly once and apply the one result to both the engineer-level and candidate-level state — see "Existing interview-engine reuse verification" below. |
| **C. Re-apply PR #254 hardening when porting selected ideas** | Confirmed still intact: aggregate-level safe wrapper (`evaluatePartnerInterviewForCandidate`/`evaluateClientInterviewForCandidate` remain the only safe entry points, unwired to any UI), partner-only slot consumption, client zero-slot, `_hasConsistentAuthorityFacts` score/identity checks, and `_withMigratedOfferCandidates` save compatibility are all unchanged in strictness. |
| **D. Duplicate identity policy** | **Explicit decision: keep the current `main` reject-on-duplicate policy.** PR #256's "silently canonicalize a duplicate pair" idea was NOT adopted — `PublicDemoWorkflowState.fromJson` continues to throw a `FormatException` on a duplicate `(engineerId, projectId)` composite key in a raw save (verified by test), exactly as it already did before this Phase. |
| **E. Report SSOT** | Followed — Phase 1a's own report (`..._Phase1a_Result.md`) was not touched or duplicated; this Phase's own record is this file. |

## Session-keying verification (`(employeeId, projectId)`)

`projectInterviewSessions` (the interactive Partner/Client Interview session list) was widened the same way `offerCandidates` already was in Phase 1a: from a single `employeeId` key to a composite `(employeeId, projectId)` key.

- `PublicDemoWorkflowState.projectInterviewSessionFor(engineerId, projectId)` now matches both fields (previously `employeeId` alone, returning the first — and only ever — match).
- `startProjectInterviewSession`'s replacement logic now removes only the entry for the exact same `(employeeId, projectId)` pair — previously it discarded **every** entry for that `employeeId`, regardless of project, the moment any new session started.
- `updateProjectInterviewSession` and `concludeProjectInterview`/`concludePartnerProjectInterview` were **already** composite-key-aware (a pre-existing Codex P1/P2 defense-in-depth guard from PR #214) — only the lookup/replace half needed widening.
- `PublicDemoAggregate.projectInterviewSessionFor(engineerId)` keeps its exact existing single-argument public signature (every production/UI caller only ever needs "the session for whichever project is currently proposed") — it now resolves that project internally via `projectInterviewCandidateFor(engineerId)` and calls the widened workflow method. **Zero UI or test call-site changes were needed anywhere in the codebase** — confirmed by `flutter analyze` passing clean with no signature-mismatch errors across all 14 files that reference this method.
- Verified directly by test (`public_demo_parallel_sales_phase1b_test.dart`, "Session keying / engine reuse" group): the same engineer can hold two genuinely concurrent, independently-progressing in-progress Partner Interview sessions for two different projects through the real production API (`proposeMatch`/`startPartnerInterview`/`chooseProjectInterviewFollowUp`) — starting/advancing one never touches the other, and retrying a failed attempt for one project replaces only that project's own stale session.

## Existing interview-engine reuse verification

- `concludeProjectInterview`/`concludePartnerProjectInterview` each call `PublicDemoProjectInterview.conclude` (itself `ClientInterviewEngine.finalRate` + `ProjectInterviewEngine.roll`) **exactly once** per conclusion and apply that single result object to both the engineer-level (`applyProjectInterviewResult`/`applyPartnerProjectInterviewResult`) and candidate-level (`applyClientInterviewResult`/`applyPartnerInterviewResult`) state, in the same `_copyWith` call — confirmed by direct code reading, not merely by doc comment, both before and after the session-keying widening.
- `PublicDemoInterviewEvaluator`'s original generic formula (Phase 1a's own building-block `evaluatePartnerInterviewForCandidate`/`evaluateClientInterviewForCandidate`) was not replaced or forked; it remains the separate, still-unwired-to-UI generic path.
- No new RNG stream, no duplicated scoring formula, anywhere in this diff.

## Partner/client sales-slot verification

- Partner interview (interactive engine): exactly one real slot consumed on a genuinely new attempt at the `PublicDemoAggregate` layer — unaffected by whether a matching candidate exists to sync (test: "partner interview slot semantics").
- Resuming the same in-progress partner session never re-consumes a slot (test: "resuming the SAME in-progress partner interview session never double-consumes a sales slot").
- Client interview consumes **zero** additional sales slots, even though it now also syncs the candidate (test: "client interview consumes ZERO additional sales slots").
- Capacity exhausted → a partner interview attempt is a total no-op: neither `state.salesUsed` nor the candidate's own stage changes (test: "capacity exhausted...no partial mutation").
- The two standalone Phase 1a "building block" aggregate methods (`evaluatePartnerInterviewForCandidate`/`evaluateClientInterviewForCandidate`, added during PR #254's own Codex review response) are unchanged and still not wired to any production UI call site — confirmed by grep of `lib/ui/`.

## `ordered != assigned` verification

- `PublicDemoWorkflowState.recordOrder`'s candidate-aware cutover never appends to `assignments` — verified directly (`ordered.workflow.assignments` is empty immediately after `recordOrder`, and only becomes non-empty after a real `closeApril`/`assignOrderedForMay`/`recoverLateYearAssignment` call, exactly as before).
- `recordOfferCandidateOrder` (the standalone candidate-level building block `recordOrder` now composes the same rule from) likewise never touches `assignments`.

## Legacy save matrix (reconciliation test coverage)

All of the following are covered by `test/game/public_demo/public_demo_parallel_sales_phase1b_test.dart`'s "Reconciliation" group (in addition to Phase 1a's own still-green migration suite in `public_demo_offer_candidate_test.dart`):

| Scenario | Result |
|---|---|
| `offerCandidates` key **present but stale** (stuck at `proposed` while the generic legacy path advanced the engineer past it) | Upgraded on next load — the exact Codex PR #254 finding |
| Candidate already **ahead** of legacy authority for the same project | Never rewound |
| Candidate **declined** | Never resurrected, even as legacy authority later advances further |
| `introduced` engineer with a real proposal, no candidate yet | Synthesizes a `proposed` candidate — new beyond Phase 1a's original `relevantStages` |
| `partnerInterviewFailed` / `clientInterviewFailed` legacy stages | Both migrate to their matching candidate stage — new beyond Phase 1a's original scope |
| Legacy `clientInterviewPassed`/`ordered` with a matching proposal (project-specific) | Synthesizes correctly (Phase 1a coverage, still green) |
| Legacy `ordered` with **no** proposal, resolved via `PublicDemoAssignment.projectId` (project-agnostic-then-assigned) | Synthesizes correctly (Phase 1a coverage, still green) |
| Legacy `clientInterviewPassed` with **no** resolvable project at all | Synthesizes nothing — documented limitation preserved (Phase 1a coverage, still green) |
| An `ordered` engineer with a lagging sibling candidate for a different project | Ordered project's candidate upgraded to `ordered` **and** the sibling atomically declined |
| Save → load → reconcile → save → reload | Idempotent — second reload byte-identical to the first |
| Duplicate `(engineerId, projectId)` identity in a raw save | Rejected (`FormatException`) |
| Fake interview proof (`clientInterviewPassed` with no genuine record) | Never orderable |
| Raw `ordered` candidate whose own engineer is not itself genuinely `ordered` | Rejected by `PublicDemoSaveCodec.fromJson` |

## Tests

- `flutter analyze` (whole project): **No issues found.**
- `flutter test test/game/public_demo`: **980/980 passed** (952 pre-existing + 25 in `public_demo_parallel_sales_phase1b_test.dart` covering Scopes A–D/reconciliation/integrity + 2 new "session keying / engine reuse" tests in the same file + 1 focused regression test from the independent review's own P1 fix, `public_demo_parallel_sales_offer_candidate_seed_isolation_test.dart`). One pre-existing test (`public_demo_project_interview_test.dart`, "conclude and failureReasons never mix a stale session with a different current project") was updated to check the widened, more precise session-keying semantics directly against the full session list rather than the now-narrower single-argument convenience accessor — a mechanical update to reflect the more precise composite key, not a behavior regression (the stale session itself is still preserved, exactly as the test always required).
- `flutter test test/ui/public_demo`: **741/741 passed** — zero UI regression (no `lib/ui/` file touched; production UI call sites automatically exercise the cutover through their existing, unmodified signatures; the session-keying widening required zero UI/test call-site changes anywhere).
- `git diff --check`: clean, no whitespace errors.

## Security / self-hardening findings (this session)

1. **Test-construction transient-mismatch, self-caught during implementation.** An early version of `withMatchingProposal`'s candidate creation always started a fresh candidate at `proposed`, regardless of the engineer's own current legacy stage. For an engineer who reached `partnerInterviewPassed`/`Failed` via the legacy generic path *before* the project in question was ever proposed (an edge case, but a real, reachable production combination — not merely a test artifact), this left the freshly-created candidate transiently one stage behind the very engineer it belongs to until the next save/reload's reconciliation caught it up. Found via 16 pre-existing test failures after the first cutover pass (all in `public_demo_project_interview_test.dart`'s own strict-round-trip assertions). Fixed by seeding a brand-new candidate directly at the engineer's current legacy stage (`_offerCandidateFromLegacy`, shared with reconciliation's own synthesis branch) rather than always the bare `proposed` entry point. Re-verified: all 977 `test/game/public_demo` tests green afterward.
2. **CRITICAL — self-caught and reverted before completion: an over-strict raw-level cross-check would have rejected a legitimate, non-forged save.** An initial hardening attempt required every `offerCandidates` entry at `stage: 'ordered'` to also name the exact same project as the engineer's *current* `PublicDemoMatchingProposal`/`PublicDemoAssignment` resolution. Since `matchingProposals` is single-slot (replaced, never accumulated), this would have rejected a real save where an engineer completed one assignment cycle (`endAssignment` → re-sell → re-propose → pass → order a *different* project later in the same fiscal year) while `offerCandidates` — which never deletes history — still carries the *earlier* cycle's own genuine `ordered` candidate for a now-different project than the current proposal names. Caught by re-reasoning through the full diff before considering the hardening done (not by a failing test — no test exercised this exact multi-cycle sequence). Relaxed to the correct invariant: an `ordered` candidate's own engineer must itself be genuinely `ordered` (still closes the actual gap — an `ordered` candidate whose engineer never reached `ordered` at all did not come from any real command path), without requiring project-level agreement across historically-superseded cycles.
3. **Considered and declined: full ordered-project agreement cross-check.** Per finding #2's reasoning, this was deliberately not added. The residual risk (a forged `ordered` candidate for an unrelated project, on an engineer who genuinely *is* ordered for a *different* real project) is inert: no production code path reads `offerCandidates` for any assignment-materialization or financial purpose — `assignOrderedForMay`/`recoverLateYearAssignment` still gate exclusively on `PublicDemoEngineerSales.stage`/`hasGenuineInterviewRecord`, unchanged — and `recordOrder`'s own real order path only ever targets the one project resolved from the engineer's own locked proposal, so a forged sibling can never actually be ordered through any real command. Documented here rather than silently dropped.
4. **Duplicate composite identity, unknown engineerId** — re-verified at both `PublicDemoWorkflowState.fromJson` (checked once on the raw decoded list before reconciliation, once more on reconciliation's own output) and `PublicDemoAggregate._validateForPersistence` (defense in depth, unchanged from Phase 1a).
5. **Retry/idempotency** — every cutover transition (`withMatchingProposal`'s candidate creation, `concludePartnerProjectInterview`/`concludeProjectInterview`'s candidate sync, `recordOrder`'s candidate order+decline) is a no-op-unless-precondition-holds addition layered onto each method's own pre-existing engineer-level precondition gate, so every existing double-tap/reload/retry safety this file already had is inherited unchanged, not re-derived.
6. **Atomicity** — every cutover writes both the legacy engineer-level field and the candidate-level field in the SAME `_copyWith` call; there is no intermediate, persistable state where one authority has advanced and the other has not (mirrors Phase 1a's own `recordOfferCandidateOrder` atomicity guarantee, now extended to the real production callers).
7. **Found by an independent Claude Broad Review, fixed on this branch (P1):** `withMatchingProposal`'s candidate-creation cross-project stage/score leak — see "Independent Broad Review" above for the full mechanism/fix.
8. **Own follow-up after the independent review (`projectInterviewSessions` composite-key widening):** the reviewer's own P2 finding was that Issue #257's "PR #256 carry-over" section (added to the issue after this session's initial research — see the scope-drift note above) explicitly marks this **必須** and it was neither implemented nor documented as deferred. Rather than merely recording it as a known limitation, this session implemented the full widening (see "Session-keying verification" above) — a scoped, low-risk change once traced: the only non-composite-aware code was the lookup/replace half of `projectInterviewSessionFor`/`startProjectInterviewSession`; the conclude/update paths already had Codex P1/P2 composite guards from PR #214. Verified via a dedicated regression test group and the full suite re-run (980/980 game, 741/741 UI, both green).

No other issues were found. No production code outside `lib/game/public_demo/public_demo_offer_candidate.dart`, `lib/game/public_demo/public_demo_workflow_state.dart`, `lib/game/public_demo/public_demo_aggregate.dart`, and `lib/game/persistence/public_demo_save_codec.dart` was touched.

## Guardrails confirmed unchanged

- HOME: no file under `lib/ui/public_demo/public_demo_home_*` touched.
- Finance/Payroll: `PublicDemoRevenue`, payroll math untouched.
- Matching/Interview outcome formulas: `PublicDemoInterviewEvaluator`, `ClientInterviewEngine`, `ProjectInterviewEngine`, `PublicDemoMatchingFit` untouched — every cutover reuses an already-computed outcome, never a second formula.
- `salesCapacity`/`salesUsed` semantics: unchanged mechanism; verified no new/second slot consumption anywhere.
- 1-turn-1-week: not touched.
- Phase 1C comparison UI: not started (see below).

## Post-review focused fix: `projectInterviewSessions` composite-identity widening (Issue #257 own "必須" item, PR #258 Claude Broad Review blocking P2)

**Status: resolved. This is a focused fix following up on PR #258's own Claude Independent Broad Review — that review is not re-run here; see `docs/reports/SES_PR-258_Parallel-Sales-Phase1B_Claude-Broad-Review.md`'s own appended section for the fix's own before/after HEAD and verdict.**

**Concurrent-session merge note:** a second session (`session_011q8sKy4zSgnsfDshCNbPCB`, commit `7a44149`) independently pushed an equivalent fix to this same branch while this session was still working — both sessions converged on the identical composite-identity design below, confirming it independently. The two branches were merged (not force-pushed over), keeping both sessions' non-overlapping test coverage. One genuine bug was caught in the process: commit `7a44149`'s own `concludeProjectInterview`/`concludePartnerProjectInterview` correctly narrowed the session *lookup* to the `(engineerId, projectId)` pair, but left the `_copyWith` session-list *replacement* filter matching on `employeeId` alone — concluding project A's interview while a sibling project B's own session also existed would have overwritten/destroyed B's entry with a duplicate of A's completed session. This session's own independent implementation of that same replacement filter was already composite-aware and is the version that survived the merge (git's 3-way merge took it automatically, since commit `7a44149` never touched that exact line). See "Design" below.

### The gap

Issue #257 itself required widening `projectInterviewSessions` from an `engineerId`-only identity to `(engineerId, projectId)` composite identity — the same widening this Phase already gave `offerCandidates` in Phase 1a. This PR's own original implementation (above) left `projectInterviewSessions` untouched: `PublicDemoWorkflowState.projectInterviewSessionFor`/`startProjectInterviewSession` still matched by `employeeId` alone, so starting an interactive interview for a second project silently discarded any in-progress (or even completed-but-not-yet-reconciled) session the same engineer already held for a different project. Concluded pass/fail *results* already coexisted correctly per project via `offerCandidates` (Phase 1a/1B's own authority) — only the raw, in-progress `ClientInterviewSession` transcript was ever at risk of being swept away by switching Matching focus to a different project mid-interview.

### Design

`ClientInterviewSession` already carried its own `projectId` field on every entry (`PublicDemoProjectInterview.start` always sets `id: 'public-demo-project-interview:$employeeId:$projectId'`, `projectId: candidate.id`) — the composite key was always structurally present in the data; only the container's own "at most one per employee" *enforcement* needed relaxing to "at most one per `(employeeId, projectId)` pair", mirroring `offerCandidates`' own identity exactly:

- `PublicDemoWorkflowState.projectInterviewSessionFor(engineerId, projectId)` now requires an explicit `projectId` and matches both fields — no ambiguous employeeId-only lookup remains at the workflow layer.
- `startProjectInterviewSession` now replaces only the existing entry for the SAME `(employeeId, projectId)` pair (still discarding a stale/completed entry for that exact project, per the pre-existing Codex P1/P2 rules — unchanged), leaving every sibling project's own session for the same engineer completely untouched.
- `concludeProjectInterview`/`concludePartnerProjectInterview` now look up and replace by the exact `(engineerId, project.id)` pair, never by `engineerId` alone — concluding one project's interview can no longer read, overwrite, or discard a different project's own session.
- `PublicDemoAggregate.projectInterviewSessionFor(engineerId)` keeps its exact existing single-argument public signature for every pre-existing UI/test call site — it resolves `projectId` from the engineer's CURRENT Phase 5 proposal via `projectInterviewCandidateFor` internally (exactly what "the" session for an engineer already meant to every existing caller); a caller that needs a specific, possibly-not-current project instead calls `workflow.projectInterviewSessionFor(engineerId, projectId)` directly. No `lib/ui/` file needed to change: the interactive dialog always drives whichever project is currently proposed, which this resolution already matches.

### Migration

**None needed.** Every `ClientInterviewSession` ever persisted already carries its own `projectId` (a required field since before this Phase existed) — the composite key was always present in the save data; only the in-memory enforcement rule changed. A save with exactly one session per employee (the shape every pre-existing save has) trivially satisfies the new "at most one per pair" invariant unchanged, and round-trips byte-identical. `PublicDemoSaveCodec._withMigratedProjectInterviewSessions`'s splice (absence-gated, unchanged) and `schemaVersion` (still `1`, unchanged) needed no changes — confirmed by test (see "G. legacy save migration" below).

`PublicDemoSaveCodec._hasConsistentAuthorityFacts` was updated for the composite shape:
- The raw-level duplicate check now dedupes on `'$employeeId::$projectId'` instead of `employeeId` alone — a genuine second session for the same employee at a *different* project is no longer rejected as a forged duplicate (it is now the normal, expected shape); an actual duplicate `(employeeId, projectId)` pair is still rejected exactly as before.
- The engineer-level `recordProjectId`-vs-completed-session cross-check (which used to compare against a single per-employee "the one completed session's project" fact) was removed — under composite identity this check became structurally vacuous: a completed session's own `projectId` is now, by construction of its own composite key, always exactly the project that entry belongs to, so there is no longer a distinct fact it could ever disagree with. The proposal-vs-record cross-check (`proposalProjectIdByEngineer`) and every other authority check in this method are unchanged.

### Authority / security re-verification for the new shape

- **Forged engineerId / unknown engineerId**: unchanged, still rejected by `engineerIds.contains(employeeId)`.
- **Forged projectId / session-identity mismatch**: unchanged, still rejected by the existing `id == 'public-demo-project-interview:$employeeId:$projectId'` structural check.
- **Duplicate composite identity**: now dedupes on the composite pair (was: `employeeId` alone) — a real duplicate for the same pair is still rejected; two genuinely different pairs for the same employee are now correctly accepted.
- **Stale session / session-vs-project mismatch (conclude authority)**: `concludeProjectInterview`/`concludePartnerProjectInterview` resolve the session via the exact `(engineerId, project.id)` pair before any other check runs — a session for a different project can never be reached, let alone concluded, for the wrong one. `test/game/public_demo/public_demo_parallel_sales_session_composite_identity_test.dart`'s group E covers both the aggregate-level no-op and a direct workflow-level call with a deliberately mismatched `project`.
- **Candidate/session/matching-proposal project agreement**: unaffected — `offerCandidates`' own `(engineerId, projectId)` authority (Phase 1a/1B, unchanged) and the session's own composite key are independently keyed by the same real project identity; nothing here lets a caller forge a mismatch between them.
- **`salesCapacity` exactly-once**: `startPartnerInterview`'s existing `identical(nextWorkflow, workflow)` no-op-detection (used to decide whether to charge a slot) is unaffected — it still keys off whether `startProjectInterviewSession` for the CALLER'S OWN `(employeeId, projectId)` pair genuinely changed anything, which composite widening does not alter for a same-pair retry/resume. Verified by test (group F): retrying the same pair never re-charges; starting a second, different project's interview is correctly treated as its own genuinely new attempt.
- **Duplicate/retry conclude**: unaffected — every conclude method's own precondition (current engineer stage + a genuine, ready-to-conclude session for the exact pair) is unchanged, still a no-op on a second call.
- **Partner/Client Interview authority already established in this PR (Scope B/C) and Phase 1a's `offerCandidates` reconciliation/candidate-aware `recordOrder`/sibling-decline**: unaffected — none of those methods' own logic changed; only the container `projectInterviewSessions` itself widened.

### Tests

New file `test/game/public_demo/public_demo_parallel_sales_session_composite_identity_test.dart` (15 tests), covering the full verification matrix this fix's own task required:

- **A.** Same engineer / two projects: starting a fresh interview for project B no longer discards project A's still-incomplete session — both held at once.
- **B.** Independent results: a genuine partner-interview FAIL for project A followed by a genuine PASS for project B (via the real `beginSelling` failure-recovery path) leaves each project's own session/candidate authority independently correct, never mixed.
- **C.** Both pass: a genuine order → April/May assignment → `notOffered` decision → `endAssignment` release (at month ≥ 7, the real production precondition for `assignedEngineerIds` to stop counting a `notOffered` row) → resell cycle, followed by a second genuine pass for project B, leaves BOTH sessions completed/passed and both candidates correctly resolved (A stays `ordered`, never rewound by the later, unrelated cycle; B is the engineer's new current pass).
- **D.** Save/reload: two held sessions (one failed, one passed) round-trip byte-identically, resolvable independently by their own composite keys.
- **E.** Stale identity: `concludeProjectInterview` is a no-op when the CURRENT proposal's project has no session of its own yet (even though a fully-answered session exists for a DIFFERENT project); a direct workflow-level call naming a genuinely different, unrelated project is also rejected.
- **F.** Duplicate/retry: resuming the same `(engineer, project)` interview never creates a duplicate entry or re-charges a sales slot; two different projects' interviews are correctly treated as independent, genuinely-new attempts; concluding an already-completed session a second time is a no-op.
- **G.** Legacy save migration: a single-session save (the pre-existing shape every real save has) still decodes and round-trips byte-identical — no migration needed, confirming the "every entry already carried its own projectId" design claim above.
- **H.** Malformed/forged save rejection: a raw duplicate `(employeeId, projectId)` pair is rejected; a session naming an unknown `employeeId` is rejected; two genuinely different `(employeeId, projectId)` pairs for the same employee are correctly *accepted* (the new legitimate shape, not a forgery).
- **I.** Month boundary: reopening the CURRENTLY-proposed project's own stale-month session discards and restarts only that one; a sibling project's own same-month session (started earlier, before the close) is left completely untouched.
- **J.** Existing single-project gameplay regression: unaffected.

Two pre-existing tests were updated to match the new, intentionally-changed semantics (not weakened — the old assertions encoded exactly the single-slot behavior this fix replaces):
- `test/game/public_demo/public_demo_project_interview_test.dart`'s "2. changing the matching proposal mid-interview" test and its neighbor now look up the old project's own session by its explicit composite key rather than the ambiguous single-argument accessor, and their prose reflects that the old session is now preserved, not discarded.
- `test/game/public_demo/public_demo_save_codec_test.dart`'s duplicate-session test title/comment now says "pair" instead of "engineer", and a new companion test ("5b") confirms two sessions for the same employee at different projects round-trip correctly rather than being rejected.

Full-suite results from this session (Flutter 3.47.4 stable, freshly fetched — no SDK was preinstalled in this session's container, mirroring the Broad Review session's own environment note):
- `flutter analyze` (whole project): **No issues found.**
- `flutter test test/game/public_demo`: **996/996 passed**, run after merging with the concurrent session's own commit `7a44149` (977 pre-existing at the merge base + 15 new composite-identity tests + 2 new save-codec tests from this session, + 2 additional "session keying / engine reuse" tests carried in from `7a44149`).
- `flutter test test/ui/public_demo`: **741/741 passed** — zero UI regression (no `lib/ui/` file was touched by this fix).
- `git diff --check`: clean.

### Guardrails re-confirmed for this fix

- `PublicDemoEngineerSales.stage` remains the coarse, unmodified compatibility scalar — zero diff to `public_demo_sales.dart`.
- `matchingProposals` remains single-slot per engineer, unchanged — this fix does not widen it (out of the task's own stated scope).
- `offerCandidates`/reconciliation/candidate-aware `recordOrder`/sibling-decline (Phase 1a/1B) — zero diff, all pre-existing tests re-run green.
- Finance/Payroll/Matching/Interview-outcome formulas — zero diff.
- HOME — zero diff (no `lib/ui/public_demo/public_demo_home_*` file touched).
- Phase 1C comparison UI — not implemented, not started; out of scope for this fix exactly as for the rest of this Phase.
- `ordered != assigned` — unaffected, unchanged.
- Schema version — still `1`; not bumped (no migration was needed — see above).

### Files changed by this fix

- `lib/game/public_demo/public_demo_workflow_state.dart` (`projectInterviewSessionFor`, `startProjectInterviewSession`, `concludeProjectInterview`, `concludePartnerProjectInterview`, plus doc updates)
- `lib/game/public_demo/public_demo_aggregate.dart` (`projectInterviewSessionFor` — internal resolution updated to the widened workflow-level lookup; public single-argument signature unchanged)
- `lib/game/persistence/public_demo_save_codec.dart` (`_hasConsistentAuthorityFacts` — composite-key dedup, removal of the now-vacuous single-employee completed-session cross-check)
- `test/game/public_demo/public_demo_parallel_sales_session_composite_identity_test.dart` (new, 15 tests)
- `test/game/public_demo/public_demo_project_interview_test.dart` (2 tests updated for the new, intentional semantics)
- `test/game/public_demo/public_demo_save_codec_test.dart` (1 test title/comment updated, 1 new companion test added)

No other file was touched. `Blocking P2 (Issue #257/PR #258 Broad Review): RESOLVED.`

## Known limitations / unresolved Phase 1C

- **Comparison UI (Phase 1C) is unimplemented**, exactly as scoped. `offerCandidates` is now a live, correctly-synchronized, per-project authority, but no screen surfaces it — a player cannot yet see or choose between multiple concluded candidates for one engineer. `PublicDemoAggregate.offerCandidates`/`offerCandidateFor` (already public since Phase 1a) are the read surface Phase 1c should build on.
- **`availableEngineersForMatching` still gates on the coarse engineer scalar** (excludes `clientInterviewPassed`/`ordered`), not on candidate authority — per this task's own scope, Phase 1B does not change matching eligibility rules; that UI/rule decision belongs to Phase 1c.
- **The generic, project-agnostic `recordEngineerInterviewResult` path remains uncut-over** — by design, since it has no project identity to sync a candidate against. An engineer who reaches a relevant stage through this path alone (no proposal ever made) continues to synthesize no candidate, exactly matching Phase 1a's own documented limitation.
- **The declined-vs-legacy-advance edge case documented in self-hardening finding #3's neighbor** (a candidate manually `declined` while legacy authority is later driven past it through the generic path) is handled by never resurrecting the decline — this is a deliberate design choice (a decline is final), not a gap, but is worth Phase 1c's awareness if a future UI ever lets a player "undo" a decline.
- One considered-and-declined hardening (full ordered-project cross-check across historical order cycles) is documented above (self-hardening finding #3) rather than implemented, with its residual-risk reasoning recorded for a future session to revisit if `offerCandidates` ever becomes load-bearing for assignment materialization itself.
- **New, from the independent Broad Review:** a theoretical, currently-**unreachable** dual-authority shape — a `declined` candidate for the exact `(engineerId, projectId)` pair legacy authority currently resolves to `ordered` is not proactively caught by either reconciliation (declines are deliberately never touched) or `_hasConsistentAuthorityFacts` (which only checks the reverse direction). Unreachable today because `declineOfferCandidate` has zero UI call sites; becomes relevant once Phase 1c exposes a manual decline action, at which point a save-codec hardening pass should close it.
- **`projectInterviewSessions` composite-key widening (Issue #257's own "必須" PR #256 carry-over item) is now implemented** (this was the independent review's own P2 finding; closed out in this session rather than left as a documented gap — see "Session-keying verification" above). The one remaining, explicitly-deferred piece is Phase 1c's own comparison UI actually letting a player drive two concurrent in-flight interviews through the real screen — the underlying domain/workflow capability is what this session delivers; no UI exists yet to exercise it end-to-end.

## Final HEAD SHA / PR

See the commit this file is part of, on branch `claude/first-fun-year-phase-1b-2zy73j` (base: `origin/main` @ `3dffd5c78b5c956dfc4f0804eb12887d17042eb1`). PR opened against `main`; Broad Review (Codex) requested once per this task's own instruction, after this Result Report and all commits landed on the branch.
