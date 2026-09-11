// SES EMPLOYEE-UI-PHASE-1: the 社員タブ is reorganized into four
// information-hierarchy sections — 1) 社員一覧・現在状態 (`_employeeRosterSection`,
// new), 2) 今やるべき社員アクション (`_employeeNextActionsSection`), 3) 参画中案件
// (`_employeeActiveProjectsSection`, the existing SES ACTIVE-PROJECT-VISIBILITY
// Phase 1 card), 4) 成長・スキルシート・研修 (`_employeeGrowthSection`) — instead of
// one flat stack of cards. Every card/key/eligibility check moved verbatim
// from the prior single-`Column` build (see
// `public_demo_active_project_visibility_test.dart` for the APV card's own
// pre-existing coverage, unaffected by this reorganization).
//
// Every fixture here is built by chaining the SAME real domain commands
// production code uses, starting from `PublicDemoAggregate.initial()` (via
// `publicDemoAggregateAtMonth` / `publicDemoAdvanceEngineerToOrdered` /
// `recoverAssignment`), matching the APV suite's own established technique —
// never a UI-driven walkthrough or a hand-built fixture object.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_home_dashboard_section.dart';
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

PublicDemoWorkflowState currentWorkflow(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
            .workflow
        as PublicDemoWorkflowState;

Key rosterRowKey(String engineerId) =>
    Key('public-demo-employee-roster-row-$engineerId');

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
  await switchPublicDemoTab(tester, PublicDemoTab.employees);
}

/// eng-01 genuinely ordered then Recovery-assigned (the same real
/// `recoverAssignment` command RECOVERY-LOOP-1's own suite and the APV
/// suite's fixture use) — a truthfully "参画中" (currently assigned)
/// engineer. eng-02 is left waiting throughout (default founding capability
/// 52, below the 60 field-sales threshold), giving a real, differentiated
/// waiting/assigned fixture at [month] (8-14, or reachable pre-close at 15).
PublicDemoAggregate oneAssignedOneWaitingAtMonth(int month) {
  var aggregate = publicDemoAggregateAtMonth(month);
  aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
  aggregate = aggregate.recoverAssignment('eng-01');
  return aggregate;
}

const _targetSizes = <Size>[Size(360, 800), Size(390, 844)];

void main() {
  group('Section 1 (社員一覧・現在状態): waiting employee', () {
    testWidgets(
      'April: both founding engineers are waiting — the roster shows each '
      'one, truthfully labeled by real field-sales readiness (Issue #231 '
      'FIRST-FUN-YEAR P1: 佐藤=営業可能/鈴木=研修が必要, not both 待機), and '
      'the 待機/参画中/合計 summary line matches '
      'PublicDemoState.engineersWaiting/engineersAssigned',
      (tester) async {
        final aggregate = PublicDemoAggregate.initial();
        await pumpDemoWith(tester, aggregate);
        final state = currentState(tester);
        final workflow = currentWorkflow(tester);

        expect(state.engineersWaiting, 2);
        expect(state.engineersAssigned, 0);
        expect(workflow.engineers.length, 2);

        for (final e in workflow.engineers) {
          expect(find.byKey(rosterRowKey(e.id)), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(rosterRowKey(e.id)),
              matching: find.text(e.name),
            ),
            findsOneWidget,
          );
        }
        // eng-01 (佐藤, founding capability 78) already clears the
        // authoritative field-sales threshold (60); eng-02 (鈴木, 52) does
        // not — see publicDemoInitialEngineerRuntimes /
        // PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement.
        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-01')),
            matching: find.text('営業可能'),
          ),
          findsOneWidget,
          reason: 'eng-01 is economically waiting but already field-sales '
              'ready',
        );
        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-02')),
            matching: find.text('研修が必要'),
          ),
          findsOneWidget,
          reason: 'eng-02 is economically waiting and below the field-sales '
              'capability threshold',
        );

        expect(
          find.text('待機 2・参画中 0・合計 2'),
          findsOneWidget,
          reason:
              'the roster summary must read straight off '
              'engineersWaiting/engineersAssigned, never a second count',
        );
      },
    );
  });

  group('Section 1 + Section 3: assigned employee shows truthful 参画中, '
      'and gets an APV card', () {
    testWidgets(
      'August: eng-01 (Recovery-assigned) is 参画中 in the roster and has a '
      'Section 3 project-status card; eng-02 (still waiting) is unaffected',
      (tester) async {
        final aggregate = oneAssignedOneWaitingAtMonth(8);
        expect(aggregate.state.engineersAssigned, 1);

        await pumpDemoWith(tester, aggregate);

        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-01')),
            matching: find.text('参画中'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-01')),
            matching: find.text('翌月参画予定'),
          ),
          findsNothing,
          reason: 'an assigned engineer must never show the stale label',
        );
        // Issue #231 FIRST-FUN-YEAR P1: eng-02's founding capability (52)
        // stays below the field-sales threshold at month 8 (no training was
        // selected in this fixture), so the roster now truthfully reads
        // 研修が必要 rather than the generic 待機 both engineers used to share.
        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-02')),
            matching: find.text('研修が必要'),
          ),
          findsOneWidget,
        );

        expect(find.text('参画中案件'), findsOneWidget);
        expect(
          find.byKey(const Key('public-demo-active-project-status-eng-01')),
          findsOneWidget,
        );
      },
    );
  });

  group('Stale ordered-vs-assigned regression: the same ordered stage reads '
      'differently once actually assigned', () {
    // Same engineer (eng-01, capability 78 — reliably clears both
    // interviews) in two different real aggregates, each pumped in its own
    // `testWidgets` (a fresh `WidgetTester`/State per case — pumping a
    // second, structurally-identical `PublicDemo01PlaceholderScreen` into
    // the same tester would let Flutter's own element reconciliation reuse
    // the first State instead of re-`initState`-ing from the new
    // saveService, which would silently keep testing the first aggregate):
    // one where the `ordered` stage has already been turned into a real
    // assignment (`recoverAssignment`) and one where it deliberately has
    // not. Comparing the same id under both real states — rather than
    // eng-02, whose lower founding capability (52) can genuinely fail the
    // client interview before ever reaching `ordered` — isolates the
    // assignment fact as the only variable.
    testWidgets(
      'eng-01 ordered AND Recovery-assigned reads 参画中',
      (tester) async {
        var aggregate = publicDemoAggregateAtMonth(8);
        aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
        aggregate = aggregate.recoverAssignment('eng-01');
        expect(aggregate.workflow.assignedEngineerIds(month: 8), {'eng-01'});

        await pumpDemoWith(tester, aggregate);
        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-01')),
            matching: find.text('参画中'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'eng-01 ordered but NOT YET assigned still truthfully reads 参画予定 '
      '(PR #238 review follow-up: unified taxonomy renamed the raw '
      "engineerStatus '翌月参画予定' to '参画予定' for this exact case) — the "
      'fix is about the assignment fact, not about hiding the ordered '
      'stage',
      (tester) async {
        var aggregate = publicDemoAggregateAtMonth(8);
        aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
        expect(
          aggregate.workflow.assignedEngineerIds(month: 8),
          isEmpty,
          reason: 'ordered but never recovered into a real assignment',
        );

        await pumpDemoWith(tester, aggregate);
        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-01')),
            matching: find.text('参画予定'),
          ),
          findsOneWidget,
          reason: 'eng-01 has genuinely not joined a project yet',
        );
      },
    );
  });

  group('Section 2 (今やるべき社員アクション): next actionable employee state', () {
    testWidgets(
      'April: the ready engineer (capability >= 60) gets 営業準備OK and a '
      'スキルシート確認 action; the not-yet-ready one gets the truthful lock '
      'banner instead — both under the Section 2 header',
      (tester) async {
        final aggregate = PublicDemoAggregate.initial();
        await pumpDemoWith(tester, aggregate);

        expect(find.text('今やるべき社員アクション'), findsOneWidget);
        expect(find.text('営業準備OK'), findsOneWidget);
        expect(find.text('スキルシート確認'), findsOneWidget);
        expect(find.byKey(const Key('public-demo-field-sales-lock-eng-02')), findsOneWidget);
      },
    );
  });

  group('Section 4 (成長・スキルシート・研修): existing routes stay reachable', () {
    testWidgets(
      'April: スキルシート確認 still opens the real PublicDemoSkillSheetSheet '
      'for the ready engineer',
      (tester) async {
        final aggregate = PublicDemoAggregate.initial();
        await pumpDemoWith(tester, aggregate);

        // SES HUMAN-REPLAY PRE-FIX P1: the filter-chip tap-target fix
        // (48dp minimum) grew Section 1's height enough that this button
        // is no longer guaranteed to sit inside the default unscrolled
        // test viewport — scroll it into view first, same as every other
        // tap-driven test in this suite already does.
        await tester.ensureVisible(find.text('スキルシート確認'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('スキルシート確認'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('public-demo-skill-sheet-eng-01')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('public-demo-skill-sheet-cancel-eng-01')),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'month 6: the standalone internal-training card is reachable under '
      'the Section 4 header for a still-waiting engineer runtime',
      (tester) async {
        final aggregate = publicDemoAggregateAtMonth(6);
        await pumpDemoWith(tester, aggregate);

        expect(find.text('成長・スキルシート・研修'), findsOneWidget);
        expect(
          find.byKey(const Key('public-demo-internal-training-eng-01')),
          findsOneWidget,
        );
      },
    );
  });

  group('March / month 15', () {
    testWidgets(
      'an engineer assigned continuously into month 15 (pre-close) keeps '
      'the truthful 参画中 roster label and the Section 3 project card',
      (tester) async {
        var aggregate = oneAssignedOneWaitingAtMonth(8);
        while (aggregate.state.month < 15) {
          aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000);
        }
        expect(aggregate.state.month, 15);
        expect(aggregate.state.fiscalYearCompleted, isFalse);

        await pumpDemoWith(tester, aggregate);

        expect(
          find.descendant(
            of: find.byKey(rosterRowKey('eng-01')),
            matching: find.text('参画中'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('public-demo-active-project-status-eng-01')),
          findsOneWidget,
        );
      },
    );
  });

  group('HOME Freeze regression', () {
    testWidgets(
      'switching to 社員 and back to ホーム leaves HOME exactly as before — '
      'no employee-tab-only key or section leaks into it',
      (tester) async {
        final aggregate = oneAssignedOneWaitingAtMonth(8);
        await pumpDemoWith(tester, aggregate);
        expect(find.text('社員一覧・現在状態'), findsOneWidget);

        await switchPublicDemoTab(tester, PublicDemoTab.home);
        expect(find.byType(PublicDemoHomeDashboardSection), findsOneWidget);
        expect(find.text('社員一覧・現在状態'), findsNothing);
        expect(find.text('今やるべき社員アクション'), findsNothing);
        expect(find.text('参画中案件'), findsNothing);
        expect(find.text('成長・スキルシート・研修'), findsNothing);
        expect(
          find.byKey(const Key('public-demo-active-project-status-eng-01')),
          findsNothing,
        );
      },
    );
  });

  group('360x800 / 390x844, TextScaler 1.3 / 2.0: no horizontal overflow', () {
    for (final size in _targetSizes) {
      for (final textScale in [1.0, 1.3, 2.0]) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} / textScale '
          '$textScale: the 社員 tab renders with no overflow exception, and '
          'the roster/section content stays within the screen width',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            final aggregate = oneAssignedOneWaitingAtMonth(8);
            await tester.pumpWidget(
              MaterialApp(
                theme: SesTheme.build(),
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
            await switchPublicDemoTab(tester, PublicDemoTab.employees);

            expect(
              tester.takeException(),
              isNull,
              reason:
                  'a RenderFlex/RenderBox overflow at an enlarged TextScaler '
                  'surfaces as a FlutterError here',
            );

            final rosterRect = tester.getRect(
              find.byKey(const Key('public-demo-employee-roster-section')),
            );
            expect(rosterRect.left, greaterThanOrEqualTo(0.0));
            expect(rosterRect.right, lessThanOrEqualTo(size.width));

            for (final rowKey in [
              rosterRowKey('eng-01'),
              rosterRowKey('eng-02'),
            ]) {
              final rowRect = tester.getRect(find.byKey(rowKey));
              expect(rowRect.left, greaterThanOrEqualTo(0.0));
              expect(rowRect.right, lessThanOrEqualTo(size.width));
            }

            final apvRect = tester.getRect(
              find.byKey(const Key('public-demo-active-project-status-eng-01')),
            );
            expect(apvRect.left, greaterThanOrEqualTo(0.0));
            expect(apvRect.right, lessThanOrEqualTo(size.width));
          },
        );
      }
    }
  });
}
