import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

import 'test_support/public_demo_recovery_test_helpers.dart';
import 'test_support/public_demo_sales_test_helpers.dart';

/// CORE-GAMEPLAY Phase 7A (Assignment Lifecycle) focused tests, exercised
/// directly on [PublicDemoWorkflowState]/[PublicDemoAggregate] — mirrors
/// public_demo_recovery_workflow_test.dart/public_demo_recovery_aggregate_
/// test.dart's own approach (no widget needed; these commands never read
/// UI state).
void main() {
  PublicDemoEngineerSales genuineEngineer(String id) => PublicDemoEngineerSales(
    id: id,
    name: 'エンジニア $id',
    summary: 'テスト用',
    interviewProfile: const PublicDemoInterviewProfile(
      skillFit: 90,
      humanity: 90,
      morale: 90,
      clientTrust: 90,
    ),
  );

  /// A workflow with [id] genuinely `ordered` and already picked up into
  /// [PublicDemoWorkflowState.assignments] via [assignOrderedForMay] — the
  /// generic (project-agnostic) interview path, exactly like
  /// public_demo_recovery_workflow_test.dart's own `orderedWorkflow`.
  PublicDemoWorkflowState orderedAssignedWorkflow(String id) =>
      PublicDemoWorkflowState(
        applicants: const [],
        engineers: [recordTestClientInterviewPass(genuineEngineer(id))],
      ).recordOrder(id).assignOrderedForMay();

  group('Real project identity: assignOrderedForMay', () {
    test(
      'threads the genuine Phase 6 projectId onto the new assignment, '
      'instead of the generic placeholder',
      () {
        var workflow = PublicDemoWorkflowState(
          applicants: const [],
          engineers: [
            recordTestProjectInterviewPass(
              genuineEngineer('eng-project-x'),
              projectId: 'project-4-2',
            ),
          ],
        );
        workflow = workflow.recordOrder('eng-project-x');
        workflow = workflow.assignOrderedForMay();

        expect(workflow.assignments, hasLength(1));
        final assignment = workflow.assignments.single;
        expect(assignment.engineerId, 'eng-project-x');
        expect(assignment.projectId, 'project-4-2');
      },
    );

    test(
      'the generic (project-agnostic) interview path is unchanged: '
      'projectId stays null and the founding-engineer template still wins',
      () {
        final workflow = orderedAssignedWorkflow('eng-01');

        expect(workflow.assignments, hasLength(1));
        final assignment = workflow.assignments.single;
        expect(assignment.projectId, isNull);
        expect(
          assignment.projectName,
          '販売管理システム開発',
          reason: 'unchanged from before Phase 7A — matches '
              'publicDemoInitialAssignments',
        );
      },
    );
  });

  group('Real project identity: recoverLateYearAssignment', () {
    test('threads the genuine projectId for a late-year order', () {
      var workflow = PublicDemoWorkflowState(
        applicants: const [],
        engineers: [
          recordTestProjectInterviewPass(
            genuineEngineer('eng-project-y'),
            projectId: 'project-8-1',
          ),
        ],
      );
      workflow = workflow
          .recordOrder('eng-project-y')
          .recoverLateYearAssignment('eng-project-y', month: 8);

      final assignment = workflow.assignments.single;
      expect(assignment.projectId, 'project-8-1');
      expect(assignment.nextOrderStatus, PublicDemoNextOrderStatus.accepted);
      expect(assignment.replacementStage, PublicDemoReplacementStage.ordered);
    });

    test(
      'never reuses a stale template/existing entry when a genuine, '
      'project-bound record exists — even for a founding engineer with a '
      'pre-populated template',
      () {
        var workflow = PublicDemoWorkflowState(
          applicants: const [],
          engineers: [
            recordTestProjectInterviewPass(
              genuineEngineer('eng-01'),
              projectId: 'project-8-1',
            ),
          ],
        );
        workflow = workflow
            .recordOrder('eng-01')
            .recoverLateYearAssignment('eng-01', month: 8);

        expect(workflow.assignments, hasLength(1));
        final assignment = workflow.assignments.single;
        expect(assignment.projectId, 'project-8-1');
        expect(
          assignment.projectName,
          '新規開発支援',
          reason: 'the generic forOrderedEngineer text, never the '
              'founding-engineer template this id also has',
        );
      },
    );

    test(
      'the generic (project-agnostic) upsert path is unchanged: an '
      'existing template entry is preserved verbatim aside from its '
      'order-state fields',
      () {
        var workflow = PublicDemoWorkflowState(
          applicants: const [],
          engineers: [recordTestClientInterviewPass(genuineEngineer('eng-01'))],
        );
        workflow = workflow
            .recordOrder('eng-01')
            .recoverLateYearAssignment('eng-01', month: 8);

        final assignment = workflow.assignments.single;
        expect(assignment.projectId, isNull);
        expect(assignment.projectName, '販売管理システム開発');
      },
    );
  });

  group('endAssignment: precondition (no malformed/premature end)', () {
    test('no-op when no assignment exists for the engineer', () {
      final workflow = PublicDemoWorkflowState(
        applicants: const [],
        engineers: [genuineEngineer('eng-none')],
      );
      expect(identical(workflow.endAssignment('eng-none'), workflow), isTrue);
    });

    test('no-op for an unknown engineer id entirely', () {
      final workflow = PublicDemoWorkflowState.initial();
      expect(
        identical(workflow.endAssignment('does-not-exist'), workflow),
        isTrue,
      );
    });

    test(
      'no-op unless nextOrderStatus == notOffered (undecided/offered/'
      'accepted must never be silently ended)',
      () {
        final workflow = orderedAssignedWorkflow('eng-01');
        expect(
          workflow.assignments.single.nextOrderStatus,
          PublicDemoNextOrderStatus.undecided,
        );
        expect(identical(workflow.endAssignment('eng-01'), workflow), isTrue);
      },
    );

    test(
      'no-op when a replacement has already been genuinely secured '
      '(replacementStage == ordered) — a real new order is never silently '
      'discarded',
      () {
        final workflow = orderedAssignedWorkflow('eng-01').withAssignmentUpdate(
          'eng-01',
          nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
          replacementStage: PublicDemoReplacementStage.ordered,
        );
        expect(identical(workflow.endAssignment('eng-01'), workflow), isTrue);
      },
    );
  });

  group(
    'endAssignment: atomic end→available transition, exactly once',
    () {
      test(
        'ends the assignment and releases the engineer to waiting '
        'atomically — no intermediate off-roster-but-still-ordered state',
        () {
          final workflow = orderedAssignedWorkflow(
            'eng-01',
          ).withAssignmentUpdate(
            'eng-01',
            nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
          );
          final ended = workflow.endAssignment('eng-01');

          expect(ended.assignments, isEmpty);
          final engineer = ended.engineers.firstWhere(
            (candidate) => candidate.id == 'eng-01',
          );
          expect(engineer.stage, PublicDemoSalesStage.waiting);
        },
      );

      test(
        'the engineer is never simultaneously "active" (present in '
        'assignments) and "waiting" — before, during, or after ending',
        () {
          bool waitingAndActive(PublicDemoWorkflowState w, String id) {
            final isActive = w.assignedEngineerIdsUnfiltered.contains(id);
            final engineer = w.engineers.firstWhere((e) => e.id == id);
            return isActive && engineer.stage == PublicDemoSalesStage.waiting;
          }

          final before = orderedAssignedWorkflow('eng-01').withAssignmentUpdate(
            'eng-01',
            nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
          );
          expect(waitingAndActive(before, 'eng-01'), isFalse);
          final after = before.endAssignment('eng-01');
          expect(waitingAndActive(after, 'eng-01'), isFalse);
          expect(
            after.assignedEngineerIdsUnfiltered.contains('eng-01'),
            isFalse,
          );
        },
      );

      test(
        'ending is idempotent: a second call on the already-ended workflow '
        'is a true no-op — an assignment can never be "ended" twice',
        () {
          final workflow = orderedAssignedWorkflow('eng-01')
              .withAssignmentUpdate(
                'eng-01',
                nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
              )
              .endAssignment('eng-01');

          expect(identical(workflow.endAssignment('eng-01'), workflow), isTrue);
        },
      );

      test(
        'a different engineer\'s assignment is completely untouched by '
        'ending eng-01\'s',
        () {
          var workflow = PublicDemoWorkflowState(
            applicants: const [],
            engineers: [
              recordTestClientInterviewPass(genuineEngineer('eng-01')),
              recordTestClientInterviewPass(genuineEngineer('eng-02')),
            ],
          );
          workflow = workflow
              .recordOrder('eng-01')
              .recordOrder('eng-02')
              .assignOrderedForMay()
              .withAssignmentUpdate(
                'eng-01',
                nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
              );
          final eng02Before = workflow.assignments.firstWhere(
            (a) => a.engineerId == 'eng-02',
          );

          workflow = workflow.endAssignment('eng-01');

          expect(
            workflow.assignments.where((a) => a.engineerId == 'eng-01'),
            isEmpty,
          );
          final eng02After = workflow.assignments.firstWhere(
            (a) => a.engineerId == 'eng-02',
          );
          expect(eng02After.projectName, eng02Before.projectName);
          expect(eng02After.nextOrderStatus, eng02Before.nextOrderStatus);
        },
      );
    },
  );

  group(
    'endAssignment → real re-entry: engineer returns to next-project sales',
    () {
      test(
        'a released engineer can genuinely re-enter the Sales pipeline '
        '(startSkillSheetReview succeeds — the entry point every waiting '
        'engineer uses)',
        () {
          final workflow = orderedAssignedWorkflow('eng-01')
              .withAssignmentUpdate(
                'eng-01',
                nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
              )
              .endAssignment('eng-01')
              .startSkillSheetReview('eng-01');

          final engineer = workflow.engineers.firstWhere(
            (candidate) => candidate.id == 'eng-01',
          );
          expect(engineer.stage, PublicDemoSalesStage.skillSheet);
        },
      );

      test(
        'a released engineer who completes a full new sales cycle produces '
        'exactly ONE new assignment — no duplicate, no stale carryover from '
        'the ended contract',
        () {
          var workflow = orderedAssignedWorkflow('eng-01')
              .withAssignmentUpdate(
                'eng-01',
                nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
              )
              .endAssignment('eng-01');
          expect(workflow.assignments, isEmpty);

          workflow = workflow
              .startSkillSheetReview('eng-01')
              .beginSelling('eng-01')
              .introduceProject('eng-01')
              .recordEngineerInterviewResult(
                engineerId: 'eng-01',
                type: PublicDemoInterviewType.partner,
                actualCapability: 95,
              )
              .recordEngineerInterviewResult(
                engineerId: 'eng-01',
                type: PublicDemoInterviewType.client,
                actualCapability: 95,
              )
              .recordOrder('eng-01')
              .recoverLateYearAssignment('eng-01', month: 8);

          expect(workflow.assignments, hasLength(1));
          expect(workflow.assignments.single.engineerId, 'eng-01');
        },
      );
    },
  );

  group('PublicDemoAggregate.endAssignment: Finance/month-boundary safety', () {
    /// A real May assignment for [engineerId] — unlike [recoverAssignment]
    /// (which always sets `replacementStage: ordered`, an already-secured
    /// order that `endAssignment` correctly refuses to end), this leaves
    /// `nextOrderStatus`/`replacementStage` at their real
    /// undecided/none defaults, matching [orderedAssignedWorkflow] above
    /// but at the full aggregate level (through `closeApril`/`closeMay`,
    /// exactly like public_demo_save_codec_test.dart's own
    /// `_advancedAggregate` helper).
    PublicDemoAggregate assignedViaMay(String engineerId) {
      final aggregate = PublicDemoAggregate.initial()
          .startSkillSheetReview(engineerId)
          .beginSelling(engineerId)
          .introduceProject(engineerId)
          .recordEngineerInterviewResult(
            engineerId: engineerId,
            type: PublicDemoInterviewType.partner,
          )
          .recordEngineerInterviewResult(
            engineerId: engineerId,
            type: PublicDemoInterviewType.client,
          )
          .recordOrder(engineerId)
          .closeApril(monthlyExpenses: 0);
      return aggregate.closeMay(week: 9, monthlyExpenses: 0);
    }

    test(
      're-projects engineersAssigned/engineersWaiting together with the '
      'workflow change — never a stale count',
      () {
        var aggregate = assignedViaMay('eng-01');
        expect(aggregate.state.engineersAssigned, 1);
        expect(aggregate.state.engineersWaiting, 1);

        aggregate = aggregate.withAssignmentUpdate(
          'eng-01',
          nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
        );
        aggregate = aggregate.endAssignment('eng-01');

        expect(aggregate.workflow.assignments, isEmpty);
        expect(aggregate.state.engineersAssigned, 0);
        expect(aggregate.state.engineersWaiting, 2);
        expect(
          aggregate.state.engineersAssigned + aggregate.state.engineersWaiting,
          aggregate.state.engineerCount,
        );
      },
    );

    test(
      'a no-op end when the order was already secured through Recovery '
      '(replacementStage: ordered) leaves the aggregate identical — no '
      'accidental Finance projection churn',
      () {
        var aggregate = publicDemoAggregateAtMonth(7);
        aggregate = publicDemoAdvanceEngineerToOrdered(aggregate, 'eng-01');
        aggregate = aggregate.recoverAssignment('eng-01');
        final before = aggregate;

        aggregate = aggregate.endAssignment('eng-01');

        expect(identical(aggregate, before), isTrue);
      },
    );

    test(
      'ending never changes cash/pendingRevenue — Finance authority is not '
      'duplicated here, only the roster/stage projection',
      () {
        var aggregate = assignedViaMay('eng-01');
        aggregate = aggregate.withAssignmentUpdate(
          'eng-01',
          nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
        );
        final cashBefore = aggregate.state.cash;
        final pendingBefore = aggregate.state.pendingRevenue;

        aggregate = aggregate.endAssignment('eng-01');

        expect(aggregate.workflow.assignments, isEmpty);
        expect(aggregate.state.cash, cashBefore);
        expect(aggregate.state.pendingRevenue, pendingBefore);
      },
    );

    test(
      'save/reload immediately after ending round-trips through the '
      'aggregate JSON envelope without violating persistence invariants',
      () {
        var aggregate = assignedViaMay('eng-01');
        aggregate = aggregate.withAssignmentUpdate(
          'eng-01',
          nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
        );
        aggregate = aggregate.endAssignment('eng-01');
        expect(aggregate.workflow.assignments, isEmpty);

        final restored = PublicDemoAggregate.fromJson(aggregate.toJson());
        expect(restored.workflow.assignments, isEmpty);
        expect(restored.state.engineersAssigned, aggregate.state.engineersAssigned);
      },
    );
  });
}
