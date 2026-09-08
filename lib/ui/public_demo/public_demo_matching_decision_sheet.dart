import 'package:flutter/material.dart';

import '../../game/game.dart';
import '../../game/public_demo/public_demo_project_generator.dart';
import '../../game/public_demo/public_demo_sales.dart';
import '../theme.dart';
import '../widgets/fit_badge.dart';
import '../widgets/labels.dart';

/// CORE-GAMEPLAY Phase 5 (Matching): steps 3-5 of the required player flow
/// ("強み/不足を見る → 提案する/見送る") for [engineer] × [candidate].
///
/// Reuses the *structure* of `lib/ui/widgets/fit_reason_sheet.dart`'s
/// `FitReasonSheet`/`FitBadge` (per this Issue's own instruction) — the
/// same qualitative breakdown rows and 良い点/不足点 bullet lists, built
/// from the same [FitBreakdown]/[FitDetailItem]/[PlayerVisibleFit] the
/// caller computed via `MatchingEngine.computeFit` (through
/// `ProjectComparisonEngine.rowFor`) — but never renders `fit.total` or any
/// other raw/internal score: only the ◎○△× [FitBadge] and a coarse
/// "面接通過見込み: 高/中/低" tier derived from the same
/// [PlayerVisibleFit.fromScore] bucketing the app already uses everywhere
/// else, per this Issue's explicit "do not show only a number" rule.
class PublicDemoMatchingDecisionSheet extends StatelessWidget {
  const PublicDemoMatchingDecisionSheet({
    super.key,
    required this.candidate,
    required this.engineer,
    required this.fit,
    required this.onViewSkillSheet,
    this.alreadyProposedForThisProject = false,
  });

  final PublicDemoProjectCandidate candidate;
  final PublicDemoEngineerSales engineer;
  final FitBreakdown fit;
  final VoidCallback onViewSkillSheet;

  /// True when [engineer] already has a recorded matching proposal for
  /// this exact [candidate] — only changes the confirm button's label
  /// ("提案し直す" vs "提案する"); every other rule is identical.
  final bool alreadyProposedForThisProject;

  /// Opens the sheet. Mirrors [PublicDemoSkillSheetSheet]'s own tri-state
  /// contract: `true` only from the explicit "提案する" button (the caller
  /// commits `PublicDemoAggregate.proposeMatching` itself — this widget
  /// never touches workflow state directly), `false` from "見送る", `null`
  /// on Back/barrier dismiss. The caller already treats `false`/`null`
  /// identically as "do not propose".
  static Future<bool?> show(
    BuildContext context, {
    required PublicDemoProjectCandidate candidate,
    required PublicDemoEngineerSales engineer,
    required FitBreakdown fit,
    required VoidCallback onViewSkillSheet,
    bool alreadyProposedForThisProject = false,
  }) => showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PublicDemoMatchingDecisionSheet(
      candidate: candidate,
      engineer: engineer,
      fit: fit,
      onViewSkillSheet: onViewSkillSheet,
      alreadyProposedForThisProject: alreadyProposedForThisProject,
    ),
  );

  static const _prospectLabels = {
    PlayerVisibleFit.excellent: '高',
    PlayerVisibleFit.good: '高',
    PlayerVisibleFit.fair: '中',
    PlayerVisibleFit.poor: '低',
  };

  @override
  Widget build(BuildContext context) {
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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Container(
      key: Key('public-demo-matching-decision-sheet-${engineer.id}'),
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${engineer.name} × ${candidate.title}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: SesTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    key: Key(
                      'public-demo-matching-view-skill-sheet-${engineer.id}',
                    ),
                    onPressed: onViewSkillSheet,
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('スキルシートを見る'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('総合評価', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      FitBadge(fit: overall),
                      const SizedBox(width: 10),
                      Text(
                        '面接通過見込み: ${_prospectLabels[overall]}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('内訳', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(height: 6),
                  _BreakdownRow(label: '技術', score: fit.techScore, max: 55),
                  _BreakdownRow(label: '経験', score: fit.experienceScore, max: 15),
                  _BreakdownRow(label: '人物・相性', score: fit.personalityScore, max: 20),
                  _BreakdownRow(label: '条件', score: fit.conditionScore, max: 10),
                  if (positives.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '強み',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.teal),
                    ),
                    const SizedBox(height: 4),
                    for (final item in positives) _ReasonLine(item: item),
                  ],
                  if (cautions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '不足',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.deepOrange),
                    ),
                    const SizedBox(height: 4),
                    for (final item in cautions) _ReasonLine(item: item),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: Key('public-demo-matching-skip-${engineer.id}'),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('見送る'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: Key('public-demo-matching-propose-${engineer.id}'),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(alreadyProposedForThisProject ? '提案し直す' : '提案する'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same qualitative-only sub-score row `FitReasonSheet._BreakdownRow`
/// already uses — never the raw `score`/`max` numbers, only the bucketed
/// ◎○△× symbol+label (see that class's own doc for why 人物・相性 folding
/// in a hidden input is still safe to bucket this way).
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

/// One 強み/不足 bullet line for a single [FitDetailItem] — reuses
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
