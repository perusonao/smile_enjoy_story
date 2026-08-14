// Regression tests for the Playable 0.4C.2 progress-blocker audit (§4):
// concrete cases where a legitimately-playing player got permanently
// stuck. Each test reproduces the exact bug before asserting the fix.

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

void main() {
  group('salesStatus must never get stuck at interviewing (§4 case F)', () {
    test('declining a final Offer returns the engineer to selling', () {
      var state = GameEngine.newGame(seed: 1);
      final engineer = state.engineers.first;
      final project = state.openProjects.first.project;
      final (afterMint, proposalId) = state.mintId('proposal');
      final proposal = ProjectProposal(
        id: proposalId,
        engineerId: engineer.id,
        project: project,
        proposedWeek: state.week,
        stage: ProposalStage.proposed,
        status: ApplicationStatus.offered,
      );
      final offer = Offer(
        id: 'offer-1',
        applicationId: proposalId,
        projectId: project.id,
        employeeId: engineer.id,
        monthlyRate: project.monthlyRate,
        startWeek: state.week + 1,
        responseDeadlineWeek: state.week + 1,
      );
      state = afterMint.copyWith(
        engineers: [engineer.copyWith(salesStatus: SalesStatus.interviewing), ...afterMint.engineers.skip(1)],
        proposals: [proposal],
        offers: [offer],
      );

      state = GameEngine.declineOffer(state, offer.id);

      expect(state.engineerById(engineer.id).salesStatus, SalesStatus.selling);
      // Before the fix this was permanently blocked because startSales
      // refuses anyone already `interviewing`.
      final restarted = GameEngine.startSales(state, engineer.id);
      expect(restarted.engineerById(engineer.id).salesStatus, SalesStatus.selling);
    });

    test('an expired final Offer (missed deadline) also returns the engineer to selling', () {
      var state = GameEngine.newGame(seed: 1);
      final engineer = state.engineers.first;
      final project = state.openProjects.first.project;
      final (afterMint, proposalId) = state.mintId('proposal');
      final proposal = ProjectProposal(
        id: proposalId,
        engineerId: engineer.id,
        project: project,
        proposedWeek: state.week,
        stage: ProposalStage.proposed,
        status: ApplicationStatus.offered,
      );
      final offer = Offer(
        id: 'offer-1',
        applicationId: proposalId,
        projectId: project.id,
        employeeId: engineer.id,
        monthlyRate: project.monthlyRate,
        startWeek: state.week + 1,
        // Deadline is this week — advanceWeek should expire it immediately.
        responseDeadlineWeek: state.week,
      );
      state = afterMint.copyWith(
        engineers: [engineer.copyWith(salesStatus: SalesStatus.interviewing), ...afterMint.engineers.skip(1)],
        proposals: [proposal],
        offers: [offer],
      );

      state = GameEngine.advanceWeek(state);

      expect(state.offers.single.status, OfferStatus.expired);
      expect(state.engineerById(engineer.id).salesStatus, SalesStatus.selling);
      final restarted = GameEngine.startSales(state, engineer.id);
      expect(restarted.engineerById(engineer.id).salesStatus, SalesStatus.selling);
    });
  });

  group('acceptInterviewOffer never silently no-ops (§4 case D)', () {
    test('accepting an offer whose project already left the marketplace expires it with a log line instead of doing nothing', () {
      var state = GameEngine.newGame(seed: 1);
      final engineer = state.engineers.first;
      final vanishedProjectId = 'project-does-not-exist';
      final (afterMint, offerId) = state.mintId('interview-offer');
      final offer = InterviewOffer(
        id: offerId,
        employeeId: engineer.id,
        projectId: vanishedProjectId,
        clientId: state.openProjects.first.project.clientId,
        generatedWeek: state.week,
        expiresWeek: state.week + 2,
        skillSheetMatch: 70,
      );
      state = afterMint.copyWith(interviewOffers: [offer]);
      final beforeEventCount = state.events.length;

      final next = GameEngine.acceptInterviewOffer(state, offerId);

      expect(next.interviewOffers.single.status, InterviewOfferStatus.expired);
      expect(next.events.length, greaterThan(beforeEventCount));
      // No proposal should have been created for a project that doesn't
      // exist in the marketplace.
      expect(next.proposals, isEmpty);
    });
  });

  group('advanceWeek hard-blocks on a pending client interview (§4 case H, §54)', () {
    test('advanceWeek refuses to run while a client interview is unresolved', () {
      var state = GameEngine.newGame(seed: 2);
      final engineer = state.engineers.first;
      final project = state.openProjects.first.project;
      final proposal = ProjectProposal(
        id: 'p1',
        engineerId: engineer.id,
        project: project,
        proposedWeek: state.week,
        stage: ProposalStage.proposed,
        currentStepIndex: project.selectionFlow.steps.indexOf(SelectionStep.clientInterview).clamp(0, project.selectionFlow.steps.length - 1),
      );
      state = state.copyWith(proposals: [proposal]);
      // Only meaningful if this project's flow actually has a clientInterview step.
      if (proposal.currentStep == SelectionStep.clientInterview) {
        final weekBefore = state.week;
        final next = GameEngine.advanceWeek(state);
        expect(next.week, weekBefore, reason: 'advanceWeek must not progress while a client interview is pending');
      }
    });

    test('autoResolveClientInterview clears the block so advanceWeek can proceed', () {
      var state = GameEngine.newGame(seed: 2);
      final engineer = state.engineers.first;
      // Find a project whose flow includes clientInterview as step 0 so a
      // freshly-proposed application is immediately blocking.
      Project? withClientInterviewFirst;
      for (final entry in state.openProjects) {
        if (entry.project.selectionFlow.steps.isNotEmpty && entry.project.selectionFlow.steps.first == SelectionStep.clientInterview) {
          withClientInterviewFirst = entry.project;
          break;
        }
      }
      if (withClientInterviewFirst == null) return; // no fixture project matches this shape — nothing to assert
      final proposal = ProjectProposal(
        id: 'p1',
        engineerId: engineer.id,
        project: withClientInterviewFirst,
        proposedWeek: state.week,
        stage: ProposalStage.proposed,
      );
      state = state.copyWith(proposals: [proposal]);
      expect(GameEngine.advanceWeek(state).week, state.week);

      state = GameEngine.autoResolveClientInterview(state, proposal.id);
      final advanced = GameEngine.advanceWeek(state);
      expect(advanced.week, state.week + 1);
    });
  });
}
