import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_growth_engine.dart';
import '../../game/public_demo/public_demo_monthly_growth.dart';
import '../widgets/labels.dart';

/// A compact, player-facing summary of a completed Public Demo growth month.
///
/// This deliberately renders only the outcome and its plain-language context.
/// Growth potential, morale multipliers, and SkillSheet values remain private.
class PublicDemoGrowthResultCard extends StatelessWidget {
  const PublicDemoGrowthResultCard({
    super.key,
    required this.engineerName,
    required this.result,
  });

  final String engineerName;
  final PublicDemoMonthlyGrowth result;

  @override
  Widget build(BuildContext context) {
    final language =
        languageLabels[result.primaryLanguage] ?? result.primaryLanguage.name;
    final sourceLabel = switch (result.source) {
      PublicDemoGrowthSource.assignment => '案件参画を通じて成長',
      PublicDemoGrowthSource.internalTraining => '社内研修を通じて成長',
      PublicDemoGrowthSource.externalTraining => '社外研修を通じて成長',
      PublicDemoGrowthSource.waiting => '待機中の自己学習',
    };
    final delta = result.capabilityAfter - result.capabilityBefore;
    return Container(
      key: Key('public-demo-growth-result-${result.engineerId}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            engineerName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '$language ${result.capabilityBefore} → ${result.capabilityAfter}  (+$delta)',
          ),
          if (result.actualExperienceMonthsDelta > 0)
            Text('実務経験 +${result.actualExperienceMonthsDelta}か月'),
          const SizedBox(height: 2),
          Text(sourceLabel, style: Theme.of(context).textTheme.bodySmall),
          if (delta == 0)
            Text('今月は大きな変化なし', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
