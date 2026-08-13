import 'package:flutter/material.dart';

/// Week-1-only founding guidance (Playable 0.3A §18) — deliberately brief,
/// not a multi-step tutorial: just enough to point the player at what to
/// do before cash runs out.
Future<void> showFoundingTutorialDialog(BuildContext context, {required int waitingCount}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('創業1か月目'),
      content: Text(
        '現在、社員$waitingCount名は案件に参画していません。\n\n'
        'まずは案件を確認し、待機社員を提案してください。\n'
        '現金が尽きると倒産します。',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('案件を見る'),
        ),
      ],
    ),
  );
}
