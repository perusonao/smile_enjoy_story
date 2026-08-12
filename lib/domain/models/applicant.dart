import 'applicant_type.dart';
import 'education.dart';
import 'hidden_parameters.dart';
import 'language_skill.dart';
import 'personality_traits.dart';
import 'programming_language.dart';
import 'tech_skill_levels.dart';
import 'work_style.dart';

/// A job applicant, as produced by `ApplicantGenerator`.
///
/// This models the state at the "application" step of the hiring flow
/// (求人 → 応募). It intentionally carries both résumé-visible fields and
/// [HiddenParameters] the UI is not meant to reveal yet — see the Phase 0
/// design doc for the full rationale.
class Applicant {
  final String id;
  final ApplicantType type;

  // --- Basic profile ---
  final String name;
  final int age;
  final String nationality;
  final Education education;
  final Major major;
  final int totalItExperienceMonths;
  final int jobChangeCount;
  final int desiredMonthlySalary;
  final WorkStyle desiredWorkStyle;
  final int japaneseLevel; // 1-5
  final int englishLevel; // 1-5
  final List<String> qualifications;

  // --- Technical history ---
  /// One entry per [ProgrammingLanguage], including languages the applicant
  /// has zero experience with (experience/skill == 0).
  final Map<ProgrammingLanguage, LanguageSkill> languageSkills;
  final ProgrammingLanguage mainLanguage;
  final List<ProgrammingLanguage> subLanguages;
  final TechSkillLevels techSkills;

  // --- Person ---
  final PersonalityTraits personality;

  // --- Hidden ---
  final HiddenParameters hidden;

  const Applicant({
    required this.id,
    required this.type,
    required this.name,
    required this.age,
    required this.nationality,
    required this.education,
    required this.major,
    required this.totalItExperienceMonths,
    required this.jobChangeCount,
    required this.desiredMonthlySalary,
    required this.desiredWorkStyle,
    required this.japaneseLevel,
    required this.englishLevel,
    required this.qualifications,
    required this.languageSkills,
    required this.mainLanguage,
    required this.subLanguages,
    required this.techSkills,
    required this.personality,
    required this.hidden,
  }) : assert(japaneseLevel >= 1 && japaneseLevel <= 5),
       assert(englishLevel >= 1 && englishLevel <= 5);

  LanguageSkill skillFor(ProgrammingLanguage language) =>
      languageSkills[language] ??
      LanguageSkill(
        language: language,
        displayedExperienceMonths: 0,
        actualExperienceMonths: 0,
        actualSkill: 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.jsonValue,
    'name': name,
    'age': age,
    'nationality': nationality,
    'education': education.jsonValue,
    'major': major.jsonValue,
    'totalItExperienceMonths': totalItExperienceMonths,
    'jobChangeCount': jobChangeCount,
    'desiredMonthlySalary': desiredMonthlySalary,
    'desiredWorkStyle': desiredWorkStyle.jsonValue,
    'japaneseLevel': japaneseLevel,
    'englishLevel': englishLevel,
    'qualifications': qualifications,
    'languageSkills': languageSkills.map(
      (key, value) => MapEntry(key.jsonValue, value.toJson()),
    ),
    'mainLanguage': mainLanguage.jsonValue,
    'subLanguages': subLanguages.map((e) => e.jsonValue).toList(),
    'techSkills': techSkills.toJson(),
    'personality': personality.toJson(),
    'hidden': hidden.toJson(),
  };

  factory Applicant.fromJson(Map<String, dynamic> json) {
    return Applicant(
      id: json['id'] as String,
      type: ApplicantType.fromJson(json['type'] as String),
      name: json['name'] as String,
      age: json['age'] as int,
      nationality: json['nationality'] as String,
      education: Education.fromJson(json['education'] as String),
      major: Major.fromJson(json['major'] as String),
      totalItExperienceMonths: json['totalItExperienceMonths'] as int,
      jobChangeCount: json['jobChangeCount'] as int,
      desiredMonthlySalary: json['desiredMonthlySalary'] as int,
      desiredWorkStyle: WorkStyle.fromJson(json['desiredWorkStyle'] as String),
      japaneseLevel: json['japaneseLevel'] as int,
      englishLevel: json['englishLevel'] as int,
      qualifications: (json['qualifications'] as List).cast<String>(),
      languageSkills: (json['languageSkills'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          ProgrammingLanguage.fromJson(key),
          LanguageSkill.fromJson(value as Map<String, dynamic>),
        ),
      ),
      mainLanguage: ProgrammingLanguage.fromJson(
        json['mainLanguage'] as String,
      ),
      subLanguages: (json['subLanguages'] as List)
          .map((e) => ProgrammingLanguage.fromJson(e as String))
          .toList(),
      techSkills: TechSkillLevels.fromJson(
        json['techSkills'] as Map<String, dynamic>,
      ),
      personality: PersonalityTraits.fromJson(
        json['personality'] as Map<String, dynamic>,
      ),
      hidden: HiddenParameters.fromJson(json['hidden'] as Map<String, dynamic>),
    );
  }

  @override
  String toString() => 'Applicant($id, $name, $type, age:$age)';
}
