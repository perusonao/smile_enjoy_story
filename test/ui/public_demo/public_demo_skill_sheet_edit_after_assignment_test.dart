// SES First Fun Quarter AI Replay Audit #2 P1-2: `ec(i)`'s own
// "スキルシートを編集" entry point (Section 2, "今やるべき社員アクション")
// stops rendering for an engineer the moment they enter
// [PublicDemoWorkflowState.assignedEngineerIds] — every render site in
// [PublicDemo01PlaceholderScreen._employeeNextActionsSection] excludes an
// already-assigned engineer, and no later month ever re-includes them. A
// player who completes the natural April chain (SkillSheet確認 → 営業開始 →
// 案件紹介 → 上位会社面談 → 客先面談 → 受注 → 参画) without ever tapping
// "スキルシートを編集" along the way could previously never complete Mission 2
// (`PublicDemoMissionId.editSkillSheet`) again — the April Mission chain
// permanently stuck at 7/8.
//
// The fix adds one more, narrower entry point: `activeProjectStatusCard`
// (Section 3, "参画中案件" — the one card an assigned engineer always gets)
// now also carries the exact same "スキルシートを編集" action, calling the
// exact same [PublicDemo01PlaceholderScreen._openSkillSheetEdit] /
// [PublicDemoAggregate.confirmSkillSheetEdit] command as `ec(i)`'s own
// button — no new authority, no fake completion: the Mission only flips
// once a genuine save actually lands on
// [PublicDemoEngineerSales.salesProfileEditConfirmed].
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/persistence/public_demo_save_service.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_mission_resolver.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';
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

PublicDemoWorkflowState currentWorkflow(WidgetTester tester) =>
    (tester.state(find.byType(PublicDemo01PlaceholderScreen)) as dynamic)
            .workflow
        as PublicDemoWorkflowState;

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
  await switchPublicDemoTab(tester, PublicDemoTab.employees);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// eng-01 driven through the real April sales chain to
/// [PublicDemoSalesStage.ordered], then genuinely assigned via
/// [PublicDemoAggregate.recoverAssignment] — the exact same real commands
/// [publicDemoAdvanceEngineerToOrdered] chains, EXCEPT `confirmSkillSheetEdit`
/// is deliberately never called, reproducing the exact player path this
/// Finding describes ("SkillSheet確認 → 営業開始 → 案件紹介 → 上位会社面談 →
/// 客先面談 → 受注 → 参画" with the edit step skipped).
PublicDemoAggregate _oneFounderAssignedNeverEdited(int month) {
  var aggregate = publicDemoAggregateAtMonth(month);
  aggregate = aggregate
      .startSkillSheetReview('eng-01')
      .beginSelling('eng-01')
      .introduceProject('eng-01')
      .recordEngineerInterviewResult(
        engineerId: 'eng-01',
        type: PublicDemoInterviewType.partner,
      )
      .recordEngineerInterviewResult(
        engineerId: 'eng-01',
        type: PublicDemoInterviewType.client,
      )
      .recordOrder('eng-01');
  return aggregate.recoverAssignment('eng-01');
}

void main() {
  group(
    'SES First Fun Quarter AI Replay Audit #2 P1-2: SkillSheet edit '
    'reachable after assignment',
    () {
      test(
        'sanity: the natural chain without an explicit edit reaches '
        'assigned with salesProfileEditConfirmed still false, and the April '
        'Mission chain is stuck at 7/8 (editSkillSheet is the only gap)',
        () {
          final aggregate = _oneFounderAssignedNeverEdited(8);
          final engineer = aggregate.workflow.engineers.firstWhere(
            (e) => e.id == 'eng-01',
          );
          expect(engineer.salesProfileEditConfirmed, isFalse);
          expect(aggregate.state.engineersAssigned, 1);

          final entries = PublicDemoMissionResolver.resolve(
            workflow: aggregate.workflow,
            state: aggregate.state,
          );
          final completed = entries
              .where((e) => e.status == PublicDemoMissionStatus.completed)
              .map((e) => e.id)
              .toSet();
          expect(completed.length, publicDemoAprilMissionChain.length - 1);
          expect(completed.contains(PublicDemoMissionId.editSkillSheet), isFalse);
          for (final id in publicDemoAprilMissionChain) {
            if (id == PublicDemoMissionId.editSkillSheet) continue;
            expect(
              completed.contains(id),
              isTrue,
              reason: '$id should already be completed by this chain',
            );
          }
        },
      );

      testWidgets(
        'the old ec(i) edit entry point is gone once assigned, but the new '
        'active-project-card entry point is reachable and a real save on it '
        'completes editSkillSheet — closing the April chain to 8/8',
        (tester) async {
          final aggregate = _oneFounderAssignedNeverEdited(8);
          await pumpDemoWith(tester, aggregate);

          expect(
            find.byKey(const Key('public-demo-skill-sheet-edit-open-eng-01')),
            findsNothing,
            reason:
                'ec(i) no longer renders for an already-assigned engineer',
          );

          final activeEditButton = find.byKey(
            const Key('public-demo-skill-sheet-edit-open-active-eng-01'),
          );
          expect(activeEditButton, findsOneWidget);

          // Cancel first: must never fake-complete the mission.
          await tapVisible(tester, activeEditButton);
          await tapVisible(
            tester,
            find.byKey(const Key('public-demo-skill-sheet-edit-cancel-eng-01')),
          );
          expect(
            currentWorkflow(
              tester,
            ).engineers.firstWhere((e) => e.id == 'eng-01').salesProfileEditConfirmed,
            isFalse,
          );

          // Now a genuine save.
          await tapVisible(tester, activeEditButton);
          await tapVisible(
            tester,
            find.byKey(const Key('public-demo-skill-sheet-edit-save-eng-01')),
          );

          final afterEngineer = currentWorkflow(
            tester,
          ).engineers.firstWhere((e) => e.id == 'eng-01');
          expect(afterEngineer.salesProfileEditConfirmed, isTrue);
          expect(
            afterEngineer.stage,
            PublicDemoSalesStage.ordered,
            reason: 'the save must not touch sales-pipeline stage',
          );

          final entries = PublicDemoMissionResolver.resolve(
            workflow: currentWorkflow(tester),
            state: currentState(tester),
          );
          expect(
            entries.every((e) => e.status == PublicDemoMissionStatus.completed),
            isTrue,
            reason: 'the full April chain is now genuinely 8/8',
          );
        },
      );
    },
  );
}
