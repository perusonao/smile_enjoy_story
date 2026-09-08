# SES CORE-GAMEPLAY Phase 3: Recruitment Interview — Result

Status: **Implementation complete, all tests green**

## BASE SHA / branch / HEAD

- Expected BASE SHA (given by the task): `09555d1c89569c4d2ba4b461beb55c5358641367`
- BASE SHA (origin/main at session start, confirmed via `git fetch origin main`):
  `09555d1c89569c4d2ba4b461beb55c5358641367` — matched exactly, no divergence
  to reconcile.
- Branch: `claude/ses-phase3-recruitment-interview-bbu0h2` — this branch's
  own prior tip (`f4ca78f`, "Phase 0A/0B: SES domain models and random
  generators") was confirmed to be an ancestor of `origin/main` with no
  unmerged commits (`git log HEAD ^origin/main` was empty), so per the
  merged-branch-reuse rule it was reset onto the BASE SHA above at session
  start.
- HEAD after this work: `a08eb406d0697b37c7032190dd1f4834439e47cb`
  ("SES CORE-GAMEPLAY Phase 3: interactive recruitment interview")
- PR: https://github.com/perusonao/smile_enjoy_story/pull/203

## Pre-implementation audit (summary)

Audited before writing any code, per the task's own numbered checklist:

1. **Main game `RecruitmentInterviewEngine`** (`lib/game/engine/
   recruitment_interview_engine.dart`) and its models
   (`lib/game/models/recruitment_interview.dart`) — `start`/`ask`/
   `answerReverse`/`generateAnswer`/`observe`/`selectReverseQuestion` all
   already pure functions of `(seed, week, applicant, ...)`, no shared
   mutable `Random`. Also audited `lib/ui/recruitment/
   recruitment_interview_screen.dart` (the main game's own post-tutorial
   hiring screen) and its shared presentation widgets
   (`recruitment_interview_widgets.dart`, `interview_presentation.dart`) —
   both take `Applicant`/`RecruitmentInterviewSession` directly with no
   `GameState`/`game_scope` coupling, making them directly reusable.
2. **Phase 2** (`PublicDemoSeededRecruitmentGenerator`,
   `lib/game/public_demo/public_demo_recruitment_candidate_generator.dart`)
   — read in full; its own result report explicitly named
   `regenerateDomainApplicant({runSeed, applicantId})` as this phase's
   integration seam.
3. `regenerateDomainApplicant` itself — confirmed it recovers the exact
   full domain `Applicant` (every `HiddenParameters`/`TechSkillLevels`/
   personality field) purely from `(runSeed, applicantId)`, and returns
   `null` for the two hand-authored legacy fixture pools.
4. **Phase 1** `PublicDemoRng`/`PublicDemoRngNamespace.recruitmentInterview`
   (`lib/game/public_demo/public_demo_rng.dart`) — already reserved,
   unused until this phase, exactly as its own doc predicted.
5. **Current Public Demo recruitment/offer/hire workflow** — a full audit
   (own reading + a dedicated read-only Explore pass) established:
   - `PublicDemoAggregate.completeInterview(applicantId)` was, before this
     phase, the *entire* "interview": one call that atomically consumes a
     sales slot, mints an unforgeable `PublicDemoInterviewRecord`, and
     flips `stage: interviewed` — no question/answer content of any kind.
   - `PublicDemoApplicantStage.rejected` has existed on the stage enum
     since WORKFLOW-STATE-1, but **no production code ever set it** — no
     `reject`/`decline` command existed anywhere in
     `PublicDemoAggregate`/`PublicDemoWorkflowState`. It was dead,
     UI-label-only (`applicantStatus`/`_applicantStatusTone` already had a
     ready-to-use `不採用` label and negative tone for it).
   - The offer flow (`PublicDemoSalaryOfferEvaluator`,
     `PublicDemoOfferAcceptance.accept`) is a separate, player-initiated
     step after `interviewed` (a salary-offer dialog), gated on
     `hasBeenInterviewed` (the unforgeable record), not on `stage` — see
     "New authority: closing an offer-after-reject gap" below for the one
     narrow hardening this phase added here.
6. **`PublicDemoRngNamespace.recruitmentInterview`** — confirmed unused in
   any production code before this phase (Phase 1's own doc already said
   so).
7. **Sales action-slot authority** (`PublicDemoState.useSalesSlot()` /
   `.useSalesSlotForInterview()`) — the interview's slot cost is consumed
   exactly once, inside `completeInterview()`, gated by the real
   `salesCapacity`/`salesUsed` budget; every other slot-consuming action
   (partner interviews, replacement interviews) is independent and
   untouched.
8. **Save/reload authority** — `PublicDemoWorkflowState.toJson()/
   fromJson()` and `PublicDemoAggregate._validateForPersistence()` audited
   in full to design the additive `interviewSessions` field (see
   "Persistence" below).

## Reused main-game classes/functions (no reimplementation)

- `RecruitmentInterviewEngine` (`lib/game/engine/
  recruitment_interview_engine.dart`) — `start`/`ask`/`answerReverse`/
  `generateAnswer`/`observe`/`selectReverseQuestion`/`applicantValue`/
  `knowledgeLabel`/`impressionLabel`, called through a thin adapter
  (`PublicDemoRecruitmentInterview`, new file) with **no logic changes** —
  same file, same code, same question/answer/observation generation as the
  main game's own interview.
- `RecruitmentInterviewSession`, `ApplicantAnswer`, `InterviewObservation`,
  `InterviewQuestionCategory`, `InterviewOutcome`, `ReverseQuestionCategory`,
  `ApplicantValue`, `ObservationConfidence` (`lib/game/models/
  recruitment_interview.dart`) — used directly as Public Demo's own
  in-progress interview session type. **Not copied or subset** — the exact
  same class, including its own `toJson()/fromJson()`, is what
  `PublicDemoWorkflowState.interviewSessions` stores.
- `interviewQuestionTexts`, `interviewQuestionLabels`,
  `reverseQuestionTexts`, `companyAnswerChoices`, `CompanyAnswerChoice`
  (`lib/game/engine/recruitment_interview_content.dart`) — the exact same
  Japanese question/answer-choice content the main game's own interview
  uses; Public Demo adds none of its own.
- `RecommendationEngine.postInterviewAssessment` (`lib/game/engine/
  recommendation_engine.dart`) — the "良い材料/注意" summary shown at the
  end of the interview is this exact function, called with the Public
  Demo `RecruitmentInterviewSession` unmodified.
- `ApplicantPersonaHeader`, `QuestionProgress`, `QuestionCard`,
  `ReactionLine`, `TalkCard`, `ObservationSummaryTile`,
  `InterviewConclusionSummary`, `InterviewInfoGauge` (`lib/ui/recruitment/
  recruitment_interview_widgets.dart`, transitively `interview_presentation
  .dart`) — every card/gauge/tag in the new Public Demo interview modal is
  one of these exact main-game widgets, imported and used verbatim. The
  modal writes its own (small) reverse-question and title-bar/decision-bar
  widgets only, since the main game's own `_Reverse`/`_Summary` are
  private to its screen file.
- `ApplicantGenerator` (`lib/domain/generation/applicant_generator.dart`)
  — used only for the narrow legacy-fixture fallback (see below), exactly
  as Phase 2 already used it, never a new generator.
- `PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant` (Phase
  2) and `PublicDemoRng`/`PublicDemoRngNamespace.recruitmentInterview`
  (Phase 1) — used exactly as both phases' own reports specified this
  integration would work.
- `PublicDemoAggregate.completeInterview`, `PublicDemoState
  .useSalesSlotForInterview`, `PublicDemoOfferAcceptance.accept`,
  `PublicDemoSalaryOfferEvaluator.evaluate` — **all untouched in behavior**
  (one narrow, additive guard added to `accept`, see below); this phase
  builds entirely on top of them rather than replacing any part of the
  existing authority.

## New adapter/persistence components

- **`lib/game/public_demo/public_demo_recruitment_interview.dart`** (new)
  — `PublicDemoRecruitmentInterview`: the sole adapter onto
  `RecruitmentInterviewEngine` for Public Demo. Resolves the full domain
  `Applicant` behind a `PublicDemoApplicant` (via `regenerateDomainApplicant`
  or the legacy fallback), re-identifies it to carry the Public Demo
  applicant's own id (see "Candidate identity" below), and exposes
  `start`/`ask`/`answerReverse` as thin, seed-deriving passthroughs.
- **`PublicDemoRng.legacyFixtureSeed(applicantId)`** (new, small addition
  to the existing Phase 1 adapter) — the one other sanctioned use of
  `rng.dart`'s `stableHash`, kept inside `public_demo_rng.dart` so every
  Public Demo file still reaches `rng.dart` through that single adapter.
- **`PublicDemoWorkflowState.interviewSessions`** (new field, additive to
  the save schema) — `List<RecruitmentInterviewSession>`, one per
  applicant who has started the interactive interview. New methods
  `startInterviewSession`/`updateInterviewSession` follow the file's own
  established pattern (`_withApplicant`, `_transitionApplicantStage`):
  named, precondition-gated, no generic caller-supplied mutator.
- **`PublicDemoWorkflowState.rejectApplicant(applicantId)`** (new) — wires
  up the previously-dead `PublicDemoApplicantStage.rejected` value via the
  same `_transitionApplicantStage` helper every other stage transition in
  this file uses (`from: {interviewed}, to: rejected`).
- **`PublicDemoAggregate.startInterviewSession` / `askInterviewQuestion` /
  `answerInterviewReverseQuestion` / `concludeInterviewSession`** (new) —
  the four commands the UI dialog calls, all thin passthroughs to the
  adapter + the new `PublicDemoWorkflowState` methods, in the exact style
  of every other command on this class (validate, no-op on failure, single
  new `PublicDemoAggregate` on success). None of them touch `state`
  (finance/month side) — see "Finance/Month regression" below.
- **`PublicDemoAggregate._validateForPersistence()`** — one added
  invariant: `interviewSessions` applicant ids must be unique (mirrors the
  existing uniqueness checks for engineer/applicant/runtime/assignment
  ids).
- **`lib/ui/public_demo/public_demo_recruitment_interview_dialog.dart`**
  (new) — `PublicDemoRecruitmentInterviewDialog`, the interactive modal
  (see "UI" below).
- **New authority: closing an offer-after-reject gap.**
  `PublicDemoOfferAcceptance.accept` (`public_demo_binding_offer.dart`)
  gates on `applicant.hasBeenInterviewed` (the interview-paperwork record)
  but, before this phase, had no reason to check `stage` at all — nothing
  could ever reach `PublicDemoApplicantStage.rejected` while still
  carrying that record. Now that `rejectApplicant` exists, a rejected
  applicant keeps `hasBeenInterviewed == true` (that record is about the
  slot/paperwork step, not the hire decision) — without a stage check,
  `acceptOffer` could still mint a binding offer for someone the player
  already declined. Closed with one additive guard: `stage ==
  PublicDemoApplicantStage.rejected` now returns `invalidStage`, mirroring
  the file's existing "unforgeable fact gates the mint, not a caller-
  supplied field" pattern. No existing test exercised this path as a
  positive case (it was structurally unreachable before this phase), so
  nothing regressed; a new test in this phase's own suite covers it
  directly.

## Interview state machine

Three phases, driven entirely by the reused `RecruitmentInterviewSession`'s
own fields — no new state machine invented:

1. **Questions** (`!session.questionsComplete`): the player picks up to 3
   of the 6 `InterviewQuestionCategory` values via `QuestionCard`; each tap
   calls `PublicDemoAggregate.askInterviewQuestion`, which appends one
   `ApplicantAnswer` + `InterviewObservation` and increments
   `candidateKnowledge`.
2. **Reverse question** (`questionsComplete && companyAnswer == null`):
   once 3 questions are asked, the engine has already picked the
   applicant's own reverse question (`selectReverseQuestion`, seeded); the
   player picks the company's answer from `companyAnswerChoices`, calling
   `answerInterviewReverseQuestion`.
3. **Summary/decision** (`conversationComplete`): `InterviewInfoGauge` +
   `InterviewConclusionSummary` + `RecommendationEngine
   .postInterviewAssessment` render what was learned; a decision bar
   offers "採用候補として進める" (`InterviewOutcome.hired`) or "見送る"
   (`InterviewOutcome.rejected`, behind `confirmIrreversibleAction`), both
   committed via `concludeInterviewSession`.

The dialog can be closed (header ✕, or the barrier) at any point before a
decision and reopened later ("面談を続ける") — every question/answer/
reverse-choice tap already committed to the aggregate the moment it
happened, so there is no separate "cancel" state to model.

## RNG derivation

`PublicDemoRecruitmentInterview._seed({runSeed, month, applicantId})` =
`PublicDemoRng.derivedSeed(runSeed: runSeed, month: month, namespace:
PublicDemoRngNamespace.recruitmentInterview, identifier: applicantId)` —
exactly the call Phase 1's own report predicted this integration point
would make. This derived `int` is passed as `RecruitmentInterviewEngine`'s
own `seed` parameter for every `start`/`ask` call (`week: state.month`,
purely for the `RecruitmentInterviewSession.startedWeek` display field —
the derived seed itself already encodes month, so this is not a second,
redundant source of entropy).

Because `generateAnswer`/`applicantValue`/`selectReverseQuestion` each
build their own fresh `seededRandom(seed, 0, 'answer:$id:$category')` (or
equivalent) internally — the main engine's own existing, unmodified
contract — asking questions in any order never perturbs an unrelated
question's answer content. Verified directly: `public_demo_recruitment_interview_test.dart`'s
"question choice changes the information revealed" and "candidate
identity" tests construct sessions via different orderings/subsets of
categories and confirm identical per-category results either way.

`same runSeed + month + applicant + question → reload後も同一結果` is
satisfied structurally: every draw is a pure function of these four
inputs via `PublicDemoRng`/`seededRandom`, never a cached/live `Random`
instance — confirmed by the "same runSeed..." and "reload mid-interview"
tests (full save/load round-trip via `PublicDemoAggregate.toJson()/
fromJson()`, then continuing produces byte-identical further results).

## Candidate identity / legacy fixture fallback

`PublicDemoRecruitmentInterview.domainApplicantFor({runSeed, applicant})`:

1. Calls `PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant
   (runSeed, applicant.id)` — for every seed-generated candidate (Phase 2)
   this recovers the *exact* full domain `Applicant` that candidate was
   generated from, byte-for-byte, purely from `(runSeed, id)`. This is the
   same person the player saw on the résumé/candidate card — never a
   re-roll.
2. The recovered `Applicant`'s own `id` field (an internal
   `ApplicantGenerator`-minted value like `applicant-<seed>-<n>`, not
   Public Demo's own `recruitment-<month>-<medium>-<slot>` id) is
   re-identified — a plain re-spread of every other field onto Public
   Demo's own `applicant.id` — so `RecruitmentInterviewSession
   .applicantId` (set internally by `RecruitmentInterviewEngine.start`
   from `applicant.id`) stays keyed the same way every other Public Demo
   workflow record already is. `Applicant` has no `copyWith` (a plain
   `const` data class), so this is a straightforward field-for-field
   reconstruction, not a new derivation.
3. **Legacy fixture fallback** (`app-01`, `app-02`,
   `free-template-inexperienced-01`, `free-template-experienced-01` —
   `publicDemoMayApplicants`/`publicDemoFreeApplicants`,
   `public_demo_recruitment.dart`): these hand-authored founding-pool
   constants predate `PublicDemoSeededRecruitmentGenerator` and were never
   produced by `ApplicantGenerator`, so step 1 returns `null` for them
   (exactly as Phase 2's own report documented). A synthetic flavor
   `Applicant` is generated instead, from `ApplicantGenerator(seed:
   PublicDemoRng.legacyFixtureSeed(applicant.id))` — **deliberately seeded
   from the applicant's id alone, not `runSeed`**, since these 4 fixtures
   are the same every playthrough (the founding pool), not seed-varied
   candidates. This is a narrow, display-flavor-only exception: the
   résumé-visible facts a player actually decides on (name, résumé text,
   requested salary, the `interviewScore`/`acceptanceScore` gates) still
   come from the authoritative `PublicDemoApplicant` fixture itself, never
   from this synthetic stand-in — only the interview's own flavor answers/
   observations draw from it. **Rationale for this specific design**: the
   alternative (refusing to let legacy-fixture applicants interview at
   all, or reverting to the old rubber-stamp for them only) would make the
   founding pool — the very first two candidates every new playthrough
   sees — the one place the new interactive interview doesn't work, which
   is worse than a flavor-only compromise. Documented and tested (see
   "legacy fixture applicant" test) rather than silently patched over.

## Visible vs. hidden information policy

Nothing new is displayed as a raw number. Every UI surface in the new
dialog is one of the reused main-game widgets, which already only render:
free-text answers/observations, category labels, a coarse 0-5 "confidence"
bar + qualitative tag (`ObservationTag`: 好印象/深掘りしたい/気になる/まだ
不確か — never a percentage or the underlying `credibility`/`specificity`
int), and `RecommendationEngine.postInterviewAssessment`'s "良い材料/注意"
bullet lists. `HiddenParameters` fields (`retention`, `turnoverIntent`,
`growthPotential`, `dishonesty`, `stressTolerance`) feed the *generation*
of answers/observations (exactly as the main game's own engine already
does) but are never themselves serialized into the persisted
`RecruitmentInterviewSession` or read by any Public Demo UI code — verified
directly by a dedicated test asserting none of those five field names ever
appear in `RecruitmentInterviewSession.toJson()`'s encoded output, across a
real multi-question session.

## Action-slot handling

Unchanged. `PublicDemoAggregate.completeInterview(applicantId)` —
untouched, still the sole consumer of `PublicDemoState
.useSalesSlotForInterview()` — remains the single sales-slot cost for an
applicant's whole interview. The new interactive session
(`startInterviewSession`/`askInterviewQuestion`/
`answerInterviewReverseQuestion`/`concludeInterviewSession`) never calls
`useSalesSlot`/`useSalesSlotForInterview` at all; every one of these four
new methods only ever changes `workflow`, never `state` (see "Finance/
Month regression" test, which asserts `identical(next.state, previous
.state)` across all four). The "採用面談" button's behavior and gate
(`salesRemaining > 0`) are completely unchanged — the interactive
interview is additive gameplay layered on top of the *existing*
slot-consuming step, not a new consumer of the budget.

## UI

**Where it lives**: a modal dialog
(`PublicDemoRecruitmentInterviewDialog`, `showDialog`), matching Public
Demo's own existing convention — every non-card interaction in this screen
(`PublicDemoInterviewResultDialog`, `PublicDemoSalaryOfferDialog`, etc.) is
already a dialog; Public Demo has no `Navigator.push` route anywhere, so a
new full-screen route would have been a larger architectural departure
than the task's own "既存設計に最も自然な形式" instruction allows.

**Card wiring** (`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`,
`ac(i)`'s `interviewed`-stage branch): unchanged until a hire decision is
reached. Before this phase, `interviewed` stage went straight to the
`合格・給与提示` button. Now:
- No completed-hired session yet → a `面談を行う`/`面談を続ける` button
  opens (or resumes) the dialog.
- A session decided `InterviewOutcome.hired` → the card reverts to
  **exactly** its pre-existing rendering (`評価 {interviewScore}` /
  `希望給与 ...` / the same, unmodified `合格・給与提示` button gated on
  `interviewScore >= 60`) — so every existing test/behavior for the
  post-decision "proceed to offer" path is untouched byte-for-byte.
- A session decided `InterviewOutcome.rejected` → the applicant's `stage`
  is already `rejected` by the time of the next render, so this branch
  never renders for them again (the existing, dormant `不採用` status
  label/tone takes over, unmodified).

The HOME "recommended action" mirror (`_addApplicantStageCandidate`) got
the same split, plus one new `HomeRecommendedActionKind.applicantContinueInterview`
(presentation-priority band between the existing `applicantSalaryOffer`
and `applicantInterview`, per that enum's own "further along the pipeline
= more urgent" ordering rule) so the dashboard's own CTA opens the dialog
too instead of jumping straight to the offer dialog.

**Viewports**: 360×800/390×844, TextScaler 1.0/1.3/2.0 — the dialog is a
height-constrained `Dialog` with a scrollable `ListView` body per phase and
a pinned title bar / decision bar, matching the main game's own
`RecruitmentInterviewScreen` layout pattern adapted to a modal. Verified
with real widget-tree overflow assertions (`tester.takeException()` +
on-screen rect bounds), not just visual inspection — see Tests below.

## Persistence / legacy save handling

**`PublicDemoWorkflowState.interviewSessions`** — additive top-level key,
absent in a save from before this phase, decoded to `[]` when missing
(distinct from "malformed" — every other unexpected/missing field in this
file's `fromJson` is still a hard `FormatException`, unchanged). No
`schemaVersion` bump: `PublicDemoWorkflowState`'s codec is not gated by
`schemaVersion` at all (that gate lives one level up, in
`PublicDemoSaveCodec`, which this phase does not touch), and the new key
is purely additive/optional, so an old save loads exactly as before, just
with an empty interview-session list ready to be populated the next time
that applicant's interview is opened.

**Legacy fixture applicants already `interviewed` in an old save** — since
`startInterviewSession` only requires `hasBeenInterviewed` and "no session
yet" (not any particular provenance for *how* they got interviewed), an
applicant who reached `interviewed` under the pre-Phase-3 rubber-stamp
behavior can open the interactive interview retroactively, using the same
legacy-fixture-or-regenerated-candidate resolution described above. No
special-casing was needed for "already interviewed under old rules" as a
distinct case.

## Tests

Environment note: no Flutter SDK was preinstalled in this session;
Flutter 3.44.9 (stable, matching this repo's CI pin) was downloaded to
`/opt/flutter` to run every command below.

- `dart format` (every changed/new file): clean, 8 files reformatted to
  the repo's own style (no logic change).
- `flutter analyze` (whole project): **No issues found.**
- `git diff --check`: clean.
- New: `test/game/public_demo/public_demo_recruitment_interview_test.dart`
  (12 tests, entirely against `PublicDemoAggregate` — the same entry
  points the UI dialog itself calls):
  - same `runSeed`+month+applicant+question → identical session (exact
    JSON equality across two independently-constructed aggregates).
  - reload mid-interview: a real `toJson()`/`fromJson()` round-trip mid
    session, then continuing, matches continuing without the round-trip.
  - different `runSeed` → variation (10-seed spread, >1 distinct answer).
  - candidate identity: the interview subject's id matches the Phase 2
    candidate's own id; restarting the session from scratch (same
    aggregate) reproduces the identical result.
  - question choice changes revealed information (technical vs.
    reasonForChange on the same candidate yield different category/answer
    content).
  - no raw `HiddenParameters` field name ever appears in persisted session
    JSON (5 forbidden keys checked directly against the encoded string).
  - interview → existing offer/hire path: deciding "hired" changes nothing
    about `stage`/offer authority; the existing, unmodified
    `PublicDemoSalaryOfferEvaluator`/`acceptOffer` still decide
    acceptance.
  - reject/decline path: deciding "見送る" moves `stage` to `rejected`,
    and a subsequent `acceptOffer` attempt is confirmed a no-op (the new
    guard).
  - action-slot consumption exactly once: `salesUsed` and `state` itself
    (via `identical()`) are unchanged across the entire interactive
    session; a stray repeated `completeInterview` call afterward still
    doesn't consume a second slot (pre-existing idempotency, reconfirmed).
  - legacy fixture applicant (`app-01`): interview works via the id-only
    fallback; the fallback's underlying flavor name is confirmed
    `runSeed`-independent while a same-seed same-question repeat is still
    exactly reproducible; confirmed this really is the fallback path (the
    seeded generator itself returns `null` for this id).
  - a save with no `interviewSessions` key migrates to an empty list,
    every other field preserved exactly.
  - Finance/Month regression: every interview-session command leaves
    `state` `identical()` to its input; closing May with an in-progress,
    undecided interview session on the roster still closes normally.
- New: `test/ui/public_demo/public_demo_recruitment_interview_visual_test.dart`
  (8 tests) — the full interview flow (open → 3 questions → reverse →
  decide "採用候補として進める") and the reject path, at 360×800/390×844,
  TextScaler 1.0/1.3/2.0 for the hire path (2×3) and 1.0 for the reject
  path (2×1): `tester.takeException()` is null throughout every phase
  transition, plus on-screen rect bounds checks on the dialog's close
  button and the return-trip `合格・給与提示` button.
- New: `test/ui/public_demo/public_demo_interview_test_helpers.dart` —
  shared widget-test driver (`openRecruitmentInterviewDialog`/
  `continueRecruitmentInterviewToHireDecision`/
  `driveRecruitmentInterviewToHireDecision`), used by both the new visual
  test and the 4 existing UI tests below.
- Updated (behavior-preserving, minimal insertion — see "UI" above for why
  this was unavoidable: the whole point of this phase is that `合格・給与
  提示` no longer appears the instant `採用面談` is tapped):
  `test/ui/public_demo/public_demo_01_success_playthrough_test.dart`,
  `public_demo_01_home_runtime_read_test.dart`,
  `public_demo_01_recovery_ui_test.dart`,
  `public_demo_01_suzuki_sales_yearend_boundary_test.dart` — each gained
  exactly one `driveRecruitmentInterviewToHireDecision(tester)` call
  between the existing `採用面談` tap and the existing `合格・給与提示`
  tap; every other assertion in these files is unchanged.
- Updated: `test/game/public_demo/public_demo_recovery_aggregate_test.dart`
  — one exact-key-set assertion (`{applicants, engineers, assignments}`)
  extended to include the new, additive `interviewSessions` key; the
  behavior under test (Recovery's own assignment authority) is untouched.
- Updated: `test/presentation/home/home_recommended_action_test.dart` —
  the new `applicantContinueInterview` kind inserted into the existing
  strict-ordering assertion at its documented position.
- `flutter test test/game/public_demo/` — **570 tests passed**.
- `flutter test test/ui/public_demo/ test/presentation/home/` — **682
  tests passed** (this is the parametrized count; several test names
  repeat once per generated scenario/seed).
- Final full suite: **`flutter test --concurrency=6`, whole repo — 1856
  tests passed, exit code 0.**

## Changed files

- `lib/game/public_demo/public_demo_recruitment_interview.dart` (new)
- `lib/game/public_demo/public_demo_rng.dart` — `legacyFixtureSeed` added.
- `lib/game/public_demo/public_demo_workflow_state.dart` —
  `interviewSessions` field, `startInterviewSession`/
  `updateInterviewSession`/`rejectApplicant` methods, JSON round trip.
- `lib/game/public_demo/public_demo_aggregate.dart` —
  `startInterviewSession`/`askInterviewQuestion`/
  `answerInterviewReverseQuestion`/`concludeInterviewSession`, one added
  persistence invariant.
- `lib/game/public_demo/public_demo_binding_offer.dart` — one additive
  guard in `PublicDemoOfferAcceptance.accept` for the `rejected` stage.
- `lib/ui/public_demo/public_demo_recruitment_interview_dialog.dart` (new)
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — card
  wiring, HOME recommended-action wiring, new helper methods.
- `lib/presentation/home/models/home_recommended_action.dart` — new
  `applicantContinueInterview` kind.
- `lib/presentation/home/models/home_navigator_display.dart` — one new
  `switch` case for it.
- `test/game/public_demo/public_demo_recruitment_interview_test.dart` (new)
- `test/ui/public_demo/public_demo_recruitment_interview_visual_test.dart`
  (new)
- `test/ui/public_demo/public_demo_interview_test_helpers.dart` (new)
- `test/game/public_demo/public_demo_recovery_aggregate_test.dart` — one
  assertion updated (see Tests).
- `test/presentation/home/home_recommended_action_test.dart` — one
  assertion updated (see Tests).
- `test/ui/public_demo/public_demo_01_success_playthrough_test.dart`,
  `public_demo_01_home_runtime_read_test.dart`,
  `public_demo_01_recovery_ui_test.dart`,
  `public_demo_01_suzuki_sales_yearend_boundary_test.dart` — one driver
  call inserted each (see Tests).
- `docs/reports/SES_CORE-GAMEPLAY_Phase3_Recruitment-Interview_Result.md`
  (this report, new)

## Untouched authorities

- `RecruitmentInterviewEngine`, `recruitment_interview_content.dart`,
  `RecommendationEngine.postInterviewAssessment` — not modified at all.
- `PublicDemoAggregate.completeInterview`, `PublicDemoState
  .useSalesSlotForInterview`/`.useSalesSlot`, `PublicDemoApplicant
  .completeInterview` — not modified.
- `PublicDemoSalaryOfferEvaluator`, `PublicDemoBindingOffer`,
  `PublicDemoJoinTransaction` — not modified.
- `PublicDemoSeededRecruitmentGenerator` (Phase 2) — not modified; used
  read-only via its own documented `regenerateDomainApplicant` seam.
- Finance formulas, starting cash, baseline payroll, month-close authority
  (`PublicDemoMonthlyClose`, `advanceToMay`/`closeApril`/...) — not
  touched; confirmed via the "Finance/Month regression" test and the full
  `test/game/public_demo/` suite passing unmodified.
- `PublicDemoSaveCodec`/`schemaVersion` — not touched (the new field is
  additive at the `PublicDemoWorkflowState` layer, below that codec).
- HOME layout/visual SSOT — not touched; the one HOME change
  (`applicantContinueInterview`) is a typed recommended-action kind behind
  the pre-existing eligibility/dispatch machinery, not a layout change.

## Known limitations

- **`companyCredit`/`officeType` substitution.** Public Demo has no
  "company credit" or `OfficeType` concept of its own. The initial
  `companyImpression` roll (`RecruitmentInterviewEngine.start`) uses a
  fixed `companyCredit: 0` and `OfficeType.smallOffice` (the founding-era
  baseline) — a small, bounded, one-time offset on the very first
  impression value, never read by any other Public Demo authority.
  `companySize` uses Public Demo's own real `workflow.engineers.length`.
  A future phase adding a genuine Public Demo office/reputation concept
  should revisit this substitution.
- **Legacy-fixture flavor is cosmetic only, not `runSeed`-linked.** See
  "Candidate identity" above — documented and tested, but worth
  re-examining if the founding pool itself is ever replaced with seeded
  generation in a later phase (at which point this fallback becomes dead
  code, not a design flaw to fix).
- **`HomeRecommendedActionKind.presentationPriority` renumbering.**
  Inserting `applicantContinueInterview` required shifting
  `applicantInterview`/`applicantReviewResume`'s existing priority
  integers up by one each (46→47 unaffected, 47→48, 48→49) to make room;
  their *relative* order and every other kind's value is unchanged, and
  the one test asserting this ordering was updated in lockstep.
- **No new UI-level "in-progress interview" indicator on résumé-review
  cards other than the button label swap** (`面談を行う` vs `面談を続け
  る`) — sufficient for this phase's scope per the task's own "Visual
  Complete 2はまだ実施しない" instruction, but a future visual pass could
  add a richer progress affordance.

## Phase 4 (Random Projects) connection

Phase 4 is out of scope for this change and nothing here should need to be
revisited by it: recruitment/interview state lives entirely under
`PublicDemoWorkflowState.applicants`/`interviewSessions`, independent of
whatever project-generation state Phase 4 introduces. The one shared
surface, `PublicDemoRng`, already reserves `projectGeneration`/
`projectInterview` as separate namespaces (Phase 1) — Phase 4 should follow
this same "new adapter file, new namespace, existing engine reused"
pattern rather than touching anything under `public_demo_recruitment*`.

## FINISH

1. Committed: `a08eb406d0697b37c7032190dd1f4834439e47cb`.
2. Pushed to `claude/ses-phase3-recruitment-interview-bbu0h2`.
3. PR opened (base = `main`): https://github.com/perusonao/smile_enjoy_story/pull/203
4. PR URL confirmed above.
5. This report updated with final HEAD SHA / PR URL (this commit).

## Final verdict

**PASS**
