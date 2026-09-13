import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_offer_candidate.dart';
import '../../game/public_demo/public_demo_project_generator.dart';
import '../theme.dart';
import '../widgets/labels.dart';
import 'public_demo_sales_visual.dart';

/// Issue #245 Finding #4, Phase 1c: "候補案件を比較" — the full-screen
/// comparison view for every [PublicDemoOfferCandidate] one engineer
/// currently holds, plus the two real per-candidate actions this Finding
/// exists for: running that candidate's own next interview step, and
/// choosing exactly one already-passed candidate to receive the order
/// (declining every other live sibling atomically — see
/// [PublicDemoAggregate.recordOfferCandidateOrder]'s own doc).
///
/// Every fact rendered here is read straight from [candidatesFor]'s own
/// [PublicDemoOfferCandidate]s (Phase 1a/1b's own authority — this screen
/// invents nothing) and [resolveProject] (the same real, seeded
/// [PublicDemoSeededProjectGenerator.regenerate] resolution the Matching
/// screen and [PublicDemoProjectContextResolver] already use) — never a
/// second title/rate/type authority.
///
/// Deliberately a scrollable column of vertical cards (never a
/// horizontal-scrolling table) so it stays readable at 360/390px portrait
/// widths, per this task's own "スマホUI" requirement.
class PublicDemoOfferComparisonScreen extends StatefulWidget {
  const PublicDemoOfferComparisonScreen({
    super.key,
    required this.engineerId,
    required this.engineerName,
    required this.runSeed,
    required this.candidatesFor,
    required this.canProposeAdditional,
    required this.additionalProjectPoolFor,
    required this.onProposeAdditional,
    required this.onInterviewPartner,
    required this.onInterviewClient,
    required this.onOrder,
  });

  final String engineerId;
  final String engineerName;
  final int runSeed;

  /// Live getter (not a snapshot) — re-read after every action so the
  /// screen reflects the just-committed aggregate without needing its own
  /// second copy of game state.
  final List<PublicDemoOfferCandidate> Function() candidatesFor;

  /// Live getter — [PublicDemoAggregate.canProposeAdditionalOfferCandidate].
  final bool Function() canProposeAdditional;

  /// This month's real Phase 4 project pool, minus every project this
  /// engineer already holds a candidate for — never a fabricated project.
  final List<PublicDemoProjectCandidate> Function() additionalProjectPoolFor;

  final void Function(String projectId) onProposeAdditional;
  final void Function(String projectId) onInterviewPartner;
  final void Function(String projectId) onInterviewClient;
  final void Function(String projectId) onOrder;

  @override
  State<PublicDemoOfferComparisonScreen> createState() =>
      _PublicDemoOfferComparisonScreenState();
}

class _PublicDemoOfferComparisonScreenState
    extends State<PublicDemoOfferComparisonScreen> {
  bool _showAdditionalPicker = false;

  PublicDemoProjectCandidate? _resolve(String projectId) =>
      PublicDemoSeededProjectGenerator.regenerate(
        runSeed: widget.runSeed,
        projectId: projectId,
      );

  /// Codex Broad Review (PR #260) Finding #1 fix: [widget.onInterviewPartner]/
  /// [widget.onInterviewClient] only commit the mutated aggregate on the
  /// PARENT screen (`_openOfferComparison`'s own `_commitAggregate`) — they
  /// never by themselves trigger a rebuild of THIS screen, whose [build]
  /// re-reads [widget.candidatesFor]/[widget.canProposeAdditional] fresh
  /// every time it runs. Without an explicit [setState] here, the card kept
  /// showing the pre-interview stage/CTA until the player closed and
  /// reopened this screen (or triggered some OTHER rebuild, e.g. the order
  /// confirmation flow, which already called [setState] correctly) — and a
  /// second tap on the now-stale button re-ran the same, already-completed
  /// transition (harmless, since every domain transition below is its own
  /// precondition-gated no-op once already applied, but still surfaced as a
  /// silently-inert button rather than the next real action).
  ///
  /// Both calls are synchronous (no `await` in the parent's own commit
  /// chain), so [mounted] is checked defensively — mirroring [_confirmOrder]'s
  /// own convention — rather than because a real async gap exists here
  /// today; if a future caller ever makes the commit path asynchronous, this
  /// guard is already in place.
  void _runInterviewPartner(String projectId) {
    widget.onInterviewPartner(projectId);
    if (mounted) setState(() {});
  }

  void _runInterviewClient(String projectId) {
    widget.onInterviewClient(projectId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.candidatesFor();
    final canAddMore = widget.canProposeAdditional();
    return Scaffold(
      key: const Key('public-demo-offer-comparison-screen'),
      appBar: AppBar(title: Text('${widget.engineerName}さんの候補案件を比較')),
      body: ListView(
        key: const Key('public-demo-offer-comparison-list'),
        padding: const EdgeInsets.all(12),
        children: [
          if (candidates.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '現在、提案中の案件がありません。',
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final candidate in candidates)
              _OfferCandidateCard(
                key: Key(
                  'public-demo-offer-candidate-card-${candidate.engineerId}-${candidate.projectId}',
                ),
                candidate: candidate,
                project: _resolve(candidate.projectId),
                onInterviewPartner: () =>
                    _runInterviewPartner(candidate.projectId),
                onInterviewClient: () =>
                    _runInterviewClient(candidate.projectId),
                onOrder: () => _confirmOrder(context, candidate),
              ),
          if (canAddMore) ...[
            const SizedBox(height: 8),
            if (!_showAdditionalPicker)
              OutlinedButton.icon(
                key: const Key('public-demo-offer-comparison-add-project'),
                onPressed: () => setState(() => _showAdditionalPicker = true),
                icon: const Icon(Icons.add),
                label: const Text('別の案件も提案する'),
              )
            else
              _AdditionalProjectPicker(
                projects: widget.additionalProjectPoolFor(),
                onPick: (projectId) {
                  widget.onProposeAdditional(projectId);
                  setState(() => _showAdditionalPicker = false);
                },
                onCancel: () => setState(() => _showAdditionalPicker = false),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmOrder(
    BuildContext context,
    PublicDemoOfferCandidate candidate,
  ) async {
    final project = _resolve(candidate.projectId);
    if (project == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('public-demo-offer-comparison-order-confirm'),
        title: const Text('この案件を受注しますか？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('技術者：${widget.engineerName}'),
            const SizedBox(height: 4),
            Text('案件：${project.title}'),
            const SizedBox(height: 4),
            Text('単価：月額${formatYen(project.monthlyRate)}'),
            const SizedBox(height: 10),
            const Text(
              '受注すると、この技術者の他の候補案件は自動的に見送りになります。',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('public-demo-offer-comparison-order-confirm-yes'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('この案件を受注'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.onOrder(candidate.projectId);
    if (mounted) setState(() {});
  }
}

/// Every candidate stage, mapped to the task's own required Japanese
/// vocabulary — never the raw enum name.
(String, PublicDemoSalesStatusTone) _candidateStatus(
  PublicDemoOfferCandidateStage stage,
) => switch (stage) {
  PublicDemoOfferCandidateStage.proposed => ('提案中', PublicDemoSalesStatusTone.inProgress),
  PublicDemoOfferCandidateStage.partnerInterviewPassed => (
    'パートナー面談 通過',
    PublicDemoSalesStatusTone.inProgress,
  ),
  PublicDemoOfferCandidateStage.partnerInterviewFailed => (
    'パートナー面談 不通過',
    PublicDemoSalesStatusTone.negative,
  ),
  PublicDemoOfferCandidateStage.clientInterviewPassed => (
    '客先面談 通過',
    PublicDemoSalesStatusTone.positive,
  ),
  PublicDemoOfferCandidateStage.clientInterviewFailed => (
    '客先面談 不通過',
    PublicDemoSalesStatusTone.negative,
  ),
  PublicDemoOfferCandidateStage.ordered => ('受注', PublicDemoSalesStatusTone.positive),
  PublicDemoOfferCandidateStage.declined => ('見送り', PublicDemoSalesStatusTone.negative),
};

String _interviewResultLabel(int? score, bool passed) =>
    score == null ? '未実施' : (passed ? '合格（$score点）' : '不合格（$score点）');

class _OfferCandidateCard extends StatelessWidget {
  const _OfferCandidateCard({
    super.key,
    required this.candidate,
    required this.project,
    required this.onInterviewPartner,
    required this.onInterviewClient,
    required this.onOrder,
  });

  final PublicDemoOfferCandidate candidate;
  final PublicDemoProjectCandidate? project;
  final VoidCallback onInterviewPartner;
  final VoidCallback onInterviewClient;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, tone) = _candidateStatus(candidate.stage);
    final p = project;
    return PublicDemoSalesCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p?.title ?? '案件情報を取得できません',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: PublicDemoSalesStatusBadge(label: statusLabel, tone: tone),
              ),
            ],
          ),
          if (p == null) ...[
            const SizedBox(height: 6),
            const Text(
              'この案件のデータが古い、または取得できません。この候補は操作できません。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              '${projectTypeLabels[p.project.type] ?? p.project.type.name}｜'
              '月額${formatYen(p.monthlyRate)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: SesTheme.primaryBlue),
            ),
            const SizedBox(height: 2),
            Text(
              '取引先：${p.clientName}（${commercialFlowLabels[p.project.commercialFlow] ?? p.project.commercialFlow.name}）',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              'パートナー面談：${_interviewResultLabel(candidate.partnerScore, candidate.stage != PublicDemoOfferCandidateStage.partnerInterviewFailed)}',
              style: const TextStyle(fontSize: 12.5),
            ),
            Text(
              // Codex Broad Review (PR #260) Finding #3 fix: a `declined`
              // candidate that genuinely passed its client interview before
              // being auto-declined (a sibling ordered instead) still
              // carries its own genuine [PublicDemoOfferInterviewRecord] —
              // [candidate.hasGenuineInterviewRecord] is the unforgeable,
              // stage-independent authority for "did this pass", exactly
              // like [PublicDemoOfferCandidate.markOrdered]'s own gate uses
              // it. The OLD check here (`stage == clientInterviewPassed ||
              // stage == ordered`) was `false` for a genuinely-passed
              // `declined` candidate, mislabeling a real pass as "不合格".
              '客先面談：${_interviewResultLabel(candidate.clientScore, candidate.hasGenuineInterviewRecord)}',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            _actionFor(context),
          ],
        ],
      ),
    );
  }

  Widget _actionFor(BuildContext context) {
    switch (candidate.stage) {
      case PublicDemoOfferCandidateStage.proposed:
      case PublicDemoOfferCandidateStage.partnerInterviewFailed:
        return FilledButton(
          key: Key(
            'public-demo-offer-comparison-partner-interview-${candidate.projectId}',
          ),
          onPressed: onInterviewPartner,
          child: Text(
            candidate.stage == PublicDemoOfferCandidateStage.partnerInterviewFailed
                ? 'パートナー面談を再実施'
                : 'パートナー面談を実施',
          ),
        );
      case PublicDemoOfferCandidateStage.partnerInterviewPassed:
      case PublicDemoOfferCandidateStage.clientInterviewFailed:
        return FilledButton(
          key: Key(
            'public-demo-offer-comparison-client-interview-${candidate.projectId}',
          ),
          onPressed: onInterviewClient,
          child: Text(
            candidate.stage == PublicDemoOfferCandidateStage.clientInterviewFailed
                ? '客先面談を再実施'
                : '客先面談を実施',
          ),
        );
      case PublicDemoOfferCandidateStage.clientInterviewPassed:
        return FilledButton(
          key: Key(
            'public-demo-offer-comparison-order-${candidate.projectId}',
          ),
          onPressed: onOrder,
          child: const Text('この案件を受注'),
        );
      case PublicDemoOfferCandidateStage.ordered:
        return const Text(
          '受注済みの案件です。',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        );
      case PublicDemoOfferCandidateStage.declined:
        // Codex Broad Review (PR #260) Finding #3 fix: distinguish "passed,
        // but a sibling was ordered instead" from "declined without ever
        // genuinely passing" — both are `declined`, but only the former
        // means the player actually won this interview.
        return Text(
          candidate.hasGenuineInterviewRecord
              ? '客先面談に合格していましたが、他の案件を受注したため見送りになりました。'
              : '見送り済みのため、この案件は受注できません。',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        );
    }
  }
}

class _AdditionalProjectPicker extends StatelessWidget {
  const _AdditionalProjectPicker({
    required this.projects,
    required this.onPick,
    required this.onCancel,
  });

  final List<PublicDemoProjectCandidate> projects;
  final void Function(String projectId) onPick;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return PublicDemoSalesCard(
      key: const Key('public-demo-offer-comparison-additional-picker'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '提案する案件を選ぶ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: onCancel,
                icon: const Icon(Icons.close),
                tooltip: '閉じる',
              ),
            ],
          ),
          if (projects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('今月、他に提案できる案件がありません。'),
            )
          else
            for (final project in projects)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: OutlinedButton(
                  key: Key(
                    'public-demo-offer-comparison-additional-pick-${project.id}',
                  ),
                  onPressed: () => onPick(project.id),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          project.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(formatYen(project.monthlyRate)),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
