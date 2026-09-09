# SES CORE-GAMEPLAY Phase 6: Project Interview Gameplay — Result

Status: **Implementation complete, Codex P1 review fix applied, `flutter analyze` clean, full test suite green (1947/1947)**

## BASE SHA / branch / HEAD

- Expected base per the task: `4994301314535186165ee8b45ad031b6a801fca5`.
- Actual `origin/main` at session start (`git fetch origin` re-confirmed,
  not trusted from repository metadata): **`4994301314535186165ee8b45ad031b6a801fca5`**
  ("Merge PR #212: CORE-GAMEPLAY Phase 5 Matching Decision Gameplay") — matches
  the expectation exactly.
- Branch: `claude/ses-phase-6-project-interview-vjxk32`. This branch's prior
  tip (`f4ca78f`, "Phase 0A/0B: SES domain models and random generators")
  was a stale ancestor of `origin/main` with no open PR, so it was reset
  onto the BASE SHA above (`git checkout -B ... origin/main`) before any
  new work, per the merged/stale-branch-reuse rule.
- Initial implementation HEAD: `8b208ea99124ff43cabd58f295a88c94878e6de0`
  ("CORE-GAMEPLAY Phase 6: Project Interview Gameplay") — this is the PR
  #214 HEAD Codex reviewed and left its P1 finding against (an earlier
  in-progress draft of this same commit was briefly amended twice while
  still unpushed, hence a stale intermediate SHA value this file itself
  once quoted here — `8b208ea...` is, and remains, the one that was
  actually pushed and reviewed).
- **Final HEAD SHA (this update, Codex P1 fix):** `43e481cba23fc700fb31e48cd3b3a5ecee1957aa`
  ("fix(project-interview): bind resumed sessions to the current matching
  proposal (Codex P1, PR #214)"). (A commit's hash covers its own tree, so
  amending this file after that hash was computed would change it again —
  this is the value actually pushed; not re-amended after this point.)

## Codex P1 review fix — "Bind resumed interviews to the proposed project"

**Finding (verified TRUE against actual code):** Codex flagged
`lib/game/public_demo/public_demo_workflow_state.dart:1090-1105`
(`startProjectInterviewSession`, as shipped in `8b208ea`) — its "already an
incomplete session? then resume, no-op" check matched only
`ClientInterviewSession.employeeId`, never `projectId`. Root-cause traced
by direct code reading: if the player closed an in-progress project
interview and then used the (unmodified) Matching screen to replace that
engineer's `PublicDemoMatchingProposal` with a *different* project
(`proposeMatch` has always freely allowed this, with no lock, at any time),
reopening the interview would resume the stale session — the old project's
questions/answers verbatim — while `PublicDemoAggregate
.chooseProjectInterviewFollowUp`/`concludeProjectInterview` always resolve
the *current* proposal's project fresh via `projectInterviewCandidateFor`.
The result: old questions scored against the new project's fit, and a
`clientInterviewPassed`/`Failed` outcome recorded for the wrong project —
exactly the "mixing old questions with a new project's scoring" Codex
described. Confirmed reproducible by a new failing-then-passing regression
test (`Codex P1 fix (PR #214)` group, test 2, in
`public_demo_project_interview_test.dart`) before/after the fix.

**Fix decision — option B (safe replace), not option A (reject the
proposal change):** `PublicDemoMatchingProposal`/`proposeMatch` has never
had a lock concept, and Matching's existing "at most one proposal per
engineer, a later call replaces the earlier one" contract
(`PublicDemoWorkflowState.withMatchingProposal`'s own doc) is unmodified
authority this phase must not touch. Rejecting a proposal change while an
interview is active would require new, invasive cross-cutting validation in
that unrelated file with no existing precedent. Safely discarding a
now-stale, project-mismatched session and replacing it with a fresh one for
the currently proposed project is a minimal, localized fix that keeps
every existing invariant (no dead end, retryable, atomic) intact.

**Fix** (`public_demo_workflow_state.dart`, `public_demo_aggregate.dart`):

- `startProjectInterviewSession`: the resume/no-op check now additionally
  requires `existing.projectId == session.projectId`. An incomplete session
  for a *different* project than the one just started is discarded (like a
  completed session already was) rather than resumed — never a bare
  `employeeId` match alone.
- `updateProjectInterviewSession` (defense in depth): now takes an explicit
  `projectId` parameter and only advances a session matching both
  `employeeId` and that `projectId` — a stale session left over for a
  since-replaced proposal can never be advanced against the wrong project
  even if some future caller skipped `startProjectInterviewSession` first.
  `PublicDemoAggregate.chooseProjectInterviewFollowUp` updated to pass its
  already-resolved `candidate.id` (the engineer's *current* proposal's
  project) through.
- `concludeProjectInterview` (defense in depth): now also requires
  `session.projectId == project.id` before deriving/applying an outcome —
  a mismatched session is a no-op (the engineer's stage is left untouched,
  never silently scored against the wrong project).
- `MatchingEngine`/`ClientInterviewEngine`/`ProjectInterviewEngine`/
  `SelectionEngine` were **not touched** — this is purely a
  session-identity/precondition fix in the Public-Demo-only workflow layer,
  exactly as scoped.

**Regression tests added** (`public_demo_project_interview_test.dart`,
group `Codex P1 fix (PR #214)`, 7 tests):

1. Same engineer/project → a second `startProjectInterview` call genuinely
   resumes the existing session (follow-up progress survives).
2. Changing the proposal mid-interview → the stale old-project session is
   never resumed; reopening replaces it with a fresh session bound to the
   new project (verified: new `projectId`, empty `playerFollowUps`,
   different session `id`).
3. Save/reload preserves the project binding of an in-progress session, and
   a reload still resumes correctly when the proposal is unchanged.
4. `concludeProjectInterview`/`projectInterviewFailureReasonsFor` never mix
   a fully-answered stale session with a newly-proposed different project —
   concluding is a no-op (engineer stage/session both left untouched) until
   the player reopens and gets a fresh, correctly-bound session.
5. Normal pass/fail flow (proposal never changed) is unaffected — a full
   interview still reaches a genuine `completed`/`result` and
   `clientInterviewPassed`/`clientInterviewFailed` stage.
6. Sales-slot behavior stays 0-slot (`state.salesUsed` unchanged) even
   across a mid-interview proposal change.

All pre-existing Phase 6 tests (15 domain + 8 widget from the initial PR)
continue to pass unmodified.

## Authority audit (READ-ONLY, before writing anything)

Audited current `main` before designing anything new, per the task's
explicit instruction to prefer newer main authority over a Public-Demo-only
duplicate:

| Authority | Location | Disposition |
|---|---|---|
| `ClientInterviewEngine` | `lib/game/engine/client_interview_engine.dart` | **Reused as-is.** Full interactive question/answer/follow-up/evaluate/finalRate engine already exists for the main game's own multi-step selection flow (`SelectionStep.clientInterview`). Not modified. |
| `ProjectInterviewEngine` | `lib/game/engine/project_interview_engine.dart` | **Reused as-is** for `successRate`/`roll`/`failureReasons`. Not modified. |
| `SelectionEngine` | `lib/game/engine/selection_engine.dart` | **Reused indirectly** — `ClientInterviewEngine.finalRate` already calls `SelectionEngine.successRate(..., SelectionStep.clientInterview)` internally. Not modified. |
| `MatchingEngine`/`FitBreakdown` | `lib/game/engine/matching_engine.dart` | **Not touched at all**, per the task's explicit prohibition. Reached only through the existing Phase 5 `PublicDemoEngineerProjectFit` adapter. |
| Trust/track record | `Engineer.companyTrust`, `PublicDemoEngineerSales.trust` | Read via the same placeholder `Engineer` Phase 5 already builds; `ClientInterviewEngine.evaluate` already folds `companyTrust`/`morale` into per-answer quality. |
| `PublicDemoRngNamespace.projectInterview` | `lib/game/public_demo/public_demo_rng.dart` | Was declared but **unused** by any code since Phase 1. **Now wired** — every Phase 6 seed derives through `PublicDemoRng.derivedSeed(..., namespace: PublicDemoRngNamespace.projectInterview, ...)`. |
| Phase 5 matching proposal handoff | `PublicDemoMatchingProposal`, `PublicDemoWorkflowState.matchingProposalFor`/`withMatchingProposal`, `PublicDemoAggregate.proposeMatch` | **Reused as-is**, the documented Phase 6 entry point. Not modified. |
| Existing Sales pipeline | `PublicDemoSalesStage` (`waiting → skillSheet → selling → introduced → partnerInterviewPassed/Failed → clientInterviewPassed/Failed → ordered`), `PublicDemoEngineerSales.evaluateInterview`, `PublicDemoInterviewEvaluator` | **Kept fully intact** as the fallback path for any engineer without a Phase 5 proposal (including every pre-Phase-6/legacy save). Phase 6 only *replaces what happens* at the existing `partnerInterviewPassed → client interview (0-slot)` transition when a genuine Phase 5 proposal exists — it does not add a new stage, remove the old one, or change its preconditions. |
| Sales-slot authority | `PublicDemoState.salesCapacity`/`salesUsed`/`useSalesSlot`/`useSalesSlotForInterview` | **Not touched.** Confirmed by audit that the existing partner-interview step is the only one of the two that consumes a slot; the client-interview step was already 0-slot before this phase and stays 0-slot. |
| Save codec | `PublicDemoWorkflowState.toJson`/`fromJson`, `PublicDemoAggregate.toJson`/`fromJson` | **Additive only** — one new top-level workflow key (`projectInterviewSessions`), following the exact precedent of Phase 3's `interviewSessions` and Phase 5's `matchingProposals` (both already documented as "additive, unrelated to X, present on every workflow JSON since this phase" in `public_demo_recovery_aggregate_test.dart`, which this phase extends the same way). |

**Conclusion:** no newer/duplicate "project interview" authority existed on
`main` beyond what's listed above. The existing generic
`PublicDemoInterviewEvaluator`-based client-interview step (in
`public_demo_interview.dart`/`public_demo_sales.dart`) is a genuinely
different, older, non-project-aware formula — kept unchanged as the
fallback, never modified or duplicated, per "既存Sales capacity・workflow
を壊さない".

## Implementation approach

**Required game flow**, mapped onto existing authority:

```
Matching (Phase 5, unchanged)
  → proposeMatch(engineerId, projectId)         [existing]
  → player advances engineer: skillSheet → selling
    → introduced → partner interview (1 slot)   [existing, unchanged]
    → partnerInterviewPassed                    [existing stage]
  → 案件面談 entry point (NEW, Phase 6):
      PublicDemoAggregate.startProjectInterview(engineerId)
        - no-op unless partnerInterviewPassed AND a real Phase 5
          proposal/candidate/runtime resolve (no proposal → falls back
          to the existing generic ei()/recordEngineerInterviewResult path,
          unchanged, so legacy saves and "Matching-skipped" playthroughs
          are unaffected)
      → real multi-question interactive interview (ClientInterviewEngine)
      → chooseProjectInterviewFollowUp(engineerId, choice) per question
      → concludeProjectInterview(engineerId)
  → pass  → clientInterviewPassed + genuine interviewRecord minted
          → existing recordOrder/assignOrderedForMay (Phase 7A handoff),
            UNCHANGED
  → fail  → clientInterviewFailed → existing beginSelling() recovery,
            UNCHANGED (no dead end)
```

New files (Public-Demo-only adapters/UI, never a second interview formula):

- `lib/game/public_demo/public_demo_project_interview.dart` —
  `PublicDemoProjectInterview`, the adapter onto
  `ClientInterviewEngine`/`ProjectInterviewEngine`, mirroring the exact
  shape of the Phase 3 `PublicDemoRecruitmentInterview` adapter
  (`start`/`chooseFollowUp`/`conclude`, all thin wrappers with zero
  independent game-math).
- `lib/ui/public_demo/public_demo_project_interview_dialog.dart` — the
  interactive modal (mirrors `PublicDemoRecruitmentInterviewDialog`'s
  "commit on every tap, resumable" shape; question/follow-up presentation
  mirrors the main game's own `ClientInterviewScreen`, reusing
  `ClientInterviewEngine.choices`/`clientInterviewFollowUpLabels`
  verbatim).

Modified files:

- `lib/game/public_demo/public_demo_matching_fit.dart` — added one public
  accessor, `PublicDemoEngineerProjectFit.engineerFor`, exposing the
  existing private placeholder-`Engineer` builder so Phase 6 uses the
  *exact same* placeholder Engineer Phase 5 already scored, rather than
  building a second one that could drift.
- `lib/game/public_demo/public_demo_sales.dart` — added
  `PublicDemoEngineerSales.applyProjectInterviewResult({passed, score})`,
  structurally mirroring `evaluateInterview` (same stage-precondition gate,
  same "mint the record only on a genuine pass" contract). Its only
  production call site computes `passed`/`score` immediately beforehand via
  a fresh `PublicDemoProjectInterview.conclude` call — never a
  caller-asserted outcome with no real interview behind it.
- `lib/game/public_demo/public_demo_workflow_state.dart` — added the
  additive `projectInterviewSessions` list (persistence) and three
  transitions: `startProjectInterviewSession`, `updateProjectInterviewSession`
  (both simple id-keyed append/replace, mirroring the Phase 3 recruitment
  session methods exactly), and `concludeProjectInterview` (the one place
  the real `ClientInterviewEngine.finalRate` + `ProjectInterviewEngine.roll`
  derivation happens, gated on the existing `partnerInterviewPassed`
  precondition and on every question already having a player-chosen
  follow-up).
- `lib/game/public_demo/public_demo_aggregate.dart` — added
  `projectInterviewCandidateFor`, `projectInterviewSessionFor`,
  `startProjectInterview`, `projectInterviewChoicesFor`,
  `chooseProjectInterviewFollowUp`, `concludeProjectInterview`,
  `projectInterviewFailureReasonsFor` — the public command surface, all
  no-ops without a genuine Phase 5 proposal + runtime.
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — the two
  existing "客先面談" entry points (the HOME recommended-action emit and the
  Sales-tab card button) now call a new `_startClientInterview(i)` dispatcher:
  opens the new interactive dialog when `projectInterviewCandidateFor`
  resolves a real proposal, otherwise calls the existing `ei(i, client)`
  path completely unchanged. No other UI flow was touched.
- `test/game/public_demo/public_demo_recovery_aggregate_test.dart` — updated
  the one pre-existing hardcoded workflow-JSON key-set assertion to include
  the new additive `projectInterviewSessions` key (same pattern already
  used there for Phase 3's/Phase 5's own additive keys). No assertion was
  weakened; the test's own purpose (Recovery introduces no *unexpected*
  schema drift) is unchanged and still enforced.

## Outcome authority (never a coin flip)

Final pass/fail rate: `ClientInterviewEngine.finalRate(engineer, project,
session)` = `SelectionEngine.successRate(engineer, project,
SelectionStep.clientInterview)` (fit + personality + trust-derived, from the
existing `MatchingEngine.computeFit`) `+ session.accumulatedEvaluation.total`
(clamped ±15; the sum of every player choice's effect across the whole
interview), clamped to `[5, 95]`. Rolled via
`ProjectInterviewEngine.roll(rate, seed, week, salt)` — a single seeded
`Random.nextInt(100) < rate` draw, never a raw 50/50 flip and never decided
by the roll alone (the rate itself already reflects fit + choices + trust
before any randomness is applied).

## RNG derivation

Every draw for one `(engineer, project)` interview keys off one seed:

```
seed = PublicDemoRng.derivedSeed(
  runSeed: state.runSeed,
  month: session.startedWeek,   // the month the interview began
  namespace: PublicDemoRngNamespace.projectInterview,
  identifier: '<engineerId>:<projectId>',
)
```

- Question selection (`ClientInterviewEngine.questions`) and every
  follow-up's deep-dive draw (`ClientInterviewEngine.evaluate`) use this
  seed directly.
- The final pass/fail roll salts it further with the session id and the
  full, ordered list of the player's own follow-up choice names
  (`'public-demo-project-interview-result:<sessionId>:<choice1,choice2,...>'`),
  mirroring the main game's own `chooseClientInterviewFollowUp`/
  `_completeClientInterview` salt convention exactly — so two different
  choice sequences can roll differently even when they happen to reach the
  same clamped rate.

**Determinism guarantee:** `(runSeed, month, engineerId, projectId,
playerFollowUps)` is a pure function → the same result every time, verified
by a dedicated domain test (`public_demo_project_interview_test.dart`,
"determinism" group) that replays the identical seed/context/choice
sequence twice and asserts byte-identical stage/score/session-result.
Nothing here is a `Random()` instance held across calls — every draw is
freshly derived per Phase 1's `PublicDemoRng` contract, so a save
reload can always recompute the same stream.

## Player choices and their effect

`ClientInterviewEngine.questions` selects 3 categories (technical
experience, industry experience, leadership, role experience, teamwork,
trouble-handling, communication, work style) ranked by real relevance to
the specific project's requirements and the engineer's real SkillSheet.
For each question the player picks one of 3 follow-up responses
(`ClientInterviewFollowUp`: emphasize-technical / emphasize-industry /
emphasize-leadership / emphasize-communication / adjust-expectation /
let-employee-handle, depending on category) — `ClientInterviewEngine
.evaluate` turns that choice, combined with the engineer's own real
answer quality and the question's real mismatch (gap between the
SkillSheet's claim and the engineer's actual skill), into a signed
per-question evaluation delta (technical/experience/communication/
credibility/clientFit) that accumulates into `session.accumulatedEvaluation`
and directly shifts the final clamped rate — the same "choices are not
decorative" test asserts two different full choice sequences reliably
produce different accumulated totals for the same fixed fit/seed.
Overreaching on a mismatched claim risks a deep-dive follow-up question
that *lowers* the score instead — a bad choice can genuinely hurt.

## Sales-slot behavior

- `startProjectInterview` / `chooseProjectInterviewFollowUp` /
  `concludeProjectInterview` never call `PublicDemoState.useSalesSlot()` /
  `useSalesSlotForInterview()` and never read/write `salesUsed` — verified
  by a dedicated regression test asserting `state.salesUsed` is bit-for-bit
  unchanged across the whole interactive flow.
- The existing partner-interview step (`introduced → partnerInterviewPassed`,
  unchanged) is confirmed, by a second regression test, to still consume
  exactly one slot — Phase 6 does not touch it, so there is no double
  consumption and the shared monthly budget with recruitment interviews is
  preserved exactly as before.

## Persistence

Additive only, following the Phase 3 `interviewSessions` precedent exactly:

- New field `PublicDemoWorkflowState.projectInterviewSessions:
  List<ClientInterviewSession>` (the same model class the main game's own
  `GameState.clientInterviews` already uses — reused verbatim, no new
  session model invented).
- `toJson` always emits the key; `fromJson` treats a missing key as an empty
  list (verified: a legacy save with the key stripped decodes cleanly).
- A full aggregate save with an in-progress or completed project-interview
  session round-trips byte-for-byte (`toJson → fromJson → toJson` equality,
  both mid-interview and post-conclusion) — verified by dedicated tests.
- `public_demo_recovery_aggregate_test.dart`'s hardcoded schema-snapshot
  test was updated (not weakened) to include the new key, exactly like it
  already documents doing for Phase 3/Phase 5's own additive keys.

## Success/fail handoff

- **Pass:** `PublicDemoEngineerSales.applyProjectInterviewResult(passed:
  true, ...)` sets `stage: clientInterviewPassed` and mints a genuine,
  unforgeable `PublicDemoEngineerInterviewRecord` — the same record type
  `hasGenuineInterviewRecord`/`assignOrderedForMay` already require. The
  existing, **completely unmodified** `recordOrder` → `assignOrderedForMay`
  pipeline (Phase 7A's own order/assignment authority) accepts this exactly
  as it already accepts a generic client-interview pass — verified by a
  test that drives a Phase 6 pass through to a real `ordered` stage via the
  existing `recordOrder` call.
- **Fail:** `stage: clientInterviewFailed` — the existing `beginSelling`
  transition (already accepting `clientInterviewFailed` as a valid source
  stage, unchanged) lets the player return to selling and retry, for the
  same or a newly-proposed project. No new terminal/dead-end state is
  introduced.
- Retrying: `startProjectInterviewSession` replaces a stale *completed*
  session for the same engineer with a fresh one (a still-*in-progress*
  session is resumed, never restarted) — so a fail is never a hard stop.

## HOME/UI wiring

Both existing "客先面談" entry points (the HOME recommended-action shortcut
and the Sales tab's own card button) now dispatch through
`_startClientInterview`, which opens the new interactive dialog only when
`PublicDemoAggregate.projectInterviewCandidateFor` resolves a genuine Phase
5 proposal; otherwise they fall back to the pre-existing `ei(i, client)`
call unchanged. No other screen, tab, or navigation route was touched. HOME
itself is unmodified.

## Information discipline

- No raw `HiddenParameters`, `FitBreakdown.total`, or the interview's own
  clamped `rate`/`accumulatedEvaluation` total is ever passed to a widget —
  the dialog only receives `passed`/`session` (for interviewer-reaction
  text and question/answer copy) and, on failure,
  `projectInterviewFailureReasonsFor`'s already-truthful, `MatchingEngine`
  -derived reason strings (`ProjectInterviewEngine.failureReasons`, reused
  verbatim, never a fabricated cause). Verified by a widget test asserting
  no `%`/numeric-score text appears anywhere in the result phase.

## Tests

New:

- `test/game/public_demo/public_demo_project_interview_test.dart` (22
  tests, 15 from the initial PR + 7 Codex P1 regression tests added in this
  update): start/no-op preconditions, resume-not-restart, determinism,
  choice-materially-affects-outcome, non-degenerate pass/fail distribution
  (not a disguised coin flip), truthful failure reasons, 0-slot/no-double-
  consumption regressions, pass→`recordOrder`→`ordered` Phase 7A handoff,
  fail→`beginSelling` continuation, three persistence/round-trip tests
  (in-progress, legacy-missing-key, full strict round-trip), and the
  `Codex P1 fix (PR #214)` group covering the resumed-session
  project-binding fix (see that section above for the full list).
- `test/ui/public_demo/public_demo_project_interview_dialog_test.dart` (8
  tests): question/answer/follow-up rendering and advancement, full
  interview-to-result flow with no raw score/percentage shown, and
  viewport/TextScaler regression across all 6 required combinations
  (390×844 / 360×800 × 1.0 / 1.3 / 2.0), each also driving one real
  follow-up tap (the densest on-screen content state) with zero exceptions.

Updated:

- `test/game/public_demo/public_demo_recovery_aggregate_test.dart` — added
  the new additive schema key to the existing hardcoded key-set assertion
  (no assertion removed or loosened).

Verification run (this update, after the Codex P1 fix):

```
flutter analyze            → No issues found!
flutter test --concurrency=6 → 1947/1947 passed
git diff --check           → clean (no whitespace errors)
```

No existing test was deleted, skipped, or weakened.

## Known limitations

- The generic, pre-Phase-6 `PublicDemoInterviewEvaluator`-based client
  interview remains reachable and unchanged for any engineer without a
  Phase 5 proposal — by design (legacy-save/skip-Matching compatibility),
  not an oversight. A player who never uses the Matching screen never sees
  the new interactive interview.
- `PublicDemoAssignment`'s own project name/economic fields are still
  populated by the existing `assignOrderedForMay`/`forOrderedEngineer`
  template logic (generic humanity/pressure/health defaults), not yet
  keyed to the specific project the player interviewed for — full
  assignment lifecycle/CareerHistory wiring is explicitly out of scope for
  Phase 6 per the task (Phase 7A/7B).
- A project interview session is retried fresh (new questions) rather than
  resuming the exact same question set after a fail — intentional, since a
  fail returns the engineer through `selling`/`introduced`/partner
  interview again before a new client interview can start, by which point
  the month has very likely advanced and a fresh seed/question draw is the
  more honest choice.

## Phase 7A handoff

On a genuine pass, the engineer carries: `stage ==
PublicDemoSalesStage.clientInterviewPassed`, a real
`PublicDemoEngineerInterviewRecord` (`hasGenuineInterviewRecord == true`),
`lastInterviewScore` set, and — recoverable at any time via
`PublicDemoAggregate.projectInterviewCandidateFor(engineerId)` — the exact
real Phase 4/5 `PublicDemoProjectCandidate`/`Project` the player interviewed
for (never discarded; regenerable purely from `runSeed` + the still-present
`PublicDemoMatchingProposal`). Phase 7A can read this candidate directly
when building the full order/assignment/CareerHistory record, rather than
falling back to `assignOrderedForMay`'s generic per-engineer template — that
wiring itself is left to Phase 7A, per this phase's explicit scope limit.

## Actual processing time

**Initial Phase 6 implementation:** approximately 2 hours (within the
90–150 minute estimate's upper range, extended somewhat by the full
authority audit across Phase 0–5 and a viewport-test root-cause
investigation for a `ListView` sliver-virtualization edge case at
360×800/TextScaler 2.0, resolved by switching the dialog's scrollable
content to `SingleChildScrollView`).

**This update (Codex P1 fix):** approximately 25 minutes, within the
15–30 minute estimate.
