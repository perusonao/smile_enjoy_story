import 'package:flutter/material.dart';

/// 内定承諾/辞退モーダル (§13).
Future<void> showOfferResultDialog(
  BuildContext context, {
  required bool accepted,
  required String name,
  int? joinWeek,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(accepted ? '内定承諾' : '内定辞退'),
      content: Text(
        accepted
            ? '$name さんが内定を承諾しました。\n\n入社予定: Week $joinWeek'
            : '今回は他社へ入社することになりました。',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}
