# SES First Fun Year — Parallel Sales Phase 1B (Production Cutover / Dual Authority Reconciliation)

Status: **Implemented. Production Public Demo sales/interview/order flow cut over to `(engineerId, projectId)` candidate authority, with real, repeatable legacy reconciliation. Comparison UI (Phase 1C) is explicitly out of scope and remains unimplemented.**

## Audited explicit main SHA

- `git fetch origin` performed at session start; `origin/main` HEAD confirmed to be **exactly** `3dffd5c78b5c956dfc4f0804eb12887d17042eb1` (PR #254's own merge commit), matching Issue #257's own stated starting-point SHA — no drift to report.
- The designated branch `claude/first-fun-year-phase-1b-2zy73j` existed but carried no commits ahead of `origin/main` and was missing everything back through `f4ca78f` (857+ commits behind) — confirmed (`git log origin/claude/...-2zy73j..origin/main`) to be a stale leftover with no unmerged work. Reset via `git reset --hard origin/main`, mirroring this task's own branch-recovery instructions and every prior session's identical handling of the same situation.
- Governing docs read in full before any code change: `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Result.md` (Fresh Audit / design), `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Phase1a_Result.md` (Phase 1a domain foundation + its own Codex review responses), `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`, Issue #257, and PR #254's Codex review threads (all four findings and their resolutions).

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
- `flutter test test/game/public_demo`: **977/977 passed** (952 pre-existing + 25 in the new `public_demo_parallel_sales_phase1b_test.dart` file, covering Scopes A–D, reconciliation, and integrity).
- `flutter test test/ui/public_demo`: **741/741 passed** — zero UI regression (no `lib/ui/` file touched; production UI call sites automatically exercise the cutover through their existing, unmodified signatures).
- `git diff --check`: clean, no whitespace errors.

## Security / self-hardening findings (this session)

1. **Test-construction transient-mismatch, self-caught during implementation.** An early version of `withMatchingProposal`'s candidate creation always started a fresh candidate at `proposed`, regardless of the engineer's own current legacy stage. For an engineer who reached `partnerInterviewPassed`/`Failed` via the legacy generic path *before* the project in question was ever proposed (an edge case, but a real, reachable production combination — not merely a test artifact), this left the freshly-created candidate transiently one stage behind the very engineer it belongs to until the next save/reload's reconciliation caught it up. Found via 16 pre-existing test failures after the first cutover pass (all in `public_demo_project_interview_test.dart`'s own strict-round-trip assertions). Fixed by seeding a brand-new candidate directly at the engineer's current legacy stage (`_offerCandidateFromLegacy`, shared with reconciliation's own synthesis branch) rather than always the bare `proposed` entry point. Re-verified: all 977 `test/game/public_demo` tests green afterward.
2. **CRITICAL — self-caught and reverted before completion: an over-strict raw-level cross-check would have rejected a legitimate, non-forged save.** An initial hardening attempt required every `offerCandidates` entry at `stage: 'ordered'` to also name the exact same project as the engineer's *current* `PublicDemoMatchingProposal`/`PublicDemoAssignment` resolution. Since `matchingProposals` is single-slot (replaced, never accumulated), this would have rejected a real save where an engineer completed one assignment cycle (`endAssignment` → re-sell → re-propose → pass → order a *different* project later in the same fiscal year) while `offerCandidates` — which never deletes history — still carries the *earlier* cycle's own genuine `ordered` candidate for a now-different project than the current proposal names. Caught by re-reasoning through the full diff before considering the hardening done (not by a failing test — no test exercised this exact multi-cycle sequence). Relaxed to the correct invariant: an `ordered` candidate's own engineer must itself be genuinely `ordered` (still closes the actual gap — an `ordered` candidate whose engineer never reached `ordered` at all did not come from any real command path), without requiring project-level agreement across historically-superseded cycles.
3. **Considered and declined: full ordered-project agreement cross-check.** Per finding #2's reasoning, this was deliberately not added. The residual risk (a forged `ordered` candidate for an unrelated project, on an engineer who genuinely *is* ordered for a *different* real project) is inert: no production code path reads `offerCandidates` for any assignment-materialization or financial purpose — `assignOrderedForMay`/`recoverLateYearAssignment` still gate exclusively on `PublicDemoEngineerSales.stage`/`hasGenuineInterviewRecord`, unchanged — and `recordOrder`'s own real order path only ever targets the one project resolved from the engineer's own locked proposal, so a forged sibling can never actually be ordered through any real command. Documented here rather than silently dropped.
4. **Duplicate composite identity, unknown engineerId** — re-verified at both `PublicDemoWorkflowState.fromJson` (checked once on the raw decoded list before reconciliation, once more on reconciliation's own output) and `PublicDemoAggregate._validateForPersistence` (defense in depth, unchanged from Phase 1a).
5. **Retry/idempotency** — every cutover transition (`withMatchingProposal`'s candidate creation, `concludePartnerProjectInterview`/`concludeProjectInterview`'s candidate sync, `recordOrder`'s candidate order+decline) is a no-op-unless-precondition-holds addition layered onto each method's own pre-existing engineer-level precondition gate, so every existing double-tap/reload/retry safety this file already had is inherited unchanged, not re-derived.
6. **Atomicity** — every cutover writes both the legacy engineer-level field and the candidate-level field in the SAME `_copyWith` call; there is no intermediate, persistable state where one authority has advanced and the other has not (mirrors Phase 1a's own `recordOfferCandidateOrder` atomicity guarantee, now extended to the real production callers).

No other issues were found. No production code outside `lib/game/public_demo/public_demo_offer_candidate.dart`, `lib/game/public_demo/public_demo_workflow_state.dart`, and `lib/game/persistence/public_demo_save_codec.dart` was touched.

## Guardrails confirmed unchanged

- HOME: no file under `lib/ui/public_demo/public_demo_home_*` touched.
- Finance/Payroll: `PublicDemoRevenue`, payroll math untouched.
- Matching/Interview outcome formulas: `PublicDemoInterviewEvaluator`, `ClientInterviewEngine`, `ProjectInterviewEngine`, `PublicDemoMatchingFit` untouched — every cutover reuses an already-computed outcome, never a second formula.
- `salesCapacity`/`salesUsed` semantics: unchanged mechanism; verified no new/second slot consumption anywhere.
- 1-turn-1-week: not touched.
- Phase 1C comparison UI: not started (see below).

## Known limitations / unresolved Phase 1C

- **Comparison UI (Phase 1C) is unimplemented**, exactly as scoped. `offerCandidates` is now a live, correctly-synchronized, per-project authority, but no screen surfaces it — a player cannot yet see or choose between multiple concluded candidates for one engineer. `PublicDemoAggregate.offerCandidates`/`offerCandidateFor` (already public since Phase 1a) are the read surface Phase 1c should build on.
- **`availableEngineersForMatching` still gates on the coarse engineer scalar** (excludes `clientInterviewPassed`/`ordered`), not on candidate authority — per this task's own scope, Phase 1B does not change matching eligibility rules; that UI/rule decision belongs to Phase 1c.
- **The generic, project-agnostic `recordEngineerInterviewResult` path remains uncut-over** — by design, since it has no project identity to sync a candidate against. An engineer who reaches a relevant stage through this path alone (no proposal ever made) continues to synthesize no candidate, exactly matching Phase 1a's own documented limitation.
- **The declined-vs-legacy-advance edge case documented in self-hardening finding #3's neighbor** (a candidate manually `declined` while legacy authority is later driven past it through the generic path) is handled by never resurrecting the decline — this is a deliberate design choice (a decline is final), not a gap, but is worth Phase 1c's awareness if a future UI ever lets a player "undo" a decline.
- One considered-and-declined hardening (full ordered-project cross-check across historical order cycles) is documented above (self-hardening finding #3) rather than implemented, with its residual-risk reasoning recorded for a future session to revisit if `offerCandidates` ever becomes load-bearing for assignment materialization itself.

## Final HEAD SHA / PR

See the commit this file is part of, on branch `claude/first-fun-year-phase-1b-2zy73j` (base: `origin/main` @ `3dffd5c78b5c956dfc4f0804eb12887d17042eb1`). PR opened against `main`; Broad Review (Codex) requested once per this task's own instruction, after this Result Report and all commits landed on the branch.
