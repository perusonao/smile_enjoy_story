import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/models/recruitment_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_candidate_generator.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';

import 'test_support/public_demo_legacy_applicant_test_helpers.dart';

/// CORE-GAMEPLAY Phase 3 (Recruitment Interview) test coverage, exercised
/// entirely against [PublicDemoAggregate] -- the same authoritative entry
/// points the UI dialog itself calls
/// (`lib/ui/public_demo/public_demo_recruitment_interview_dialog.dart`).

/// A May aggregate with one seeded, genuinely-interviewed
/// `engineer`-medium applicant -- the real production path
/// (`recruit` -> `completeInterview`), never a fabricated fixture.
PublicDemoAggregate _mayWithSeededInterviewedApplicant({required int runSeed}) {
  final started = PublicDemoAggregate.initial(
    runSeed: runSeed,
  ).closeApril(monthlyExpenses: 800000);
  final recruited = started.recruit(PublicDemoRecruitmentMedium.engineer);
  final game = recruited.aggregate!;
  final applicant = game.workflow.applicants.firstWhere(
    (candidate) => candidate.id.startsWith('recruitment-'),
  );
  final result = game.completeInterview(applicant.id);
  expect(result.isCompleted, isTrue);
  return result.aggregate;
}

String _seededApplicantId(PublicDemoAggregate aggregate) => aggregate
    .workflow
    .applicants
    .firstWhere((candidate) => candidate.id.startsWith('recruitment-'))
    .id;

void main() {
  group('CORE-GAMEPLAY Phase 3: interactive recruitment interview', () {
    test('same runSeed+month+applicant+question -> identical session', () {
      final a1 = _mayWithSeededInterviewedApplicant(runSeed: 4242);
      final a2 = _mayWithSeededInterviewedApplicant(runSeed: 4242);
      final id1 = _seededApplicantId(a1);
      final id2 = _seededApplicantId(a2);
      expect(id1, id2, reason: 'same runSeed must generate the same id');

      final s1 = a1
          .startInterviewSession(id1)
          .askInterviewQuestion(id1, InterviewQuestionCategory.technical)
          .askInterviewQuestion(id1, InterviewQuestionCategory.teamwork)
          .askInterviewQuestion(id1, InterviewQuestionCategory.workStyle);
      final s2 = a2
          .startInterviewSession(id2)
          .askInterviewQuestion(id2, InterviewQuestionCategory.technical)
          .askInterviewQuestion(id2, InterviewQuestionCategory.teamwork)
          .askInterviewQuestion(id2, InterviewQuestionCategory.workStyle);

      expect(
        s1.workflow.interviewSessions.single.toJson(),
        s2.workflow.interviewSessions.single.toJson(),
      );
    });

    test('reload mid-interview: continuing after a save/load round-trip '
        'matches continuing without one', () {
      final withoutReload = _mayWithSeededInterviewedApplicant(runSeed: 777);
      final id = _seededApplicantId(withoutReload);
      final partial = withoutReload
          .startInterviewSession(id)
          .askInterviewQuestion(id, InterviewQuestionCategory.career);

      // Round-trip through the real save codec surface: toJson/fromJson,
      // exactly what a save/reload does.
      final reloaded = PublicDemoAggregate.fromJson(partial.toJson());
      expect(reloaded.toJson(), partial.toJson());

      final continuedWithoutReload = partial.askInterviewQuestion(
        id,
        InterviewQuestionCategory.reasonForChange,
      );
      final continuedAfterReload = reloaded.askInterviewQuestion(
        id,
        InterviewQuestionCategory.reasonForChange,
      );
      expect(
        continuedAfterReload.workflow.interviewSessions.single.toJson(),
        continuedWithoutReload.workflow.interviewSessions.single.toJson(),
      );
    });

    test(
      'different runSeed produces variation across a spread of interviews',
      () {
        final answers = <String>{};
        for (var seed = 1; seed <= 10; seed++) {
          final game = _mayWithSeededInterviewedApplicant(runSeed: seed * 91);
          final id = _seededApplicantId(game);
          final asked = game
              .startInterviewSession(id)
              .askInterviewQuestion(id, InterviewQuestionCategory.technical);
          answers.add(
            asked
                .workflow
                .interviewSessions
                .single
                .applicantAnswers
                .single
                .answer,
          );
        }
        expect(
          answers.length,
          greaterThan(1),
          reason: 'distinct runSeeds must not all produce the same answer',
        );
      },
    );

    test('candidate identity: the interview subject is the exact Phase 2 '
        'candidate, never a re-rolled one', () {
      final game = _mayWithSeededInterviewedApplicant(runSeed: 555);
      final id = _seededApplicantId(game);
      final applicant = game.workflow.applicants.firstWhere(
        (candidate) => candidate.id == id,
      );
      final started = game.startInterviewSession(id);
      // The interview session is keyed by the same Public Demo applicant
      // id the player already saw during recruitment/résumé review.
      expect(
        started.workflow.interviewSessions.single.applicantId,
        applicant.id,
      );
      // Starting again from the same aggregate a second time must resolve
      // to the exact same underlying domain Applicant (same name/traits),
      // not a fresh draw -- verified indirectly via identical answer
      // content for the same question.
      final askedOnce = started.askInterviewQuestion(
        id,
        InterviewQuestionCategory.futureCareer,
      );
      final askedAgainFromScratch = game
          .startInterviewSession(id)
          .askInterviewQuestion(id, InterviewQuestionCategory.futureCareer);
      expect(
        askedOnce.workflow.interviewSessions.single.toJson(),
        askedAgainFromScratch.workflow.interviewSessions.single.toJson(),
      );
    });

    test('question choice changes the information revealed', () {
      final game = _mayWithSeededInterviewedApplicant(runSeed: 999);
      final id = _seededApplicantId(game);
      final askedTechnical = game
          .startInterviewSession(id)
          .askInterviewQuestion(id, InterviewQuestionCategory.technical);
      final askedReasonForChange = game
          .startInterviewSession(id)
          .askInterviewQuestion(id, InterviewQuestionCategory.reasonForChange);

      final technicalAnswer = askedTechnical
          .workflow
          .interviewSessions
          .single
          .applicantAnswers
          .single;
      final reasonAnswer = askedReasonForChange
          .workflow
          .interviewSessions
          .single
          .applicantAnswers
          .single;
      expect(technicalAnswer.category, InterviewQuestionCategory.technical);
      expect(reasonAnswer.category, InterviewQuestionCategory.reasonForChange);
      expect(
        technicalAnswer.answer,
        isNot(reasonAnswer.answer),
        reason: 'different questions must reveal different information',
      );
    });

    test(
      'no raw HiddenParameters value ever appears in persisted session JSON',
      () {
        final game = _mayWithSeededInterviewedApplicant(runSeed: 314);
        final id = _seededApplicantId(game);
        final withSession = game
            .startInterviewSession(id)
            .askInterviewQuestion(id, InterviewQuestionCategory.reasonForChange)
            .askInterviewQuestion(id, InterviewQuestionCategory.futureCareer)
            .askInterviewQuestion(id, InterviewQuestionCategory.workStyle);
        final encoded = jsonEncode(
          withSession.workflow.interviewSessions.single.toJson(),
        );
        for (final forbiddenKey in const [
          'retention',
          'turnoverIntent',
          'growthPotential',
          'dishonesty',
          'stressTolerance',
        ]) {
          expect(
            encoded.contains(forbiddenKey),
            isFalse,
            reason:
                '$forbiddenKey is a HiddenParameters field and must never '
                'appear in the persisted interview session',
          );
        }
      },
    );

    test('interview session -> existing offer/hire path: proceeding still '
        'uses the untouched PublicDemoOfferAcceptance authority', () {
      final game = _mayWithSeededInterviewedApplicant(runSeed: 12);
      final id = _seededApplicantId(game);
      final conversationComplete = game
          .startInterviewSession(id)
          .askInterviewQuestion(id, InterviewQuestionCategory.technical)
          .askInterviewQuestion(id, InterviewQuestionCategory.career)
          .askInterviewQuestion(id, InterviewQuestionCategory.teamwork);
      final session = conversationComplete.workflow.interviewSessions.single;
      final afterReverse = conversationComplete.answerInterviewReverseQuestion(
        id,
        0,
      );
      expect(
        afterReverse.workflow.interviewSessions.single.conversationComplete,
        isTrue,
      );

      final decided = afterReverse.concludeInterviewSession(
        id,
        InterviewOutcome.hired,
      );
      expect(decided.workflow.interviewSessions.single.completed, isTrue);
      expect(
        decided.workflow.interviewSessions.single.outcome,
        InterviewOutcome.hired,
      );
      // Deciding "hired" must not itself change the applicant's stage --
      // the existing offer flow is still the sole hiring authority.
      final applicant = decided.workflow.applicants.firstWhere(
        (candidate) => candidate.id == id,
      );
      expect(applicant.stage, PublicDemoApplicantStage.interviewed);

      final offer = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: applicant,
        offeredMonthlySalary: applicant.requestedMonthlySalary,
      );
      final offered = decided.acceptOffer(
        applicantId: id,
        offer: offer,
        fiscalCloseId: PublicDemoFiscalCloseId.forMonth(decided.state.month),
      );
      final finalApplicant = offered.workflow.applicants.firstWhere(
        (candidate) => candidate.id == id,
      );
      expect(
        finalApplicant.stage,
        anyOf(
          PublicDemoApplicantStage.offerAccepted,
          PublicDemoApplicantStage.offerDeclined,
        ),
        reason:
            'the existing, unmodified salary-offer authority alone '
            'decides acceptance',
      );
      expect(session.applicantId, id);
    });

    test('reject/decline path: 見送る moves the applicant to the rejected '
        'stage and closes off the offer flow', () {
      final game = _mayWithSeededInterviewedApplicant(runSeed: 88);
      final id = _seededApplicantId(game);
      final conversationComplete = game
          .startInterviewSession(id)
          .askInterviewQuestion(id, InterviewQuestionCategory.technical)
          .askInterviewQuestion(id, InterviewQuestionCategory.career)
          .askInterviewQuestion(id, InterviewQuestionCategory.teamwork)
          .answerInterviewReverseQuestion(id, 0);

      final decided = conversationComplete.concludeInterviewSession(
        id,
        InterviewOutcome.rejected,
      );
      final applicant = decided.workflow.applicants.firstWhere(
        (candidate) => candidate.id == id,
      );
      expect(applicant.stage, PublicDemoApplicantStage.rejected);
      expect(
        decided.workflow.interviewSessions.single.outcome,
        InterviewOutcome.rejected,
      );

      // A rejected applicant can never subsequently receive a binding
      // offer -- the offer flow's own authority (untouched, plus the one
      // Phase-3-added guard for this exact new terminal stage) is still
      // the sole hiring gate.
      final offer = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: applicant,
        offeredMonthlySalary: applicant.requestedMonthlySalary,
      );
      final afterOfferAttempt = decided.acceptOffer(
        applicantId: id,
        offer: offer,
        fiscalCloseId: PublicDemoFiscalCloseId.forMonth(decided.state.month),
      );
      final unchanged = afterOfferAttempt.workflow.applicants.firstWhere(
        (candidate) => candidate.id == id,
      );
      expect(unchanged.stage, PublicDemoApplicantStage.rejected);
      expect(unchanged.hasBindingOffer, isFalse);
    });

    test('action-slot consumption exactly once: the interactive session never '
        'consumes a second sales slot', () {
      final game = _mayWithSeededInterviewedApplicant(runSeed: 33);
      final id = _seededApplicantId(game);
      final usedAfterInterview = game.state.salesUsed;

      final afterSession = game
          .startInterviewSession(id)
          .askInterviewQuestion(id, InterviewQuestionCategory.technical)
          .askInterviewQuestion(id, InterviewQuestionCategory.career)
          .askInterviewQuestion(id, InterviewQuestionCategory.teamwork)
          .answerInterviewReverseQuestion(id, 0)
          .concludeInterviewSession(id, InterviewOutcome.hired);

      expect(afterSession.state.salesUsed, usedAfterInterview);
      expect(identical(afterSession.state, game.state), isTrue);

      // Re-attempting completeInterview (e.g. a stray double-tap) also
      // never consumes a second slot -- pre-existing idempotency,
      // reconfirmed here since Phase 3 opens the dialog right after it.
      final retried = afterSession.completeInterview(id);
      expect(retried.aggregate.state.salesUsed, usedAfterInterview);
    });

    test('legacy fixture applicant: interview still works via the '
        'id-only fallback, deterministically', () {
      // CORE-GAMEPLAY Phase 4.5: `app-01` is one of the hand-authored
      // founding-pool fixtures (`publicDemoMayApplicants`), never produced
      // by PublicDemoSeededRecruitmentGenerator, and no longer pre-seeded by
      // `PublicDemoWorkflowState.initial()` either — this simulates a save
      // created before that fix, where `app-01` really was persisted.
      final game = withLegacyFoundingApplicants(
        PublicDemoAggregate.initial(
          runSeed: 1,
        ).closeApril(monthlyExpenses: 800000),
      );
      final legacyApplicant = game.workflow.applicants.firstWhere(
        (candidate) => candidate.id == 'app-01',
      );
      final interviewed = game.completeInterview(legacyApplicant.id).aggregate;

      final started = interviewed.startInterviewSession(legacyApplicant.id);
      final session = started.workflow.interviewSessions.single;
      expect(session.applicantId, legacyApplicant.id);

      // The underlying "who is this person" flavor (name) behind the
      // fallback is deterministic across two independent playthroughs with
      // DIFFERENT runSeeds -- the fallback Applicant itself is intentionally
      // id-only, not runSeed-derived (see PublicDemoRecruitmentInterview's
      // own doc).
      final nameWithRunSeed1 =
          PublicDemoRecruitmentInterview.domainApplicantFor(
            runSeed: 1,
            applicant: legacyApplicant,
          ).name;
      final nameWithRunSeed2 =
          PublicDemoRecruitmentInterview.domainApplicantFor(
            runSeed: 2,
            applicant: legacyApplicant,
          ).name;
      expect(
        nameWithRunSeed1,
        nameWithRunSeed2,
        reason:
            'the legacy-fixture fallback Applicant is id-only, not '
            'runSeed-derived',
      );

      // Same-seed reproducibility for the fallback still holds end-to-end:
      // asking the same question from two independently-constructed
      // aggregates that share both runSeed and month reproduces the exact
      // same session.
      final sameSeedGame = withLegacyFoundingApplicants(
        PublicDemoAggregate.initial(
          runSeed: 1,
        ).closeApril(monthlyExpenses: 800000),
      );
      final sameSeedStarted = sameSeedGame
          .completeInterview(legacyApplicant.id)
          .aggregate
          .startInterviewSession(legacyApplicant.id);
      final askedHere = started.askInterviewQuestion(
        legacyApplicant.id,
        InterviewQuestionCategory.technical,
      );
      final askedThere = sameSeedStarted.askInterviewQuestion(
        legacyApplicant.id,
        InterviewQuestionCategory.technical,
      );
      expect(
        askedHere.workflow.interviewSessions.single.toJson(),
        askedThere.workflow.interviewSessions.single.toJson(),
      );

      // Confirms this really is the fallback path, not a real recovered
      // candidate: the seeded generator itself has nothing for this id.
      expect(
        PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant(
          runSeed: 1,
          applicantId: legacyApplicant.id,
        ),
        isNull,
      );
    });

    test(
      'a save from before this phase (no interviewSessions key) migrates to an empty list',
      () {
        final game = PublicDemoAggregate.initial(
          runSeed: 9,
        ).closeApril(monthlyExpenses: 800000);
        final json = game.toJson();
        final workflowJson = Map<String, dynamic>.from(
          json['workflow'] as Map<String, dynamic>,
        )..remove('interviewSessions');
        final legacyJson = {...json, 'workflow': workflowJson};

        final restored = PublicDemoAggregate.fromJson(legacyJson);
        expect(restored.workflow.interviewSessions, isEmpty);
        // Every other field still round-trips exactly.
        expect(
          restored.workflow.applicants.length,
          game.workflow.applicants.length,
        );
        expect(restored.state.toJson(), game.state.toJson());
      },
    );

    test('Finance/Month regression: interview-session commands never touch '
        'PublicDemoState', () {
      final game = _mayWithSeededInterviewedApplicant(runSeed: 61);
      final id = _seededApplicantId(game);
      final beforeState = game.state;

      final started = game.startInterviewSession(id);
      expect(identical(started.state, beforeState), isTrue);
      final asked = started.askInterviewQuestion(
        id,
        InterviewQuestionCategory.workStyle,
      );
      expect(identical(asked.state, beforeState), isTrue);

      // Month progression is unaffected: closing May still works
      // normally with an in-progress (undecided) interview session on
      // the roster.
      final closed = asked.closeMay(week: 9, monthlyExpenses: 800000);
      expect(closed.state.month, 6);
    });
  });

  group(
    'AI Replay Audit #3 P1 fix: finalEvaluationScore folds real Q&A '
    'answer credibility into the pre-interview interviewScore baseline',
    () {
      // qaEvaluationApplies: true -- these fixtures test the current-code
      // decision path (AI Replay Audit #3 P1-1 backward-compat fix); a
      // grandfathered (false) applicant would bypass all of this and
      // always return the raw interviewScore instead, which is covered by
      // its own dedicated group below.
      const baseline = PublicDemoApplicant(
        id: 'probe-applicant',
        name: 'Probe',
        resumeSummary: 'n/a',
        interviewScore: 50,
        acceptanceScore: 50,
        salesSkillFit: 50,
        qaEvaluationApplies: true,
      );

      ApplicantAnswer answerWithCredibility(
        InterviewQuestionCategory category,
        int credibility,
      ) => ApplicantAnswer(
        category: category,
        question: 'q',
        answer: 'a',
        specificity: credibility,
        consistency: credibility,
        confidence: credibility,
        credibility: credibility,
      );

      RecruitmentInterviewSession completedSession(List<int> credibilities) =>
          RecruitmentInterviewSession(
            id: 'probe-session',
            applicantId: baseline.id,
            startedWeek: 1,
            applicantValue: ApplicantValue.careerFocused,
            selectedQuestions: const [
              InterviewQuestionCategory.technical,
              InterviewQuestionCategory.career,
              InterviewQuestionCategory.reasonForChange,
            ],
            applicantAnswers: [
              answerWithCredibility(
                InterviewQuestionCategory.technical,
                credibilities[0],
              ),
              answerWithCredibility(
                InterviewQuestionCategory.career,
                credibilities[1],
              ),
              answerWithCredibility(
                InterviewQuestionCategory.reasonForChange,
                credibilities[2],
              ),
            ],
            companyImpression: 50,
            completed: true,
          );

      test('null before the session is completed -- never displays or '
          'gates on an evaluation before the Q&A genuinely concludes', () {
        expect(
          PublicDemoRecruitmentInterview.finalEvaluationScore(
            applicant: baseline,
            session: null,
          ),
          isNull,
        );
        final inProgress = completedSession([80, 80, 80]).copyWith(
          completed: false,
        );
        expect(
          PublicDemoRecruitmentInterview.finalEvaluationScore(
            applicant: baseline,
            session: inProgress,
          ),
          isNull,
        );
      });

      test(
        'consistently credible (good) answers push the score above the '
        'interviewScore baseline; consistently poor answers push it below',
        () {
          final good = PublicDemoRecruitmentInterview.finalEvaluationScore(
            applicant: baseline,
            session: completedSession([95, 90, 92]),
          )!;
          final poor = PublicDemoRecruitmentInterview.finalEvaluationScore(
            applicant: baseline,
            session: completedSession([8, 12, 10]),
          )!;
          expect(
            good,
            greaterThan(baseline.interviewScore),
            reason: 'good answers must be advantageous, not neutral',
          );
          expect(
            poor,
            lessThan(baseline.interviewScore),
            reason: 'poor answers must be disadvantageous, not neutral',
          );
          expect(
            good,
            greaterThan(poor),
            reason:
                'the same candidate must score higher for good answers '
                'than for poor ones -- this is what makes the Q&A '
                'genuinely decide the outcome instead of a coin flip',
          );
        },
      );

      test(
        'deterministic: the exact same answers always produce the exact '
        'same final evaluation -- never a fresh random roll',
        () {
          final first = PublicDemoRecruitmentInterview.finalEvaluationScore(
            applicant: baseline,
            session: completedSession([70, 65, 72]),
          );
          final second = PublicDemoRecruitmentInterview.finalEvaluationScore(
            applicant: baseline,
            session: completedSession([70, 65, 72]),
          );
          expect(first, second);
        },
      );

      test('clamps to the valid 0-100 evaluation range at both ends', () {
        const strongBaseline = PublicDemoApplicant(
          id: 'probe-applicant',
          name: 'Probe',
          resumeSummary: 'n/a',
          interviewScore: 95,
          acceptanceScore: 50,
          salesSkillFit: 50,
          qaEvaluationApplies: true,
        );
        expect(
          PublicDemoRecruitmentInterview.finalEvaluationScore(
            applicant: strongBaseline,
            session: completedSession([95, 95, 95]),
          ),
          lessThanOrEqualTo(100),
        );
        const weakBaseline = PublicDemoApplicant(
          id: 'probe-applicant',
          name: 'Probe',
          resumeSummary: 'n/a',
          interviewScore: 5,
          acceptanceScore: 50,
          salesSkillFit: 50,
          qaEvaluationApplies: true,
        );
        expect(
          PublicDemoRecruitmentInterview.finalEvaluationScore(
            applicant: weakBaseline,
            session: completedSession([5, 5, 5]),
          ),
          greaterThanOrEqualTo(0),
        );
      });

      test('does not mutate PublicDemoApplicant.interviewScore itself -- no '
          'second authority, purely an additive read', () {
        PublicDemoRecruitmentInterview.finalEvaluationScore(
          applicant: baseline,
          session: completedSession([95, 90, 92]),
        );
        expect(baseline.interviewScore, 50);
      });
    },
  );
}
