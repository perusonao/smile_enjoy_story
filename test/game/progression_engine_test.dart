// Guided-founding progression tests (Playable 0.4C.1 §54-57).
//
// Covers: stage advancement, feature gates, failure-safe paths, save
// round-trips (including the legacy-save "grant full access" branch), and
// that navigation from every founding-mission step lands somewhere real
// (no dead ends).

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/game.dart';

void main() {
  group('Stage progression (§54)', () {
    test('a brand-new game starts at Stage 1 (employeeIntro)', () {
      final state = GameEngine.newGame(seed: 1);
      expect(ProgressionEngine.currentStage(state), FoundingStage.employeeIntro);
      expect(ProgressionEngine.showFoundingMission(state), isTrue);
      expect(ProgressionEngine.missionStep(state)!.stepNumber, 1);
    });

    test('inspecting an employee advances to Stage 2 (skillSheet)', () {
      var state = GameEngine.newGame(seed: 1);
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectEmployee);
      expect(ProgressionEngine.currentStage(state), FoundingStage.skillSheet);
    });

    test('inspecting the SkillSheet advances to Stage 3 (salesStart)', () {
      var state = GameEngine.newGame(seed: 1);
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectEmployee);
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectSkillSheet);
      expect(ProgressionEngine.currentStage(state), FoundingStage.salesStart);
    });

    test('starting sales advances to Stage 4 (awaitingOffer)', () {
      var state = GameEngine.newGame(seed: 1);
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectEmployee);
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectSkillSheet);
      final engineerId = state.engineers.first.id;
      state = GameEngine.startSales(state, engineerId);
      expect(ProgressionEngine.currentStage(state), FoundingStage.awaitingOffer);
      expect(state.foundingProgress.has(FoundingMilestone.startSales), isTrue);
      expect(state.foundingProgress.milestoneWeeks[FoundingMilestone.startSales], 1);
    });

    test('receiving an interview offer advances to Stage 5 (clientInterview)', () {
      var state = _stateAtStage(FoundingStage.awaitingOffer);
      state = GameEngine.recordMilestone(state, FoundingMilestone.receiveInterviewOffer);
      expect(ProgressionEngine.currentStage(state), FoundingStage.clientInterview);
    });

    test('completing a client interview advances to Stage 6 (awaitingAssignment) — pass or fail (§16)', () {
      for (final passed in [true, false]) {
        var state = _stateAtStage(FoundingStage.clientInterview);
        // §16: completion, not passing, is the gate — the milestone must
        // fire whether the interview passed or failed.
        state = GameEngine.recordMilestone(state, FoundingMilestone.completeClientInterview);
        expect(
          ProgressionEngine.currentStage(state),
          FoundingStage.awaitingAssignment,
          reason: 'passed=$passed should not matter',
        );
      }
    });

    test('the first assignment unlocks Recruitment (Stage 7) and advanced finance', () {
      var state = _stateAtStage(FoundingStage.awaitingAssignment);
      expect(ProgressionEngine.canUseRecruitment(state), isFalse);
      expect(ProgressionEngine.canUseAdvancedFinance(state), isFalse);

      state = GameEngine.recordMilestone(state, FoundingMilestone.firstAssignment);

      expect(ProgressionEngine.currentStage(state), FoundingStage.recruitment);
      expect(ProgressionEngine.canUseRecruitment(state), isTrue);
      expect(ProgressionEngine.canUseAdvancedFinance(state), isTrue);
      // Welfare needs a recruitment interview too — not unlocked yet.
      expect(ProgressionEngine.canUseWelfare(state), isFalse);
    });

    test('a recruitment interview experience unlocks Welfare (Stage 8)', () {
      var state = _stateAtStage(FoundingStage.recruitment);
      state = GameEngine.recordMilestone(state, FoundingMilestone.firstRecruitmentInterview);
      expect(ProgressionEngine.currentStage(state), FoundingStage.welfare);
      expect(ProgressionEngine.canUseWelfare(state), isTrue);
    });

    test('completing the founding tutorial moves to free management', () {
      var state = _stateAtStage(FoundingStage.welfare);
      expect(ProgressionEngine.showFoundingMission(state), isTrue);
      state = GameEngine.completeFoundingTutorial(state);
      expect(ProgressionEngine.currentStage(state), FoundingStage.freeManagement);
      expect(ProgressionEngine.showFoundingMission(state), isFalse);
      expect(ProgressionEngine.missionStep(state), isNull);
    });

    test('milestones only move forward — recording twice keeps the first week', () {
      var state = GameEngine.newGame(seed: 1);
      state = GameEngine.advanceWeek(state); // week 2
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectEmployee);
      expect(state.foundingProgress.milestoneWeeks[FoundingMilestone.inspectEmployee], 2);
      state = GameEngine.advanceWeek(state); // week 3
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectEmployee);
      expect(state.foundingProgress.milestoneWeeks[FoundingMilestone.inspectEmployee], 2);
    });
  });

  group('Feature gates (§56)', () {
    test('Recruitment and Welfare are locked at game start', () {
      final state = GameEngine.newGame(seed: 1);
      expect(ProgressionEngine.canUseRecruitment(state), isFalse);
      expect(ProgressionEngine.canUseWelfare(state), isFalse);
      expect(ProgressionEngine.canUseAdvancedFinance(state), isFalse);
      expect(ProgressionEngine.canUseFullDashboard(state), isFalse);
    });

    test('"自由に開始" (skip) unlocks every feature immediately', () {
      final state = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 1));
      expect(ProgressionEngine.currentStage(state), FoundingStage.freeManagement);
      expect(ProgressionEngine.canUseRecruitment(state), isTrue);
      expect(ProgressionEngine.canUseWelfare(state), isTrue);
      expect(ProgressionEngine.canUseAdvancedFinance(state), isTrue);
      expect(ProgressionEngine.showFoundingMission(state), isFalse);
    });

    test('skipping the tutorial suppresses one-time celebration/tutorial dialogs', () {
      var state = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 1));
      state = GameEngine.recordMilestone(state, FoundingMilestone.receiveInterviewOffer);
      expect(
        ProgressionEngine.pendingEvents(state, ProgressionEngine.weeklyEvents),
        isEmpty,
      );
    });

    test('old (pre-0.4C.1) saves are granted full access, never crash', () {
      final legacyJson = GameEngine.newGame(seed: 1).toJson();
      legacyJson.remove('foundingProgress'); // simulate a pre-0.4C.1 save
      final state = GameState.fromJson(legacyJson);
      expect(state.foundingProgress.tutorialSkipped, isTrue);
      expect(ProgressionEngine.canUseRecruitment(state), isTrue);
      expect(ProgressionEngine.canUseWelfare(state), isTrue);
      expect(ProgressionEngine.showFoundingMission(state), isFalse);
    });
  });

  group('Save round-trip', () {
    test('completed milestones, weeks, seen tutorials and skip flag survive toJson/fromJson', () {
      var state = GameEngine.newGame(seed: 1);
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectEmployee);
      state = GameEngine.advanceWeek(state);
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectSkillSheet);
      state = GameEngine.markTutorialSeen(state, OneTimeEvent.firstOfferTutorial);

      final roundTripped = GameState.fromJson(state.toJson());
      expect(roundTripped.foundingProgress.completedMilestones, state.foundingProgress.completedMilestones);
      expect(roundTripped.foundingProgress.milestoneWeeks, state.foundingProgress.milestoneWeeks);
      expect(roundTripped.foundingProgress.seenTutorials, state.foundingProgress.seenTutorials);
      expect(roundTripped.foundingProgress.tutorialSkipped, isFalse);
    });
  });

  group('Failure-safe paths (§55)', () {
    test('declining an interview offer still completed the milestone that unlocked it', () {
      var state = _stateAtStage(FoundingStage.awaitingOffer);
      final (afterMint, offerId) = state.mintId('interview-offer');
      final offer = InterviewOffer(
        id: offerId,
        employeeId: state.engineers.first.id,
        projectId: state.openProjects.first.project.id,
        clientId: state.openProjects.first.project.clientId,
        generatedWeek: state.week,
        expiresWeek: state.week + 2,
        skillSheetMatch: 70,
      );
      state = afterMint.copyWith(interviewOffers: [offer]);
      state = GameEngine.recordMilestone(state, FoundingMilestone.receiveInterviewOffer);
      state = GameEngine.declineInterviewOffer(state, offerId);
      // Tutorial keeps moving even though the player declined (§14).
      expect(ProgressionEngine.currentStage(state), FoundingStage.clientInterview);
    });

    test('a failed client interview does not block progression (§17)', () {
      var state = _stateAtStage(FoundingStage.clientInterview);
      state = GameEngine.recordMilestone(state, FoundingMilestone.completeClientInterview);
      expect(ProgressionEngine.currentStage(state), FoundingStage.awaitingAssignment);
      expect(ProgressionEngine.showFoundingMission(state), isTrue);
    });

    test('Critical tasks are generated regardless of tutorial stage (§34, §55)', () {
      // A pending offer whose response deadline is this week is Critical
      // (TaskEngine, unchanged by this feature) — must still show up while
      // the founding mission is active.
      var state = GameEngine.newGame(seed: 1);
      final (afterMint, proposalId) = state.mintId('proposal');
      final proposal = ProjectProposal(
        id: proposalId,
        engineerId: state.engineers.first.id,
        project: state.openProjects.first.project,
        proposedWeek: state.week,
        stage: ProposalStage.interviewPassed,
        status: ApplicationStatus.offered,
      );
      final offer = Offer(
        id: 'offer-critical',
        applicationId: proposalId,
        projectId: proposal.project.id,
        employeeId: proposal.engineerId,
        monthlyRate: proposal.project.monthlyRate,
        startWeek: state.week + 1,
        responseDeadlineWeek: state.week,
      );
      state = afterMint.copyWith(proposals: [proposal], offers: [offer]);
      expect(ProgressionEngine.showFoundingMission(state), isTrue);
      final critical = TaskEngine.generateTasks(state).where((t) => t.priority == TaskPriority.critical);
      expect(critical, isNotEmpty);
    });

    test('state survives a reload mid-tutorial (stage preserved)', () {
      var state = GameEngine.newGame(seed: 1);
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectEmployee);
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectSkillSheet);
      state = GameEngine.startSales(state, state.engineers.first.id);
      final reloaded = GameState.fromJson(state.toJson());
      expect(ProgressionEngine.currentStage(reloaded), ProgressionEngine.currentStage(state));
      expect(ProgressionEngine.currentStage(reloaded), FoundingStage.awaitingOffer);
    });
  });

  group('Mission-step navigation has no dead ends (§57)', () {
    test('every stage before freeManagement has either a CTA target or is purely informational', () {
      for (final stage in FoundingStage.values) {
        if (stage == FoundingStage.freeManagement) continue;
        final state = _stateAtStage(stage);
        final step = ProgressionEngine.missionStep(state);
        expect(step, isNotNull, reason: '$stage should have a mission step');
        if (step!.ctaLabel != null) {
          final validTarget =
              step.targetType != TaskTargetType.none ||
              step.stage == FoundingStage.welfare; // "経営を続ける" is handled specially by Home, not a nav target.
          expect(validTarget, isTrue, reason: '$stage CTA "${step.ctaLabel}" must lead somewhere');
        }
      }
    });
  });
}

/// Builds a [GameState] whose [FoundingProgress] already satisfies every
/// milestone gating a stage *before* [stage] — i.e. the tutorial is
/// currently sitting at [stage], ready for its gating milestone to be
/// recorded next.
GameState _stateAtStage(FoundingStage stage) {
  const order = [
    FoundingStage.employeeIntro,
    FoundingStage.skillSheet,
    FoundingStage.salesStart,
    FoundingStage.awaitingOffer,
    FoundingStage.clientInterview,
    FoundingStage.awaitingAssignment,
    FoundingStage.recruitment,
    FoundingStage.welfare,
  ];
  const gates = {
    FoundingStage.employeeIntro: FoundingMilestone.inspectEmployee,
    FoundingStage.skillSheet: FoundingMilestone.inspectSkillSheet,
    FoundingStage.salesStart: FoundingMilestone.startSales,
    FoundingStage.awaitingOffer: FoundingMilestone.receiveInterviewOffer,
    FoundingStage.clientInterview: FoundingMilestone.completeClientInterview,
    FoundingStage.awaitingAssignment: FoundingMilestone.firstAssignment,
    FoundingStage.recruitment: FoundingMilestone.firstRecruitmentInterview,
  };
  var state = GameEngine.newGame(seed: 1);
  final index = order.indexOf(stage);
  for (var i = 0; i < index; i++) {
    final milestone = gates[order[i]];
    if (milestone != null) {
      state = GameEngine.recordMilestone(state, milestone);
    }
  }
  return state;
}
