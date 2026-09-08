import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../../game/models/fit_result.dart';
import '../../game/public_demo/public_demo_engineer_runtime.dart';
import '../../game/public_demo/public_demo_matching_fit.dart';
import '../../game/public_demo/public_demo_matching_proposal.dart';
import '../../game/public_demo/public_demo_project_generator.dart';
import '../../game/public_demo/public_demo_sales.dart';
import '../theme.dart';
import '../widgets/fit_badge.dart';
import '../widgets/labels.dart';

/// CORE-GAMEPLAY Phase 5 (Matching Decision Gameplay): the player-facing
/// flow `案件を見る → 社員を選ぶ → スキルシートを見る → 強み/不足を見る →
/// 提案する/見送る`.
///
/// Every project/engineer/fit value shown anywhere in this file is read
/// verbatim from an already-computed, authoritative source the caller
/// supplies (Phase 4's real seeded [PublicDemoProjectCandidate]s, and
/// [PublicDemoEngineerProjectFit] — itself a thin reshaping of
/// [MatchingEngine.computeFit]'s own result). Nothing here invents a
/// project/engineer value or a second matching formula.
///
/// Two full pushed screens (mirrors the main game's own
/// `ProjectComparisonScreen`/`project_list_screen.dart` precedent — never a
/// desktop-style wide table) plus, for the strengths/gaps + propose/pass
/// step, an inline expansion under the tapped engineer row rather than a
/// second stacked modal, so "スキルシートを見る" can reuse the existing
/// [PublicDemoSkillSheetSheet] bottom sheet without nesting one modal
/// inside another.
class PublicDemoProjectMatchingScreen extends StatelessWidget {
  const PublicDemoProjectMatchingScreen({
    super.key,
    required this.candidates,
    required this.availableEngineers,
    required this.runtimeFor,
    required this.proposalFor,
    required this.fitFor,
    required this.onViewSkillSheet,
    required this.onPropose,
  });

  /// Real Phase 4 seeded projects for the current month
  /// ([PublicDemoAggregate.projectCandidatesForMonth]) — this screen
  /// invents no project of its own.
  final List<PublicDemoProjectCandidate> candidates;

  /// Engineers currently eligible for this decision
  /// ([PublicDemoAggregate.availableEngineersForMatching]).
  final List<PublicDemoEngineerSales> availableEngineers;
  final PublicDemoEngineerRuntime? Function(String engineerId) runtimeFor;
  final PublicDemoMatchingProposal? Function(String engineerId) proposalFor;
  final PublicDemoEngineerProjectFit Function(
    PublicDemoEngineerRuntime runtime,
    PublicDemoProjectCandidate candidate,
  )
  fitFor;
  final Future<void> Function(PublicDemoEngineerSales engineer)
  onViewSkillSheet;
  final void Function(String engineerId, String projectId) onPropose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('public-demo-project-matching-screen'),
      appBar: AppBar(title: const Text('案件を見る')),
      body: candidates.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '今月、閲覧できる案件がありません。',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              key: const Key('public-demo-project-matching-list'),
              padding: const EdgeInsets.all(12),
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                return _ProjectCard(
                  key: Key('public-demo-project-matching-card-${candidate.id}'),
                  candidate: candidate,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PublicDemoMatchingEngineerScreen(
                        candidate: candidate,
                        engineers: availableEngineers,
                        runtimeFor: runtimeFor,
                        proposalFor: proposalFor,
                        fitFor: fitFor,
                        onViewSkillSheet: onViewSkillSheet,
                        onPropose: onPropose,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// A single Phase 4 project's truthful decision-relevant facts — Issue
/// #205's own required field list, each read straight from [candidate]/its
/// underlying [Project]/[Client] (Phase 4's own "thin projection" — nothing
/// duplicated or invented here either).
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({super.key, required this.candidate, required this.onTap});

  final PublicDemoProjectCandidate candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final project = candidate.project;
    final requiredSkills = _requiredSkillLabels(project);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                candidate.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                '月額 ${formatYen(candidate.monthlyRate)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: SesTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _InfoChip(
                    label: projectRankLabels[candidate.rank] ?? candidate.rank.name,
                  ),
                  _InfoChip(label: '難易度 ${candidate.difficulty}'),
                  _InfoChip(
                    label: '必要経験 ${formatExperience(candidate.requiredExperienceMonths)}',
                  ),
                  _InfoChip(label: '支払サイト ${project.paymentTermDays}日'),
                  _InfoChip(
                    label:
                        clientSpecialtyLabels[candidate.clientTendency] ??
                        candidate.clientTendency.name,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                requiredSkills.isEmpty ? '必須スキル: 指定なし' : '必須スキル: $requiredSkills',
                style: const TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _requiredSkillLabels(Project project) {
    final parts = <String>[
      for (final language in project.requiredLanguages)
        languageLabels[language] ?? language.name,
      if (project.requiredDatabase > 0) 'DB Lv.${project.requiredDatabase}',
      if (project.requiredNetwork > 0) 'Network Lv.${project.requiredNetwork}',
      if (project.requiredInfrastructure > 0)
        'Infra Lv.${project.requiredInfrastructure}',
      if (project.requiredFrontend > 0) 'Frontend Lv.${project.requiredFrontend}',
      if (project.requiredBackend > 0) 'Backend Lv.${project.requiredBackend}',
      if (project.requiredLeader > 0) 'Leader Lv.${project.requiredLeader}',
      if (project.requiredManager > 0) 'Manager Lv.${project.requiredManager}',
    ];
    return parts.join(' / ');
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11.5)),
    );
  }
}

/// Step 2/3/4 of the flow: pick an employee, inspect strengths/gaps
/// (`fitFor`) and the SkillSheet, then propose or pass — all for the one
/// [candidate] this screen was opened for.
class PublicDemoMatchingEngineerScreen extends StatefulWidget {
  const PublicDemoMatchingEngineerScreen({
    super.key,
    required this.candidate,
    required this.engineers,
    required this.runtimeFor,
    required this.proposalFor,
    required this.fitFor,
    required this.onViewSkillSheet,
    required this.onPropose,
  });

  final PublicDemoProjectCandidate candidate;
  final List<PublicDemoEngineerSales> engineers;
  final PublicDemoEngineerRuntime? Function(String engineerId) runtimeFor;
  final PublicDemoMatchingProposal? Function(String engineerId) proposalFor;
  final PublicDemoEngineerProjectFit Function(
    PublicDemoEngineerRuntime runtime,
    PublicDemoProjectCandidate candidate,
  )
  fitFor;
  final Future<void> Function(PublicDemoEngineerSales engineer)
  onViewSkillSheet;
  final void Function(String engineerId, String projectId) onPropose;

  @override
  State<PublicDemoMatchingEngineerScreen> createState() =>
      _PublicDemoMatchingEngineerScreenState();
}

class _PublicDemoMatchingEngineerScreenState
    extends State<PublicDemoMatchingEngineerScreen> {
  String? _expandedEngineerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('public-demo-matching-engineer-screen'),
      appBar: AppBar(title: Text('社員を選ぶ：${widget.candidate.title}')),
      body: widget.engineers.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '現在、検討できる社員がいません（全員が案件に参画中です）。',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              key: const Key('public-demo-matching-engineer-list'),
              padding: const EdgeInsets.all(12),
              itemCount: widget.engineers.length,
              itemBuilder: (context, index) {
                final engineer = widget.engineers[index];
                final runtime = widget.runtimeFor(engineer.id);
                final expanded = _expandedEngineerId == engineer.id;
                return Card(
                  key: Key('public-demo-matching-engineer-card-${engineer.id}'),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          engineer.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(engineer.summary),
                        trailing: runtime == null
                            ? null
                            : _ProspectChip(
                                prospect: widget
                                    .fitFor(runtime, widget.candidate)
                                    .prospect,
                              ),
                        onTap: () => setState(() {
                          _expandedEngineerId = expanded ? null : engineer.id;
                        }),
                      ),
                      if (expanded && runtime != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: _MatchDecisionPanel(
                            key: Key('public-demo-match-decision-${engineer.id}'),
                            engineer: engineer,
                            candidate: widget.candidate,
                            fit: widget.fitFor(runtime, widget.candidate),
                            existingProposal: widget.proposalFor(engineer.id),
                            onViewSkillSheet: () =>
                                widget.onViewSkillSheet(engineer),
                            onPass: () =>
                                setState(() => _expandedEngineerId = null),
                            onPropose: () {
                              widget.onPropose(engineer.id, widget.candidate.id);
                              setState(() {});
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Steps 3 ("強み/不足を見る") and 4 ("提案する/見送る") for one
/// engineer/project pair.
class _MatchDecisionPanel extends StatelessWidget {
  const _MatchDecisionPanel({
    super.key,
    required this.engineer,
    required this.candidate,
    required this.fit,
    required this.existingProposal,
    required this.onViewSkillSheet,
    required this.onPass,
    required this.onPropose,
  });

  final PublicDemoEngineerSales engineer;
  final PublicDemoProjectCandidate candidate;
  final PublicDemoEngineerProjectFit fit;
  final PublicDemoMatchingProposal? existingProposal;
  final VoidCallback onViewSkillSheet;
  final VoidCallback onPass;
  final VoidCallback onPropose;

  @override
  Widget build(BuildContext context) {
    final details = fit.visibleDetails;
    final positives = <FitDetailItem>[];
    final cautions = <FitDetailItem>[];
    for (final item in details) {
      switch (item.rating) {
        case PlayerVisibleFit.excellent:
        case PlayerVisibleFit.good:
          positives.add(item);
        case PlayerVisibleFit.fair:
        case PlayerVisibleFit.poor:
          cautions.add(item);
      }
    }
    final alreadyProposedHere = existingProposal?.projectId == candidate.id;
    final alreadyProposedElsewhere =
        existingProposal != null && !alreadyProposedHere;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '面談通過見込み',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              const SizedBox(width: 8),
              _ProspectChip(prospect: fit.prospect),
            ],
          ),
          if (positives.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              '良い点',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
            ),
            for (final item in positives) _ReasonLine(item: item),
          ],
          if (cautions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              '注意点',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.deepOrange,
              ),
            ),
            for (final item in cautions) _ReasonLine(item: item),
          ],
          if (alreadyProposedHere) ...[
            const SizedBox(height: 10),
            const Text(
              'この案件へ提案済みです。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ] else if (alreadyProposedElsewhere) ...[
            const SizedBox(height: 10),
            const Text(
              '既に他の案件へ提案中です。提案すると内容が置き換わります。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            key: Key('public-demo-matching-view-skillsheet-${engineer.id}'),
            onPressed: onViewSkillSheet,
            child: const Text('スキルシートを見る'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: Key('public-demo-matching-pass-${engineer.id}'),
                  onPressed: onPass,
                  child: const Text('見送る'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: Key('public-demo-matching-propose-${engineer.id}'),
                  onPressed: alreadyProposedHere ? null : onPropose,
                  child: Text(alreadyProposedHere ? '提案済み' : '提案する'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One 良い点/注意点 bullet line — mirrors [FitReasonSheet]'s own
/// `_ReasonLine` exactly (same [fitDetailLabel] reuse, same wording shape),
/// just for the Public Demo [PublicDemoEngineerProjectFit.visibleDetails]
/// subset instead of the main game's full [FitBreakdown.details].
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

/// A small 高/中/低 chip for [PublicDemoMatchingProspect] — the same visual
/// language as [FitBadge], but for this file's own coarse prospect tier
/// rather than a [PlayerVisibleFit].
class _ProspectChip extends StatelessWidget {
  const _ProspectChip({required this.prospect});

  final PublicDemoMatchingProspect prospect;

  @override
  Widget build(BuildContext context) {
    final color = switch (prospect) {
      PublicDemoMatchingProspect.high => Colors.blue,
      PublicDemoMatchingProspect.medium => Colors.orange,
      PublicDemoMatchingProspect.low => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        prospect.label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
