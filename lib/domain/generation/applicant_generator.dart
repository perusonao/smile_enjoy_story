import 'dart:math';

import '../models/applicant.dart';
import '../models/applicant_type.dart';
import '../models/education.dart';
import '../models/hidden_parameters.dart';
import '../models/language_skill.dart';
import '../models/personality_traits.dart';
import '../models/programming_language.dart';
import '../models/tech_skill_levels.dart';
import 'applicant_distribution.dart';
import 'name_pool.dart';
import 'weighted_pick.dart';

/// Generates [Applicant]s per the Phase 0 design doc.
///
/// Deterministic: constructing two generators with the same [seed] and
/// calling [generate] the same number of times produces identical
/// applicants, in the same order. Never reads `DateTime.now()` or any other
/// non-deterministic source.
class ApplicantGenerator {
  final int seed;
  final Random _rng;
  int _sequence = 0;

  ApplicantGenerator({required this.seed}) : _rng = Random(seed);

  /// Generates [count] applicants in sequence.
  List<Applicant> generate(int count) {
    return List.generate(count, (_) => _generateOne());
  }

  Applicant _generateOne() {
    _sequence++;
    final id = 'applicant-$seed-$_sequence';

    final type = pickWeighted(applicantTypeWeights, _rng);
    final age = ageRangeByType[type]!.pick(_rng);
    final totalItExperienceMonths = _pickTotalItExperienceMonths(type, age);

    final mainLanguage = pickWeighted(languageWeightsByType[type]!, _rng);
    final subLanguageCount = pickWeighted(subLanguageCountWeights, _rng);
    final subLanguagePool = Map<ProgrammingLanguage, double>.from(
      languageWeightsByType[type]!,
    )..remove(mainLanguage);
    final subLanguages = pickWeightedDistinct(
      subLanguagePool,
      subLanguageCount,
      _rng,
    );

    final personality = _pickPersonality(type);

    final languageSkills = _buildLanguageSkills(
      mainLanguage: mainLanguage,
      subLanguages: subLanguages,
      totalItExperienceMonths: totalItExperienceMonths,
      dishonesty: personality.dishonesty,
    );

    final techSkills = _pickTechSkills(type);
    final hidden = _pickHiddenParameters();

    final desiredMonthlySalary = _pickSalary(
      type: type,
      mainLanguageActualSkill: languageSkills[mainLanguage]!.actualSkill,
      techSkills: techSkills,
      totalItExperienceMonths: totalItExperienceMonths,
    );

    final education = pickWeighted(educationWeights, _rng);
    final major =
        education == Education.university ||
            education == Education.graduateSchool
        ? pickWeighted(higherEducationMajorWeights, _rng)
        : Major.informationTechnology;

    return Applicant(
      id: id,
      type: type,
      name: _pickName(),
      age: age,
      nationality: nationalityPool[_rng.nextInt(nationalityPool.length)],
      education: education,
      major: major,
      totalItExperienceMonths: totalItExperienceMonths,
      jobChangeCount: jobChangeCountRange.pick(_rng),
      desiredMonthlySalary: desiredMonthlySalary,
      desiredWorkStyle: pickWeighted(workStyleWeights, _rng),
      japaneseLevel: pickWeighted(japaneseLevelDistribution, _rng),
      englishLevel: pickWeighted(englishLevelDistribution, _rng),
      qualifications: _pickQualifications(),
      languageSkills: languageSkills,
      mainLanguage: mainLanguage,
      subLanguages: subLanguages,
      techSkills: techSkills,
      personality: personality,
      hidden: hidden,
    );
  }

  int _pickTotalItExperienceMonths(ApplicantType type, int age) {
    final typeRange = itExperienceYearsRangeByType[type]!;
    final maxAllowedMonths = (age - itExperienceStartAge) * 12;
    final minMonths = typeRange.min * 12;
    final maxMonths = min(typeRange.max * 12, maxAllowedMonths);
    final clampedMinMonths = min(minMonths, maxMonths);
    if (clampedMinMonths >= maxMonths) return maxMonths;
    return clampedMinMonths + _rng.nextInt(maxMonths - clampedMinMonths + 1);
  }

  PersonalityTraits _pickPersonality(ApplicantType type) {
    int trait(String name) {
      final overrides = personalityOverridesByType[type]?[name];
      return pickWeighted(overrides ?? basePersonalityDistribution, _rng);
    }

    return PersonalityTraits(
      looks: trait('looks'),
      cleanliness: trait('cleanliness'),
      communication: trait('communication'),
      alcoholTolerance: trait('alcoholTolerance'),
      seriousness: trait('seriousness'),
      dishonesty: trait('dishonesty'),
    );
  }

  Map<ProgrammingLanguage, LanguageSkill> _buildLanguageSkills({
    required ProgrammingLanguage mainLanguage,
    required List<ProgrammingLanguage> subLanguages,
    required int totalItExperienceMonths,
    required int dishonesty,
  }) {
    final result = <ProgrammingLanguage, LanguageSkill>{};
    for (final language in ProgrammingLanguage.values) {
      int actualMonths;
      if (language == mainLanguage) {
        final pct = mainLanguageExperiencePercentRange.pick(_rng);
        actualMonths = (totalItExperienceMonths * pct / 100).round();
      } else if (subLanguages.contains(language)) {
        final pct = subLanguageExperiencePercentRange.pick(_rng);
        actualMonths = (totalItExperienceMonths * pct / 100).round();
      } else {
        actualMonths = 0;
      }
      actualMonths = actualMonths.clamp(0, totalItExperienceMonths);

      var displayedMonths = actualMonths;
      if (actualMonths > 0) {
        final inflationChance =
            dishonestyInflationChanceByLevel[dishonesty] ?? 0;
        if (_rng.nextDouble() < inflationChance) {
          final inflationPct = dishonestyInflationPercentRange.pick(_rng);
          displayedMonths = (actualMonths * inflationPct / 100).round();
        }
      }
      // Never let a padded résumé exceed the applicant's declared total IT
      // experience, and never display less than the true experience.
      displayedMonths = displayedMonths.clamp(
        actualMonths,
        totalItExperienceMonths,
      );

      result[language] = LanguageSkill(
        language: language,
        displayedExperienceMonths: displayedMonths,
        actualExperienceMonths: actualMonths,
        actualSkill: _computeActualSkill(actualMonths),
      );
    }
    return result;
  }

  int _computeActualSkill(int actualExperienceMonths) {
    final years = actualExperienceMonths / 12.0;
    final base = actualSkillBase + years * actualSkillExperienceYearMultiplier;
    final variance = actualSkillVarianceRange.pick(_rng);
    return (base + variance).round().clamp(0, 100);
  }

  TechSkillLevels _pickTechSkills(ApplicantType type) {
    final ranges = techSkillRangesByType[type]!;
    return TechSkillLevels(
      database: ranges.database.pick(_rng),
      network: ranges.network.pick(_rng),
      infrastructure: ranges.infrastructure.pick(_rng),
      frontend: ranges.frontend.pick(_rng),
      backend: ranges.backend.pick(_rng),
      leader: ranges.leader.pick(_rng),
      manager: ranges.manager.pick(_rng),
    );
  }

  HiddenParameters _pickHiddenParameters() {
    final retention = pickWeighted(basePersonalityDistribution, _rng);
    // Turnover intent skews lower for high-retention applicants and higher
    // for low-retention ones, without ever losing its 0-100 range.
    final baseTurnover = _rng.nextInt(101);
    final turnoverIntent = (baseTurnover - (retention - 3) * 10).clamp(0, 100);

    return HiddenParameters(
      growthPotential: pickWeighted(basePersonalityDistribution, _rng),
      stressTolerance: pickWeighted(basePersonalityDistribution, _rng),
      retention: retention,
      projectInterviewSkill: pickWeighted(basePersonalityDistribution, _rng),
      turnoverIntent: turnoverIntent,
    );
  }

  int _pickSalary({
    required ApplicantType type,
    required int mainLanguageActualSkill,
    required TechSkillLevels techSkills,
    required int totalItExperienceMonths,
  }) {
    final range = salaryRangeByType[type]!;
    final typeExpMaxMonths = itExperienceYearsRangeByType[type]!.max * 12;

    final skillFactor = mainLanguageActualSkill / 100.0;
    final techAvg =
        (techSkills.database +
            techSkills.network +
            techSkills.infrastructure +
            techSkills.frontend +
            techSkills.backend +
            techSkills.leader +
            techSkills.manager) /
        7.0 /
        5.0;
    final expFactor = (totalItExperienceMonths / typeExpMaxMonths).clamp(
      0.0,
      1.0,
    );

    var abilityFactor = skillFactor * 0.5 + techAvg * 0.3 + expFactor * 0.2;
    final noise = _rng.nextDouble() * 0.3 - 0.15;
    abilityFactor = (abilityFactor + noise).clamp(0.0, 1.0);

    var salary = range.min + ((range.max - range.min) * abilityFactor).round();

    if (_rng.nextDouble() < bargainApplicantChance) {
      final discountPct = bargainDiscountPercentRange.pick(_rng);
      salary = (salary * (100 - discountPct) / 100).round();
    }

    salary = max(salary, 50000);
    return (salary / 1000).round() * 1000;
  }

  List<String> _pickQualifications() {
    final count = qualificationCountRange.pick(_rng);
    if (count == 0) return const [];
    final pool = List<String>.from(qualificationPool)..shuffle(_rng);
    return pool.take(count).toList();
  }

  String _pickName() {
    final surname = surnamePool[_rng.nextInt(surnamePool.length)];
    final given = givenNamePool[_rng.nextInt(givenNamePool.length)];
    return '$surname $given';
  }
}
