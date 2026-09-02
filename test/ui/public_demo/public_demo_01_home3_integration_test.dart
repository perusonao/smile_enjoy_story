import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/home_navigator_section.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/home_office_stage_section.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_home_presentation_components.dart';

PublicDemoState currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

Future<void> pumpDemo(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const PublicDemo01PlaceholderScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> settleDialogImage(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

// PUBLIC-DEMO-HOME-UI-3A: the new bottomNavigationBar shrinks the ListView's
// own visible viewport below the raw physical screen size, so a manual drag
// loop that checked against `tester.view.physicalSize.height` could scroll
// a target directly *behind* the nav bar and still "pass" the bound check
// while the widget was not actually hit-testable there.
// `WidgetController.ensureVisible` scrolls using the real ancestor
// `Scrollable`'s own viewport instead, so it does not have this defect.
Future<void> scrollToVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> tapAndDismissMonthEnd(WidgetTester tester) async {
  final cta = find.byKey(const Key('public-demo-monthly-primary-cta'));
  await scrollToVisible(tester, cta);
  await tester.tap(cta);
  await settleDialogImage(tester);
  await tester.tap(find.widgetWithText(FilledButton, '確認'));
  await tester.pumpAndSettle();
}

int treeIndexOf(WidgetTester tester, Finder finder) {
  final target = finder.evaluate().single;
  final all = find
      .byWidgetPredicate((_) => true)
      .evaluate()
      .toList(growable: false);
  return all.indexOf(target);
}

void main() {
  group('HOME-3 current-main integration', () {
    testWidgets('composes the authoritative HOME sections in reading order', (
      tester,
    ) async {
      await pumpDemo(tester, size: const Size(360, 800));

      // PUBLIC-DEMO-HOME-UI-3A: PublicDemoEmployeeStageSection (the
      // duplicate full-size roster) is deleted — HomeOfficeStageSection is
      // now the only employee-roster presentation on HOME.
      // PublicDemoImportantEventsSection is replaced by
      // PublicDemoImportantTasksSection ("今月の重要タスク"), and
      // PublicDemoQuickAccessSection (section 7) is new.
      final order = [
        find.byType(HomeNavigatorSection),
        find.byType(HomeOfficeStageSection),
        find.byType(PublicDemoImportantTasksSection),
        find.byType(PublicDemoQuickAccessSection),
        find.byType(PublicDemoFinanceSummarySection),
        find.byType(PublicDemoMonthlyPrimaryCtaSection),
      ];
      for (final section in order) {
        expect(section, findsOneWidget);
      }
      for (var i = 1; i < order.length; i++) {
        expect(
          treeIndexOf(tester, order[i - 1]),
          lessThan(treeIndexOf(tester, order[i])),
        );
      }
      // SES-FIRST-FUN-YEAR-UI-PHASE-1: PublicDemoFinanceSummarySection no
      // longer carries cash/nextMonthEstimate — both duplicated the compact
      // KPI, which shows them on every build (see
      // PublicDemoFinanceSummaryModel's class doc). It still carries the
      // two figures the KPI does not: payroll and fixed costs, sourced from
      // the same finance authority as before.
      final finance = tester.widget<PublicDemoFinanceSummarySection>(
        find.byType(PublicDemoFinanceSummarySection),
      );
      expect(finance.summary.payroll, greaterThan(0));
      expect(finance.summary.fixedCosts, greaterThan(0));
      expect(find.text('佐藤 健'), findsWidgets);
      // The Office Stage card is the only roster-like employee summary.
      expect(
        find.descendant(
          of: find.byType(HomeOfficeStageSection),
          matching: find.text('佐藤 健'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the primary Recommended Action remains initially reachable', (
      tester,
    ) async {
      await pumpDemo(tester, size: const Size(360, 800));

      final cta = find.byKey(const Key('home-recommended-action-cta'));
      expect(cta, findsOneWidget);
      final rect = tester.getRect(cta);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(rect.bottom, lessThanOrEqualTo(800));
    });

    testWidgets(
      'the month-end shortcut dispatches its existing April handler once',
      (tester) async {
        await pumpDemo(tester, size: const Size(360, 800));
        expect(currentState(tester).month, 4);

        await tapAndDismissMonthEnd(tester);

        expect(currentState(tester).month, 5);
        expect(
          find.text('5月を終了して6月へ'),
          findsOneWidget,
          reason: 'a single tap must not advance two monthly closes',
        );
      },
    );

    testWidgets(
      'a quick-access item scroll-jumps to its section and preserves state',
      (tester) async {
        await pumpDemo(tester, size: const Size(390, 844));
        await tapAndDismissMonthEnd(tester);
        final before = currentState(tester).toJson();

        final quickAccessFinance = find.byKey(
          const Key('public-demo-quick-access-finance'),
        );
        await scrollToVisible(tester, quickAccessFinance);
        await tester.tap(quickAccessFinance);
        await tester.pumpAndSettle();

        expect(currentState(tester).toJson(), before);
        expect(
          find.byKey(const Key('public-demo-finance-summary')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'an important-task CTA scroll-jumps to the legacy action surface and '
      'preserves state',
      (tester) async {
        await pumpDemo(tester, size: const Size(390, 844));
        final before = currentState(tester).toJson();

        final taskCta = find.widgetWithText(TextButton, '対応する').first;
        await scrollToVisible(tester, taskCta);
        await tester.tap(taskCta);
        await tester.pumpAndSettle();

        expect(currentState(tester).toJson(), before);
      },
    );

    for (final width in [360.0, 390.0]) {
      testWidgets(
        'at ${width.toInt()}px with increased text scale, HOME-3 has no horizontal overflow or clipped labels',
        (tester) async {
          await pumpDemo(tester, size: Size(width, 844), textScale: 1.3);

          for (final text in [
            '今月の重要タスク',
            'クイックアクセス',
            '今月の支出予定',
            '今月の主要行動',
            '給与',
            '固定費',
          ]) {
            final label = find.text(text);
            await tester.ensureVisible(label);
            final rect = tester.getRect(label);
            expect(rect.left, greaterThanOrEqualTo(0), reason: text);
            expect(rect.right, lessThanOrEqualTo(width), reason: text);
          }

          final cta = find.byKey(const Key('public-demo-monthly-primary-cta'));
          await tester.ensureVisible(cta);
          final ctaRect = tester.getRect(cta);
          expect(ctaRect.left, greaterThanOrEqualTo(0));
          expect(ctaRect.right, lessThanOrEqualTo(width));

          for (var i = 0; i < 8; i++) {
            await tester.drag(find.byType(ListView), const Offset(0, -400));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  });
}
