// SES ACTIVE-PROJECT-VISIBILITY Phase 1: a read-only per-engineer status
// card on 社員 (`activeProjectStatusCard`) showing which project a
// currently-assigned engineer is in and its state — engineerName,
// projectName, deliveryPressure, budgetHealth — sourced only from
// PublicDemoAssignment, the authority PublicDemoWorkflowState.assignments /
// assignedEngineerIds already hold. Every fixture here is built by chaining
// the SAME real domain commands production code uses, starting from
// PublicDemoAggregate.initial() (via publicDemoAggregateAtMonth /
// publicDemoAdvanceEngineerToOrdered / recoverAssignment), matching
// public_demo_01_year_end_result_test.dart's own established technique
// (_FixedSaveService injecting a pre-built aggregate as the "restored save")
// rather than a UI-driven walkthrough, so this suite is deterministic and
// fast — reaching August, and March/month15, without 7+ real month
// transitions.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_founder_follow_up.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_01_placeholder_screen.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_home_dashboard_section.dart';

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

PublicDemoWorkflowState currentWorkflow(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
            .workflow
        as PublicDemoWorkflowState;

Key activeProjectStatusKey(String engineerId) =>
    Key('public-demo-active-project-status-$engineerId');

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

/// eng-01 genuinely ordered then Recovery-assigned (`recoverAssignment`, the
/// same real command RECOVERY-LOOP-1's own finance suite and the Year-End
/// suite's fixture use) at [month] (8-14, or reachable pre-close at 15).
/// eng-02 is left waiting throughout — her founding capability (52) is
/// below the field-sales capability requirement (60), so she is never
/// Recovery-eligible — giving a real, differentiated
/// participating(eng-01)/waiting(eng-02) fixture, matching
/// public_demo_01_year_end_result_test.dart's own
/// `_successOneFounderParticipating` fixture technique.
PublicDemoAggregate oneFounderParticipatingAtMonth(int month) {
  var aggregate = publicDemoAggregateAtMonth(month);
  aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
  aggregate = aggregate.recoverAssignment('eng-01');
  return aggregate;
}

void main() {
  group('SES ACTIVE-PROJECT-VISIBILITY Phase 1: assigned-engineer card', () {
    testWidgets(
      'an assigned engineer (eng-01, August) gets a project status card '
      'whose engineerName/projectName/deliveryPressure/budgetHealth match '
      'the authoritative PublicDemoAssignment — and fieldEvaluation is not '
      'shown',
      (tester) async {
        final aggregate = oneFounderParticipatingAtMonth(8);
        expect(aggregate.state.month, 8);
        expect(
          aggregate.state.engineersAssigned,
          1,
          reason: 'recoverAssignment must have actually assigned eng-01',
        );

        await pumpDemoWith(tester, aggregate);

        final assignment = currentWorkflow(
          tester,
        ).assignments.firstWhere((a) => a.engineerId == 'eng-01');

        final cardKey = activeProjectStatusKey('eng-01');
        expect(find.byKey(cardKey), findsOneWidget);

        expect(
          find.descendant(
            of: find.byKey(cardKey),
            matching: find.text(assignment.engineerName),
          ),
          findsOneWidget,
          reason: 'engineerName must match PublicDemoAssignment.engineerName',
        );
        expect(
          find.descendant(
            of: find.byKey(cardKey),
            matching: find.textContaining(assignment.projectName),
          ),
          findsOneWidget,
          reason: 'projectName must match PublicDemoAssignment.projectName',
        );
        expect(
          find.descendant(
            of: find.byKey(cardKey),
            matching: find.textContaining('${assignment.deliveryPressure}'),
          ),
          findsOneWidget,
          reason:
              'deliveryPressure must match '
              'PublicDemoAssignment.deliveryPressure',
        );
        expect(
          find.descendant(
            of: find.byKey(cardKey),
            matching: find.textContaining('${assignment.budgetHealth}'),
          ),
          findsOneWidget,
          reason: 'budgetHealth must match PublicDemoAssignment.budgetHealth',
        );

        // Phase 1 deliberately shows exactly four facts (name, project,
        // deliveryPressure, budgetHealth) — never a fifth line for
        // fieldEvaluation, which is always its constructed default (50)
        // today and would misrepresent a constant as a real evaluation.
        expect(
          find.descendant(
            of: find.byKey(cardKey),
            matching: find.byType(Text),
          ),
          findsNWidgets(4),
        );
      },
    );

    testWidgets(
      'August: eng-01 (assigned) has a card, eng-02 (waiting) does not',
      (tester) async {
        final aggregate = oneFounderParticipatingAtMonth(8);
        await pumpDemoWith(tester, aggregate);

        expect(currentWorkflow(tester).assignedEngineerIds(month: 8), {
          'eng-01',
        });
        expect(find.byKey(activeProjectStatusKey('eng-01')), findsOneWidget);
        expect(find.byKey(activeProjectStatusKey('eng-02')), findsNothing);
      },
    );

    testWidgets(
      'March (month 15, pre-close): the still-assigned engineer keeps a '
      'project status card — continuity through the fiscal-year-extension '
      'window, not just August',
      (tester) async {
        // recoverAssignment's own eligibility window excludes March (15)
        // itself (RECOVERY-LOOP-1 is July-February), so this fixture
        // assigns at August, then advances with the same real
        // closeOrdinaryMonth chain production play uses — never a fresh
        // assignment reconstructed directly at month 15.
        var aggregate = oneFounderParticipatingAtMonth(8);
        while (aggregate.state.month < 15) {
          aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000);
        }
        expect(aggregate.state.month, 15);
        expect(aggregate.state.fiscalYearCompleted, isFalse);
        expect(aggregate.state.engineersAssigned, 1);

        await pumpDemoWith(tester, aggregate);

        expect(find.byKey(activeProjectStatusKey('eng-01')), findsOneWidget);
        expect(find.byKey(activeProjectStatusKey('eng-02')), findsNothing);
      },
    );

    testWidgets(
      'assigned continuously from August through March (real '
      'closeOrdinaryMonth chain, not a reconstruction shortcut): the card '
      'is present at every one of those months',
      (tester) async {
        var aggregate = oneFounderParticipatingAtMonth(8);
        for (var month = 8; month <= 15; month++) {
          expect(aggregate.state.month, month);
          expect(
            aggregate.workflow.assignedEngineerIds(month: month),
            {'eng-01'},
            reason: 'month $month',
          );
          await pumpDemoWith(tester, aggregate);
          expect(
            find.byKey(activeProjectStatusKey('eng-01')),
            findsOneWidget,
            reason: 'month $month',
          );
          if (month < 15) {
            aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000);
          }
        }
      },
    );
  });

  group(
    'SES ACTIVE-PROJECT-VISIBILITY Phase 1: coexistence with Issue #167 '
    'founder follow-up',
    () {
      testWidgets(
        'August: the project status card and the founder follow-up card '
        'both render for the same still-undecided assigned founding '
        'engineer',
        (tester) async {
          final aggregate = oneFounderParticipatingAtMonth(8);
          expect(
            aggregate.workflow.engineers
                .firstWhere((e) => e.id == 'eng-01')
                .founderFollowUpMonth,
            isNull,
            reason: 'no follow-up decision made yet this fiscal year',
          );

          await pumpDemoWith(tester, aggregate);

          expect(find.byKey(activeProjectStatusKey('eng-01')), findsOneWidget);
          expect(
            find.byKey(
              const Key('public-demo-founder-follow-up-card-eng-01'),
            ),
            findsOneWidget,
          );
        },
      );
    },
  );

  group('SES ACTIVE-PROJECT-VISIBILITY Phase 1: regressions', () {
    testWidgets(
      'HOME Freeze: switching to ホーム still shows the unchanged HOME '
      'dashboard, and the new employee-tab card never leaks into it',
      (tester) async {
        final aggregate = oneFounderParticipatingAtMonth(8);
        await pumpDemoWith(tester, aggregate);
        expect(find.byKey(activeProjectStatusKey('eng-01')), findsOneWidget);

        await switchPublicDemoTab(tester, PublicDemoTab.home);
        expect(find.byType(PublicDemoHomeDashboardSection), findsOneWidget);
        expect(find.byKey(activeProjectStatusKey('eng-01')), findsNothing);
      },
    );

    testWidgets(
      'Year-End: at March fiscal-year completion, the accounting tab '
      'year-end card still renders unaffected by the new employee-tab card',
      (tester) async {
        var aggregate = oneFounderParticipatingAtMonth(8);
        while (aggregate.state.month < 15) {
          aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000);
        }
        aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: 10000);
        expect(aggregate.state.fiscalYearCompleted, isTrue);

        await tester.pumpWidget(
          MaterialApp(
            home: PublicDemo01PlaceholderScreen(
              saveService: _FixedSaveService(aggregate),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await switchPublicDemoTab(tester, PublicDemoTab.accounting);
        expect(
          find.byKey(const Key('public-demo-fiscal-year-complete')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '#167 regression: an assigned founding engineer whose follow-up '
      'decision has already been made this year no longer gets a '
      'founder-follow-up card, but keeps its project status card',
      (tester) async {
        var aggregate = oneFounderParticipatingAtMonth(8);
        aggregate = aggregate.applyFounderFollowUpDecision(
          engineerId: 'eng-01',
          decision: PublicDemoFounderFollowUpDecision.checkIn,
        );
        expect(
          aggregate.workflow.engineers
              .firstWhere((e) => e.id == 'eng-01')
              .founderFollowUpMonth,
          8,
        );

        await pumpDemoWith(tester, aggregate);

        expect(find.byKey(activeProjectStatusKey('eng-01')), findsOneWidget);
        expect(
          find.byKey(const Key('public-demo-founder-follow-up-card-eng-01')),
          findsNothing,
        );
      },
    );
  });
}
