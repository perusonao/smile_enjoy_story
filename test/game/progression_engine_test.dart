// Guided-founding progression tests (Playable 0.4C.1 §54-57, 0.4C.2 §58-60).
//
// Covers: stage advancement, feature gates, failure-safe paths, save
// round-trips (including the legacy-save "grant full access" branch),
// reconciliation, the tutorial focus employee, and that navigation from
// every guided action lands somewhere real (no dead ends).

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

void main() {
  group('Stage progression (§54)', () {
    test('a brand-new game starts at Stage 1 (employeeIntro)', () {
      final state = GameEngine.newGame(seed: 1);
      expect(ProgressionEngine.currentStage(state), FoundingStage.employeeIntro);
      expect(ProgressionEngine.showFoundingMission(state), isTrue);
      expect(ProgressionEngine.guidedAction(state)!.stepNumber, 1);
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

    test('viewing an employee after Welfare unlocks moves to Stage 9 (tutorialComplete, §35-37)', () {
      var state = _stateAtStage(FoundingStage.welfare);
      state = GameEngine.recordMilestone(state, FoundingMilestone.welfareIntroSeen);
      expect(ProgressionEngine.currentStage(state), FoundingStage.tutorialComplete);
      expect(ProgressionEngine.guidedAction(state)!.ctaLabel, '自由経営を始める');
    });

    test('completing the founding tutorial moves to free management', () {
      var state = _stateAtStage(FoundingStage.tutorialComplete);
      expect(ProgressionEngine.showFoundingMission(state), isTrue);
      state = GameEngine.completeFoundingTutorial(state);
      expect(ProgressionEngine.currentStage(state), FoundingStage.freeManagement);
      expect(ProgressionEngine.showFoundingMission(state), isFalse);
      expect(ProgressionEngine.guidedAction(state), isNull);
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

  group('Tutorial focus employee (§13-15, §58)', () {
    test('focusEmployeeId picks one of the two founders, deterministically for a given seed', () {
      final a = ProgressionEngine.focusEmployeeId(GameEngine.newGame(seed: 42));
      final b = ProgressionEngine.focusEmployeeId(GameEngine.newGame(seed: 42));
      expect(a, isNotNull);
      expect(a, b);
      expect(GameEngine.newGame(seed: 42).engineers.map((e) => e.id), contains(a));
    });

    test('does not alter either founder\'s abilities (§14)', () {
      final before = GameEngine.newGame(seed: 7);
      final snapshot = {for (final e in before.engineers) e.id: e.profile};
      ProgressionEngine.focusEmployeeId(before);
      for (final e in before.engineers) {
        expect(e.profile, snapshot[e.id]);
      }
    });

    test('early-stage guided actions target the focus employee specifically', () {
      final state = GameEngine.newGame(seed: 1);
      final focusId = ProgressionEngine.focusEmployeeId(state);
      final action = ProgressionEngine.guidedAction(state)!;
      expect(action.targetId, focusId);
    });
  });

  group('Reconciliation (§5-8, §50, §59)', () {
    test('a milestone missed by explicit recording is backfilled from GameState facts', () {
      // Simulate a save/desync where startSales happened for real but the
      // milestone was somehow never recorded.
      var state = GameEngine.newGame(seed: 1);
      final engineer = state.engineers.first;
      state = state.copyWith(
        engineers: [engineer.copyWith(salesStatus: SalesStatus.selling), ...state.engineers.skip(1)],
      );
      expect(state.foundingProgress.has(FoundingMilestone.startSales), isFalse);

      final reconciled = ProgressionEngine.reconcile(state);

      expect(reconciled.foundingProgress.has(FoundingMilestone.startSales), isTrue);
    });

    test('reconcile is idempotent — reconciling twice gives the same result (§59)', () {
      var state = GameEngine.newGame(seed: 3);
      final engineer = state.engineers.first;
      state = state.copyWith(
        activeAssignments: [
          ActiveAssignment(engineerId: engineer.id, project: state.openProjects.first.project, remainingWeeks: 4, assignedWeek: 1),
        ],
      );
      final once = ProgressionEngine.reconcile(state);
      final twice = ProgressionEngine.reconcile(once);
      expect(twice.foundingProgress.completedMilestones, once.foundingProgress.completedMilestones);
      expect(twice.foundingProgress.milestoneWeeks, once.foundingProgress.milestoneWeeks);
    });

    test('reconcile never un-completes a milestone (monotonic)', () {
      var state = GameEngine.newGame(seed: 1);
      state = GameEngine.recordMilestone(state, FoundingMilestone.firstAssignment);
      // No active assignments and no assignmentsStarted stat — a naive,
      // non-monotonic reconcile might try to "correct" this back to false.
      final reconciled = ProgressionEngine.reconcile(state);
      expect(reconciled.foundingProgress.has(FoundingMilestone.firstAssignment), isTrue);
    });

    test('reconcile does not touch the purely UI-driven milestones (§6)', () {
      var state = GameEngine.newGame(seed: 1);
      state = state.copyWith(
        activeAssignments: [
          ActiveAssignment(engineerId: state.engineers.first.id, project: state.openProjects.first.project, remainingWeeks: 4, assignedWeek: 1),
        ],
      );
      final reconciled = ProgressionEngine.reconcile(state);
      expect(reconciled.foundingProgress.has(FoundingMilestone.inspectEmployee), isFalse);
      expect(reconciled.foundingProgress.has(FoundingMilestone.inspectSkillSheet), isFalse);
      expect(reconciled.foundingProgress.has(FoundingMilestone.welfareIntroSeen), isFalse);
      expect(reconciled.foundingProgress.has(FoundingMilestone.freeManagement), isFalse);
    });

    test('a save from mid-tutorial reconciles to the correct stage on load, never regressing (§50)', () {
      // A save whose engineer state clearly shows sales already started and
      // an assignment already active, but whose FoundingProgress is still
      // completely empty (as if written by a broken older build).
      var state = GameEngine.newGame(seed: 5);
      final engineer = state.engineers.first;
      state = state.copyWith(
        engineers: [engineer.copyWith(salesStatus: SalesStatus.assigned), ...state.engineers.skip(1)],
        activeAssignments: [
          ActiveAssignment(engineerId: engineer.id, project: state.openProjects.first.project, remainingWeeks: 4, assignedWeek: 1),
        ],
      );
      final reloaded = ProgressionEngine.reconcile(GameState.fromJson(state.toJson()));
      // firstAssignment (derivable) must be reconciled even though
      // inspectEmployee/inspectSkillSheet (not derivable) legitimately
      // weren't recorded — currentStage must never claim to be behind an
      // assignment that already exists.
      expect(reloaded.foundingProgress.has(FoundingMilestone.firstAssignment), isTrue);
      expect(ProgressionEngine.canUseRecruitment(reloaded), isTrue);
    });
  });

  group('Impossible-stage fallback (§8)', () {
    test('awaitingOffer falls back to "restart sales" if the focus employee is no longer selling', () {
      var state = _stateAtStage(FoundingStage.awaitingOffer);
      final focusId = ProgressionEngine.focusEmployeeId(state)!;
      final focus = state.engineerById(focusId);
      // Force the impossible combination: stage says "waiting for an
      // offer" but sales isn't actually running.
      state = state.copyWith(
        engineers: [for (final e in state.engineers) if (e.id == focusId) e.copyWith(salesStatus: SalesStatus.notSelling) else e],
      );
      final action = ProgressionEngine.guidedAction(state)!;
      expect(action.ctaLabel, isNotNull);
      expect(action.targetType, TaskTargetType.employeeDetail);
      expect(action.targetId, focus.id);
      expect(action.title, contains('営業'));
    });

    test('a genuinely waiting player (still selling) gets the plain waiting message, not the fallback', () {
      final state = _stateAtStage(FoundingStage.awaitingOffer);
      final action = ProgressionEngine.guidedAction(state)!;
      expect(action.canAdvanceWeek, isTrue);
      expect(action.title, isNot(contains('再開')));
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

  group('Guided-action navigation has no dead ends (§57, §59)', () {
    test('every stage before freeManagement has either a CTA target or is purely informational', () {
      for (final stage in FoundingStage.values) {
        if (stage == FoundingStage.freeManagement) continue;
        final state = _stateAtStage(stage);
        final action = ProgressionEngine.guidedAction(state);
        expect(action, isNotNull, reason: '$stage should have a guided action');
        if (action!.ctaLabel != null) {
          final validTarget =
              action.targetType != TaskTargetType.none ||
              action.stage == FoundingStage.tutorialComplete; // "自由経営を始める" is handled specially by Home, not a nav target.
          expect(validTarget, isTrue, reason: '$stage CTA "${action.ctaLabel}" must lead somewhere');
        } else {
          // No CTA is only acceptable when "次の週へ" is the real action.
          expect(action.canAdvanceWeek, isTrue, reason: '$stage has neither a CTA nor canAdvanceWeek — a dead end');
        }
      }
    });

    test('exactly one primary guided action exists at every stage (never zero, never ambiguous)', () {
      for (final stage in FoundingStage.values) {
        if (stage == FoundingStage.freeManagement) continue;
        final state = _stateAtStage(stage);
        // guidedAction returns a single object, not a list — this is
        // structurally guaranteed, but assert non-null explicitly so a
        // future refactor that makes it nullable-by-mistake fails loudly.
        expect(ProgressionEngine.guidedAction(state), isNotNull, reason: '$stage');
      }
    });
  });
}

/// Builds a [GameState] whose [FoundingProgress] (and, where relevant,
/// underlying engineer state) already satisfies every milestone gating a
/// stage *before* [stage] — i.e. the tutorial is currently sitting at
/// [stage], ready for its gating milestone to be recorded next.
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
    FoundingStage.tutorialComplete,
  ];
  const gates = {
    FoundingStage.employeeIntro: FoundingMilestone.inspectEmployee,
    FoundingStage.skillSheet: FoundingMilestone.inspectSkillSheet,
    FoundingStage.awaitingOffer: FoundingMilestone.receiveInterviewOffer,
    FoundingStage.clientInterview: FoundingMilestone.completeClientInterview,
    FoundingStage.awaitingAssignment: FoundingMilestone.firstAssignment,
    FoundingStage.recruitment: FoundingMilestone.firstRecruitmentInterview,
    FoundingStage.welfare: FoundingMilestone.welfareIntroSeen,
  };
  var state = GameEngine.newGame(seed: 1);
  final index = order.indexOf(stage);
  for (var i = 0; i < index; i++) {
    final s = order[i];
    if (s == FoundingStage.salesStart) {
      // Actually start sales (not just mark the milestone) so downstream
      // stages' guided-action fallback logic sees a real `selling` status
      // instead of tripping the "sales stopped" branch.
      state = GameEngine.startSales(state, ProgressionEngine.focusEmployeeId(state)!);
      continue;
    }
    final milestone = gates[s];
    if (milestone != null) {
      state = GameEngine.recordMilestone(state, milestone);
    }
  }
  return state;
}
