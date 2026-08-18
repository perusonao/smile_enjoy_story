import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/labels.dart';

/// Phase 3B-1 (S.E.S. Development Plan §3.3, "案件を選ぶ"): opens the
/// full-screen "案件を比較" comparison screen for [engineer] across
/// [projects] (2-3 candidates, chosen by the player beforehand — see
/// `_OffersComparisonSection` in `engineer_detail_screen.dart`, the one
/// screen that currently reaches this).
///
/// Distinct from [FitReasonSheet]'s bottom sheet — this is a full screen
/// (multiple projects, `Navigator.push`), not a modal that drills into a
/// single project's Fit reasons. The two never share a widget: this screen
/// leaves per-project Fit *reasons* for [FitReasonSheet] to show if the
/// player wants that from elsewhere (fit_reason_sheet.dart).
///
/// Also marks [BeginnerMilestone.projectComparisonUsed] shown, once, the
/// first time a Beginner Mode player actually opens this screen — the same
/// one-time-milestone shape [showFitReasonSheet] already established for
/// [BeginnerMilestone.fitReasonViewed] (fit_reason_sheet.dart). Free Mode
/// can reach this screen too (comparison itself is not Beginner-Mode-only),
/// but never records the milestone outside a Beginner Mode journey, mirroring
/// [BeginnerModeEngine.isBeginnerJourney]'s own gate.
Future<void> showProjectComparisonScreen(
  BuildContext context, {
  required Engineer engineer,
  required List<Project> projects,
  int? totalCandidates,
}) async {
  final controller = context.game;
  if (BeginnerModeEngine.isBeginnerJourney(controller.state) &&
      !controller.state.beginnerModeState.has(BeginnerMilestone.projectComparisonUsed)) {
    controller.markBeginnerMilestoneShown(BeginnerMilestone.projectComparisonUsed);
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProjectComparisonScreen(
        engineer: engineer,
        projects: projects,
        totalCandidates: totalCandidates,
      ),
    ),
  );
}

/// The screen body itself, split out from [showProjectComparisonScreen] so
/// widget tests can pump it directly (mirrors [FitReasonSheet]'s own split).
///
/// Scrollable, single-column, portrait-first layout (S.E.S. Development
/// Plan §3.3 UI note: never a horizontal wall-to-wall table for 2-3
/// projects on a phone). Every project gets one letter column (A/B/[C]) —
/// an overview card up top, then every required comparison item laid out
/// as its own row with that project's value in the matching column below.
class ProjectComparisonScreen extends StatelessWidget {
  const ProjectComparisonScreen({
    super.key,
    required this.engineer,
    required this.projects,
    this.totalCandidates,
  });

  final Engineer engineer;

  /// 2-3 candidate projects, same order the player selected them in.
  final List<Project> projects;

  /// How many candidates the player was choosing from before narrowing down
  /// to [projects] (e.g. `pendingOffers.length` at the entry point in
  /// `engineer_detail_screen.dart`) — shown as "選択中案件 n/合計件" so the
  /// fraction is a real ratio, not a tautology. `null` (and any pumped-
  /// directly widget test that never passes it) falls back to
  /// `projects.length`, i.e. "all of what's shown was selected".
  final int? totalCandidates;

  @override
  Widget build(BuildContext context) {
    // The one and only Fit/粗利 computation in this whole screen — every
    // row below just lays [rows] out, reusing the exact FitBreakdown/
    // monthlyProfit ProjectComparisonEngine already re-exposes from
    // MatchingEngine, never a second UI-side calculation (Phase 3B-1
    // implementation principle #1/#2).
    final rows = ProjectComparisonEngine.compare(engineer: engineer, projects: projects);
    final columnLabels = [for (var i = 0; i < rows.length; i++) String.fromCharCode(0x41 + i)];

    String fitCell(int score, int max) {
      final rating = PlayerVisibleFit.fromRaw(score, max);
      return '${rating.symbol} ${rating.label}';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('案件を比較')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          const Text('対象社員', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(
            engineer.profile.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '選択中案件 ${rows.length}/${totalCandidates ?? rows.length}件',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 14),
          _ColumnsRow([
            for (var i = 0; i < rows.length; i++) _OverviewCard(label: columnLabels[i], project: rows[i].project),
          ]),
          const SizedBox(height: 18),
          _SpecRow(
            label: '単価',
            values: [for (final row in rows) formatYen(row.monthlyRate)],
          ),
          _SpecRow(
            label: '粗利',
            helper: '会社に残る利益',
            values: [
              for (final row in rows) '${row.monthlyProfit >= 0 ? '+' : ''}${formatYen(row.monthlyProfit)}',
            ],
          ),
          const SizedBox(height: 6),
          const Text('Fit内訳', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 2),
          _SpecRow(
            label: '総合Fit',
            helper: '高いほど面談・参画との相性が良い',
            values: [for (final row in rows) fitCell(row.totalFit, 100)],
          ),
          // 技術/経験/人物・相性/条件: the same ◎○△× bucketed rating
          // FitReasonSheet's _BreakdownRow already shows for these four
          // sub-scores — never the raw score/max fraction. 人物・相性 folds
          // in the hidden `projectInterviewSkill`, so an exact number here
          // would let a player back-solve a stat that's never shown
          // (fit_reason_sheet.dart's own doc comment / PR #18 review fix) —
          // every row stays qualitative for the same reason, not just that
          // one.
          _SpecRow(label: '技術', values: [for (final row in rows) fitCell(row.techFit, 55)]),
          _SpecRow(label: '経験', values: [for (final row in rows) fitCell(row.experienceFit, 15)]),
          _SpecRow(label: '人物・相性', values: [for (final row in rows) fitCell(row.personalityFit, 20)]),
          _SpecRow(label: '条件', values: [for (final row in rows) fitCell(row.conditionFit, 10)]),
          _SpecRow(
            label: '商流',
            helper: '浅いほど条件が良い傾向',
            values: [for (final row in rows) commercialFlowLabels[row.commercialFlow] ?? row.commercialFlow.name],
          ),
          _SpecRow(
            label: '面談回数',
            values: [for (final row in rows) '${row.interviewCount}回'],
          ),
          _SpecRow(
            label: '支払サイト',
            helper: '短いほど早く入金される',
            // `paymentTermDaysById` (labels.dart), not `row.paymentTermDays`
            // — the underlying `Project.paymentTermDays` field is never
            // populated by the generator and stays at its class default;
            // every other screen that shows 支払サイト already reads the
            // client's real term this same way (project_detail_screen.dart,
            // project_list_screen.dart, engineer_detail_screen.dart).
            values: [for (final row in rows) '${paymentTermDaysById(row.project.clientId)}日'],
          ),
          _SpecRow(
            label: '契約期間',
            // `project.durationWeeks`, not `row.contractTermMonths` — the
            // engine's `contractTermMonths` getter passes through
            // `Project.contractTermMonths`, which `ProjectGenerator` never
            // populates (it stays at the class default of 3 for every
            // generated project) and which the engine only ever *uses* for
            // renewal-length math (`GameEngine.decideContract`'s
            // `contractTermMonths*4`), not the initial engagement length.
            // The actual initial contract length a player is choosing
            // between is `durationWeeks` (what `GameEngine.proposeEngineer`
            // /`acceptOffer` actually assign as `remainingWeeks`) — the same
            // field the existing `project_detail_screen.dart` already shows
            // under this exact "契約期間" label (Codex review on this PR:
            // showing "3ヶ月" for every project regardless of its real
            // 4-36 week duration would mislead the comparison this screen
            // exists for).
            values: [for (final row in rows) '${row.project.durationWeeks}週間'],
          ),
        ],
      ),
    );
  }
}

/// One project's short summary card — its column letter, title, and client.
/// Deliberately excludes Fit/価格 (those are in the rows below): a first
/// glance here should only answer "which project is A/B/C", not repeat the
/// whole comparison.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.label, required this.project});

  final String label;
  final Project project;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: SesTheme.primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '案件$label',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SesTheme.primaryBlue),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            project.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
          const SizedBox(height: 2),
          Text(
            clientNameById(project.clientId),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

/// One comparison item: a bold label (+ an optional short beginner-facing
/// caveat for the items that aren't simply "higher/shorter is always
/// better"), then every project's value in its own column directly below —
/// vertical stacking instead of one wide table row, so this keeps reading
/// cleanly at 360-390px (S.E.S. Development Plan §3.3 UI note).
class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.values, this.helper});

  final String label;
  final List<String> values;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: SesTheme.primaryBlue)),
          if (helper != null) ...[
            const SizedBox(height: 1),
            Text(helper!, style: const TextStyle(fontSize: 11, color: Colors.black45)),
          ],
          const SizedBox(height: 5),
          _ColumnsRow([
            for (final value in values)
              Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
          ]),
          const Divider(height: 16),
        ],
      ),
    );
  }
}

/// Lays [children] out in one equal-width column per project — the shared
/// layout both [_OverviewCard]s and every [_SpecRow]'s values use, so a
/// project's column lines up the same way from the overview cards all the
/// way down through every comparison item.
class _ColumnsRow extends StatelessWidget {
  const _ColumnsRow(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}
