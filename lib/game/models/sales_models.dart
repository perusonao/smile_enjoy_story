enum InterviewOfferStatus { pending, accepted, declined, expired }

class InterviewOffer {
  final String id, employeeId, projectId, clientId;
  final int generatedWeek, expiresWeek, skillSheetMatch;
  final InterviewOfferStatus status;
  const InterviewOffer({required this.id, required this.employeeId, required this.projectId, required this.clientId, required this.generatedWeek, required this.expiresWeek, required this.skillSheetMatch, this.status = InterviewOfferStatus.pending});
  InterviewOffer copyWith({InterviewOfferStatus? status}) => InterviewOffer(id:id, employeeId:employeeId, projectId:projectId, clientId:clientId, generatedWeek:generatedWeek, expiresWeek:expiresWeek, skillSheetMatch:skillSheetMatch, status:status ?? this.status);
  Map<String,dynamic> toJson() => {'id':id,'employeeId':employeeId,'projectId':projectId,'clientId':clientId,'generatedWeek':generatedWeek,'expiresWeek':expiresWeek,'skillSheetMatch':skillSheetMatch,'status':status.name};
  factory InterviewOffer.fromJson(Map<String,dynamic> j) => InterviewOffer(id:j['id'] as String,employeeId:j['employeeId'] as String,projectId:j['projectId'] as String,clientId:j['clientId'] as String,generatedWeek:j['generatedWeek'] as int,expiresWeek:j['expiresWeek'] as int,skillSheetMatch:j['skillSheetMatch'] as int,status:InterviewOfferStatus.values.byName(j['status'] as String));
}

class ClientRelation {
  final String clientId;
  final bool unlocked;
  final int trust, totalDeals, successfulAssignments;
  final int? lastDealWeek;
  final String? introducedByClientId;
  const ClientRelation({required this.clientId, required this.unlocked, this.trust=0, this.totalDeals=0, this.successfulAssignments=0, this.lastDealWeek, this.introducedByClientId});
  ClientRelation copyWith({bool? unlocked,int? trust,int? totalDeals,int? successfulAssignments,int? lastDealWeek,String? introducedByClientId}) => ClientRelation(clientId:clientId,unlocked:unlocked??this.unlocked,trust:trust??this.trust,totalDeals:totalDeals??this.totalDeals,successfulAssignments:successfulAssignments??this.successfulAssignments,lastDealWeek:lastDealWeek??this.lastDealWeek,introducedByClientId:introducedByClientId??this.introducedByClientId);
  Map<String,dynamic> toJson()=>{'clientId':clientId,'unlocked':unlocked,'trust':trust,'totalDeals':totalDeals,'successfulAssignments':successfulAssignments,'lastDealWeek':lastDealWeek,'introducedByClientId':introducedByClientId};
  factory ClientRelation.fromJson(Map<String,dynamic> j)=>ClientRelation(clientId:j['clientId'] as String,unlocked:j['unlocked'] as bool,trust:j['trust'] as int,totalDeals:j['totalDeals'] as int,successfulAssignments:j['successfulAssignments'] as int,lastDealWeek:j['lastDealWeek'] as int?,introducedByClientId:j['introducedByClientId'] as String?);
}

enum ContractDecision { undecided, extend, withdraw }
