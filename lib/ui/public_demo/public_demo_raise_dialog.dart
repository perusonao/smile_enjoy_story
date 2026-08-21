import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_raise.dart';
import '../../game/public_demo/public_demo_recruitment.dart';

class PublicDemoRaiseDialog extends StatelessWidget {
  const PublicDemoRaiseDialog({super.key, required this.applicant});

  final PublicDemoApplicant applicant;

  @override
  Widget build(BuildContext context) {
    final request = PublicDemoRaiseRequest.forApplicant(applicant);
    Widget choice(PublicDemoRaiseDecision decision, String label) =>
        FilledButton.tonal(
          key: Key('public-demo-raise-${decision.name}'),
          onPressed: () => Navigator.pop(context, decision),
          child: Text(label),
        );
    return AlertDialog(
      title: Text('${applicant.name}さんから昇給の相談'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('入社後の働きぶりを踏まえ、次月以降の給与について相談されています。'),
          const SizedBox(height: 8),
          Text('希望額：月給 ¥${request.requestedMonthlySalary ~/ 10000}万'),
          const SizedBox(height: 12),
          const Text('選択した給与は翌月から反映されます。'),
        ],
      ),
      actions: [
        choice(PublicDemoRaiseDecision.hold, '据え置き'),
        choice(PublicDemoRaiseDecision.smallRaise, '小幅昇給'),
        choice(PublicDemoRaiseDecision.requestedRaise, '希望額で昇給'),
      ],
    );
  }
}
