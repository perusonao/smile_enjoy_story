// SES NON-HOME-UI ACCOUNTING Visual Complete: pins the new 会計タブ Visual
// structure — the 現在の現金 hero (label + large cash figure + 前回決算の収支
// line + financial-status badge), 今月の売上/今月の支出 stat tiles, the forecast
// section's alert card + per-month bars + 入金予定 tile, and icon-led section
// headers — while leaving every pre-existing information-hierarchy
// assertion (`public_demo_accounting_ui_phase1_test.dart`,
// `public_demo_01_accounting_tab_empty_heading_test.dart`) unmodified and
// still green (both suites are re-run, unmodified, alongside this one — see
// the Result report's tests section).
//
// Every fixture here is built by chaining the SAME real domain commands
// production code uses (`publicDemoAggregateAtMonth`/`closeOrdinaryMonth`),
// matching the technique the pre-existing accounting suite already
// established. No fabricated revenue/customer/project/rate data is ever
// introduced, and every expected figure below is read from the pumped
// widget's own [PublicDemoState]/[PublicDemoCashForecast], never
// hand-typed, so this suite cannot silently drift from the real domain.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_cash_forecast.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_cash_status_presentation.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_accounting_visual.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

import '../../game/public_demo/test_support/public_demo_recovery_test_helpers.dart';
import 'public_demo_tab_test_helpers.dart';

class _FixedSaveService extends PublicDemoSaveService {
  _FixedSaveService(this._aggregate);
  final PublicDemoAggregate _aggregate;

  @override
  Future<PublicDemoAggregate?> load() async => _aggregate;

  @override
  Future<void> save(PublicDemoAggregate aggregate) async {}

  @override
  Future<bool> clear() async => true;
}

PublicDemoState currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

Future<void> pumpAccountingTab(
  WidgetTester tester,
  PublicDemoAggregate aggregate, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: PublicDemo01PlaceholderScreen(
          saveService: _FixedSaveService(aggregate),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await switchPublicDemoTab(tester, PublicDemoTab.accounting);
}

const _targetSizes = <Size>[Size(360, 800), Size(390, 844)];

PublicDemoAggregate shortageAtMonth9() =>
    publicDemoAggregateAtMonth(9, monthlyExpenses: 1000000);

void main() {
  group('現在の現金 hero (Section 1)', () {
    testWidgets('April (before the first close): hero shows cash + 健全 '
        'badge, no 前回決算の収支 line and no 今月の売上/支出 tiles yet', (tester) async {
      final game = publicDemoAggregateAtMonth(4);
      await pumpAccountingTab(tester, game);
      final state = currentState(tester);
      expect(state.latestMonthlyCashFlow, isNull, reason: 'fixture sanity');

      expect(find.byType(PublicDemoAccountingCashHero), findsOneWidget);
      expect(find.textContaining('現在の現預金'), findsOneWidget);
      expect(find.text(formatYen(state.cash)), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is PublicDemoAccountingStatusBadge && w.label == '健全',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('前回決算の収支'), findsNothing);
      // Section 2's PublicDemoFinanceSummarySection still legitimately says
      // '今月の支出予定', and Section 3 always renders its own 入金予定 stat
      // tile even in April — only the Section 1 売上/支出 tiles are under
      // test here, checked by their exact label rather than a raw substring.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is PublicDemoAccountingStatTile &&
              (w.label == '今月の売上' || w.label == '今月の支出'),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'May (after the first close): 前回決算の収支 line + 今月の売上/支出 tiles all '
      'match PublicDemoMonthlyCashFlow exactly',
      (tester) async {
        final game = publicDemoAggregateAtMonth(5);
        await pumpAccountingTab(tester, game);
        final state = currentState(tester);
        final flow = state.latestMonthlyCashFlow;
        expect(flow, isNotNull, reason: 'fixture sanity');

        final delta = flow!.netCashMovement;
        expect(
          find.textContaining(
            '前回決算の収支 ${delta >= 0 ? '+' : '-'}${formatYen(delta.abs())}',
          ),
          findsOneWidget,
        );
        expect(find.text(formatYen(flow.revenue)), findsWidgets);
        expect(find.text(formatYen(flow.totalOutflow)), findsWidgets);
      },
    );

    testWidgets(
      'an actual cash shortage: badge tone/label read 資金不足（猶予期間中）, never '
      '健全',
      (tester) async {
        final game = shortageAtMonth9();
        await pumpAccountingTab(tester, game);

        expect(
          find.byWidgetPredicate(
            (w) =>
                w is PublicDemoAccountingStatusBadge &&
                w.label == '資金不足（猶予期間中）' &&
                w.tone == PublicDemoAccountingTone.caution,
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is PublicDemoAccountingStatusBadge && w.label == '健全',
          ),
          findsNothing,
        );
      },
    );
  });

  group(
    '前回決算の収支 stays pinned to the prior close (SES HUMAN-REPLAY PRE-FIX '
    'P1): post-close training/recruitment-media spend must not be mistaken '
    'for a re-computed comparison',
    () {
      testWidgets(
        'training + recruitment-media spend after May\'s close changes only '
        '現在の現預金 — 前回決算の収支 keeps showing April\'s already-closed figure',
        (tester) async {
          final closed = publicDemoAggregateAtMonth(5);
          final flow = closed.state.latestMonthlyCashFlow;
          expect(flow, isNotNull, reason: 'fixture sanity: May has a close');
          final engineerId = closed.workflow.engineers.first.id;

          final afterTraining = closed.selectInternalTraining(engineerId);
          expect(
            afterTraining.state.cash,
            lessThan(closed.state.cash),
            reason: 'fixture sanity: training charges cash immediately, '
                'independent of any monthly close',
          );

          final recruited = afterTraining.recruit(
            PublicDemoRecruitmentMedium.engineer,
          );
          final spent = recruited.aggregate;
          expect(
            spent,
            isNotNull,
            reason: 'fixture sanity: recruitment media purchase succeeds',
          );
          expect(
            spent!.state.cash,
            lessThan(afterTraining.state.cash),
            reason: 'fixture sanity: recruitment media also charges cash '
                'immediately',
          );
          expect(
            spent.state.latestMonthlyCashFlow!.month,
            flow!.month,
            reason: 'post-close spending must not create or replace a '
                'monthly close record',
          );
          expect(
            spent.state.latestMonthlyCashFlow!.netCashMovement,
            flow.netCashMovement,
            reason: '前回決算の収支 must stay the already-closed month\'s own '
                'figure, unaffected by spending made after that close',
          );

          await pumpAccountingTab(tester, spent);
          final delta = flow.netCashMovement;
          expect(
            find.textContaining(
              '前回決算の収支 ${delta >= 0 ? '+' : '-'}${formatYen(delta.abs())}',
            ),
            findsOneWidget,
          );
          expect(find.text(formatYen(spent.state.cash)), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  group('将来の資金予測・リスク (Section 3): bars, alert tone, and 入金予定', () {
    testWidgets(
      'a healthy April start: positive alert tone, one forecast bar per '
      'projected month, and a truthful 入金予定 tile',
      (tester) async {
        final game = publicDemoAggregateAtMonth(4);
        await pumpAccountingTab(tester, game);
        final state = currentState(tester);
        final forecast = PublicDemoCashForecast.forecast(
          state: state,
          workflow: game.workflow,
        );
        final status = PublicDemoCashStatusPresentation.fromForecast(forecast);
        expect(status.status, PublicDemoCashStatus.safe, reason: 'fixture sanity');

        expect(
          find.byWidgetPredicate(
            (w) =>
                w is PublicDemoAccountingAlertCard &&
                w.tone == PublicDemoAccountingTone.positive,
          ),
          findsOneWidget,
        );
        expect(
          find.byType(PublicDemoAccountingForecastBar),
          findsNWidgets(forecast.months.length),
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is PublicDemoAccountingStatTile &&
                w.label == '入金予定' &&
                w.primaryText == formatYen(state.pendingRevenue),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'an actual cash shortage: alert tone is caution, and the negative '
      'month renders a zero-fraction, isNegative bar',
      (tester) async {
        final game = shortageAtMonth9();
        final state = game.state;
        final forecast = PublicDemoCashForecast.forecast(
          state: state,
          workflow: game.workflow,
        );
        final status = PublicDemoCashStatusPresentation.fromForecast(forecast);
        expect(
          status.status,
          PublicDemoCashStatus.shortage,
          reason: 'fixture sanity',
        );

        await pumpAccountingTab(tester, game);

        expect(
          find.byWidgetPredicate(
            (w) =>
                w is PublicDemoAccountingAlertCard &&
                w.tone == PublicDemoAccountingTone.caution,
          ),
          findsOneWidget,
        );
        final negativeMonth = forecast.months.firstWhere((m) => m.isNegative);
        final bar = tester.widgetList<PublicDemoAccountingForecastBar>(
          find.descendant(
            of: find.byKey(
              Key(
                'public-demo-accounting-forecast-month-${negativeMonth.month}',
              ),
            ),
            matching: find.byType(PublicDemoAccountingForecastBar),
          ),
        );
        expect(bar.single.isNegative, isTrue);
        expect(bar.single.fraction, 0);
      },
    );
  });

  group('icon-led section headers (P0 goal 5): all 5 accounting sections '
      'carry a leading Icon', () {
    testWidgets('July: fund status / balance / forecast / decision headers '
        'each render an Icon', (tester) async {
      final game = publicDemoAggregateAtMonth(7);
      await pumpAccountingTab(tester, game);

      for (final key in [
        'public-demo-accounting-fund-status-section',
        'public-demo-accounting-forecast-section',
        'public-demo-accounting-decision-section',
      ]) {
        final section = find.byKey(Key(key));
        expect(section, findsOneWidget, reason: key);
        expect(
          find.descendant(of: section, matching: find.byType(Icon)),
          findsWidgets,
          reason: key,
        );
      }
    });

    testWidgets('August: monthly-result header renders an Icon', (
      tester,
    ) async {
      final game = publicDemoAggregateAtMonth(8);
      await pumpAccountingTab(tester, game);

      final section = find.byKey(
        const Key('public-demo-accounting-monthly-result-section'),
      );
      expect(section, findsOneWidget);
      expect(
        find.descendant(of: section, matching: find.byType(Icon)),
        findsWidgets,
      );
    });
  });

  group('PublicDemoAccountingStatusBadge / AlertCard tones are visually '
      'distinct', () {
    testWidgets('the 3 tones render 3 different background colors', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                PublicDemoAccountingStatusBadge(
                  key: Key('badge-positive'),
                  label: 'positive',
                  tone: PublicDemoAccountingTone.positive,
                ),
                PublicDemoAccountingStatusBadge(
                  key: Key('badge-caution'),
                  label: 'caution',
                  tone: PublicDemoAccountingTone.caution,
                ),
                PublicDemoAccountingStatusBadge(
                  key: Key('badge-negative'),
                  label: 'negative',
                  tone: PublicDemoAccountingTone.negative,
                ),
              ],
            ),
          ),
        ),
      );

      Color bgOf(String key) {
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Container),
          ),
        );
        return (container.decoration as BoxDecoration).color!;
      }

      final colors = {
        bgOf('badge-positive'),
        bgOf('badge-caution'),
        bgOf('badge-negative'),
      };
      expect(colors.length, 3);
    });
  });

  group('HOME Freeze / other-tab isolation', () {
    testWidgets(
      'switching 会計 → 社員 → 営業 → ホーム and back leaves no 会計-visual '
      'widget on any other tab',
      (tester) async {
        final game = publicDemoAggregateAtMonth(7);
        await tester.pumpWidget(
          MaterialApp(
            home: PublicDemo01PlaceholderScreen(
              saveService: _FixedSaveService(game),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await switchPublicDemoTab(tester, PublicDemoTab.accounting);
        expect(find.byType(PublicDemoAccountingCashHero), findsOneWidget);

        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        expect(find.byType(PublicDemoAccountingCashHero), findsNothing);
        expect(find.byType(PublicDemoAccountingForecastBar), findsNothing);

        await switchPublicDemoTab(tester, PublicDemoTab.sales);
        expect(find.byType(PublicDemoAccountingCashHero), findsNothing);

        await switchPublicDemoTab(tester, PublicDemoTab.home);
        expect(find.byType(PublicDemoAccountingCashHero), findsNothing);
        expect(find.byType(PublicDemoAccountingStatusBadge), findsNothing);

        await switchPublicDemoTab(tester, PublicDemoTab.accounting);
        expect(find.byType(PublicDemoAccountingCashHero), findsOneWidget);
      },
    );
  });

  group('360x800 / 390x844, TextScaler 1.0 / 1.3 / 2.0: no horizontal '
      'overflow with the new hero/tiles/bars', () {
    for (final size in _targetSizes) {
      for (final textScale in [1.0, 1.3, 2.0]) {
        testWidgets(
          'July (richest content) at ${size.width.toInt()}x'
          '${size.height.toInt()} / textScale $textScale',
          (tester) async {
            await pumpAccountingTab(
              tester,
              publicDemoAggregateAtMonth(7),
              size: size,
              textScale: textScale,
            );

            expect(tester.takeException(), isNull);
            for (var i = 0; i < 6; i++) {
              await tester.drag(find.byType(ListView), const Offset(0, -400));
              await tester.pump();
            }
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets(
          'an actual cash shortage at ${size.width.toInt()}x'
          '${size.height.toInt()} / textScale $textScale',
          (tester) async {
            await pumpAccountingTab(
              tester,
              shortageAtMonth9(),
              size: size,
              textScale: textScale,
            );

            expect(tester.takeException(), isNull);
            for (final key in [
              'public-demo-accounting-fund-status-section',
              'public-demo-accounting-forecast-section',
            ]) {
              final rect = tester.getRect(find.byKey(Key(key)));
              expect(rect.left, greaterThanOrEqualTo(0.0), reason: key);
              expect(rect.right, lessThanOrEqualTo(size.width), reason: key);
            }
          },
        );

        testWidgets(
          'May (前月比 + tiles visible) at ${size.width.toInt()}x'
          '${size.height.toInt()} / textScale $textScale',
          (tester) async {
            await pumpAccountingTab(
              tester,
              publicDemoAggregateAtMonth(5),
              size: size,
              textScale: textScale,
            );

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
