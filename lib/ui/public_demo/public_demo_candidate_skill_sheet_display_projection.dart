import '../../game/public_demo/public_demo_recruitment.dart';
import '../widgets/labels.dart';

/// CORE-GAMEPLAY Phase 4.5: a read-only display projection of a
/// **pre-hire candidate's** own SkillSheet content — the same design intent
/// as [PublicDemoSkillSheetDisplayFactory] one file over
/// (public_demo_skill_sheet_display_projection.dart) has for a joined
/// *employee*, but built from [PublicDemoApplicant] instead of
/// [PublicDemoEngineerRuntime], since a candidate has no runtime yet.
///
/// [PublicDemoApplicant] itself only carries flat, résumé-level scalars
/// (see its own class doc) — there is no structured per-language skill
/// breakdown, ability list, or career history to project for a candidate the
/// way there is for an employee. Every field here is one of those existing
/// scalars, read verbatim; nothing is computed or invented.
///
/// Deliberately excludes [PublicDemoApplicant.interviewScore],
/// [PublicDemoApplicant.acceptanceScore], and
/// [PublicDemoApplicant.salesSkillFit]: each is information the player only
/// ever learns by actually running an interview step (採用面談 for the
/// first two; 上位会社面談/客先面談 for the third, via
/// [PublicDemoInterviewResultDialog]'s own `score` display). A pre-hire
/// SkillSheet must not leak what those steps exist to reveal.
class PublicDemoCandidateSkillSheetDisplayData {
  const PublicDemoCandidateSkillSheetDisplayData({
    required this.applicantId,
    required this.name,
    required this.summaryText,
    required this.experienceLabel,
    required this.requestedMonthlySalaryLabel,
  });

  final String applicantId;
  final String name;

  /// The candidate's own résumé text — [PublicDemoApplicant.resumeSummary]
  /// verbatim.
  final String summaryText;

  /// [PublicDemoApplicant.experienceMonths], formatted the same way an
  /// employee's SkillSheet formats experience ([formatExperience]).
  final String experienceLabel;

  /// [PublicDemoApplicant.requestedMonthlySalary], formatted the same way
  /// the applicant card's own existing "希望給与" line already renders it.
  final String requestedMonthlySalaryLabel;
}

class PublicDemoCandidateSkillSheetDisplayFactory {
  const PublicDemoCandidateSkillSheetDisplayFactory._();

  static PublicDemoCandidateSkillSheetDisplayData create({
    required PublicDemoApplicant applicant,
  }) => PublicDemoCandidateSkillSheetDisplayData(
    applicantId: applicant.id,
    name: applicant.name,
    summaryText: applicant.resumeSummary,
    experienceLabel: formatExperience(applicant.experienceMonths),
    requestedMonthlySalaryLabel:
        '${applicant.requestedMonthlySalary ~/ 10000}万円',
  );
}
