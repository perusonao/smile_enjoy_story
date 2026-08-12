import 'applicant.dart';
import 'engineer_status.dart';

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

  const Engineer({
    required this.id,
    required this.sourceApplicantId,
    required this.profile,
    required this.salary,
    required this.employmentWeek,
    required this.status,
  });

  Engineer copyWith({
    String? id,
    String? sourceApplicantId,
    Applicant? profile,
    int? salary,
    int? employmentWeek,
    EngineerStatus? status,
  }) {
    return Engineer(
      id: id ?? this.id,
      sourceApplicantId: sourceApplicantId ?? this.sourceApplicantId,
      profile: profile ?? this.profile,
      salary: salary ?? this.salary,
      employmentWeek: employmentWeek ?? this.employmentWeek,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceApplicantId': sourceApplicantId,
    'profile': profile.toJson(),
    'salary': salary,
    'employmentWeek': employmentWeek,
    'status': status.jsonValue,
  };

  factory Engineer.fromJson(Map<String, dynamic> json) {
    return Engineer(
      id: json['id'] as String,
      sourceApplicantId: json['sourceApplicantId'] as String,
      profile: Applicant.fromJson(json['profile'] as Map<String, dynamic>),
      salary: json['salary'] as int,
      employmentWeek: json['employmentWeek'] as int,
      status: EngineerStatus.fromJson(json['status'] as String),
    );
  }

  @override
  String toString() => 'Engineer($id, ${profile.name}, $status)';
}
