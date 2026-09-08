import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../../game/public_demo/public_demo_project_generator.dart';
import '../widgets/labels.dart';
import 'public_demo_sales_visual.dart';

/// CORE-GAMEPLAY Phase 5 (Matching): one 案件カード for [candidate] — the
/// project-card fields the Issue requires (project name, monthly rate,
/// required skills/technologies, required experience, difficulty/rank,
/// payment term, client tendency), read straight through to
/// [PublicDemoProjectCandidate]'s own getters (themselves straight reads of
/// the real Phase 4 [Project]/[Client] — see that file's own doc). Nothing
/// here computes or invents a project fact.
class PublicDemoMatchingProjectCard extends StatelessWidget {
  const PublicDemoMatchingProjectCard({
    super.key,
    required this.candidate,
    required this.onTap,
  });

  final PublicDemoProjectCandidate candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final requiredDomains = _requiredDomainLabels(candidate.project);
    return PublicDemoSalesCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    candidate.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: PublicDemoSalesStatusBadge(
                    label:
                        projectRankLabels[candidate.rank] ??
                        candidate.rank.name,
                    tone: PublicDemoSalesStatusTone.inProgress,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _fact(context, '月額 ${candidate.monthlyRate ~/ 10000}万円'),
                _fact(
                  context,
                  '必要経験 ${formatExperience(candidate.requiredExperienceMonths)}',
                ),
                _fact(context, '難易度 ${candidate.difficulty}'),
                _fact(context, '支払サイト ${candidate.project.paymentTermDays}日'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '必要スキル: ${_requiredLanguageLabels(candidate.project)}'
              '${requiredDomains.isEmpty ? '' : ' / $requiredDomains'}',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              '取引先: ${candidate.clientName}'
              '（${clientSpecialtyLabels[candidate.clientTendency] ?? candidate.clientTendency.name}）',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  static String _requiredLanguageLabels(Project project) {
    if (project.requiredLanguages.isEmpty) return '指定なし';
    return project.requiredLanguages
        .map((language) => languageLabels[language] ?? language.name)
        .join('・');
  }

  static String _requiredDomainLabels(Project project) {
    final entries = <(String label, int level)>[
      ('DB', project.requiredDatabase),
      ('NW', project.requiredNetwork),
      ('インフラ', project.requiredInfrastructure),
      ('フロント', project.requiredFrontend),
      ('バック', project.requiredBackend),
      ('リーダー', project.requiredLeader),
      ('マネージャ', project.requiredManager),
    ];
    return entries
        .where((entry) => entry.$2 > 0)
        .map((entry) => '${entry.$1}Lv.${entry.$2}')
        .join('・');
  }

  Widget _fact(BuildContext context, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: const TextStyle(fontSize: 11.5)),
  );
}
