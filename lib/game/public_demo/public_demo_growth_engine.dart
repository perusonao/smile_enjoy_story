import '../../domain/models/language_skill.dart';
import '../../domain/models/programming_language.dart';
import '../../domain/models/sales_profile.dart';
import 'public_demo_engineer_runtime.dart';

/// The context in which an engineer develops during one future growth period.
///
/// EG-2 only computes results. Applying them during month-end is deliberately
/// deferred to EG-3.
enum PublicDemoGrowthSource {
  assignment,
  waiting,
  internalTraining,
  externalTraining,
}

/// A domain-level target that presentation can translate without owning the
/// growth rules themselves.
enum PublicDemoGrowthTarget { primaryLanguage, industryExperience }

class PublicDemoGrowthRequest {
  const PublicDemoGrowthRequest({
    required this.source,
    required this.morale,
    this.industry,
  }) : assert(morale >= 0 && morale <= 100);

  final PublicDemoGrowthSource source;
  final int morale;
  final Industry? industry;
}

class PublicDemoGrowthChange {
  const PublicDemoGrowthChange({
    required this.target,
    required this.before,
    required this.after,
    this.language,
    this.industry,
  });

  final PublicDemoGrowthTarget target;
  final int before;
  final int after;
  final ProgrammingLanguage? language;
  final Industry? industry;
  int get delta => after - before;
}

/// A deterministic, structured calculation that EG-3 can later apply.
class PublicDemoGrowthResult {
  const PublicDemoGrowthResult({
    required this.engineerId,
    required this.source,
    required this.before,
    required this.after,
    required this.capabilityChange,
    required this.actualExperienceMonthsDelta,
    required this.industryExperienceMonthsDelta,
    required this.changes,
  });

  final String engineerId;
  final PublicDemoGrowthSource source;
  final PublicDemoEngineerRuntime before;
  final PublicDemoEngineerRuntime after;
  final PublicDemoGrowthChange capabilityChange;
  final int actualExperienceMonthsDelta;
  final int industryExperienceMonthsDelta;
  final List<PublicDemoGrowthChange> changes;
}

/// Pure growth calculator for Public Demo engineer runtime data.
///
/// No Company Trust or sales-facing SkillSheet value participates here. The
/// absence of a random input is intentional: each calculation is reproducible
/// from its request and runtime alone.
class PublicDemoGrowthEngine {
  const PublicDemoGrowthEngine._();

  static PublicDemoGrowthResult calculate(
    PublicDemoEngineerRuntime runtime,
    PublicDemoGrowthRequest request,
  ) {
    final language = runtime.primaryLanguage;
    final beforeSkill = runtime.languageSkills[language]?.actualSkill ?? 0;
    final delta = _capabilityDelta(runtime, request, beforeSkill);
    final afterSkill = (beforeSkill + delta).clamp(0, 100);
    final practicalExperience =
        request.source == PublicDemoGrowthSource.assignment ? 1 : 0;
    final industryExperience =
        practicalExperience > 0 && request.industry != null ? 1 : 0;
    final languageBefore =
        runtime.languageSkills[language] ??
        LanguageSkill(
          language: language,
          displayedExperienceMonths: 0,
          actualExperienceMonths: 0,
          actualSkill: 0,
        );
    final languageAfter = languageBefore.copyWith(
      // SkillSheet-facing displayed experience intentionally remains intact.
      actualExperienceMonths:
          languageBefore.actualExperienceMonths + practicalExperience,
      actualSkill: afterSkill,
    );
    final updatedLanguages = {
      ...runtime.languageSkills,
      language: languageAfter,
    };
    final updatedIndustries = {...runtime.industryExperience};
    if (industryExperience > 0) {
      updatedIndustries[request.industry!] =
          (updatedIndustries[request.industry!] ?? 0) + industryExperience;
    }
    final after = runtime.copyWith(
      languageSkills: updatedLanguages,
      industryExperience: updatedIndustries,
    );
    final capabilityChange = PublicDemoGrowthChange(
      target: PublicDemoGrowthTarget.primaryLanguage,
      language: language,
      before: beforeSkill,
      after: afterSkill,
    );
    final changes = <PublicDemoGrowthChange>[capabilityChange];
    if (request.industry != null) {
      final before = runtime.industryExperience[request.industry!] ?? 0;
      changes.add(
        PublicDemoGrowthChange(
          target: PublicDemoGrowthTarget.industryExperience,
          industry: request.industry,
          before: before,
          after: before + industryExperience,
        ),
      );
    }
    return PublicDemoGrowthResult(
      engineerId: runtime.engineerId,
      source: request.source,
      before: runtime,
      after: after,
      capabilityChange: capabilityChange,
      actualExperienceMonthsDelta: practicalExperience,
      industryExperienceMonthsDelta: industryExperience,
      changes: changes,
    );
  }

  static int _capabilityDelta(
    PublicDemoEngineerRuntime runtime,
    PublicDemoGrowthRequest request,
    int skill,
  ) {
    final sourceBase = switch (request.source) {
      PublicDemoGrowthSource.assignment => 2.0,
      PublicDemoGrowthSource.waiting => 0.45,
      PublicDemoGrowthSource.internalTraining => 1.2,
      PublicDemoGrowthSource.externalTraining => 1.4,
    };
    final potentialMultiplier = 0.70 + runtime.hidden.growthPotential * 0.15;
    final fastLearnerMultiplier =
        runtime.abilities.contains(EmployeeAbility.fastLearner) ? 1.20 : 1.0;
    final moraleMultiplier = request.morale < 30
        ? 0.75
        : request.morale > 75
        ? 1.10
        : 1.0;
    final diminishingMultiplier = skill >= 85
        ? 0.30
        : skill >= 70
        ? 0.65
        : 1.0;
    return (sourceBase *
            potentialMultiplier *
            fastLearnerMultiplier *
            moraleMultiplier *
            diminishingMultiplier)
        .floor()
        .clamp(0, 100 - skill);
  }
}
