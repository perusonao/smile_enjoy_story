/// Tunable constants for [ProjectGenerator]. See the Phase 0 design doc for
/// the source of each table.
library;

import '../models/programming_language.dart';
import '../models/project_rank.dart';
import '../models/project_type.dart';
import 'int_range.dart';

/// Base occurrence weights for [ProjectType]. A [Client] can bias this via
/// `Client.projectTypeWeights`.
const Map<ProjectType, double> projectTypeWeights = {
  ProjectType.javaBusiness: 0.30,
  ProjectType.webBackend: 0.20,
  ProjectType.frontend: 0.15,
  ProjectType.infrastructure: 0.15,
  ProjectType.testSupport: 0.10,
  ProjectType.pl: 0.10,
};

/// Base monthly rate range (JPY) per [ProjectRank].
const Map<ProjectRank, IntRange> monthlyRateRangeByRank = {
  ProjectRank.entry: IntRange(450000, 550000),
  ProjectRank.junior: IntRange(550000, 650000),
  ProjectRank.middle: IntRange(650000, 800000),
  ProjectRank.senior: IntRange(800000, 950000),
  ProjectRank.lead: IntRange(900000, 1100000),
};

/// Rank order used for "bump" calculations (higher index = more senior).
const List<ProjectRank> projectRankOrder = [
  ProjectRank.entry,
  ProjectRank.junior,
  ProjectRank.middle,
  ProjectRank.senior,
  ProjectRank.lead,
];

/// Rank occurrence weights per [ProjectType]. `testSupport` skews toward
/// entry/junior (low difficulty per the design doc); `pl` skews senior/lead.
const Map<ProjectType, Map<ProjectRank, double>> rankWeightsByProjectType = {
  ProjectType.javaBusiness: {
    ProjectRank.entry: 0.10,
    ProjectRank.junior: 0.30,
    ProjectRank.middle: 0.35,
    ProjectRank.senior: 0.20,
    ProjectRank.lead: 0.05,
  },
  ProjectType.webBackend: {
    ProjectRank.entry: 0.15,
    ProjectRank.junior: 0.30,
    ProjectRank.middle: 0.30,
    ProjectRank.senior: 0.20,
    ProjectRank.lead: 0.05,
  },
  ProjectType.frontend: {
    ProjectRank.entry: 0.15,
    ProjectRank.junior: 0.30,
    ProjectRank.middle: 0.30,
    ProjectRank.senior: 0.20,
    ProjectRank.lead: 0.05,
  },
  ProjectType.infrastructure: {
    ProjectRank.entry: 0.10,
    ProjectRank.junior: 0.25,
    ProjectRank.middle: 0.30,
    ProjectRank.senior: 0.25,
    ProjectRank.lead: 0.10,
  },
  ProjectType.testSupport: {
    ProjectRank.entry: 0.55,
    ProjectRank.junior: 0.35,
    ProjectRank.middle: 0.10,
  },
  ProjectType.pl: {
    ProjectRank.middle: 0.15,
    ProjectRank.senior: 0.45,
    ProjectRank.lead: 0.40,
  },
};

/// Duration (weeks) range per [ProjectType].
const Map<ProjectType, IntRange> durationWeeksRangeByProjectType = {
  ProjectType.javaBusiness: IntRange(12, 28),
  ProjectType.webBackend: IntRange(8, 24),
  ProjectType.frontend: IntRange(8, 20),
  ProjectType.infrastructure: IntRange(12, 30),
  ProjectType.testSupport: IntRange(4, 12),
  ProjectType.pl: IntRange(16, 36),
};

/// How many weeks out (from the generation base week) the application
/// deadline falls.
const IntRange applicationDeadlineWeeksOutRange = IntRange(1, 4);

/// Technical domain skill (0-5) requirement ranges per [ProjectType], before
/// the rank-based bump in [rankSkillBump] is applied.
class SkillRequirementRangeSet {
  final IntRange database;
  final IntRange network;
  final IntRange infrastructure;
  final IntRange frontend;
  final IntRange backend;
  final IntRange leader;
  final IntRange manager;

  const SkillRequirementRangeSet({
    required this.database,
    required this.network,
    required this.infrastructure,
    required this.frontend,
    required this.backend,
    required this.leader,
    required this.manager,
  });
}

const Map<ProjectType, SkillRequirementRangeSet>
baseSkillRequirementsByProjectType = {
  ProjectType.javaBusiness: SkillRequirementRangeSet(
    database: IntRange(1, 3),
    network: IntRange(0, 1),
    infrastructure: IntRange(0, 1),
    frontend: IntRange(0, 1),
    backend: IntRange(2, 4),
    leader: IntRange(0, 2),
    manager: IntRange(0, 0),
  ),
  ProjectType.webBackend: SkillRequirementRangeSet(
    database: IntRange(1, 3),
    network: IntRange(0, 1),
    infrastructure: IntRange(0, 1),
    frontend: IntRange(0, 2),
    backend: IntRange(2, 4),
    leader: IntRange(0, 2),
    manager: IntRange(0, 0),
  ),
  ProjectType.frontend: SkillRequirementRangeSet(
    database: IntRange(0, 1),
    network: IntRange(0, 0),
    infrastructure: IntRange(0, 0),
    frontend: IntRange(3, 5),
    backend: IntRange(0, 2),
    leader: IntRange(0, 1),
    manager: IntRange(0, 0),
  ),
  ProjectType.infrastructure: SkillRequirementRangeSet(
    database: IntRange(0, 2),
    network: IntRange(2, 4),
    infrastructure: IntRange(3, 5),
    frontend: IntRange(0, 1),
    backend: IntRange(0, 1),
    leader: IntRange(0, 2),
    manager: IntRange(0, 0),
  ),
  ProjectType.testSupport: SkillRequirementRangeSet(
    database: IntRange(0, 1),
    network: IntRange(0, 0),
    infrastructure: IntRange(0, 0),
    frontend: IntRange(0, 1),
    backend: IntRange(0, 1),
    leader: IntRange(0, 0),
    manager: IntRange(0, 0),
  ),
  ProjectType.pl: SkillRequirementRangeSet(
    database: IntRange(1, 3),
    network: IntRange(0, 2),
    infrastructure: IntRange(0, 2),
    frontend: IntRange(0, 2),
    backend: IntRange(1, 3),
    leader: IntRange(2, 4),
    manager: IntRange(1, 3),
  ),
};

/// Added to both ends of each non-zero skill range as rank increases.
/// Fields whose base range is fixed at (0,0) for a project type are left
/// untouched regardless of rank, so e.g. a `frontend` project never
/// acquires an `infrastructure` requirement just because it's senior.
const Map<ProjectRank, int> rankSkillBump = {
  ProjectRank.entry: 0,
  ProjectRank.junior: 0,
  ProjectRank.middle: 1,
  ProjectRank.senior: 1,
  ProjectRank.lead: 2,
};

const IntRange requiredJapaneseLevelBaseRange = IntRange(2, 4);

/// Interview count range per [ProjectRank].
const Map<ProjectRank, IntRange> interviewCountRangeByRank = {
  ProjectRank.entry: IntRange(1, 1),
  ProjectRank.junior: IntRange(1, 1),
  ProjectRank.middle: IntRange(1, 2),
  ProjectRank.senior: IntRange(2, 2),
  ProjectRank.lead: IntRange(2, 3),
};

/// Difficulty (1-5) base value per [ProjectRank], before +/-1 individual
/// variance is applied (see `project_generator.dart`).
const Map<ProjectRank, int> baseDifficultyByRank = {
  ProjectRank.entry: 1,
  ProjectRank.junior: 2,
  ProjectRank.middle: 3,
  ProjectRank.senior: 4,
  ProjectRank.lead: 5,
};

/// Test-support projects are explicitly low-difficulty per the design doc
/// even if a middle-rank roll occurs; this caps the final value.
const int testSupportMaxDifficulty = 3;

/// Required-language candidate pools and pick weights, per [ProjectType].
/// `javaBusiness` and `pl` (Java-flavored) always require Java; the other
/// types weight-pick from a small pool, matching the design doc's examples
/// (an EC site needs Java, a React admin panel needs JS/TS, ...).
const Map<ProgrammingLanguage, double> webBackendLanguageWeights = {
  ProgrammingLanguage.php: 0.35,
  ProgrammingLanguage.python: 0.30,
  ProgrammingLanguage.java: 0.20,
  ProgrammingLanguage.csharp: 0.15,
};

/// Chance a frontend project requires both JS and TS rather than just one.
const double frontendRequiresBothLanguagesChance = 0.60;
const Map<ProgrammingLanguage, double> frontendSingleLanguageWeights = {
  ProgrammingLanguage.typescript: 0.60,
  ProgrammingLanguage.javascript: 0.40,
};

/// Chance an infrastructure project also lists Python as a required skill.
const double infrastructureRequiresPythonChance = 0.40;

/// Chance a test-support project lists a language requirement at all.
const double testSupportRequiresLanguageChance = 0.15;
const Map<ProgrammingLanguage, double> testSupportLanguageWeights = {
  ProgrammingLanguage.java: 0.5,
  ProgrammingLanguage.python: 0.5,
};

/// Chance a `pl` project's required language comes from the web pool
/// instead of defaulting to Java.
const double plUsesWebLanguagePoolChance = 0.30;

/// Required experience (in months, mapped from `requiredLanguages`' minimum
/// years called out in the design doc examples) roughly tracks rank; the
/// generator derives it from [rankSkillBump]/[baseDifficultyByRank] rather
/// than a separate table to avoid divergent knobs.

/// Title templates per [ProjectType]. Picked at random and optionally
/// suffixed with the client's name for flavor.
const Map<ProjectType, List<String>> titleTemplatesByProjectType = {
  ProjectType.javaBusiness: [
    'ECサイト追加開発',
    '基幹業務システム保守',
    '金融システム刷新',
    '在庫管理システム開発',
    '会計システム機能追加',
  ],
  ProjectType.webBackend: [
    'Web予約システム開発',
    'API基盤刷新',
    '会員サイトバックエンド開発',
    'ECサイトバックエンド保守',
  ],
  ProjectType.frontend: [
    'React管理画面開発',
    '社内ポータルUIリニューアル',
    'ダッシュボード画面開発',
    'ECサイトフロントエンド改修',
  ],
  ProjectType.infrastructure: [
    'AWS基盤構築',
    'クラウド移行プロジェクト',
    '社内インフラ刷新',
    'ネットワーク基盤保守',
  ],
  ProjectType.testSupport: ['テスト支援', '結合テスト支援', 'QA体制強化支援', 'リグレッションテスト支援'],
  ProjectType.pl: ['システム開発PL', 'プロジェクトリーダー募集', '開発チームマネジメント', '大規模開発PL/PM候補'],
};
