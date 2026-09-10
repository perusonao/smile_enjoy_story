// Issue #231 FIRST-FUN-YEAR P1: Initial Employee / SkillSheet Gate Clarity.
//
// Fresh Audit found that `engineerStatus`'s '待機' label was shared by every
// still-`waiting` engineer regardless of real field-sales readiness — a
// fresh April player could not tell 佐藤健 (founding capability 78, already
// field-sales ready) apart from 鈴木葵 (52, below the threshold) without
// scrolling from Section 1 (社員一覧・現在状態) down to Section 2's
// per-engineer action card. `PublicDemoEngineerRuntime.isReadyForFieldSales`
// / `fieldSalesCapabilityRequirement` already carried this fact
// authoritatively; only the roster's own presentation was silent about it.
//
// These tests cover the resulting `_currentEmployeeStatusLabel`/
// `_employeeStatusTone` roster changes: real-authority-derived labels
// ('営業可能'/'研修が必要'), the reason caption reusing the exact same
// authority the existing Section 2 lock banner already reads (never a
// duplicated or re-hardcoded threshold/capability), the label flipping once
// training genuinely raises capability past the threshold (proving the
// training-effect authority is what drives the roster, not a UI-local
// state), and that the fact survives a real save/reload round trip.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
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

Key _rosterRowKey(String engineerId) =>
    Key('public-demo-employee-roster-row-$engineerId');

Future<void> _pumpDemoWith(
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
  await switchPublicDemoTab(tester, PublicDemoTab.employees);
}

void main() {
  group('Roster readiness labels read PublicDemoEngineerRuntime authority', () {
    testWidgets(
      'April fresh start: eng-01 (78, ready) reads 営業可能 with no reason '
      'caption; eng-02 (52, not ready) reads 研修が必要 with a reason caption '
      'stating the exact fieldSalesCapabilityRequirement/actualCapability '
      'authority values, never a re-hardcoded number',
      (tester) async {
        final aggregate = PublicDemoAggregate.initial();
        final threshold =
            PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement;
        final eng01 = aggregate.state.runtimeForOrNull('eng-01')!;
        final eng02 = aggregate.state.runtimeForOrNull('eng-02')!;
        expect(eng01.isReadyForFieldSales, isTrue);
        expect(eng02.isReadyForFieldSales, isFalse);

        await _pumpDemoWith(tester, aggregate);

        expect(
          find.descendant(
            of: find.byKey(_rosterRowKey('eng-01')),
            matching: find.text('営業可能'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(_rosterRowKey('eng-01')),
            matching: find.textContaining('実力$threshold以上が必要'),
          ),
          findsNothing,
          reason: 'a ready engineer needs no reason caption for a gate '
              'that does not apply to them',
        );

        expect(
          find.descendant(
            of: find.byKey(_rosterRowKey('eng-02')),
            matching: find.text('研修が必要'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(_rosterRowKey('eng-02')),
            matching: find.text(
              '営業には実力$threshold以上が必要（現在${eng02.actualCapability}）',
            ),
          ),
          findsOneWidget,
          reason: 'the reason must read the same authoritative threshold/'
              'capability the Section 2 lock banner already uses, not an '
              'independently invented copy',
        );
      },
    );

    testWidgets(
      'genuine internal training that raises eng-02 past the threshold '
      'flips the roster label from 研修が必要 to 営業可能 — the label tracks '
      'PublicDemoGrowthEngine authority, not a one-time April snapshot',
      (tester) async {
        // closeOrdinaryMonth (the only close this loop needs to repeat) is
        // a no-op before month 8 — start from the real month-8 aggregate
        // RECOVERY-LOOP-1's own suite already builds (closeApril → closeMay
        // → closeJune → closeJuly, nobody ever run through the sales
        // pipeline, so eng-02 stays genuinely waiting throughout).
        var aggregate = publicDemoAggregateAtMonth(8);
        var ready = aggregate.state.runtimeForOrNull('eng-02')!.isReadyForFieldSales;
        expect(ready, isFalse);

        // Real production commands only: select internal training for
        // eng-02, then close the month — the same
        // selectInternalTraining/closeOrdinaryMonth pair the 社員 tab's own
        // training card and month-close button use. Bounded by the real
        // fiscal year's remaining ordinary-close months (8-14) so a genuine
        // growth-formula regression fails loudly (via the `ready` assertion
        // below) instead of looping forever.
        var months = 0;
        while (!ready && aggregate.state.month <= 14 && months < 10) {
          aggregate = aggregate.selectInternalTraining('eng-02');
          aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000);
          ready = aggregate.state.runtimeForOrNull('eng-02')!.isReadyForFieldSales;
          months++;
        }
        expect(
          ready,
          isTrue,
          reason: 'repeated internal training must eventually clear the '
              'field-sales threshold — if this fails, PublicDemoGrowthEngine '
              'itself regressed, not this Issue #231 UI change',
        );

        await _pumpDemoWith(tester, aggregate);

        expect(
          find.descendant(
            of: find.byKey(_rosterRowKey('eng-02')),
            matching: find.text('営業可能'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(_rosterRowKey('eng-02')),
            matching: find.text('研修が必要'),
          ),
          findsNothing,
        );
      },
    );

    group('PR #233 Codex review (P2): 営業可能 must not be shown in a month '
        'with no actual sales-flow control to act on it', () {
      testWidgets(
        'May (month 5): eng-01 is genuinely ready but still waiting — no '
        'ec(i) card renders in May for any engineer, so the roster falls '
        'back to the plain 待機 label/tone instead of naming an unreachable '
        'action',
        (tester) async {
          final aggregate = publicDemoAggregateAtMonth(5);
          expect(
            aggregate.state.runtimeForOrNull('eng-01')!.isReadyForFieldSales,
            isTrue,
          );

          await _pumpDemoWith(tester, aggregate);

          expect(
            find.descendant(
              of: find.byKey(_rosterRowKey('eng-01')),
              matching: find.text('待機'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(_rosterRowKey('eng-01')),
              matching: find.text('営業可能'),
            ),
            findsNothing,
          );
        },
      );

      testWidgets(
        'March (month 15): eng-01 is genuinely ready but still waiting — '
        'ec(i) never renders in March either, so the roster still reads '
        '待機, never 営業可能, for the entire remainder of the fiscal year',
        (tester) async {
          final aggregate = publicDemoAggregateAtMonth(15);
          expect(aggregate.state.month, 15);
          expect(
            aggregate.state.runtimeForOrNull('eng-01')!.isReadyForFieldSales,
            isTrue,
          );

          await _pumpDemoWith(tester, aggregate);

          expect(
            find.descendant(
              of: find.byKey(_rosterRowKey('eng-01')),
              matching: find.text('待機'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(_rosterRowKey('eng-01')),
              matching: find.text('営業可能'),
            ),
            findsNothing,
          );
        },
      );

      testWidgets(
        'June (month 6): a founding engineer (never in joinedApplicantIds) '
        'gets no June-specific ec(i) render site either — still 待機, not '
        '営業可能',
        (tester) async {
          final aggregate = publicDemoAggregateAtMonth(6);
          expect(
            aggregate.state.runtimeForOrNull('eng-01')!.isReadyForFieldSales,
            isTrue,
          );
          expect(aggregate.workflow.applicants.any(
            (a) => a.id == 'eng-01',
          ), isFalse);

          await _pumpDemoWith(tester, aggregate);

          expect(
            find.descendant(
              of: find.byKey(_rosterRowKey('eng-01')),
              matching: find.text('待機'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(_rosterRowKey('eng-01')),
              matching: find.text('営業可能'),
            ),
            findsNothing,
          );
        },
      );

      testWidgets(
        'July (month 8, inside the RECOVERY-LOOP-1 window): the same '
        'still-waiting, ready eng-01 now DOES read 営業可能 — proving the '
        'gate is month/reachability-specific, not a blanket suppression',
        (tester) async {
          final aggregate = publicDemoAggregateAtMonth(8);
          expect(
            aggregate.state.runtimeForOrNull('eng-01')!.isReadyForFieldSales,
            isTrue,
          );

          await _pumpDemoWith(tester, aggregate);

          expect(
            find.descendant(
              of: find.byKey(_rosterRowKey('eng-01')),
              matching: find.text('営業可能'),
            ),
            findsOneWidget,
          );
        },
      );
    });

    test(
      'save/reload (PublicDemoSaveCodec round trip) preserves the same '
      'readiness fact the roster label is derived from — no UI-local state '
      'is persisted or duplicated for this label',
      () {
        const codec = PublicDemoSaveCodec();
        final aggregate = PublicDemoAggregate.initial();
        final before = (
          eng01: aggregate.state.runtimeForOrNull('eng-01')!.isReadyForFieldSales,
          eng02: aggregate.state.runtimeForOrNull('eng-02')!.isReadyForFieldSales,
        );

        final restored = codec.decode(codec.encode(aggregate));
        expect(restored, isNotNull);
        final after = (
          eng01: restored!.state.runtimeForOrNull('eng-01')!.isReadyForFieldSales,
          eng02: restored.state.runtimeForOrNull('eng-02')!.isReadyForFieldSales,
        );

        expect(after, equals(before));
        expect(before.eng01, isTrue);
        expect(before.eng02, isFalse);
      },
    );
  });
}
