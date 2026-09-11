// SES Employee Status Unified Display (Fresh Audit,
// docs/reports/SES_FIRST-FUN-YEAR_Employee-Status-Unified-Display_Fresh-Audit.md):
// widget-level regression coverage for the two concrete inconsistencies the
// Fresh Audit confirmed by tracing the code (§3), now fixed by routing the
// 社員タブ roster and both SkillSheet call sites through
// PublicDemoEmployeeStatusResolver — see that file's own doc.
//
// Pure-function coverage of the resolver itself lives in
// `public_demo_employee_status_resolver_test.dart`; this file exercises the
// real, unchanged [PublicDemo01PlaceholderScreen] widget so a regression in
// either call site (roster card, SkillSheet) is caught the same way the
// existing suites already catch one.
//
// Every fixture below is built by chaining the same real domain commands the
// existing roster suites already use
// (`test/game/public_demo/test_support/public_demo_recovery_test_helpers.dart`)
// — never a hand-built/UI-driven fixture.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';

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

Future<void> pumpDemoWith(
  WidgetTester tester,
  PublicDemoAggregate aggregate, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: PublicDemo01PlaceholderScreen(
          saveService: _FixedSaveService(aggregate),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await switchPublicDemoTab(tester, PublicDemoTab.employees);
}

/// eng-01 genuinely ordered, then Recovery-assigned (real 参画中) at
/// [month] — the same fixture shape
/// `public_demo_employee_roster_phase_b1_test.dart`'s own
/// `oneAssignedOneWaitingAtMonth` uses. eng-02 stays waiting.
PublicDemoAggregate _oneAssignedOneWaitingAtMonth(int month) {
  var aggregate = publicDemoAggregateAtMonth(month);
  aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
  aggregate = aggregate.recoverAssignment('eng-01');
  return aggregate;
}

void main() {
  group(
    'Fresh Audit §3 fix 1: SkillSheet must show the same 参画中 the roster '
    'does for an ordered + currently-assigned engineer',
    () {
      testWidgets(
        'eng-01 (ordered + assigned at month 8) — SkillSheet reads 参画中, '
        'never the stale 翌月参画予定',
        (tester) async {
          final aggregate = _oneAssignedOneWaitingAtMonth(8);

          // Fixture sanity: eng-01 is genuinely ordered AND counted in
          // assignedEngineerIds — exactly the combination the resolver's
          // top-priority branch requires.
          final sato = aggregate.workflow.engineers.firstWhere(
            (e) => e.id == 'eng-01',
          );
          expect(sato.stage, PublicDemoSalesStage.ordered);
          expect(
            aggregate.workflow
                .assignedEngineerIds(month: aggregate.state.month)
                .contains('eng-01'),
            isTrue,
          );

          await pumpDemoWith(tester, aggregate);

          // The roster badge already reads 参画中 (pre-existing, unchanged
          // behavior) — asserted here only as the baseline the SkillSheet
          // must now agree with.
          expect(
            find.descendant(
              of: find.byKey(
                const Key('public-demo-employee-roster-row-eng-01'),
              ),
              matching: find.text('参画中'),
            ),
            findsOneWidget,
          );

          // The always-available SkillSheet entry point
          // (`_viewEmployeeSkillSheet` — CORE-GAMEPLAY Phase 4.5).
          await tester.tap(
            find.byKey(
              const Key('public-demo-employee-roster-skill-sheet-eng-01'),
            ),
          );
          await tester.pumpAndSettle();

          final sheet = find.byKey(
            const Key('public-demo-skill-sheet-eng-01'),
          );
          expect(sheet, findsOneWidget);
          // '参画中' legitimately renders twice inside the sheet — once as
          // the header's summary-chip band (`_SummaryBand`, pre-existing,
          // unrelated to this fix) and once as the dedicated status chip
          // (`_HeaderSection`'s teal `SkillChip(data.statusLabel, ...)`,
          // the one this fix changed) — so this only pins "at least one",
          // never "exactly one".
          expect(
            find.descendant(of: sheet, matching: find.text('参画中')),
            findsAtLeastNWidgets(1),
            reason:
                'Fresh Audit §3: this exact call site used to pass raw '
                'engineerStatus(engineer) straight through and kept '
                'showing 翌月参画予定 here even after the roster/HOME '
                'already said 参画中 for the same engineer.',
          );
          expect(
            find.descendant(of: sheet, matching: find.text('翌月参画予定')),
            findsNothing,
          );
        },
      );
    },
  );

  group(
    'Fresh Audit §3/§6 fix 2: a month-training-selection must never '
    'override an otherwise-correct label/tone',
    () {
      testWidgets(
        'eng-01 (waiting, field-sales ready, action reachable) with this '
        "month's internal training also selected still reads 営業可能 — "
        'never the training-tone label mismatch the Fresh Audit found',
        (tester) async {
          // Month 8 is within RECOVERY-LOOP-1's July-February window, where
          // a still-waiting engineer's 営業可能 is genuinely reachable
          // (_fieldSalesActionReachableThisMonth), and also >= 5, where the
          // internal-training card is unconditionally reachable — the exact
          // overlap this Issue's fix concerns.
          var aggregate = publicDemoAggregateAtMonth(8);
          final sato = aggregate.workflow.engineers.firstWhere(
            (e) => e.id == 'eng-01',
          );
          // Fixture sanity: eng-01 is genuinely still waiting and
          // field-sales ready (founding capability 78 >= the 60 threshold)
          // — nothing here touched the sales pipeline.
          expect(sato.stage, PublicDemoSalesStage.waiting);
          expect(
            aggregate.state.runtimeForOrNull('eng-01')!.isReadyForFieldSales,
            isTrue,
          );

          aggregate = aggregate.selectInternalTraining('eng-01');
          expect(
            aggregate.state.trainingSelections.containsKey('eng-01'),
            isTrue,
            reason:
                'fixture sanity: the real selectInternalTraining command '
                'must have actually recorded the selection (affordable, '
                'not already assigned, fiscal year not completed)',
          );

          await pumpDemoWith(tester, aggregate);

          final rosterRow = find.byKey(
            const Key('public-demo-employee-roster-row-eng-01'),
          );
          expect(
            find.descendant(of: rosterRow, matching: find.text('営業可能')),
            findsOneWidget,
            reason:
                'the label must stay 営業可能 — trainingSelections is not '
                'a resolver input and can never override it',
          );
          expect(
            find.descendant(of: rosterRow, matching: find.text('研修が必要')),
            findsNothing,
          );

          // The badge tone must agree — no way to assert a Container's
          // background color by key alone here without over-fitting to
          // paint internals, so this pins the resolver-level guarantee
          // (covered exhaustively in
          // public_demo_employee_status_resolver_test.dart) end-to-end:
          // the SAME PublicDemoEmployeeStatusDisplay value backs both the
          // label Text and the badge Container in one widget, so a correct
          // label here is only possible if the tone agrees too.
        },
      );
    },
  );

  group(
    'PR #238 review follow-up (P1): sales-pipeline sub-stages collapse to '
    '営業中 in both the roster and SkillSheet, and an ordered-but-not-yet-'
    'assigned engineer reads 参画予定, never the raw per-sub-stage label',
    () {
      testWidgets(
        'eng-01 genuinely at stage == selling (real startSkillSheetReview → '
        'beginSelling chain) reads 営業中 in the roster and in SkillSheet — '
        'never the raw 営業準備/営業中-sub-stage-specific label',
        (tester) async {
          var aggregate = publicDemoAggregateAtMonth(8);
          aggregate = aggregate
              .startSkillSheetReview('eng-01')
              .beginSelling('eng-01');
          final sato = aggregate.workflow.engineers.firstWhere(
            (e) => e.id == 'eng-01',
          );
          expect(sato.stage, PublicDemoSalesStage.selling);

          await pumpDemoWith(tester, aggregate);

          final rosterRow = find.byKey(
            const Key('public-demo-employee-roster-row-eng-01'),
          );
          expect(
            find.descendant(of: rosterRow, matching: find.text('営業中')),
            findsOneWidget,
          );

          await tester.tap(
            find.byKey(
              const Key('public-demo-employee-roster-skill-sheet-eng-01'),
            ),
          );
          await tester.pumpAndSettle();
          final sheet = find.byKey(
            const Key('public-demo-skill-sheet-eng-01'),
          );
          expect(sheet, findsOneWidget);
          expect(
            find.descendant(of: sheet, matching: find.text('営業中')),
            findsAtLeastNWidgets(1),
          );
        },
      );

      testWidgets(
        'eng-01 genuinely ordered but NOT YET assigned reads 参画予定 in the '
        'roster — the unified label, never the raw 翌月参画予定 text',
        (tester) async {
          var aggregate = publicDemoAggregateAtMonth(8);
          aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
          expect(
            aggregate.workflow.assignedEngineerIds(month: 8),
            isEmpty,
            reason: 'ordered but never recovered into a real assignment',
          );

          await pumpDemoWith(tester, aggregate);

          final rosterRow = find.byKey(
            const Key('public-demo-employee-roster-row-eng-01'),
          );
          expect(
            find.descendant(of: rosterRow, matching: find.text('参画予定')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: rosterRow, matching: find.text('翌月参画予定')),
            findsNothing,
          );
        },
      );
    },
  );

  group('mobile density — the two fixed scenarios add no new overflow', () {
    for (final size in [Size(360, 800), Size(390, 844)]) {
      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} / '
          'TextScaler $textScale: ordered+assigned roster card renders '
          'with no overflow',
          (tester) async {
            await pumpDemoWith(
              tester,
              _oneAssignedOneWaitingAtMonth(8),
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
