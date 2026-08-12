import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/game_scope.dart';
import '../../domain/domain.dart';
import '../theme.dart';
import '../widgets/labels.dart';

class OthersScreen extends StatelessWidget {
  const OthersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.game;
    final state = controller.state;

    return Scaffold(
      appBar: AppBar(title: const Text('その他')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          _SectionCard(
            title: '会社情報',
            children: [
              _Row('会社名', state.company.name),
              _Row('資金', formatYen(state.company.cash)),
              _Row('信用', '${state.company.credit}'),
              _Row('Seed', '${state.seed}'),
            ],
          ),
          const SizedBox(height: 14),
          Text('取引先', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final client in sampleClients)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ClientCard(
                client: client,
                known: state.company.clientIds.contains(client.id),
              ),
            ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'デバッグ / プレイテスト',
            children: [
              const Text(
                'ここまでのプレイログをJSON形式でコピーできます。',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: controller.playtestLogJson()),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('プレイログをコピーしました。')),
                    );
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('プレイログをコピー'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'セーブデータ',
            children: [
              const Text(
                'このゲームは端末のローカルストレージに自動保存されます。',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmRestart(context),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('最初からやり直す'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmRestart(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('最初からやり直しますか？'),
        content: const Text('現在の進行状況は失われます。新しい seed でゲームを開始します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.game.restart();
            },
            child: const Text('やり直す'),
          ),
        ],
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client, required this.known});

  final Client client;
  final bool known;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  clientSpecialtyLabels[client.specialty] ?? client.specialty.name,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (known)
            const Icon(Icons.handshake_outlined, color: SesTheme.primaryBlue, size: 20),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, color: SesTheme.primaryBlue),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
