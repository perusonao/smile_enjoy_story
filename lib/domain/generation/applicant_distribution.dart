/// Tunable constants for [ApplicantGenerator].
///
/// Everything that shapes the "feel" of generated applicants lives here as
/// data so it can be rebalanced without touching generator logic. See the
/// Phase 0 design doc for the source of each table.
library;

import '../models/applicant_type.dart';
import '../models/education.dart';
import '../models/programming_language.dart';
import '../models/work_style.dart';
import 'int_range.dart';

/// Occurrence weights for [ApplicantType]. Do not need to sum to 1 (the
/// generator normalizes), but are written as percentages for readability.
const Map<ApplicantType, double> applicantTypeWeights = {
  ApplicantType.juniorProgrammer: 0.25,
  ApplicantType.midLevelEngineer: 0.30,
  ApplicantType.seniorEngineer: 0.15,
  ApplicantType.frontendSpecialist: 0.10,
  ApplicantType.infrastructureSpecialist: 0.10,
  ApplicantType.plCandidate: 0.10,
};

/// Age range (inclusive, in years) per [ApplicantType].
const Map<ApplicantType, IntRange> ageRangeByType = {
  ApplicantType.juniorProgrammer: IntRange(22, 28),
  ApplicantType.midLevelEngineer: IntRange(26, 35),
  ApplicantType.seniorEngineer: IntRange(32, 45),
  ApplicantType.frontendSpecialist: IntRange(24, 36),
  ApplicantType.infrastructureSpecialist: IntRange(25, 40),
  ApplicantType.plCandidate: IntRange(30, 45),
};

/// Total IT experience range (inclusive, in years) per [ApplicantType],
/// before the `experience <= age - 20` clamp is applied.
const Map<ApplicantType, IntRange> itExperienceYearsRangeByType = {
  ApplicantType.juniorProgrammer: IntRange(1, 3),
  ApplicantType.midLevelEngineer: IntRange(3, 7),
  ApplicantType.seniorEngineer: IntRange(7, 15),
  ApplicantType.frontendSpecialist: IntRange(2, 8),
  ApplicantType.infrastructureSpecialist: IntRange(2, 10),
  ApplicantType.plCandidate: IntRange(6, 15),
};

/// Minimum age used to derive the "cannot have more IT experience than
/// years-since-this-age" rule (`totalItExperienceMonths <= (age - 20) * 12`).
const int itExperienceStartAge = 20;

/// Main-language occurrence weights per [ApplicantType]. Each inner map
/// should sum to ~1.0 (percentages), though [pickWeighted] normalizes
/// regardless.
const Map<ApplicantType, Map<ProgrammingLanguage, double>>
languageWeightsByType = {
  ApplicantType.juniorProgrammer: {
    ProgrammingLanguage.java: 0.30,
    ProgrammingLanguage.csharp: 0.15,
    ProgrammingLanguage.php: 0.15,
    ProgrammingLanguage.python: 0.15,
    ProgrammingLanguage.javascript: 0.15,
    ProgrammingLanguage.typescript: 0.10,
  },
  ApplicantType.midLevelEngineer: {
    ProgrammingLanguage.java: 0.35,
    ProgrammingLanguage.csharp: 0.20,
    ProgrammingLanguage.php: 0.15,
    ProgrammingLanguage.python: 0.15,
    ProgrammingLanguage.javascript: 0.10,
    ProgrammingLanguage.typescript: 0.05,
  },
  ApplicantType.seniorEngineer: {
    ProgrammingLanguage.java: 0.30,
    ProgrammingLanguage.csharp: 0.20,
    ProgrammingLanguage.php: 0.10,
    ProgrammingLanguage.python: 0.15,
    ProgrammingLanguage.javascript: 0.15,
    ProgrammingLanguage.typescript: 0.10,
  },
  ApplicantType.frontendSpecialist: {
    ProgrammingLanguage.javascript: 0.45,
    ProgrammingLanguage.typescript: 0.45,
    ProgrammingLanguage.java: 0.025,
    ProgrammingLanguage.csharp: 0.025,
    ProgrammingLanguage.php: 0.025,
    ProgrammingLanguage.python: 0.025,
  },
  ApplicantType.infrastructureSpecialist: {
    // Python is deliberately boosted relative to the other backend
    // languages per the Phase 0 design doc, section 7.
    ProgrammingLanguage.python: 0.30,
    ProgrammingLanguage.java: 0.20,
    ProgrammingLanguage.csharp: 0.10,
    ProgrammingLanguage.php: 0.10,
    ProgrammingLanguage.javascript: 0.15,
    ProgrammingLanguage.typescript: 0.15,
  },
  ApplicantType.plCandidate: {
    ProgrammingLanguage.java: 0.35,
    ProgrammingLanguage.csharp: 0.20,
    ProgrammingLanguage.php: 0.10,
    ProgrammingLanguage.python: 0.15,
    ProgrammingLanguage.javascript: 0.10,
    ProgrammingLanguage.typescript: 0.10,
  },
};

/// How many sub-languages (0-2) an applicant tends to have.
const Map<int, double> subLanguageCountWeights = {0: 0.30, 1: 0.45, 2: 0.25};

/// Main-language experience as a fraction of total IT experience.
const IntRange mainLanguageExperiencePercentRange = IntRange(50, 100);

/// Sub-language experience as a fraction of total IT experience.
const IntRange subLanguageExperiencePercentRange = IntRange(10, 60);

/// Technical domain skill (0-5) ranges per [ApplicantType].
class TechSkillRangeSet {
  final IntRange database;
  final IntRange network;
  final IntRange infrastructure;
  final IntRange frontend;
  final IntRange backend;
  final IntRange leader;
  final IntRange manager;

  const TechSkillRangeSet({
    required this.database,
    required this.network,
    required this.infrastructure,
    required this.frontend,
    required this.backend,
    required this.leader,
    required this.manager,
  });
}

const Map<ApplicantType, TechSkillRangeSet> techSkillRangesByType = {
  ApplicantType.juniorProgrammer: TechSkillRangeSet(
    database: IntRange(1, 3),
    network: IntRange(0, 2),
    infrastructure: IntRange(0, 2),
    frontend: IntRange(0, 3),
    backend: IntRange(1, 3),
    leader: IntRange(0, 1),
    manager: IntRange(0, 0),
  ),
  ApplicantType.midLevelEngineer: TechSkillRangeSet(
    database: IntRange(2, 4),
    network: IntRange(0, 3),
    infrastructure: IntRange(0, 3),
    frontend: IntRange(0, 4),
    backend: IntRange(2, 4),
    leader: IntRange(0, 3),
    manager: IntRange(0, 1),
  ),
  ApplicantType.seniorEngineer: TechSkillRangeSet(
    database: IntRange(3, 5),
    network: IntRange(1, 4),
    infrastructure: IntRange(1, 4),
    frontend: IntRange(1, 4),
    backend: IntRange(3, 5),
    leader: IntRange(1, 4),
    manager: IntRange(0, 3),
  ),
  ApplicantType.frontendSpecialist: TechSkillRangeSet(
    database: IntRange(1, 3),
    network: IntRange(0, 2),
    infrastructure: IntRange(0, 1),
    frontend: IntRange(4, 5),
    backend: IntRange(0, 3),
    leader: IntRange(0, 2),
    manager: IntRange(0, 1),
  ),
  ApplicantType.infrastructureSpecialist: TechSkillRangeSet(
    database: IntRange(1, 3),
    network: IntRange(3, 5),
    infrastructure: IntRange(4, 5),
    frontend: IntRange(0, 1),
    backend: IntRange(0, 2),
    leader: IntRange(0, 2),
    manager: IntRange(0, 1),
  ),
  ApplicantType.plCandidate: TechSkillRangeSet(
    database: IntRange(2, 4),
    network: IntRange(1, 3),
    infrastructure: IntRange(1, 3),
    frontend: IntRange(1, 3),
    backend: IntRange(2, 4),
    leader: IntRange(3, 5),
    manager: IntRange(1, 3),
  ),
};

/// Base 1-5 ability distribution shared by all [ApplicantType]s unless
/// overridden below.
const Map<int, double> basePersonalityDistribution = {
  1: 0.10,
  2: 0.20,
  3: 0.40,
  4: 0.20,
  5: 0.10,
};

/// Per-type overrides for specific traits, keyed by the field name used in
/// [PersonalityTraits] (e.g. `'communication'`). A type/trait combination not
/// present here uses [basePersonalityDistribution].
const Map<ApplicantType, Map<String, Map<int, double>>>
personalityOverridesByType = {
  ApplicantType.plCandidate: {
    'communication': {1: 0.02, 2: 0.08, 3: 0.35, 4: 0.35, 5: 0.20},
  },
};

/// Desired monthly salary range (JPY) per [ApplicantType].
const Map<ApplicantType, IntRange> salaryRangeByType = {
  ApplicantType.juniorProgrammer: IntRange(250000, 350000),
  ApplicantType.midLevelEngineer: IntRange(320000, 450000),
  ApplicantType.seniorEngineer: IntRange(400000, 600000),
  ApplicantType.frontendSpecialist: IntRange(300000, 500000),
  ApplicantType.infrastructureSpecialist: IntRange(320000, 500000),
  ApplicantType.plCandidate: IntRange(450000, 650000),
};

/// Chance that a "bargain" applicant is generated: desired salary is
/// discounted relative to their ability.
const double bargainApplicantChance = 0.075; // 7.5%, within the 5-10% target

/// How much a bargain applicant's salary is discounted by.
const IntRange bargainDiscountPercentRange = IntRange(15, 30);

/// Chance (by [PersonalityTraits.dishonesty] level 1-5) that a given
/// language's résumé experience is inflated above its true experience.
const Map<int, double> dishonestyInflationChanceByLevel = {
  1: 0.02,
  2: 0.10,
  3: 0.25,
  4: 0.45,
  5: 0.65,
};

/// How much a padded résumé inflates true experience by, as a multiplier.
const IntRange dishonestyInflationPercentRange = IntRange(
  120,
  220,
); // x1.2-x2.2

/// actualSkill = 30 + experienceYears * [actualSkillExperienceYearMultiplier],
/// plus individual variance in [actualSkillVarianceRange], clamped 0-100.
const int actualSkillBase = 30;
const int actualSkillExperienceYearMultiplier = 6;
const IntRange actualSkillVarianceRange = IntRange(-20, 20);

/// Pool of nationalities used for flavor only — never used to bias ability.
const List<String> nationalityPool = [
  '日本',
  'ベトナム',
  '中国',
  'インド',
  'フィリピン',
  'ネパール',
  '韓国',
  'ミャンマー',
  'インドネシア',
  'ブラジル',
];

/// Pool of light-weight qualifications an applicant may list.
const List<String> qualificationPool = [
  '基本情報技術者',
  '応用情報技術者',
  'AWS認定ソリューションアーキテクト',
  'Oracle Java Silver',
  'Oracle Java Gold',
  'LPIC-1',
  'LPIC-2',
  '簿記3級',
  'TOEIC 600',
  'TOEIC 800',
  '普通自動車免許',
];

const IntRange qualificationCountRange = IntRange(0, 2);

const IntRange jobChangeCountRange = IntRange(0, 4);

/// Japanese/English proficiency (1-5) distributions. Deliberately *not*
/// derived from [nationalityPool] — nationality is flavor-only, see the
/// Phase 0 design doc, section 13.
const Map<int, double> japaneseLevelDistribution = {
  1: 0.05,
  2: 0.10,
  3: 0.25,
  4: 0.35,
  5: 0.25,
};
const Map<int, double> englishLevelDistribution = {
  1: 0.25,
  2: 0.30,
  3: 0.25,
  4: 0.15,
  5: 0.05,
};

const Map<Education, double> educationWeights = {
  Education.highSchool: 0.10,
  Education.vocationalSchool: 0.25,
  Education.technicalCollege: 0.15,
  Education.university: 0.40,
  Education.graduateSchool: 0.10,
};

/// Major weights used for higher-ed (`university`/`graduateSchool`)
/// applicants. `highSchool`/`vocationalSchool`/`technicalCollege` applicants
/// are always assigned [Major.informationTechnology] to avoid unnatural
/// combinations (e.g. a high-school-only "humanities major").
const Map<Major, double> higherEducationMajorWeights = {
  Major.informationTechnology: 0.50,
  Major.scienceEngineering: 0.25,
  Major.humanities: 0.15,
  Major.other: 0.10,
};

const Map<WorkStyle, double> workStyleWeights = {
  WorkStyle.onsite: 0.30,
  WorkStyle.hybrid: 0.45,
  WorkStyle.fullRemote: 0.25,
};
