import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/engineer_avatar.dart';
import '../widgets/labels.dart';
import '../widgets/status_chip.dart';
import 'engineer_detail_screen.dart';

String _topTechSkillLabel(TechSkillLevels t) {
  final entries = <String, int>{
    'DB': t.database,
    'Network': t.network,
    'Infra': t.infrastructure,
    'Frontend': t.frontend,
    'Backend': t.backend,
    'Leader': t.leader,
    'Manager': t.manager,
  };
  final best = entries.entries.reduce((a, b) => a.value >= b.value ? a : b);
  if (best.value <= 0) return '-';
  return '${best.key} Lv.${best.value}';
}

/// The 社員 tab's own top filter (Playable "Phase 2: 社員画面のレイアウト改修"
/// §3) — a UI-only view of the same [EngineerStatus] partition
/// [GameState.assignedEngineerCount]/[GameState.waitingEngineerCount]
/// already define, never a second, independently-judged notion of "who's
/// waiting" (§3: "UI側に別の社員状態判定ロジックを二重実装しないでください").
enum _EngineerFilter { all, assigned, waiting }

/// 社員一覧 (Phase 2 §1-2): "誰が参画中で、誰が待機中で、会社全体はどうなって
/// いるか" が一目でわかり、詳しく見たい社員だけ [EngineerDetailScreen] へ進める
/// 画面。一覧はあくまで概要 — スキルシート・営業状況・案件比較などの判断/操作
/// は既存のまま社員詳細に残る（§8-9）。
class EngineerListScreen extends StatefulWidget {
  const EngineerListScreen({super.key});

  @override
  State<EngineerListScreen> createState() => _EngineerListScreenState();
}

class _EngineerListScreenState extends State<EngineerListScreen> {
  _EngineerFilter _filter = _EngineerFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    final engineers = [...state.engineers]
      ..sort((a, b) {
        int rank(EngineerStatus s) => switch (s) {
          EngineerStatus.waiting => 0,
          EngineerStatus.interviewScheduled => 1,
          EngineerStatus.proposed => 2,
          EngineerStatus.assigned => 3,
        };
        return rank(a.status).compareTo(rank(b.status));
      });

    final filtered = switch (_filter) {
      _EngineerFilter.all => engineers,
      _EngineerFilter.assigned =>
        engineers.where((e) => e.status == EngineerStatus.assigned).toList(),
      _EngineerFilter.waiting =>
        engineers.where((e) => e.status == EngineerStatus.waiting).toList(),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('社員')),
      body: engineers.isEmpty
          ? const Center(child: Text('社員がいません。'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Column(
                    children: [
                      _EngineerFilterRow(
                        selected: _filter,
                        allCount: state.engineers.length,
                        assignedCount: state.assignedEngineerCount,
                        waitingCount: state.waitingEngineerCount,
                        onChanged: (f) => setState(() => _filter = f),
                      ),
                      const SizedBox(height: 10),
                      _EngineerSummaryCard(state: state),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('該当する社員がいません。'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) =>
                              _EngineerCard(engineer: filtered[i]),
                        ),
                ),
              ],
            ),
    );
  }
}

/// すべて/参画中/待機中 の3セグメント、各件数付き (§3). Counts come straight
/// from the same [GameState] getters Home's 会社の状況 card already uses, so
/// this row and that card can never disagree.
class _EngineerFilterRow extends StatelessWidget {
  const _EngineerFilterRow({
    required this.selected,
    required this.allCount,
    required this.assignedCount,
    required this.waitingCount,
    required this.onChanged,
  });

  final _EngineerFilter selected;
  final int allCount;
  final int assignedCount;
  final int waitingCount;
  final ValueChanged<_EngineerFilter> onChanged;

  Widget _chip(BuildContext context, _EngineerFilter filter, String label, int count) {
    final isSelected = selected == filter;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: ChoiceChip(
          label: Center(
            child: Text(
              '$label $count',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
          selected: isSelected,
          showCheckmark: false,
          selectedColor: SesTheme.primaryBlue,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: isSelected
                ? SesTheme.primaryBlue
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          onSelected: (_) => onChanged(filter),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(context, _EngineerFilter.all, 'すべて', allCount),
        _chip(context, _EngineerFilter.assigned, '参画中', assignedCount),
        _chip(context, _EngineerFilter.waiting, '待機中', waitingCount),
      ],
    );
  }
}

/// フィルター下のコンパクトなサマリー (§4): 人数系（社員数/参画中/待機中/稼働
/// 率）と Morale/Trust の平均を別の行に分け、360pxでも詰め込みすぎない構成に
/// する。稼働率の計算そのものは [GameState.utilizationPercent] のまま — Home
/// 改修で表示先を失っていたのをこの画面へ移すだけで、ロジックは変更しない。
class _EngineerSummaryCard extends StatelessWidget {
  const _EngineerSummaryCard({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _SummaryMetric('社員数', '${state.engineers.length}名')),
              Expanded(child: _SummaryMetric('参画中', '${state.assignedEngineerCount}名')),
              Expanded(child: _SummaryMetric('待機中', '${state.waitingEngineerCount}名')),
              Expanded(child: _SummaryMetric('稼働率', '${state.utilizationPercent}%')),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: Colors.black12),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _SummaryMetric('平均Morale', '${state.averageMorale}')),
              Expanded(child: _SummaryMetric('平均Trust', '${state.averageCompanyTrust}')),
            ],
          ),
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

/// 一覧カード (§5, §8): P0（顔・氏名・現在状態）と P1（主要スキル・現在案件・
/// 顧客・契約終了まで）のみ。営業状況の詳細（並行営業数・オファー詳細・選考
/// ステップ）と案件比較は [EngineerDetailScreen] 側に残したまま、ここへ移植
/// しない（§8-9）。現在状態は [EngineerStatusChip] 一枚に集約し、参画中/待機
/// 中はもちろん営業中/面談中/オファー待ちなども含めて色・ラベルとも
/// [EmployeeWorkflowEngine]/[status_chip.dart] の一箇所だけに従う（§7）。
class _EngineerCard extends StatelessWidget {
  const _EngineerCard({required this.engineer});

  final Engineer engineer;

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    final profile = engineer.profile;
    final workflowState = EmployeeWorkflowEngine.forEngineer(state, engineer.id);
    // "Idle" (red tint / border) means truly nothing is happening — not
    // merely unassigned. An employee who's selling, has a pending
    // interview request, or is mid-selection is doing something, and the
    // waiting-weeks badge is shown alongside that instead of being hidden
    // behind it (Playable 0.4C.3 §41-43).
    final isIdle = workflowState == EmployeeWorkflowState.waiting;
    final waitingWeeks = state.waitingStreakFor(engineer.id);
    final assignment = state.assignmentForEngineer(engineer.id);

    final waitingColor = waitingWeeks >= 3
        ? Colors.red
        : (waitingWeeks >= 2 ? Colors.orange : null);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EngineerDetailScreen(engineerId: engineer.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isIdle ? Colors.red.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isIdle
                ? Colors.red.withValues(alpha: 0.4)
                : Theme.of(context).colorScheme.outlineVariant,
            width: isIdle ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EngineerAvatar(applicantType: profile.type),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          profile.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                        ),
                      ),
                      if (waitingWeeks > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _WaitingBadge(weeks: waitingWeeks, color: waitingColor),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: EngineerStatusChip(state: workflowState),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${languageLabels[profile.mainLanguage] ?? profile.mainLanguage.name} / ${_topTechSkillLabel(profile.techSkills)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                  if (assignment != null) ...[
                    const SizedBox(height: 6),
                    _InfoLine(
                      icon: Icons.work_outline,
                      label: '案件',
                      value: assignment.project.title,
                    ),
                    _InfoLine(
                      icon: Icons.business_outlined,
                      label: '顧客',
                      value: clientNameById(assignment.project.clientId),
                    ),
                    _InfoLine(
                      icon: Icons.schedule_outlined,
                      label: '契約終了まで',
                      value: '${assignment.remainingWeeks}週',
                    ),
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

/// 案件/顧客/契約終了までの1行 (§5, §13): ラベル+値を1本の [Text.rich] に
/// して、長い案件名・顧客名でも `overflow: ellipsis` だけで確実に折り返さず
/// 収まるようにする（固定幅の2カラムレイアウトは長い文字列で崩れやすいため
/// あえて避けている）。
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      children: [
        Icon(icon, size: 13, color: Colors.black45),
        const SizedBox(width: 4),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$label  ', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    ),
  );
}

class _WaitingBadge extends StatelessWidget {
  const _WaitingBadge({required this.weeks, required this.color});

  final int weeks;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '待機$weeks週目',
        style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}
