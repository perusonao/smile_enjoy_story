import '../../domain/domain.dart';
import '../models/client_interview.dart';

const clientInterviewFollowUpLabels=<ClientInterviewFollowUp,String>{
  ClientInterviewFollowUp.emphasizeTechnical:'技術面の担当範囲を補足する',
  ClientInterviewFollowUp.emphasizeIndustry:'業界知識を補足する',
  ClientInterviewFollowUp.emphasizeCommunication:'顧客との調整経験を補足する',
  ClientInterviewFollowUp.emphasizeLeadership:'リーダー経験を補足する',
  ClientInterviewFollowUp.adjustExpectation:'主担当ではないと期待値を調整する',
  ClientInterviewFollowUp.letEmployeeHandle:'本人の回答に任せる',
};

String languageName(ProgrammingLanguage language)=>language.name[0].toUpperCase()+language.name.substring(1);

String questionText(ClientInterviewQuestionCategory category,Project project,SkillSheet sheet){
  final language=project.requiredLanguages.isEmpty?null:project.requiredLanguages.first;
  return switch(category){
    ClientInterviewQuestionCategory.technicalExperience=>language==null?'今回必要な技術領域での担当内容を教えてください':'${languageName(language)}で担当した開発について、具体的に教えてください。',
    ClientInterviewQuestionCategory.roleExperience=>sheet.displayedRoles.isNotEmpty?'${sheet.displayedRoles.first}として、どこまで担当されましたか？':'設計からテストまで、どこを担当されましたか？',
    ClientInterviewQuestionCategory.industryExperience=>'${_industry(project.industry)}業務の経験について教えてください。',
    ClientInterviewQuestionCategory.teamwork=>'チームではどのような役割を担っていましたか？',
    ClientInterviewQuestionCategory.troubleHandling=>'トラブルが起きたとき、どう対応しましたか？',
    ClientInterviewQuestionCategory.communication=>'顧客との仕様調整経験について教えてください。',
    ClientInterviewQuestionCategory.workStyle=>'この案件での働き方にどう適応しますか？',
    ClientInterviewQuestionCategory.leadership=>'何名規模のチームをリードし、何を管理しましたか？',
  };
}
String _industry(Industry i)=>switch(i){Industry.finance=>'金融',Industry.manufacturing=>'製造',Industry.logistics=>'物流',Industry.publicSector=>'公共',Industry.telecom=>'通信',Industry.ecommerce=>'EC',Industry.healthcare=>'医療',Industry.other=>'この案件の業界'};
