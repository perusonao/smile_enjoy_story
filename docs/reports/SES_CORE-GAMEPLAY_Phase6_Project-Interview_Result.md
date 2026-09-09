# SES CORE-GAMEPLAY Phase 6: Project Interview Gameplay — Result

Status: **Phase 6 closed pending this update's merge-gate re-review. Merged onto latest `main` (PR #213); every Codex finding through this update fixed (P1, P1-1, P1-2, P2 duplicate-follow-up, P2-1 malformed-session-restore, P2-2 dialog-launch-serialization, P2 proposal/pass authority-chain, and this update's two scoped fixes: P2 duplicate-proposal rejection and P2 accumulated-evaluation recomputation) — no new broad audit performed this update, per explicit scope limit; `flutter analyze` clean, full test suite green (1998/1998)**

## BASE SHA / branch / HEAD

- Expected base per the original task: `4994301314535186165ee8b45ad031b6a801fca5`.
- Actual `origin/main` at initial session start (`git fetch origin`
  re-confirmed, not trusted from repository metadata): **`4994301314535186165ee8b45ad031b6a801fca5`**
  ("Merge PR #212: CORE-GAMEPLAY Phase 5 Matching Decision Gameplay") — matched
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
- HEAD after the Codex P1 fix: `c0581fa36b8904252d1b7b22f5cc51901c830c34`
  ("fix(project-interview): bind resumed sessions to the current matching
  proposal (Codex P1, PR #214)") — the report's own SHA line at the time
  quoted `43e481c...`, an intermediate value from before a same-session
  amend; `c0581fa` is, and remains, the one actually pushed and reviewed.
- **Expected `main` for this integration update:** `d07ef6b534c8f74b23e9e15583f89ea52a6bb898`
  ("Merge PR #213: fix Phase 5 save migration compatibility") — re-confirmed
  via a fresh `git fetch origin` as the actual `origin/main` tip, matching
  the task's expectation exactly.
- HEAD after the main-integration + save-codec fix:
  `038369d8e83f9b18e0b8fdcfad9b0be794394451` ("fix(save): migrate
  interviewSessions/projectInterviewSessions before strict save
  comparison") — this is the PR #214 HEAD Codex reviewed and left its
  P1-1/P1-2/P2 findings against.
- HEAD after the Codex P1-1/P1-2/P2 fixes:
  `d9c6a09851de1179db4d0e7257c99a64e5c10baa` ("fix(project-interview):
  address Codex P1-1/P1-2/P2 findings on PR #214") — the report's own SHA
  line at the time quoted `7a0c5d8...`, an intermediate value from before a
  same-session amend; `d9c6a09` is, and remains, the one actually pushed
  and reviewed. This is the HEAD Codex reviewed and left the new
  "Ignore duplicate follow-up submissions" P2 finding against.
- HEAD after the Codex duplicate-follow-up P2 fix:
  `40fa9434d94512a26b3af70c92bc8b264037f354` ("fix(project-interview): reject
  duplicate/stale follow-up submissions at the authority boundary (Codex P2,
  PR #214)") — the report's own SHA line at the time quoted `d42d70c...`, an
  intermediate value from before a same-session amend; `40fa943` is, and
  remains, the one actually pushed and reviewed. This is the HEAD Codex
  reviewed and left the new "Reject malformed project-interview sessions
  during restore" (P2-1) and "Serialize project-interview dialog launches"
  (P2-2) findings against.
- HEAD after the Codex P2-1/P2-2 fixes: `5e67f42d4dc47b1d66e20fa00e960c1a6ae12d27`
  ("fix(project-interview): validate restored sessions and serialize dialog
  launches (Codex P2-1/P2-2, PR #214)") — the report's own SHA line at the
  time quoted `c34831d...`, an intermediate value from before a same-session
  amend; `5e67f42` is, and remains, the one actually pushed and reviewed.
  This is the HEAD Codex reviewed and left the new "Validate restored passes
  against their proposals" P2 finding against — the one addressed, alongside
  the FINAL HARDENING audit, by this update.
- HEAD after the Codex P2 authority-chain fix + Final Hardening audit:
  `7dd3326c163662c053168e356ac18be6d82685a6` ("fix(project-interview):
  cross-check restored project-bound passes against their proposal/session
  (Codex P2, PR #214) + Phase 6 Final Hardening audit") — the report's own
  SHA line at the time quoted `700752f...`, an intermediate value from
  before a same-session amend; `7dd3326` is, and remains, the one actually
  pushed and reviewed. This is the HEAD Codex reviewed and left the two new
  findings against that this update fixes: "Reject duplicate proposals
  before validating pass bindings" (P2) and "Validate restored accumulated
  interview evaluation" (P2).
- **Final HEAD SHA (this update, the two scoped P2 fixes above; NO new
  broad audit):** `930f2f7d08e5d535a1bf77b12a4409b30a357652`
  ("fix(project-interview): reject duplicate matchingProposals and
  recompute accumulatedEvaluation on restore (Codex P2 x2, PR #214)").
  Note: this hash is the value actually committed and pushed; because this
  file documents its own commit's hash, the file's bytes at the moment of
  that commit necessarily differ infinitesimally from what a fresh re-hash
  would produce (the well-known self-reference limit for a report that
  names its own SHA) -- this value is not re-amended after this point and
  is the one used consistently in the PR reply and final response.

## Main integration (PR #213 → PR #214)

`git merge origin/main` from `c0581fa` produced a **clean merge, zero
conflicts**: PR #213 touched only `lib/game/persistence/
public_demo_save_codec.dart`, its test file, and the Phase 5 result
report — none of which Phase 6 had touched — so no Phase 6 authority
(including the Codex P1 fix from the previous update) needed to change to
absorb it. The merge commit itself (`5c13dbf...`) is a pure merge, no
manual resolution.

**A second save-codec gap was found and fixed during this integration**
(not a merge conflict — a latent bug the merge made newly relevant to
verify): see the next section.

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

## Save-codec gap found during main integration — "interviewSessions /
## projectInterviewSessions never spliced into the strict-comparison baseline"

**How this was found:** PR #213 (now on `main`) fixed `PublicDemoSaveCodec`
so a legacy save missing `matchingProposals` or an `engineerRuntime`'s
`totalItExperienceMonths` no longer gets wholesale-rejected by the strict
round-trip comparison — both are spliced into the comparison baseline
before the byte-for-byte check. This task's own checklist asked to
specifically verify `projectInterviewSessions`/`interviewSessions` against
exactly that same "`PublicDemoSaveCodec` strict round-trip" / "legacy save"
concern, so — rather than only re-running the existing tests — a direct
probe was written: build a fresh aggregate, encode it, strip the
`interviewSessions` key from the decoded JSON, and call
`PublicDemoSaveCodec.fromJson` on it directly. **Confirmed: it returned
`null`** (the whole save rejected), and the identical probe for
`projectInterviewSessions` **also returned `null`** — even though
`PublicDemoWorkflowState.fromJson` itself already tolerates either key
being absent (defaults to `[]`). This is the exact same failure mode PR
#213 already documents and fixed for `matchingProposals`/
`totalItExperienceMonths`, just never extended to these two additive
session lists — `interviewSessions` (CORE-GAMEPLAY Phase 3) predates even
`matchingProposals` and was apparently never covered by any prior fix;
`projectInterviewSessions` is this Phase 6 PR's own field, carrying the
identical gap from day one.

**Fix** (`public_demo_save_codec.dart`): added
`_withMigratedInterviewSessions`/`_withMigratedProjectInterviewSessions`,
mirroring `_withMigratedMatchingProposals` exactly — each splices the
already-decoded, defaulted session list into the comparison baseline only
when its key is absent from the original envelope; a no-op once a save
genuinely already carries it. No gameplay/domain authority was touched —
purely a save-codec comparison-baseline fix, the same established pattern.

**Verified fixed:** the same two probes now both return a real, non-null
aggregate with the expected empty session lists. Three permanent regression
tests were added to `public_demo_save_codec_test.dart`:

1. A save missing **both** `interviewSessions` and `projectInterviewSessions`
   (a save written before CORE-GAMEPLAY Phase 3) still decodes.
2. A save that already carries a real recruitment `interviewSession`
   round-trips it exactly — the migration only ever fires for an absent
   key, never overriding a genuinely-present one.
3. A save that already carries a real `projectInterviewSession` (with its
   real `engineerId`/`projectId` binding intact) round-trips it exactly,
   same non-override guarantee.

## Codex P1-1/P1-2/P2 review fixes (this update)

Three new findings on the post-main-integration HEAD
(`038369d8e83f9b18e0b8fdcfad9b0be794394451`). All three root-caused by
direct code reading before any fix was written; all three fixed with the
smallest change that closes the gap without touching `MatchingEngine`,
Finance/Month/Balance, HOME, or the Phase 7A lifecycle.

### P1-1 — "Preserve stochastic passes when decoding saves"

**Root cause:** `PublicDemoSaveCodec._hasConsistentAuthorityFacts` rejected
any `clientInterviewPassed`/`ordered` engineer whose `lastInterviewScore` was
below 60 — a rule written for the legacy `PublicDemoInterviewEvaluator`,
whose `passed = score >= 60` really is a hard floor. Phase 6's own
`ClientInterviewEngine.finalRate` + `ProjectInterviewEngine.roll` can
legitimately **pass at any rate in its own clamped `[5, 95]` range** — a
genuine pass at, say, 45 is exactly what "small seeded RNG on top of a real
fit/choice-driven rate" means. That save was writable but silently
discarded as "inconsistent" on the very next reload — real player progress
lost.

**Fix:** `PublicDemoEngineerInterviewRecord` gained an optional `projectId`
(see P1-2 below — the two findings share one field). `_hasConsistentAuthorityFacts`
now reads `interviewRecordProjectId`: `null` (the legacy, project-agnostic
path) still requires `score >= 60`, **unconditionally, unchanged**; a real
project id (a genuine Phase 6 pass) requires `score` in `[5, 95]` instead —
Phase 6's own real range, never an unconditional pass-through. The new
field is additive and spliced into the save-codec's comparison baseline for
any save written before this fix (mirrors the existing per-entry
`totalItExperienceMonths` splice), so no existing save is affected.

### P1-2 — "Bind a passing record to the interviewed project"

**Root cause:** `PublicDemoEngineerInterviewRecord` only ever stored
`engineerId` — no project. After a genuine pass, `proposeMatch` still
happily replaced that engineer's `PublicDemoMatchingProposal` with a
*different*, never-interviewed project (it only checked assignment status),
and `recordOrder` would then succeed using the old, employee-only record —
ordering for a project this engineer was never actually vetted for. Fresh
evidence confirmed this was still reachable even after the prior Codex P1
in-progress-session fix, which only protected an *incomplete* session, not
an already-*completed* pass.

**Fix:** `PublicDemoEngineerInterviewRecord.projectId` (added for P1-1
above) is minted with the real interviewed project's id on every genuine
Phase 6 pass (`PublicDemoEngineerSales.applyProjectInterviewResult`).
`PublicDemoWorkflowState.withMatchingProposal` now refuses to replace a
proposal once the engineer has reached `clientInterviewPassed`/`ordered` —
the proposal is permanently locked to the interviewed project from that
point on (a *failed* interview is unaffected and stays freely
re-proposable, exactly as before). `PublicDemoAggregate
.availableEngineersForMatching` also now excludes such engineers, so
Matching no longer offers a "提案する" that would silently no-op. This was
the option explicitly recommended over locking `recordOrder` itself: the
proposal can now never drift from the passed project in the first place, so
there is nothing left for `recordOrder`/Phase 7A to need to cross-check.

### P2 — "Freeze capability for the duration of an interview"

**Root cause:** `PublicDemoState`'s own engineer runtime only ever changes
at a month-close boundary — confirmed by reading
`PublicDemoInternalTrainingTransaction.execute`, which only records a
training *selection* mid-month (`state.selectInternalTraining`); the actual
capability change lands later, via `applyMonthlyGrowth` at the next close.
`startProjectInterviewSession`'s resume check (already fixed for `projectId`
mismatch) never checked *when* the existing session was started: if the
player closed an incomplete interview, let a month pass, and reopened it,
the stale session's old-month questions/answers would be resumed and then
scored (`chooseFollowUp`/`conclude`) against the engineer's new-month
runtime — exactly the "old conversation state mixed with post-growth fit"
Codex described.

**Fix (minimal, no fake snapshot data):** `ClientInterviewSession
.startedWeek` already exists and is already persisted — no new field was
added. `startProjectInterviewSession`'s resume condition now also requires
`existing.startedWeek == session.startedWeek` (the freshly-built session's
own `startedWeek` is always the current month); a mismatch is treated
exactly like the existing projectId-mismatch case — the stale session is
discarded and a genuinely fresh one (new questions, current-month capability)
replaces it, never resumed. `concludeProjectInterview` gained the matching
defense-in-depth guard (`session.startedWeek == currentMonth`), mirroring
the existing `projectId` guard from the prior Codex P1 fix. Verified against
real production month-close code (`closeApril`) in a scratch probe before
writing the permanent test: an unassigned engineer's stage/proposal/session
are all left untouched by the close itself, and only the *next*
`startProjectInterview` call correctly discards the stale session.

### Regression tests added (this update)

`public_demo_project_interview_test.dart` (6 new tests): proposing a
different project after a genuine pass is a no-op and the engineer
disappears from `availableEngineersForMatching`; `recordOrder` still
succeeds normally for the actually-passed project; a *failed* interview
stays freely re-proposable (proving the lock is pass-specific); advancing
the month mid-interview forces a safe restart with zero carried-over
follow-ups; both the P1-2 project lock and the P2 month-freshness check
survive a save/reload round-trip.

`public_demo_save_codec_test.dart` (5 new tests): a genuine low-score
(`<60`) Phase 6 pass is accepted; the identical low score *without* a
project binding is still rejected (the legacy floor is provably
unweakened); a score above the `[5, 95]` ceiling on a project-bound record
is rejected too; a save missing the new `interviewRecordProjectId` key
entirely still decodes; a real end-to-end interview (genuine seeded roll,
not a hand-crafted fixture) round-trips its project binding exactly.

All pre-existing Phase 6 tests (28 domain + 8 widget, including the entire
prior Codex P1 regression group) continue to pass unmodified.

## Codex P2 review fix (this update) — "Ignore duplicate follow-up submissions"

**Finding (verified TRUE by direct code reading):** `PublicDemoProjectInterview
.chooseFollowUp` applied a follow-up to `session.currentQuestionIndex`
unconditionally — nothing checked whether that exact question had already
received one. If the same logical player action reached the authority layer
twice (a rapid double tap before a rebuild swaps out the pressed button, a
duplicated accessibility activation, or any other caller invoking the
command twice for what the player experienced as one choice), the second
call would either (a) for a non-final question, apply the stale,
player-unintended `followUp` value to the question the session had *already
advanced to*, silently skipping the player's real decision for it, or (b)
for the final question (whose `currentQuestionIndex` never advances once
answered), re-run `ClientInterviewEngine.evaluate` a second time and add its
result into `accumulatedEvaluation` again — corrupting the seeded
`finalRate`/`conclude` outcome the player never actually chose.

**Root-cause analysis — why a simple "already answered" flag on the session
alone cannot fully catch this:** `session.currentQuestionIndex` and
`session.playerFollowUps.length` advance together for every non-final
question, so a stale duplicate arriving after a genuine advance looks
*identical* to a legitimate first answer for the new current question —
there is no way to distinguish "the player's real answer for question K+1"
from "a stale echo of their answer for question K, misapplied to K+1" using
only the session's own current state. The only way to detect a stale
resubmission is for the caller to say *which* question it believes it is
answering, captured at the moment the player actually made the choice, so
authority can reject it once the session has since moved past that index.

**Fix (minimal, authority-enforced, no reliance on UI disabling):**

- `PublicDemoProjectInterview.chooseFollowUp` gained a required
  `questionIndex` parameter. It is now a no-op unless **both**
  `questionIndex == session.currentQuestionIndex` **and**
  `questionIndex == session.playerFollowUps.length` hold (plus an in-range
  bounds check). Verified this pair — not either alone — correctly rejects
  a duplicate on every question: `currentQuestionIndex` alone misses the
  final-question case (it never advances there), and `playerFollowUps
  .length` alone is otherwise implied by `currentQuestionIndex` for a
  fresh/valid submission, so the combination is exactly "this question has
  not yet received its one follow-up."
- `followUp` is additionally required to be one of
  `ClientInterviewEngine.choices(question)`'s own offered values for that
  exact question — never an arbitrary enum value the UI never actually
  presented (every category offers only 3 of the 6
  `ClientInterviewFollowUp` values, so this is a real, non-vacuous check).
- `PublicDemoAggregate.chooseProjectInterviewFollowUp` threads the new
  `questionIndex` straight through — the aggregate itself derives/asserts
  nothing about it, exactly like every other value that crosses this
  boundary in this file.
- `PublicDemoProjectInterviewDialog` now captures `session
  .currentQuestionIndex` from the specific `ClientInterviewSession` **local
  variable** `build()` actually rendered the pressed follow-up button from,
  and closes over that captured value — never re-reading `_session`/
  `_aggregate` (the mutable State fields) at tap time, which could already
  reflect a prior tap's own advance by the time a second, stale tap on the
  same (not-yet-rebuilt) button is processed. This is what makes the
  authority-level rejection actually reachable from a genuine double-tap,
  rather than the UI accidentally self-correcting via field mutation timing
  — the fix does not depend on, or assume anything about, that timing.
- `MatchingEngine`, Finance/Month/Balance, HOME, and the Phase 7A lifecycle
  were not touched — purely a duplicate-submission guard in the Phase
  6-only interview adapter/aggregate/dialog.

**Regression tests added** (`public_demo_project_interview_test.dart`,
group `Codex P2 fix (PR #214): duplicate/stale follow-up submissions are
ignored at the authority boundary`, 11 tests): the same follow-up submitted
twice in a row is a no-op the second time; a double submit on a non-final
question does not skip that question's real successor; a double submit on
the *final* question does not double-add its evaluation; a follow-up not
among the current question's offered choices is rejected; a follow-up for a
stale, already-advanced question index is rejected even when the choice
value is otherwise valid; a negative or out-of-range index is rejected;
normal valid progression through every question still completes and
concludes correctly; save/reload preserves progress and the stale-duplicate
rejection keeps working identically after a reload; determinism is
unaffected (replaying the same seed/choices through the new, validated API
reproduces the same result).

All pre-existing Phase 6 tests (37 domain including the full P1/P1-1/P1-2/P2
regression history + 8 widget) continue to pass unmodified — the existing
widget test suite in particular already exercised the real
`PublicDemoProjectInterviewDialog` tap flow end-to-end and needed no changes
to keep passing, confirming the new `questionIndex` capture is transparent
to normal, non-duplicate play.

## Codex P2-1/P2-2 review fixes (this update)

### P2-1 — "Reject malformed project-interview sessions during restore"

**Finding (verified TRUE by direct code reading):**
`ClientInterviewSession.fromJson` only casts fields — it never checks that
they describe a coherent interview. A save with, say, an empty `questions`
list or an out-of-range `currentQuestionIndex` decodes without throwing and
re-encodes byte-for-byte identical to what it decoded from (nothing about
these values is normalized away), so `PublicDemoSaveCodec`'s strict
round-trip comparison — the only other gate a save has to pass — accepted
it. The dialog's own `session.questions[session.currentQuestionIndex]` /
`session.employeeAnswers[session.currentQuestionIndex]` indexing then
crashes the first time the player reopens that interview, instead of the
corrupt save ever being rejected up front.

**Fix (in `PublicDemoSaveCodec._hasConsistentAuthorityFacts`, the same gate
that already rejects other impossible-from-production combinations — see
its existing engineer/assignment checks above):** every
`workflow.projectInterviewSessions` entry, when present, is now validated
against the exact structural invariants every session
`PublicDemoProjectInterview.start`/`chooseFollowUp` can ever actually
produce — none of this is a new restriction on real gameplay, only
enforcing here what production code already guarantees:

- **Identity:** `applicationId == projectId` and
  `id == 'public-demo-project-interview:$employeeId:$projectId'` — both
  always true for a genuine session, so a mismatch proves the entry did not
  come from `start()`.
- **Duplicate session identity:** at most one entry per `employeeId` — a
  second entry for the same engineer is unreachable from
  `startProjectInterviewSession`/`projectInterviewSessionFor`, both of
  which assume exactly this.
- **Employee identity:** `employeeId` must name an engineer that actually
  exists elsewhere in the same save (`workflow.engineers`).
- **`startedWeek` vs. existing authority:** `1 <= startedWeek <= month` — a
  session cannot have started after the month this same save records
  having reached.
- **`questions` non-empty**, and `0 <= currentQuestionIndex < questions.length`.
- **`employeeAnswers` in lockstep:** `employeeAnswers.length ==
  currentQuestionIndex + 1` — `ClientInterviewEngine.answer` always
  pre-computes exactly one answer ahead of, and including, the current
  question.
- **`playerFollowUps`/`interviewerReactions` progression invariant:**
  `chooseFollowUp` advances `currentQuestionIndex` in lockstep with
  `playerFollowUps.length` for every question except the last (which never
  advances past itself), so a valid session has either
  `playerFollowUps.length == currentQuestionIndex` (this question not yet
  answered) or, only once `currentQuestionIndex` is the final index,
  `playerFollowUps.length == questions.length` (every question answered,
  ready for `conclude`) — any other combination cannot come from
  `chooseFollowUp`. `interviewerReactions.length` must equal
  `playerFollowUps.length` (appended together, every call).
- **completed/incomplete invariants:** `completed` may only be `true`
  together with the "every question answered" case above and a genuine
  `result` (`'passed'`/`'failed'`) — only `conclude` ever sets either, and
  always together.

**Tests** (`public_demo_save_codec_test.dart`, group `Codex P2-1 fix (PR
#214)`, 8 tests): an empty `questions` list is rejected; an out-of-range
`currentQuestionIndex` is rejected; `employeeAnswers` falling out of
lockstep is rejected; a `playerFollowUps` count violating the progression
invariant is rejected; a duplicate session for the same `employeeId` is
rejected; a session for an unknown `employeeId` is rejected; a valid,
genuine session round-trips exactly (this validation rejects nothing a real
command path produces); a genuinely *completed* session (the one case where
`playerFollowUps.length` and `currentQuestionIndex` legitimately diverge)
also round-trips exactly.

### P2-2 — "Serialize project-interview dialog launches"

**Finding (verified TRUE by direct code reading):** `_openProjectInterview`
awaited `_precacheEventImage(...)` *before* ever calling `showDialog` and
set no guard beforehand. Activating `客先面談` twice in quick succession —
well within that await window, and before any `setState`-driven button
disable could even repaint — let both invocations reach `showDialog`,
pushing `PublicDemoProjectInterviewDialog` twice. Each pushed dialog
captures its own `aggregate: _game` snapshot at build time and only writes
back through `onCommit`/`_commitAggregate` when it closes; with two
independent dialogs alive at once, closing the top one commits its result,
but the dialog still open underneath still holds the *older*, pre-result
snapshot — completing it (or the player merely interacting with it) then
commits that stale snapshot over the first result, silently undoing it.

**Fix (minimal, screen-level, no dependency on button-disable timing):**
added a plain `bool _projectInterviewLaunchInProgress` `State` field.
`_openProjectInterview` now checks it and returns immediately (no-op) if
already `true`; otherwise it sets `true` **before** its first `await`
(`_precacheEventImage`, the exact window the race exploited — not after
that await returns, which would leave the same window open) and clears it
in a `finally` block wrapping everything through `showDialog`'s own
`await`, so the guard is released whichever way the route ends: a genuine
pass/fail commit, the player dismissing/backing out, or this widget being
disposed while still awaiting (a `finally` still runs after disposal here;
it only ever mutates a plain field, never calls `setState`, so this is
safe). The guard does not depend on, or replace, any button-level
`setState` disable — it is checked and set synchronously, before any such
disable could even take visual effect.

**Tests** (new file `test/ui/public_demo/
public_demo_01_project_interview_launch_guard_test.dart`, 2 widget tests,
driving the real, full `PublicDemo01PlaceholderScreen` — not the isolated
dialog — via a fake `PublicDemoSaveService` seeded with a genuine
`partnerInterviewPassed` + Phase 5 proposal aggregate): rapid double
activation of the real `客先面談` button (two `tester.tap` calls back to
back, with no `pump()` in between, so the second call's synchronous
onPressed genuinely runs while the first is still suspended inside its own
`_precacheEventImage` await — reproducing the exact race, not merely
approximating it) opens exactly one `PublicDemoProjectInterviewDialog`;
after that dialog is popped, a fresh activation opens a new dialog normally
(the guard does not outlive its own dialog). Verified this test file
actually fails (finds 2 dialogs) against the pre-fix code and passes
against the fix, confirming it is a genuine regression test rather than a
false positive.

Neither fix touches `MatchingEngine`, Finance/Month/Balance, HOME, or the
Phase 7A lifecycle. Every prior Codex fix (P1, P1-1, P1-2, P2
duplicate-follow-up) and all pre-existing tests (37 domain + 8 dialog
widget tests) continue to pass unmodified; full suite after this update:
1982/1982 (1972 prior + 8 new save-codec + 2 new widget).

## Phase 6 FINAL HARDENING (this update)

This update is designated the final Phase 6 hardening pass: one more
Codex-flagged authority-chain gap fixed, followed by a one-time proactive
audit across a fixed checklist of Phase 6 risk categories, rather than an
open-ended commitment to keep chasing every future low-impact Codex
finding on this phase indefinitely.

### Codex P2 fix — "Validate restored passes against their proposals"

**Finding (verified TRUE by direct code reading):** the proposal-lock fix
(Codex P1-2) prevents the *runtime* from ever producing a new mismatch
between a passed engineer's `interviewRecordProjectId` and their
`matchingProposals` entry — but it does nothing to stop a corrupted or
hand-edited save from simply asserting `interviewRecordProjectId: A` on an
engineer whose `matchingProposals` entry (independently, in the same
save) still names a different project `B`. `_hasConsistentAuthorityFacts`
checked the record's own type, score, and engineer-id agreement, but never
cross-referenced it against the proposal or completed session at all.
Restoring such a save would resolve project `B` via
`projectInterviewCandidateFor`/`recordOrder` for an engineer whose only
real, derived fact is a pass on project `A` — reproducing exactly the
never-interviewed-project handoff the runtime lock exists to prevent, this
time via a corrupted save rather than a live `proposeMatch` call.

**Fix (in `_hasConsistentAuthorityFacts`, additive to the existing
per-engineer checks — no change to how any of those score/stage checks
work):** for every engineer whose `interviewRecordProjectId` is non-null (a
genuine, project-bound Phase 6 pass — the legacy generic-path case,
`interviewRecordProjectId == null`, is untouched and still skips this
entirely), two independent real, derived facts are now cross-checked
against it:
- The engineer's `matchingProposals` entry (built from
  `workflow.matchingProposals`, the same list `matchingProposalFor` reads
  in production) must exist and its `projectId` must equal
  `interviewRecordProjectId` exactly. Starting a project interview at all
  requires a real proposal for that engineer (`projectInterviewCandidateFor`
  resolves it), so a genuine pass can never exist with no proposal, or a
  proposal for a different project — this is a real, non-speculative
  cross-check, not an over-restriction on real gameplay.
- If a *completed* session exists for that engineer in
  `workflow.projectInterviewSessions` (the other real, derived fact of
  which project this engineer actually interviewed for, per
  `concludeProjectInterview`'s own `session.projectId != project.id` guard),
  its `projectId` must also equal `interviewRecordProjectId`.

Neither check relies on, or is weakened by, the P2-1 structural-validity
block for `projectInterviewSessions` (that block still runs independently
and rejects its own class of corruption); the two are complementary.
`MatchingEngine`, Finance/Month/Balance, HOME, and the Phase 7A lifecycle
are untouched.

**Tests** (`public_demo_save_codec_test.dart`, new group `Codex P2 fix (PR
#214) "Validate restored passes against their proposals"`, 6 tests): record
A + proposal B is rejected; record A + proposal A (the normal case)
restores successfully; a project-bound record with no matching proposal at
all is rejected; record A + a completed session for project B (proposal
otherwise consistently A) is rejected; a legacy generic-path pass
(`interviewRecordProjectId == null`) still round-trips with no proposal at
all, proving the cross-check is scoped to project-bound passes only; a
genuine end-to-end pass via real `proposeMatch` + a full interactive
interview round-trips normally under the new check. Two pre-existing P1-1
tests (score < 60 pass, score > 95 ceiling) were updated to include a
matching proposal in their hand-crafted envelopes — required now that a
project-bound record without one is itself rejected — so each test again
isolates the one specific violation it was written to exercise, rather
than incidentally also tripping the new cross-check.

### Final Hardening audit — scope and findings

Read (not modified except where a finding below required it) every Phase
6-authoring file — `public_demo_project_interview.dart`,
`public_demo_aggregate.dart`'s Phase 6 methods, `public_demo_sales.dart`'s
`PublicDemoEngineerInterviewRecord`/`applyProjectInterviewResult`,
`public_demo_workflow_state.dart`'s project-interview/matching-proposal
sections, `public_demo_project_interview_dialog.dart`, the `客先面談`
launch path in `public_demo_01_placeholder_screen.dart`, and
`public_demo_save_codec.dart`'s `_hasConsistentAuthorityFacts` — against
the task's fixed checklist:

- **stale aggregate/state, duplicate/double execution, async race, dialog
  reopen/dismiss/dispose:** re-verified the P2-2 launch-guard fix and
  re-derived, from first principles this time, *why* no other Phase 6
  action needs the same guard: `_recordEngineerOrder`/`ei()` (the generic
  interview path) both call `_commitAggregate` — which synchronously
  updates `_game` via `setState` and short-circuits identical no-op
  results — as their very first statement, *before* any `await`. Their
  underlying domain commands (`recordOrder`, `recordEngineerInterviewResult`)
  are themselves idempotent precondition-gated transitions (a no-op once
  the engineer has moved past the required stage). A rapid double-tap on
  either therefore has its second call see the already-updated `_game`
  synchronously and no-op — structurally the same reasoning that made
  `_openProjectInterview` (mutation deferred until the dialog itself
  closes, *after* an `await`) the one genuinely exploitable case, now
  fixed. No other Phase 6 action shares that "await-before-commit" shape.
- **malformed/corrupted save, session identity, engineer identity, project
  identity, invalid indices/list lengths, completed/incomplete session
  invariants, duplicate sessions:** covered by the pre-existing P2-1 fix
  plus this update's new proposal/session cross-check; re-confirmed both
  together reject every combination the checklist names without rejecting
  any real command-path output (see the P2-1 and P2 test groups).
- **proposal/pass/order authority chain, month/runtime boundary, retry
  after failure:** re-traced the full chain by hand —
  `proposeMatch`→`startProjectInterview`→`chooseFollowUp`→
  `concludeProjectInterview`→`applyProjectInterviewResult`→`recordOrder` —
  confirming a *failed* interview's session is always `completed`, so
  `startProjectInterviewSession`'s replace-on-completed rule always
  discards it for a genuinely fresh session on retry (new questions,
  current-month capability), even when the retry re-proposes the very same
  project; no residual stale state can leak from one attempt to the next.
- **deterministic seeded outcome, sales-slot atomicity, legacy save
  compatibility:** re-confirmed by re-running every existing regression
  group for these (no new gap found; see Tests below for the full list
  re-verified this update).

**Two low-impact residuals found, deliberately NOT fixed this update** (per
the task's own instruction not to extend Phase 6 indefinitely for low-impact
P2/P3 — recorded as Known Limitations below instead):
1. `_openProjectMatching` (Phase 5's `案件マッチング` entry point, unchanged
   by Phase 6) uses a plain synchronous `Navigator.push` with no launch
   guard — a rapid double-tap could push `PublicDemoProjectMatchingScreen`
   twice, requiring an extra back-press. `onPropose` itself
   (`proposeMatch`) is fully idempotent, so this is a UI-navigation nit, not
   an authority/data-integrity issue — unlike `_openProjectInterview`,
   nothing here can silently overwrite or lose a genuine result.
2. `_hasConsistentAuthorityFacts` does not verify that every
   `matchingProposals` entry's `engineerId` names a real engineer in the
   same save. A fabricated proposal for a nonexistent id is inert (nothing
   in production code looks up a proposal by an id that isn't also a real
   engineer) rather than exploitable, so this is corruption-tolerance
   hygiene, not a live gap.

All prior Codex fixes and all pre-existing tests continue to pass
unmodified. Full suite after this update: 1988/1988 (1982 prior + 6 new
save-codec tests).

## Codex P2 x2 scoped fixes (this update) — no new broad audit

This update is explicitly scoped to the two Codex findings below only, per
the task's own instruction: no new Final-Hardening-style audit, no Phase 6
scope extension, existing PR #214.

### P2 — "Reject duplicate proposals before validating pass bindings"

**Finding (verified TRUE by direct code reading):** the previous
authority-chain fix built `proposalProjectIdByEngineer` as a plain `Map`
assignment while iterating `workflow.matchingProposals` — a SECOND entry
for the same `engineerId` silently overwrote the first (last-write-wins).
But `PublicDemoWorkflowState.matchingProposalFor` — the one production
code actually calls — returns the FIRST match in the list instead. A
corrupted save with `matchingProposals: [{engineerId: A, projectId: B},
{engineerId: A, projectId: A}]` would therefore validate the pass record
against project A (this lookup's last-write) while runtime resolves
project B (the real first-match lookup) — `recordOrder`/
`projectInterviewCandidateFor` could then proceed for the never-interviewed
project B even though the just-added cross-check believed A was verified.

**Fix:** the same loop that builds `proposalProjectIdByEngineer` now
rejects the whole save (`return false`) the moment it encounters a second
entry for an `engineerId` already seen — `withMatchingProposal` always
filters out any existing entry for that engineer before appending a new
one, so at most one proposal per engineer is the only shape any real
command path can ever produce; a genuine duplicate is unreachable, and
there is no "correct" value to prefer between first and last, so it is
rejected outright rather than resolved either way.

**Tests** (`public_demo_save_codec_test.dart`, new group, 5 tests): a
duplicate (project B then project A) for the same engineer is rejected; a
duplicate naming the SAME project is rejected too (not just a
mismatched-project duplicate); one proposal each for two different
engineers restores normally; a valid single-proposal genuine pass still
round-trips exactly; a legacy save with no `matchingProposals` key at all
still decodes. Verified this fix is a genuine regression-catcher by
reverting it and re-running the two duplicate-rejection tests — both
failed (`Expected: null, Actual: <PublicDemoAggregate>`) — then restoring
it and re-confirming green.

### P2 — "Validate restored accumulated interview evaluation"

**Finding (verified TRUE by direct code reading):** `ClientInterviewSession
.fromJson` casts `accumulatedEvaluation`'s five integers verbatim — a
shape-valid save can carry ANY values there, and any int round-trips
byte-identical, so the strict round-trip comparison never catches a
tampered one. `ClientInterviewEngine.finalRate` trusts
`session.accumulatedEvaluation.total.clamp(-15, 15)` as a genuine,
player-choice-derived adjustment to the pass/fail rate — a corrupted save
could shift that by the full ±15 range without tripping any other check.

**Fix (in `PublicDemoSaveCodec`, reusing `ClientInterviewEngine.evaluate`
as the sole authority — no second formula):** a new
`_hasConsistentProjectInterviewEvaluations` runs on the already-decoded
aggregate (needs real `Engineer`/session values, not just JSON shape) right
after `PublicDemoAggregate.fromJson` succeeds. For every
`projectInterviewSessions` entry with at least one `playerFollowUps`
entry, it replays every recorded follow-up from scratch — same
`Engineer` (via `PublicDemoEngineerProjectFit.engineerFor`), same
`questions[i]`/`employeeAnswers[i]`/`playerFollowUps[i]`, same seed (via
`PublicDemoRng.derivedSeed` with the `projectInterview` namespace, exactly
as `PublicDemoProjectInterview.chooseFollowUp` itself derives it) — and
rejects the save if the recomputed total disagrees with the stored one in
any of the five fields. Every index this walks is already guaranteed
in-bounds by the P2-1 structural checks (which always run first), so no
new bounds-checking was needed.

**Tests** (`public_demo_save_codec_test.dart`, new group, 5 tests): a
tampered `accumulatedEvaluation` (an added positive delta) is rejected; a
tampered one (a subtracted negative delta) is rejected; a genuine
in-progress session (real, untampered evaluation) round-trips exactly; a
genuine completed session round-trips exactly; a full seeded
interview's pass/fail and score are unaffected by this recomputation
check. While writing the tampering tests, found and fixed a bug in the
test helper itself (`withAccumulatedEvaluationPatch` produced an untyped
`Map<dynamic, dynamic>` via unchecked spread, which threw a type-cast
exception during decode that the codec's own outer `try`/`catch`
silently turned into a `null` result — coincidentally matching the
expected `isNull` assertion for the wrong reason, before the real check
was even wired up). Confirmed as a genuine regression-catcher the same
way as the P2-1 duplicate-proposal fix: reverted the real fix (leaving the
corrected test helper in place), re-ran the two tampering tests, watched
both fail, then restored the fix and re-confirmed green.

Neither fix touches `MatchingEngine`, Finance/Month/Balance, HOME, or the
Phase 7A lifecycle. Every prior Codex fix and all pre-existing tests
continue to pass unmodified. Full suite after this update: 1998/1998
(1988 prior + 10 new save-codec tests).

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
- New field `PublicDemoEngineerInterviewRecord.projectId` (Codex P1-1/P1-2
  fix, this update) — additive, nullable, persisted as
  `interviewRecordProjectId` on each `workflow.engineers` entry, `null` for
  every record minted before this fix (and for every generic-path record
  minted since). Spliced into the save-codec's comparison baseline for any
  pre-fix save (mirrors the existing `totalItExperienceMonths` splice), so
  every existing save keeps decoding and round-tripping exactly as before.

## Success/fail handoff

- **Pass:** `PublicDemoEngineerSales.applyProjectInterviewResult(passed:
  true, ..., projectId: ...)` sets `stage: clientInterviewPassed` and mints
  a genuine, unforgeable `PublicDemoEngineerInterviewRecord` — bound to the
  real interviewed project id (Codex P1-2 fix, this update) — the same
  record type `hasGenuineInterviewRecord`/`assignOrderedForMay` already
  require. `PublicDemoWorkflowState.withMatchingProposal` now refuses to
  re-bind that engineer to a different project once passed, so the record's
  own `projectId` and the engineer's current `PublicDemoMatchingProposal`
  can never drift apart. The
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

## Save-compatibility verification (this integration update)

Every item this task asked to specifically confirm, and how:

| Item | Verified how | Result |
|---|---|---|
| `matchingProposals` migration | PR #213's own splice, unmodified; re-ran its 2 existing tests | ✅ unaffected, still passing |
| `totalItExperienceMonths` migration | PR #213's own splice, unmodified; re-ran its existing test | ✅ unaffected, still passing |
| `projectInterviewSessions` | New splice added this update (see above) + 2 new tests (missing-key, real-session round-trip) | ✅ fixed and verified |
| `interviewSessions` | New splice added this update (see above) + 2 new tests (missing-key, real-session round-trip) | ✅ fixed and verified |
| `PublicDemoSaveCodec` strict round-trip | `_advancedAggregate()`'s existing full round-trip test, plus every new/existing test above | ✅ passing |
| Legacy save | Combined missing-both-keys test + PR #213's own matchingProposals/totalItExperienceMonths legacy test | ✅ passing |
| `engineerId + projectId` interview binding | Re-ran the full Codex P1 fix test group (7 tests) from the prior update — all still pass after the merge; the new save-codec test also asserts the restored session's `projectId` matches the real candidate's id | ✅ unaffected, still passing |
| Sales slot atomicity | Re-ran the 0-slot regression tests (both the original pair and the Codex-P1-group's mid-interview-proposal-change variant) | ✅ unaffected, still passing |
| Pass/fail continuation | Re-ran the pass→`recordOrder`→`ordered` and fail→`beginSelling` tests | ✅ unaffected, still passing |

**This update (Codex P1-1/P1-2/P2 fixes) additionally verified:**

| Item | Verified how | Result |
|---|---|---|
| `finalRate < 60` + seeded PASS → save/reload succeeds | New save-codec test: a genuine low-score (45) project-bound pass decodes successfully | ✅ fixed and verified |
| Legacy threshold-based invalid state still rejected | New save-codec test: the identical score 45 *without* a project binding is still rejected | ✅ unweakened, verified |
| Pass on project A, switch to project B → cannot order for the un-interviewed project | New domain test: `proposeMatch` to B after a pass on A is a no-op; proposal/record both stay on A | ✅ fixed and verified |
| Pass project A → order project A works normally | New domain test: `recordOrder` still reaches `ordered` for the actually-passed project | ✅ verified |
| Mid-interview project-swap prevention (prior Codex P1 fix) | Re-ran that entire 7-test group unmodified | ✅ unaffected, still passing |
| Mid-interview month/runtime change → no old/new authority mixing | New domain test: a real `closeApril` mid-interview forces a fresh restart with zero carried-over answers on reopen | ✅ fixed and verified |
| Save/reload preserves both new bindings | Two new domain tests: the project lock and the session's `startedWeek` both survive a round-trip | ✅ verified |
| Sales slot atomicity (re-verified) | Existing 0-slot tests re-run; unaffected by any of the three fixes | ✅ unaffected |
| Normal PASS/FAIL continuation (re-verified) | Existing pass/fail tests re-run; unaffected | ✅ unaffected |

## Tests

New:

- `test/game/public_demo/public_demo_project_interview_test.dart` (28
  tests: 15 from the initial PR + 7 Codex P1 regression tests + 6 Codex
  P1-2/P2 regression tests added this update): start/no-op preconditions,
  resume-not-restart, determinism, choice-materially-affects-outcome,
  non-degenerate pass/fail distribution (not a disguised coin flip),
  truthful failure reasons, 0-slot/no-double-consumption regressions,
  pass→`recordOrder`→`ordered` Phase 7A handoff, fail→`beginSelling`
  continuation, three persistence/round-trip tests (in-progress,
  legacy-missing-key, full strict round-trip), the `Codex P1 fix (PR #214)`
  group covering the resumed-session project-binding fix, and this update's
  `Codex P1-2 fix`/`Codex P2 fix`/binding-survives-save-reload groups (see
  the section above for the full list).
- `test/ui/public_demo/public_demo_project_interview_dialog_test.dart` (8
  tests): question/answer/follow-up rendering and advancement, full
  interview-to-result flow with no raw score/percentage shown, and
  viewport/TextScaler regression across all 6 required combinations
  (390×844 / 360×800 × 1.0 / 1.3 / 2.0), each also driving one real
  follow-up tap (the densest on-screen content state) with zero exceptions.
- `test/game/public_demo/public_demo_save_codec_test.dart` (3 tests from
  the main-integration update + 5 new Codex P1-1 regression tests this
  update): the `interviewSessions`/`projectInterviewSessions` gap fix, plus
  this update's low-score-stochastic-pass/legacy-floor-unweakened/
  out-of-range-score/legacy-missing-key/real-end-to-end-round-trip tests
  (see the section above for the full list).

Updated:

- `test/game/public_demo/public_demo_recovery_aggregate_test.dart` — added
  the new additive schema key to the existing hardcoded key-set assertion
  (no assertion removed or loosened).

Verification run (this update, after the Codex P1-1/P1-2/P2 fixes):

```
flutter analyze            → No issues found!
flutter test --concurrency=6 → 1963/1963 passed
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
  resuming the exact same question set after a fail, or after a month
  boundary passes mid-interview (Codex P2 fix, this update) — intentional
  in both cases: a fresh seed/question draw against current-month capability
  is the more honest choice than either resuming stale state or fabricating
  a snapshot.
- Once an engineer reaches `clientInterviewPassed`/`ordered`, their
  Matching proposal is now permanently locked (Codex P1-2 fix, this
  update) — there is currently no production path back to an earlier stage
  for such an engineer (no assignment-ends/re-entry lifecycle exists yet;
  that is Phase 7A/7B scope), so this lock cannot yet be exercised twice
  for the same engineer within a single playthrough. Should a future phase
  add such a path, it would need to explicitly decide whether reaching
  `selling` again also clears the old `interviewRecord`.
- (Final Hardening audit, this update) `_openProjectMatching`'s `案件
  マッチング` entry point (Phase 5, unmodified by Phase 6) has no
  double-launch guard — a rapid double-tap can push
  `PublicDemoProjectMatchingScreen` twice, needing an extra back-press.
  `proposeMatch` itself is fully idempotent, so this is a navigation nit,
  not an authority/data-integrity issue; deliberately left unfixed as
  low-impact per the task's own scope limit for this final hardening pass.
- (Final Hardening audit, this update) `_hasConsistentAuthorityFacts` does
  not verify every `matchingProposals` entry's `engineerId` names a real
  engineer — a fabricated proposal for a nonexistent id decodes but is
  inert (nothing in production code resolves a proposal by an id that
  isn't also a real engineer). Corruption-tolerance hygiene, not a live
  exploit path; deliberately left unfixed as low-impact for the same
  reason.

## Phase 7A handoff

On a genuine pass, the engineer carries: `stage ==
PublicDemoSalesStage.clientInterviewPassed`, a real
`PublicDemoEngineerInterviewRecord` — bound to the actually-interviewed
project's id via `genuineInterviewProjectId` (Codex P1-2 fix, this update),
never just the engineer's own id — `lastInterviewScore` set (any genuine
value in `[5, 95]`, not only `>= 60` — Codex P1-1 fix, this update), and —
recoverable at any time via `PublicDemoAggregate
.projectInterviewCandidateFor(engineerId)` — the exact real Phase 4/5
`PublicDemoProjectCandidate`/`Project` the player interviewed for (never
discarded; regenerable purely from `runSeed` + the still-present
`PublicDemoMatchingProposal`, which can now never drift from the passed
project). Phase 7A can read this candidate — and now trust that
`genuineInterviewProjectId` and the current proposal always agree — directly
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

**Second update (Codex P1 fix):** approximately 25 minutes, within the
15–30 minute estimate.

**Third update (main integration to PR #213 + save-codec fix):**
approximately 30 minutes, within the 15–30 minute estimate's upper bound
(the merge itself was immediate/conflict-free; the extra time went to
discovering and fixing the `interviewSessions`/`projectInterviewSessions`
save-codec gap and its regression tests).

**This update (Codex P1-1/P1-2/P2 fixes):** approximately 45 minutes,
within the 30–60 minute estimate (root-causing P1-1/P1-2 together — both
traced to the same missing `projectId` field — was quick; P2's fix needed
one scratch-probe run against real `closeApril` production code to confirm
engineer runtime genuinely never changes mid-month before writing the
permanent test).
