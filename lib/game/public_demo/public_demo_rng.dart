import 'dart:math';

import '../engine/rng.dart';

/// The independently-reproducible content streams Public Demo's future
/// gameplay (Phase 2/3 -- SES_DEVELOPMENT-PRIORITY_2026-09-02) will derive
/// from [PublicDemoState.runSeed] via [PublicDemoRng]. Phase 1 only defines
/// these identifiers; nothing in the current build calls [PublicDemoRng]
/// yet, since recruitment/project generation and interview UI stay on their
/// existing deterministic template selection (see
/// `PublicDemoRecruitmentCalculation._generateApplicants`'s own doc) until
/// those phases actually rewire it.
///
/// Each value is its own hash-salt namespace (see [PublicDemoRng]), so
/// drawing from one stream can never perturb another even when both are
/// requested for the same month and the same candidate/engineer id.
enum PublicDemoRngNamespace {
  recruitmentCandidate,
  recruitmentInterview,
  projectGeneration,
  projectInterview,
}

/// Public Demo's adapter onto the main game's authoritative seeded-RNG
/// primitives (`lib/game/engine/rng.dart`) -- reused as-is, not
/// reimplemented (SEEDED-RNG-REUSE-1). This is intentionally the only place
/// Public Demo code should ever import `rng.dart`: every future generator
/// derives its `Random`/seed through here instead of calling
/// [seededRandom]/[weekSeed] directly, so the (namespace, identifier)
/// convention below stays uniform across recruitment, interviews, and
/// project generation.
///
/// A derived stream is a pure function of `(runSeed, month, namespace,
/// identifier)` -- nothing here holds or threads a live [Random] instance,
/// exactly like [seededRandom] itself: every stream can be recomputed on
/// demand, in any order, including after a save reload, purely from
/// [PublicDemoState.runSeed] and whichever month/id the caller already has.
class PublicDemoRng {
  const PublicDemoRng._();

  /// The deterministic seed for one `(namespace, identifier)` stream within
  /// [month], derived from the playthrough's [runSeed]. Reuses [weekSeed]'s
  /// own `(seed, week, salt)` hashing (`month` standing in for the main
  /// game's `week`) rather than a new derivation, so this inherits the same
  /// collision-avoidance guarantee `weekSeed` already gives every other
  /// `(seed, week, salt)` stream in the main engine.
  static int derivedSeed({
    required int runSeed,
    required int month,
    required PublicDemoRngNamespace namespace,
    required String identifier,
  }) => weekSeed(runSeed, month, '${namespace.name}:$identifier');

  /// A fresh [Random] for one `(namespace, identifier)` stream within
  /// [month]. Callers should build a new one per draw (or per short-lived
  /// sequence of draws) from the same inputs rather than caching it, the
  /// same way every [seededRandom] call site in the main engine does.
  static Random random({
    required int runSeed,
    required int month,
    required PublicDemoRngNamespace namespace,
    required String identifier,
  }) => Random(
    derivedSeed(
      runSeed: runSeed,
      month: month,
      namespace: namespace,
      identifier: identifier,
    ),
  );

  /// Deterministic seed for the narrow legacy-fixture interview fallback
  /// (`PublicDemoRecruitmentInterview` -- CORE-GAMEPLAY Phase 3). Deliberately
  /// NOT `runSeed`-derived: the hand-authored founding-pool fixtures
  /// (`app-01`, `app-02`, `free-template-*`) predate
  /// [PublicDemoSeededRecruitmentGenerator] and were never produced by
  /// `ApplicantGenerator` in the first place, so there is no `runSeed`-linked
  /// domain `Applicant` to recover for them -- only a stable, id-only seed
  /// so the interview engine still has consistent (if not "real") flavor
  /// data to draw from across reloads. This is the one other sanctioned use
  /// of `rng.dart`'s primitives outside [derivedSeed]/[random] above, kept
  /// here rather than duplicated in the interview adapter so every
  /// Public Demo file still reaches `rng.dart` through this one adapter.
  static int legacyFixtureSeed(String applicantId) =>
      stableHash('legacy-recruitment-interview:$applicantId');
}
