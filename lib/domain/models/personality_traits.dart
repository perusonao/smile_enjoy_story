/// Human/personal traits of an applicant, each on a 1-5 scale.
///
/// These are considered public/visible profile data (as opposed to
/// [HiddenParameters]), though the UI layer may still choose to hide some of
/// them until later in the hiring flow.
class PersonalityTraits {
  final int looks;
  final int cleanliness;
  final int communication;
  final int alcoholTolerance;
  final int seriousness;

  /// How likely the applicant is to embellish their résumé. Does not by
  /// itself imply anything was embellished — see [LanguageSkill].
  final int dishonesty;

  const PersonalityTraits({
    required this.looks,
    required this.cleanliness,
    required this.communication,
    required this.alcoholTolerance,
    required this.seriousness,
    required this.dishonesty,
  }) : assert(looks >= 1 && looks <= 5),
       assert(cleanliness >= 1 && cleanliness <= 5),
       assert(communication >= 1 && communication <= 5),
       assert(alcoholTolerance >= 1 && alcoholTolerance <= 5),
       assert(seriousness >= 1 && seriousness <= 5),
       assert(dishonesty >= 1 && dishonesty <= 5);

  Map<String, dynamic> toJson() => {
    'looks': looks,
    'cleanliness': cleanliness,
    'communication': communication,
    'alcoholTolerance': alcoholTolerance,
    'seriousness': seriousness,
    'dishonesty': dishonesty,
  };

  factory PersonalityTraits.fromJson(Map<String, dynamic> json) {
    return PersonalityTraits(
      looks: json['looks'] as int,
      cleanliness: json['cleanliness'] as int,
      communication: json['communication'] as int,
      alcoholTolerance: json['alcoholTolerance'] as int,
      seriousness: json['seriousness'] as int,
      dishonesty: json['dishonesty'] as int,
    );
  }

  @override
  String toString() =>
      'PersonalityTraits(looks:$looks clean:$cleanliness '
      'comm:$communication alcohol:$alcoholTolerance serious:$seriousness '
      'dishonesty:$dishonesty)';
}
