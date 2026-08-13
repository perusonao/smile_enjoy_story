import 'dart:io';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

void main(){
  final applicants=ApplicantGenerator(seed:303).generate(1000);
  final strategies=<String,List<InterviewQuestionCategory>>{
    'A technical':[InterviewQuestionCategory.technical,InterviewQuestionCategory.career,InterviewQuestionCategory.futureCareer],
    'B people/retention':[InterviewQuestionCategory.reasonForChange,InterviewQuestionCategory.teamwork,InterviewQuestionCategory.workStyle],
    'C mixed':[InterviewQuestionCategory.technical,InterviewQuestionCategory.reasonForChange,InterviewQuestionCategory.teamwork],
  };
  for(final e in strategies.entries){var k=0,imp=0,rate=0,hires=0,skill=0.0,ret=0.0,dish=0.0;
    for(final a in applicants){var s=RecruitmentInterviewEngine.start(seed:303,week:1,applicant:a,companyCredit:20,officeType:OfficeType.smallOffice,companySize:2);for(final q in e.value){s=RecruitmentInterviewEngine.ask(session:s,applicant:a,seed:303,category:q);}s=RecruitmentInterviewEngine.answerReverse(s,0);k+=s.candidateKnowledge;imp+=s.companyImpression;rate+=RecruitmentEngine.acceptanceRate(20,companyImpression:s.companyImpression);
      final evidence=s.applicantAnswers.fold<int>(0,(n,x)=>n+x.credibility);if(evidence>=150){hires++;skill+=a.skillFor(a.mainLanguage).actualSkill;ret+=a.hidden.retention;dish+=a.personality.dishonesty;}}
    stdout.writeln('${e.key}: knowledge ${(k/1000).toStringAsFixed(1)}, impression ${(imp/1000).toStringAsFixed(1)}, acceptance ${(rate/1000).toStringAsFixed(1)}%, hires $hires, skill ${(skill/hires).toStringAsFixed(1)}, retention ${(ret/hires).toStringAsFixed(2)}, dishonesty ${(dish/hires).toStringAsFixed(2)}');
  }
}
