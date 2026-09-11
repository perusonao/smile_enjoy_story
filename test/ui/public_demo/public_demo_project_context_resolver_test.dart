import 'package:flutter_test/flutter_test.dart';

import 'package:smile_enjoy_story/game/public_demo/public_demo_project_generator.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/ui/public_demo/public_demo_project_context_resolver.dart';

/// SES FIRST-FUN-YEAR P1 (Project/Order/Assignment Continuous Visibility):
/// pure unit coverage for [PublicDemoProjectContextResolver] — deliberately
/// independent of any widget/pump, mirroring
/// public_demo_employee_status_resolver_test.dart's own convention: the
/// resolver takes only primitives/enums (plus an injected candidate lookup)
/// and never reads [PublicDemoAggregate]/[PublicDemoState] itself.
void main() {
  group('projectIdFor: priority order', () {
    test('currently assigned → assignmentProjectId only, regardless of '
        'stage or any other still-recorded id', () {
      final id = PublicDemoProjectContextResolver.projectIdFor(
        stage: PublicDemoSalesStage.ordered,
        isCurrentlyAssigned: true,
        assignmentProjectId: 'project-assignment',
        genuineInterviewProjectId: 'project-interview',
        matchingProposalProjectId: 'project-proposal',
      );
      expect(id, 'project-assignment');
    });

    test('currently assigned with no assignmentProjectId (legacy/generic '
        'path) → null, never falling back to a stale interview/proposal id', () {
      final id = PublicDemoProjectContextResolver.projectIdFor(
        stage: PublicDemoSalesStage.ordered,
        isCurrentlyAssigned: true,
        genuineInterviewProjectId: 'project-interview',
        matchingProposalProjectId: 'project-proposal',
      );
      expect(id, isNull);
    });

    test('ordered, not yet assigned (参画予定) → genuineInterviewProjectId '
        'first', () {
      final id = PublicDemoProjectContextResolver.projectIdFor(
        stage: PublicDemoSalesStage.ordered,
        isCurrentlyAssigned: false,
        genuineInterviewProjectId: 'project-interview',
        matchingProposalProjectId: 'project-proposal',
      );
      expect(id, 'project-interview');
    });

    test('ordered, not yet assigned, no genuine interview id → falls back '
        'to a pre-existing assignmentProjectId (e.g. a prior cycle\'s row)', () {
      final id = PublicDemoProjectContextResolver.projectIdFor(
        stage: PublicDemoSalesStage.ordered,
        isCurrentlyAssigned: false,
        assignmentProjectId: 'project-prior',
      );
      expect(id, 'project-prior');
    });

    for (final stage in [
      PublicDemoSalesStage.introduced,
      PublicDemoSalesStage.partnerInterviewPassed,
      PublicDemoSalesStage.partnerInterviewFailed,
      PublicDemoSalesStage.clientInterviewPassed,
      PublicDemoSalesStage.clientInterviewFailed,
    ]) {
      test('$stage → genuineInterviewProjectId first, else '
          'matchingProposalProjectId', () {
        expect(
          PublicDemoProjectContextResolver.projectIdFor(
            stage: stage,
            isCurrentlyAssigned: false,
            genuineInterviewProjectId: 'project-interview',
            matchingProposalProjectId: 'project-proposal',
          ),
          'project-interview',
        );
        expect(
          PublicDemoProjectContextResolver.projectIdFor(
            stage: stage,
            isCurrentlyAssigned: false,
            matchingProposalProjectId: 'project-proposal',
          ),
          'project-proposal',
        );
        expect(
          PublicDemoProjectContextResolver.projectIdFor(
            stage: stage,
            isCurrentlyAssigned: false,
          ),
          isNull,
        );
      });
    }

    for (final stage in [
      PublicDemoSalesStage.waiting,
      PublicDemoSalesStage.skillSheet,
      PublicDemoSalesStage.selling,
    ]) {
      test('$stage → always null — nothing has been introduced yet, even '
          'if a stale proposal/interview id happens to be passed in', () {
        expect(
          PublicDemoProjectContextResolver.projectIdFor(
            stage: stage,
            isCurrentlyAssigned: false,
            genuineInterviewProjectId: 'project-interview',
            matchingProposalProjectId: 'project-proposal',
          ),
          isNull,
        );
      });
    }
  });

  group('labelFor', () {
    test('currently assigned → 参画中案件, regardless of stage', () {
      expect(
        PublicDemoProjectContextResolver.labelFor(
          stage: PublicDemoSalesStage.ordered,
          isCurrentlyAssigned: true,
        ),
        '参画中案件',
      );
    });

    test('ordered, not assigned → 受注案件', () {
      expect(
        PublicDemoProjectContextResolver.labelFor(
          stage: PublicDemoSalesStage.ordered,
          isCurrentlyAssigned: false,
        ),
        '受注案件',
      );
    });

    test('any pre-order pipeline stage → 提案中の案件', () {
      expect(
        PublicDemoProjectContextResolver.labelFor(
          stage: PublicDemoSalesStage.introduced,
          isCurrentlyAssigned: false,
        ),
        '提案中の案件',
      );
    });
  });

  group('resolve: end-to-end via an injected candidate lookup', () {
    test('null projectId short-circuits without ever calling '
        'resolveCandidate', () {
      var called = false;
      final context = PublicDemoProjectContextResolver.resolve(
        stage: PublicDemoSalesStage.waiting,
        isCurrentlyAssigned: false,
        resolveCandidate: (_) {
          called = true;
          return null;
        },
      );
      expect(context, isNull);
      expect(called, isFalse);
    });

    test('a resolveCandidate miss (should not happen for a genuine id, but '
        'never assumed) also yields null, never a partially-built context', () {
      final context = PublicDemoProjectContextResolver.resolve(
        stage: PublicDemoSalesStage.introduced,
        isCurrentlyAssigned: false,
        matchingProposalProjectId: 'not-a-real-id',
        resolveCandidate: (_) => null,
      );
      expect(context, isNull);
    });

    test('a resolved candidate produces a context carrying its real title/'
        'client/rate verbatim, under the stage-appropriate label', () {
      final candidate = PublicDemoSeededProjectGenerator.forMonth(
        runSeed: 1,
        month: 4,
      ).first;
      final context = PublicDemoProjectContextResolver.resolve(
        stage: PublicDemoSalesStage.clientInterviewPassed,
        isCurrentlyAssigned: false,
        genuineInterviewProjectId: candidate.id,
        resolveCandidate: (id) => PublicDemoSeededProjectGenerator.regenerate(
          runSeed: 1,
          projectId: id,
        ),
      );
      expect(context, isNotNull);
      expect(context!.label, '提案中の案件');
      expect(context.title, candidate.title);
      expect(context.clientName, candidate.clientName);
      expect(context.monthlyRate, candidate.monthlyRate);
    });
  });
}
