import '../../domain/domain.dart';
import 'public_demo_recruitment.dart';
import 'public_demo_recruitment_medium.dart';
import 'public_demo_rng.dart';

/// Generates [PublicDemoApplicant] candidates for one recruitment purchase
/// by reusing the main game's [ApplicantGenerator] (CORE-GAMEPLAY Phase 2:
/// seeded recruitment) instead of the fixed/cyclic template pool
/// `PublicDemoRecruitmentCalculation` used before this change (see
/// `docs/reports/SES_CORE-GAMEPLAY_Phase2_Random-Recruitment_Result.md`).
///
/// Every candidate is a pure function of `(runSeed, month, medium, slot
/// index)` via [PublicDemoRng] -- never a shared/live [Random] and never
/// dependent on how many candidates were generated before it -- so:
///  - the same inputs always produce the same candidate (reload-safe, and
///    stable while the player is still deciding on it)
///  - a different [PublicDemoState.runSeed] (new playthrough) produces a
///    different candidate pool
///  - generating slot N never perturbs slot N+1's own draw (order
///    independence)
///
/// Each candidate's [PublicDemoApplicant.id] keeps the exact pre-existing
/// format (`recruitment-<month>-<medium>-<slot>`) so callers that already
/// depend on that shape (portraits, persistence, tests) are unaffected --
/// only the underlying attributes are now genuinely generated instead of
/// cycled from a 2-entry template pool. Because the id alone encodes
/// `(month, medium, slot)`, and [PublicDemoState.runSeed] never changes
/// within a playthrough, the exact same full domain [Applicant] -- with
/// every hidden/interview-only field -- can be regenerated later purely
/// from `(runSeed, id)` via [regenerateDomainApplicant]; nothing about this
/// candidate's identity needs to be persisted beyond the existing
/// [PublicDemoApplicant] projection.
class PublicDemoSeededRecruitmentGenerator {
  const PublicDemoSeededRecruitmentGenerator._();

  static List<PublicDemoApplicant> generate({
    required int runSeed,
    required int month,
    required PublicDemoRecruitmentMedium medium,
    required int count,
  }) {
    return List.generate(count, (index) {
      final identifier = '${medium.name}:$index';
      final id = 'recruitment-$month-${medium.name}-${index + 1}';
      if (medium == PublicDemoRecruitmentMedium.free &&
          _rollsInexperienced(
            runSeed: runSeed,
            month: month,
            identifier: identifier,
          )) {
        return _inexperiencedCandidate(
          runSeed: runSeed,
          month: month,
          identifier: identifier,
          id: id,
        );
      }
      final applicant = _pickApplicant(
        runSeed: runSeed,
        month: month,
        medium: medium,
        identifier: identifier,
      );
      return _project(applicant, id: id, medium: medium);
    });
  }

  /// Recovers the exact full domain [Applicant] this candidate was
  /// generated from, purely from `(runSeed, applicant.id)` -- no save-data
  /// dependency. Returns null for an id that does not match this
  /// generator's own `recruitment-<month>-<medium>-<slot>` scheme (e.g. the
  /// hand-authored `app-01`/`app-02`/`free-template-*` fixtures), since
  /// those were never produced by [ApplicantGenerator] in the first place.
  ///
  /// This is the Phase 3 (Recruitment Interview) integration point named in
  /// the Phase 2 result report: interview logic needs the full [Applicant]
  /// (hidden parameters included), not just the trimmed
  /// [PublicDemoApplicant] projection this generator persists.
  static Applicant? regenerateDomainApplicant({
    required int runSeed,
    required String applicantId,
  }) {
    final parsed = _parseId(applicantId);
    if (parsed == null) return null;
    final (month, medium, index) = parsed;
    final identifier = '${medium.name}:$index';
    if (medium == PublicDemoRecruitmentMedium.free &&
        _rollsInexperienced(
          runSeed: runSeed,
          month: month,
          identifier: identifier,
        )) {
      return _generateOne(
        runSeed: runSeed,
        month: month,
        identifier: '$identifier:flavor',
      );
    }
    return _pickApplicant(
      runSeed: runSeed,
      month: month,
      medium: medium,
      identifier: identifier,
    );
  }

  /// Reconstructs the exact [PublicDemoApplicant] [generate] would have
  /// produced for [applicantId]'s own slot, purely from `(runSeed, id)` --
  /// the same per-slot projection [generate] itself performs, exposed for
  /// [verifiedSourceApplicantFor] to compare against what is actually
  /// stored. Returns `null` under the same condition as
  /// [regenerateDomainApplicant] (an id this generator's own scheme cannot
  /// parse).
  static PublicDemoApplicant? regenerateProjectedApplicant({
    required int runSeed,
    required String applicantId,
  }) {
    final parsed = _parseId(applicantId);
    if (parsed == null) return null;
    final (month, medium, index) = parsed;
    final identifier = '${medium.name}:$index';
    if (medium == PublicDemoRecruitmentMedium.free &&
        _rollsInexperienced(
          runSeed: runSeed,
          month: month,
          identifier: identifier,
        )) {
      return _inexperiencedCandidate(
        runSeed: runSeed,
        month: month,
        identifier: identifier,
        id: applicantId,
      );
    }
    final applicant = _pickApplicant(
      runSeed: runSeed,
      month: month,
      medium: medium,
      identifier: identifier,
    );
    return _project(applicant, id: applicantId, medium: medium);
  }

  /// Issue #248 Codex P1 fix: verifies that regenerating from [applicant]'s
  /// own id would reproduce the exact same résumé-visible profile already
  /// stored on [applicant], before trusting the result as this applicant's
  /// real generation source.
  ///
  /// A save created before this generator existed can still carry a
  /// *pending* (not yet joined) applicant whose id already happens to be
  /// shaped like `recruitment-<month>-<medium>-<slot>` -- the pre-Phase-2
  /// fixed/cyclic template pool this generator replaced
  /// (`PublicDemoRecruitmentCalculation`'s old default, see this class's
  /// own doc) used the exact same id scheme, just cycling through a small
  /// template array instead of seed-generating. For such an applicant, the
  /// id alone is not proof of provenance: [regenerateDomainApplicant]
  /// would return today's seed-generated candidate for that slot -- an
  /// unrelated person's profile, not the one the old template pool
  /// actually assigned this stored applicant. Only once every
  /// résumé-visible field [regenerateProjectedApplicant] independently
  /// derives for this id already matches what is actually stored is it
  /// safe to treat the regenerated domain [Applicant] as this applicant's
  /// genuine source; otherwise this returns `null` and the caller must
  /// fall back to its own pre-existing (non-seeded) behavior. Deliberately
  /// adds no new save-schema/provenance field -- this is a pure,
  /// re-derived-on-demand check, exactly like [regenerateDomainApplicant]
  /// itself.
  static Applicant? verifiedSourceApplicantFor({
    required int runSeed,
    required PublicDemoApplicant applicant,
  }) {
    final projected = regenerateProjectedApplicant(
      runSeed: runSeed,
      applicantId: applicant.id,
    );
    if (projected == null ||
        projected.name != applicant.name ||
        projected.resumeSummary != applicant.resumeSummary ||
        projected.experienceMonths != applicant.experienceMonths ||
        projected.salesSkillFit != applicant.salesSkillFit ||
        projected.interviewScore != applicant.interviewScore ||
        projected.acceptanceScore != applicant.acceptanceScore ||
        projected.requestedMonthlySalary != applicant.requestedMonthlySalary) {
      return null;
    }
    return regenerateDomainApplicant(
      runSeed: runSeed,
      applicantId: applicant.id,
    );
  }

  static (int, PublicDemoRecruitmentMedium, int)? _parseId(String id) {
    final parts = id.split('-');
    if (parts.length != 4 || parts[0] != 'recruitment') return null;
    final month = int.tryParse(parts[1]);
    final slot = int.tryParse(parts[3]);
    if (month == null || slot == null) return null;
    final medium = PublicDemoRecruitmentMedium.values
        .where((value) => value.name == parts[2])
        .firstOrNull;
    if (medium == null) return null;
    return (month, medium, slot - 1);
  }

  static bool _rollsInexperienced({
    required int runSeed,
    required int month,
    required String identifier,
  }) {
    final rng = PublicDemoRng.random(
      runSeed: runSeed,
      month: month,
      namespace: PublicDemoRngNamespace.recruitmentCandidate,
      identifier: '$identifier:inexperienced-check',
    );
    return rng.nextInt(100) < 50;
  }

  /// Engineer media is paid and biased toward stronger candidates -- mirrors
  /// the main engine's own over-generate-then-rank pattern
  /// (`RecruitmentEngine.generateApplicants`) instead of inventing a new
  /// selection mechanism. Free media takes a single, unranked draw, matching
  /// its own existing doc ("deliberately has a mixed-quality candidate
  /// pool").
  static Applicant _pickApplicant({
    required int runSeed,
    required int month,
    required PublicDemoRecruitmentMedium medium,
    required String identifier,
  }) {
    if (medium != PublicDemoRecruitmentMedium.engineer) {
      return _generateOne(
        runSeed: runSeed,
        month: month,
        identifier: '$identifier:candidate-0',
      );
    }
    const batchSize = 3;
    final batch = List.generate(
      batchSize,
      (n) => _generateOne(
        runSeed: runSeed,
        month: month,
        identifier: '$identifier:candidate-$n',
      ),
    );
    batch.sort(
      (a, b) => b.totalItExperienceMonths.compareTo(a.totalItExperienceMonths),
    );
    return batch.first;
  }

  static Applicant _generateOne({
    required int runSeed,
    required int month,
    required String identifier,
  }) {
    final seed = PublicDemoRng.derivedSeed(
      runSeed: runSeed,
      month: month,
      namespace: PublicDemoRngNamespace.recruitmentCandidate,
      identifier: identifier,
    );
    return ApplicantGenerator(seed: seed).generate(1).single;
  }

  // ---------------------------------------------------------------------
  // Adapter / projection: main-engine Applicant -> PublicDemoApplicant.
  //
  // Only résumé-visible (non-[HiddenParameters]) facts feed the visible
  // fields below -- see the Phase 2 result report's "visible vs
  // interview-hidden fields" table. [HiddenParameters]/[dishonesty] stay
  // unread here; they remain reachable only via [regenerateDomainApplicant]
  // for a future interview step.
  // ---------------------------------------------------------------------

  static PublicDemoApplicant _project(
    Applicant a, {
    required String id,
    required PublicDemoRecruitmentMedium medium,
  }) {
    final skill = a.skillFor(a.mainLanguage);
    final displayedYears = (skill.displayedExperienceMonths / 12).round();
    final resumeSummary =
        '${_languageLabel[a.mainLanguage]} $displayedYears年・${a.age}歳 '
        '/ ${_roleNote[a.type]}';
    return PublicDemoApplicant(
      id: id,
      name: a.name,
      resumeSummary: resumeSummary,
      interviewScore: _interviewScore(a.personality),
      acceptanceScore: _acceptanceScore(a.hidden),
      salesSkillFit: skill.actualSkill,
      experienceMonths: a.totalItExperienceMonths,
      requestedMonthlySalary: _mapSalary(a, medium),
    );
  }

  static PublicDemoApplicant _inexperiencedCandidate({
    required int runSeed,
    required int month,
    required String identifier,
    required String id,
  }) {
    // ApplicantGenerator's minimum experience floor (itExperienceYearsRangeByType,
    // 1+ year for every ApplicantType) cannot express a genuine
    // zero-experience hire (see ApplicantType's own doc: "untrained/
    // inexperienced hires ... are intentionally not part of this ... enum").
    // Public Demo's free-medium inexperienced-hire path (isInexperienced /
    // canEnterPreJoinSales) predates this generator and stays reachable via
    // this narrow, documented adapter exception: a generated applicant
    // supplies authentic name/age/personality flavor, while experience and
    // requested salary use the pre-existing entry-level anchor values
    // instead of a fabricated generator output.
    final flavor = _generateOne(
      runSeed: runSeed,
      month: month,
      identifier: '$identifier:flavor',
    );
    return PublicDemoApplicant(
      id: id,
      name: flavor.name,
      resumeSummary: '${flavor.age}歳 / ITスクール修了・実務未経験',
      interviewScore: _interviewScore(flavor.personality),
      acceptanceScore: _acceptanceScore(flavor.hidden),
      salesSkillFit:
          (10 +
                  flavor.personality.communication * 4 +
                  flavor.personality.seriousness * 2)
              .clamp(0, 100),
      experienceMonths: 0,
      requestedMonthlySalary: 220000,
    );
  }

  /// A coarse, résumé-visible "first impression" read (gates whether the
  /// player can even send a salary offer -- see
  /// `PublicDemoApplicant.interviewScore` call sites). Derived only from
  /// [PersonalityTraits] fields the domain model itself documents as
  /// "public/visible profile data".
  static int _interviewScore(PersonalityTraits p) =>
      (62 + (p.communication - 3) * 9 + (p.seriousness - 3) * 5).clamp(0, 100);

  /// Baseline offer-acceptance propensity (see
  /// `PublicDemoSalaryOfferEvaluator.evaluate`, which further adjusts this
  /// by the offered-vs-requested salary gap). Derived from
  /// [HiddenParameters.retention]/[HiddenParameters.turnoverIntent] --
  /// legitimately hidden domain data, but Public Demo already used this
  /// field only as an internal acceptance-math input, never as displayed
  /// text, so surfacing it here does not newly expose hidden information to
  /// the player.
  static int _acceptanceScore(HiddenParameters h) =>
      (70 + (h.retention - 3) * 8 - ((h.turnoverIntent - 50) ~/ 10)).clamp(
        0,
        100,
      );

  /// Rescales [Applicant.desiredMonthlySalary] from the main engine's own
  /// per-[ApplicantType] range (250,000-650,000 JPY across all types) into a
  /// band close to Public Demo's pre-existing recruitment economy
  /// (engineer-medium templates: 300,000-320,000; free-medium: 220,000-
  /// 250,000; starting cash 4,000,000; baseline monthly payroll ~800,000) --
  /// see the Phase 2 result report's balance-compatibility section. This
  /// preserves each applicant's *relative* ability signal (a stronger
  /// candidate within their own type still costs more) while keeping
  /// absolute JPY figures inside the range Public Demo's finance was tuned
  /// for, instead of importing the main engine's wider salary economy
  /// verbatim.
  static int _mapSalary(Applicant a, PublicDemoRecruitmentMedium medium) {
    final range = salaryRangeByType[a.type]!;
    final fraction = range.max == range.min
        ? 0.5
        : ((a.desiredMonthlySalary - range.min) / (range.max - range.min))
              .clamp(0.0, 1.0);
    final target = medium == PublicDemoRecruitmentMedium.engineer
        ? const IntRange(260000, 420000)
        : const IntRange(220000, 300000);
    final mapped = target.min + ((target.max - target.min) * fraction).round();
    return (mapped / 10000).round() * 10000;
  }

  static const Map<ProgrammingLanguage, String> _languageLabel = {
    ProgrammingLanguage.java: 'Java',
    ProgrammingLanguage.csharp: 'C#',
    ProgrammingLanguage.php: 'PHP',
    ProgrammingLanguage.python: 'Python',
    ProgrammingLanguage.javascript: 'JavaScript',
    ProgrammingLanguage.typescript: 'TypeScript',
  };

  static const Map<ApplicantType, String> _roleNote = {
    ApplicantType.juniorProgrammer: '基本設計〜実装',
    ApplicantType.midLevelEngineer: '詳細設計〜テスト',
    ApplicantType.seniorEngineer: '要件定義〜運用',
    ApplicantType.frontendSpecialist: 'UI実装〜フロント設計',
    ApplicantType.infrastructureSpecialist: 'インフラ構築〜運用',
    ApplicantType.plCandidate: '進行管理〜折衝',
  };
}
