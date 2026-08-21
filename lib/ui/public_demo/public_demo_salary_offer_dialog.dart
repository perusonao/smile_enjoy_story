import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_recruitment.dart';
import '../../game/public_demo/public_demo_salary_offer.dart';

/// Lets the player choose the salary offered after a successful interview.
class PublicDemoSalaryOfferDialog extends StatelessWidget {
  const PublicDemoSalaryOfferDialog({
    super.key,
    required this.applicant,
  });

  final PublicDemoApplicant applicant;

  List<int> get _choices => <int>{
        applicant.requestedMonthlySalary - 40000,
        applicant.requestedMonthlySalary,
        applicant.requestedMonthlySalary + 40000,
      }.where((salary) => salary > 0).toList()..sort();

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('給与を提示'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${applicant.name}さんの希望給与'),
            const SizedBox(height: 4),
            Text(
              '月給 ¥${applicant.requestedMonthlySalary ~/ 10000}万',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text('提示する月給を選んでください。給与は承諾だけでなく、入社後のMotivation / Trustにも影響します。'),
          ],
        ),
        actions: [
          for (final salary in _choices)
            FilledButton.tonal(
              key: Key('public-demo-salary-offer-$salary'),
              onPressed: () => Navigator.of(context).pop(
                PublicDemoSalaryOfferEvaluator.evaluate(
                  applicant: applicant,
                  offeredMonthlySalary: salary,
                ),
              ),
              child: Text('${salary ~/ 10000}万円'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('戻る'),
          ),
        ],
      );
}
