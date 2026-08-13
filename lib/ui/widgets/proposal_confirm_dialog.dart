import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../../game/game.dart';
import '../theme.dart';
import 'fit_badge.dart';
import 'labels.dart';

/// 提案確認モーダル (§11): shows who, where, the Fit rating, and the
/// estimated monthly profit before actually submitting the proposal.
Future<bool> showProposalConfirmDialog(
  BuildContext context, {
  required Engineer engineer,
  required Project project,
}) async {
  final fit = MatchingEngine.visibleFit(engineer, project);
  final profit = MatchingEngine.monthlyProfit(engineer, project);
  final profitColor = profit >= 0 ? Colors.green.shade700 : Colors.red.shade700;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('この案件へ提案しますか？'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(engineer.profile.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.arrow_forward, size: 14, color: Colors.black45),
              const SizedBox(width: 4),
              Expanded(child: Text(project.title)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('案件適性: ', style: TextStyle(fontSize: 13)),
              FitBadge(fit: fit),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('月間想定粗利: ', style: TextStyle(fontSize: 13)),
              Text(
                '${profit >= 0 ? '+' : ''}${formatYen(profit)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: profitColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('選考', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(project.selectionFlow.steps.map((step) => selectionStepLabels[step]!).join('\n↓\n')),
          const SizedBox(height: 6),
          const Text('選考は週ごとに進行します。', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('提案する'),
        ),
      ],
    ),
  );
  return result ?? false;
}
