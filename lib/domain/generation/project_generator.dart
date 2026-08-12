import 'dart:math';

import '../models/client.dart';
import '../models/programming_language.dart';
import '../models/project.dart';
import '../models/project_rank.dart';
import '../models/project_type.dart';
import '../models/remote_policy.dart';
import 'int_range.dart';
import 'project_distribution.dart';
import 'weighted_pick.dart';

/// Generates [Project]s per the Phase 0 design doc.
///
/// Deterministic: constructing two generators with the same [seed] and the
/// same [clients] list, then calling [generate] the same number of times,
/// produces identical projects in the same order. Never reads
/// `DateTime.now()` or any other non-deterministic source.
class ProjectGenerator {
  final int seed;
  final List<Client> clients;
  final Random _rng;
  int _sequence = 0;

  ProjectGenerator({required this.seed, required this.clients})
    : assert(clients.isNotEmpty, 'ProjectGenerator needs at least one client'),
      _rng = Random(seed);

  /// Generates [count] projects in sequence, anchored to [baseWeek] (the
  /// current in-game week) for computing `applicationDeadlineWeek`.
  List<Project> generate(int count, {int baseWeek = 1}) {
    return List.generate(count, (_) => _generateOne(baseWeek));
  }

  Project _generateOne(int baseWeek) {
    _sequence++;
    final id = 'project-$seed-$_sequence';

    final client = _pickClient();
    final type = _pickProjectType(client);
    final rank = pickWeighted(rankWeightsByProjectType[type]!, _rng);

    final rateRange = monthlyRateRangeByRank[rank]!;
    final monthlyRate = rateRange.pick(_rng);

    final durationRange = durationWeeksRangeByProjectType[type]!;
    final durationWeeks = durationRange.pick(_rng);

    final applicationDeadlineWeek =
        baseWeek + applicationDeadlineWeeksOutRange.pick(_rng);

    final requiredLanguages = _pickRequiredLanguages(type);

    final bump = rankSkillBump[rank]!;
    final baseReq = baseSkillRequirementsByProjectType[type]!;
    // Bump each range by rank (fixed-zero ranges — fields the project type
    // structurally doesn't need — are left untouched) then pick within it.
    int reqField(IntRange range) {
      final bumpedRange = range.max == 0 ? range : range.shifted(bump);
      return bumpedRange.pick(_rng);
    }

    final requiredDatabase = reqField(baseReq.database);
    final requiredNetwork = reqField(baseReq.network);
    final requiredInfrastructure = reqField(baseReq.infrastructure);
    final requiredFrontend = reqField(baseReq.frontend);
    final requiredBackend = reqField(baseReq.backend);
    final requiredLeader = reqField(baseReq.leader);
    final requiredManager = reqField(baseReq.manager);

    final requiredJapaneseLevel =
        (requiredJapaneseLevelBaseRange.pick(_rng) +
                (rank == ProjectRank.senior || rank == ProjectRank.lead
                    ? 1
                    : 0))
            .clamp(1, 5);

    final remotePolicy =
        RemotePolicy.values[_rng.nextInt(RemotePolicy.values.length)];
    final interviewCount = interviewCountRangeByRank[rank]!.pick(_rng);

    var difficulty = (baseDifficultyByRank[rank]! + (_rng.nextInt(3) - 1))
        .clamp(1, 5);
    if (type == ProjectType.testSupport) {
      difficulty = min(difficulty, testSupportMaxDifficulty);
    }

    final title = _pickTitle(type);

    return Project(
      id: id,
      clientId: client.id,
      title: title,
      type: type,
      rank: rank,
      monthlyRate: monthlyRate,
      durationWeeks: durationWeeks,
      applicationDeadlineWeek: applicationDeadlineWeek,
      requiredLanguages: requiredLanguages,
      requiredDatabase: requiredDatabase,
      requiredNetwork: requiredNetwork,
      requiredInfrastructure: requiredInfrastructure,
      requiredFrontend: requiredFrontend,
      requiredBackend: requiredBackend,
      requiredLeader: requiredLeader,
      requiredManager: requiredManager,
      requiredJapaneseLevel: requiredJapaneseLevel,
      remotePolicy: remotePolicy,
      interviewCount: interviewCount,
      difficulty: difficulty,
    );
  }

  Client _pickClient() {
    final weights = <Client, double>{
      for (final c in clients) c: c.projectGenerationWeight,
    };
    return pickWeighted(weights, _rng);
  }

  ProjectType _pickProjectType(Client client) {
    final weights = <ProjectType, double>{
      for (final entry in projectTypeWeights.entries)
        entry.key: entry.value * client.weightFor(entry.key),
    };
    return pickWeighted(weights, _rng);
  }

  List<ProgrammingLanguage> _pickRequiredLanguages(ProjectType type) {
    switch (type) {
      case ProjectType.javaBusiness:
        return const [ProgrammingLanguage.java];
      case ProjectType.webBackend:
        return [pickWeighted(webBackendLanguageWeights, _rng)];
      case ProjectType.frontend:
        if (_rng.nextDouble() < frontendRequiresBothLanguagesChance) {
          return const [
            ProgrammingLanguage.javascript,
            ProgrammingLanguage.typescript,
          ];
        }
        return [pickWeighted(frontendSingleLanguageWeights, _rng)];
      case ProjectType.infrastructure:
        if (_rng.nextDouble() < infrastructureRequiresPythonChance) {
          return const [ProgrammingLanguage.python];
        }
        return const [];
      case ProjectType.testSupport:
        if (_rng.nextDouble() < testSupportRequiresLanguageChance) {
          return [pickWeighted(testSupportLanguageWeights, _rng)];
        }
        return const [];
      case ProjectType.pl:
        if (_rng.nextDouble() < plUsesWebLanguagePoolChance) {
          return [pickWeighted(webBackendLanguageWeights, _rng)];
        }
        return const [ProgrammingLanguage.java];
    }
  }

  String _pickTitle(ProjectType type) {
    final templates = titleTemplatesByProjectType[type]!;
    return templates[_rng.nextInt(templates.length)];
  }
}
