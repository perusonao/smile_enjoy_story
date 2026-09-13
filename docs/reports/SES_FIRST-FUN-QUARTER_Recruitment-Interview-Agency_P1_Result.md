# SES First Fun Quarter — Recruitment Interview Agency — P1 Fix — Result Report

## Scope

AI Replay Audit #3's single open P1: the interactive recruitment-interview
Q&A's answer content had zero effect on the interview's pass/fail outcome,
and the candidate card's "評価" (evaluation) label was already showing the
pass/fail read before the Q&A even started — so the interview *felt*
decided in advance, with the player's in-dialog choices along for the ride.

Out of scope (unchanged, per task instructions): Aug-Feb, Year-end, Main
Game, monthly accounting, salary balance, recruitment media balance, save
schema, Parallel Sales, training, bonus, HOME redesign. No same-root-cause
P2 was found (see "Same-root P2 fixes" below).

## Phase 1 Fresh Audit

Traced every authority named in the task against the real code before
writing anything:

1. **Candidate generation "評価"** —
   `PublicDemoSeededRecruitmentGenerator._project`/`_inexperiencedCandidate`
   (`lib/game/public_demo/public_demo_recruitment_candidate_generator.dart`)
   set `PublicDemoApplicant.interviewScore` once, at candidate generation,
   from `_interviewScore(PersonalityTraits p) => (62 + (p.communication-3)*9
   + (p.seriousness-3)*5).clamp(0,100)` — a pure function of the
   candidate's personality, rolled before any interview exists. The field
   is immutable afterward (no setter, `copyWith` never touches it).

2. **Pre-interview card "評価"** —
   `public_demo_01_placeholder_screen.dart`'s applicant card rendered
   `Text(publicDemoApplicantEvaluationLabel(a.interviewScore))` as soon as
   `a.stage == PublicDemoApplicantStage.interviewed` — the stage reached by
   tapping "採用面談" (`recruit(i)` → `completeInterview`), which happens
   **before** the interactive Q&A dialog is ever opened. The label
   (`>= 60` ⇒ "採用基準を満たしています") was therefore on screen, next to
   the "面談を行う" button, before a single question had been asked.

3. **Interactive Q&A** — `PublicDemoRecruitmentInterviewDialog`
   (`lib/ui/public_demo/public_demo_recruitment_interview_dialog.dart`)
   drives `RecruitmentInterviewEngine` (`lib/game/engine/
   recruitment_interview_engine.dart`): the player picks 3 of 6
   `InterviewQuestionCategory` questions (`ask`), the candidate's answer is
   generated from their own hidden traits (skill/dishonesty/etc, not a
   player choice), then the player answers one reverse question from a set
   of ranked-quality choices (`answerReverse`).

4. **Are Q&A answers scored?** Yes — each `ApplicantAnswer` carries
   `specificity`/`consistency`/`confidence`/`credibility` (computed in
   `RecruitmentInterviewEngine.generateAnswer`). These only fed two
   session meters, `candidateKnowledge` and `companyImpression` — both
   purely presentational (gauges/reaction text) and never read anywhere
   else.

5. **Where pass/fail is actually decided** — `_DecisionBar`
   (`public_demo_recruitment_interview_dialog.dart`) is two unconditional
   buttons, "見送る"/"採用候補として進める", wired straight to
   `PublicDemoAggregate.concludeInterviewSession(applicantId, outcome)`.
   Nothing in that call path reads `candidateKnowledge`, `companyImpression`,
   or any `ApplicantAnswer` field — `outcome` is exactly and only what the
   player tapped. **Confirmed the audit's claim in code**: the Q&A content
   has no bearing on this decision; it is a free player choice either way.
   Downstream, the 合格・給与提示 offer button's actual eligibility gate —
   `a.interviewScore >= 60` — read only the item-1 pre-interview number,
   never anything from the session. So even the one thing the interactive
   Q&A *could* have decided (whether an offer ever becomes possible) was
   fully pre-determined at candidate generation, before the interview.

6. **Salary-offer eligibility** — two independent gates, confirmed in
   `public_demo_binding_offer.dart` (`hasBeenInterviewed`/stage != rejected
   — an unforgeable paperwork check, untouched by this fix) and the UI's own
   `a.interviewScore >= 60` button/HOME-action gate (item 2/5) — the second
   gate is what this fix changes.

7. **Candidate lifecycle** — `PublicDemoApplicantStage` enum
   (`public_demo_recruitment.dart`), `PublicDemoInterviewRecord`/
   `PublicDemoJoinRecord` as unforgeable provenance. Untouched.

8. **Save/reload** — `PublicDemoApplicant`/`RecruitmentInterviewSession`/
   `ApplicantAnswer` `toJson`/`fromJson` already persist everything this fix
   reads (`interviewScore`, `applicantAnswers[].credibility`, `completed`).
   No schema change was needed or made.

**Conclusion**: the audit's finding was accurate and reproducible in code,
not a misreading — proven with a focused test before any fix (see
"Why Q&A now affects outcome" below for the exact numbers).

## Chosen solution: 第一候補 (wire Q&A into the existing authority)

The Fresh Audit found this **did not** require save-schema, economy, or
lifecycle changes — every input the fix needed
(`PublicDemoApplicant.interviewScore`, `RecruitmentInterviewSession
.applicantAnswers[].credibility`, `.completed`) already existed and was
already persisted. So the Alternative (honest-UI-only) was not needed; the
real integration was implemented instead.

### Fix

**New pure, derived function** — `PublicDemoRecruitmentInterview
.finalEvaluationScore({applicant, session})` (`lib/game/public_demo/
public_demo_recruitment_interview.dart`), added to the existing, designated
Public-Demo/main-engine adapter class (no new authority, no new save
field, no new RNG roll):

```dart
static int? finalEvaluationScore({
  required PublicDemoApplicant applicant,
  required RecruitmentInterviewSession? session,
}) {
  if (session == null || !session.completed || session.applicantAnswers.isEmpty) {
    return null;
  }
  final averageCredibility = session.applicantAnswers
          .fold<int>(0, (sum, answer) => sum + answer.credibility) /
      session.applicantAnswers.length;
  final credibilityDelta = ((averageCredibility - 50) / 2.5).round();
  return (applicant.interviewScore + credibilityDelta).clamp(0, 100);
}
```

- Returns `null` before the interview session is genuinely `completed` —
  the mechanism that prevents any pre-interview reveal.
- Folds in the average `credibility` of exactly the 3 answers the player
  chose to hear (asking a different question category samples a different,
  real, credibility-scored answer from the same candidate), moving the
  score up to ±18 around the unchanged `interviewScore` baseline.
- `PublicDemoApplicant.interviewScore` itself is never mutated — every
  other existing reader of it (e.g.
  `PublicDemoEngineerRuntime._usesPotentialTemplate`) is unaffected.

**UI wiring** (`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`)
— added `_completedInterviewSession`/`_finalInterviewEvaluation` helpers,
and replaced every place that read `a.interviewScore` for the *outcome*
decision (never the résumé/experience/salary display, which is untouched)
with `_finalInterviewEvaluation(a)`:
- The card's "評価" label + 合格・給与提示 button's `>= 60` gate.
- The lifecycle-bucket "dead end" check (`interviewScore < 60` → `closed`).
- HOME's guided-route action emission (`applicantSalaryOffer`).

**The "評価" label and its explanation text now render only inside the
`_interviewDecidedHired(a.id)` branch** — i.e., only after the player has
completed the interactive Q&A and tapped "採用候補として進める" — never in
the "面談を行う"/"面談を続ける" (not-yet-decided) branch. Before that point
there is nothing to leak: `_finalInterviewEvaluation` itself returns `null`
until the session is `completed`.

### Why Q&A now affects outcome — proof, not assertion

Verified end-to-end against the real production path
(`test/ui/public_demo/public_demo_recruitment_interview_outcome_test.dart`),
seed 555's first `engineer`-medium candidate (`interviewScore` baseline 62,
i.e. already just above the 60 line before any Q&A):

| Question set asked | Final evaluation | Offer button | Label |
|---|---|---|---|
| technical / career / reasonForChange | **67** | enabled | 採用基準を満たしています |
| futureCareer / teamwork / workStyle | **53** | disabled | 採用基準を下回っています |

Same candidate, same seed, same baseline `interviewScore` — the *only*
difference is which 3 real questions the player chose to ask and what
credible answers came back. That is a genuine, deterministic (reload-safe)
flip across the pass line, driven by the interactive Q&A, not a coin flip:
`test/game/public_demo/public_demo_recruitment_interview_test.dart`'s new
unit-test group proves the underlying function is deterministic, that good
(high-credibility) answers are always advantageous and poor answers always
disadvantageous relative to the same baseline, and that it clamps to
[0,100] — never fully random, never neutral.

## Before/after behavior

- **Before**: 評価 visible the instant "採用面談" is tapped, before the
  Q&A dialog even opens; picking any questions/reverse-answer never changed
  whether the offer button would ever be enabled.
- **After**: no 評価 anywhere on the card until the player has completed
  the interactive Q&A and chosen "採用候補として進める"; the evaluation
  shown then — and the offer button's enabled state — depends on which
  questions were asked and how credible the candidate's actual answers to
  them were. Causality now runs 候補者情報 → 面談 → 質問への回答 → 面談結果
  → 給与提示可否, exactly as required.
- **Unchanged**: "見送る" still immediately rejects (unaffected by this
  fix); `PublicDemoOfferAcceptance`/salary math/acceptance authority;
  `hasBeenInterviewed` paperwork gate; save schema; all pre-existing
  résumé/experience/salary display fields.

## Files changed

- `lib/game/public_demo/public_demo_recruitment_interview.dart` —
  added `finalEvaluationScore`.
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` — added
  `_completedInterviewSession`/`_finalInterviewEvaluation`; rewired the
  card label/button, lifecycle bucket, and HOME action emission to use it;
  moved the "評価" block inside the decided-hired branch.
- `test/game/public_demo/public_demo_recruitment_interview_test.dart` —
  new `finalEvaluationScore` unit-test group (null-before-completion, good
  vs. poor answers, determinism, clamping, no mutation of `interviewScore`).
- `test/ui/public_demo/public_demo_recruitment_interview_outcome_test.dart`
  (new) — proves no pre-interview reveal, and the pass/fail flip described
  above, against the real production UI.
- `test/ui/public_demo/public_demo_01_success_playthrough_test.dart` /
  `public_demo_01_recovery_ui_test.dart` — the pre-existing assertion of
  "評価" appearing immediately after "採用面談" (before any Q&A) was itself
  an encoding of the bug; moved to after the interview is actually decided,
  with the label text re-verified against the fixture's real seed-9 numbers
  (baseline 80 + this fixture's fixed question set → 83, still "満たしてい
  ます", so the surrounding success-path assertions are unaffected).

## Tests

- `flutter analyze` (whole repo): **no issues found**.
- `git diff --check`: clean.
- Focused: `test/game/public_demo/public_demo_recruitment_interview_test.dart`
  — 17/17 pass (11 pre-existing + 6 new).
- Focused: `test/ui/public_demo/public_demo_recruitment_interview_outcome_test.dart`
  (new) — 2/2 pass.
- `test/ui/public_demo/public_demo_01_success_playthrough_test.dart` +
  `public_demo_01_recovery_ui_test.dart` — 3/3 pass after the assertion move.
- Full `flutter test test/game/public_demo` — **1022/1022 pass**.
- Full `flutter test test/ui/public_demo` — see final HEAD section below.
- Mobile overflow (360x800, 390x844): already covered by the untouched
  `public_demo_recruitment_interview_visual_test.dart` (no overflow across
  both viewports × 3 textScale factors for the full flow, reject path, and
  dismiss/reopen); still passing (button rendering, not gating, is what
  that suite checks, so the new enabled/disabled gate value doesn't change
  its assertions).
- Regression checklist (task's minimum list): interview-before / interview
  start / good answer / poor answer / pass / fail / offer possible-impossible
  — all directly exercised by the new outcome test above. HOME guided route
  — `_addApplicantStageCandidate`'s `applicantSalaryOffer` emission updated
  and covered by existing HOME-action tests (unchanged call shape, only the
  gate value source changed, exercised transitively by the success
  playthrough test's HOME-guided card flow). Sales direct route — same card
  code path, covered by the outcome test (no HOME involved there). Save/
  reload — no schema change; pre-existing round-trip tests
  (`toJson`/`fromJson`) in the recruitment-interview test file still pass
  unchanged, and `finalEvaluationScore` is re-derived from already-persisted
  fields, so a reloaded save reproduces the identical evaluation. Modal
  close/reopen — pre-existing "dismiss never commits" tests in the visual
  test file, untouched and still passing. Double interview — pre-existing
  "action-slot consumption exactly once" test, untouched and still passing.
  Multiple candidates — no change to per-applicant iteration/list rendering;
  the fix is purely a per-applicant, per-session pure computation.
- Claude self-hardening review: performed (see below); no findings required
  a further code change beyond what is already reflected above.

## Same-root P2 fixes

None found. The one related, pre-existing P2 comment in the codebase (PR
#252, "decided-hired but interviewScore < 60 is a genuine dead end") was
already a *documented, intentional* terminal state, not a bug sharing this
P1's root cause — it is preserved as-is, just now keyed off
`_finalInterviewEvaluation` instead of the frozen pre-interview
`interviewScore`, which is exactly this P1's own fix.

## Known limitations

- The reverse-question answer's authored `quality` values (which the player
  also actively chooses) are not part of `finalEvaluationScore` — they
  continue to drive only `companyImpression` (the candidate's own read on
  the company), which is a semantically different axis (would matter to
  offer *acceptance*, not the company's hire/no-hire read) and, in Public
  Demo, is not otherwise read by any acceptance authority either. Folding
  it in was considered and deliberately left out to avoid mixing two
  different existing signals into one number without a clear domain reason;
  the fix already satisfies "good answers help, poor answers hurt, not
  fully random" using only the candidate-answer-credibility axis.
- The ±18-point swing around the baseline is a judgment call sized to be
  able to flip a genuinely borderline candidate (baseline in roughly
  50-69) without letting Q&A performance alone override a clearly strong or
  clearly weak candidate's résumé-based baseline. Not tuned against any
  balance/economy target — this is presentation/agency correctness, not a
  balance change, per scope.

## Current status

Fix implemented, tested, and verified. Committing and pushing to the
designated branch next; PR to be opened against `main`.

## Next action

Commit → push → open PR → report final HEAD SHA and PR URL.

## Base main SHA

`55b6c64086032e9fdbe2ce19e7821170dd3902d0`
