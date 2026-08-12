import 'programming_language.dart';
import 'project_rank.dart';
import 'project_type.dart';
import 'remote_policy.dart';

/// A project engagement offered by a [Client], as produced by
/// `ProjectGenerator`.
///
/// Models the "案件" stage of the pipeline (案件探索 → 案件提案 →
/// 案件面談 → 参画). Matching/negotiation logic is out of scope for Phase 0.
class Project {
  final String id;
  final String clientId;
  final String title;

  /// Category used by the generator to keep required-skill fields coherent.
  /// Not itemized explicitly in the Phase 0 design doc's field list, but
  /// required for consistency checks (e.g. a `frontend` project should
  /// require frontend skill, not infrastructure).
  final ProjectType type;
  final ProjectRank rank;
  final int monthlyRate;
  final int durationWeeks;
  final int applicationDeadlineWeek;

  final List<ProgrammingLanguage> requiredLanguages;
  final int requiredDatabase; // 0-5
  final int requiredNetwork; // 0-5
  final int requiredInfrastructure; // 0-5
  final int requiredFrontend; // 0-5
  final int requiredBackend; // 0-5
  final int requiredLeader; // 0-5
  final int requiredManager; // 0-5
  final int requiredJapaneseLevel; // 1-5

  final RemotePolicy remotePolicy;
  final int interviewCount;

  /// 1 (easy) - 5 (hard).
  final int difficulty;

  const Project({
    required this.id,
    required this.clientId,
    required this.title,
    required this.type,
    required this.rank,
    required this.monthlyRate,
    required this.durationWeeks,
    required this.applicationDeadlineWeek,
    required this.requiredLanguages,
    required this.requiredDatabase,
    required this.requiredNetwork,
    required this.requiredInfrastructure,
    required this.requiredFrontend,
    required this.requiredBackend,
    required this.requiredLeader,
    required this.requiredManager,
    required this.requiredJapaneseLevel,
    required this.remotePolicy,
    required this.interviewCount,
    required this.difficulty,
  }) : assert(monthlyRate > 0),
       assert(durationWeeks > 0),
       assert(requiredDatabase >= 0 && requiredDatabase <= 5),
       assert(requiredNetwork >= 0 && requiredNetwork <= 5),
       assert(requiredInfrastructure >= 0 && requiredInfrastructure <= 5),
       assert(requiredFrontend >= 0 && requiredFrontend <= 5),
       assert(requiredBackend >= 0 && requiredBackend <= 5),
       assert(requiredLeader >= 0 && requiredLeader <= 5),
       assert(requiredManager >= 0 && requiredManager <= 5),
       assert(requiredJapaneseLevel >= 1 && requiredJapaneseLevel <= 5),
       assert(interviewCount >= 1),
       assert(difficulty >= 1 && difficulty <= 5);

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'title': title,
    'type': type.jsonValue,
    'rank': rank.jsonValue,
    'monthlyRate': monthlyRate,
    'durationWeeks': durationWeeks,
    'applicationDeadlineWeek': applicationDeadlineWeek,
    'requiredLanguages': requiredLanguages.map((e) => e.jsonValue).toList(),
    'requiredDatabase': requiredDatabase,
    'requiredNetwork': requiredNetwork,
    'requiredInfrastructure': requiredInfrastructure,
    'requiredFrontend': requiredFrontend,
    'requiredBackend': requiredBackend,
    'requiredLeader': requiredLeader,
    'requiredManager': requiredManager,
    'requiredJapaneseLevel': requiredJapaneseLevel,
    'remotePolicy': remotePolicy.jsonValue,
    'interviewCount': interviewCount,
    'difficulty': difficulty,
  };

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      title: json['title'] as String,
      type: ProjectType.fromJson(json['type'] as String),
      rank: ProjectRank.fromJson(json['rank'] as String),
      monthlyRate: json['monthlyRate'] as int,
      durationWeeks: json['durationWeeks'] as int,
      applicationDeadlineWeek: json['applicationDeadlineWeek'] as int,
      requiredLanguages: (json['requiredLanguages'] as List)
          .map((e) => ProgrammingLanguage.fromJson(e as String))
          .toList(),
      requiredDatabase: json['requiredDatabase'] as int,
      requiredNetwork: json['requiredNetwork'] as int,
      requiredInfrastructure: json['requiredInfrastructure'] as int,
      requiredFrontend: json['requiredFrontend'] as int,
      requiredBackend: json['requiredBackend'] as int,
      requiredLeader: json['requiredLeader'] as int,
      requiredManager: json['requiredManager'] as int,
      requiredJapaneseLevel: json['requiredJapaneseLevel'] as int,
      remotePolicy: RemotePolicy.fromJson(json['remotePolicy'] as String),
      interviewCount: json['interviewCount'] as int,
      difficulty: json['difficulty'] as int,
    );
  }

  @override
  String toString() => 'Project($id, $title, $rank, ¥$monthlyRate/mo)';
}
