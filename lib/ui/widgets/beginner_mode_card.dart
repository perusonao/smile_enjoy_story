import 'package:flutter/material.dart';

import '../../game/game.dart';
import '../theme.dart';
import 'expense_breakdown_sheet.dart';

/// Phase 3A's persistent "初心者経営期間" framing on Home (April-June, week
/// <= [BeginnerModeEngine.lastWeek]): a compact reminder of the current
/// teaching goal plus the handful of cash-flow facts a first-time player
/// most needs — never a second full accounting screen (§16 of the Phase 3A
/// brief: priority order is 1) what to do now, 2) cash / month-end payment,
/// 3) next collection, 4) waiting risk, 5) detail — the last of which stays
/// in [showExpenseBreakdownSheet], one tap away, not duplicated here).
///
/// Everything shown here reads straight from [FinanceEngine] /
/// [BeginnerModeEngine] — no new prediction/accounting logic, and no
/// precise "N.N か月" runway forecast (§10).
class BeginnerModeCard extends StatelessWidget {
  const BeginnerModeCard({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final remainingWeeks = (BeginnerModeEngine.lastWeek - state.week + 1).clamp(0, BeginnerModeEngine.lastWeek);
    final nextAr = BeginnerModeEngine.nextExpectedCollection(state);
    final waitingSalary = BeginnerModeEngine.waitingSalaryTotal(state);
    final waitingCount = state.waitingEngineerCount;
    final runwayLevel = FinanceEngine.classifyRunway(FinanceEngine.cashRunwayMonths(state));
    final runwayColor = RunwayIndicator.colorFor(runwayLevel);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, size: 16, color: Colors.teal),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('初心者経営期間 (4〜6月)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
              Text(
                remainingWeeks > 0 ? 'あと$remainingWeeks週' : '最終週',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // A dynamic "今月の経営ポイント" headline (Phase 3A UX review
          // follow-up), not a static, always-identical blurb — so this card
          // reads as "this week's lesson" instead of blending into the rest
          // of Home as just another fixed info box. Replaces the old static
          // sentence rather than adding to it, so total text length here
          // stays about the same.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(4)),
                child: const Text('POINT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.3)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  BeginnerModeEngine.currentThemeLabel(state),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.teal.shade900, height: 1.25),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'おすすめ行動は強制ではありません。',
            style: TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (nextAr != null)
                _Fact(
                  icon: Icons.schedule,
                  label: '次回入金予定',
                  value: '${formatCompactYen(nextAr.amount)}（${GameCalendar.monthEndLabel(nextAr.dueMonth)}）',
                ),
              if (waitingCount > 0)
                _Fact(
                  icon: Icons.hourglass_bottom,
                  label: '待機社員の給与負担',
                  value: '$waitingCount名 / 月${formatCompactYen(waitingSalary)}',
                ),
              _Fact(
                icon: Icons.shield_outlined,
                label: '資金状況',
                value: RunwayIndicator.qualitativeLabelFor(runwayLevel),
                color: runwayColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value, this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? Colors.black54),
        const SizedBox(width: 4),
        Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
      ],
    );
  }
}
