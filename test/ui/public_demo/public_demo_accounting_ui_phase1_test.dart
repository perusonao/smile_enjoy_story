// SES ACCOUNTING-UI-PHASE-1: the 会計タブ is reorganized into five
// information-hierarchy sections — 1) 現在の資金状態
// (`_S._accountingFundStatusSection`, new), 2) 今月の収支
// (`_S._accountingMonthlyBalanceSection` — the existing monthly cash-flow
// card plus `PublicDemoFinanceSummarySection`), 3) 将来の資金予測・リスク
// (`_S._accountingForecastSection`, new — the existing `PublicDemoCashForecast`
// pure model), 4) 今月必要な経営判断 (`_S._accountingDecisionSection` — the July
// summer-bonus decision card), 5) 月次結果 / Year-End
// (`_S._accountingMonthlyResultSection` — the August start-result narrative
// and `PublicDemoYearEndResultCard`) — instead of one flat body. Every card,
// key, month gate, and figure is moved verbatim from the prior single flat
// `Column` (see `public_demo_01_accounting_tab_empty_heading_test.dart` and
// `public_demo_01_year_end_result_test.dart` for the pre-existing coverage
// of that content, deliberately left unmodified and still passing
// unchanged). The one presentation fix under test here (Fresh Audit): the
// finance summary's title now truthfully distinguishes a pre-close baseline
// ("今月の支出予定") from a settled actual ("前回確定の支出（給与・固定費）") —
// see `PublicDemoFinanceSummaryModel.isSettled`'s own doc — with no change
// to the payroll/fixedCosts figures themselves.
//
// Every fixture here is built by chaining the SAME real domain commands
// production code uses — `PublicDemoAggregate.initial()` /
// `publicDemoAggregateAtMonth` plus `closeOrdinaryMonth` — matching the
// established technique in this suite (see
// `public_demo_01_year_end_result_test.dart`'s own class doc). No fabricated
// revenue/customer/project/rate data is ever introduced.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_cash_forecast.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_cash_status_presentation.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_month_label.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
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

const _fundStatusKey = Key('public-demo-accounting-fund-status-section');
const _forecastKey = Key('public-demo-accounting-forecast-section');
const _decisionKey = Key('public-demo-accounting-decision-section');
const _monthlyResultKey = Key('public-demo-accounting-monthly-result-section');
const _financeSummaryKey = Key('public-demo-finance-summary');
const _cashFlowCardKey = Key('public-demo-monthly-cash-flow-card');
const _targetSizes = <Size>[Size(360, 800), Size(390, 844)];

/// Drives cash down using only ordinary closes with no sales activity at
/// all (`workflow.assignedEngineerIds` stays empty throughout, so
/// `PublicDemoRevenue.monthlyRevenueForAssignedCount` is always 0) — the
/// simplest real trajectory that reaches an actual
/// `PublicDemoFinancialStatus.cashShortage` deterministically, without
/// depending on the sales pipeline this phase must not touch.
PublicDemoAggregate shortageAtMonth9() =>
    publicDemoAggregateAtMonth(9, monthlyExpenses: 1000000);

void main() {
  group('Section 1 (現在の資金状態): always renders a truthful snapshot', () {
    testWidgets('April: cash and financial status match PublicDemoState '
        'exactly', (tester) async {
      final game = publicDemoAggregateAtMonth(4);
      await pumpAccountingTab(tester, game);
      final state = currentState(tester);

      expect(find.byKey(_fundStatusKey), findsOneWidget);
      expect(find.textContaining('現在の現預金'), findsOneWidget);
      expect(
        find.textContaining(formatYen(state.cash)),
        findsWidgets,
      );
      expect(find.textContaining('健全'), findsOneWidget);
    });

    testWidgets(
      'an actual cash shortage: 資金状態 truthfully reads the shortage label, '
      'never claiming 健全',
      (tester) async {
        final game = shortageAtMonth9();
        expect(
          game.state.financialStatus,
          PublicDemoFinancialStatus.cashShortage,
          reason: 'fixture sanity',
        );

        await pumpAccountingTab(tester, game);

        expect(find.textContaining('資金不足（猶予期間中）'), findsOneWidget);
        expect(find.textContaining('健全'), findsNothing);
      },
    );
  });

  group('Section 2 (今月の収支) truthful labels (Fresh Audit label fix)', () {
    testWidgets(
      'April (before the first close): the finance summary still says '
      '今月の支出予定 — genuinely a forward baseline, not yet a settled actual',
      (tester) async {
        final game = publicDemoAggregateAtMonth(4);
        expect(
          game.state.latestMonthlyCashFlow,
          isNull,
          reason: 'fixture sanity: no close has happened yet',
        );

        await pumpAccountingTab(tester, game);

        expect(find.byKey(_financeSummaryKey), findsOneWidget);
        expect(find.text('今月の支出予定'), findsOneWidget);
        expect(find.text('前回確定の支出（給与・固定費）'), findsNothing);
      },
    );

    testWidgets(
      'May (after the first close): the finance summary now says '
      '前回確定の支出（給与・固定費） — the same figures, truthfully labeled as '
      "last CLOSED month's actual rather than a same-month forecast",
      (tester) async {
        final game = publicDemoAggregateAtMonth(5);
        expect(
          game.state.latestMonthlyCashFlow,
          isNotNull,
          reason: 'fixture sanity: April has already closed',
        );

        await pumpAccountingTab(tester, game);

        expect(find.text('前回確定の支出（給与・固定費）'), findsOneWidget);
        expect(find.text('今月の支出予定'), findsNothing);
        // The underlying figures are unchanged by the label fix.
        expect(find.byKey(_cashFlowCardKey), findsOneWidget);
      },
    );
  });

  group('Sep-Feb: normal accounting (no active decision, no monthly-result '
      'narrative)', () {
    for (final month in [9, 10, 11, 12, 13, 14]) {
      testWidgets(
        'month $month: fund status + monthly balance + forecast render; '
        'decision and monthly-result sections are absent',
        (tester) async {
          final game = publicDemoAggregateAtMonth(month);
          await pumpAccountingTab(tester, game);
          expect(currentState(tester).month, month);

          expect(find.byKey(_fundStatusKey), findsOneWidget);
          expect(find.byKey(_financeSummaryKey), findsOneWidget);
          expect(find.byKey(_decisionKey), findsNothing);
          expect(find.byKey(_monthlyResultKey), findsNothing);
        },
      );
    }
  });

  group('July: 今月必要な経営判断 shows the summer-bonus decision', () {
    testWidgets(
      'the decision card renders under its own section, and the existing '
      'CTA/eligibility (decideSummerBonus) is unchanged',
      (tester) async {
        final game = publicDemoAggregateAtMonth(7);
        await pumpAccountingTab(tester, game);
        expect(currentState(tester).month, 7);

        expect(find.byKey(_decisionKey), findsOneWidget);
        expect(find.text('夏季賞与'), findsOneWidget);
        expect(
          find.byKey(const Key('public-demo-summer-bonus-decision')),
          findsOneWidget,
        );
        expect(find.byKey(_monthlyResultKey), findsNothing);
      },
    );
  });

  group('August: 月次結果 / Year-End shows the start-result narrative', () {
    testWidgets(
      'the August recap renders under the shared section, decision section '
      'is absent',
      (tester) async {
        final game = publicDemoAggregateAtMonth(8);
        await pumpAccountingTab(tester, game);
        expect(currentState(tester).month, 8);

        expect(find.byKey(_monthlyResultKey), findsOneWidget);
        expect(find.text('8月開始結果'), findsOneWidget);
        expect(find.text('7月分の給与を反映しました'), findsOneWidget);
        expect(find.byKey(_decisionKey), findsNothing);
      },
    );
  });

  group('将来の資金予測・リスク: reuses PublicDemoCashForecast verbatim, no new '
      'threshold', () {
    testWidgets('a healthy April start: safe summary, every projected month '
        'matches PublicDemoCashForecast.forecast exactly', (tester) async {
      final game = publicDemoAggregateAtMonth(4);
      await pumpAccountingTab(tester, game);
      final state = currentState(tester);
      final expected = PublicDemoCashForecast.forecast(
        state: state,
        workflow: game.workflow,
      );
      final status = PublicDemoCashStatusPresentation.fromForecast(expected);
      expect(status.status, PublicDemoCashStatus.safe, reason: 'fixture sanity');

      expect(find.byKey(_forecastKey), findsOneWidget);
      expect(
        find.textContaining('今後${expected.months.length}回の決算見込みでは資金不足はありません'),
        findsOneWidget,
      );
      for (final month in expected.months) {
        expect(
          find.byKey(
            Key('public-demo-accounting-forecast-month-${month.month}'),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            '${publicDemoMonthLabel(month.month)}末 現預金見込み',
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets(
      'an actual cash shortage: the shortage headline states the exact '
      'forecasted month PublicDemoCashForecast reports, and never implies '
      'safety',
      (tester) async {
        final game = shortageAtMonth9();
        final state = currentState0(game);
        final expected = PublicDemoCashForecast.forecast(
          state: state,
          workflow: game.workflow,
        );
        final status = PublicDemoCashStatusPresentation.fromForecast(expected);
        expect(
          status.status,
          PublicDemoCashStatus.shortage,
          reason: 'fixture sanity',
        );

        await pumpAccountingTab(tester, game);

        expect(
          find.textContaining(
            '${publicDemoMonthLabel(status.shortageMonth!)}に資金がマイナスになる見込みです。',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('資金不足はありません'), findsNothing);
      },
    );

    testWidgets(
      'fiscal year completed: the forecast window is empty (no further '
      'close ahead), so the section is hidden rather than shown empty',
      (tester) async {
        var game = publicDemoAggregateAtMonth(15);
        game = game.closeOrdinaryMonth(monthlyExpenses: 10000);
        expect(game.state.fiscalYearCompleted, isTrue, reason: 'fixture sanity');

        await pumpAccountingTab(tester, game);

        expect(find.byKey(_forecastKey), findsNothing);
      },
    );
  });

  group('March / month15 Year-End and restart route', () {
    testWidgets(
      'a completed fiscal year shows the Year-End card under 月次結果 / '
      'Year-End, and the replay CTA reuses the canonical restart flow',
      (tester) async {
        var game = publicDemoAggregateAtMonth(15);
        game = game.closeOrdinaryMonth(monthlyExpenses: 10000);
        expect(game.state.fiscalYearCompleted, isTrue);

        await pumpAccountingTab(tester, game);

        expect(find.byKey(_monthlyResultKey), findsOneWidget);
        expect(
          find.byKey(const Key('public-demo-fiscal-year-complete')),
          findsOneWidget,
        );

        final replayButton = find.byKey(
          const Key('public-demo-year-end-replay-button'),
        );
        await tester.ensureVisible(replayButton);
        await tester.pumpAndSettle();
        await tester.tap(replayButton);
        await tester.pumpAndSettle();

        // The SAME dialog the dev-menu restart control shows — no separate
        // reset authority is introduced by this phase.
        expect(
          find.byKey(const Key('public-demo-restart-april-dialog')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('public-demo-restart-april-confirm')),
        );
        await tester.pumpAndSettle();

        final state = currentState(tester);
        expect(state.month, 4);
        expect(state.fiscalYearCompleted, isFalse);
        expect(find.byKey(const Key('public-demo-nav-home')), findsOneWidget);
      },
    );

    testWidgets(
      'March (15) before fiscal-year completion: no Year-End card, and the '
      'monthly-result section stays hidden (no August recap, no completion)',
      (tester) async {
        final game = publicDemoAggregateAtMonth(15);
        expect(game.state.fiscalYearCompleted, isFalse);

        await pumpAccountingTab(tester, game);

        expect(
          find.byKey(const Key('public-demo-fiscal-year-complete')),
          findsNothing,
        );
        expect(find.byKey(_monthlyResultKey), findsNothing);
      },
    );
  });

  group('360x800 / 390x844, TextScaler 1.0 / 1.3 / 2.0: no horizontal '
      'overflow', () {
    PublicDemoAggregate juneClosed() {
      var game = publicDemoAggregateAtMonth(7);
      return game;
    }

    for (final size in _targetSizes) {
      for (final textScale in [1.0, 1.3, 2.0]) {
        testWidgets(
          'July (richest content: fund status + balance + forecast + '
          'decision) at ${size.width.toInt()}x${size.height.toInt()} / '
          'textScale $textScale',
          (tester) async {
            await pumpAccountingTab(
              tester,
              juneClosed(),
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
          'an actual cash shortage at '
          '${size.width.toInt()}x${size.height.toInt()} / textScale '
          '$textScale',
          (tester) async {
            await pumpAccountingTab(
              tester,
              shortageAtMonth9(),
              size: size,
              textScale: textScale,
            );

            expect(tester.takeException(), isNull);
            for (final key in [_fundStatusKey, _forecastKey]) {
              final rect = tester.getRect(find.byKey(key));
              expect(rect.left, greaterThanOrEqualTo(0.0), reason: '$key');
              expect(rect.right, lessThanOrEqualTo(size.width), reason: '$key');
            }
          },
        );

        testWidgets(
          'a completed fiscal year (Year-End) at '
          '${size.width.toInt()}x${size.height.toInt()} / textScale '
          '$textScale',
          (tester) async {
            var game = publicDemoAggregateAtMonth(15);
            game = game.closeOrdinaryMonth(monthlyExpenses: 10000);
            await pumpAccountingTab(
              tester,
              game,
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
      }
    }
  });

  group('HOME Freeze / Employee UI / Sales UI regression', () {
    testWidgets(
      'switching 会計 → 社員 → 営業 → ホーム and back leaves every other tab '
      'exactly as before — no 会計-only key leaks into any of them',
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
        expect(find.byKey(_fundStatusKey), findsOneWidget);

        await switchPublicDemoTab(tester, PublicDemoTab.employees);
        expect(find.byKey(_fundStatusKey), findsNothing);
        expect(find.byKey(_decisionKey), findsNothing);
        expect(
          find.byKey(const Key('public-demo-employee-roster-section')),
          findsOneWidget,
        );

        await switchPublicDemoTab(tester, PublicDemoTab.sales);
        expect(find.byKey(_fundStatusKey), findsNothing);
        expect(find.byKey(_forecastKey), findsNothing);

        await switchPublicDemoTab(tester, PublicDemoTab.home);
        expect(find.byKey(_fundStatusKey), findsNothing);
        expect(
          find.byKey(const Key('public-demo-employee-roster-section')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('public-demo-important-tasks')),
          findsOneWidget,
        );

        await switchPublicDemoTab(tester, PublicDemoTab.accounting);
        expect(find.byKey(_fundStatusKey), findsOneWidget);
        expect(find.byKey(_decisionKey), findsOneWidget);
      },
    );
  });
}

/// `PublicDemoAggregate.state` read without going through the pumped
/// widget — used only where the forecast under test must be computed from
/// the exact same aggregate a fixture built, before/without pumping.
PublicDemoState currentState0(PublicDemoAggregate aggregate) =>
    aggregate.state;
