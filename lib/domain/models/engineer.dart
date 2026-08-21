import 'applicant.dart';
import 'career_history_entry.dart';
import 'employee_preference.dart';
import 'employee_relationship_event.dart';
import 'engineer_status.dart';
import 'sales_profile.dart';

/// Number of recent [EmployeeRelationshipEvent] rows kept per engineer
/// (Playable 0.4C §38).
const int maxRelationshipHistory = 5;
const int defaultEmployeeCompanyTrust = 60;
const int defaultEmployeeMorale = 65;

/// An employee, created once an [Applicant] has been hired.
///
/// Phase 0 only defines the shape of this model; the hiring flow that
/// produces an [Engineer] from an [Applicant] is out of scope until a later
/// phase.
class Engineer {
  final String id;
  final String sourceApplicantId;

  /// Snapshot of the applicant's profile at the time of hiring.
  final Applicant profile;
  final int salary;
  final int employmentWeek;
  final EngineerStatus status;

  /// "会社・社長そのものをどれくらい信用しているか" (Playable 0.4C §4):
  /// promises kept, honest SkillSheet handling, good placements.
  final int companyTrust;

  /// "今、仕事や待遇にどれくらい満足しているか" (Playable 0.4C §3):
  /// current assignment fit, pay events, equipment, waiting streak, commute.
  /// Deliberately independent from [companyTrust] — high pay can mean high
  /// morale with low trust, and vice versa.
  final int morale;

  /// The one welfare dimension this employee cares about most (§25-26),
  /// driving how they react to bonuses/trips/etc.
  final EmployeePreference preference;

  /// Up to [maxRelationshipHistory] most recent morale/trust changes, newest
  /// last, so the player can always see *why* a number moved (§38-40).
  final List<EmployeeRelationshipEvent> relationshipHistory;

  final Map<Industry, int> industryExperience;
  final ResidenceArea residenceArea;
  final int talkSkill;
  final int mental;
  final int toughness;
  final Set<EmployeeAbility> abilities;
  final SalesStatus salesStatus;
  final int availableFromWeek;

  /// Actual project-by-project career facts. SkillSheet remains the separate
  /// sales-facing representation and may intentionally differ from this.
  final List<CareerHistoryEntry> careerHistory;

  const Engineer({
    required this.id,
    required this.sourceApplicantId,
    required this.profile,
    required this.salary,
    required this.employmentWeek,
    required this.status,
    this.companyTrust = defaultEmployeeCompanyTrust,
    this.morale = defaultEmployeeMorale,
    this.preference = EmployeePreference.stability,
    this.relationshipHistory = const [],
    this.industryExperience = const {},
    this.residenceArea = ResidenceArea.tokyo,
    this.talkSkill = 3,
    this.mental = 3,
    this.toughness = 3,
    this.abilities = const {},
    this.salesStatus = SalesStatus.notSelling,
    this.availableFromWeek = 1,
    this.careerHistory = const [],
  });

  Engineer copyWith({
    String? id,
    String? sourceApplicantId,
    Applicant? profile,
    int? salary,
    int? employmentWeek,
    EngineerStatus? status,
    int? companyTrust,
    int? morale,
    EmployeePreference? preference,
    List<EmployeeRelationshipEvent>? relationshipHistory,
    Map<Industry,int>? industryExperience,
    ResidenceArea? residenceArea,
    int? talkSkill,
    int? mental,
    int? toughness,
    Set<EmployeeAbility>? abilities,
    SalesStatus? salesStatus,
    int? availableFromWeek,
    List<CareerHistoryEntry>? careerHistory,
  }) {
    return Engineer(
      id: id ?? this.id,
      sourceApplicantId: sourceApplicantId ?? this.sourceApplicantId,
      profile: profile ?? this.profile,
      salary: salary ?? this.salary,
      employmentWeek: employmentWeek ?? this.employmentWeek,
      status: status ?? this.status,
      companyTrust: companyTrust ?? this.companyTrust,
      morale: morale ?? this.morale,
      preference: preference ?? this.preference,
      relationshipHistory: relationshipHistory ?? this.relationshipHistory,
      industryExperience: industryExperience ?? this.industryExperience,
      residenceArea: residenceArea ?? this.residenceArea,
      talkSkill: talkSkill ?? this.talkSkill,
      mental: mental ?? this.mental,
      toughness: toughness ?? this.toughness,
      abilities: abilities ?? this.abilities,
      salesStatus: salesStatus ?? this.salesStatus,
      availableFromWeek: availableFromWeek ?? this.availableFromWeek,
      careerHistory: careerHistory ?? this.careerHistory,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceApplicantId': sourceApplicantId,
    'profile': profile.toJson(),
    'salary': salary,
    'employmentWeek': employmentWeek,
    'status': status.jsonValue,
    'companyTrust': companyTrust,
    'morale': morale,
    'preference': preference.jsonValue,
    'relationshipHistory': relationshipHistory.map((e) => e.toJson()).toList(),
    'industryExperience': industryExperience.map((k,v)=>MapEntry(k.name,v)),
    'residenceArea': residenceArea.name,
    'talkSkill': talkSkill,
    'mental': mental,
    'toughness': toughness,
    'abilities': abilities.map((e)=>e.name).toList(),
    'salesStatus': salesStatus.name,
    'availableFromWeek': availableFromWeek,
    'careerHistory': careerHistory.map((e) => e.toJson()).toList(),
  };

  factory Engineer.fromJson(Map<String, dynamic> json) {
    return Engineer(
      id: json['id'] as String,
      sourceApplicantId: json['sourceApplicantId'] as String,
      profile: Applicant.fromJson(json['profile'] as Map<String, dynamic>),
      salary: json['salary'] as int,
      employmentWeek: json['employmentWeek'] as int,
      status: EngineerStatus.fromJson(json['status'] as String),
      companyTrust: json['companyTrust'] as int? ?? defaultEmployeeCompanyTrust,
      morale: json['morale'] as int? ?? defaultEmployeeMorale,
      preference: json['preference'] == null
          ? EmployeePreference.stability
          : EmployeePreference.fromJson(json['preference'] as String),
      relationshipHistory: (json['relationshipHistory'] as List? ?? const [])
          .map((e) => EmployeeRelationshipEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      industryExperience: (json['industryExperience'] as Map<String,dynamic>? ?? {}).map((k,v)=>MapEntry(Industry.values.byName(k),v as int)),
      residenceArea: ResidenceArea.values.byName(json['residenceArea'] as String? ?? 'tokyo'),
      talkSkill: json['talkSkill'] as int? ?? 3,
      mental: json['mental'] as int? ?? 3,
      toughness: json['toughness'] as int? ?? 3,
      abilities: (json['abilities'] as List? ?? const []).map((e)=>EmployeeAbility.values.byName(e as String)).toSet(),
      salesStatus: SalesStatus.values.byName(json['salesStatus'] as String? ?? 'notSelling'),
      availableFromWeek: json['availableFromWeek'] as int? ?? 1,
      careerHistory: (json['careerHistory'] as List? ?? const [])
          .map((e) => CareerHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() => 'Engineer($id, ${profile.name}, $status)';
}
