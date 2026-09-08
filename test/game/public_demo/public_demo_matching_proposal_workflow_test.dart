import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_matching_proposal.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

/// SES CORE-GAMEPLAY Phase 5 (Matching Decision Gameplay): coverage for the
/// proposal handoff -- [PublicDemoWorkflowState.proposeMatching] /
/// [PublicDemoAggregate.proposeMatching] / [PublicDemoMatchingProposal].
/// See `docs/reports/SES_CORE-GAMEPLAY_Phase5_Matching_Result.md`.
void main() {
  group('PublicDemoWorkflowState.proposeMatching', () {
    test('records a proposal for a real engineer', () {
      final workflow = PublicDemoWorkflowState.initial();
      final next = workflow.proposeMatching(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        month: 4,
      );

      final proposal = next.matchingProposals['eng-01'];
      expect(proposal, isNotNull);
      expect(proposal!.engineerId, 'eng-01');
      expect(proposal.projectId, 'project-4-1');
      expect(proposal.decidedMonth, 4);
    });

    test('is a no-op for an unknown engineerId', () {
      final workflow = PublicDemoWorkflowState.initial();
      final next = workflow.proposeMatching(
        engineerId: 'does-not-exist',
        projectId: 'project-4-1',
        month: 4,
      );

      expect(next.matchingProposals, isEmpty);
    });

    test('a later call for the same engineer overwrites the earlier one', () {
      final workflow = PublicDemoWorkflowState.initial()
          .proposeMatching(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            month: 4,
          )
          .proposeMatching(
            engineerId: 'eng-01',
            projectId: 'project-5-2',
            month: 5,
          );

      expect(workflow.matchingProposals.length, 1);
      expect(workflow.matchingProposals['eng-01']!.projectId, 'project-5-2');
      expect(workflow.matchingProposals['eng-01']!.decidedMonth, 5);
    });

    test('does not touch the engineer sales-pipeline stage', () {
      final workflow = PublicDemoWorkflowState.initial();
      final before = workflow.engineers
          .firstWhere((e) => e.id == 'eng-01')
          .stage;

      final next = workflow.proposeMatching(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        month: 4,
      );

      final after = next.engineers.firstWhere((e) => e.id == 'eng-01').stage;
      expect(after, before);
      expect(after, PublicDemoSalesStage.waiting);
    });

    test('a proposal for a second engineer is independent of the first', () {
      final workflow = PublicDemoWorkflowState.initial()
          .proposeMatching(
            engineerId: 'eng-01',
            projectId: 'project-4-1',
            month: 4,
          )
          .proposeMatching(
            engineerId: 'eng-02',
            projectId: 'project-4-2',
            month: 4,
          );

      expect(workflow.matchingProposals.length, 2);
      expect(workflow.matchingProposals['eng-01']!.projectId, 'project-4-1');
      expect(workflow.matchingProposals['eng-02']!.projectId, 'project-4-2');
    });
  });

  group('PublicDemoAggregate.proposeMatching', () {
    test('commits through to the workflow, stamped with the current month', () {
      var aggregate = PublicDemoAggregate.initial(runSeed: 1);
      aggregate = aggregate.closeApril(monthlyExpenses: 10000); // -> May
      expect(aggregate.state.month, 5);

      final next = aggregate.proposeMatching(
        engineerId: 'eng-01',
        projectId: 'project-5-1',
      );

      final proposal = next.workflow.matchingProposals['eng-01'];
      expect(proposal, isNotNull);
      expect(proposal!.projectId, 'project-5-1');
      expect(proposal.decidedMonth, 5);
      // Finance/state facts are untouched by this command.
      expect(next.state.toJson(), aggregate.state.toJson());
    });
  });

  group('persistence', () {
    test('toJson/fromJson round-trips a recorded proposal', () {
      final workflow = PublicDemoWorkflowState.initial().proposeMatching(
        engineerId: 'eng-01',
        projectId: 'project-4-1',
        month: 4,
      );

      final restored = PublicDemoWorkflowState.fromJson(workflow.toJson());

      expect(restored.matchingProposals.length, 1);
      expect(restored.matchingProposals['eng-01']!.projectId, 'project-4-1');
      expect(restored.matchingProposals['eng-01']!.decidedMonth, 4);
    });

    test('a save written before this field existed (no matchingProposals '
        'key) restores to an empty map, not a rejected save', () {
      final legacyJson = PublicDemoWorkflowState.initial().toJson()
        ..remove('matchingProposals');

      final restored = PublicDemoWorkflowState.fromJson(legacyJson);

      expect(restored.matchingProposals, isEmpty);
    });
  });

  group('PublicDemoMatchingProposal', () {
    test('toJson/fromJson round-trips exactly', () {
      const proposal = PublicDemoMatchingProposal(
        engineerId: 'eng-01',
        projectId: 'project-6-3',
        decidedMonth: 6,
      );

      final restored = PublicDemoMatchingProposal.fromJson(proposal.toJson());

      expect(restored.engineerId, proposal.engineerId);
      expect(restored.projectId, proposal.projectId);
      expect(restored.decidedMonth, proposal.decidedMonth);
    });
  });
}
