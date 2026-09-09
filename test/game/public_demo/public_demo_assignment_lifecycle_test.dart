import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_revenue.dart';
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
      expect(
        identical(workflow.endAssignment('eng-none', month: 7), workflow),
        isTrue,
      );
    });

    test('no-op for an unknown engineer id entirely', () {
      final workflow = PublicDemoWorkflowState.initial();
      expect(
        identical(
          workflow.endAssignment('does-not-exist', month: 7),
          workflow,
        ),
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
        expect(
          identical(workflow.endAssignment('eng-01', month: 7), workflow),
          isTrue,
        );
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
        expect(
          identical(workflow.endAssignment('eng-01', month: 7), workflow),
          isTrue,
        );
      },
    );
  });

  group(
    'endAssignment: atomic end→available transition, month-aware '
    '(Codex P1 fix, PR #215: must never shrink the CURRENT month\'s '
    'assignedEngineerIds/Finance projection)',
    () {
      test(
        'month ≥ 7: the assignment row is removed immediately and the '
        'engineer is released to waiting atomically — safe because this '
        'row was already excluded from the *filtered* assignedEngineerIds',
        () {
          final workflow = orderedAssignedWorkflow(
            'eng-01',
          ).withAssignmentUpdate(
            'eng-01',
            nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
          );
          final ended = workflow.endAssignment('eng-01', month: 8);

          expect(ended.assignments, isEmpty);
          final engineer = ended.engineers.firstWhere(
            (candidate) => candidate.id == 'eng-01',
          );
          expect(engineer.stage, PublicDemoSalesStage.waiting);
        },
      );

      test(
        'month < 7: the assignment row is deliberately LEFT IN PLACE '
        '(would otherwise shrink this month\'s unfiltered '
        'assignedEngineerIds — see endAssignment\'s own doc), while the '
        'engineer\'s stage still resets to waiting immediately — "begin '
        'searching for the next project during the current month" without '
        'touching this month\'s Finance projection',
        () {
          final workflow = orderedAssignedWorkflow(
            'eng-01',
          ).withAssignmentUpdate(
            'eng-01',
            nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
          );
          final ended = workflow.endAssignment('eng-01', month: 6);

          expect(ended.assignments, hasLength(1));
          expect(ended.assignments.single.engineerId, 'eng-01');
          final engineer = ended.engineers.firstWhere(
            (candidate) => candidate.id == 'eng-01',
          );
          expect(engineer.stage, PublicDemoSalesStage.waiting);
          expect(
            ended.assignedEngineerIdsUnfiltered.contains('eng-01'),
            isTrue,
            reason: 'still counted toward the current month\'s headcount, '
                'exactly like before ending',
          );
        },
      );

      test(
        'assignedEngineerIds(month) itself never changes across the call, '
        'in either branch — the whole point of the month-aware deferral',
        () {
          for (final month in [6, 7, 8]) {
            final workflow = orderedAssignedWorkflow(
              'eng-01',
            ).withAssignmentUpdate(
              'eng-01',
              nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
            );
            final before = workflow.assignedEngineerIds(month: month);
            final ended = workflow.endAssignment('eng-01', month: month);
            expect(
              ended.assignedEngineerIds(month: month),
              before,
              reason: 'month $month: ending must never change this month\'s '
                  'assigned-headcount projection',
            );
          }
        },
      );

      test(
        'ending is idempotent at every month: a second call at the same '
        'month is a true no-op — an assignment can never be "ended" twice',
        () {
          for (final month in [6, 8]) {
            final workflow = orderedAssignedWorkflow('eng-01')
                .withAssignmentUpdate(
                  'eng-01',
                  nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
                )
                .endAssignment('eng-01', month: month);

            expect(
              identical(
                workflow.endAssignment('eng-01', month: month),
                workflow,
              ),
              isTrue,
              reason: 'month $month',
            );
          }
        },
      );

      test(
        'a different engineer\'s assignment is completely untouched by '
        'ending eng-01\'s, at month ≥ 7',
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

          workflow = workflow.endAssignment('eng-01', month: 8);

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
              .endAssignment('eng-01', month: 8)
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
              .endAssignment('eng-01', month: 8);
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

      test(
        'a released-but-not-yet-removed (month < 7) row is safely upserted '
        'in place by a later genuine re-order — never duplicated',
        () {
          var workflow = orderedAssignedWorkflow('eng-01')
              .withAssignmentUpdate(
                'eng-01',
                nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
              )
              .endAssignment('eng-01', month: 6);
          expect(workflow.assignments, hasLength(1));

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
          expect(
            workflow.assignments.single.nextOrderStatus,
            PublicDemoNextOrderStatus.accepted,
          );
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
    /// `_advancedAggregate` helper). Lands on `state.month == 6` (June) —
    /// exactly the window [PublicDemoWorkflowState.endAssignment]'s
    /// deferred-removal branch protects.
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
      'in June (month 6), ending never changes engineersAssigned/'
      'engineersWaiting at all — the row is deferred, not removed',
      () {
        var aggregate = assignedViaMay('eng-01');
        expect(aggregate.state.month, 6);
        expect(aggregate.state.engineersAssigned, 1);
        expect(aggregate.state.engineersWaiting, 1);

        aggregate = aggregate.withAssignmentUpdate(
          'eng-01',
          nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
        );
        aggregate = aggregate.endAssignment('eng-01');

        expect(aggregate.workflow.assignments, hasLength(1));
        expect(aggregate.state.engineersAssigned, 1);
        expect(aggregate.state.engineersWaiting, 1);
        final engineer = aggregate.workflow.engineers.firstWhere(
          (e) => e.id == 'eng-01',
        );
        expect(engineer.stage, PublicDemoSalesStage.waiting);
      },
    );

    test(
      'at month ≥ 7, ending removes the row and re-projects '
      'engineersAssigned/engineersWaiting together — the count itself is '
      'unchanged (this row was already excluded from the filtered set)',
      () {
        // Reaches July (month 7) through the real May→June→July close
        // chain — never via recoverAssignment, which always sets
        // replacementStage: ordered (a secured order endAssignment
        // correctly refuses to end; see the "already secured" precondition
        // test above).
        var aggregate = assignedViaMay(
          'eng-01',
        ).closeJune(assignedInJuly: 0, monthlyExpenses: 0);
        expect(aggregate.state.month, 7);
        aggregate = aggregate.withAssignmentUpdate(
          'eng-01',
          nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
        );
        expect(aggregate.state.engineersAssigned, 0);

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
      'ending never changes cash/pendingRevenue directly — Finance '
      'authority is not duplicated here, only the roster/stage projection',
      () {
        var aggregate = assignedViaMay('eng-01');
        aggregate = aggregate.withAssignmentUpdate(
          'eng-01',
          nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
        );
        final cashBefore = aggregate.state.cash;
        final pendingBefore = aggregate.state.pendingRevenue;

        aggregate = aggregate.endAssignment('eng-01');

        expect(aggregate.state.cash, cashBefore);
        expect(aggregate.state.pendingRevenue, pendingBefore);
      },
    );

    test(
      'Codex P1 regression (PR #215): ending in June, then closing June, '
      'still books June\'s revenue for the released engineer — the '
      'declined order concerns JULY, not June\'s already-earned billing',
      () {
        var aggregate = assignedViaMay('eng-01');
        expect(aggregate.state.month, 6);
        aggregate = aggregate.withAssignmentUpdate(
          'eng-01',
          nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
        );
        aggregate = aggregate.endAssignment('eng-01');

        aggregate = aggregate.closeJune(
          assignedInJuly: 0,
          monthlyExpenses: 0,
        );

        expect(
          aggregate.state.pendingRevenue,
          PublicDemoRevenue.monthlyRevenueForAssignedCount(1),
          reason: 'June\'s billing must still reflect the 1 engineer who '
              'genuinely worked through June, not 0',
        );
      },
    );

    test(
      'the June-deferred row is never double-counted in July: once the '
      'month rolls over, this engineer is genuinely excluded from July\'s '
      'headcount and cannot generate a second, phantom revenue booking',
      () {
        var aggregate = assignedViaMay('eng-01');
        aggregate = aggregate.withAssignmentUpdate(
          'eng-01',
          nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
        );
        aggregate = aggregate.endAssignment('eng-01');
        // June's own revenue is correctly booked (see the test above);
        // closeJune now advances state.month to 7 with the stale row still
        // sitting in workflow.assignments (deferred, never removed at this
        // point).
        aggregate = aggregate.closeJune(
          assignedInJuly: 0,
          monthlyExpenses: 0,
        );
        expect(aggregate.state.month, 7);
        expect(
          aggregate.workflow.assignments,
          hasLength(1),
          reason: 'the row is still present — deferred, not removed',
        );

        // July's own headcount/revenue projection must already exclude it:
        // assignedEngineerIds(month>=7) filters by
        // accepted/replacementStage-ordered, which this stale
        // notOffered/none row never matches.
        expect(
          aggregate.workflow.assignedEngineerIds(month: 7),
          isEmpty,
          reason: 'no phantom July headcount from the ended assignment',
        );
        expect(
          PublicDemoRevenue.monthlyRevenueForAssignedCount(
            aggregate.workflow.assignedEngineerIds(month: 7).length,
          ),
          0,
          reason: 'July books zero revenue for this engineer — the same '
              'June billing must never be recognized twice',
        );

        // A real closeJuly confirms the same fact through the actual
        // Finance authority, not a re-derived formula.
        final closed = aggregate.closeJuly(monthlyExpenses: 0);
        expect(closed.state.month, 8);
        expect(
          closed.state.pendingRevenue,
          0,
          reason: 'August\'s pending billing carries no revenue from the '
              'already-ended eng-01 assignment',
        );
      },
    );

    test(
      'a genuine Phase 6 project-bound assignment keeps its real projectId '
      'through an unrelated endAssignment call — Phase 7A\'s '
      'real-project-identity contract is unaffected by these P1 fixes (the '
      'dedicated SaveCodec round-trip coverage for a genuine projectId '
      'lives in public_demo_assignment_lifecycle_save_codec_test.dart and '
      'is unmodified/still green)',
      () {
        // Two engineers on the same roster: eng-project-w has a genuine
        // Phase 6 project-bound assignment (kept active); eng-01 has an
        // ordinary generic assignment that gets declined and ended.
        var workflow = PublicDemoWorkflowState(
          applicants: const [],
          engineers: [
            recordTestProjectInterviewPass(
              genuineEngineer('eng-project-w'),
              projectId: 'project-4-2',
            ),
            recordTestClientInterviewPass(genuineEngineer('eng-01')),
          ],
        );
        workflow = workflow
            .recordOrder('eng-project-w')
            .recordOrder('eng-01')
            .assignOrderedForMay()
            .withAssignmentUpdate(
              'eng-01',
              nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
            );
        expect(
          workflow.assignments
              .firstWhere((a) => a.engineerId == 'eng-project-w')
              .projectId,
          'project-4-2',
        );

        workflow = workflow.endAssignment('eng-01', month: 8);

        expect(
          workflow.assignments.where((a) => a.engineerId == 'eng-01'),
          isEmpty,
        );
        final survivor = workflow.assignments.firstWhere(
          (a) => a.engineerId == 'eng-project-w',
        );
        expect(
          survivor.projectId,
          'project-4-2',
          reason: 'an unrelated endAssignment call must never disturb '
              'another engineer\'s genuine project identity',
        );
      },
    );

    test(
      'save/reload immediately after ending round-trips through the real '
      'PublicDemoSaveCodec (Codex P1 regression, PR #215) — not merely '
      'PublicDemoAggregate.fromJson, which bypasses '
      '_hasConsistentAuthorityFacts entirely',
      () {
        const codec = PublicDemoSaveCodec();
        for (final month in [6, 8]) {
          var aggregate = month == 6
              ? assignedViaMay('eng-01')
              : (() {
                  var a = publicDemoAggregateAtMonth(7);
                  a = publicDemoAdvanceEngineerToOrdered(a, 'eng-01');
                  return a.recoverAssignment('eng-01');
                })();
          aggregate = aggregate.withAssignmentUpdate(
            'eng-01',
            nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
          );
          aggregate = aggregate.endAssignment('eng-01');

          final restored = codec.decode(codec.encode(aggregate));

          expect(restored, isNotNull, reason: 'month $month');
          expect(codec.toJson(restored!), codec.toJson(aggregate));
        }
      },
    );
  });
}
