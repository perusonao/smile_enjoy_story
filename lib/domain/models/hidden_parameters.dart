/// Parameters that are never shown to the player at application time.
///
/// They still live on the domain model (per the Phase 0 design doc) so that
/// later phases (interviews, onboarding, retention, ...) can consume them
/// without changing the applicant's shape.
class HiddenParameters {
  final int growthPotential; // 1-5
  final int stressTolerance; // 1-5
  final int retention; // 1-5
  final int projectInterviewSkill; // 1-5
  final int turnoverIntent; // 0-100

  const HiddenParameters({
    required this.growthPotential,
    required this.stressTolerance,
    required this.retention,
    required this.projectInterviewSkill,
    required this.turnoverIntent,
  }) : assert(growthPotential >= 1 && growthPotential <= 5),
       assert(stressTolerance >= 1 && stressTolerance <= 5),
       assert(retention >= 1 && retention <= 5),
       assert(projectInterviewSkill >= 1 && projectInterviewSkill <= 5),
       assert(turnoverIntent >= 0 && turnoverIntent <= 100);

  Map<String, dynamic> toJson() => {
    'growthPotential': growthPotential,
    'stressTolerance': stressTolerance,
    'retention': retention,
    'projectInterviewSkill': projectInterviewSkill,
    'turnoverIntent': turnoverIntent,
  };

  factory HiddenParameters.fromJson(Map<String, dynamic> json) {
    return HiddenParameters(
      growthPotential: json['growthPotential'] as int,
      stressTolerance: json['stressTolerance'] as int,
      retention: json['retention'] as int,
      projectInterviewSkill: json['projectInterviewSkill'] as int,
      turnoverIntent: json['turnoverIntent'] as int,
    );
  }

  @override
  String toString() =>
      'HiddenParameters(growth:$growthPotential stress:$stressTolerance '
      'retention:$retention interview:$projectInterviewSkill '
      'turnover:$turnoverIntent)';
}
