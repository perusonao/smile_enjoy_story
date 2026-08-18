import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/engineer_avatar.dart';
import '../widgets/fit_badge.dart';
import '../widgets/labels.dart';
import '../widgets/status_chip.dart';
import '../engineers/engineer_detail_screen.dart';
import 'project_comparison_screen.dart';
import 'project_list_screen.dart';

/// Display-only bucket over [EmployeeWorkflowState] for the 案件タブの
/// summary counts / filter (営業・案件画面 Phase 2 §5-6) — never a second
/// state machine, just a grouping of the one state [EmployeeWorkflowEngine]
/// already computes. `waiting` engineers have no sales activity and are
/// excluded (`null`) — they already have their own place on the 社員タブ.
enum _SalesBucket { selling, inSelection, offer, assigned }

_SalesBucket? _bucketFor(EmployeeWorkflowState s) => switch (s) {
  EmployeeWorkflowState.selling ||
  EmployeeWorkflowState.interviewRequestPending => _SalesBucket.selling,
  EmployeeWorkflowState.clientInterviewActionRequired ||
  EmployeeWorkflowState.waitingSelectionResult => _SalesBucket.inSelection,
  EmployeeWorkflowState.finalOfferPending => _SalesBucket.offer,
  EmployeeWorkflowState.assigned ||
  EmployeeWorkflowState.assignmentScheduled => _SalesBucket.assigned,
  EmployeeWorkflowState.waiting => null,
};

/// The 案件タブの独自フィルター (§6): 「営業状況」リストにのみ適用する。参画中は
/// 常時表示の別セクション（§11）を持つため、ここにフィルター項目としては
/// 含めない。
enum _SalesFilter { all, selling, inSelection, offer }

/// The three actionable [EmployeeWorkflowState]s [EmployeeWorkflowEngine]
/// itself would report for [engineerId] *if it didn't already know they're
/// assigned* — i.e. the exact same predicates `forEngineer` checks
/// internally (Codex review, PR #26), just without its own
/// assigned/assignmentScheduled early-return. `GameEngine.startSales`
/// explicitly allows an already-assigned employee to start selling their
/// *next* contract (see its `availableFromWeek` handling), and
/// `GameEngine.acceptOffer` never blocks accepting a next-contract offer
/// while still on a current one — so a pending offer/客先面談/面談依頼 for
/// that next contract is a real, live thing needing the player's attention,
/// even though `forEngineer` always reports `assigned` for them (correctly,
/// for their headline status everywhere else in the app). Returns `null`
/// when none of the three apply.
EmployeeWorkflowState? _secondarySalesActionState(GameState state, String engineerId) {
  final hasPendingOffer = state.offers.any(
    (o) => o.employeeId == engineerId && o.status == OfferStatus.pending,
  );
  if (hasPendingOffer) return EmployeeWorkflowState.finalOfferPending;

  final clientInterviewPending = state.proposals.any(
    (p) =>
        p.engineerId == engineerId &&
        p.status == ApplicationStatus.active &&
        p.currentStep == SelectionStep.clientInterview &&
        !state.clientInterviews.any((s) => s.applicationId == p.id && s.completed),
  );
  if (clientInterviewPending) return EmployeeWorkflowState.clientInterviewActionRequired;

  final hasInterviewRequest = state.interviewOffers.any(
    (o) => o.employeeId == engineerId && o.status == InterviewOfferStatus.pending,
  );
  if (hasInterviewRequest) return EmployeeWorkflowState.interviewRequestPending;

  return null;
}

/// The state to key 要対応 off of for one engineer: [primary] itself when
/// that's already actionable, or — only for an engineer whose primary state
/// is `assigned`/`assignmentScheduled` — the hidden secondary state from
/// [_secondarySalesActionState]. `null` means nothing needs the player's
/// attention right now.
EmployeeWorkflowState? _actionStateFor(GameState state, Engineer engineer, EmployeeWorkflowState primary) {
  if (EmployeeWorkflowEngine.requiresAction(primary)) return primary;
  if (primary == EmployeeWorkflowState.assigned || primary == EmployeeWorkflowState.assignmentScheduled) {
    return _secondarySalesActionState(state, engineer.id);
  }
  return null;
}

/// ある社員が今アクティブに関わっている案件（あれば）— [EmployeeWorkflowEngine]
/// や `_CurrentStatusCard`（engineer_detail_screen.dart）が同じ状態のために
/// 既に読んでいるのと同じレコードから導出する。*どの状態か* を再判定するもの
/// ではなく、その状態に付随する *どの案件か* を表示用に取り出すだけ。
class _PrimaryContext {
  const _PrimaryContext({this.project, this.pendingOfferCount = 0});

  final Project? project;
  final int pendingOfferCount;
}

_PrimaryContext _primaryContextFor(
  GameState state,
  Engineer engineer,
  EmployeeWorkflowState workflowState,
) {
  switch (workflowState) {
    case EmployeeWorkflowState.finalOfferPending:
      final offers = state.offers
          .where((o) => o.employeeId == engineer.id && o.status == OfferStatus.pending)
          .toList();
      if (offers.length == 1) {
        final project = state.proposals
            .firstWhere((p) => p.id == offers.first.applicationId)
            .project;
        return _PrimaryContext(project: project, pendingOfferCount: 1);
      }
      return _PrimaryContext(pendingOfferCount: offers.length);
    case EmployeeWorkflowState.clientInterviewActionRequired:
      final p = state.proposals.firstWhere(
        (p) =>
            p.engineerId == engineer.id &&
            p.status == ApplicationStatus.active &&
            p.currentStep == SelectionStep.clientInterview,
      );
      return _PrimaryContext(project: p.project);
    case EmployeeWorkflowState.waitingSelectionResult:
      final p = state.proposals.firstWhere(
        (p) => p.engineerId == engineer.id && p.status == ApplicationStatus.active,
      );
      return _PrimaryContext(project: p.project);
    case EmployeeWorkflowState.interviewRequestPending:
      final offer = state.interviewOffers.firstWhere(
        (o) => o.employeeId == engineer.id && o.status == InterviewOfferStatus.pending,
      );
      for (final entry in state.openProjects) {
        if (entry.project.id == offer.projectId) {
          return _PrimaryContext(project: entry.project);
        }
      }
      return const _PrimaryContext();
    case EmployeeWorkflowState.assigned:
    case EmployeeWorkflowState.assignmentScheduled:
    case EmployeeWorkflowState.selling:
    case EmployeeWorkflowState.waiting:
      return const _PrimaryContext();
  }
}

/// 営業・案件 (Phase 2): 「案件を探す画面」から「会社全体の営業活動を把握し、
/// 必要な営業判断へ進む画面」へ。新しい営業ロジックは作らず、既存の
/// [EmployeeWorkflowEngine]/[ProjectComparisonScreen]/[FitBadge] をそのまま
/// 再利用し、「今、誰がどの段階にいるのか」「プレイヤーが今対応すべきものは
/// 何か」を一覧の先頭でまとめて見せる。一覧は状況把握、詳細（営業開始・
/// 面談・オファー回答・比較の実行）は [EngineerDetailScreen]/
/// [ProjectComparisonScreen] に残したまま（責務分離）。
class SalesOverviewScreen extends StatefulWidget {
  const SalesOverviewScreen({super.key});

  @override
  State<SalesOverviewScreen> createState() => _SalesOverviewScreenState();
}

class _SalesOverviewScreenState extends State<SalesOverviewScreen> {
  _SalesFilter _filter = _SalesFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    final workflowStates = {
      for (final e in state.engineers) e.id: EmployeeWorkflowEngine.forEngineer(state, e.id),
    };
    final buckets = {
      for (final e in state.engineers) e.id: _bucketFor(workflowStates[e.id]!),
    };

    int countFor(_SalesBucket b) => buckets.values.where((x) => x == b).length;
    final sellingCount = countFor(_SalesBucket.selling);
    final inSelectionCount = countFor(_SalesBucket.inSelection);
    final offerCount = countFor(_SalesBucket.offer);
    final assignedCount = countFor(_SalesBucket.assigned);

    final actionStates = {
      for (final e in state.engineers) e.id: _actionStateFor(state, e, workflowStates[e.id]!),
    };
    final actionNeeded = state.engineers.where((e) => actionStates[e.id] != null).toList()
      ..sort((a, b) => actionStates[a.id]!.index.compareTo(actionStates[b.id]!.index));

    final pipeline = state.engineers.where((e) {
      final bucket = buckets[e.id];
      if (bucket == null || bucket == _SalesBucket.assigned) return false;
      return switch (_filter) {
        _SalesFilter.all => true,
        _SalesFilter.selling => bucket == _SalesBucket.selling,
        _SalesFilter.inSelection => bucket == _SalesBucket.inSelection,
        _SalesFilter.offer => bucket == _SalesBucket.offer,
      };
    }).toList()..sort((a, b) => workflowStates[a.id]!.index.compareTo(workflowStates[b.id]!.index));

    // 参画中の案件 (§11): [GameState.activeAssignments] alone misses an
    // engineer whose offer was accepted but whose contract hasn't started
    // yet (`assignmentScheduled` — no ActiveAssignment exists for them
    // until then), even though the 参画中 summary count above already
    // includes them. Adding their still-accepted [ProjectProposal] here
    // keeps the count and this list in agreement (Codex review, PR #26).
    // `GameEngine`'s weekly tick removes a proposal from `state.proposals`
    // the moment it actually starts (finalizedProposalIds), so this can
    // never double up with an already-started assignment for the same
    // project.
    final assignmentCards = [
      for (final a in state.activeAssignments)
        _AssignmentCardData(engineerId: a.engineerId, project: a.project, remainingWeeks: a.remainingWeeks),
      for (final p in state.proposals)
        if (p.status == ApplicationStatus.accepted)
          _AssignmentCardData(engineerId: p.engineerId, project: p.project, startWeek: p.assignWeek),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('営業・案件')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          _SalesSummaryCard(
            sellingCount: sellingCount,
            inSelectionCount: inSelectionCount,
            offerCount: offerCount,
            assignedCount: assignedCount,
          ),
          if (actionNeeded.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle('要対応'),
            const SizedBox(height: 8),
            for (final e in actionNeeded)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ActionNeededCard(
                  engineer: e,
                  workflowState: actionStates[e.id]!,
                  primary: _primaryContextFor(state, e, actionStates[e.id]!),
                ),
              ),
          ],
          const SizedBox(height: 18),
          const _SectionTitle('営業状況'),
          const SizedBox(height: 8),
          _SalesFilterRow(
            selected: _filter,
            allCount: sellingCount + inSelectionCount + offerCount,
            sellingCount: sellingCount,
            inSelectionCount: inSelectionCount,
            offerCount: offerCount,
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 10),
          if (pipeline.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('該当する営業案件はありません。', style: TextStyle(color: Colors.black54)),
            )
          else
            for (final e in pipeline)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SalesStatusCard(
                  engineer: e,
                  workflowState: workflowStates[e.id]!,
                  primary: _primaryContextFor(state, e, workflowStates[e.id]!),
                ),
              ),
          if (assignmentCards.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle('参画中の案件'),
            const SizedBox(height: 8),
            for (final a in assignmentCards)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AssignmentCard(data: a),
              ),
          ],
          const SizedBox(height: 18),
          const _SectionTitle('案件を探す'),
          const SizedBox(height: 8),
          const _ExploreProjectsCard(),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold));
}

/// フィルター行と常に同じ4件のカウントを表示する概要カード（§3, §5）。
/// [_SalesOverviewScreenState.build] から渡された値をそのまま表示するだけで、
/// ここで再度カウントし直すことはしない — フィルター行とサマリーが食い違う
/// ことがないようにするため（PR #25 の `_EngineerSummaryCard` と同じ考え方）。
class _SalesSummaryCard extends StatelessWidget {
  const _SalesSummaryCard({
    required this.sellingCount,
    required this.inSelectionCount,
    required this.offerCount,
    required this.assignedCount,
  });

  final int sellingCount;
  final int inSelectionCount;
  final int offerCount;
  final int assignedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: _SummaryMetric('営業中', '$sellingCount名')),
          Expanded(child: _SummaryMetric('選考中', '$inSelectionCount名')),
          Expanded(child: _SummaryMetric('オファー', '$offerCount名')),
          Expanded(child: _SummaryMetric('参画中', '$assignedCount名')),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    );
  }
}

/// すべて/営業中/選考中/オファー の4セグメント（§6）。PR #25の
/// `_EngineerFilterRow`（3チップ・Row+Expanded固定割り）とは違い、[Wrap] で
/// 折り返す — 4チップを均等幅Rowへ詰め込むと360pxで窮屈になるため、収まらな
/// ければ2行目へ流れるだけで、隠れて気づかれない横スクロール領域を作らない。
class _SalesFilterRow extends StatelessWidget {
  const _SalesFilterRow({
    required this.selected,
    required this.allCount,
    required this.sellingCount,
    required this.inSelectionCount,
    required this.offerCount,
    required this.onChanged,
  });

  final _SalesFilter selected;
  final int allCount;
  final int sellingCount;
  final int inSelectionCount;
  final int offerCount;
  final ValueChanged<_SalesFilter> onChanged;

  Widget _chip(BuildContext context, _SalesFilter filter, String label, int count) {
    final isSelected = selected == filter;
    return ChoiceChip(
      label: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : Colors.black87,
        ),
      ),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: SesTheme.primaryBlue,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? SesTheme.primaryBlue : Theme.of(context).colorScheme.outlineVariant,
      ),
      onSelected: (_) => onChanged(filter),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _chip(context, _SalesFilter.all, 'すべて', allCount),
        _chip(context, _SalesFilter.selling, '営業中', sellingCount),
        _chip(context, _SalesFilter.inSelection, '選考中', inSelectionCount),
        _chip(context, _SalesFilter.offer, 'オファー', offerCount),
      ],
    );
  }
}

/// 要対応カード（§4）: [EmployeeWorkflowEngine.requiresAction] が真の社員のみ
/// 対象 — 新しい優先順位判定は行わない。pendingOffers が2件以上ある場合のみ
/// 「案件を比較する」ボタンを強調表示し、既存の [ProjectComparisonScreen] へ
/// 直接遷移する（§9）。
class _ActionNeededCard extends StatelessWidget {
  const _ActionNeededCard({
    required this.engineer,
    required this.workflowState,
    required this.primary,
  });

  final Engineer engineer;
  final EmployeeWorkflowState workflowState;
  final _PrimaryContext primary;

  String get _message => switch (workflowState) {
    EmployeeWorkflowState.finalOfferPending => primary.pendingOfferCount >= 2
        ? 'オファーが${primary.pendingOfferCount}件届いています'
        : 'オファーが届いています',
    EmployeeWorkflowState.clientInterviewActionRequired => '客先面談の対応が必要です',
    EmployeeWorkflowState.interviewRequestPending => '面談依頼が届いています',
    _ => '対応が必要です',
  };

  void _openComparison(BuildContext context) {
    final state = context.game.state;
    final offers = state.offers
        .where((o) => o.employeeId == engineer.id && o.status == OfferStatus.pending)
        .toList();
    final projects = [
      for (final o in offers) state.proposals.firstWhere((p) => p.id == o.applicationId).project,
    ];
    showProjectComparisonScreen(
      context,
      engineer: engineer,
      projects: projects,
      totalCandidates: offers.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCompare = primary.pendingOfferCount >= 2;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EngineerAvatar(applicantType: engineer.profile.type, radius: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  engineer.profile.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_message, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => EngineerDetailScreen(engineerId: engineer.id)),
                  ),
                  child: const Text('社員詳細を見る'),
                ),
              ),
              if (canCompare) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _openComparison(context),
                    child: const Text('案件を比較する'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 営業状況カード（§5, §7）: 社員/案件/顧客/現在状態（[EngineerStatusChip] ―
/// [EmployeeWorkflowEngine] のラベルをそのまま再利用）のみ。粗利・商流・
/// 支払サイト・契約期間・Fit内訳などの詳細は載せない（詳細は
/// [EngineerDetailScreen]/[ProjectComparisonScreen] 側）。Fitを出す場合は
/// 既存の [FitBadge]（◎○△×）のみ、生スコアは出さない（§8）。
class _SalesStatusCard extends StatelessWidget {
  const _SalesStatusCard({
    required this.engineer,
    required this.workflowState,
    required this.primary,
  });

  final Engineer engineer;
  final EmployeeWorkflowState workflowState;
  final _PrimaryContext primary;

  @override
  Widget build(BuildContext context) {
    final project = primary.project;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EngineerDetailScreen(engineerId: engineer.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EngineerAvatar(applicantType: engineer.profile.type, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          engineer.profile.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      EngineerStatusChip(state: workflowState),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    project != null
                        ? project.title
                        : (primary.pendingOfferCount >= 2
                              ? 'オファー${primary.pendingOfferCount}件受領'
                              : '案件未定'),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  if (project != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      clientNameById(project.clientId),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    FitBadge(fit: MatchingEngine.visibleFit(engineer, project)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 参画中の案件カードの表示用データ（§11）。稼働中（[remainingWeeks] あり）
/// か、オファー受諾済みでまだ参画開始前（[startWeek] あり）かのどちらか一方
/// のみが入る — 新しい状態判定ではなく、[GameState.activeAssignments]/
/// `ApplicationStatus.accepted` のどちらの記録から来たかをそのまま運ぶだけ。
class _AssignmentCardData {
  const _AssignmentCardData({
    required this.engineerId,
    required this.project,
    this.remainingWeeks,
    this.startWeek,
  });

  final String engineerId;
  final Project project;
  final int? remainingWeeks;
  final int? startWeek;
}

/// 参画中の案件カード（§11）: 社員画面（誰が参画しているか＝社員中心）とは
/// 逆に、案件名を先頭に置いた案件中心の表示にする。
class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.data});

  final _AssignmentCardData data;

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    final engineer = state.engineerById(data.engineerId);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EngineerDetailScreen(engineerId: data.engineerId)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.project.title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                ),
                if (data.startWeek != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: _StatusTag(text: '参画予定'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Bit(Icons.business_outlined, clientNameById(data.project.clientId)),
                _Bit(Icons.person_outline, engineer.profile.name),
                _Bit(
                  Icons.schedule_outlined,
                  data.remainingWeeks != null ? '残り${data.remainingWeeks}週' : 'Week ${data.startWeek}〜',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: SesTheme.primaryBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: SesTheme.primaryBlue, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Bit extends StatelessWidget {
  const _Bit(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.black54),
        const SizedBox(width: 3),
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}

/// 「案件を探す」導線（§10）: 案件タブを開いた瞬間から市場の全案件を並べる
/// のではなく、末尾に小さく置く。押すと既存の [ProjectListScreen] をそのまま
/// 開く — 検索・営業開始フローは一切変更しない。
class _ExploreProjectsCard extends StatelessWidget {
  const _ExploreProjectsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '市場に公開されている案件を、条件を確認しながら探せます。',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProjectListScreen()),
              ),
              child: const Text('案件一覧を見る'),
            ),
          ),
        ],
      ),
    );
  }
}
