import 'package:flutter/material.dart';

import '../widgets/game_event_modal.dart';

/// SES_PUBLIC-DEMO-INTRO-1A — the one-time fresh-start intro.
///
/// Resolves READINESS-2A's FINDING-2 (no first-time onboarding): a fresh
/// player is told, once, who they play (会社の社長), the objective
/// (grow engineers into billable sales without running out of cash), the
/// time structure (April start, monthly progression, March fiscal year
/// end), and the failure condition (sustained cash shortage → bankruptcy).
/// It closes by pointing at the existing Recommended Action card
/// ("次にやること" — quoted verbatim from
/// `recommended_action_section.dart`'s own eyebrow label) as the first
/// concrete action, rather than re-describing or renaming it.
///
/// Deliberately presentation-only: this widget takes no parameters, reads
/// no game state, and owns no persisted flag. The caller
/// (`PublicDemo01PlaceholderScreen`) decides *when* to show it, entirely
/// from the existing "was a save restored" signal it already computes —
/// see that screen's `_showFreshStartIntroIfNeeded`. Nothing here can
/// duplicate or drift from a KPI, cash figure, or month value, because it
/// never reads one.
class PublicDemoIntroDialog extends StatelessWidget {
  const PublicDemoIntroDialog({super.key});

  static const String _body =
      'あなたはこの会社の社長です。技術者を育成・営業して案件を受注し、'
      '会社の売上を伸ばしていきましょう。\n\n'
      '4月に創業し、毎月経営を進めます。翌年3月の決算までに資金が不足した'
      '状態が続くと、倒産してプレイは終了します。\n\n'
      'まずは「次にやること」カードの案内に沿って、最初の操作を進めましょう。';

  @override
  Widget build(BuildContext context) {
    return GameEventModal(
      key: const Key('public-demo-intro-dialog'),
      title: 'ようこそ、S.E.S.へ',
      description: _body,
      barrierDismissible: false,
      actions: [
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const Key('public-demo-intro-dialog-confirm'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('はじめる'),
          ),
        ),
      ],
    );
  }
}
