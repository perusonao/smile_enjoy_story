// Issue #168 (FIRST-FUN-YEAR-ONBOARDING-1) Finding D: the internal-training
// card used to state only "社内研修 ¥30,000" — no explanation of who it is
// for, when its cost is charged, when its effect lands, or that it must be
// selected again each month. This pins the new, truthful explanatory line
// added to `internalTrainingCard()`, and that it renders without overflow at
// both required widths. Every fact the new copy states is already true and
// already authoritative elsewhere (`PublicDemoInternalTrainingTransaction`,
// `PublicDemoGrowthEngine`) — this test does not assert any new domain
// behavior, only that the existing facts are now visible on screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_tab_test_helpers.dart';

const _explanation =
    '待機中の社員が対象です。費用は選択時に発生し、効果は月末に反映されます'
    '（毎月選び直しが必要です）。';

void main() {
  for (final size in [const Size(360, 800), const Size(390, 844)]) {
    testWidgets(
      'internal training card explains who/cost-timing/effect-timing/'
      're-selection at ${size.width.toInt()}x${size.height.toInt()}, no '
      'overflow',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          const MaterialApp(home: PublicDemo01PlaceholderScreen()),
        );
        await tester.pumpAndSettle();
        // Fresh April: eng-01 (Sato)'s own training card is reachable on 社員
        // (PUBLIC-DEMO-HOME-UI-3B moved employee detail off HOME).
        await switchPublicDemoTab(tester, PublicDemoTab.employees);

        final card = find.byKey(
          const Key('public-demo-internal-training-eng-01'),
        );
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();

        expect(card, findsOneWidget);
        expect(
          find.descendant(of: card, matching: find.text(_explanation)),
          findsOneWidget,
        );
        // Deliberately makes no claim about a specific capability gain,
        // success rate, or guaranteed sales-eligibility outcome — none of
        // those are safe to state as a fixed number (see Finding B's own
        // lock-banner copy, which already establishes training is never
        // guaranteed to arrive in time for a given engineer's sales window).
        expect(
          find.descendant(of: card, matching: find.textContaining('%')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.textContaining('必ず営業可能'),
          ),
          findsNothing,
        );

        final rect = tester.getRect(card);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
