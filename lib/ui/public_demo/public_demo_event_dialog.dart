import 'package:flutter/material.dart';
import 'package:smile_enjoy_story/ui/widgets/game_event_modal.dart';

class PublicDemoEventDialog extends StatelessWidget {
  const PublicDemoEventDialog({
    super.key,
    required this.title,
    required this.imageAsset,
    required this.message,
    required this.nextAction,
    this.imageKey,
  });

  final String title;
  final String imageAsset;
  final String message;
  final String nextAction;
  final Key? imageKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GameEventModal(
      imageAsset: imageAsset,
      imageKey: imageKey,
      title: title,
      description: message,
      infoSection: Container(
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
      actions: [
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('確認'),
          ),
        ),
      ],
    );
  }
}
