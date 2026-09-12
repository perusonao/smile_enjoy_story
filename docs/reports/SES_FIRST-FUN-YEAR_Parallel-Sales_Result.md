# SES First Fun Year — Parallel Sales / Offer Selection (Issue #245 Finding #4)

Status: **Fresh Audit complete. Phase B — detailed design + migration plan only. No schema/domain code changed in this session.**

## Audited explicit main SHA

- Task start base given: `afd34333c0e6a4f3db104e8159317bbdc068b544`
- `git fetch origin` performed at session start; `origin/main` HEAD was confirmed to be **exactly** `afd34333c0e6a4f3db104e8159317bbdc068b544` (0 commits ahead) — no drift to report.
- The designated branch `claude/ses-parallel-sales-offers-4e18j7` existed but only carried the project's very first commit (`f4ca78f`, "Phase 0A/0B", Aug 12), 855 commits behind `origin/main` and 0 commits ahead — no unmerged prior work to preserve. Per this task's own branch-recovery instructions, the branch was reset to start cleanly from `origin/main` (`git checkout -B claude/ses-parallel-sales-offers-4e18j7 origin/main`) rather than rebasing an empty diff.

## Why Phase B (no implementation this session)

Issue #245 itself anticipated this outcome for Finding #4 explicitly:

> 大きなstate/schema redesignが必要ならこのIssueで即実装せず、設計Phaseへ分離する

and lists "複数案件面談結果→受注/辞退のparallel sales / offer selection gameplay" under **Separate design candidate**, not under P1/P2. PR #247 (merged same day as this task started) independently reached the same conclusion in its own Known Limitations: *"Parallel Sales（Finding #4）...は未実装（指示通り）"*.

This session's Fresh Audit confirms why: the current Public Demo sales authority is built around **one scalar per engineer**, not one per (engineer, project) pair, and that scalar is simultaneously the interview-progress cursor *and* the unforgeable proof gating order/assignment. Making two projects genuinely parallel for one engineer requires decoupling that scalar into a per-(engineer, project) fact — a real authority/schema restructuring, not a safe additive extension. Section "Current authority (Fresh Audit)" below documents exactly which facts would have to move and why doing so in one sitting, without a prior design review, would risk the exact things Issue #245's guardrails protect (`ordered != assigned`, no double-order, no sales-slot double consumption, full save backward compatibility, ~1,600+ existing Public Demo domain/UI tests).

## Current authority (Fresh Audit)

All facts below were read directly from `lib/game/public_demo/*.dart` on `origin/main` at the audited SHA — nothing is inferred from documentation or issue text.

### Engineer × project — how many can be held today?

**Exactly one**, enforced at three independent layers that all key off the same single engineer:

1. **`PublicDemoMatchingProposal`** (`public_demo_matching_proposal.dart`) — `PublicDemoWorkflowState.matchingProposals` is a flat list, but `withMatchingProposal` (public_demo_workflow_state.dart:1360) explicitly replaces any existing proposal for the same `engineerId`: *"At most one proposal is kept per engineer — a later call for the same engineerId replaces the earlier one rather than accumulating history."* It is additionally a no-op once the engineer reaches `clientInterviewPassed`/`ordered` — the proposal becomes permanently locked to whichever project the engineer actually interviewed for.
2. **`ClientInterviewSession` (`projectInterviewSessions`)** — `projectInterviewSessionFor` (workflow_state.dart:1399) looks up by `employeeId` alone; `startProjectInterviewSession` (workflow_state.dart:1446) replaces any existing entry for that `employeeId` (keeping it only when it is the *same* project and *same* month — otherwise discarded). At most one session, for one project, can be in flight or hold a concluded result per engineer at any time.
3. **`PublicDemoEngineerSales.stage`** (`public_demo_sales.dart`) — a single enum (`waiting → skillSheet → selling → introduced → partnerInterviewPassed/Failed → clientInterviewPassed/Failed → ordered`) per engineer. This is the actual bottleneck: it represents *both* "which interview stage is this engineer's current pipeline at" *and* (via `hasGenuineInterviewRecord`) "is this engineer allowed to be ordered/assigned." A single field cannot represent "passed for project A, still pending for project B."
4. `PublicDemoAggregate.availableEngineersForMatching` (public_demo_aggregate.dart:138) additionally excludes any engineer already at `clientInterviewPassed`/`ordered` from the Matching pool entirely — so today, once an engineer passes one project's client interview, the game will not even let the player propose them to a second project.

### Active proposal/session constraints

Confirmed identical to above: **1 active `PublicDemoMatchingProposal` and 1 active/concluded `ClientInterviewSession` per engineer**, both keyed only by `engineerId`, both silently replaced (never accumulated) by a new proposal/session for the same engineer.

### Partner Interview session/result authority (PR #247 integration point)

PR #247 (merged just before this session started) added `PublicDemoAggregate.startPartnerInterview`/`concludePartnerInterview` and `PublicDemoWorkflowState.concludePartnerProjectInterview`, which **reuse the exact same `projectInterviewSessions` list and the exact same `ClientInterviewSession` shape** as the Phase 6 client interview — a partner-interview session for `introduced` and a client-interview session for `partnerInterviewPassed` are structurally identical entries, distinguished only by which `PublicDemoEngineerSales.stage` the engineer is currently at when the session starts/concludes. `startProjectInterviewSession`'s own "at most one entry per `employeeId`" replace rule is what stops a stale partner session and a fresh client session from ever coexisting for the same engineer today. Any parallel-offer design must preserve this reuse (no forked/duplicated interview engine) while extending the *key* these sessions are stored under.

### Order confirmation — the exact location

`PublicDemoWorkflowState.recordOrder(engineerId)` (workflow_state.dart:792) is the **only** production path from `clientInterviewPassed` to `ordered`. It requires the engineer's current `stage == clientInterviewPassed` — no project/candidate parameter at all, because there is only ever one candidate project to order. This is called from `PublicDemoAggregate.recordOrder` (aggregate.dart:614-615), which the Matching/Sales UI calls directly on player action — order is **immediate and manual** (never auto-committed by an interview pass), already satisfying design principle #2 ("面談合格だけで自動受注させない").

### `ordered != assigned`

Confirmed still correctly separated: `recordOrder` only flips `PublicDemoEngineerSales.stage` to `ordered`. Materializing an actual `PublicDemoAssignment` row happens only via `assignOrderedForMay` (workflow_state.dart:1007) or `recoverLateYearAssignment` (workflow_state.dart:1100), both of which re-derive eligibility from `stage == ordered && hasGenuineInterviewRecord` rather than trusting a caller-supplied roster — and both run at a month-boundary/recovery call site, never inline with `recordOrder` itself. Any Phase 1 design must preserve this separation exactly (see "Design principles preserved" below).

### Save/reload serialization

`PublicDemoWorkflowState.toJson`/`fromJson` (workflow_state.dart:130-230) treats `matchingProposals` and `projectInterviewSessions` as **additive, backward-compatible** lists: absent key → empty list, never a rejected save. `PublicDemoEngineerSales.toJson`/`fromJson` (public_demo_sales.dart:161-234) persists `stage`, `lastInterviewScore`, and `interviewRecordEngineerId`/`interviewRecordProjectId` (the latter additive from PR #214) with an identity check (`recordId != id` is rejected as corrupt). `PublicDemoAggregate._validateForPersistence` (aggregate.dart:215-287) cross-checks `engineer.interviewRecord!.engineerId == engineer.id` for every engineer on load — this is the exact invariant a parallel-offer redesign must generalize (from "one record per engineer" to "N records, one per engineer×project, each still identity-checked").

### Month boundary

`salesUsed` resets to `0` at every month-close call site (`advanceToMay`, and the equivalent closes for June onward — confirmed via grep, 5 reset sites in `public_demo_state.dart`). `assignedEngineerIds(month:)` (workflow_state.dart:1299) changes meaning at month 7: before month 7 it is every assignment row regardless of `nextOrderStatus` (this month's revenue is already earned); from month 7 it is filtered to `accepted`/`replacementStage == ordered` only. Any new parallel-offer state must not be read into either of these month-boundary computations without going through the exact same `assignedEngineerIds`/`assignOrderedForMay` gate — introducing a second, competing "is this engineer working" definition is exactly the class of bug `12MONTH-3-FIX1` originally fixed and multiple later PRs (WORKFLOW-STATE-1AB) defended against.

### `salesCapacity` consumption

`PublicDemoState.salesCapacity`/`salesUsed` (public_demo_state.dart) is a **flat monthly budget (4/month)**, unrelated to which project is being pursued. `useSalesSlot()`/`useSalesSlotForInterview()` are called once per **new interview attempt** — confirmed call sites: `completeInterview` (applicant interview, aggregate.dart:334), the generic `recordEngineerInterviewResult` partner path (aggregate.dart:667), `startPartnerInterview` (aggregate.dart:849), and the Phase 6 client-interview start path (aggregate.dart:907-922). Resuming an already-started, incomplete session never re-consumes a slot (confirmed by PR #247's own regression note and by `startProjectInterviewSession`'s idempotent-resume contract). A parallel-offer design that lets a player pursue N projects for one engineer must charge **N sales slots** — one per project actually interviewed, exactly matching today's per-attempt cost — not one flat slot regardless of N.

### Replacement sales

`PublicDemoReplacementStage` (public_demo_assignment.dart) is a **separate, already-existing** mini-cycle for an *already-ordered/assigned* engineer whose current project's continuation was declined (`nextOrderStatus == notOffered`) — `selling → introduced → partnerPassed/Failed → clientPassed/Failed → ordered`, tracked per assignment row, not per engineer-wide `stage`. This is functionally already "parallel-shaped" in one narrow sense (it lives on the assignment, not the engineer), but it is a single-candidate replacement search, not a multi-candidate comparison, and it is out of scope for Finding #4 (which is about the *initial* Sales/Matching pipeline, before any order exists). It is called out here only because a future design must not let the new parallel-offer authority and this pre-existing replacement authority silently diverge on "what counts as this engineer's current real project."

### Existing Parallel Sales / Offer code, Issues, tests in this repository

- **No existing Public Demo code, tests, or Issue implements engineer-side parallel proposals.** `test/ui/parallel_sales_ux_test.dart` and the "並行営業" references in `lib/ui/engineers/engineer_detail_screen.dart` / `engineer_list_screen.dart` all belong to the **Main Game** (not Public Demo), and are a different, already-shipped feature — see next section.
- Two long-stale branches (`agent/parallel-design-payroll-employee[-20260829]`) exist on `origin` but are about payroll/employee data design, unrelated to sales despite the "parallel" in the name (confirmed by reading their commit log: "employee data expansion design", "PAYROLL-1B integration design") — not relevant prior art for this Finding.

### Main Game's own parallel-offer implementation (reference pattern, not integration target)

The Main Game (not Public Demo) already ships exactly the gameplay loop Finding #4 wants, via a genuinely separate, proven domain shape:

- `ProjectProposal` (`lib/game/models/project_proposal.dart`): one row per (engineer, project), carrying its **own** `stage` (`proposed`/`interviewPassed`/`interviewFailed`) and `status` (`active`/`rejected`/`offered`/`accepted`/`declined`/`cancelled`). `GameState.proposals` is a flat list with **no** "one per engineer" constraint — an engineer can have N simultaneously-active proposals for N different projects, each independently progressing through its own interview.
- `Offer` (same file): a final "this specific proposal has resulted in an offer" record, again per-proposal, with its own `OfferStatus` (`pending`/`accepted`/`declined`/`expired`).
- `game_engine.dart:372-380`: accepting one `Offer` for an engineer **automatically marks every other pending offer for the same `employeeId` as `declined`** — this is the exact "受注したら他候補を辞退" mechanic Finding #4 asks for, already implemented, already tested, in production.
- The Main Game's own `Engineer` keeps only a coarse `salesStatus` (e.g. `interviewing`) — it does **not** try to encode per-project interview progress on the engineer itself. All per-project detail lives on `ProjectProposal`/`Offer`. This is the single most important structural lesson for Public Demo's own design (below): **the per-engineer scalar must shrink to a coarse status; per-project detail must move to its own list.**

Per design principle #9 ("Main Game側との全面統合はしない"), the recommendation below does **not** import, share, or unify this code with Public Demo — Public Demo's own `PublicDemoEngineerSales`/`PublicDemoWorkflowState`/save schema are independent and must stay that way. It is cited only as evidence the target shape is sound and shippable, not as a dependency.

## Rejected alternatives

1. **Attempt the full schema change in this session anyway ("Phase A").** Rejected: the change touches the load-bearing security surface of this codebase — `hasGenuineInterviewRecord`/`interviewRecord` identity checks, `assignOrderedForMay`/`recoverLateYearAssignment`'s "never trust `stage` alone" defense-in-depth, and `_validateForPersistence`'s cross-checks — all of which exist because of a long, explicit history of prior review-caught bugs (WORKFLOW-STATE-1AB FIX1 through FIX7, Codex P1/P2 fixes across PR #214/#215/#216). Rewriting the SSOT these all depend on, in one pass, without an independent design review first, is precisely the "無理に実装" this task explicitly warns against, and directly risks the double-order / double-slot-consumption / save-corruption failure modes design principle #7 lists as must-not-happen.
2. **UI-only "show N candidate project cards, but only allow one active interview attempt at a time, no held results."** Rejected: does not satisfy the literal requirement — "各案件の上位会社面談 → 結果を保持 → 条件を比較" requires multiple **concluded** interview outcomes to coexist so the player can compare them before deciding. A UI that lets the player *choose which one project to pursue* before any interview happens is a different (and lesser) feature, not a presentation-only reading of the existing authority.
3. **Reuse/import Main Game's `ProjectProposal`/`Offer` types directly into Public Demo.** Rejected per design principle #9 and Issue #245's own non-goals ("Main Game側との全面統合はしない"). Public Demo's save schema, `PublicDemoAggregate._validateForPersistence`, and its own economy (`salesCapacity`, `PublicDemoAssignment`) are intentionally independent; importing Main Game types would either couple the two save formats or require a parallel, duplicated type — neither is worth it when Public Demo can express the same idea in ~150-250 lines of its own additive code (see below).
4. **Do nothing / declare Finding #4 permanently out of scope.** Rejected: Finding #4 is real, already validated as a genuine gap by both this audit and PR #247's own admission, and the Main Game proves it is buildable. A design-only deliverable (this document) is the correct middle path Issue #245 itself specifies.

## Recommended design (for the next implementation session)

### Principle: keep the engineer scalar coarse; move per-project detail to a new list

Add a new, purely additive top-level list to `PublicDemoWorkflowState`, mirroring the existing `matchingProposals`/`projectInterviewSessions` pattern exactly (same file, same additive-`fromJson` convention):

```dart
enum PublicDemoOfferCandidateStage {
  proposed,               // player proposed this engineer for this project
  partnerInterviewPassed, // this candidate's own partner-interview pass
  partnerInterviewFailed,
  clientInterviewPassed,  // this candidate's own genuine client-interview pass
  clientInterviewFailed,
  ordered,                // player chose this candidate to receive the order
  declined,               // player (or the system, on order of a sibling) declined this candidate
}

class PublicDemoOfferCandidate {
  final String id;              // stable, e.g. '<engineerId>::<projectId>'
  final String engineerId;
  final String projectId;
  final int proposedMonth;
  final PublicDemoOfferCandidateStage stage;
  final int? partnerScore;
  final int? clientScore;
  // Unforgeable proof, generalized from today's single
  // PublicDemoEngineerInterviewRecord: minted only by the same
  // conclude*Interview path, now keyed to (engineerId, projectId, candidateId)
  // instead of engineerId alone.
  final PublicDemoOfferInterviewRecord? interviewRecord;
}
```

- `PublicDemoWorkflowState.offerCandidates: List<PublicDemoOfferCandidate>` — many per `engineerId`, at most one per `(engineerId, projectId)` pair (mirrors `matchingProposals`' existing per-key uniqueness, just keyed on the pair instead of `engineerId` alone).
- `projectInterviewSessions` gains a **composite key** `(employeeId, projectId)` instead of `employeeId` alone — the session-replacement rules already in `startProjectInterviewSession`/`updateProjectInterviewSession` port over almost unchanged (they already check `projectId`/`startedWeek` defensively; only the *lookup* key needs to stop being employee-only so two sessions for two different projects can coexist).
- `PublicDemoEngineerSales.stage` **shrinks** to a coarse status the way Main Game's `salesStatus` does: `waiting / skillSheet / selling / hasActiveCandidates` — it stops being the interview-progress cursor for any *specific* project. `interviewRecord` (singular) and `genuineInterviewProjectId` are **removed** from the engineer and replaced by querying `offerCandidates` for that engineer's own `clientInterviewPassed`/`ordered` entries — this is the one genuinely breaking rename, and is why this is schema work, not an additive-only change.
- `recordOrder(engineerId)` becomes `recordOrder(engineerId, projectId)`, requiring `offerCandidates` to contain a `clientInterviewPassed` entry for that exact pair; on success it also flips **every other** `offerCandidates` entry for the same `engineerId` at `clientInterviewPassed`/`partnerInterviewPassed`/`proposed` to `declined` in the same atomic `_copyWith` call — this is the direct analogue of Main Game's `game_engine.dart:372-380` auto-decline, and is what satisfies design principle #6 ("1件受注したら競合候補を明示的に辞退/closeする").
- `assignOrderedForMay`/`recoverLateYearAssignment` change their eligibility read from `engineer.stage == ordered && engineer.hasGenuineInterviewRecord` to "does `offerCandidates` contain an entry for this engineer at `stage == ordered` with a genuine `interviewRecord`" — same shape of check, new source.
- `salesCapacity` consumption: unchanged mechanism, just called once per **candidate's own** interview attempt (already true today per-attempt; simply no longer limited to one attempt total per engineer per cycle).

### Backward compatibility / migration plan

- **`offerCandidates` is a brand-new additive list**, exactly like `matchingProposals` was when Phase 5 introduced it: absent key on load → empty list, never a rejected save.
- **The breaking part is removing `PublicDemoEngineerSales.interviewRecord`/`genuineInterviewProjectId` and narrowing `stage`.** Migration path: on `fromJson`, if a legacy save has an engineer at `partnerInterviewPassed`/`clientInterviewPassed`/`ordered` with a legacy `interviewRecordEngineerId`/`interviewRecordProjectId`, **synthesize exactly one `PublicDemoOfferCandidate`** from that engineer's existing `matchingProposals` entry (or, if none, from `PublicDemoAssignment.projectId` for an already-`ordered` engineer) at the equivalent new stage, carrying the legacy score/record forward as that candidate's own `interviewRecord`. This is a one-time, one-directional load-time upgrade — never a live gameplay path — mirroring exactly how PR #214 already introduced `interviewRecordProjectId` as `null`-on-legacy-load. A dedicated legacy-fixture test suite (loading real saves captured from `origin/main` before this change) is mandatory before this ships, not optional.
- `PublicDemoAggregate._validateForPersistence` must gain the equivalent per-candidate identity check (`candidate.interviewRecord!.engineerId == candidate.engineerId && candidate.interviewRecord!.projectId == candidate.projectId`) alongside, not instead of, the existing per-engineer checks during the migration window.

### Phase split for the next session(s)

- **Phase 1a (domain only, no UI, ~2-3h):** `PublicDemoOfferCandidate`/`PublicDemoOfferCandidateStage`, the `offerCandidates` list plumbing (`propose`/`startPartnerInterview`/`concludePartnerInterview`/`startClientInterview`/`concludeClientInterview`/`recordOrder`/`declineCandidate`, all keyed by `(engineerId, projectId)`), migration/`fromJson` upgrade path, `_validateForPersistence` extension, and the full domain test list this task specifies (below). No UI changes; `PublicDemoEngineerSales.stage`/`interviewRecord` remain untouched and unused by new code in this sub-phase — old and new authority coexist read-only side by side so behavior is provably unchanged until Phase 1b switches callers over.
- **Phase 1b (cut over existing callers, ~1.5-2.5h):** switch `assignOrderedForMay`/`recoverLateYearAssignment`/`availableEngineersForMatching`/`recordOrder` to read `offerCandidates` instead of the legacy engineer fields; remove `PublicDemoEngineerSales.interviewRecord`/`genuineInterviewProjectId`; full regression of every existing Public Demo domain/UI suite (they must not need to change, since `assignedEngineerIds`/`ordered != assigned`/`salesCapacity` semantics are preserved exactly — any test that does need to change is a signal this cutover leaked new behavior and must be reverted).
- **Phase 1c (comparison UI, ~2-3h):** a "候補案件を比較" screen/section listing every `offerCandidate` at `clientInterviewPassed` for one engineer side by side, showing only fields already authoritative today (`Project.title`/rate/type via the existing `PublicDemoSeededProjectGenerator.regenerate` resolution PR #240 already established — never a fabricated score or trade-flow field, per design principle #5), a "この案件を受注" action per candidate, and explicit visible state for every sibling candidate once one is ordered (辞退 badge). Wires `PublicDemoProjectContextResolver` (PR #240) to also resolve from `offerCandidates`, not just the legacy single fields.

### Design principles preserved by this design (cross-checked against the task's own list)

1. Interview result vs. order decision: already separated today (`recordOrder` is manual); the new design keeps this exactly, just per-candidate instead of per-engineer.
2. No auto-order on interview pass: unchanged — `clientInterviewPassed` is a candidate stage, `recordOrder` is still a distinct, explicit player action.
3. Multiple valid candidates held per engineer: this is the entire point of `offerCandidates` — directly solved.
4. Comparison screen shows only existing authority: Phase 1c explicitly reuses PR #240's resolver/`Project` fields, no new fabricated data.
5. No hidden score / fabricated trade-flow: unchanged; `offerCandidate.partnerScore`/`clientScore` are the same scores `PublicDemoInterviewEvaluator`/`ClientInterviewEngine` already compute today, just retained per-candidate instead of overwritten.
6. Ordering one candidate explicitly declines the others: the `recordOrder` auto-decline step above, mirroring Main Game's proven `game_engine.dart:372-380`.
7. No double-order / double-slot-consumption on double-tap/retry/save-reload: preserved by keeping `recordOrder`/`concludeClientInterview` precondition-gated-transition style (a no-op unless the exact required current stage holds) — the same pattern every existing transition in `public_demo_workflow_state.dart` already uses, and by continuing to charge `salesCapacity` per interview *attempt* (unchanged mechanism) rather than per candidate held.
8. Finance/Payroll/Matching formulas unchanged: nothing in this design touches `PublicDemoInterviewEvaluator`, `ClientInterviewEngine`/`ProjectInterviewEngine`, `PublicDemoRevenue`, or payroll — only which container holds an already-computed score.
9. No Main Game integration: confirmed above — pattern reference only, no shared code/types/save format.
10. No unrelated HOME redesign: this design touches only `public_demo_sales.dart`/`public_demo_workflow_state.dart`/`public_demo_aggregate.dart`/the Matching screen and a new comparison surface; nothing under `lib/ui/public_demo/public_demo_home_*`.

## Required test matrix (mapped to the Phase 1a/1b domain design, for the next session)

All 18 scenarios the task specifies map directly onto the design above and must be written as domain tests before any UI work starts:

| Scenario | Exercises |
|---|---|
| 1 engineer / 2 projects, both proposed | `offerCandidates` holds 2 entries, `matchingProposals`-equivalent no longer replaces |
| Both Partner Interview pass | 2 independent `partnerInterviewPassed` candidates, 2 sales-slot consumptions |
| One pass / one fail | independent stage per candidate, failed candidate re-sellable via existing `beginSelling` recovery path |
| Order one → others close | `recordOrder(engineerId, projectId)` auto-declines siblings |
| Decline → order the other later | declined candidate never blocks ordering a sibling |
| Save/reload before interview | `proposed`-stage candidates round-trip |
| Save/reload after interview result | `partnerInterviewPassed`/`clientInterviewPassed`/`Failed` candidates round-trip with their own score/record |
| Save/reload before order selection | 2 `clientInterviewPassed` candidates persist side by side, neither auto-resolves on load |
| Month boundary | `salesUsed` reset behavior unchanged; candidates are not month-scoped and survive a close untouched unless explicitly declined/ordered |
| Double tap / duplicate conclude | `concludeClientInterview` no-ops once already completed, exactly like today's `concludeProjectInterview` |
| Stale project/session ID | composite-key session lookup rejects a session for a since-declined/replaced candidate, mirroring today's Codex P1 (PR #214) project/month mismatch guards |
| Replacement sales | `PublicDemoReplacementStage` mini-cycle untouched; explicit test that it never reads/writes `offerCandidates` |
| `salesCapacity` exactly-once | one slot consumed per candidate's own interview *attempt*, never on resume, never twice for the same attempt |
| `ordered != assigned` | ordering a candidate never appends to `assignments` directly; only `assignOrderedForMay`/`recoverLateYearAssignment` do |
| Legacy save / backward compatibility | a save captured from current `origin/main` (single-`stage`, single-`interviewRecord`, no `offerCandidates` key) loads, synthesizes the correct single candidate, and behaves identically to before |

## Changed files (this session)

Documentation only:

- `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Result.md` (this file, new)
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` (Living SSOT — appended a dated entry recording this Fresh Audit + Phase B decision, per its own "計画変更時にこの文書を都度更新する" convention)

No `lib/`, no `test/` file was created or modified.

## Tests / results

No production or test code changed, so no new test run is required to validate a behavior change. As a sanity check, `git status`/`git diff --check` were run after all edits (clean, no whitespace errors) and `git log` confirms `origin/main`'s HEAD used as this branch's base is unmodified by this session's docs-only commit.

## Save compatibility

Not applicable this session — no schema field was added, removed, or reinterpreted. The migration plan for the schema change this design implies (removing `PublicDemoEngineerSales.interviewRecord`/`genuineInterviewProjectId`, narrowing `stage`, adding `offerCandidates`) is fully specified above for whichever session implements Phase 1a/1b, including the mandatory legacy-fixture-load test gate.

## Known limitations

- This is a design deliverable, not working code — Finding #4 (parallel sales / offer selection) remains **unimplemented** in Public Demo after this session, exactly as it was after PR #247.
- The design above is this session's best judgment from a single-pass Fresh Audit; it has not been through the "self-hardening" or Codex Broad Review passes the task reserves for an actual implementation PR. Treat field/method names above as a strong proposal, not a locked API — Phase 1a's own implementer should re-verify every cited line number/behavior against whatever `origin/main` HEAD exists at that time, since other First Fun Year work continues to land on `main` concurrently (this session observed 5+ merges to `main` on 2026-09-11/12 alone).
- The Replacement Sales mini-cycle (`PublicDemoReplacementStage`) is explicitly out of scope and was only audited far enough to confirm it does not need to change for this design.
- Trade-flow/紹介元 authority (Issue #245 Finding #7) was not investigated in this session beyond what was already necessary to confirm the comparison UI (Phase 1c) must not fabricate it — that remains its own separate Fresh Audit.

## Next phase

Implement **Phase 1a** (domain-only `offerCandidates` + migration, as scoped above) as its own dedicated session/PR, following this design's own Phase split — do not attempt 1a+1b+1c in one PR. Recommended AI: Claude Code Sonnet. Estimated: 2-3h for 1a alone, matching this task's own stated per-phase budget.

## Final HEAD SHA

See the commit this file is part of on branch `claude/ses-parallel-sales-offers-4e18j7` (base: `origin/main` @ `afd34333c0e6a4f3db104e8159317bbdc068b544`).

## PR

Opened against `main` for user review of this design-only deliverable (see session output for the URL).

## Unresolved

- Whether Phase 1a should proceed immediately in a follow-up session, or wait for a Human Replay / product decision on exactly how many parallel candidates the UI should reasonably show at once (Main Game has no hard cap beyond `salesCapacity`; Public Demo may want a smaller, explicit cap for comprehension — this is a product call, not an authority constraint).
