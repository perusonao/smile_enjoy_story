import 'package:flutter/material.dart';

import '../../game/game.dart';
import '../theme.dart';

/// Priority order (highest first) for picking which of this week's events
/// to show when there are more than [_maxLines] of them (§22).
const List<GameLogCategory> _importanceOrder = [
  GameLogCategory.bankrupt,
  GameLogCategory.gameFinished,
  GameLogCategory.contractEnded,
  GameLogCategory.assignmentStarted,
  GameLogCategory.interviewPassed,
  GameLogCategory.interviewFailed,
  GameLogCategory.offerAccepted,
  GameLogCategory.offerDeclined,
  GameLogCategory.engineerJoined,
  GameLogCategory.applicantsArrived,
  GameLogCategory.newProjects,
  GameLogCategory.listingExpired,
];

const int _maxLines = 6;

/// "Week N 開始" summary shown right after 次の週へ (§22), so the player
/// sees what changed before deciding what to do this week.
Future<void> showWeekSummaryDialog(BuildContext context, GameState state) {
  final thisWeekEvents = state.events.where((e) => e.week == state.week).toList()
    ..sort((a, b) {
      final ai = a.category == null ? _importanceOrder.length : _importanceOrder.indexOf(a.category!);
      final bi = b.category == null ? _importanceOrder.length : _importanceOrder.indexOf(b.category!);
      return ai.compareTo(bi);
    });
  final shown = thisWeekEvents.take(_maxLines).toList();
  final more = thisWeekEvents.length - shown.length;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('Week ${state.displayWeek} 開始'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('今週の変化', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            if (shown.isEmpty)
              const Text('特に大きな変化はありませんでした。', style: TextStyle(color: Colors.black54, fontSize: 13))
            else
              ...shown.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3, right: 6),
                        child: Icon(Icons.circle, size: 6, color: SesTheme.primaryBlue),
                      ),
                      Expanded(child: Text(e.message, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ),
            if (more > 0)
              Text('ほか$more件', style: const TextStyle(fontSize: 12, color: Colors.black45)),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('今週を始める'),
        ),
      ],
    ),
  );
}
