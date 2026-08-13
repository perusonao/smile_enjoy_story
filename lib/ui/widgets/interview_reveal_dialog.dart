import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../../game/game.dart';

enum InterviewDecision { reject, hire }

/// 面接結果モーダル (§12): reveals the locked personality stats + a short
/// résumé-trust read, then lets the player decide on the spot. Returns the
/// player's choice (or null if dismissed) so the caller can sequence the
/// follow-up offer-result dialog without racing this one.
Future<InterviewDecision?> showInterviewResultDialog(
  BuildContext context,
  Applicant applicant,
) {
  final pt = applicant.personality;
  return showDialog<InterviewDecision>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('面接結果'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(applicant.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            _StarRow('コミュ力', pt.communication),
            _StarRow('清潔感', pt.cleanliness),
            _StarRow('真面目度', pt.seriousness),
            _StarRow('嘘つき度', pt.dishonesty),
            _StarRow('アルコール耐性', pt.alcoholTolerance),
            const SizedBox(height: 10),
            const Text('経歴書評価', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            const SizedBox(height: 2),
            Text(
              RecruitmentEngine.trustAssessment(applicant),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(InterviewDecision.reject),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('不採用'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(InterviewDecision.hire),
          child: const Text('採用する'),
        ),
      ],
    ),
  );
}

class _StarRow extends StatelessWidget {
  const _StarRow(this.label, this.level);

  final String label;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(label, style: const TextStyle(fontSize: 12.5))),
          Text('★' * level, style: const TextStyle(color: Colors.amber, fontSize: 13)),
          Text('☆' * (5 - level), style: const TextStyle(color: Colors.black26, fontSize: 13)),
        ],
      ),
    );
  }
}
