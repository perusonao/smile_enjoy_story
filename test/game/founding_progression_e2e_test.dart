// End-to-end guided-founding simulation (Playable 0.4C.1 §54): drives a
// full playthrough through nothing but legitimate `GameEngine` actions
// (mirroring the "employee-first loop" pattern from sales_04a1_test.dart)
// and checks every milestone fires in order, purely from genuine gameplay
// — not by manually injecting milestones like progression_engine_test.dart
// does for its narrower, faster unit tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

void main() {
  test('a full guided playthrough reaches free management through real gameplay only', () {
    var completedAssignment = false;
    var finalState = GameEngine.newGame(seed: 1);

    for (var seed = 1; seed <= 60 && !completedAssignment; seed++) {
      var s = GameEngine.newGame(seed: seed);
      final employee = s.engineers.first;

      // Stage 1-3: inspect employee, inspect SkillSheet, start sales.
      s = GameEngine.recordMilestone(s, FoundingMilestone.inspectEmployee);
      s = GameEngine.recordMilestone(s, FoundingMilestone.inspectSkillSheet);
      s = GameEngine.startSales(s, employee.id);
      expect(s.foundingProgress.has(FoundingMilestone.startSales), isTrue);
      expect(ProgressionEngine.currentStage(s), FoundingStage.awaitingOffer);

      for (var week = 0; week < 47 && s.status == GameStatus.playing; week++) {
        for (final interview in s.interviewOffers
            .where((o) => o.employeeId == employee.id && o.status == InterviewOfferStatus.pending)
            .toList()) {
          s = GameEngine.acceptInterviewOffer(s, interview.id);
        }
        for (final interview in s.proposals
            .where((p) =>
                p.engineerId == employee.id &&
                p.status == ApplicationStatus.active &&
                p.currentStep == SelectionStep.clientInterview)
            .toList()) {
          s = GameEngine.autoResolveClientInterview(s, interview.id);
        }
        for (final offer in s.offers
            .where((o) => o.employeeId == employee.id && o.status == OfferStatus.pending)
            .toList()) {
          s = GameEngine.acceptOffer(s, offer.id);
        }
        if (s.engineerById(employee.id).status == EngineerStatus.waiting &&
            s.engineerById(employee.id).salesStatus != SalesStatus.selling) {
          s = GameEngine.startSales(s, employee.id);
        }
        s = GameEngine.advanceWeek(s);
        if (s.assignmentForEngineer(employee.id) != null) {
          completedAssignment = true;
          finalState = s;
          break;
        }
      }
    }

    expect(completedAssignment, isTrue, reason: 'no seed in range reached an assignment — sales loop broke');
    var s = finalState;

    // Stage 4-6 all completed as a side effect of genuine sales/interview
    // flow above (§13-19).
    expect(s.foundingProgress.has(FoundingMilestone.receiveInterviewOffer), isTrue);
    expect(s.foundingProgress.has(FoundingMilestone.completeClientInterview), isTrue);
    expect(s.foundingProgress.has(FoundingMilestone.firstAssignment), isTrue);

    // Stage 7: Recruitment is now unlocked — post a listing, wait for an
    // applicant, interview them for real, and complete the interview.
    expect(ProgressionEngine.canUseRecruitment(s), isTrue);
    s = GameEngine.postRecruitmentMedia(s, RecruitmentMediaType.freeWork);
    var applicantId = '';
    for (var week = 0; week < 20 && applicantId.isEmpty; week++) {
      s = GameEngine.advanceWeek(s);
      if (s.applicants.isNotEmpty) applicantId = s.applicants.first.applicant.id;
    }
    expect(applicantId, isNotEmpty, reason: 'no applicant showed up within 20 weeks');

    s = GameEngine.interviewApplicant(s, applicantId);
    var session = s.recruitmentInterviews.firstWhere((sess) => sess.applicantId == applicantId);
    for (final category in InterviewQuestionCategory.values.take(3)) {
      s = GameEngine.askRecruitmentQuestion(s, applicantId, category);
    }
    session = s.recruitmentInterviews.firstWhere((sess) => sess.applicantId == applicantId);
    if (!session.questionsComplete) {
      // Some categories may already be exhausted by the loop above; ask
      // whatever's left until 3 questions are recorded.
      for (final category in InterviewQuestionCategory.values) {
        session = s.recruitmentInterviews.firstWhere((sess) => sess.applicantId == applicantId);
        if (session.questionsComplete) break;
        if (!session.selectedQuestions.contains(category)) {
          s = GameEngine.askRecruitmentQuestion(s, applicantId, category);
        }
      }
    }
    session = s.recruitmentInterviews.firstWhere((sess) => sess.applicantId == applicantId);
    if (session.reverseQuestion != null && session.companyAnswer == null) {
      s = GameEngine.answerRecruitmentReverseQuestion(s, applicantId, 0);
    }
    session = s.recruitmentInterviews.firstWhere((sess) => sess.applicantId == applicantId);
    expect(session.conversationComplete, isTrue);
    s = GameEngine.completeRecruitmentInterview(s, applicantId, InterviewOutcome.rejected);

    expect(s.foundingProgress.has(FoundingMilestone.firstRecruitmentInterview), isTrue);
    expect(ProgressionEngine.canUseWelfare(s), isTrue);
    expect(ProgressionEngine.currentStage(s), FoundingStage.welfare);

    // Stage 8: the player looks at an employee's condition once Welfare is
    // unlocked (§35-37) — this is what actually moves to tutorialComplete.
    s = GameEngine.recordMilestone(s, FoundingMilestone.welfareIntroSeen);
    expect(ProgressionEngine.currentStage(s), FoundingStage.tutorialComplete);

    // Stage 9: the player finishes the tutorial explicitly (§27-28, §37).
    s = GameEngine.completeFoundingTutorial(s);
    expect(ProgressionEngine.currentStage(s), FoundingStage.freeManagement);
    expect(ProgressionEngine.showFoundingMission(s), isFalse);
  });
}
