// SES POST-HOME-FREEZE Small-UX-Fix (Fresh Audit Option 1): before this fix,
// 会計's "○月開始結果" heading rendered every month from August through
// (pre-fiscal-year-completion) March, but only August ever had a body under
// it (the July payroll/summer-bonus recap). September-February, and March
// before the fiscal year completes, rendered a bold section heading over an
// empty body — a section that looked like it had content but did not.
//
// This suite pins the fix at the real screen, for every affected month, by
// loading a [PublicDemoAggregate] built at each target month via the same
// real month-close commands production code uses (the technique already
// established by `publicDemoAggregateAtMonth` and
// `public_demo_01_home_cash_forecast_advice_test.dart`'s `_FixedSaveService`)
// — never a UI-layer shortcut or a new domain fact.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

import '../../game/public_demo/test_support/public_demo_recovery_test_helpers.dart';
import 'public_demo_tab_test_helpers.dart';

/// Mirrors `public_demo_01_home_cash_forecast_advice_test.dart`'s own
/// `_FixedSaveService` — injects a pre-built aggregate as the "restored
/// save" so each test starts directly at its target month instead of
/// re-driving every intervening UI step.
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

/// No engineer or applicant is ever run through the sales pipeline by
/// [publicDemoAggregateAtMonth], and it defaults to a deliberately small
/// monthly expense figure precisely so a long run of ordinary-month closes
/// never drives financialStatus into cashShortage/bankruptcy as a fixture
/// artifact — see that helper's own doc. Exactly what this suite needs: only
/// the heading's presence/absence is under test, not finance outcomes.
Future<PublicDemoAggregate> _at(int month) async =>
    publicDemoAggregateAtMonth(month);

void main() {
  group('the empty "○月開始結果" heading is gone where it never had a body', () {
    testWidgets('August keeps its existing heading and body', (tester) async {
      await pumpDemoWith(tester, await _at(8));

      expect(find.text('8月開始結果'), findsOneWidget);
      expect(find.text('7月分の給与を反映しました'), findsOneWidget);
      expect(find.text('夏季賞与 なし'), findsOneWidget);
    });

    for (final month in [9, 10, 11, 12, 13, 14]) {
      testWidgets(
        'month $month renders no "○月開始結果" heading (no body ever '
        'existed for it)',
        (tester) async {
          await pumpDemoWith(tester, await _at(month));

          expect(find.textContaining('開始結果'), findsNothing);
        },
      );
    }

    testWidgets(
      'March (15) before fiscal-year completion renders no "○月開始結果" '
      'heading either',
      (tester) async {
        final aggregate = await _at(15);
        expect(
          aggregate.state.fiscalYearCompleted,
          isFalse,
          reason: 'this fixture must land before fiscal-year completion',
        );

        await pumpDemoWith(tester, aggregate);

        expect(find.textContaining('開始結果'), findsNothing);
        expect(
          find.byKey(const Key('public-demo-fiscal-year-complete')),
          findsNothing,
        );
      },
    );
  });
}
