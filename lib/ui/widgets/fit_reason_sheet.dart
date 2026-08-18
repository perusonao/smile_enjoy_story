import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import 'fit_badge.dart';
import 'labels.dart';

/// Phase 3B-1 (S.E.S. Development Plan §3.3, "案件を選ぶ"): opens the
/// "Fitの理由を見る" bottom sheet for [engineer] x [project].
///
/// Reuses [ProjectComparisonEngine.rowFor] — itself a thin wrapper around
/// [MatchingEngine.computeFit] — so this sheet always shows the *exact*
/// [FitBreakdown] already backing whatever [FitBadge] the player tapped
/// through from. No Fit score/weight is computed a second time anywhere in
/// this file.
///
/// Also marks [BeginnerMilestone.fitReasonViewed] shown, once, the first
/// time a Beginner Mode player actually opens this sheet — mirrors every
/// other one-time [GameController.markBeginnerMilestoneShown] call site
/// (`home_screen.dart`'s `_showPendingBeginnerEvents`). Guarded so this
/// never re-writes `GameState` on a later open once the milestone is
/// already recorded, and never fires at all outside a Beginner Mode
/// journey (mirrors [BeginnerModeEngine.pendingMilestones]'s own
/// `isBeginnerJourney` gate).
Future<void> showFitReasonSheet(
  BuildContext context, {
  required Engineer engineer,
  required Project project,
}) async {
  final controller = context.game;
  if (BeginnerModeEngine.isBeginnerJourney(controller.state) &&
      !controller.state.beginnerModeState.has(BeginnerMilestone.fitReasonViewed)) {
    controller.markBeginnerMilestoneShown(BeginnerMilestone.fitReasonViewed);
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FitReasonSheet(engineer: engineer, project: project),
  );
}

/// The sheet body itself, split out from [showFitReasonSheet] so widget
/// tests can pump it directly without going through a real
/// [showModalBottomSheet] call / [GameScope].
class FitReasonSheet extends StatelessWidget {
  const FitReasonSheet({super.key, required this.engineer, required this.project});

  final Engineer engineer;
  final Project project;

  @override
  Widget build(BuildContext context) {
    // The one and only Fit computation in this whole widget — everything
    // below just lays [fit] out, never re-derives it.
    final fit = ProjectComparisonEngine.rowFor(engineer, project).fit;
    final overall = PlayerVisibleFit.fromScore(fit.total);
    final positives = <FitDetailItem>[];
    final cautions = <FitDetailItem>[];
    for (final item in fit.details) {
      switch (item.rating) {
        case PlayerVisibleFit.excellent:
        case PlayerVisibleFit.good:
          positives.add(item);
        case PlayerVisibleFit.fair:
        case PlayerVisibleFit.poor:
          cautions.add(item);
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Fitの理由',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: SesTheme.primaryBlue),
            ),
            const SizedBox(height: 2),
            Text(
              project.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            const Text('総合Fit', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
            const SizedBox(height: 4),
            Row(
              children: [
                FitBadge(fit: overall),
                const SizedBox(width: 10),
                Text('${fit.total}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Fit内訳', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            const SizedBox(height: 6),
            _BreakdownRow(label: '技術', score: fit.techScore, max: 55),
            _BreakdownRow(label: '経験', score: fit.experienceScore, max: 15),
            _BreakdownRow(label: '人物・相性', score: fit.personalityScore, max: 20),
            _BreakdownRow(label: '条件', score: fit.conditionScore, max: 10),
            if (positives.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '良い点',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.teal),
              ),
              const SizedBox(height: 4),
              for (final item in positives) _ReasonLine(item: item),
            ],
            if (cautions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '注意点',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.deepOrange),
              ),
              const SizedBox(height: 4),
              for (final item in cautions) _ReasonLine(item: item),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Fitは案件との相性を表します。\n単価だけでなく、技術・経験・条件も確認しましょう。',
                style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One 技術/経験/人物・相性/条件 row: the same ◎○△× [PlayerVisibleFit.fromRaw]
/// conversion [MatchingEngine] already uses for its own per-dimension
/// [FitDetailItem]s — not a new rating rule, just the existing model-layer
/// helper applied to the four aggregate sub-scores.
///
/// Deliberately never renders the raw `score`/`max` numbers (only the
/// bucketed ◎○△× symbol+label, same as every other Fit display in the
/// app) — 人物・相性 folds in `HiddenParameters.projectInterviewSkill`
/// alongside the two *visible* personality traits `communication`/
/// `cleanliness` (both already shown as ★ ratings on this same engineer's
/// detail screen), so an exact `x / 20` here would let a player back-solve
/// for a stat `HiddenParameters`'s own doc comment says is "never shown to
/// the player" (docs/DEVELOPMENT_PLAN.md §3.0 rule 2 — mirrors the existing
/// hidden-value leak guard in `ux_guidance_test.dart`). 技術/経験/条件 have
/// no hidden inputs, but showing the exact number for only one of the four
/// rows would look like an inconsistent, oddly-vague UI — so every row
/// stays qualitative.
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.score, required this.max});

  final String label;
  final int score;
  final int max;

  @override
  Widget build(BuildContext context) {
    final rating = PlayerVisibleFit.fromRaw(score, max);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 68, child: Text(label, style: const TextStyle(fontSize: 13))),
          const Spacer(),
          Text(rating.symbol, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(rating.label, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
        ],
      ),
    );
  }
}

/// One 良い点/注意点 bullet line for a single [FitDetailItem] — reuses
/// [fitDetailLabel] (labels.dart) for the dimension name and the item's own
/// [FitDetailItem.rating] symbol/label, never a UI-invented explanation.
class _ReasonLine extends StatelessWidget {
  const _ReasonLine({required this.item});

  final FitDetailItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '・${fitDetailLabel(item)}: ${item.rating.symbol} ${item.rating.label}',
        style: const TextStyle(fontSize: 12.5, height: 1.4),
      ),
    );
  }
}
