import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

void main() {
  group('SelectionFlow generation', () {
    test('Simple, Standard and Advanced patterns are generated', () {
      final projects = ProjectGenerator(
        seed: 99,
        clients: sampleClients,
      ).generate(500);
      final types = projects.map((p) => p.selectionFlow.type).toSet();
      expect(types, containsAll(SelectionFlowType.values));
      for (final project in projects) {
        expect(project.selectionFlow.steps.last, SelectionStep.offer);
        expect(project.interviewCount, project.selectionFlow.interviewCount);
      }
    });
  });

  group('Parallel proposals', () {
    test(
      'one employee can hold three, fourth is blocked, employee slots are independent',
      () {
        var state = GameEngine.newGame(seed: 11);
        final projects = ProjectGenerator(
          seed: 123,
          clients: sampleClients,
        ).generate(8);
        state = state.copyWith(
          openProjects: projects
              .map((p) => ProjectEntry(project: p, postedWeek: 1))
              .toList(),
        );
        final first = state.engineers[0];
        final second = state.engineers[1];
        for (final project in projects.take(3)) {
          state = GameEngine.proposeEngineer(state, first.id, project.id);
        }
        expect(state.activeProposalCountFor(first.id), 3);
        final before = state.proposals.length;
        state = GameEngine.proposeEngineer(state, first.id, projects[3].id);
        expect(state.proposals.length, before);
        state = GameEngine.proposeEngineer(state, second.id, projects[3].id);
        expect(state.activeProposalCountFor(second.id), 1);
        expect(state.activeCompanyProposalCount, 4);
      },
    );
  });

  group('Step judgment', () {
    test('every step rate clamps to 5-95 and rolls reproducibly', () {
      final state = GameEngine.newGame(seed: 5);
      final engineer = state.engineers.first;
      final project = state.openProjects.first.project;
      for (final step in SelectionStep.values.where(
        (s) => s != SelectionStep.offer,
      )) {
        final rate = SelectionEngine.successRate(engineer, project, step);
        expect(rate, inInclusiveRange(5, 95));
        expect(
          SelectionEngine.roll(rate: rate, seed: 2, week: 3, salt: step.name),
          SelectionEngine.roll(rate: rate, seed: 2, week: 3, salt: step.name),
        );
      }
    });

    test('one week advances exactly one selection step or rejects', () {
      var state = GameEngine.newGame(seed: 8);
      final engineer = state.engineers.first;
      final project = state.openProjects.first.project;
      state = GameEngine.proposeEngineer(state, engineer.id, project.id);
      final before = state.proposals.single.currentStepIndex;
      final next = GameEngine.advanceWeek(state);
      final application = next.proposals.first;
      expect(
        application.currentStepIndex == before + 1 ||
            application.status == ApplicationStatus.rejected,
        isTrue,
      );
      expect(application.stepHistory, hasLength(1));
    });
  });

  group('Offer lifecycle', () {
    GameState stateAtOfferStep() {
      var state = GameEngine.newGame(seed: 21);
      final engineer = state.engineers.first;
      final project = state.openProjects.first.project;
      final application = ProjectApplication(
        id: 'application-offer',
        engineerId: engineer.id,
        project: project,
        proposedWeek: 1,
        stage: ProposalStage.proposed,
        currentStepIndex: project.selectionFlow.steps.length - 1,
        fitScore: 80,
      );
      return state.copyWith(proposals: [application]);
    }

    test('final passage creates a pending offer, not an assignment', () {
      final state = GameEngine.advanceWeek(stateAtOfferStep());
      expect(state.offers.single.status, OfferStatus.pending);
      expect(state.activeAssignments, isEmpty);
      expect(state.proposals.single.status, ApplicationStatus.offered);
    });

    test(
      'accepted offer starts next week and cancels employee alternatives',
      () {
        var state = stateAtOfferStep();
        final employee = state.engineers.first;
        final otherProject = ProjectGenerator(
          seed: 55,
          clients: sampleClients,
        ).generate(1).single;
        state = GameEngine.advanceWeek(state);
        state = state.copyWith(
          proposals: [
            ...state.proposals,
            ProjectApplication(
              id: 'alternative',
              engineerId: employee.id,
              project: otherProject,
              proposedWeek: 1,
              stage: ProposalStage.proposed,
            ),
          ],
        );
        state = GameEngine.acceptOffer(state, state.offers.single.id);
        expect(
          state.proposals.firstWhere((p) => p.id == 'alternative').status,
          ApplicationStatus.cancelled,
        );
        state = GameEngine.advanceWeek(state);
        expect(state.activeAssignments, hasLength(1));
        expect(state.engineerById(employee.id).status, EngineerStatus.assigned);
      },
    );

    test('decline only closes that application', () {
      var state = GameEngine.advanceWeek(stateAtOfferStep());
      state = GameEngine.declineOffer(state, state.offers.single.id);
      expect(state.offers.single.status, OfferStatus.declined);
      expect(state.proposals.single.status, ApplicationStatus.declined);
    });

    test('unanswered offer expires after its one-week deadline', () {
      var state = GameEngine.advanceWeek(stateAtOfferStep());
      state = GameEngine.advanceWeek(state);
      expect(state.offers.single.status, OfferStatus.expired);
      expect(state.stats.offersExpired, 1);
    });

    test('applications and offers round-trip through GameState JSON', () {
      final state = GameEngine.advanceWeek(stateAtOfferStep());
      final restored = GameState.fromJson(state.toJson());
      expect(
        restored.proposals.single.toJson(),
        state.proposals.single.toJson(),
      );
      expect(restored.offers.single.toJson(), state.offers.single.toJson());
    });
  });
}
