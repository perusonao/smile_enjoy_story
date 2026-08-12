import '../../domain/domain.dart';

/// Where a [ProjectProposal] is in its lifecycle.
///
/// `proposed` (提案週) → `interviewPassed`/`interviewFailed` (翌週の案件面談)
/// → a passed proposal becomes an [ActiveAssignment] the week after that.
enum ProposalStage {
  proposed,
  interviewPassed,
  interviewFailed;

  String get jsonValue => name;

  static ProposalStage fromJson(String value) => ProposalStage.values
      .firstWhere(
        (e) => e.name == value,
        orElse: () => throw ArgumentError('Unknown ProposalStage: $value'),
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

  const ProjectProposal({
    required this.id,
    required this.engineerId,
    required this.project,
    required this.proposedWeek,
    required this.stage,
    this.interviewWeek,
    this.interviewSuccessRate,
    this.assignWeek,
  });

  ProjectProposal copyWith({
    ProposalStage? stage,
    int? interviewWeek,
    int? interviewSuccessRate,
    int? assignWeek,
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
      );
}

/// An engineer currently staffed on a project, generating weekly revenue.
class ActiveAssignment {
  final String engineerId;
  final Project project;
  final int remainingWeeks;
  final int assignedWeek;

  const ActiveAssignment({
    required this.engineerId,
    required this.project,
    required this.remainingWeeks,
    required this.assignedWeek,
  });

  ActiveAssignment copyWith({int? remainingWeeks}) => ActiveAssignment(
    engineerId: engineerId,
    project: project,
    remainingWeeks: remainingWeeks ?? this.remainingWeeks,
    assignedWeek: assignedWeek,
  );

  Map<String, dynamic> toJson() => {
    'engineerId': engineerId,
    'project': project.toJson(),
    'remainingWeeks': remainingWeeks,
    'assignedWeek': assignedWeek,
  };

  factory ActiveAssignment.fromJson(Map<String, dynamic> json) =>
      ActiveAssignment(
        engineerId: json['engineerId'] as String,
        project: Project.fromJson(json['project'] as Map<String, dynamic>),
        remainingWeeks: json['remainingWeeks'] as int,
        assignedWeek: json['assignedWeek'] as int,
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
