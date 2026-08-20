import 'package:flutter/material.dart';

class PublicDemoSalesProgress extends StatelessWidget {
  const PublicDemoSalesProgress({
    super.key,
    required this.currentStep,
    this.preEntry = false,
  });

  final int currentStep;
  final bool preEntry;

  @override
  Widget build(BuildContext context) {
    final labels = preEntry
        ? const ['準備', '営業', '紹介', '上位面談', '客先面談', '受注']
        : const ['SkillSheet', '営業', '紹介', '上位面談', '客先面談', '受注'];
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('営業進捗', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: i <= currentStep ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${i < currentStep ? '✓ ' : i == currentStep ? '● ' : ''}${labels[i]}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: i == currentStep ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (i != labels.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(Icons.chevron_right, size: 14),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
