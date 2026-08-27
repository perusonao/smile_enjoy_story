import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/game_scope.dart';
import '../theme.dart';

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    final state = controller.state;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3F3),
      appBar: AppBar(
        title: const Text('倒産'),
        backgroundColor: Colors.red.shade700,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 40),
                SizedBox(height: 8),
                Text(
                  '倒産しました',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ResultRow('倒産週', 'Week ${state.bankruptWeek ?? state.displayWeek}'),
          _ResultRow('最終資金', formatYen(state.company.cash)),
          _ResultRow('最終技術者数', '${state.engineers.length}名'),
          _ResultRow('待機人数', '${state.waitingEngineerCount}名'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('原因', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(state.bankruptCause ?? '資金がマイナスになりました。'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: controller.playtestLogJson()),
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('プレイログをコピーしました。')));
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
