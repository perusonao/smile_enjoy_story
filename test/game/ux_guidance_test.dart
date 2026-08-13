import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/theme.dart';
import 'test_helpers.dart';

void main() {
  test('compact yen formatter covers dashboard boundaries', () {
    expect(formatCompactYen(0), '0円');
    expect(formatCompactYen(850000), '85万円');
    expect(formatCompactYen(3500000), '350万円');
    expect(formatCompactYen(12500000), '1250万円');
    expect(formatCompactYen(100000000), '1億円');
    expect(formatCompactYen(-3500000), '-350万円');
  });

  test('recommendations cap at three and critical sorts first', () {
    var state = GameEngine.newGame(seed: 1);
    final engineer = state.engineers.first;
    final project = state.openProjects.first.project;
    final application = ProjectProposal(id:'p',engineerId:engineer.id,project:project,proposedWeek:1,stage:ProposalStage.proposed,status:ApplicationStatus.offered);
    final offer = Offer(id:'o',applicationId:'p',projectId:project.id,employeeId:engineer.id,monthlyRate:project.monthlyRate,startWeek:2,responseDeadlineWeek:1);
    state = state.copyWith(proposals:[application], offers:[offer]);
    final actions = RecommendationEngine.recommendedActions(state);
    expect(actions.length, lessThanOrEqualTo(3));
    expect(actions.first.priority, TaskPriority.critical);
    expect(actions.first.targetType, TaskTargetType.employeeDetail);
  });

  test('candidate recommendation cannot leak hidden or actual values', () {
    final state = GameEngine.newGame(seed: 2);
    final visible = buildApplicant(id:'same');
    final altered = buildApplicant(id:'same', mainLanguageActualSkill:1,
      personality:const PersonalityTraits(looks:1,cleanliness:1,communication:1,alcoholTolerance:1,seriousness:1,dishonesty:5),
      hidden:const HiddenParameters(growthPotential:1,stressTolerance:1,retention:1,projectInterviewSkill:1,turnoverIntent:100));
    final a=RecommendationEngine.candidateAssessment(visible,state);
    final b=RecommendationEngine.candidateAssessment(altered,state);
    expect(a.level,b.level); expect(a.good,b.good); expect(a.cautions,b.cautions);
  });

  test('post interview assessment only uses recorded observations', () {
    const observation=InterviewObservation(category:InterviewQuestionCategory.technical,text:'具体例がある',confidence:ObservationConfidence.high);
    const session=RecruitmentInterviewSession(id:'i',applicantId:'a',startedWeek:1,applicantValue:ApplicantValue.careerFocused,observations:[observation],companyImpression:50);
    final result=RecommendationEngine.postInterviewAssessment(session);
    expect(result.good,['具体例がある']); expect(result.good.join(),isNot(contains('retention')));
  });
}
