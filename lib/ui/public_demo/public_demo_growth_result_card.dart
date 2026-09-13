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
          // FIRST-FUN-QUARTER-VISUAL-POLISH P1-D: the text above already
          // states the exact before/after numbers — this bar makes "研修す
          // ると成長する" legible at a glance too, not just to a player who
          // stops to read digits. Reuses the same 0-100 capability scale and
          // fill-bar language [PublicDemoEmployeeSkillBar] already renders
          // on every employee roster row ([_employeeRosterCard] in
          // `public_demo_01_placeholder_screen.dart`), plus a thin marker at
          // the pre-training level so the *gain* — not just the destination
          // — reads visually. Only shown when something actually grew
          // (`delta == 0` keeps its own plain-text "変化なし" line below,
          // unchanged): a flat bar would visually claim a gain that did not
          // happen.
          if (delta > 0) ...[
            const SizedBox(height: 4),
            _CapabilityGrowthBar(
              before: result.capabilityBefore,
              after: result.capabilityAfter,
            ),
          ],
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

/// A 0-100 capability fill bar with a thin marker at [before], so a growth
/// result reads as "grew from here to here" rather than just "is now at
/// this level" — see [PublicDemoGrowthResultCard]'s own doc for why this
/// exists alongside (not instead of) the plain-text before/after line.
class _CapabilityGrowthBar extends StatelessWidget {
  const _CapabilityGrowthBar({required this.before, required this.after});

  final int before;
  final int after;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final beforeFraction = (before / 100).clamp(0.0, 1.0);
    final afterFraction = (after / 100).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 8,
          width: double.infinity,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: afterFraction,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
              Positioned(
                left: (width * beforeFraction - 1).clamp(0.0, width - 2),
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: scheme.onPrimary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
