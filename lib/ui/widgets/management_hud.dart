import 'package:flutter/material.dart';

import '../../game/game.dart';
import '../theme.dart';
import 'expense_breakdown_sheet.dart';

/// Persistent, always-visible strip across every tab (Playable 0.4C.3 §2):
/// Week / cash / headcount / month-end cash forecast, so "how is my company
/// doing right now" never requires leaving whatever screen the player is on.
///
/// Deliberately a single slim row — this is a glance-only summary, not a
/// second accounting screen. Full detail (AR, this month's inflow/outflow,
/// runway) stays in [showExpenseBreakdownSheet], which tapping this strip
/// opens.
class ManagementHud extends StatelessWidget {
  const ManagementHud({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final projected = FinanceEngine.projectedMonthEndCash(state);
    final level = FinanceEngine.classifyRunway(FinanceEngine.cashRunwayMonths(state));
    final forecast = _ForecastStyle.forLevel(level);

    return Semantics(
      container: true,
      label: '経営状況 WEEK ${state.displayWeek} 現預金 ${formatCompactYen(state.company.cash)} '
          '社員 ${state.engineers.length}人 月末予想 ${formatCompactYen(projected)} ${forecast.label}',
      // The label above already gives a screen reader the whole row in one
      // clean sentence — without this, InkWell's default merge-descendants
      // behavior would additionally announce every child Text a second time
      // (e.g. "...WEEK 1..." then, separately, "WEEK 1 350万円 2人...").
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => showExpenseBreakdownSheet(context, state),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
            ),
            child: Row(
              children: [
                _HudItem(
                  child: Text(
                    'WEEK ${state.displayWeek}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ),
                _divider(),
                _HudItem(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.payments_outlined, size: 14, color: SesTheme.primaryBlue),
                      const SizedBox(width: 3),
                      Text(
                        formatCompactYen(state.company.cash),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                _divider(),
                _HudItem(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.groups_outlined, size: 14, color: Colors.black54),
                      const SizedBox(width: 3),
                      Text(
                        '${state.engineers.length}人',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                _divider(),
                Expanded(
                  flex: 2,
                  child: _HudItem(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(forecast.icon, size: 14, color: forecast.color),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '月末予想 ${formatCompactYen(projected)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: forecast.color),
                          ),
                        ),
                        if (forecast.suffix != null) ...[
                          const SizedBox(width: 2),
                          Text(forecast.suffix!, style: TextStyle(fontSize: 12, color: forecast.color)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _divider() => Container(
    width: 1,
    height: 16,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: Colors.black12,
  );
}

class _HudItem extends StatelessWidget {
  const _HudItem({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => FittedBox(fit: BoxFit.scaleDown, child: child);
}

/// Icon + short text + color for a runway level — color is never the only
/// signal (Playable 0.4C.3 §2, §15).
class _ForecastStyle {
  const _ForecastStyle({required this.icon, required this.color, required this.label, this.suffix});

  final IconData icon;
  final Color color;
  final String label;
  final String? suffix;

  static _ForecastStyle forLevel(RunwayLevel level) => switch (level) {
    RunwayLevel.safe => const _ForecastStyle(
      icon: Icons.check_circle_outline,
      color: Color(0xFF2E7D32),
      label: '安全',
    ),
    RunwayLevel.caution => _ForecastStyle(
      icon: Icons.info_outline,
      color: Colors.orange.shade800,
      label: '注意',
      suffix: '⚠',
    ),
    RunwayLevel.danger => _ForecastStyle(
      icon: Icons.error_outline,
      color: Colors.red.shade700,
      label: '危険',
      suffix: '⚠',
    ),
  };
}
