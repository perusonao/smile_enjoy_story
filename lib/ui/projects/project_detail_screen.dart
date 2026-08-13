import 'package:flutter/material.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import '../widgets/fit_badge.dart';
import '../widgets/labels.dart';
import '../widgets/proposal_confirm_dialog.dart';

class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    this.preferredEmployeeId,
  });

  final String projectId;
  final String? preferredEmployeeId;

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    final state = controller.state;

    ProjectEntry? entry;
    for (final e in state.openProjects) {
      if (e.project.id == projectId) {
        entry = e;
        break;
      }
    }
    if (entry == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    final project = entry.project;
    final open = state.isProjectOpenForProposal(project.id);
    final waitingEngineers =
        state.engineers
            .where((e) => e.status != EngineerStatus.assigned)
            .toList()
          ..sort(
            (a, b) => MatchingEngine.computeFit(
              b,
              project,
            ).total.compareTo(MatchingEngine.computeFit(a, project).total),
          );
    if (preferredEmployeeId != null) {
      waitingEngineers.sort((a, b) {
        if (a.id == preferredEmployeeId) return -1;
        if (b.id == preferredEmployeeId) return 1;
        return MatchingEngine.computeFit(
          b,
          project,
        ).total.compareTo(MatchingEngine.computeFit(a, project).total);
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(project.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _SectionCard(
            title: '案件概要',
            children: [
              _Row('取引先', clientNameById(project.clientId)),
              _Row('種別', projectTypeLabels[project.type] ?? project.type.name),
              _Row('ランク', projectRankLabels[project.rank] ?? project.rank.name),
              _Row('月単価', formatYen(project.monthlyRate)),
              _Row('支払サイト', '${paymentTermDaysById(project.clientId)}日'),
              _Row('契約期間', '${project.durationWeeks}週間'),
              _Row('応募締切', 'Week ${project.applicationDeadlineWeek}'),
              _Row('面談回数', '${project.interviewCount}回'),
              _Row('競争度', '★' * project.competitionLevel),
              _Row(
                '選考フロー',
                project.selectionFlow.steps
                    .map((step) => selectionStepLabels[step]!)
                    .join(' → '),
              ),
              _Row(
                '自社応募',
                '${state.proposals.where((p) => p.project.id == project.id && p.isActive).length}名',
              ),
              _Row('勤務形態', remotePolicyLabels[project.remotePolicy] ?? ''),
              _Row('難易度', '★' * project.difficulty),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '求めるスキル',
            children: [
              _Row(
                '必要言語',
                project.requiredLanguages.isEmpty
                    ? '不問'
                    : project.requiredLanguages
                          .map((l) => languageLabels[l] ?? l.name)
                          .join(' / '),
              ),
              _Row('DB', 'Lv.${project.requiredDatabase}'),
              _Row('Network', 'Lv.${project.requiredNetwork}'),
              _Row('Infrastructure', 'Lv.${project.requiredInfrastructure}'),
              _Row('Frontend', 'Lv.${project.requiredFrontend}'),
              _Row('Backend', 'Lv.${project.requiredBackend}'),
              _Row('Leader', 'Lv.${project.requiredLeader}'),
              _Row('Manager', 'Lv.${project.requiredManager}'),
              _Row('日本語レベル', 'Lv.${project.requiredJapaneseLevel}'),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('待機社員から提案', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              if (open && waitingEngineers.isNotEmpty)
                Text(
                  '比較して選べます',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!open)
            _InfoBox(text: 'この案件は現在提案できません(選考中、または募集終了)。')
          else if (waitingEngineers.isEmpty)
            _InfoBox(text: '待機中の社員がいません。採用してから提案しましょう。')
          else
            for (final engineer in waitingEngineers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CandidateCard(engineer: engineer, project: project),
              ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(text),
    );
  }
}

class _CandidateCard extends StatefulWidget {
  const _CandidateCard({required this.engineer, required this.project});

  final Engineer engineer;
  final Project project;

  @override
  State<_CandidateCard> createState() => _CandidateCardState();
}

class _CandidateCardState extends State<_CandidateCard> {
  bool _expanded = false;

  Future<void> _propose(BuildContext context) async {
    final controller = context.game;
    final confirmed = await showProposalConfirmDialog(
      context,
      engineer: widget.engineer,
      project: widget.project,
    );
    if (!confirmed || !context.mounted) return;
    controller.proposeEngineer(widget.engineer.id, widget.project.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.engineer.profile.name} を提案しました。')),
    );
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final engineer = widget.engineer;
    final project = widget.project;
    final profile = engineer.profile;
    final fit = MatchingEngine.computeFit(engineer, project);
    final visibleFit = PlayerVisibleFit.fromScore(fit.total);
    final profit = MatchingEngine.monthlyProfit(engineer, project);
    final profitColor = profit >= 0
        ? Colors.green.shade700
        : Colors.red.shade700;
    final state = context.game.state;
    final slots = state.activeProposalCountFor(engineer.id);
    final canPropose = state.canPropose(engineer.id, project.id);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              FitBadge(fit: visibleFit),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _Bit(
                Icons.code,
                languageLabels[profile.mainLanguage] ??
                    profile.mainLanguage.name,
              ),
              _Bit(
                Icons.timelapse,
                formatExperience(profile.totalItExperienceMonths),
              ),
              _Bit(Icons.payments_outlined, formatYen(engineer.salary)),
              _Bit(
                Icons.workspaces_outline,
                '並行営業 $slots / $maxParallelProposalsPerEmployee',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                '月間想定粗利  ',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              Text(
                '${profit >= 0 ? '+' : ''}${formatYen(profit)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: profitColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text(
                  _expanded ? '内訳を閉じる' : 'Fitの内訳を見る',
                  style: const TextStyle(
                    fontSize: 12,
                    color: SesTheme.primaryBlue,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: SesTheme.primaryBlue,
                ),
              ],
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  for (final detail in fit.details)
                    Text(
                      '${fitDetailLabel(detail)}: ${detail.rating.symbol}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canPropose ? () => _propose(context) : null,
              child: Text(canPropose ? '提案する' : '提案枠がありません'),
            ),
          ),
        ],
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
        Icon(icon, size: 14, color: Colors.black54),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 12.5)),
      ],
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
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: SesTheme.primaryBlue,
            ),
          ),
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
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
