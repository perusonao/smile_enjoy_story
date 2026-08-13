import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'test_helpers.dart';

void main() {
  group('Conversational recruitment interview', () {
    test('three unique questions only and knowledge is clamped', () {
      final a=buildApplicant();
      var s=RecruitmentInterviewEngine.start(seed:7,week:1,applicant:a,companyCredit:20,officeType:OfficeType.smallOffice,companySize:2);
      s=RecruitmentInterviewEngine.ask(session:s,applicant:a,seed:7,category:InterviewQuestionCategory.technical);
      final duplicate=RecruitmentInterviewEngine.ask(session:s,applicant:a,seed:7,category:InterviewQuestionCategory.technical);
      expect(duplicate.selectedQuestions.length,1);
      for(final q in [InterviewQuestionCategory.career,InterviewQuestionCategory.teamwork,InterviewQuestionCategory.workStyle]) { s=RecruitmentInterviewEngine.ask(session:s,applicant:a,seed:7,category:q); }
      expect(s.selectedQuestions.length,3); expect(s.candidateKnowledge,inInclusiveRange(0,100));
    });
    test('same seed and question produce the same response', () {
      final a=buildApplicant();
      final x=RecruitmentInterviewEngine.generateAnswer(applicant:a,seed:99,category:InterviewQuestionCategory.technical);
      final y=RecruitmentInterviewEngine.generateAnswer(applicant:a,seed:99,category:InterviewQuestionCategory.technical);
      expect(x.toJson(),y.toJson());
    });
    test('parameters change answer tendency', () {
      final strong=buildApplicant(id:'strong',mainLanguageActualSkill:95,personality:const PersonalityTraits(looks:3,cleanliness:3,communication:4,alcoholTolerance:3,seriousness:5,dishonesty:1));
      final weak=buildApplicant(id:'weak',mainLanguageActualSkill:15,personality:const PersonalityTraits(looks:3,cleanliness:3,communication:2,alcoholTolerance:3,seriousness:2,dishonesty:5));
      final x=RecruitmentInterviewEngine.generateAnswer(applicant:strong,seed:11,category:InterviewQuestionCategory.technical);
      final y=RecruitmentInterviewEngine.generateAnswer(applicant:weak,seed:11,category:InterviewQuestionCategory.technical);
      expect(x.credibility,greaterThan(y.credibility));
      expect(y.confidence,greaterThan(y.specificity));
    });
    test('dishonesty raises vague or boasting tendency but is not always a lie', () {
      var suspicious=0; var credible=0;
      for(var i=0;i<100;i++) { final a=buildApplicant(id:'d$i',personality:const PersonalityTraits(looks:3,cleanliness:3,communication:4,alcoholTolerance:3,seriousness:3,dishonesty:5)); final r=RecruitmentInterviewEngine.generateAnswer(applicant:a,seed:i,category:InterviewQuestionCategory.technical); if(r.confidence-r.specificity>20)suspicious++; if(r.credibility>=50)credible++; }
      expect(suspicious,greaterThan(20)); expect(credible,greaterThan(0));
    });
    test('observations do not expose hidden field names or values', () {
      final a=buildApplicant(); final r=RecruitmentInterviewEngine.generateAnswer(applicant:a,seed:2,category:InterviewQuestionCategory.reasonForChange); final o=RecruitmentInterviewEngine.observe(r,a);
      expect(o.text,allOf(isNot(contains('dishonesty')),isNot(contains('retention =')),isNot(contains('actualSkill'))));
    });
    test('reverse question is reproducible and values bias categories', () {
      final a=RecruitmentInterviewEngine.selectReverseQuestion(applicantValue:ApplicantValue.salaryFocused,applicantId:'a',seed:4);
      final b=RecruitmentInterviewEngine.selectReverseQuestion(applicantValue:ApplicantValue.salaryFocused,applicantId:'a',seed:4); expect(a,b);
      var preferred=0; for(var i=0;i<300;i++){final q=RecruitmentInterviewEngine.selectReverseQuestion(applicantValue:ApplicantValue.salaryFocused,applicantId:'a$i',seed:i);if(q==ReverseQuestionCategory.salary||q==ReverseQuestionCategory.waiting)preferred++;} expect(preferred,greaterThan(100));
    });
    test('company answer changes and clamps impression', () {
      var s=RecruitmentInterviewSession(id:'i',applicantId:'a',startedWeek:1,applicantValue:ApplicantValue.salaryFocused,selectedQuestions:InterviewQuestionCategory.values.take(3).toList(),reverseQuestion:ReverseQuestionCategory.salary,companyImpression:98);
      s=RecruitmentInterviewEngine.answerReverse(s,0); expect(s.companyImpression,100); expect(s.applicantReaction,contains('安心'));
    });
    test('acceptance includes impression and clamps 5 to 95', () {
      expect(RecruitmentEngine.acceptanceRate(-999,companyImpression:0),5); expect(RecruitmentEngine.acceptanceRate(999,companyImpression:100),95);
      expect(RecruitmentEngine.acceptanceRate(20,companyImpression:80),greaterThan(RecruitmentEngine.acceptanceRate(20,companyImpression:20)));
    });
    test('session and applicant value round-trip', () {
      final a=buildApplicant(); var s=RecruitmentInterviewEngine.start(seed:4,week:2,applicant:a,companyCredit:20,officeType:OfficeType.smallOffice,companySize:2);
      s=RecruitmentInterviewEngine.ask(session:s,applicant:a,seed:4,category:InterviewQuestionCategory.technical);
      expect(RecruitmentInterviewSession.fromJson(s.toJson()).toJson(),s.toJson());
    });
  });
}
