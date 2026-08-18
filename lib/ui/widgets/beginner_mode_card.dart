import 'package:flutter/material.dart';

import '../../game/game.dart';
import '../theme.dart';

/// Phase 3A's persistent "今月の経営ポイント" framing on Home (April-June,
/// week <= [BeginnerModeEngine.lastWeek]): a compact, education-only
/// reminder of what a first-time player should be paying attention to this
/// week — not a second data/accounting display. Two of the three cash-flow
/// facts this card used to repeat (待機社員の給与負担, 資金状況) are gone —
/// they now live exactly once each, via [TaskEngine]'s waiting notices and
/// Home's own "会社の状況" 資金余命 (Home layout整理 §3-4, §11).
///
/// 次回入金予定 stays (Codex review on PR #22, confirmed real: no other
/// screen shows the *specific* soonest-due [AccountsReceivable] entry —
/// [TaskEngine] has no collection task, and the 資金状況 sheet only shows
/// the aggregate 売掛金 balance, not which entry is due when). Removing it
/// would have silently dropped the Phase 3A brief's "3) 次回入金" teaching
/// priority instead of just de-duplicating it, so it's the one fact kept
/// here rather than moved elsewhere.
///
/// [BeginnerModeEngine.currentThemeLabel]/[BeginnerModeEngine.nextExpectedCollection]
/// read straight off [BeginnerModeEngine]/[FinanceEngine] state — no new
/// judgment logic lives in this widget, and the theme strings themselves
/// are unchanged from Phase 3A.
class BeginnerModeCard extends StatelessWidget {
  const BeginnerModeCard({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final remainingWeeks = (BeginnerModeEngine.lastWeek - state.week + 1).clamp(0, BeginnerModeEngine.lastWeek);
    final nextAr = BeginnerModeEngine.nextExpectedCollection(state);

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
          // follow-up, extended by Home layout整理 §3): not a static,
          // always-identical blurb — this card reads as "this week's
          // lesson" instead of blending into the rest of Home as just
          // another fixed info box. [BeginnerModeEngine.currentThemeLabel]
          // supplies the one-line body; the heading itself never changes,
          // so a future Phase 3B-1 theme label can plug into the same slot
          // without any layout change here.
          const Text(
            '今月の経営ポイント',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.teal, letterSpacing: 0.3),
          ),
          const SizedBox(height: 2),
          Text(
            BeginnerModeEngine.currentThemeLabel(state),
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.teal.shade900, height: 1.25),
          ),
          const SizedBox(height: 3),
          const Text(
            'おすすめ行動は強制ではありません。',
            style: TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
          if (nextAr != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule, size: 13, color: Colors.black54),
                const SizedBox(width: 4),
                const Text('次回入金予定: ', style: TextStyle(fontSize: 11, color: Colors.black54)),
                Expanded(
                  child: Text(
                    '${formatCompactYen(nextAr.amount)}（${GameCalendar.monthEndLabel(nextAr.dueMonth)}）',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
