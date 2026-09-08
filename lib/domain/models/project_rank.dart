/// Seniority rank of a project engagement. Drives the base monthly-rate
/// range used by the `ProjectGenerator` — see `distribution_tables.dart`.
enum ProjectRank {
  entry,
  junior,
  middle,
  senior,
  lead;

  String get jsonValue => name;

  static ProjectRank fromJson(String value) => ProjectRank.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw ArgumentError('Unknown ProjectRank: $value'),
  );

  /// Canonical minimum IT experience (months) a project of this rank expects
  /// an assigned engineer/applicant to have — see
  /// [projectRankMinimumExperienceMonths] for the single source of truth
  /// this reads.
  int get minimumExperienceMonths => projectRankMinimumExperienceMonths[this]!;
}

/// CORE-GAMEPLAY Phase 4 (Random Projects): the one canonical
/// rank→required-experience-months mapping every "requiredExperience" reader
/// must use — [Project.requiredExperienceMonths] reads it directly, and any
/// future matching logic should read this map too rather than inventing a
/// second one. Values intentionally match the main game's own
/// `MatchingEngine._rankExperienceExpectationMonths` (`lib/game/engine/
/// matching_engine.dart`) exactly — audited, not independently re-tuned —
/// so a project's stated requirement stays consistent with however the main
/// engine already scores an engineer's experience fit against the same rank.
const Map<ProjectRank, int> projectRankMinimumExperienceMonths = {
  ProjectRank.entry: 6,
  ProjectRank.junior: 18,
  ProjectRank.middle: 36,
  ProjectRank.senior: 60,
  ProjectRank.lead: 84,
};
