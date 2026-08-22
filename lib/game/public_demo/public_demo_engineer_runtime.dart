import '../../domain/models/career_history_entry.dart';
import '../../domain/models/hidden_parameters.dart';
import '../../domain/models/language_skill.dart';
import '../../domain/models/programming_language.dart';
import '../../domain/models/sales_profile.dart';
import '../../domain/models/tech_skill_levels.dart';

/// Ground-truth, growth-ready capability owned by one Public Demo employee.
///
/// This deliberately does not contain SkillSheet/sales values. EG-2 can update
/// this object from assignment, waiting, or training without mutating project
/// state or the sales-facing representation.
class PublicDemoEngineerRuntime {
  const PublicDemoEngineerRuntime({
    required this.engineerId,
    required this.primaryLanguage,
    required this.languageSkills,
    required this.techSkills,
    required this.hidden,
    this.abilities = const {},
    this.industryExperience = const {},
    this.careerHistory = const [],
  });

  final String engineerId;
  final ProgrammingLanguage primaryLanguage;
  final Map<ProgrammingLanguage, LanguageSkill> languageSkills;
  final TechSkillLevels techSkills;
  final HiddenParameters hidden;
  final Set<EmployeeAbility> abilities;
  final Map<Industry, int> industryExperience;
  final List<CareerHistoryEntry> careerHistory;

  /// Compatibility score for Public Demo 0.1's existing project evaluation.
  /// It is derived from actual capability, never copied onto an assignment.
  int get actualCapability => languageSkills[primaryLanguage]?.actualSkill ?? 0;

  Map<String, dynamic> toJson() => {
    'engineerId': engineerId,
    'primaryLanguage': primaryLanguage.jsonValue,
    'languageSkills': languageSkills.map(
      (language, skill) => MapEntry(language.jsonValue, skill.toJson()),
    ),
    'techSkills': techSkills.toJson(),
    'hidden': hidden.toJson(),
    'abilities': abilities.map((ability) => ability.name).toList(),
    'industryExperience': industryExperience.map(
      (industry, months) => MapEntry(industry.name, months),
    ),
    'careerHistory': careerHistory.map((entry) => entry.toJson()).toList(),
  };

  factory PublicDemoEngineerRuntime.fromJson(Map<String, dynamic> json) {
    return PublicDemoEngineerRuntime(
      engineerId: json['engineerId'] as String,
      primaryLanguage: ProgrammingLanguage.fromJson(
        json['primaryLanguage'] as String,
      ),
      languageSkills: (json['languageSkills'] as Map<String, dynamic>).map(
        (language, skill) => MapEntry(
          ProgrammingLanguage.fromJson(language),
          LanguageSkill.fromJson(skill as Map<String, dynamic>),
        ),
      ),
      techSkills: TechSkillLevels.fromJson(
        json['techSkills'] as Map<String, dynamic>,
      ),
      hidden: HiddenParameters.fromJson(json['hidden'] as Map<String, dynamic>),
      abilities: (json['abilities'] as List? ?? const [])
          .map((ability) => EmployeeAbility.values.byName(ability as String))
          .toSet(),
      industryExperience:
          (json['industryExperience'] as Map<String, dynamic>? ?? {}).map(
            (industry, months) =>
                MapEntry(Industry.values.byName(industry), months as int),
          ),
      careerHistory: (json['careerHistory'] as List? ?? const [])
          .map(
            (entry) =>
                CareerHistoryEntry.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// Deterministic migration defaults for saves created before EG-1.
///
/// The values intentionally reproduce the former assignment scores; no
/// balance or SkillSheet representation changes merely because a save loads.
const publicDemoInitialEngineerRuntimes = <PublicDemoEngineerRuntime>[
  PublicDemoEngineerRuntime(
    engineerId: 'eng-01',
    primaryLanguage: ProgrammingLanguage.java,
    languageSkills: {
      ProgrammingLanguage.java: LanguageSkill(
        language: ProgrammingLanguage.java,
        displayedExperienceMonths: 36,
        actualExperienceMonths: 36,
        actualSkill: 78,
      ),
    },
    techSkills: TechSkillLevels(
      database: 3,
      network: 1,
      infrastructure: 1,
      frontend: 1,
      backend: 3,
      leader: 1,
      manager: 0,
    ),
    hidden: HiddenParameters(
      growthPotential: 3,
      stressTolerance: 3,
      retention: 3,
      projectInterviewSkill: 3,
      turnoverIntent: 50,
    ),
  ),
  PublicDemoEngineerRuntime(
    engineerId: 'eng-02',
    primaryLanguage: ProgrammingLanguage.javascript,
    languageSkills: {
      ProgrammingLanguage.javascript: LanguageSkill(
        language: ProgrammingLanguage.javascript,
        displayedExperienceMonths: 24,
        actualExperienceMonths: 24,
        actualSkill: 52,
      ),
    },
    techSkills: TechSkillLevels(
      database: 1,
      network: 1,
      infrastructure: 1,
      frontend: 3,
      backend: 1,
      leader: 0,
      manager: 0,
    ),
    hidden: HiddenParameters(
      growthPotential: 4,
      stressTolerance: 3,
      retention: 3,
      projectInterviewSkill: 3,
      turnoverIntent: 50,
    ),
  ),
];
