import '../../domain/domain.dart';
import 'public_demo_engineer_runtime.dart';
import 'public_demo_rng.dart';

/// A [Project] bundled with the [Client] that offers it (CORE-GAMEPLAY
/// Phase 4: Random Projects) — a thin projection, not a second copy of
/// either model's data: every field below reads straight through to
/// [project]/[client]. [Client] carries no free-text "tendency" field of its
/// own, so [clientTendency] re-exposes [Client.specialty] (its own existing
/// "what kind of work this client mostly deals in" descriptor) under the
/// name the task's field list uses.
///
/// Phase 5 (Matching) is expected to consume [project]/[client] directly for
/// anything beyond this projection's convenience getters — nothing here
/// narrows what Phase 5 can see relative to the real domain [Project].
class PublicDemoProjectCandidate {
  const PublicDemoProjectCandidate({required this.project, required this.client});

  final Project project;
  final Client client;

  String get id => project.id;
  String get title => project.title;
  List<ProgrammingLanguage> get requiredLanguages => project.requiredLanguages;
  int get requiredExperienceMonths => project.requiredExperienceMonths;
  int get monthlyRate => project.monthlyRate;
  ProjectRank get rank => project.rank;
  int get difficulty => project.difficulty;
  String get clientName => client.name;
  ClientSpecialty get clientTendency => client.specialty;
}

/// Generates [PublicDemoProjectCandidate]s by reusing the main game's
/// [ProjectGenerator]/[Project] (CORE-GAMEPLAY Phase 4: Random Projects)
/// instead of inventing a separate Public-Demo-only project generator —
/// mirrors [PublicDemoSeededRecruitmentGenerator]'s own precedent (Phase 2)
/// for adapting a main-engine generator onto Public Demo.
///
/// Every candidate is a pure function of `(runSeed, month, slot index)` via
/// [PublicDemoRng] — never a shared/live `Random`, never dependent on how
/// many slots were generated before or after it — so:
///  - the same `(runSeed, month, slot)` always produces the same project
///    (reload-safe: nothing about a candidate's content is persisted, it is
///    always re-derived from [PublicDemoState.runSeed] and the requested
///    month/slot)
///  - a different [PublicDemoState.runSeed] (new playthrough) produces a
///    different set of projects
///  - generating slot N never perturbs slot N+1's own draw, and asking for
///    a different total slot count never changes an already-generated
///    slot's own content (generation order independence)
class PublicDemoSeededProjectGenerator {
  const PublicDemoSeededProjectGenerator._();

  /// Default number of project candidates offered per month. Phase 5 may
  /// pass its own `count`; this is only the Phase 4 default.
  static const int defaultSlotsPerMonth = 4;

  /// Slot 0 is regenerated (see [_guaranteedEligibleProject]) until it is
  /// realistically reachable by a founding-caliber engineer profile — the
  /// Balance Guard this phase's task requires. Bounded so a pathological
  /// `(runSeed, month)` can never spin forever; see the Result report's
  /// balance-guard section for why this bound is never actually hit in
  /// practice.
  static const int _guardMaxAttempts = 500;

  /// Every project offered for [month], as `(runSeed, month, slot)`-derived
  /// [PublicDemoProjectCandidate]s. Slot 0 is guaranteed realistically
  /// reachable by a founding-caliber engineer (the Balance Guard); every
  /// other slot is an unconstrained seeded draw.
  static List<PublicDemoProjectCandidate> forMonth({
    required int runSeed,
    required int month,
    int count = defaultSlotsPerMonth,
  }) {
    assert(count >= 1);
    return List.generate(count, (index) {
      final project = index == 0
          ? _guaranteedEligibleProject(runSeed: runSeed, month: month)
          : _generateOne(runSeed: runSeed, month: month, identifier: 'slot:$index');
      return _projectFor(_withStableId(project, _stableId(month, index)));
    });
  }

  /// Recovers the exact candidate a given [projectId] (as minted by
  /// [forMonth]) represents, purely from `(runSeed, projectId)` — no
  /// save-data dependency, mirroring [PublicDemoSeededRecruitmentGenerator
  /// .regenerateDomainApplicant]. Returns `null` for an id this generator
  /// did not mint.
  static PublicDemoProjectCandidate? regenerate({
    required int runSeed,
    required String projectId,
  }) {
    final parsed = _parseId(projectId);
    if (parsed == null) return null;
    final (month, index) = parsed;
    final project = index == 0
        ? _guaranteedEligibleProject(runSeed: runSeed, month: month)
        : _generateOne(runSeed: runSeed, month: month, identifier: 'slot:$index');
    return _projectFor(_withStableId(project, projectId));
  }

  static String _stableId(int month, int index) => 'project-$month-${index + 1}';

  static (int, int)? _parseId(String id) {
    final parts = id.split('-');
    if (parts.length != 3 || parts[0] != 'project') return null;
    final month = int.tryParse(parts[1]);
    final slot = int.tryParse(parts[2]);
    if (month == null || slot == null || slot < 1) return null;
    return (month, slot - 1);
  }

  static Project _generateOne({
    required int runSeed,
    required int month,
    required String identifier,
  }) {
    final seed = PublicDemoRng.derivedSeed(
      runSeed: runSeed,
      month: month,
      namespace: PublicDemoRngNamespace.projectGeneration,
      identifier: identifier,
    );
    return ProjectGenerator(
      seed: seed,
      clients: sampleClients,
    ).generate(1, baseWeek: _baseWeekForMonth(month)).single;
  }

  /// Public Demo has no week-granular calendar of its own (state advances by
  /// month only); this is a stable, deterministic stand-in so
  /// [Project.applicationDeadlineWeek] still carries a coherent value —
  /// unused by any Public Demo authority in this phase, exactly like
  /// several other [Project] fields (`paymentTermDays`,
  /// `contractTermMonths`, ...) it already carries without Public Demo
  /// acting on them yet.
  static int _baseWeekForMonth(int month) => (month - 4) * 4 + 1;

  /// BALANCE GUARD (task requirement): April's initial project pool must
  /// always contain at least one project a founding employee could
  /// realistically target, so a bad [runSeed] alone can never make the game
  /// effectively unclearable from turn one. Rather than hope this holds
  /// statistically, slot 0 is drawn repeatedly (each attempt a genuine,
  /// unmodified [ProjectGenerator] output — never a fabricated project)
  /// until one satisfies [_isRealisticallyTargetable] for either founding
  /// engineer, or [_guardMaxAttempts] is exhausted. This construction makes
  /// the guarantee hold for every month, not only April; only April is
  /// required/tested by this task.
  static Project _guaranteedEligibleProject({
    required int runSeed,
    required int month,
  }) {
    for (var attempt = 0; attempt < _guardMaxAttempts; attempt++) {
      final candidate = _generateOne(
        runSeed: runSeed,
        month: month,
        identifier: 'slot:0:guard:$attempt',
      );
      if (publicDemoInitialEngineerRuntimes.any(
        (engineer) => _isRealisticallyTargetable(candidate, engineer),
      )) {
        return candidate;
      }
    }
    // Exceedingly unlikely given the generator's own distribution (see the
    // Result report's balance-guard section) — falls back to one further
    // genuine draw rather than fabricating a project.
    return _generateOne(
      runSeed: runSeed,
      month: month,
      identifier: 'slot:0:guard:fallback',
    );
  }

  /// A deliberately simple, Phase-4-owned eligibility heuristic for the
  /// Balance Guard only — NOT the real Matching algorithm (out of this
  /// phase's scope; Phase 5 owns that). Reads only fields
  /// [PublicDemoEngineerRuntime] and [Project] already both carry: primary
  /// language, per-domain [TechSkillLevels], and IT experience months.
  static bool _isRealisticallyTargetable(
    Project project,
    PublicDemoEngineerRuntime engineer,
  ) {
    final primarySkill = engineer.languageSkills[engineer.primaryLanguage];
    final experienceMonths = primarySkill?.actualExperienceMonths ?? 0;
    if (project.requiredExperienceMonths > experienceMonths) return false;
    if (project.requiredLanguages.isNotEmpty &&
        !project.requiredLanguages.contains(engineer.primaryLanguage)) {
      return false;
    }
    final tech = engineer.techSkills;
    final requirements = [
      (project.requiredDatabase, tech.database),
      (project.requiredNetwork, tech.network),
      (project.requiredInfrastructure, tech.infrastructure),
      (project.requiredFrontend, tech.frontend),
      (project.requiredBackend, tech.backend),
      (project.requiredLeader, tech.leader),
      (project.requiredManager, tech.manager),
    ];
    return requirements.every((pair) => pair.$1 <= pair.$2);
  }

  static PublicDemoProjectCandidate _projectFor(Project project) =>
      PublicDemoProjectCandidate(project: project, client: _clientFor(project.clientId));

  static Client _clientFor(String clientId) => sampleClients.firstWhere(
    (client) => client.id == clientId,
    orElse: () => sampleClients.first,
  );

  /// Reconstructs [project] with [id] in place of the generator's own
  /// `project-<seed>-<sequence>` id — every other field passes through
  /// unchanged. Needed because the stable id scheme below (mirroring
  /// [PublicDemoSeededRecruitmentGenerator]'s candidate ids) deliberately
  /// does not depend on `runSeed`, only on `(month, slot)`, so a project's
  /// identity is stable across an id-only lookup regardless of which
  /// playthrough produced it — but [ProjectGenerator] itself has no way to
  /// know that convention, since its own id is a function of the seed it
  /// was given.
  static Project _withStableId(Project project, String id) => Project(
    id: id,
    clientId: project.clientId,
    title: project.title,
    type: project.type,
    rank: project.rank,
    monthlyRate: project.monthlyRate,
    durationWeeks: project.durationWeeks,
    applicationDeadlineWeek: project.applicationDeadlineWeek,
    requiredLanguages: project.requiredLanguages,
    requiredDatabase: project.requiredDatabase,
    requiredNetwork: project.requiredNetwork,
    requiredInfrastructure: project.requiredInfrastructure,
    requiredFrontend: project.requiredFrontend,
    requiredBackend: project.requiredBackend,
    requiredLeader: project.requiredLeader,
    requiredManager: project.requiredManager,
    requiredJapaneseLevel: project.requiredJapaneseLevel,
    remotePolicy: project.remotePolicy,
    interviewCount: project.interviewCount,
    selectionFlow: project.selectionFlow,
    competitionLevel: project.competitionLevel,
    difficulty: project.difficulty,
    industry: project.industry,
    location: project.location,
    availableStartWeek: project.availableStartWeek,
    plannedDurationMonths: project.plannedDurationMonths,
    workCategory: project.workCategory,
    commercialFlow: project.commercialFlow,
    contractTermMonths: project.contractTermMonths,
    paymentTermDays: project.paymentTermDays,
  );
}
