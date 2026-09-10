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
      // Codex P2 fix (PR #212): CORE-GAMEPLAY Phase 5's Matching reads
      // totalItExperienceMonths directly (never re-derives it from
      // languageSkills), so it must advance here too, by the exact same
      // practicalExperience delta already applied to the primary
      // language's own actualExperienceMonths above — otherwise an
      // engineer's total IT experience would freeze at hire time even as
      // they keep gaining real (assignment) experience, and Matching would
      // never reflect months actually worked.
      totalItExperienceMonths:
          runtime.totalItExperienceMonths + practicalExperience,
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
      // Issue #223 (FIRST-FUN-YEAR Seeded Balance Fix) Fresh Audit tuning:
      // raised 1.2 -> 2.0. At 1.2, `floor()` below capped EVERY engineer's
      // internal-training gain at +1 capability/month regardless of
      // [HiddenParameters.growthPotential] (even Suzuki's own
      // growthPotential:4 only reached 1.2*1.3=1.56, still floor 1) — Suzuki
      // needed 8 straight monthly purchases (¥240,000, ~8 of the fiscal
      // year's 12 months) to cross the 52->60 field-sales bar, consuming
      // nearly this Issue's entire measured cash slack even in the
      // Conservative (never-hire) baseline and leaving zero room for any
      // other decision — training was a mandatory multi-month tax, not the
      // "弱い社員を戦力化する選択肢" the design intends. At 2.0, a
      // representative mid/high-potential engineer now gains +2/month
      // (e.g. growthPotential:4 -> 2.0*1.3=2.6 -> floor 2), roughly halving
      // that dead-weight window; a low-potential hire still only gains +1,
      // so training remains a real, uneven trade-off rather than a
      // guaranteed fast fix. See the Result report's tuning-rationale
      // section for the full before/after seed comparison.
      PublicDemoGrowthSource.internalTraining => 2.0,
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
