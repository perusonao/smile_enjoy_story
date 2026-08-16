import 'package:flutter/material.dart';

/// A single, focused confirmation dialog for genuinely irreversible,
/// high-impact player decisions (Playable 0.4C.4 §16) — rejecting a
/// candidate, declining a participation offer, withdrawing from a contract.
/// Deliberately not used for every action: routine choices (asking an
/// interview question, picking a recruitment medium) never go through this,
/// so the game's pace stays intact and this dialog keeps its weight.
Future<bool> confirmIrreversibleAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'キャンセル',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(fontSize: 13.5, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(cancelLabel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
