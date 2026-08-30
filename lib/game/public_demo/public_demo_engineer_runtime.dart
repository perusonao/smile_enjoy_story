import '../../domain/models/career_history_entry.dart';
import '../../domain/models/hidden_parameters.dart';
import '../../domain/models/language_skill.dart';
import '../../domain/models/programming_language.dart';
import '../../domain/models/sales_profile.dart';
import '../../domain/models/tech_skill_levels.dart';
import 'public_demo_recruitment.dart';

/// Ground-truth, growth-ready capability owned by one Public Demo employee.
///
/// This deliberately does not contain SkillSheet/sales values. EG-2 can update
/// this object from assignment, waiting, or training without mutating project
/// state or the sales-facing representation.
class PublicDemoEngineerRuntime {
  /// Minimum current capability required to enter the Public Demo field-sales
  /// flow. Presentation may show this rule, but must not duplicate it.
  static const int fieldSalesCapabilityRequirement = 60;

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

  /// This is deliberately derived from the runtime capability, not persisted.
  bool get isReadyForFieldSales =>
      actualCapability >= fieldSalesCapabilityRequirement;

  /// Creates the single runtime representation used after a Public Demo hire
  /// joins. Experienced applicants retain the pre-JUNIOR-3 values exactly.
  factory PublicDemoEngineerRuntime.fromApplicant(
    PublicDemoApplicant applicant,
  ) {
    if (!applicant.isInexperienced) {
      return PublicDemoEngineerRuntime(
        engineerId: applicant.id,
        primaryLanguage: ProgrammingLanguage.java,
        languageSkills: {
          ProgrammingLanguage.java: LanguageSkill(
            language: ProgrammingLanguage.java,
            displayedExperienceMonths: 0,
            actualExperienceMonths: 0,
            actualSkill: applicant.salesSkillFit,
          ),
        },
        techSkills: const TechSkillLevels.zero(),
        hidden: const HiddenParameters(
          growthPotential: 3,
          stressTolerance: 3,
          retention: 3,
          projectInterviewSkill: 3,
          turnoverIntent: 50,
        ),
      );
    }

    final isPotentialTemplate = _usesPotentialTemplate(applicant);
    return PublicDemoEngineerRuntime(
      engineerId: applicant.id,
      primaryLanguage: ProgrammingLanguage.java,
      languageSkills: {
        ProgrammingLanguage.java: LanguageSkill(
          language: ProgrammingLanguage.java,
          displayedExperienceMonths: 0,
          actualExperienceMonths: 0,
          actualSkill: isPotentialTemplate ? 20 : 28,
        ),
      },
      techSkills: const TechSkillLevels.zero(),
      hidden: HiddenParameters(
        growthPotential: isPotentialTemplate ? 5 : 3,
        stressTolerance: 3,
        retention: 3,
        projectInterviewSkill: 3,
        turnoverIntent: 50,
      ),
      abilities: isPotentialTemplate ? {EmployeeAbility.fastLearner} : const {},
    );
  }

  /// Numeric applicant facts make this stable on both VM and web without
  /// coupling profiles to generated identifier text.
  static bool _usesPotentialTemplate(PublicDemoApplicant applicant) =>
      (applicant.interviewScore +
              applicant.acceptanceScore +
              applicant.salesSkillFit) %
          2 ==
      0;

  PublicDemoEngineerRuntime copyWith({
    ProgrammingLanguage? primaryLanguage,
    Map<ProgrammingLanguage, LanguageSkill>? languageSkills,
    TechSkillLevels? techSkills,
    HiddenParameters? hidden,
    Set<EmployeeAbility>? abilities,
    Map<Industry, int>? industryExperience,
    List<CareerHistoryEntry>? careerHistory,
  }) => PublicDemoEngineerRuntime(
    engineerId: engineerId,
    primaryLanguage: primaryLanguage ?? this.primaryLanguage,
    languageSkills: languageSkills ?? this.languageSkills,
    techSkills: techSkills ?? this.techSkills,
    hidden: hidden ?? this.hidden,
    abilities: abilities ?? this.abilities,
    industryExperience: industryExperience ?? this.industryExperience,
    careerHistory: careerHistory ?? this.careerHistory,
  );

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
