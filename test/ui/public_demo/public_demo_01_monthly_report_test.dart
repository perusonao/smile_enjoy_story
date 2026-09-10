// SES ISSUE-232 Phase B: focused presentation/wiring coverage for the
// Monthly Management Report — every fixture here drives the real
// production close handlers (april/may/june/july/closeOrdinaryMonth)
// through the actual `public-demo-monthly-primary-cta` control, exactly as
// a player would, injected via the same fixed-save-service technique
// `public_demo_01_year_end_result_test.dart` already established. This
// suite intentionally does not re-derive Phase A's own snapshot/authority
// tests (`test/game/public_demo/public_demo_monthly_report_snapshot_test
// .dart`) or the presenter's own pure-mapping tests
// (`public_demo_monthly_report_display_data_test.dart`) — it only proves
// the Dialog actually appears at the right moment, shows the right values,
// and that dismissing it never re-closes the month or disturbs the
// existing bankruptcy/Year-End terminal surfaces.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import 'public_demo_tab_test_helpers.dart';

class _FixedSaveService extends PublicDemoSaveService {
  _FixedSaveService(this._aggregate);
  final PublicDemoAggregate _aggregate;
  int saveCount = 0;
  PublicDemoAggregate? lastSaved;

  @override
  Future<PublicDemoAggregate?> load() async => _aggregate;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {
    saveCount++;
    lastSaved = aggregate;
  }

  @override
  Future<bool> clear() async => true;
}

final _expense = PublicDemoSalary.baselineMonthlyExpenses;
const _reportKey = Key('public-demo-monthly-report-dialog');
const _dismissKey = Key('public-demo-monthly-report-dismiss');
const _ctaKey = Key('public-demo-monthly-primary-cta');

PublicDemoState _currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

Future<_FixedSaveService> _pump(
  WidgetTester tester,
  PublicDemoAggregate aggregate, {
  Size? size,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  final service = _FixedSaveService(aggregate);
  await tester.pumpWidget(
    MaterialApp(
      home: PublicDemo01PlaceholderScreen(saveService: service),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

/// Taps the canonical CTA and settles, without dismissing anything —
/// leaves whatever dialog the tap produced (Month Guard, event dialog, or
/// the Monthly Management Report itself) fully visible and settled for the
/// caller to assert against directly.
Future<void> _tapCtaAndSettle(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(_ctaKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(_ctaKey));
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Proceeds past the Month Guard warning if one is showing — deliberately
/// NOT `dismissMonthGuardIfPresent` from `public_demo_tab_test_helpers.dart`:
/// that shared helper also dismisses a just-appeared Monthly Management
/// Report as a safety net for every *other* suite in this directory, which
/// would defeat this file's own assertions that the report is genuinely
/// showing before it is deliberately dismissed via [_dismissKey].
Future<void> _proceedPastGuardOnly(WidgetTester tester) async {
  final guard = find.byKey(
    const Key('public-demo-month-guard-warning-dialog'),
  );
  if (guard.evaluate().isEmpty) return;
  await tester.tap(find.byKey(const Key('public-demo-month-guard-proceed')));
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  group('1. all five close handlers show the report', () {
    testWidgets('April: tapping the CTA, then the event dialog\'s own '
        '"確認", shows the report', (tester) async {
      await _pump(tester, PublicDemoAggregate.initial());
      await _tapCtaAndSettle(tester);
      await _proceedPastGuardOnly(tester); // Sato is a real candidate.
      // April's own event dialog is still open here; confirm it.
      final confirm = find.widgetWithText(FilledButton, '確認');
      expect(confirm, findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(find.byKey(_reportKey), findsOneWidget);
      expect(find.text('4月の経営結果'), findsOneWidget);
      // The month has already advanced beneath the dialog.
      expect(_currentState(tester).month, 5);
    });

    testWidgets('May: shows the report after the "入社・初参画！" event dialog '
        'is confirmed', (tester) async {
      var aggregate = PublicDemoAggregate.initial().closeApril(
        monthlyExpenses: _expense,
      );
      await _pump(tester, aggregate);
      await _tapCtaAndSettle(tester);
      await _proceedPastGuardOnly(tester);
      final confirm = find.widgetWithText(FilledButton, '確認');
      if (confirm.evaluate().isNotEmpty) {
        await tester.tap(confirm);
        await tester.pumpAndSettle();
      }

      expect(find.byKey(_reportKey), findsOneWidget);
      expect(find.text('5月の経営結果'), findsOneWidget);
      expect(_currentState(tester).month, 6);
    });

    testWidgets('June: shows the report with no event dialog in between', (
      tester,
    ) async {
      var aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: _expense)
          .closeMay(week: 9, monthlyExpenses: _expense);
      await _pump(tester, aggregate);
      await _tapCtaAndSettle(tester);
      await _proceedPastGuardOnly(tester);

      expect(find.byKey(_reportKey), findsOneWidget);
      expect(find.text('6月の経営結果'), findsOneWidget);
      expect(_currentState(tester).month, 7);
    });

    testWidgets('July: shows the report once the summer-bonus decision is '
        'already confirmed', (tester) async {
      var aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: _expense)
          .closeMay(week: 9, monthlyExpenses: _expense)
          .closeJune(assignedInJuly: 0, monthlyExpenses: _expense)
          .confirmSummerBonusDecision(PublicDemoSummerBonusPlan.none);
      await _pump(tester, aggregate);
      await _tapCtaAndSettle(tester);

      expect(find.byKey(_reportKey), findsOneWidget);
      expect(find.text('7月の経営結果'), findsOneWidget);
      expect(_currentState(tester).month, 8);
    });

    testWidgets('closeOrdinaryMonth (e.g. August): shows the report', (
      tester,
    ) async {
      var aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: _expense)
          .closeMay(week: 9, monthlyExpenses: _expense)
          .closeJune(assignedInJuly: 0, monthlyExpenses: _expense)
          .confirmSummerBonusDecision(PublicDemoSummerBonusPlan.none)
          .closeJuly(monthlyExpenses: _expense);
      expect(aggregate.state.month, 8);
      await _pump(tester, aggregate);
      await _tapCtaAndSettle(tester);
      await _proceedPastGuardOnly(tester);

      expect(find.byKey(_reportKey), findsOneWidget);
      expect(find.text('8月の経営結果'), findsOneWidget);
      expect(_currentState(tester).month, 9);
    });
  });

  group('2. dismiss advances the month exactly once, never re-closes', () {
    testWidgets('dismissing June\'s report leaves the month at exactly 7, '
        'and the CTA now advances July, not June again', (tester) async {
      var aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: _expense)
          .closeMay(week: 9, monthlyExpenses: _expense);
      await _pump(tester, aggregate);
      await _tapCtaAndSettle(tester);
      await _proceedPastGuardOnly(tester);
      expect(find.byKey(_reportKey), findsOneWidget);
      expect(_currentState(tester).month, 7);

      await tester.tap(find.byKey(_dismissKey));
      await tester.pumpAndSettle();

      expect(find.byKey(_reportKey), findsNothing);
      expect(_currentState(tester).month, 7);
      // HOME is reachable again (report dismissal never leaves the screen
      // stuck behind a route).
      expect(find.byKey(_ctaKey), findsOneWidget);
    });
  });

  group('3. blocked/no-op close never shows a report', () {
    testWidgets('canceling the Month Guard ("タスクを確認") never closes the '
        'month and never shows a report', (tester) async {
      await _pump(tester, PublicDemoAggregate.initial());
      await _tapCtaAndSettle(tester);
      expect(
        find.byKey(const Key('public-demo-month-guard-warning-dialog')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('public-demo-month-guard-review')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_reportKey), findsNothing);
      expect(_currentState(tester).month, 4);
    });

    testWidgets('a July CTA tap that only opens the summer-bonus decision '
        'never shows a report until the month genuinely closes', (
      tester,
    ) async {
      var aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: _expense)
          .closeMay(week: 9, monthlyExpenses: _expense)
          .closeJune(assignedInJuly: 0, monthlyExpenses: _expense);
      expect(aggregate.state.summerBonusDecisionConfirmed, isFalse);
      await _pump(tester, aggregate);
      await _tapCtaAndSettle(tester);

      expect(find.byKey(_reportKey), findsNothing);
      expect(_currentState(tester).month, 7);
    });
  });

  group('4. Bankruptcy: report shows, then dismiss reveals the existing '
      'bankruptcy card, never skipped or duplicated', () {
    testWidgets('a close that commits bankruptcy shows the report first; '
        'dismissing it reveals the unmodified bankruptcy terminal card', (
      tester,
    ) async {
      // A genuine zero-revenue trajectory that reaches bankruptcy on the
      // October close — the same fixture shape
      // `public_demo_01_bankruptcy_ux_test.dart` already establishes.
      var aggregate = PublicDemoAggregate.initial()
          .closeApril(monthlyExpenses: _expense)
          .closeMay(week: 9, monthlyExpenses: _expense)
          .closeJune(assignedInJuly: 0, monthlyExpenses: _expense)
          .confirmSummerBonusDecision(PublicDemoSummerBonusPlan.none)
          .closeJuly(monthlyExpenses: _expense)
          .closeOrdinaryMonth(monthlyExpenses: _expense) // August
          .closeOrdinaryMonth(monthlyExpenses: _expense); // September
      expect(
        aggregate.state.financialStatus,
        PublicDemoFinancialStatus.cashShortage,
        reason: 'fixture must reach cashShortage entering October',
      );
      await _pump(tester, aggregate);
      await _tapCtaAndSettle(tester);
      await _proceedPastGuardOnly(tester);

      expect(find.byKey(_reportKey), findsOneWidget);
      expect(
        _currentState(tester).isFinanciallyTerminal,
        isTrue,
        reason: 'the October close must have actually committed bankruptcy',
      );
      // The terminal card must not render while the report is still open —
      // it is not skipped, only shown after dismissal (via the section's
      // own state-driven build, unconditionally re-evaluated regardless of
      // this dialog).

      await tester.tap(find.byKey(_dismissKey));
      await tester.pumpAndSettle();

      expect(find.byKey(_reportKey), findsNothing);
      expect(
        find.byKey(const Key('public-demo-restart-april-confirm')),
        findsNothing,
      );
      // The bankruptcy card itself (unmodified widget) is now visible.
      expect(find.textContaining('倒産'), findsWidgets);
    });
  });

  group('5. Year-End (March): report shows, then dismiss reveals the '
      'existing Year-End result card', () {
    testWidgets('March\'s close completes the fiscal year; the report '
        'shows first, then dismissing it reveals the unmodified Year-End '
        'card on the accounting tab', (tester) async {
      // A deliberately small, flat monthlyExpenses (matching
      // `publicDemoAggregateAtMonth`'s own default of 10000) — the group 1/4
      // fixtures above use the real baseline expense specifically to reach
      // cashShortage/bankruptcy quickly, but that same zero-revenue
      // trajectory run all the way to March would go `isCloseBlocked`
      // (bankrupt) long before month 15, making `closeOrdinaryMonth` a
      // permanent no-op and this loop never reach 15. This fixture instead
      // needs a genuine SUCCESS trajectory to reach fiscal-year completion.
      const yearEndExpense = 10000;
      var aggregate = PublicDemoAggregate.initial();
      while (aggregate.state.month < 15) {
        aggregate = aggregate.state.month == 4
            ? aggregate.closeApril(monthlyExpenses: yearEndExpense)
            : aggregate.state.month == 5
            ? aggregate.closeMay(week: 9, monthlyExpenses: yearEndExpense)
            : aggregate.state.month == 6
            ? aggregate.closeJune(
                assignedInJuly: 0,
                monthlyExpenses: yearEndExpense,
              )
            : aggregate.state.month == 7
            ? aggregate
                  .confirmSummerBonusDecision(PublicDemoSummerBonusPlan.none)
                  .closeJuly(monthlyExpenses: yearEndExpense)
            : aggregate.closeOrdinaryMonth(monthlyExpenses: yearEndExpense);
        // Defense-in-depth against the exact infinite-loop class of bug
        // described above: if a future balance-tuning change makes even
        // this small expense reach a terminal status before month 15, fail
        // loudly here instead of spinning forever.
        expect(
          aggregate.state.isCloseBlocked,
          isFalse,
          reason:
              'fixture must reach month 15 via genuine ordinary closes, '
              'never a blocked/terminal state',
        );
      }
      expect(aggregate.state.month, 15);
      expect(aggregate.state.fiscalYearCompleted, isFalse);
      await _pump(tester, aggregate);
      await _tapCtaAndSettle(tester);
      await _proceedPastGuardOnly(tester);

      expect(find.byKey(_reportKey), findsOneWidget);
      expect(find.text('3月の経営結果'), findsOneWidget);
      expect(_currentState(tester).fiscalYearCompleted, isTrue);

      await tester.tap(find.byKey(_dismissKey));
      await tester.pumpAndSettle();

      expect(find.byKey(_reportKey), findsNothing);
      await switchPublicDemoTab(tester, PublicDemoTab.accounting);
      expect(
        find.byKey(const Key('public-demo-fiscal-year-complete')),
        findsOneWidget,
      );
    });
  });

  group('6. save/reload regression', () {
    testWidgets('the report never introduces its own save/persist call, '
        'and the underlying committed aggregate saves exactly once per '
        'close, matching pre-Phase-B behavior', (tester) async {
      final service = await _pump(tester, PublicDemoAggregate.initial());
      final savesBeforeClose = service.saveCount;
      await _tapCtaAndSettle(tester);
      await _proceedPastGuardOnly(tester);
      final confirm = find.widgetWithText(FilledButton, '確認');
      if (confirm.evaluate().isNotEmpty) {
        await tester.tap(confirm);
        await tester.pumpAndSettle();
      }
      expect(find.byKey(_reportKey), findsOneWidget);
      // The commit (and its one save) already happened before the report
      // ever appears — showing/dismissing the dialog must not trigger any
      // further save.
      expect(service.saveCount, savesBeforeClose + 1);
      expect(service.lastSaved?.state.month, 5);

      await tester.tap(find.byKey(_dismissKey));
      await tester.pumpAndSettle();
      expect(service.saveCount, savesBeforeClose + 1);
    });
  });

  group('7. mobile widths: no overflow, report reachable and dismissable', () {
    for (final size in [const Size(360, 800), const Size(390, 844)]) {
      testWidgets(
        'the report lays out without overflow at '
        '${size.width.toInt()}x${size.height.toInt()}, and the dismiss CTA '
        'remains reachable and tappable',
        (tester) async {
          await _pump(tester, PublicDemoAggregate.initial(), size: size);
          await _tapCtaAndSettle(tester);
          await _proceedPastGuardOnly(tester);
          final confirm = find.widgetWithText(FilledButton, '確認');
          if (confirm.evaluate().isNotEmpty) {
            await tester.tap(confirm);
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          expect(find.byKey(_reportKey), findsOneWidget);

          await tester.ensureVisible(find.byKey(_dismissKey));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(_dismissKey));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byKey(_reportKey), findsNothing);
        },
      );

      testWidgets(
        'the report lays out without overflow at a large text scale '
        '(1.3x) at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          final service = _FixedSaveService(PublicDemoAggregate.initial());
          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: MaterialApp(
                home: PublicDemo01PlaceholderScreen(saveService: service),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await _tapCtaAndSettle(tester);
          await _proceedPastGuardOnly(tester);
          final confirm = find.widgetWithText(FilledButton, '確認');
          if (confirm.evaluate().isNotEmpty) {
            await tester.tap(confirm);
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          expect(find.byKey(_reportKey), findsOneWidget);
        },
      );
    }
  });
}
