import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/game_scope.dart';
import '../theme.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    final state = controller.state;
    final stats = state.stats;
    final rank = controller.rank;

    return Scaffold(
      appBar: AppBar(title: const Text('経営結果')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [SesTheme.primaryBlue, SesTheme.accentCyan],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  '26週間の経営が終了しました',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  rank.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text('ランク', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ResultRow('最終資金', formatYen(state.company.cash)),
          _ResultRow('累計売上', formatYen(stats.cumulativeRevenue)),
          _ResultRow('累計給与', formatYen(stats.cumulativeSalary)),
          _ResultRow('利益', formatYen(stats.cumulativeProfit)),
          _ResultRow('社員数', '${state.engineers.length}名'),
          _ResultRow('稼働人数', '${state.assignedEngineerCount}名'),
          _ResultRow('稼働率', '${state.utilizationPercent}%'),
          _ResultRow('採用人数', '${stats.hires}名'),
          _ResultRow('案件参画成功数', '${stats.assignmentsStarted}件'),
          _ResultRow('待機延べ週', '${stats.waitingWeeks}週'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: controller.playtestLogJson()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('プレイログをコピーしました。')),
                );
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('プレイログ(JSON)をコピー'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => controller.restart(),
              icon: const Icon(Icons.replay),
              label: const Text('もう一度プレイする'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
