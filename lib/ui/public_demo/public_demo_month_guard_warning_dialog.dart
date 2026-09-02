import 'package:flutter/material.dart';

import '../../game/public_demo/public_demo_month_guard.dart';

/// Issue #119 PLAYTHROUGH-BLOCKER-1: shown at a month-close attempt when the
/// Domain-owned Month Guard names outstanding `recommended`-level actions —
/// never for `required` ones, which block the close entirely before this
/// dialog is ever reached (see `july()`'s own guard check).
///
/// Two ways out, matching Issue #119's acceptance criteria:
///  * `タスクを確認` (default-emphasized): cancels the close. The month does
///    not advance, so every action this dialog just named is still exactly
///    where it was — "returns the player to an actionable state" needs no
///    extra navigation, because nothing here ever left that state.
///  * `このまま月末処理を進める`: proceeds anyway. Recommended items may
///    always be bypassed, unlike required ones.
class PublicDemoMonthGuardWarningDialog extends StatelessWidget {
  const PublicDemoMonthGuardWarningDialog({super.key, required this.items});

  /// Every `recommended`-level item outstanding for this close attempt.
  /// Never empty — the caller only shows this dialog when it isn't.
  final List<PublicDemoMonthGuardItem> items;

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('public-demo-month-guard-warning-dialog'),
    title: const Text('未対応のタスクがあります'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('月末処理を進める前に、次の行動が残っています。'),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('・'),
                  Expanded(child: Text(item.message)),
                ],
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        key: const Key('public-demo-month-guard-proceed'),
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('このまま月末処理を進める'),
      ),
      FilledButton(
        key: const Key('public-demo-month-guard-review'),
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('タスクを確認'),
      ),
    ],
  );
}
