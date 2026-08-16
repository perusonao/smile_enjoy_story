import 'package:flutter/material.dart';

import '../../game/game.dart';

/// 創業準備中 → 初案件参画 → 会社経営スタート (Playable 0.4C.3 §10): a coarse,
/// 3-bucket read of company maturity derived from the same
/// [ProgressionEngine]/[FoundingMilestone] facts the guided-founding flow
/// already tracks — no new persisted state.
///
/// Deliberately just an icon + label today (no new large art assets, per
/// §10) but structured so a future office-size illustration can key off the
/// same [CompanyPhase] value without changing any call site.
enum CompanyPhase { preparing, firstAssignment, running }

class CompanyPhaseInfo {
  const CompanyPhaseInfo({required this.phase, required this.label, required this.icon});
  final CompanyPhase phase;
  final String label;
  final IconData icon;
}

CompanyPhaseInfo companyPhaseFor(GameState state) {
  final hasFirstAssignment = state.foundingProgress.has(FoundingMilestone.firstAssignment);
  final freeManagement = ProgressionEngine.currentStage(state) == FoundingStage.freeManagement;
  if (!hasFirstAssignment) {
    return const CompanyPhaseInfo(phase: CompanyPhase.preparing, label: '創業準備中', icon: Icons.home_work_outlined);
  }
  if (!freeManagement) {
    return const CompanyPhaseInfo(phase: CompanyPhase.firstAssignment, label: '初案件参画', icon: Icons.rocket_launch_outlined);
  }
  return const CompanyPhaseInfo(phase: CompanyPhase.running, label: '会社経営スタート', icon: Icons.business_outlined);
}

class CompanyPhaseBanner extends StatelessWidget {
  const CompanyPhaseBanner({super.key, required this.state});
  final GameState state;

  static const _phases = [CompanyPhase.preparing, CompanyPhase.firstAssignment, CompanyPhase.running];

  @override
  Widget build(BuildContext context) {
    final current = companyPhaseFor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(current.icon, size: 16, color: const Color(0xFF1565C0)),
          const SizedBox(width: 6),
          Text(current.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          const Spacer(),
          for (final p in _phases) ...[
            _Dot(filled: p.index <= current.phase.index),
            if (p != _phases.last) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.filled});
  final bool filled;
  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? const Color(0xFF1565C0) : Colors.black12,
    ),
  );
}
