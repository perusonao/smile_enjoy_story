import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/persistence/public_demo_save_codec.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_project_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';

/// CORE-GAMEPLAY Phase 7A (Assignment Lifecycle): focused
/// [PublicDemoSaveCodec] coverage for [PublicDemoAssignment.projectId] —
/// legacy-save migration (a save written before this field existed),
/// genuine round-trip, and the "projectId / engineerId / assignment
/// identity" cross-check rejecting a tampered/malformed save. Mirrors
/// public_demo_save_codec_test.dart's own approach and helper shapes
/// exactly (this stays a separate, self-contained file, matching this
/// suite's existing one-concern-per-file convention, e.g.
/// public_demo_recovery_finance_test.dart alongside
/// public_demo_recovery_aggregate_test.dart).
void main() {
  const codec = PublicDemoSaveCodec();

  PublicDemoAggregate advanceToPartnerPassed(PublicDemoAggregate aggregate) =>
      aggregate
          .startSkillSheetReview('eng-01')
          .beginSelling('eng-01')
          .introduceProject('eng-01')
          .recordEngineerInterviewResult(
            engineerId: 'eng-01',
            type: PublicDemoInterviewType.partner,
          );

  PublicDemoAggregate withRealProposal(PublicDemoAggregate aggregate) {
    final next = advanceToPartnerPassed(aggregate);
    final project = next.projectCandidatesForMonth(next.state.month).first;
    return next.proposeMatch(engineerId: 'eng-01', projectId: project.id);
  }

  PublicDemoEngineerSales engineerZero(PublicDemoAggregate aggregate) =>
      aggregate.workflow.engineers.firstWhere((e) => e.id == 'eng-01');

  PublicDemoAggregate runInterviewToConclusion(PublicDemoAggregate aggregate) {
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

  /// Scans a bounded, deterministic seed range for one where `eng-01`
  /// genuinely passes the Phase 6 project interview for the first
  /// candidate offered, then carries that genuine pass all the way through
  /// `recordOrder` → `closeApril` → `closeMay` into a real, project-bound
  /// May assignment — mirrors public_demo_project_interview_test.dart's own
  /// `_findGenuinePass` scanning pattern, extended to a real assignment
  /// since that file only needs the pass itself.
  ({PublicDemoAggregate aggregate, String projectId})?
  findGenuinelyAssignedPass({int maxSeed = 40}) {
    for (var seed = 0; seed < maxSeed; seed++) {
      var aggregate = withRealProposal(PublicDemoAggregate.initial(runSeed: seed));
      final projectId = aggregate.workflow.matchingProposalFor('eng-01')!.projectId;
      aggregate = runInterviewToConclusion(aggregate);
      if (engineerZero(aggregate).stage != PublicDemoSalesStage.clientInterviewPassed) {
        continue;
      }
      aggregate = aggregate
          .recordOrder('eng-01')
          .closeApril(monthlyExpenses: 0)
          .closeMay(week: 9, monthlyExpenses: 0);
      if (aggregate.workflow.assignments.any(
        (a) => a.engineerId == 'eng-01' && a.projectId == projectId,
      )) {
        return (aggregate: aggregate, projectId: projectId);
      }
    }
    return null;
  }

  group('genuine real-project-identity round trip', () {
    test(
      'a genuine end-to-end Phase 6 pass carried into a real May assignment '
      'round-trips its projectId exactly',
      () {
        final found = findGenuinelyAssignedPass();
        expect(
          found,
          isNotNull,
          reason: 'expected at least one genuine pass across 40 seeds',
        );
        final aggregate = found!.aggregate;

        final restored = codec.decode(codec.encode(aggregate));

        expect(restored, isNotNull);
        expect(codec.toJson(restored!), codec.toJson(aggregate));
        final assignment = restored.workflow.assignments.firstWhere(
          (a) => a.engineerId == 'eng-01',
        );
        expect(assignment.projectId, found.projectId);
      },
    );

    test(
      'legacy migration: a save missing the projectId key on its '
      'assignment entries (written before Phase 7A) still decodes, with '
      'projectId defaulting to null',
      () {
        final found = findGenuinelyAssignedPass();
        expect(found, isNotNull);
        final encoded = codec.toJson(found!.aggregate);
        final legacy = _withoutAssignmentProjectId(encoded);

        final restored = codec.fromJson(legacy);

        expect(restored, isNotNull);
        final assignment = restored!.workflow.assignments.firstWhere(
          (a) => a.engineerId == 'eng-01',
        );
        expect(assignment.projectId, isNull);
      },
    );

    test(
      'a legacy save that already carries a real projectId round-trips it '
      'exactly — the migration only ever fires for an ABSENT key',
      () {
        final found = findGenuinelyAssignedPass();
        expect(found, isNotNull);
        final encoded = codec.toJson(found!.aggregate);

        final restored = codec.fromJson(encoded);

        expect(restored, isNotNull);
        expect(codec.toJson(restored!), encoded);
      },
    );
  });

  group(
    '"projectId / engineerId / assignment identity" cross-check '
    '(CORE-GAMEPLAY Phase 7A)',
    () {
      test(
        'an assignment projectId that disagrees with its own engineer\'s '
        'genuine interviewRecordProjectId is rejected',
        () {
          final found = findGenuinelyAssignedPass();
          expect(found, isNotNull);
          final encoded = codec.toJson(found!.aggregate);
          final tampered = _withAssignmentProjectId(
            encoded,
            engineerId: 'eng-01',
            projectId: 'project-99-9',
          );

          expect(codec.fromJson(tampered), isNull);
        },
      );

      test(
        'an assignment projectId present for an engineer with NO genuine '
        'project-bound interview record at all is rejected',
        () {
          // eng-01 assigned through the plain, generic (project-agnostic)
          // interview path — interviewRecordProjectId is null.
          var aggregate = PublicDemoAggregate.initial()
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
              .recordOrder('eng-01')
              .closeApril(monthlyExpenses: 0);
          aggregate = aggregate.closeMay(week: 9, monthlyExpenses: 0);
          expect(engineerZero(aggregate).genuineInterviewProjectId, isNull);

          final encoded = codec.toJson(aggregate);
          final tampered = _withAssignmentProjectId(
            encoded,
            engineerId: 'eng-01',
            projectId: 'project-4-1',
          );

          expect(codec.fromJson(tampered), isNull);
        },
      );

      test(
        'a duplicate assignment entry for the same engineerId is rejected',
        () {
          final found = findGenuinelyAssignedPass();
          expect(found, isNotNull);
          final encoded = codec.toJson(found!.aggregate);
          final duplicated = _withDuplicatedAssignment(
            encoded,
            engineerId: 'eng-01',
          );

          expect(codec.fromJson(duplicated), isNull);
        },
      );
    },
  );
}

/// Removes the `projectId` key entirely from every
/// `workflow.assignments[*]` entry in an already-encoded envelope —
/// simulating a save written before CORE-GAMEPLAY Phase 7A added it.
Map<String, dynamic> _withoutAssignmentProjectId(
  Map<String, dynamic> source,
) {
  final aggregate = source['aggregate'] as Map<String, dynamic>;
  final workflow = aggregate['workflow'] as Map<String, dynamic>;
  final assignments = (workflow['assignments'] as List)
      .map((entry) => Map<String, dynamic>.from(entry as Map)..remove('projectId'))
      .toList();
  return {
    ...source,
    'aggregate': {
      ...aggregate,
      'workflow': {...workflow, 'assignments': assignments},
    },
  };
}

/// Overwrites the `projectId` field on the `workflow.assignments` entry
/// matching [engineerId] in an already-encoded envelope — mirrors
/// public_demo_save_codec_test.dart's own `_withEngineerZero`/
/// `_withMatchingProposal` "shallow patch a nested map" shape.
Map<String, dynamic> _withAssignmentProjectId(
  Map<String, dynamic> source, {
  required String engineerId,
  required String projectId,
}) {
  final aggregate = source['aggregate'] as Map<String, dynamic>;
  final workflow = aggregate['workflow'] as Map<String, dynamic>;
  final assignments = (workflow['assignments'] as List)
      .map((entry) => Map<String, dynamic>.from(entry as Map))
      .toList();
  final index = assignments.indexWhere((a) => a['engineerId'] == engineerId);
  assignments[index] = {...assignments[index], 'projectId': projectId};
  return {
    ...source,
    'aggregate': {
      ...aggregate,
      'workflow': {...workflow, 'assignments': assignments},
    },
  };
}

/// Appends a second, identical copy of the [engineerId] assignment entry —
/// a duplicate `engineerId` unreachable from any real command path (every
/// assignment-roster-changing command in this file's own doc — see
/// [PublicDemoWorkflowState.endAssignment] and its neighbors — keeps
/// `engineerId` unique by construction).
Map<String, dynamic> _withDuplicatedAssignment(
  Map<String, dynamic> source, {
  required String engineerId,
}) {
  final aggregate = source['aggregate'] as Map<String, dynamic>;
  final workflow = aggregate['workflow'] as Map<String, dynamic>;
  final assignments = (workflow['assignments'] as List)
      .map((entry) => Map<String, dynamic>.from(entry as Map))
      .toList();
  final original = assignments.firstWhere((a) => a['engineerId'] == engineerId);
  assignments.add({...original});
  return {
    ...source,
    'aggregate': {
      ...aggregate,
      'workflow': {...workflow, 'assignments': assignments},
    },
  };
}
