import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/labels.dart';
import '../widgets/status_chip.dart';

/// 社員詳細 (§19): salary, status, skills, personality, current project,
/// waiting weeks + cost, and (if assigned) the project rate / monthly
/// profit estimate.
class EngineerDetailScreen extends StatelessWidget {
  const EngineerDetailScreen({super.key, required this.engineerId});

  final String engineerId;

  @override
  Widget build(BuildContext context) {
    final state = context.game.state;
    Engineer? engineer;
    for (final e in state.engineers) {
      if (e.id == engineerId) {
        engineer = e;
        break;
      }
    }
    if (engineer == null) {
      return const Scaffold(body: Center(child: Text('社員が見つかりません。')));
    }
    final profile = engineer.profile;
    final assignment = state.assignmentForEngineer(engineerId);
    final proposal = state.proposalForEngineer(engineerId);
    final waitingWeeks = state.waitingStreakFor(engineerId);
    final weeklyCost = (engineer.salary / 4).round();

    return Scaffold(
      appBar: AppBar(title: Text(profile.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              EngineerStatusChip(status: engineer.status),
            ],
          ),
          const SizedBox(height: 12),
          if (engineer.status == EngineerStatus.waiting)
            _WaitingWarningBanner(weeks: waitingWeeks, weeklyCost: weeklyCost),
          _SectionCard(
            title: '基本情報',
            children: [
              _Row('給与', formatYen(engineer.salary)),
              _Row('今週のコスト', formatYen(weeklyCost)),
              _Row('主言語', languageLabels[profile.mainLanguage] ?? profile.mainLanguage.name),
              if (profile.subLanguages.isNotEmpty)
                _Row('副言語', profile.subLanguages.map((l) => languageLabels[l] ?? l.name).join(' / ')),
              _Row('IT経験', formatExperience(profile.totalItExperienceMonths)),
              _Row('日本語', 'Lv.${profile.japaneseLevel}'),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '技術スキル',
            children: [
              _Row('DB', 'Lv.${profile.techSkills.database}'),
              _Row('Network', 'Lv.${profile.techSkills.network}'),
              _Row('Infrastructure', 'Lv.${profile.techSkills.infrastructure}'),
              _Row('Frontend', 'Lv.${profile.techSkills.frontend}'),
              _Row('Backend', 'Lv.${profile.techSkills.backend}'),
              _Row('Leader', 'Lv.${profile.techSkills.leader}'),
              _Row('Manager', 'Lv.${profile.techSkills.manager}'),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '人物パラメータ',
            children: [
              _Row('ルックス', '★' * profile.personality.looks),
              _Row('清潔感', '★' * profile.personality.cleanliness),
              _Row('コミュ力', '★' * profile.personality.communication),
              _Row('アルコール耐性', '★' * profile.personality.alcoholTolerance),
              _Row('真面目度', '★' * profile.personality.seriousness),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '現在の状況',
            children: [
              if (assignment != null) ...[
                _Row('現在案件', assignment.project.title),
                _Row('残り期間', '${assignment.remainingWeeks}週'),
                _Row('案件単価', formatYen(assignment.project.monthlyRate)),
                _Row(
                  '月間想定粗利',
                  formatYen(MatchingEngine.monthlyProfit(engineer, assignment.project)),
                ),
              ] else if (proposal != null) ...[
                _Row('提案先', proposal.project.title),
                _Row(
                  '状況',
                  proposal.stage == ProposalStage.interviewPassed ? '面談合格・参画待ち' : '面談待ち',
                ),
              ] else ...[
                _Row('現在案件', 'なし(待機中)'),
                _Row('待機週数', '$waitingWeeks 週目'),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _WaitingWarningBanner extends StatelessWidget {
  const _WaitingWarningBanner({required this.weeks, required this.weeklyCost});

  final int weeks;
  final int weeklyCost;

  @override
  Widget build(BuildContext context) {
    final critical = weeks >= 3;
    final color = critical ? Colors.red : (weeks >= 2 ? Colors.orange : Colors.blueGrey);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '待機$weeks週目です。今週の給与コスト ${formatYen(weeklyCost)} が発生しています。',
              style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: SesTheme.primaryBlue)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
