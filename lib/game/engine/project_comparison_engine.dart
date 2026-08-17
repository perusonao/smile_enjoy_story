import '../../domain/domain.dart';
import '../models/models.dart';
import 'matching_engine.dart';

/// One row of a Phase 3B-1 (S.E.S. Development Plan §3.3, "案件を選ぶ")
/// project-to-engineer comparison: bundles the existing [MatchingEngine]
/// outputs a player weighing "この社員はどの案件を狙うべきか" needs to see
/// side by side.
///
/// Every getter below is a *derived* read of [project]/[fit]/
/// [monthlyProfit] — nothing here stores a second copy of a value that
/// already lives on [Project] or [FitBreakdown] (Phase 3B-1 design brief:
/// "既存モデルに同じ情報が存在する場合、値を重複保持せずderived valueを優先").
///
/// No UI reads this yet — that is Phase 3B-1's PR3/PR4, not this slice.
class ProjectComparisonRow {
  final Project project;
  final Engineer engineer;

  /// The exact [MatchingEngine.computeFit] result for [engineer] x
  /// [project] — total score, the four sub-scores (tech/experience/
  /// personality/condition, 55/15/20/10 weighting untouched), and the
  /// per-dimension ◎○△× reasons ([FitBreakdown.details]). Comparison never
  /// re-weights or re-derives Fit; it only re-exposes this one result.
  final FitBreakdown fit;

  /// [MatchingEngine.monthlyProfit] (`project.monthlyRate -
  /// engineer.salary`) — the same estimate already shown before proposing
  /// (Playable 0.3A design doc §10), computed once by
  /// [ProjectComparisonEngine] and re-exposed here rather than recomputed
  /// ad hoc by comparison UI later.
  final int monthlyProfit;

  const ProjectComparisonRow({
    required this.project,
    required this.engineer,
    required this.fit,
    required this.monthlyProfit,
  });

  // --- Derived only — every getter below reads straight through to
  // `project`/`fit`/`monthlyProfit`, never a stored duplicate. ---

  /// 月額単価 — straight passthrough, kept as a named getter only so
  /// comparison UI has one consistent row-level surface to read instead of
  /// reaching into `row.project.monthlyRate` directly.
  int get monthlyRate => project.monthlyRate;

  /// 粗利率 = 月間粗利 ÷ 月額単価. `Project.monthlyRate` is asserted `> 0`
  /// at construction (`project.dart`), so this never divides by zero.
  double get grossMarginRate => monthlyProfit / project.monthlyRate;

  /// 総合Fit (0-100), straight from [FitBreakdown.total].
  int get totalFit => fit.total;

  int get techFit => fit.techScore;
  int get experienceFit => fit.experienceScore;
  int get personalityFit => fit.personalityScore;
  int get conditionFit => fit.conditionScore;

  /// Fit理由 — the same per-dimension ◎○△× detail
  /// [MatchingEngine.computeFit] already produces (language / dominant
  /// tech domain / experience / communication / Japanese level). "Fitの
  /// 理由を理解する" means surfacing this list, not building a second
  /// explanation engine.
  List<FitDetailItem> get fitReasons => fit.details;

  CommercialFlow get commercialFlow => project.commercialFlow;

  /// 面談回数. Deliberately `project.interviewCount` (the field), not
  /// `project.selectionFlow.interviewCount` (a derived count that can
  /// differ for legacy proposal data — see
  /// `GameState.isProjectOpenForProposal`) — the existing project list/
  /// detail screens (`project_list_screen.dart`, `project_detail_screen.dart`)
  /// already label `project.interviewCount` as "面談回数", so comparison
  /// rows match that same existing meaning instead of introducing a second
  /// one.
  int get interviewCount => project.interviewCount;

  /// 支払サイト（日数）.
  int get paymentTermDays => project.paymentTermDays;

  /// 契約期間（月数）.
  int get contractTermMonths => project.contractTermMonths;
}

/// Phase 3B-1: builds side-by-side [ProjectComparisonRow]s for one engineer
/// across multiple candidate projects.
///
/// Pure and deterministic — reuses [MatchingEngine.computeFit] and
/// [MatchingEngine.monthlyProfit] exactly as they already exist for the
/// single-project proposal flow; this engine changes neither their scoring
/// weights nor the [Project]/[Engineer]/`GameState` model shapes. Not
/// connected to any UI yet (Phase 3B-1's comparison screen is a later PR).
class ProjectComparisonEngine {
  const ProjectComparisonEngine._();

  /// One [ProjectComparisonRow] per entry in [projects], same order.
  static List<ProjectComparisonRow> compare({
    required Engineer engineer,
    required List<Project> projects,
  }) => [for (final project in projects) rowFor(engineer, project)];

  /// A single row, e.g. for a Fit-reason-only view that doesn't need a full
  /// comparison list.
  static ProjectComparisonRow rowFor(Engineer engineer, Project project) =>
      ProjectComparisonRow(
        project: project,
        engineer: engineer,
        fit: MatchingEngine.computeFit(engineer, project),
        monthlyProfit: MatchingEngine.monthlyProfit(engineer, project),
      );
}
