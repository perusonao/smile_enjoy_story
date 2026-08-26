// HOME-RUNTIME-READ-1: the first runtime connection between the
// authoritative Public Demo 0.1 state and the new HOME dashboard's
// read-only display.
//
// Everything here drives the REAL widget (and therefore the real
// [PublicDemoAggregate] trajectory behind it) rather than a fake
// projection: the point of this phase is precisely that HOME now shows
// authoritative runtime figures, so a fixture-only suite would prove
// nothing about the wiring. The one exception is the terminal-status group
// at the bottom, which needs March states this UI trajectory cannot reach
// in a reasonable number of taps — those use the same real domain
// (`PublicDemoMonthlyClose`) rather than a hand-built projection.
//
// Scope guard: this phase connects year/month, cash, revenue,
// pendingRevenue, employeeCount and assignedEmployeeCount only, and HOME
// stays a read-only consumer. Employee identity/images, key events,
// financialStatus warnings, company status, month-end CTA activation and
// bottom-nav navigation are explicitly NOT connected yet.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/app/app_entry.dart';
import 'package:smile_enjoy_story/app/app_experience.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_monthly_close.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_revenue.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/presentation/home/home.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/kpi_section.dart';
import 'package:smile_enjoy_story/presentation/home/widgets/month_header_bar.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_home_dashboard_section.dart';

/// The screen's own authoritative finance state, read straight off its
/// [State] — the same technique
/// public_demo_01_assignment_carryforward_test.dart already uses, so every
/// assertion below compares HOME against the real authority rather than
/// against a re-derived expectation.
PublicDemoState currentState(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic).s
        as PublicDemoState;

Finder get sectionFinder => find.byType(PublicDemoHomeDashboardSection);

/// The projection actually injected into the runtime HOME display.
HomeDashboardDisplayData homeData(WidgetTester tester) =>
    tester.widget<PublicDemoHomeDashboardSection>(sectionFinder).data;

Finder inHome(Finder matching) =>
    find.descendant(of: sectionFinder, matching: matching);

/// Mirrors KpiSection's own 万-unit formatting so the rendered-text
/// assertions below describe what a player sees, not just the injected
/// object.
String yen(int amount) => '¥${amount ~/ 10000}万';

Finder actionButton(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

/// Buttons that open an event dialog first await a real image decode, which
/// this SDK only completes on the wall clock — mirrors the existing Public
/// Demo widget tests' helper.
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
/// success/carry-forward playthroughs, reused here so HOME is observed on a
/// real (not synthesized) trajectory.
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

/// Asserts the injected projection is field-for-field what the authoritative
/// state projects right now — i.e. HOME is neither stale nor computing
/// anything of its own.
void expectHomeMatchesAuthority(WidgetTester tester, {required String at}) {
  final state = currentState(tester);
  expect(
    homeData(tester),
    HomeDashboardDisplayData.fromPublicDemoState(state),
    reason: 'HOME projection must equal the current authoritative one ($at)',
  );
}

void main() {
  group('Public Demo entry is preserved', () {
    test('the Public Demo 0.1 route still resolves', () {
      expect(
        resolveAppExperience(
          Uri.parse('https://example.test/#/public-demo-01'),
        ),
        AppExperience.publicDemo01,
      );
    });

    testWidgets('the Public Demo screen still starts normally, with the '
        'runtime HOME section added alongside its existing UI', (tester) async {
      await pumpDemo(tester);

      // The Public Demo root is still the Public Demo root: HOME-RUNTIME-
      // READ-1 adds a read-only section, it does not swap the screen for
      // HomeShellPage (which stays unwired from the app's navigation).
      expect(find.byType(PublicDemo01PlaceholderScreen), findsOneWidget);
      expect(find.byType(HomeShellPage), findsNothing);
      expect(find.text('S.E.S. Public Demo 0.1'), findsOneWidget);

      // Existing Public Demo UI is untouched and still present.
      expect(find.text('4月'), findsOneWidget);
      expect(find.text('今月やること'), findsOneWidget);
      expect(find.text('現預金'), findsOneWidget);

      // ...and the new read-only HOME section is mounted next to it.
      expect(sectionFinder, findsOneWidget);
      expect(inHome(find.byType(MonthHeaderBar)), findsOneWidget);
      expect(inHome(find.byType(KpiSection)), findsOneWidget);
    });
  });

  group('runtime HOME receives the connected fields', () {
    testWidgets('year/month, cash, revenue, pendingRevenue, employeeCount and '
        'assignedCount all come from the authoritative April state', (
      tester,
    ) async {
      await pumpDemo(tester);

      final state = currentState(tester);
      final home = homeData(tester);

      // 3. year / month.
      expect(home.year, 1);
      expect(home.monthLabel, '4月');
      expect(state.month, 4);
      expect(inHome(find.text('1年目 4月')), findsOneWidget);

      // 4. cash — verbatim from the authority, never re-derived.
      expect(home.cash, state.cash);
      expect(home.cash, 3000000);
      expect(inHome(find.text(yen(state.cash))), findsOneWidget);

      // 5. revenue — the production formula applied to the authoritative
      //    assigned count, not a HOME-local calculation.
      expect(
        home.revenue,
        PublicDemoRevenue.monthlyRevenueForAssignedCount(
          state.engineersAssigned,
        ),
      );
      expect(home.revenue, 0, reason: 'nobody is assigned yet in April');

      // 6. pendingRevenue — verbatim, and separate from cash (see the
      //    dedicated adversarial test below).
      expect(home.pendingRevenue, state.pendingRevenue);
      expect(home.pendingRevenue, 0);

      // 7. employeeCount — the finance-side headcount, not applicants.
      expect(home.employeeCount, state.engineerCount);
      expect(home.employeeCount, 2);
      expect(inHome(find.text('${state.engineerCount}名')), findsWidgets);

      // 8. assignedCount — engineersAssigned, never the waiting or total headcount.
      expect(home.assignedEmployeeCount, state.engineersAssigned);
      expect(home.assignedEmployeeCount, 0);
      expect(
        home.assignedEmployeeCount,
        isNot(state.engineersWaiting),
        reason: 'April has 2 waiting and 0 assigned — they must not be mixed',
      );

      expectHomeMatchesAuthority(tester, at: 'April start');
    });
  });

  group('runtime HOME refreshes with the authoritative state', () {
    testWidgets('month progression, monthly close, employee join and '
        'assignment each move HOME to the current figures', (tester) async {
      await pumpDemo(tester);
      final april = homeData(tester);

      // 9 + 12. April -> May: the month advances AND Sato's April order
      // turns into a real assignment, so both the month label and the
      // assigned count move.
      await playApril(tester);
      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);

      var state = currentState(tester);
      var home = homeData(tester);
      expect(state.month, 5);
      expect(home.monthLabel, '5月', reason: '9: month progression');
      expect(inHome(find.text('1年目 5月')), findsOneWidget);
      expect(home.assignedEmployeeCount, state.engineersAssigned);
      expect(
        home.assignedEmployeeCount,
        greaterThan(april.assignedEmployeeCount),
        reason: '12: assignment refreshes HOME',
      );
      expect(
        home.revenue,
        PublicDemoRevenue.monthlyRevenueForAssignedCount(
          state.engineersAssigned,
        ),
      );
      expect(home.revenue, greaterThan(april.revenue));
      expectHomeMatchesAuthority(tester, at: 'May');

      // 11. Hire Takahashi in May so a real employee joins at the close.
      await tapAndSettle(tester, '経歴書確認');
      await tapAndSettle(tester, '採用面談');
      await tapAndSettle(tester, '合格・給与提示');
      await tester.tap(
        find.byKey(const Key('public-demo-salary-offer-320000')),
      );
      await tester.pumpAndSettle();

      final beforeJoin = homeData(tester);

      // 10 + 11. Closing May commits payroll/AR (cash and pendingRevenue
      // move) and lands the new employee, all through the existing
      // mutation -> setState -> build path.
      await tapAndSettle(tester, '5月終了→6月');
      await settle(tester);

      state = currentState(tester);
      home = homeData(tester);
      expect(state.month, 6);
      expect(home.monthLabel, '6月');
      expect(
        home.employeeCount,
        state.engineerCount,
        reason: '11: employee join refreshes HOME',
      );
      expect(
        home.employeeCount,
        greaterThan(beforeJoin.employeeCount),
        reason: '11: the new joiner is counted',
      );
      expect(home.cash, state.cash, reason: '10: monthly close refreshes cash');
      expect(
        home.cash,
        isNot(beforeJoin.cash),
        reason: '10: the close actually moved cash',
      );
      expect(home.pendingRevenue, state.pendingRevenue);
      expectHomeMatchesAuthority(tester, at: 'June, after the May close');
    });
  });

  group('adversarial: HOME stays a read-only consumer', () {
    testWidgets('13: pendingRevenue is never folded into cash', (tester) async {
      await pumpDemo(tester);
      await playApril(tester);
      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);
      await tapAndSettle(tester, '5月終了→6月');
      await settle(tester);

      final state = currentState(tester);
      final home = homeData(tester);

      expect(
        state.pendingRevenue,
        greaterThan(0),
        reason: 'the May close books Sato\'s assignment revenue as AR',
      );
      expect(home.cash, state.cash);
      expect(home.pendingRevenue, state.pendingRevenue);
      expect(
        home.cash,
        isNot(state.cash + state.pendingRevenue),
        reason: 'HOME must not add uncollected AR into the cash tile',
      );
      // The two tiles are rendered as separate figures, too.
      expect(inHome(find.text('現金')), findsOneWidget);
      expect(inHome(find.text('入金予定')), findsOneWidget);
    });

    testWidgets('14: HOME has no mutation path back into the aggregate', (
      tester,
    ) async {
      await pumpDemo(tester);

      // Structural: the whole HOME subtree is exactly the two read-only
      // display widgets, each of which accepts ONLY the projection — there
      // is no constructor on either that can carry a PublicDemoState, a
      // PublicDemoAggregate, or a command callback.
      expect(inHome(find.byType(MonthHeaderBar)), findsOneWidget);
      expect(inHome(find.byType(KpiSection)), findsOneWidget);
      expect(
        tester.widget<MonthHeaderBar>(inHome(find.byType(MonthHeaderBar))).data,
        isA<HomeDashboardDisplayData>(),
      );
      expect(
        tester.widget<KpiSection>(inHome(find.byType(KpiSection))).data,
        isA<HomeDashboardDisplayData>(),
      );

      // Structural: nothing inside the HOME subtree is interactive, so
      // there is no affordance that could reach a domain command.
      for (final interactive in <Finder>[
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
        find.byType(InkWell),
        find.byType(IconButton),
        find.byType(ListTile),
        find.byType(TextField),
        find.byType(Switch),
        find.byType(Checkbox),
      ]) {
        expect(inHome(interactive), findsNothing);
      }

      // Behavioural: poking at the HOME section changes nothing
      // authoritative.
      final before = currentState(tester);
      await tester.tap(inHome(find.byType(KpiSection)), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(
        inHome(find.byType(MonthHeaderBar)),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final after = currentState(tester);
      expect(after.month, before.month);
      expect(after.cash, before.cash);
      expect(after.pendingRevenue, before.pendingRevenue);
      expect(after.engineerCount, before.engineerCount);
      expect(after.engineersAssigned, before.engineersAssigned);
      expect(after.engineersWaiting, before.engineersWaiting);
      expect(after.financialStatus, before.financialStatus);
      expect(after.fiscalYearCompleted, before.fiscalYearCompleted);
    });

    testWidgets('the projection is not a second SSOT: it is re-derived from '
        'the current state on every build', (tester) async {
      await pumpDemo(tester);
      expectHomeMatchesAuthority(tester, at: 'April');

      // A plain rebuild with no state change must reproduce an equal
      // projection (value type, no accumulated history)...
      final first = homeData(tester);
      await tester.pump();
      expect(homeData(tester), first);

      // ...and a real mutation must move it, without anything having to
      // publish or invalidate a cached snapshot.
      await playApril(tester);
      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);
      expect(homeData(tester), isNot(first));
      expectHomeMatchesAuthority(tester, at: 'May');
    });
  });

  group('finance-failure UI keeps working with HOME connected', () {
    testWidgets('15 + 16: cash shortage still renders its card, bankruptcy is '
        'still reached and still terminal, and HOME keeps projecting the '
        'authoritative figures throughout', (tester) async {
      await pumpDemo(tester);

      // The same structurally-insolvent trajectory
      // public_demo_01_fiscal_year_progression_test.dart already pins:
      // CASH SHORTAGE closing September, BANKRUPTCY closing October.
      await playApril(tester);
      await tapAndSettle(tester, '4月終了→5月');
      await dismiss(tester);
      await tapAndSettle(tester, '5月終了→6月');
      await settle(tester);
      await tapAndSettle(tester, '6月終了→7月');
      await settle(tester);
      await tapAndSettle(tester, '7月終了→8月');
      await tester.tap(find.byKey(const Key('public-demo-summer-bonus-none')));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, '7月終了→8月');
      await settle(tester);
      expectHomeMatchesAuthority(tester, at: 'August');

      await tapAndSettle(tester, '8月終了→9月');
      await settle(tester);
      await tapAndSettle(tester, '9月終了→10月');
      await settle(tester);

      // 15. The FINANCE-FAILURE-1C card is neither removed nor bypassed.
      expect(
        currentState(tester).financialStatus,
        PublicDemoFinancialStatus.cashShortage,
      );
      expect(
        find.byKey(const Key('public-demo-cash-shortage-card')),
        findsOneWidget,
      );
      // HOME shows the (negative) authoritative cash without inferring any
      // status from its sign — no warning is connected in this phase.
      expectHomeMatchesAuthority(tester, at: 'cash shortage');
      expect(homeData(tester).cash, currentState(tester).cash);

      // 16. Bankruptcy is still reached, and the terminal guard still holds.
      await tapAndSettle(tester, '10月終了→11月');
      await settle(tester);
      expect(
        currentState(tester).financialStatus,
        PublicDemoFinancialStatus.bankruptcy,
      );
      expectHomeMatchesAuthority(tester, at: 'bankruptcy');

      final beforeRetry = currentState(tester);
      final homeBeforeRetry = homeData(tester);
      await tapAndSettle(tester, '11月終了→12月');
      await settle(tester);
      final afterRetry = currentState(tester);
      expect(afterRetry.month, beforeRetry.month);
      expect(afterRetry.cash, beforeRetry.cash);
      expect(afterRetry.financialStatus, beforeRetry.financialStatus);
      expect(afterRetry.fiscalYearCompleted, isFalse);
      expect(
        homeData(tester),
        homeBeforeRetry,
        reason: 'a no-op close must not move HOME either',
      );
    });

    test('17: the March terminal outcomes stay domain-owned — projecting '
        'them for HOME neither changes nor reinterprets them', () {
      // This UI trajectory cannot reach March in a reasonable number of
      // taps, so the March contract itself is exercised through the same
      // real domain the screen uses (see
      // public_demo_financial_status_test.dart cases I/J for the contract).
      PublicDemoState march({required int cash}) => PublicDemoState(
        month: 15,
        cash: cash,
        engineerCount: 1,
        adminCount: 1,
        salesCapacity: 4,
        salesUsed: 0,
        engineersWaiting: 1,
        engineersAssigned: 0,
      );

      // March failure.
      final failure = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: march(cash: 500000),
        monthlyExpenses: 800000,
      ).state;
      expect(
        failure.financialStatus,
        PublicDemoFinancialStatus.marchCashShortageFailure,
      );
      expect(failure.fiscalYearCompleted, isFalse);

      final failureProjection = HomeDashboardDisplayData.fromPublicDemoState(
        failure,
      );
      expect(failure.cash, -300000, reason: 'projecting must not mutate');
      expect(
        failure.financialStatus,
        PublicDemoFinancialStatus.marchCashShortageFailure,
      );
      expect(failure.fiscalYearCompleted, isFalse);
      expect(failureProjection.cash, failure.cash);
      expect(failureProjection.monthLabel, '3月');

      // Fiscal success.
      final success = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: march(cash: 900000),
        monthlyExpenses: 800000,
      ).state;
      expect(success.fiscalYearCompleted, isTrue);
      expect(success.financialStatus, PublicDemoFinancialStatus.normal);

      final successProjection = HomeDashboardDisplayData.fromPublicDemoState(
        success,
      );
      expect(success.fiscalYearCompleted, isTrue, reason: 'still unmutated');
      expect(success.financialStatus, PublicDemoFinancialStatus.normal);
      expect(successProjection.cash, success.cash);

      // The projection carries no status/completion field at all, so HOME
      // structurally cannot contradict either outcome.
      expect(
        failureProjection,
        isNot(successProjection),
        reason: 'the two states still project different cash',
      );
    });
  });

  group('mobile layout', () {
    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpDemo(tester);
    }

    for (final size in const [Size(360, 800), Size(390, 844)]) {
      testWidgets('the runtime HOME section lays out without overflow at '
          '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        await pumpAt(tester, size);

        expect(sectionFinder, findsOneWidget);
        expect(inHome(find.text('1年目 4月')), findsOneWidget);
        // A RenderFlex/grid overflow reports through FlutterError, which
        // the test binding records here.
        expect(tester.takeException(), isNull);

        // The section must also fit the viewport horizontally.
        expect(
          tester.getSize(sectionFinder).width,
          lessThanOrEqualTo(size.width),
        );

        // Scrolling the rest of the screen must not trip one either.
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
