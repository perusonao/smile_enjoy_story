// Issue #148 Phase 1B.3 (HOME-COMPACT-1B.3): connects the existing
// confirmed-information cash forecast (PublicDemoCashForecast, PR #153)
// through the existing presentation/advice layer
// (PublicDemoCashStatusPresentation, PublicDemoCashAdviceSelector, both
// PR #154) into the Navigator card on the real HOME screen.
//
// This suite never touches the forecast/status/advice models' own logic —
// it drives the real screen through a real gameplay trajectory and asserts
// only what the Navigator card shows as a result, per Issue #148 Phase
// 1B.3's own scope:
//
//  * a preventive window (financialStatus still `normal`, but the forecast
//    already sees a future month go cash-negative) surfaces the forecast's
//    reason and a next action inside the Navigator — no separate, large
//    standalone card;
//  * once an actual cashShortage/bankruptcy is reached, the existing strong
//    leads (PublicDemoCashShortageCard, the bankruptcy terminal card, and
//    the existing `cashShortageResponse` recommended-action candidate) are
//    not duplicated by this new forecast-based advice;
//  * a healthy month (April start) shows no cash warning at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/asset_paths.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

PublicDemoState currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

Finder actionButton(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

/// Mirrors the existing Public Demo widget suites' own helper: buttons that
/// open an event dialog first await a real image decode, which this SDK
/// only completes on the wall clock.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> tapAndSettle(WidgetTester tester, String text) async {
  final finder = actionButton(text);
  for (var i = 0; finder.evaluate().isEmpty && i < 20; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  expect(finder, findsWidgets, reason: 'Could not find action button: $text');
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await settle(tester);
  if (text == 'SkillSheet確認') {
    await tester.tap(find.widgetWithText(FilledButton, '内容を確認'));
    await tester.pumpAndSettle();
  }
  final monthGuardProceed = find.byKey(
    const Key('public-demo-month-guard-proceed'),
  );
  if (monthGuardProceed.evaluate().isNotEmpty) {
    await tester.tap(monthGuardProceed);
    await tester.pumpAndSettle();
  }
}

Future<void> dismiss(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, '確認'));
  await tester.pumpAndSettle();
}

Future<void> pumpDemo(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: PublicDemo01PlaceholderScreen()),
  );
  await tester.pumpAndSettle();
}

/// April: Sato wins the May order — the shared opening of the existing
/// playthrough suites (verbatim from public_demo_01_home_consolidation_test
/// .dart), reused here so this suite drives the exact same, already-pinned
/// structurally-insolvent trajectory.
Future<void> playApril(WidgetTester tester) async {
  await tapAndSettle(tester, 'SkillSheet確認');
  await tapAndSettle(tester, '営業開始');
  await tapAndSettle(tester, '案件紹介');
  await tapAndSettle(tester, '上位会社面談');
  await dismiss(tester);
  await tapAndSettle(tester, '客先面談');
  await dismiss(tester);
  await tapAndSettle(tester, '受注');
  await dismiss(tester);
}

/// Drives the same CASH SHORTAGE-closing-September trajectory
/// public_demo_01_home_consolidation_test.dart's group 19 pins, but stops
/// one close earlier — right after September closes (state.month == 10,
/// financialStatus still `normal`) instead of after October closes (where
/// that suite's own trajectory reaches financialStatus == cashShortage).
/// This is Issue #148 Phase 1B.3's preventive window: the real close that
/// will go cash-negative has not happened yet, but the confirmed-
/// information forecast already sees it coming.
Future<void> playToPreShortageWindow(WidgetTester tester) async {
  await playApril(tester);
  await tapAndSettle(tester, '4月を終了して5月へ');
  await dismiss(tester);
  await tapAndSettle(tester, '5月を終了して6月へ');
  await settle(tester);
  await tapAndSettle(tester, '6月を終了して7月へ');
  await settle(tester);
  await tapAndSettle(tester, '7月を終了して8月へ');
  await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
  await tester.pumpAndSettle();
  await tapAndSettle(tester, '7月を終了して8月へ');
  await settle(tester);
  await tapAndSettle(tester, '8月を終了して翌月へ');
  await settle(tester);
  await tapAndSettle(tester, '9月を終了して翌月へ');
  await settle(tester);
}

void main() {
  group('preventive window: financialStatus is still normal', () {
    testWidgets('the Navigator shows the forecasted shortage month, a caution '
        'expression, and a next action — with no duplicate large card', (
      tester,
    ) async {
      await pumpDemo(tester);
      await playToPreShortageWindow(tester);

      // The real trajectory this mirrors (group 19 in
      // public_demo_01_home_consolidation_test.dart) reaches
      // financialStatus == cashShortage only after October's close — one
      // step past where this test stops. Confirms the scenario is
      // genuinely the preventive window, not an already-realized shortage.
      expect(
        currentState(tester).financialStatus,
        PublicDemoFinancialStatus.normal,
      );
      expect(currentState(tester).month, 10);

      // No duplicate strong lead: the real shortage/bankruptcy cards are
      // for an already-realized financialStatus, which this state is not.
      expect(
        find.byKey(const Key('public-demo-cash-shortage-card')),
        findsNothing,
      );

      // The forecast's own reason (which month) is stated verbatim.
      expect(find.textContaining('10月に資金がマイナスになる見込みです'), findsOneWidget);

      // A caution expression — the same artwork the existing
      // cashShortageResponse/caution path already uses.
      final portrait = tester.widget<Image>(
        find.byKey(const Key('home-navigator-portrait')),
      );
      expect(
        (portrait.image as AssetImage).assetName,
        AssetPaths.navigatorCaution,
      );

      // A next action is offered — either the resolved advice candidate's
      // CTA, or (when none is currently valid) the finance-detail
      // fallback. Either way there is exactly one CTA in the slot, and it
      // is tappable without throwing.
      final cta = find.byKey(const Key('home-recommended-action-cta'));
      expect(cta, findsOneWidget);
      expect(tester.widget<FilledButton>(cta).onPressed, isNotNull);
    });

    testWidgets('a healthy April start shows no cash warning at all', (
      tester,
    ) async {
      await pumpDemo(tester);

      expect(
        currentState(tester).financialStatus,
        PublicDemoFinancialStatus.normal,
      );
      expect(find.textContaining('資金がマイナスになる見込みです'), findsNothing);
      expect(
        find.byKey(const Key('public-demo-cash-shortage-card')),
        findsNothing,
      );
      // The ordinary next action (April's SkillSheet confirmation) still
      // owns the slot, unchanged.
      expect(
        find.byKey(const Key('home-recommended-action-headline')),
        findsOneWidget,
      );
    });
  });

  group('an already-realized shortage is never duplicated', () {
    testWidgets(
      'once financialStatus flips to cashShortage, the forecast-based '
      'caution message is suppressed — the existing shortage card is the '
      'sole strong lead',
      (tester) async {
        await pumpDemo(tester);
        await playToPreShortageWindow(tester);
        await tapAndSettle(tester, '10月を終了して翌月へ');
        await settle(tester);

        expect(
          currentState(tester).financialStatus,
          PublicDemoFinancialStatus.cashShortage,
        );

        // The existing strong lead renders exactly once...
        expect(
          find.byKey(const Key('public-demo-cash-shortage-card')),
          findsOneWidget,
        );
        // ...and this feature's own forecast-based message never appears
        // alongside it — no duplicate cash lead.
        expect(find.textContaining('資金がマイナスになる見込みです'), findsNothing);
      },
    );
  });
}
