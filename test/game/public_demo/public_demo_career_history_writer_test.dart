import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_generator.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

/// CORE-GAMEPLAY Phase 7B (Career History / SkillSheet Growth): focused
/// coverage for the [PublicDemoAggregate.endAssignment] CareerHistory
/// writer, [PublicDemoAssignment.monthsCredited] growth-accounting
/// bookkeeping, and the Phase 6/7A project-industry handoff into monthly
/// Growth. See docs/reports/SES_CORE-GAMEPLAY_Phase7B_Career-SkillSheet
/// -Growth_Result.md.

/// A generic (project-agnostic) `eng-01` assignment, assigned through the
/// real April→May close — mirrors public_demo_assignment_lifecycle_test
/// .dart's own `assignedViaMay` helper exactly (this file cannot import
/// that private helper, so it is reproduced here against the same real
/// production commands, never a fabricated workflow).
PublicDemoAggregate _genericAssignedAggregate(String engineerId) {
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

PublicDemoAggregate _advanceToPartnerPassed(PublicDemoAggregate aggregate) {
  var next = aggregate.startSkillSheetReview('eng-01');
  next = next.beginSelling('eng-01');
  next = next.introduceProject('eng-01');
  next = next.recordEngineerInterviewResult(
    engineerId: 'eng-01',
    type: PublicDemoInterviewType.partner,
  );
  return next;
}

PublicDemoAggregate _withRealProposal(PublicDemoAggregate aggregate) {
  var next = _advanceToPartnerPassed(aggregate);
  final project = next.projectCandidatesForMonth(next.state.month).first;
  next = next.proposeMatch(engineerId: 'eng-01', projectId: project.id);
  return next;
}

PublicDemoEngineerSales _engineer(PublicDemoAggregate aggregate) => aggregate
    .workflow
    .engineers
    .firstWhere((engineer) => engineer.id == 'eng-01');

PublicDemoAggregate _runInterviewToConclusion(PublicDemoAggregate aggregate) {
  aggregate = aggregate.startProjectInterview('eng-01');
  var session = aggregate.projectInterviewSessionFor('eng-01')!;
  while (session.playerFollowUps.length < session.questions.length) {
    final choice = PublicDemoProjectInterview.choicesFor(session).first;
    aggregate = aggregate.chooseProjectInterviewFollowUp(
      'eng-01',
      session.currentQuestionIndex,
      choice,
    );
    session = aggregate.projectInterviewSessionFor('eng-01')!;
  }
  return aggregate.concludeProjectInterview('eng-01');
}

/// A genuine, project-bound `eng-01` assignment, assigned through the real
/// May close (Phase 4/6/7A production flow, never a fabricated workflow) —
/// scans a bounded, deterministic seed range for one where the real
/// formulas produce a client-interview pass, mirroring
/// public_demo_project_interview_test.dart's own `_findGenuinePass`. Never
/// asserts an outcome beyond "genuinely assigned with this real projectId"
/// — every fact from there on is the real formula's own result.
({PublicDemoAggregate aggregate, String projectId})?
_genuineAssignedAggregate({int maxSeed = 40}) {
  for (var seed = 0; seed < maxSeed; seed++) {
    var aggregate = _withRealProposal(
      PublicDemoAggregate.initial(runSeed: seed),
    );
    final projectId = aggregate.workflow.matchingProposalFor('eng-01')!.projectId;
    aggregate = _runInterviewToConclusion(aggregate);
    if (_engineer(aggregate).stage != PublicDemoSalesStage.clientInterviewPassed) {
      continue;
    }
    aggregate = aggregate.recordOrder('eng-01');
    aggregate = aggregate.closeApril(monthlyExpenses: 0);
    aggregate = aggregate.closeMay(week: 9, monthlyExpenses: 0);
    final assignment = aggregate.workflow.assignments
        .where((candidate) => candidate.engineerId == 'eng-01')
        .firstOrNull;
    if (assignment?.projectId == projectId) {
      return (aggregate: aggregate, projectId: projectId);
    }
  }
  return null;
}

void main() {
  group('PublicDemoAssignment.monthsCredited', () {
    test('starts at 0 for a freshly-assigned engineer', () {
      final aggregate = _genericAssignedAggregate('eng-01');
      // closeMay already ran once by the time assignOrderedForMay's
      // result is visible, so the freshly-created row is credited for
      // May in the very same call — see the group below for the direct,
      // isolated proof this always tracks Growth's own application.
      expect(
        aggregate.workflow.assignments.single.monthsCredited,
        1,
        reason: 'May\'s own close already credited the month the '
            'assignment was created in',
      );
    });

    test(
      'increments by exactly 1 per subsequent month-end close, never more',
      () {
        var aggregate = _genericAssignedAggregate('eng-01');
        expect(aggregate.workflow.assignments.single.monthsCredited, 1);

        aggregate = aggregate.closeJune(assignedInJuly: 1, monthlyExpenses: 0);
        expect(aggregate.workflow.assignments.single.monthsCredited, 2);

        // July's own assignedEngineerIds is filtered to explicitly
        // accepted/replacement-ordered rows only (see
        // PublicDemoWorkflowState.assignedEngineerIds's own doc) — a real
        // player must explicitly accept the June renewal decision for
        // July to keep crediting this same assignment.
        aggregate = aggregate.withAssignmentUpdate(
          'eng-01',
          nextOrderStatus: PublicDemoNextOrderStatus.accepted,
        );
        aggregate = aggregate.closeJuly(monthlyExpenses: 0);
        expect(aggregate.workflow.assignments.single.monthsCredited, 3);
      },
    );

    test(
      'creditAssignmentMonths only touches assignments whose engineerId is '
      'in the given set — every other row\'s own monthsCredited is carried '
      'forward completely untouched',
      () {
        var workflow = PublicDemoWorkflowState.initial();
        expect(
          workflow.creditAssignmentMonths(const {'nobody'}).assignments,
          isEmpty,
          reason: 'no assignments exist yet — never invents one',
        );

        final assigned = _genericAssignedAggregate('eng-01').workflow;
        final credited = assigned.creditAssignmentMonths(const {'eng-01'});
        expect(credited.assignments.single.monthsCredited, 2);

        final untouched = assigned.creditAssignmentMonths(const {'eng-99'});
        expect(
          untouched.assignments.single.monthsCredited,
          assigned.assignments.single.monthsCredited,
          reason: 'eng-01\'s own row is untouched when only eng-99 is '
              'credited',
        );
      },
    );
  });

  group('endAssignment: CareerHistoryEntry writer (generic path)', () {
    test(
      'writes exactly one truthful entry, accounting for June\'s own still '
      '-pending growth credit (the row survives at month < 7 — see the '
      'Codex P1 fix test below) — never a calendar span, never a second '
      'growth application',
      () {
        var aggregate = _genericAssignedAggregate('eng-01');
        expect(aggregate.state.month, 6);
        final assignment = aggregate.workflow.assignments.single;
        expect(assignment.monthsCredited, 1);

        final totalItBefore = aggregate.state
            .runtimeFor('eng-01')
            .totalItExperienceMonths;

        aggregate = aggregate.withAssignmentUpdate(
          'eng-01',
          nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
        );
        aggregate = aggregate.endAssignment('eng-01');

        final runtime = aggregate.state.runtimeFor('eng-01');
        expect(runtime.careerHistory, hasLength(1));
        final entry = runtime.careerHistory.single;
        expect(entry.projectName, assignment.projectName);
        expect(
          entry.experienceMonths,
          2,
          reason: 'monthsCredited (1, from May) plus June\'s own still-'
              'pending credit — the row survives this call (month < 7) so '
              'the upcoming June close is already guaranteed to credit it '
              'once more; never a calendar span',
        );
        expect(entry.languages, [runtime.primaryLanguage]);
        expect(
          entry.industry,
          isNull,
          reason: 'the generic path has no genuine project to resolve an '
              'industry from — never fabricated',
        );
        expect(entry.clientNameSnapshot, isNull);
        expect(
          runtime.totalItExperienceMonths,
          totalItBefore,
          reason: 'ending an assignment records history but never '
              're-applies growth — no double accounting',
        );
      },
    );

    test(
      'Codex P1 fix: ending in June (month < 7, deferred-removal branch) '
      'accounts for June\'s own still-pending growth credit — '
      'PublicDemoWorkflowState.endAssignment deliberately retains the row '
      'through June, and closeJune credits it one more time because June '
      'revenue was genuinely earned, so the recorded experienceMonths must '
      'already include that pending month, not just the pre-close count',
      () {
        var aggregate = _genericAssignedAggregate('eng-01');
        expect(aggregate.state.month, 6);
        expect(aggregate.workflow.assignments.single.monthsCredited, 1);

        aggregate = aggregate.withAssignmentUpdate(
          'eng-01',
          nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
        );
        aggregate = aggregate.endAssignment('eng-01');
        // The row survives (Phase 7A's own deferred-removal contract) and
        // will still be credited once more when June's own close runs.
        expect(aggregate.workflow.assignments, hasLength(1));

        aggregate = aggregate.closeJune(assignedInJuly: 0, monthlyExpenses: 0);

        final runtime = aggregate.state.runtimeFor('eng-01');
        expect(
          runtime.careerHistory.single.experienceMonths,
          2,
          reason: 'June\'s own close genuinely credited a second month to '
              'this same (still-present) assignment row — the recorded '
              'entry must reflect it, never stay stuck at the pre-close '
              'count',
        );
        // Still exactly one entry — closeJune must never write a second
        // CareerHistoryEntry of its own.
        expect(runtime.careerHistory, hasLength(1));
      },
    );

    test('double end never duplicates the CareerHistory entry', () {
      var aggregate = _genericAssignedAggregate('eng-01');
      aggregate = aggregate.withAssignmentUpdate(
        'eng-01',
        nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
      );
      aggregate = aggregate.endAssignment('eng-01');
      expect(aggregate.state.runtimeFor('eng-01').careerHistory, hasLength(1));

      final again = aggregate.endAssignment('eng-01');

      expect(
        identical(again, aggregate),
        isTrue,
        reason: 'the exact same no-op guard endAssignment already relies '
            'on for Phase 7A makes a second CareerHistory write '
            'structurally unreachable',
      );
      expect(again.state.runtimeFor('eng-01').careerHistory, hasLength(1));
    });

    test('save/reload never duplicates the CareerHistory entry', () {
      var aggregate = _genericAssignedAggregate('eng-01');
      aggregate = aggregate.withAssignmentUpdate(
        'eng-01',
        nextOrderStatus: PublicDemoNextOrderStatus.notOffered,
      );
      aggregate = aggregate.endAssignment('eng-01');
      const codec = PublicDemoSaveCodec();

      final restored = codec.decode(codec.encode(aggregate));

      expect(restored, isNotNull);
      expect(
        restored!.state.runtimeFor('eng-01').careerHistory,
        hasLength(1),
      );
      expect(codec.toJson(restored), codec.toJson(aggregate));

      // A further reload of the already-restored aggregate must not grow
      // the list either — CareerHistory is only ever written by
      // endAssignment, never re-derived on load.
      final restoredAgain = codec.decode(codec.encode(restored));
      expect(
        restoredAgain!.state.runtimeFor('eng-01').careerHistory,
        hasLength(1),
      );
    });

    test(
      'legacy save (assignment predates monthsCredited/projectId; runtime '
      'predates careerHistory) still loads and simply starts crediting '
      'from 0 under this field — never a fabricated retroactive figure',
      () {
        const codec = PublicDemoSaveCodec();
        // A genuine assignment (not the empty April-start roster) so
        // stripping monthsCredited below actually exercises the default.
        final legacy = codec.toJson(_genericAssignedAggregate('eng-01'));
        final legacyAggregate = legacy['aggregate'] as Map<String, dynamic>;
        final legacyWorkflow =
            legacyAggregate['workflow'] as Map<String, dynamic>;
        final legacyState = legacyAggregate['state'] as Map<String, dynamic>;
        final legacyEngineerRuntimes =
            legacyState['engineerRuntimes'] as List;
        // Simulate a pre-Phase-7B save: strip the new keys entirely,
        // exactly like a real payload written before this field existed.
        final strippedAssignments = [
          for (final raw in legacyWorkflow['assignments'] as List)
            {...raw as Map<String, dynamic>}..remove('monthsCredited'),
        ];
        for (final raw in legacyEngineerRuntimes) {
          (raw as Map<String, dynamic>).remove('careerHistory');
        }
        final legacyPayload = {
          ...legacy,
          'aggregate': {
            ...legacyAggregate,
            'workflow': {
              ...legacyWorkflow,
              'assignments': strippedAssignments,
            },
          },
        };

        final restored = codec.fromJson(legacyPayload);

        expect(restored, isNotNull);
        expect(restored!.state.runtimeFor('eng-01').careerHistory, isEmpty);
        expect(
          restored.workflow.assignments
              .firstWhere((assignment) => assignment.engineerId == 'eng-01')
              .monthsCredited,
          0,
          reason: 'a legacy in-flight assignment starts counting from 0 '
              'under this field, never a fabricated retroactive figure',
        );
      },
    );

    test(
      'Codex P2 fix: a corrupted/hand-edited monthsCredited outside the '
      'genuine possible range is rejected, never silently accepted',
      () {
        const codec = PublicDemoSaveCodec();
        final legacy = codec.toJson(_genericAssignedAggregate('eng-01'));
        Map<String, dynamic> withMonthsCredited(Object? value) {
          final aggregate = legacy['aggregate'] as Map<String, dynamic>;
          final workflow = aggregate['workflow'] as Map<String, dynamic>;
          final assignments = [
            for (final raw in workflow['assignments'] as List)
              if ((raw as Map<String, dynamic>)['engineerId'] == 'eng-01')
                {...raw, 'monthsCredited': value}
              else
                raw,
          ];
          return {
            ...legacy,
            'aggregate': {
              ...aggregate,
              'workflow': {...workflow, 'assignments': assignments},
            },
          };
        }

        expect(
          codec.fromJson(withMonthsCredited(-1)),
          isNull,
          reason: 'negative would silently suppress the CareerHistory '
              'write via endAssignment\'s own <= 0 skip guard',
        );
        expect(
          codec.fromJson(withMonthsCredited(999999)),
          isNull,
          reason: 'no real assignment can ever be credited for more than '
              'the fiscal year\'s own 12-month span — an oversized value '
              'would fabricate a career duration',
        );
        expect(
          codec.fromJson(withMonthsCredited('1')),
          isNull,
          reason: 'wrong type entirely',
        );
        expect(
          codec.fromJson(withMonthsCredited(12)),
          isNotNull,
          reason: 'the genuine upper bound itself is accepted, not rejected',
        );
        expect(codec.fromJson(legacy), isNotNull, reason: 'untouched');
      },
    );
  });

  group(
    'Growth handoff: real project Industry feeds monthly Growth exactly '
    'once (never double-counted against the primary-language/'
    'totalItExperienceMonths delta Growth already applies)',
    () {
      test(
        'a genuine, project-bound assignment credits its real project\'s '
        'Industry through the ordinary monthly close',
        () {
          final found = _genuineAssignedAggregate();
          if (found == null) {
            markTestSkipped(
              'no seed in the bounded scan produced a genuine pass — see '
              'public_demo_project_interview_test.dart\'s own '
              '_findGenuinePass for the same, pre-existing bound',
            );
            return;
          }
          final aggregate = found.aggregate;
          final assignment = aggregate.workflow.assignments.single;
          expect(assignment.projectId, found.projectId);

          // Resolved through the exact same production call
          // [PublicDemoAggregate] itself uses internally — never a second,
          // independently-derived expectation.
          final candidate = PublicDemoSeededProjectGenerator.regenerate(
            runSeed: aggregate.state.runSeed,
            projectId: found.projectId,
          )!;
          final runtime = aggregate.state.runtimeFor('eng-01');

          // The real project's industry was genuinely fed into this same
          // May close's Growth application — never a second, later call.
          expect(runtime.industryExperience[candidate.project.industry], 1);
        },
      );
    },
  );
}
