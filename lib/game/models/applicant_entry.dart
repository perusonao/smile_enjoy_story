import '../../domain/domain.dart';
import 'recruitment_media.dart';

/// An [Applicant] currently sitting in the player's applicant pool, tagged
/// with when and via which medium it appeared.
class ApplicantEntry {
  final Applicant applicant;
  final int appearedWeek;
  final RecruitmentMediaType source;

  const ApplicantEntry({
    required this.applicant,
    required this.appearedWeek,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
    'applicant': applicant.toJson(),
    'appearedWeek': appearedWeek,
    'source': source.jsonValue,
  };

  factory ApplicantEntry.fromJson(Map<String, dynamic> json) => ApplicantEntry(
    applicant: Applicant.fromJson(json['applicant'] as Map<String, dynamic>),
    appearedWeek: json['appearedWeek'] as int,
    source: RecruitmentMediaType.fromJson(json['source'] as String),
  );
}
