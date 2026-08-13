import '../../domain/domain.dart';
import 'sales_models.dart';

/// Where a [ProjectProposal] is in its lifecycle.
///
/// `proposed` (提案週) → `interviewPassed`/`interviewFailed` (翌週の案件面談)
/// → a passed proposal becomes an [ActiveAssignment] the week after that.
enum ProposalStage {
  proposed,
  interviewPassed,
  interviewFailed;

  String get jsonValue => name;

  static ProposalStage fromJson(String value) =>
      ProposalStage.values.firstWhere(
        (e) => e.name == value,
        orElse: () => throw ArgumentError('Unknown ProposalStage: $value'),
      );
}

enum ApplicationStatus {
  active,
  rejected,
  offered,
  accepted,
  declined,
  cancelled,
}

enum SelectionStepResult { passed, failed, cancelled }

class SelectionStepHistory {
  final int week;
  final SelectionStep step;
  final SelectionStepResult result;
  final int? successRate;

  const SelectionStepHistory({
    required this.week,
    required this.step,
    required this.result,
    this.successRate,
  });

  Map<String, dynamic> toJson() => {
    'week': week,
    'step': step.name,
    'result': result.name,
    'successRate': successRate,
  };

  factory SelectionStepHistory.fromJson(Map<String, dynamic> json) =>
      SelectionStepHistory(
        week: json['week'] as int,
        step: SelectionStep.fromJson(json['step'] as String),
        result: SelectionStepResult.values.firstWhere(
          (result) => result.name == json['result'],
        ),
        successRate: json['successRate'] as int?,
      );
}

/// A waiting engineer proposed for a project, tracked until the project
/// interview resolves (and, if passed, until assignment starts).
class ProjectProposal {
  final String id;
  final String engineerId;

  /// Snapshot of the project at proposal time. The project may have been
  /// removed from the open marketplace by the time this resolves, so we
  /// keep a copy here rather than a bare id.
  final Project project;
  final int proposedWeek;
  final ProposalStage stage;
  final int? interviewWeek;
  final int? interviewSuccessRate;
  final int? assignWeek;
  final int currentStepIndex;
  final ApplicationStatus status;
  final List<SelectionStepHistory> stepHistory;
  final int fitScore;
  final String? finalOfferId;
  final String? rejectionReason;

  const ProjectProposal({
    required this.id,
    required this.engineerId,
    required this.project,
    required this.proposedWeek,
    required this.stage,
    this.interviewWeek,
    this.interviewSuccessRate,
    this.assignWeek,
    this.currentStepIndex = 0,
    this.status = ApplicationStatus.active,
    this.stepHistory = const [],
    this.fitScore = 0,
    this.finalOfferId,
    this.rejectionReason,
  });

  String get employeeId => engineerId;
  String get projectId => project.id;
  int get createdWeek => proposedWeek;
  SelectionStep get currentStep =>
      project.selectionFlow.steps[currentStepIndex.clamp(
        0,
        project.selectionFlow.steps.length - 1,
      )];
  bool get isActive => status == ApplicationStatus.active;

  ProjectProposal copyWith({
    ProposalStage? stage,
    int? interviewWeek,
    int? interviewSuccessRate,
    int? assignWeek,
    int? currentStepIndex,
    ApplicationStatus? status,
    List<SelectionStepHistory>? stepHistory,
    int? fitScore,
    String? finalOfferId,
    String? rejectionReason,
  }) {
    return ProjectProposal(
      id: id,
      engineerId: engineerId,
      project: project,
      proposedWeek: proposedWeek,
      stage: stage ?? this.stage,
      interviewWeek: interviewWeek ?? this.interviewWeek,
      interviewSuccessRate: interviewSuccessRate ?? this.interviewSuccessRate,
      assignWeek: assignWeek ?? this.assignWeek,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      status: status ?? this.status,
      stepHistory: stepHistory ?? this.stepHistory,
      fitScore: fitScore ?? this.fitScore,
      finalOfferId: finalOfferId ?? this.finalOfferId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'engineerId': engineerId,
    'project': project.toJson(),
    'proposedWeek': proposedWeek,
    'stage': stage.jsonValue,
    'interviewWeek': interviewWeek,
    'interviewSuccessRate': interviewSuccessRate,
    'assignWeek': assignWeek,
    'currentStepIndex': currentStepIndex,
    'status': status.name,
    'stepHistory': stepHistory.map((item) => item.toJson()).toList(),
    'fitScore': fitScore,
    'finalOfferId': finalOfferId,
    'rejectionReason': rejectionReason,
  };

  factory ProjectProposal.fromJson(Map<String, dynamic> json) =>
      ProjectProposal(
        id: json['id'] as String,
        engineerId: json['engineerId'] as String,
        project: Project.fromJson(json['project'] as Map<String, dynamic>),
        proposedWeek: json['proposedWeek'] as int,
        stage: ProposalStage.fromJson(json['stage'] as String),
        interviewWeek: json['interviewWeek'] as int?,
        interviewSuccessRate: json['interviewSuccessRate'] as int?,
        assignWeek: json['assignWeek'] as int?,
        currentStepIndex: json['currentStepIndex'] as int? ?? 0,
        status: ApplicationStatus.values.firstWhere(
          (status) => status.name == (json['status'] as String? ?? 'active'),
          orElse: () => ApplicationStatus.active,
        ),
        stepHistory: (json['stepHistory'] as List? ?? const [])
            .map(
              (item) =>
                  SelectionStepHistory.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        fitScore: json['fitScore'] as int? ?? 0,
        finalOfferId: json['finalOfferId'] as String?,
        rejectionReason: json['rejectionReason'] as String?,
      );
}

/// 0.3B name for the employee x project sales entity. The legacy name is
/// retained so old UI/tests and schema-v2 saves can migrate safely.
typedef ProjectApplication = ProjectProposal;

enum OfferStatus { pending, accepted, declined, expired }

class Offer {
  final String id;
  final String applicationId;
  final String projectId;
  final String employeeId;
  final int monthlyRate;
  final int startWeek;
  final int responseDeadlineWeek;
  final OfferStatus status;

  const Offer({
    required this.id,
    required this.applicationId,
    required this.projectId,
    required this.employeeId,
    required this.monthlyRate,
    required this.startWeek,
    required this.responseDeadlineWeek,
    this.status = OfferStatus.pending,
  });

  Offer copyWith({OfferStatus? status}) => Offer(
    id: id,
    applicationId: applicationId,
    projectId: projectId,
    employeeId: employeeId,
    monthlyRate: monthlyRate,
    startWeek: startWeek,
    responseDeadlineWeek: responseDeadlineWeek,
    status: status ?? this.status,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'applicationId': applicationId,
    'projectId': projectId,
    'employeeId': employeeId,
    'monthlyRate': monthlyRate,
    'startWeek': startWeek,
    'responseDeadlineWeek': responseDeadlineWeek,
    'status': status.name,
  };

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
    id: json['id'] as String,
    applicationId: json['applicationId'] as String,
    projectId: json['projectId'] as String,
    employeeId: json['employeeId'] as String,
    monthlyRate: json['monthlyRate'] as int,
    startWeek: json['startWeek'] as int,
    responseDeadlineWeek: json['responseDeadlineWeek'] as int,
    status: OfferStatus.values.firstWhere(
      (status) => status.name == json['status'],
    ),
  );
}

/// An engineer currently staffed on a project, generating weekly revenue.
class ActiveAssignment {
  final String engineerId;
  final Project project;
  final int remainingWeeks;
  final int assignedWeek;
  final int contractStartWeek;
  final int contractEndWeek;
  final int contractTermMonths;
  final ContractDecision contractDecision;

  ActiveAssignment({
    required this.engineerId,
    required this.project,
    required this.remainingWeeks,
    required this.assignedWeek,
    int? contractStartWeek,
    int? contractEndWeek,
    int? contractTermMonths,
    this.contractDecision = ContractDecision.undecided,
  }) : contractStartWeek = contractStartWeek ?? assignedWeek,
       contractEndWeek = contractEndWeek ?? (assignedWeek + remainingWeeks - 1),
       contractTermMonths = contractTermMonths ?? project.contractTermMonths;

  ActiveAssignment copyWith({int? remainingWeeks, int? contractEndWeek, ContractDecision? contractDecision}) => ActiveAssignment(
    engineerId: engineerId,
    project: project,
    remainingWeeks: remainingWeeks ?? this.remainingWeeks,
    assignedWeek: assignedWeek,
    contractStartWeek: contractStartWeek,
    contractEndWeek: contractEndWeek ?? this.contractEndWeek,
    contractTermMonths: contractTermMonths,
    contractDecision: contractDecision ?? this.contractDecision,
  );

  Map<String, dynamic> toJson() => {
    'engineerId': engineerId,
    'project': project.toJson(),
    'remainingWeeks': remainingWeeks,
    'assignedWeek': assignedWeek,
    'contractStartWeek': contractStartWeek,
    'contractEndWeek': contractEndWeek,
    'contractTermMonths': contractTermMonths,
    'contractDecision': contractDecision.name,
  };

  factory ActiveAssignment.fromJson(Map<String, dynamic> json) =>
      ActiveAssignment(
        engineerId: json['engineerId'] as String,
        project: Project.fromJson(json['project'] as Map<String, dynamic>),
        remainingWeeks: json['remainingWeeks'] as int,
        assignedWeek: json['assignedWeek'] as int,
        contractStartWeek: json['contractStartWeek'] as int?,
        contractEndWeek: json['contractEndWeek'] as int?,
        contractTermMonths: json['contractTermMonths'] as int?,
        contractDecision: ContractDecision.values.byName(json['contractDecision'] as String? ?? 'undecided'),
      );
}

/// An applicant who has accepted an offer and is waiting to join.
class PendingHire {
  final String id;
  final Applicant applicant;
  final int salary;
  final int decisionWeek;
  final int joinWeek;

  const PendingHire({
    required this.id,
    required this.applicant,
    required this.salary,
    required this.decisionWeek,
    required this.joinWeek,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'applicant': applicant.toJson(),
    'salary': salary,
    'decisionWeek': decisionWeek,
    'joinWeek': joinWeek,
  };

  factory PendingHire.fromJson(Map<String, dynamic> json) => PendingHire(
    id: json['id'] as String,
    applicant: Applicant.fromJson(json['applicant'] as Map<String, dynamic>),
    salary: json['salary'] as int,
    decisionWeek: json['decisionWeek'] as int,
    joinWeek: json['joinWeek'] as int,
  );
}
