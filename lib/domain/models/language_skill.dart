import 'programming_language.dart';

/// An applicant's experience with a single [ProgrammingLanguage].
///
/// Two experience figures are tracked on purpose:
///  * [displayedExperienceMonths] — what appears on the applicant's résumé,
///    i.e. what the player sees.
///  * [actualExperienceMonths] — the hidden, ground-truth experience used to
///    derive [actualSkill]. A dishonest applicant (see `PersonalityTraits
///    .dishonesty`) may have `displayedExperienceMonths >
///    actualExperienceMonths`, but the displayed figure is always clamped so
///    it never contradicts the applicant's age or total IT experience.
///
/// [actualSkill] (0-100) is the hidden "real" skill level, which does not
/// necessarily line up with either experience figure.
class LanguageSkill {
  final ProgrammingLanguage language;
  final int displayedExperienceMonths;
  final int actualExperienceMonths;
  final int actualSkill;

  const LanguageSkill({
    required this.language,
    required this.displayedExperienceMonths,
    required this.actualExperienceMonths,
    required this.actualSkill,
  }) : assert(displayedExperienceMonths >= 0),
       assert(actualExperienceMonths >= 0),
       assert(actualSkill >= 0 && actualSkill <= 100);

  LanguageSkill copyWith({
    ProgrammingLanguage? language,
    int? displayedExperienceMonths,
    int? actualExperienceMonths,
    int? actualSkill,
  }) {
    return LanguageSkill(
      language: language ?? this.language,
      displayedExperienceMonths:
          displayedExperienceMonths ?? this.displayedExperienceMonths,
      actualExperienceMonths:
          actualExperienceMonths ?? this.actualExperienceMonths,
      actualSkill: actualSkill ?? this.actualSkill,
    );
  }

  Map<String, dynamic> toJson() => {
    'language': language.jsonValue,
    'displayedExperienceMonths': displayedExperienceMonths,
    'actualExperienceMonths': actualExperienceMonths,
    'actualSkill': actualSkill,
  };

  factory LanguageSkill.fromJson(Map<String, dynamic> json) {
    return LanguageSkill(
      language: ProgrammingLanguage.fromJson(json['language'] as String),
      displayedExperienceMonths: json['displayedExperienceMonths'] as int,
      actualExperienceMonths: json['actualExperienceMonths'] as int,
      actualSkill: json['actualSkill'] as int,
    );
  }

  @override
  String toString() =>
      'LanguageSkill($language, displayed: $displayedExperienceMonths mo, '
      'actual: $actualExperienceMonths mo, skill: $actualSkill)';
}
