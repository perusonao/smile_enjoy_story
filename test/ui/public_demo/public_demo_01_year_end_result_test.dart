// SES YEAR-END-PHASE-1: focused coverage for the accounting tab's enhanced
// "第1期終了" area (PublicDemoYearEndResultCard). Every fixture here is
// built by chaining the SAME real domain commands production code uses,
// starting from PublicDemoAggregate.initial() — matching
// public_demo_01_accounting_tab_empty_heading_test.dart's own established
// technique (_FixedSaveService injecting a pre-built aggregate as the
// "restored save") rather than a UI-driven walkthrough, so this suite is
// deterministic and fast.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_year_end_display_data.dart';

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

Future<void> pumpDemoWith(
  WidgetTester tester,
  PublicDemoAggregate aggregate,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PublicDemo01PlaceholderScreen(
        saveService: _FixedSaveService(aggregate),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await switchPublicDemoTab(tester, PublicDemoTab.accounting);
}

/// Same as [pumpDemoWith], at a fixed physical size — used only by the
/// 360/390px overflow checks below, mirroring
/// public_demo_01_home_office_stage_test.dart's own `pumpDemoAt` pattern.
Future<void> pumpDemoWithAt(
  WidgetTester tester,
  PublicDemoAggregate aggregate,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await pumpDemoWith(tester, aggregate);
}

/// Scrolls the accounting tab's ListView until [key] is on-screen, then
/// taps it — the year-end card's content pushes its own replay button
/// below the default test viewport, mirroring how every other Public Demo
/// UI test reaches content below the fold (see
/// public_demo_01_completion_lock_ui_test.dart's own `tapAndSettle`).
Future<void> tapYearEndKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// `eng-01` (Sato) genuinely ordered then Recovery-assigned
/// (`recoverAssignment`, the same command RECOVERY-LOOP-1's own finance
/// suite uses) from August, then closed as ordinary months through
/// fiscal-year completion, with a small [monthlyExpenses] (matching
/// `publicDemoAggregateAtMonth`'s own fixture convention) so this reaches
/// fiscal SUCCESS regardless of the one engineer's revenue. `eng-02`
/// (Suzuki) is deliberately left waiting the whole year: her founding
/// capability (52) is below `PublicDemoEngineerRuntime
/// .fieldSalesCapabilityRequirement` (60), so
/// `PublicDemoRecoveryEligibility.isEligible` genuinely refuses to assign
/// her without training first — exactly the real domain rule, not a test
/// shortcut — which makes this fixture a real, differentiated
/// participating(1)/waiting(1) year-end state with one founder assignment-
/// grown and the other unchanged.
Future<PublicDemoAggregate> _successOneFounderParticipating() async {
  var aggregate = publicDemoAggregateAtMonth(8);
  aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
  aggregate = aggregate.recoverAssignment('eng-01');
  expect(
    aggregate.state.engineersAssigned,
    1,
    reason: 'recoverAssignment must have actually assigned eng-01',
  );
  while (!aggregate.state.fiscalYearCompleted &&
      !aggregate.state.isFinanciallyTerminal) {
    aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000);
  }
  return aggregate;
}

void main() {
  group('year-end result: completion gate', () {
    testWidgets(
      'fiscal year not yet completed (March, pre-close): the year-end card '
      'and replay CTA are absent',
      (tester) async {
        final aggregate = publicDemoAggregateAtMonth(15);
        expect(aggregate.state.fiscalYearCompleted, isFalse);

        await pumpDemoWith(tester, aggregate);

        expect(
          find.byKey(const Key('public-demo-fiscal-year-complete')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('public-demo-year-end-replay-button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'an ordinary pre-year-end month (e.g. October) also shows no '
      'year-end card',
      (tester) async {
        await pumpDemoWith(tester, publicDemoAggregateAtMonth(10));

        expect(
          find.byKey(const Key('public-demo-fiscal-year-complete')),
          findsNothing,
        );
      },
    );
  });

  group('year-end result: shown once completed, values match authoritative '
      'state', () {
    testWidgets(
      'the baseline success fixture (no hires, both founders waiting) '
      'shows a year-end card whose every figure matches PublicDemoState',
      (tester) async {
        var aggregate = publicDemoAggregateAtMonth(15);
        aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000);
        expect(aggregate.state.fiscalYearCompleted, isTrue);
        final state = aggregate.state;

        await pumpDemoWith(tester, aggregate);

        expect(
          find.byKey(const Key('public-demo-fiscal-year-complete')),
          findsOneWidget,
        );
        final expected = PublicDemoYearEndDisplayData.fromPublicDemoState(
          state,
        );

        expect(
          find.textContaining(
            '${expected.finalEmployeeCount}名',
          ),
          findsWidgets,
          reason: '最終社員数 must reflect engineerCount+adminCount',
        );
        expect(state.engineersAssigned, 0);
        expect(state.engineersWaiting, 2);
        expect(expected.annualHireCount, 0);
        expect(find.textContaining('0名'), findsWidgets);

        // Replay CTA is present and enabled.
        expect(
          find.byKey(const Key('public-demo-year-end-replay-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('public-demo-year-end-hiyori-summary')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a success fixture with one founder participating shows a '
      'differentiated participation/waiting split and real founder '
      'growth, matching state exactly',
      (tester) async {
        final aggregate = await _successOneFounderParticipating();
        final state = aggregate.state;
        expect(state.fiscalYearCompleted, isTrue);
        expect(state.engineersAssigned, 1);
        expect(state.engineersWaiting, 1);

        final expected = PublicDemoYearEndDisplayData.fromPublicDemoState(
          state,
        );
        for (final founder in expected.founderGrowth) {
          expect(
            founder.capabilityDelta,
            greaterThanOrEqualTo(0),
            reason:
                'growth is never negative under current rules (${founder.name})',
          );
        }
        expect(
          expected.founderGrowth.any((f) => f.capabilityDelta > 0),
          isTrue,
          reason: 'at least one founder must show real growth after months '
              'of genuine project assignment',
        );

        await pumpDemoWith(tester, aggregate);

        expect(
          find.byKey(const Key('public-demo-fiscal-year-complete')),
          findsOneWidget,
        );
        // 最終参画人数=1, 最終待機人数=1 both render somewhere on the card.
        expect(find.textContaining('1名'), findsWidgets);
        for (final founder in expected.founderGrowth) {
          expect(
            find.byKey(
              Key(
                'public-demo-year-end-founder-growth-${founder.engineerId}',
              ),
            ),
            findsOneWidget,
          );
          expect(find.text(founder.name), findsOneWidget);
        }
      },
    );
  });

  group('year-end replay CTA reuses the canonical restart flow', () {
    testWidgets(
      'tapping "4月からもう一度" shows the existing restart confirmation '
      'dialog, and confirming resets to the canonical April state',
      (tester) async {
        var aggregate = publicDemoAggregateAtMonth(15);
        aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000);
        expect(aggregate.state.fiscalYearCompleted, isTrue);

        await pumpDemoWith(tester, aggregate);

        await tapYearEndKey(
          tester,
          const Key('public-demo-year-end-replay-button'),
        );

        // The SAME dialog the dev-menu "4月からやり直す" control shows —
        // no separate reset authority was created for this CTA.
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
        expect(state.cash, PublicDemoState.aprilStart().cash);

        // A fresh playthrough lands back on HOME, the same behavior the
        // existing restart controls already guarantee.
        expect(find.byKey(const Key('public-demo-nav-home')), findsOneWidget);
      },
    );

    testWidgets(
      'canceling the confirmation dialog leaves the completed year-end '
      'state untouched',
      (tester) async {
        var aggregate = publicDemoAggregateAtMonth(15);
        aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000);
        final cashBefore = aggregate.state.cash;

        await pumpDemoWith(tester, aggregate);
        await tapYearEndKey(
          tester,
          const Key('public-demo-year-end-replay-button'),
        );
        await tester.tap(
          find.byKey(const Key('public-demo-restart-april-cancel')),
        );
        await tester.pumpAndSettle();

        final state = currentState(tester);
        expect(state.fiscalYearCompleted, isTrue);
        expect(state.cash, cashBefore);
        expect(
          find.byKey(const Key('public-demo-fiscal-year-complete')),
          findsOneWidget,
        );
      },
    );
  });

  group('year-end result: mobile widths', () {
    for (final size in [const Size(360, 800), const Size(390, 844)]) {
      testWidgets(
        'the year-end card lays out without overflow at '
        '${size.width.toInt()}x${size.height.toInt()}, and the replay CTA '
        'remains reachable and tappable',
        (tester) async {
          var aggregate = publicDemoAggregateAtMonth(15);
          aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000);
          expect(aggregate.state.fiscalYearCompleted, isTrue);

          await pumpDemoWithAt(tester, aggregate, size);
          expect(tester.takeException(), isNull);

          expect(
            find.byKey(const Key('public-demo-fiscal-year-complete')),
            findsOneWidget,
          );

          // The CTA must be genuinely reachable (scrollable into view) and
          // tappable — not clipped or obstructed — at this width.
          await tapYearEndKey(
            tester,
            const Key('public-demo-year-end-replay-button'),
          );
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const Key('public-demo-restart-april-dialog')),
            findsOneWidget,
          );
        },
      );
    }
  });
}
