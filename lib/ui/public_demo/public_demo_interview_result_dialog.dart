import 'package:flutter/material.dart';

class PublicDemoInterviewResultDialog extends StatelessWidget {
  const PublicDemoInterviewResultDialog({
    super.key,
    required this.interviewName,
    required this.personName,
    required this.score,
    required this.passed,
    required this.points,
    required this.nextAction,
  });

  final String interviewName;
  final String personName;
  final int score;
  final bool passed;
  final List<String> points;
  final String nextAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('$interviewName 結果'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(personName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  passed ? Icons.check_circle : Icons.cancel,
                  color: passed ? scheme.primary : scheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  passed ? '通過' : '不合格',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: passed ? scheme.primary : scheme.error,
                      ),
                ),
                const Spacer(),
                Text(
                  '$score点',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('評価ポイント', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (final point in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('・$point'),
              ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('次の行動', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(nextAction),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('確認'),
        ),
      ],
    );
  }
}
