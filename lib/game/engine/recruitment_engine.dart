import '../../domain/domain.dart';
import '../models/models.dart';
import 'rng.dart';

/// Recruitment-side pure logic: offer acceptance rolls and per-media
/// applicant generation (§9-11, §21).
class RecruitmentEngine {
  const RecruitmentEngine._();

  /// `70 + companyCredit * 0.2`, clamped to `[0, 100]` (§10).
  static int acceptanceRate(int companyCredit) =>
      (70 + companyCredit * 0.2).round().clamp(0, 100);

  static bool rollAcceptance({
    required int rate,
    required int seed,
    required int week,
    required Object salt,
  }) {
    final rng = seededRandom(seed, week, salt);
    return rng.nextInt(100) < rate;
  }

  /// How many weeks (1-2) after acceptance the new hire joins (§11).
  static int joinDelayWeeks({
    required int seed,
    required int week,
    required Object salt,
  }) {
    final rng = seededRandom(seed, week, salt);
    return 1 + rng.nextInt(2);
  }

  /// Generates this week's applicants for one active [listing], biased
  /// toward the medium's target profile by over-generating a pool via the
  /// shared [ApplicantGenerator] and keeping the best-ranked subset —
  /// without needing to change the Phase 0 generator itself.
  static List<Applicant> generateApplicants({
    required RecruitmentMediaType type,
    required int week,
    required int seed,
    required String listingId,
  }) {
    final config = recruitmentMediaConfigs[type]!;
    final countRng = seededRandom(seed, week, '$listingId:count');
    final count = config.weeklyApplicants.pick(countRng);
    if (count <= 0) return const [];

    final batchSize = (count * 4).clamp(6, 16);
    final generator = ApplicantGenerator(
      seed: weekSeed(seed, week, '$listingId:pool'),
    );
    final batch = generator.generate(batchSize);

    final ranked = [...batch]
      ..sort((a, b) => _mediaScore(type, b).compareTo(_mediaScore(type, a)));
    return ranked.take(count).toList();
  }

  /// A coarse, player-facing "résumé trustworthiness" read derived from the
  /// applicant's dishonesty trait and how much their main-language résumé
  /// experience has been inflated over their true experience (§9). Never
  /// exposes the raw hidden numbers.
  static String trustAssessment(Applicant applicant) {
    final skill = applicant.skillFor(applicant.mainLanguage);
    final gap = skill.displayedExperienceMonths - skill.actualExperienceMonths;
    final gapRatio = skill.actualExperienceMonths == 0
        ? (gap > 0 ? 1.0 : 0.0)
        : gap / skill.actualExperienceMonths;

    if (applicant.personality.dishonesty <= 2 && gapRatio < 0.15) {
      return '信頼できそう';
    }
    if (applicant.personality.dishonesty >= 4 || gapRatio >= 0.4) {
      return '経歴に不自然さあり';
    }
    return '若干盛っている可能性';
  }

  static double _mediaScore(RecruitmentMediaType type, Applicant a) {
    switch (type) {
      case RecruitmentMediaType.freeWork:
        // 若手中心: younger applicants rank higher.
        return -a.age.toDouble();
      case RecruitmentMediaType.engineerCareer:
        // 経験者中心: more total IT experience ranks higher.
        return a.totalItExperienceMonths.toDouble();
      case RecruitmentMediaType.directScout:
        // 高スキル寄り: strong main-language skill + broad tech skills.
        final tech = a.techSkills;
        final techAvg =
            (tech.database +
                tech.network +
                tech.infrastructure +
                tech.frontend +
                tech.backend +
                tech.leader +
                tech.manager) /
            7.0;
        return a.skillFor(a.mainLanguage).actualSkill + techAvg * 20;
    }
  }
}
