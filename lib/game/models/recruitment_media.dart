import '../../domain/domain.dart';

/// The three recruitment media the player can post job listings to.
///
/// See the Playable 0.1 design doc, section 21.
enum RecruitmentMediaType {
  freeWork,
  engineerCareer,
  directScout;

  String get jsonValue => name;

  static RecruitmentMediaType fromJson(String value) =>
      RecruitmentMediaType.values.firstWhere(
        (e) => e.name == value,
        orElse: () =>
            throw ArgumentError('Unknown RecruitmentMediaType: $value'),
      );
}

/// Static configuration for a [RecruitmentMediaType].
class RecruitmentMediaConfig {
  final RecruitmentMediaType type;
  final String label;
  final String description;
  final int cost;
  final int durationWeeks;
  final IntRange weeklyApplicants;

  const RecruitmentMediaConfig({
    required this.type,
    required this.label,
    required this.description,
    required this.cost,
    required this.durationWeeks,
    required this.weeklyApplicants,
  });
}

/// Config table for all recruitment media (Playable 0.1 design doc §21).
const Map<RecruitmentMediaType, RecruitmentMediaConfig>
recruitmentMediaConfigs = {
  RecruitmentMediaType.freeWork: RecruitmentMediaConfig(
    type: RecruitmentMediaType.freeWork,
    label: 'Free Work',
    description: '無料の求人媒体。若手中心の応募が多い。',
    cost: 0,
    durationWeeks: 4,
    weeklyApplicants: IntRange(1, 3),
  ),
  RecruitmentMediaType.engineerCareer: RecruitmentMediaConfig(
    type: RecruitmentMediaType.engineerCareer,
    label: 'Engineer Career',
    description: '有料の求人媒体。経験者中心の応募が多い。',
    cost: 100000,
    durationWeeks: 4,
    weeklyApplicants: IntRange(1, 2),
  ),
  RecruitmentMediaType.directScout: RecruitmentMediaConfig(
    type: RecruitmentMediaType.directScout,
    label: 'Direct Scout',
    description: '高額なスカウト媒体。高スキル人材寄りの応募。',
    cost: 200000,
    durationWeeks: 4,
    weeklyApplicants: IntRange(1, 1),
  ),
};

/// An active job listing the player has posted.
class RecruitmentListing {
  final String id;
  final RecruitmentMediaType type;
  final int postedWeek;
  final int durationWeeks;

  const RecruitmentListing({
    required this.id,
    required this.type,
    required this.postedWeek,
    required this.durationWeeks,
  });

  /// Whether this listing is still generating applicants during [week].
  bool isActiveOn(int week) => week < postedWeek + durationWeeks;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.jsonValue,
    'postedWeek': postedWeek,
    'durationWeeks': durationWeeks,
  };

  factory RecruitmentListing.fromJson(Map<String, dynamic> json) =>
      RecruitmentListing(
        id: json['id'] as String,
        type: RecruitmentMediaType.fromJson(json['type'] as String),
        postedWeek: json['postedWeek'] as int,
        durationWeeks: json['durationWeeks'] as int,
      );
}
