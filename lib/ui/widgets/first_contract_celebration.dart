import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import 'celebration_fx.dart';

/// The Founding Prologue's flagship success beat (Playable 0.4C.4 §20):
/// company setup → hiring → interview → SkillSheet → sales → client
/// interview → contract all lead here. One shared widget so the scripted
/// Prologue path ([lib/ui/prologue/prologue_screen.dart]'s completion
/// screen) and the "skip the tutorial" path (the `firstAssignmentCelebration`
/// [FoundingEventDialog] in founding_dialogs.dart, for a player who reaches
/// their first assignment without playing the guided Prologue) present the
/// exact same information the exact same way — never a plainer duplicate.
///
/// Deliberately stronger than the regular [OutcomeCard]/[SuccessEntrance]
/// treatment every other success gets (§20-21): this is the one and only
/// confetti moment most playthroughs ever see this early, reserved for a
/// beat that's earned across the entire Prologue, not a single decision.
class FirstContractCelebration extends StatelessWidget {
  const FirstContractCelebration({super.key, required this.assignment, required this.employee, this.showPhaseTransition = true});

  final ActiveAssignment assignment;
  final Engineer employee;

  /// The scripted Prologue's own completion screen already narrates
  /// "会社経営スタート" as a distinct next beat below this card — set false
  /// there to avoid saying it twice in the same scroll.
  final bool showPhaseTransition;

  @override
  Widget build(BuildContext context) {
    final employeeName = employee.profile.name;
    final project = assignment.project;
    final client = FinanceEngine.clientById(project.clientId);
    final profit = MatchingEngine.monthlyProfit(employee, project);
    final paymentTermDays = client.paymentTermDays;
    final generatedMonth = GameCalendar.absoluteMonth(assignment.contractStartWeek);
    final dueMonth = FinanceEngine.dueMonthFor(generatedMonth: generatedMonth, paymentTermDays: paymentTermDays);

    return Stack(
      children: [
        SuccessEntrance(
          duration: const Duration(milliseconds: 520),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.amber.shade50, Colors.green.shade50],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade300, width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🎉 初案件参画！', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                const SizedBox(height: 2),
                Text(
                  'FIRST CONTRACT',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.green.shade700),
                ),
                const SizedBox(height: 10),
                Text('$employeeName さんが「${project.title}」(${client.name})へ参画します。', style: const TextStyle(fontSize: 13.5, height: 1.4)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('月額単価', formatYen(project.monthlyRate)),
                      _row('粗利', '${formatYen(profit)}/月'),
                      _row('支払サイト', '$paymentTermDays日'),
                      _row('初回入金予定', GameCalendar.monthEndLabel(dueMonth)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 15, color: Colors.black54),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '契約成立=即現金増加ではありません。入金は上の初回入金予定まで先になります。',
                          style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showPhaseTransition) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.arrow_circle_right, size: 18, color: SesTheme.primaryBlue),
                      const SizedBox(width: 6),
                      const Text('会社経営スタート', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: SesTheme.primaryBlue)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned.fill(child: ConfettiBurst()),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(width: 96, child: Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.black54))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold))),
      ],
    ),
  );
}
