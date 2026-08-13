enum ClientInterviewQuestionCategory { technicalExperience, roleExperience, industryExperience, teamwork, troubleHandling, communication, workStyle, leadership }
enum ClientInterviewFollowUp { emphasizeTechnical, emphasizeIndustry, emphasizeCommunication, emphasizeLeadership, adjustExpectation, letEmployeeHandle }
enum ClientInterviewResult { passed, failed }

class ClientInterviewQuestion {
  final ClientInterviewQuestionCategory category;
  final String text;
  final String target;
  final int mismatch;
  const ClientInterviewQuestion({required this.category,required this.text,required this.target,this.mismatch=0});
  Map<String,dynamic> toJson()=>{'category':category.name,'text':text,'target':target,'mismatch':mismatch};
  factory ClientInterviewQuestion.fromJson(Map<String,dynamic> j)=>ClientInterviewQuestion(category:ClientInterviewQuestionCategory.values.byName(j['category'] as String),text:j['text'] as String,target:j['target'] as String,mismatch:j['mismatch'] as int? ?? 0);
}

class ClientInterviewAnswer {
  final String text;
  final int quality;
  final bool vague;
  const ClientInterviewAnswer({required this.text,required this.quality,required this.vague});
  Map<String,dynamic> toJson()=>{'text':text,'quality':quality,'vague':vague};
  factory ClientInterviewAnswer.fromJson(Map<String,dynamic> j)=>ClientInterviewAnswer(text:j['text'] as String,quality:j['quality'] as int,vague:j['vague'] as bool);
}

class ClientInterviewEvaluation {
  final int technical,experience,communication,credibility,clientFit;
  const ClientInterviewEvaluation({this.technical=0,this.experience=0,this.communication=0,this.credibility=0,this.clientFit=0});
  int get total=>technical+experience+communication+credibility+clientFit;
  ClientInterviewEvaluation add({int technical=0,int experience=0,int communication=0,int credibility=0,int clientFit=0})=>ClientInterviewEvaluation(technical:this.technical+technical,experience:this.experience+experience,communication:this.communication+communication,credibility:this.credibility+credibility,clientFit:this.clientFit+clientFit);
  Map<String,dynamic> toJson()=>{'technical':technical,'experience':experience,'communication':communication,'credibility':credibility,'clientFit':clientFit};
  factory ClientInterviewEvaluation.fromJson(Map<String,dynamic> j)=>ClientInterviewEvaluation(technical:j['technical'] as int,experience:j['experience'] as int,communication:j['communication'] as int,credibility:j['credibility'] as int,clientFit:j['clientFit'] as int);
}

class ClientInterviewSession {
  final String id,applicationId,employeeId,projectId,clientId;
  final int startedWeek,currentQuestionIndex;
  final List<ClientInterviewQuestion> questions;
  final List<ClientInterviewAnswer> employeeAnswers;
  final List<ClientInterviewFollowUp> playerFollowUps;
  final List<String> interviewerReactions;
  final ClientInterviewEvaluation accumulatedEvaluation;
  final bool completed,deepDiveOccurred,mismatchFailure;
  final String? deepDiveText;
  final ClientInterviewResult? result;
  const ClientInterviewSession({required this.id,required this.applicationId,required this.employeeId,required this.projectId,required this.clientId,required this.startedWeek,this.currentQuestionIndex=0,required this.questions,this.employeeAnswers=const[],this.playerFollowUps=const[],this.interviewerReactions=const[],this.accumulatedEvaluation=const ClientInterviewEvaluation(),this.completed=false,this.deepDiveOccurred=false,this.mismatchFailure=false,this.deepDiveText,this.result});
  ClientInterviewSession copyWith({int? currentQuestionIndex,List<ClientInterviewAnswer>? employeeAnswers,List<ClientInterviewFollowUp>? playerFollowUps,List<String>? interviewerReactions,ClientInterviewEvaluation? accumulatedEvaluation,bool? completed,bool? deepDiveOccurred,bool? mismatchFailure,String? deepDiveText,ClientInterviewResult? result})=>ClientInterviewSession(id:id,applicationId:applicationId,employeeId:employeeId,projectId:projectId,clientId:clientId,startedWeek:startedWeek,currentQuestionIndex:currentQuestionIndex??this.currentQuestionIndex,questions:questions,employeeAnswers:employeeAnswers??this.employeeAnswers,playerFollowUps:playerFollowUps??this.playerFollowUps,interviewerReactions:interviewerReactions??this.interviewerReactions,accumulatedEvaluation:accumulatedEvaluation??this.accumulatedEvaluation,completed:completed??this.completed,deepDiveOccurred:deepDiveOccurred??this.deepDiveOccurred,mismatchFailure:mismatchFailure??this.mismatchFailure,deepDiveText:deepDiveText??this.deepDiveText,result:result??this.result);
  Map<String,dynamic> toJson()=>{'id':id,'applicationId':applicationId,'employeeId':employeeId,'projectId':projectId,'clientId':clientId,'startedWeek':startedWeek,'currentQuestionIndex':currentQuestionIndex,'questions':questions.map((e)=>e.toJson()).toList(),'employeeAnswers':employeeAnswers.map((e)=>e.toJson()).toList(),'playerFollowUps':playerFollowUps.map((e)=>e.name).toList(),'interviewerReactions':interviewerReactions,'accumulatedEvaluation':accumulatedEvaluation.toJson(),'completed':completed,'deepDiveOccurred':deepDiveOccurred,'mismatchFailure':mismatchFailure,'deepDiveText':deepDiveText,'result':result?.name};
  factory ClientInterviewSession.fromJson(Map<String,dynamic> j)=>ClientInterviewSession(id:j['id'] as String,applicationId:j['applicationId'] as String,employeeId:j['employeeId'] as String,projectId:j['projectId'] as String,clientId:j['clientId'] as String,startedWeek:j['startedWeek'] as int,currentQuestionIndex:j['currentQuestionIndex'] as int,questions:(j['questions'] as List).map((e)=>ClientInterviewQuestion.fromJson(e as Map<String,dynamic>)).toList(),employeeAnswers:(j['employeeAnswers'] as List).map((e)=>ClientInterviewAnswer.fromJson(e as Map<String,dynamic>)).toList(),playerFollowUps:(j['playerFollowUps'] as List).map((e)=>ClientInterviewFollowUp.values.byName(e as String)).toList(),interviewerReactions:(j['interviewerReactions'] as List).cast<String>(),accumulatedEvaluation:ClientInterviewEvaluation.fromJson(j['accumulatedEvaluation'] as Map<String,dynamic>),completed:j['completed'] as bool,deepDiveOccurred:j['deepDiveOccurred'] as bool? ?? false,mismatchFailure:j['mismatchFailure'] as bool? ?? false,deepDiveText:j['deepDiveText'] as String?,result:j['result']==null?null:ClientInterviewResult.values.byName(j['result'] as String));
}
