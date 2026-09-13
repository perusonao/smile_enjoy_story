// PR #264 Codex Broad Review P1-1 (Preserve eligibility for in-flight saved
// interviews): applying `PublicDemoRecruitmentInterview.finalEvaluationScore`
// retroactively to a session that was already `completed`/`hired` before
// this evaluation existed can flip a previously-eligible candidate (e.g.
// `interviewScore` 61, already >= the old 60 gate) into an ineligible one
// (the same candidate's real Q&A answers land the new evaluation at 54),
// permanently stranding an in-flight save: HOME stops recommending the
// offer, Sales disables the button, and the completed session cannot be
// retried.
//
// Fresh Audit conclusion (see this PR's own Result Report for the full
// trace): a completed, decided-`hired` session's persisted shape
// (`RecruitmentInterviewSession.applicantAnswers`/`completed`/`outcome`) is
// byte-identical whether it was decided by pre-fix or post-fix code -- the
// interactive Q&A mechanics themselves did not change, only which value the
// offer-eligibility gate reads. So existing data alone cannot distinguish
// "decided under the old rule" from "decided under the new rule"; pure,
// data-only grandfathering is not possible. This is the minimal, explicit
// migration/versioning fix instead:
// `PublicDemoApplicant.qaEvaluationApplies` (default `false`, including for
// any save serialized before this field existed) is set `true` only by
// `PublicDemoAggregate.concludeInterviewSession` the moment a `hired`
// decision is actually made by this build. `finalEvaluationScore` grandfathers
// `false` to the original `interviewScore` promise and always uses the real
// Q&A-derived evaluation for `true` -- one authority, versioned by when the
// decision was made, never two competing ones.
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/models/recruitment_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';

const _expense = 800000;

/// Codex's own cited example: `runSeed` 1's real free-medium May candidate,
/// `interviewScore` 61 (already >= the old 60 gate), driven through the
/// real interactive Q&A (technical/career/teamwork + reverse choice 0,
/// exactly like `public_demo_issue245_recruitment_lifecycle_visibility_
/// test.dart`'s own former seed-1 fixture) to a genuine "採用候補として進める"
/// decision made by *this* build -- so `qaEvaluationApplies` is genuinely
/// `true` here, and the real Q&A-derived evaluation is confirmed (not
/// assumed) to land below 60 for this exact candidate.
PublicDemoAggregate _decidedHiredSeed1FreeMedium() {
  var aggregate = PublicDemoAggregate.initial(
    runSeed: 1,
  ).closeApril(monthlyExpenses: _expense);
  final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.free);
  expect(recruited.isSuccess, isTrue, reason: 'fixture sanity');
  aggregate = recruited.aggregate!;
  final id = aggregate.workflow.applicants.first.id;
  expect(
    aggregate.workflow.applicants.first.interviewScore,
    61,
    reason: 'fixture sanity: matches the reviewer\'s own cited example',
  );
  aggregate = aggregate.completeInterview(id).aggregate;
  aggregate = aggregate
      .startInterviewSession(id)
      .askInterviewQuestion(id, InterviewQuestionCategory.technical)
      .askInterviewQuestion(id, InterviewQuestionCategory.career)
      .askInterviewQuestion(id, InterviewQuestionCategory.teamwork)
      .answerInterviewReverseQuestion(id, 0);
  return aggregate.concludeInterviewSession(id, InterviewOutcome.hired);
}

String _idOf(PublicDemoAggregate aggregate) =>
    aggregate.workflow.applicants.first.id;

/// Strips [PublicDemoApplicant.qaEvaluationApplies] out of a real,
/// current-build aggregate's JSON to reproduce exactly what a save written
/// before that field existed looks like -- the same "remove the key
/// entirely" technique `public_demo_recruitment_interview_test.dart`'s own
/// "a save from before this phase (no interviewSessions key)" test already
/// uses for the interviewSessions list.
Map<String, dynamic> _asPreUpdateSaveJson(PublicDemoAggregate aggregate) {
  final json = aggregate.toJson();
  final workflow = Map<String, dynamic>.from(json['workflow'] as Map);
  final applicants = (workflow['applicants'] as List)
      .map(
        (applicant) =>
            Map<String, dynamic>.from(applicant as Map)
              ..remove('qaEvaluationApplies'),
      )
      .toList();
  workflow['applicants'] = applicants;
  return {...json, 'workflow': workflow};
}

void main() {
  group(
    'PR #264 Codex Broad Review P1-1: preserve eligibility for in-flight '
    'saved interviews',
    () {
      test(
        '1. pre-update save equivalent (interviewScore 61, completed, '
        'before offer) keeps salary-offer eligibility',
        () {
          final live = _decidedHiredSeed1FreeMedium();
          final id = _idOf(live);
          final liveApplicant = live.workflow.applicants.firstWhere(
            (a) => a.id == id,
          );
          final liveSession = live.workflow.interviewSessions.firstWhere(
            (s) => s.applicantId == id,
          );
          // Fixture sanity: under this build with qaEvaluationApplies
          // genuinely true, this exact candidate's real Q&A answers WOULD
          // now fail the new gate on their own -- confirming this is a
          // real "already-eligible, would-become-ineligible" case, not a
          // hypothetical one.
          expect(liveApplicant.qaEvaluationApplies, isTrue);
          expect(
            PublicDemoRecruitmentInterview.finalEvaluationScore(
              applicant: liveApplicant,
              session: liveSession,
            ),
            lessThan(60),
            reason: 'fixture sanity: matches the reviewer\'s own cited 54',
          );

          final legacy = PublicDemoAggregate.fromJson(
            _asPreUpdateSaveJson(live),
          );
          final legacyApplicant = legacy.workflow.applicants.firstWhere(
            (a) => a.id == id,
          );
          expect(
            legacyApplicant.qaEvaluationApplies,
            isFalse,
            reason: 'the absent key must default to grandfathered',
          );
          final legacySession = legacy.workflow.interviewSessions.firstWhere(
            (s) => s.applicantId == id,
          );
          final grandfathered =
              PublicDemoRecruitmentInterview.finalEvaluationScore(
                applicant: legacyApplicant,
                session: legacySession,
              );
          expect(
            grandfathered,
            61,
            reason: 'grandfathered to the original interviewScore promise',
          );
          expect(
            grandfathered,
            greaterThanOrEqualTo(60),
            reason: 'still eligible for a salary offer',
          );
        },
      );

      test('2. a further save/reload round trip preserves the '
          'grandfathered eligibility', () {
        final legacy = PublicDemoAggregate.fromJson(
          _asPreUpdateSaveJson(_decidedHiredSeed1FreeMedium()),
        );
        final id = _idOf(legacy);
        final reloadedAgain = PublicDemoAggregate.fromJson(legacy.toJson());
        final applicant = reloadedAgain.workflow.applicants.firstWhere(
          (a) => a.id == id,
        );
        expect(applicant.qaEvaluationApplies, isFalse);
        final session = reloadedAgain.workflow.interviewSessions.firstWhere(
          (s) => s.applicantId == id,
        );
        expect(
          PublicDemoRecruitmentInterview.finalEvaluationScore(
            applicant: applicant,
            session: session,
          ),
          61,
        );
      });

      test(
        '5. a genuinely new (post-fix) interview still flips pass/fail on '
        'the real Q&A answers -- the same candidate under this build is '
        'never grandfathered',
        () {
          final live = _decidedHiredSeed1FreeMedium();
          final id = _idOf(live);
          final applicant = live.workflow.applicants.firstWhere(
            (a) => a.id == id,
          );
          final session = live.workflow.interviewSessions.firstWhere(
            (s) => s.applicantId == id,
          );
          expect(applicant.qaEvaluationApplies, isTrue);
          expect(
            PublicDemoRecruitmentInterview.finalEvaluationScore(
              applicant: applicant,
              session: session,
            ),
            lessThan(60),
            reason:
                'a fresh, current-build decision must use the real Q&A '
                'evaluation, not the raw interviewScore -- this candidate '
                'genuinely fails it',
          );
        },
      );

      test(
        '6. grandfathering never accidentally passes a newly-decided '
        'candidate: only a legacy (pre-update) applicant is grandfathered, '
        'not a fresh one with the exact same underlying numbers',
        () {
          final freshlyDecided = _decidedHiredSeed1FreeMedium();
          final id = _idOf(freshlyDecided);
          final applicant = freshlyDecided.workflow.applicants.firstWhere(
            (a) => a.id == id,
          );
          final session = freshlyDecided.workflow.interviewSessions
              .firstWhere((s) => s.applicantId == id);
          // Same candidate, same session data as test 1 above -- but never
          // round-tripped through a pre-update save, so qaEvaluationApplies
          // is genuinely true and the real (failing) evaluation applies.
          expect(applicant.qaEvaluationApplies, isTrue);
          expect(
            PublicDemoRecruitmentInterview.finalEvaluationScore(
              applicant: applicant,
              session: session,
            ),
            lessThan(60),
            reason:
                'must NOT be grandfathered to the raw interviewScore (61) '
                'just because that would have passed -- grandfathering is '
                'reserved for genuinely pre-update saves',
          );
        },
      );

      test(
        '7a. duplicate/retry: re-invoking concludeInterviewSession on an '
        'already-decided legacy session does not change the grandfather '
        'flag or eligibility',
        () {
          final legacy = PublicDemoAggregate.fromJson(
            _asPreUpdateSaveJson(_decidedHiredSeed1FreeMedium()),
          );
          final id = _idOf(legacy);
          final retried = legacy.concludeInterviewSession(
            id,
            InterviewOutcome.hired,
          );
          final applicant = retried.workflow.applicants.firstWhere(
            (a) => a.id == id,
          );
          expect(
            applicant.qaEvaluationApplies,
            isFalse,
            reason:
                'a no-op retry on an already-completed session must not '
                'retroactively flip the flag',
          );
          final session = retried.workflow.interviewSessions.firstWhere(
            (s) => s.applicantId == id,
          );
          expect(
            PublicDemoRecruitmentInterview.finalEvaluationScore(
              applicant: applicant,
              session: session,
            ),
            61,
          );
        },
      );

      test(
        '7b. month boundary: a month close never resets the grandfather '
        'flag for a stalled, interviewed-but-not-yet-offered legacy '
        'applicant',
        () {
          // Recruits in June (after closeApril/closeMay with zero May
          // applicants), mirroring `public_demo_issue245_recruitment_
          // lifecycle_visibility_test.dart`'s own
          // `_juneWithOneStalledBelowThresholdApplicantAfterClose` fixture
          // -- closeMay's own May-cohort pruning
          // (`joinAndKeepOnly`) only applies to applicants recruited that
          // same May, and would otherwise remove a not-yet-`accepted`
          // interviewed applicant before this test ever reaches closeJune.
          var aggregate = PublicDemoAggregate.initial(runSeed: 1)
              .closeApril(monthlyExpenses: _expense)
              .closeMay(week: 9, monthlyExpenses: _expense);
          expect(aggregate.state.month, 6, reason: 'fixture sanity');
          final recruited = aggregate.recruit(PublicDemoRecruitmentMedium.free);
          expect(recruited.isSuccess, isTrue, reason: 'fixture sanity');
          aggregate = recruited.aggregate!;
          final id = aggregate.workflow.applicants.first.id;
          aggregate = aggregate.completeInterview(id).aggregate;
          aggregate = aggregate
              .startInterviewSession(id)
              .askInterviewQuestion(id, InterviewQuestionCategory.technical)
              .askInterviewQuestion(id, InterviewQuestionCategory.career)
              .askInterviewQuestion(id, InterviewQuestionCategory.teamwork)
              .answerInterviewReverseQuestion(id, 0);
          aggregate = aggregate.concludeInterviewSession(
            id,
            InterviewOutcome.hired,
          );

          final legacy = PublicDemoAggregate.fromJson(
            _asPreUpdateSaveJson(aggregate),
          );
          final legacyApplicant = legacy.workflow.applicants.firstWhere(
            (a) => a.id == id,
          );
          expect(legacyApplicant.qaEvaluationApplies, isFalse);
          final originalInterviewScore = legacyApplicant.interviewScore;

          final closed = legacy.closeJune(
            assignedInJuly: 0,
            monthlyExpenses: _expense,
          );
          expect(closed.state.month, 7, reason: 'fixture sanity');
          final applicant = closed.workflow.applicants.firstWhere(
            (a) => a.id == id,
          );
          expect(
            applicant.qaEvaluationApplies,
            isFalse,
            reason: 'a month close must never touch this migration flag',
          );
          final session = closed.workflow.interviewSessions.firstWhere(
            (s) => s.applicantId == id,
          );
          expect(
            PublicDemoRecruitmentInterview.finalEvaluationScore(
              applicant: applicant,
              session: session,
            ),
            originalInterviewScore,
            reason:
                'grandfathered eligibility survives the month boundary '
                'unchanged',
          );
        },
      );
    },
  );
}
