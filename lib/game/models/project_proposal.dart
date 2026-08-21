import '../../domain/domain.dart';
import 'sales_models.dart';

enum ProposalStage { proposed, interviewPassed, interviewFailed; String get jsonValue => name; static ProposalStage fromJson(String value) => ProposalStage.values.firstWhere((e) => e.name == value, orElse: () => throw ArgumentError('Unknown ProposalStage: $value')); }
enum ApplicationStatus { active, rejected, offered, accepted, declined, cancelled }
enum SelectionStepResult { passed, failed, cancelled }

class SelectionStepHistory {
  final int week; final SelectionStep step; final SelectionStepResult result; final int? successRate;
  const SelectionStepHistory({required this.week, required this.step, required this.result, this.successRate});
  Map<String,dynamic> toJson()=>{'week':week,'step':step.name,'result':result.name,'successRate':successRate};
  factory SelectionStepHistory.fromJson(Map<String,dynamic> j)=>SelectionStepHistory(week:j['week'] as int,step:SelectionStep.fromJson(j['step'] as String),result:SelectionStepResult.values.firstWhere((e)=>e.name==j['result']),successRate:j['successRate'] as int?);
}

class ProjectProposal {
  final String id, engineerId; final Project project; final int proposedWeek; final ProposalStage stage; final int? interviewWeek, interviewSuccessRate, assignWeek; final int currentStepIndex; final ApplicationStatus status; final List<SelectionStepHistory> stepHistory; final int fitScore; final String? finalOfferId, rejectionReason; final bool fromInterviewOffer;
  const ProjectProposal({required this.id,required this.engineerId,required this.project,required this.proposedWeek,required this.stage,this.interviewWeek,this.interviewSuccessRate,this.assignWeek,this.currentStepIndex=0,this.status=ApplicationStatus.active,this.stepHistory=const [],this.fitScore=0,this.finalOfferId,this.rejectionReason,this.fromInterviewOffer=false});
  String get employeeId=>engineerId; String get projectId=>project.id; int get createdWeek=>proposedWeek; SelectionStep get currentStep=>project.selectionFlow.steps[currentStepIndex.clamp(0,project.selectionFlow.steps.length-1)]; bool get isActive=>status==ApplicationStatus.active;
  ProjectProposal copyWith({ProposalStage? stage,int? interviewWeek,int? interviewSuccessRate,int? assignWeek,int? currentStepIndex,ApplicationStatus? status,List<SelectionStepHistory>? stepHistory,int? fitScore,String? finalOfferId,String? rejectionReason})=>ProjectProposal(id:id,engineerId:engineerId,project:project,proposedWeek:proposedWeek,stage:stage??this.stage,interviewWeek:interviewWeek??this.interviewWeek,interviewSuccessRate:interviewSuccessRate??this.interviewSuccessRate,assignWeek:assignWeek??this.assignWeek,currentStepIndex:currentStepIndex??this.currentStepIndex,status:status??this.status,stepHistory:stepHistory??this.stepHistory,fitScore:fitScore??this.fitScore,finalOfferId:finalOfferId??this.finalOfferId,rejectionReason:rejectionReason??this.rejectionReason,fromInterviewOffer:fromInterviewOffer);
  Map<String,dynamic> toJson()=>{'id':id,'engineerId':engineerId,'project':project.toJson(),'proposedWeek':proposedWeek,'stage':stage.jsonValue,'interviewWeek':interviewWeek,'interviewSuccessRate':interviewSuccessRate,'assignWeek':assignWeek,'currentStepIndex':currentStepIndex,'status':status.name,'stepHistory':stepHistory.map((e)=>e.toJson()).toList(),'fitScore':fitScore,'finalOfferId':finalOfferId,'rejectionReason':rejectionReason,'fromInterviewOffer':fromInterviewOffer};
  factory ProjectProposal.fromJson(Map<String,dynamic> j)=>ProjectProposal(id:j['id'] as String,engineerId:j['engineerId'] as String,project:Project.fromJson(j['project'] as Map<String,dynamic>),proposedWeek:j['proposedWeek'] as int,stage:ProposalStage.fromJson(j['stage'] as String),interviewWeek:j['interviewWeek'] as int?,interviewSuccessRate:j['interviewSuccessRate'] as int?,assignWeek:j['assignWeek'] as int?,currentStepIndex:j['currentStepIndex'] as int? ?? 0,status:ApplicationStatus.values.firstWhere((e)=>e.name==(j['status'] as String? ?? 'active'),orElse:()=>ApplicationStatus.active),stepHistory:(j['stepHistory'] as List? ?? const []).map((e)=>SelectionStepHistory.fromJson(e as Map<String,dynamic>)).toList(),fitScore:j['fitScore'] as int? ?? 0,finalOfferId:j['finalOfferId'] as String?,rejectionReason:j['rejectionReason'] as String?,fromInterviewOffer:j['fromInterviewOffer'] as bool? ?? false);
}

typedef ProjectApplication = ProjectProposal;
enum OfferStatus { pending, accepted, declined, expired }
class Offer {
  final String id,applicationId,projectId,employeeId; final int monthlyRate,startWeek,responseDeadlineWeek; final OfferStatus status;
  const Offer({required this.id,required this.applicationId,required this.projectId,required this.employeeId,required this.monthlyRate,required this.startWeek,required this.responseDeadlineWeek,this.status=OfferStatus.pending});
  Offer copyWith({OfferStatus? status})=>Offer(id:id,applicationId:applicationId,projectId:projectId,employeeId:employeeId,monthlyRate:monthlyRate,startWeek:startWeek,responseDeadlineWeek:responseDeadlineWeek,status:status??this.status);
  Map<String,dynamic> toJson()=>{'id':id,'applicationId':applicationId,'projectId':projectId,'employeeId':employeeId,'monthlyRate':monthlyRate,'startWeek':startWeek,'responseDeadlineWeek':responseDeadlineWeek,'status':status.name};
  factory Offer.fromJson(Map<String,dynamic> j)=>Offer(id:j['id'] as String,applicationId:j['applicationId'] as String,projectId:j['projectId'] as String,employeeId:j['employeeId'] as String,monthlyRate:j['monthlyRate'] as int,startWeek:j['startWeek'] as int,responseDeadlineWeek:j['responseDeadlineWeek'] as int,status:OfferStatus.values.firstWhere((e)=>e.name==j['status']));
}

/// An engineer currently staffed on a project. Gameplay Phase 1 adds stable
/// storage for the placement-time fit and the evolving field evaluation;
/// both default to null so schema-v6 saves remain compatible.
class ActiveAssignment {
  final String engineerId; final Project project; final int remainingWeeks,assignedWeek,contractStartWeek,contractEndWeek,contractTermMonths; final ContractDecision contractDecision;
  final int? assignmentFitScore;
  final int? fieldEvaluation;
  ActiveAssignment({required this.engineerId,required this.project,required this.remainingWeeks,required this.assignedWeek,int? contractStartWeek,int? contractEndWeek,int? contractTermMonths,this.contractDecision=ContractDecision.undecided,this.assignmentFitScore,this.fieldEvaluation}) : contractStartWeek=contractStartWeek??assignedWeek,contractEndWeek=contractEndWeek??(assignedWeek+remainingWeeks-1),contractTermMonths=contractTermMonths??project.contractTermMonths;
  ActiveAssignment copyWith({int? remainingWeeks,int? contractEndWeek,ContractDecision? contractDecision,int? assignmentFitScore,int? fieldEvaluation})=>ActiveAssignment(engineerId:engineerId,project:project,remainingWeeks:remainingWeeks??this.remainingWeeks,assignedWeek:assignedWeek,contractStartWeek:contractStartWeek,contractEndWeek:contractEndWeek??this.contractEndWeek,contractTermMonths:contractTermMonths,contractDecision:contractDecision??this.contractDecision,assignmentFitScore:assignmentFitScore??this.assignmentFitScore,fieldEvaluation:fieldEvaluation??this.fieldEvaluation);
  Map<String,dynamic> toJson()=>{'engineerId':engineerId,'project':project.toJson(),'remainingWeeks':remainingWeeks,'assignedWeek':assignedWeek,'contractStartWeek':contractStartWeek,'contractEndWeek':contractEndWeek,'contractTermMonths':contractTermMonths,'contractDecision':contractDecision.name,'assignmentFitScore':assignmentFitScore,'fieldEvaluation':fieldEvaluation};
  factory ActiveAssignment.fromJson(Map<String,dynamic> j)=>ActiveAssignment(engineerId:j['engineerId'] as String,project:Project.fromJson(j['project'] as Map<String,dynamic>),remainingWeeks:j['remainingWeeks'] as int,assignedWeek:j['assignedWeek'] as int,contractStartWeek:j['contractStartWeek'] as int?,contractEndWeek:j['contractEndWeek'] as int?,contractTermMonths:j['contractTermMonths'] as int?,contractDecision:ContractDecision.values.byName(j['contractDecision'] as String? ?? 'undecided'),assignmentFitScore:j['assignmentFitScore'] as int?,fieldEvaluation:j['fieldEvaluation'] as int?);
}

class PendingHire {
  final String id; final Applicant applicant; final int salary,decisionWeek,joinWeek;
  const PendingHire({required this.id,required this.applicant,required this.salary,required this.decisionWeek,required this.joinWeek});
  Map<String,dynamic> toJson()=>{'id':id,'applicant':applicant.toJson(),'salary':salary,'decisionWeek':decisionWeek,'joinWeek':joinWeek};
  factory PendingHire.fromJson(Map<String,dynamic> j)=>PendingHire(id:j['id'] as String,applicant:Applicant.fromJson(j['applicant'] as Map<String,dynamic>),salary:j['salary'] as int,decisionWeek:j['decisionWeek'] as int,joinWeek:j['joinWeek'] as int);
}
