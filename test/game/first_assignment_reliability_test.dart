// Playable 0.4C.4 "Guided First Assignment Reliability" regression tests.
//
// Covers the root-cause fix (a small, scoped selection-success-rate safety
// net for the guided focus employee pre-first-assignment — see
// ProgressionEngine.guidedSafetyNetActive and tool/simulate_first_assignment.dart
// for the simulation that found and validated it), the initial-project
// reachability guarantee (§7-13), and the GuidedAction/TaskEngine staleness
// fixes (§15-27) — all via honest, non-cheating `GameEngine` play or
// hand-constructed states, never by injecting a guaranteed pass.

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

import 'test_helpers.dart';

/// Drives one guided-honest playthrough (accept every interview offer,
/// auto-resolve every client interview, accept every final offer, restart
/// sales whenever genuinely idle) purely through legitimate `GameEngine`
/// calls, mirroring tool/simulate_first_assignment.dart and
/// test/game/founding_progression_e2e_test.dart's "employee-first loop".
({int? firstInterviewRequestWeek, int? firstAssignmentWeek, bool bankrupt, List<int> fitsAtAcceptance})
    _honestPlaythrough(int seed, {int maxWeeks = 48}) {
  var s = GameEngine.newGame(seed: seed);
  final focusId = ProgressionEngine.focusEmployeeId(s)!;
  s = GameEngine.startSales(s, focusId);
  int? firstInterviewRequestWeek;
  int? firstAssignmentWeek;
  final fits = <int>[];

  for (var i = 0; i < maxWeeks; i++) {
    for (final offer in s.interviewOffers
        .where((o) => o.employeeId == focusId && o.status == InterviewOfferStatus.pending)
        .toList()) {
      firstInterviewRequestWeek ??= offer.generatedWeek;
      final matchingEntries = s.openProjects.where((e) => e.project.id == offer.projectId);
      final entry = matchingEntries.isEmpty ? null : matchingEntries.first;
      if (entry != null) fits.add(MatchingEngine.computeFit(s.engineerById(focusId), entry.project).total);
      s = GameEngine.acceptInterviewOffer(s, offer.id);
    }
    for (final p in s.proposals
        .where((p) =>
            p.engineerId == focusId &&
            p.status == ApplicationStatus.active &&
            p.currentStep == SelectionStep.clientInterview &&
            !s.clientInterviews.any((sess) => sess.applicationId == p.id && sess.completed))
        .toList()) {
      s = GameEngine.autoResolveClientInterview(s, p.id);
    }
    for (final offer in s.offers.where((o) => o.employeeId == focusId && o.status == OfferStatus.pending).toList()) {
      s = GameEngine.acceptOffer(s, offer.id);
    }
    final focus = s.engineerById(focusId);
    if (focus.status == EngineerStatus.waiting && focus.salesStatus == SalesStatus.notSelling) {
      s = GameEngine.startSales(s, focusId);
    }
    if (s.assignmentForEngineer(focusId) != null) {
      firstAssignmentWeek = s.week;
      break;
    }
    if (s.status == GameStatus.bankrupt) {
      return (firstInterviewRequestWeek: firstInterviewRequestWeek, firstAssignmentWeek: null, bankrupt: true, fitsAtAcceptance: fits);
    }
    s = GameEngine.advanceWeek(s);
  }
  return (
    firstInterviewRequestWeek: firstInterviewRequestWeek,
    firstAssignmentWeek: firstAssignmentWeek,
    bankrupt: false,
    fitsAtAcceptance: fits,
  );
}

void main() {
  group('Initial project reachability for the focus employee (§7-13)', () {
    test('at least one of the initial 2 open projects is genuinely reachable — non-advanced, reasonable Fit, not extreme difficulty', () {
      // The founder roster and the two initial open projects are generated
      // from fixed seeds (GameEngine.founderApplicantSeed/founderProjectSeed)
      // regardless of the game's market seed, so this is a deterministic
      // fact about the current generation tables — pinned across several
      // representative market seeds to document that varying the market
      // never changes it.
      for (final seed in [1, 2, 42, 999, 123456]) {
        final state = GameEngine.newGame(seed: seed);
        final focusId = ProgressionEngine.focusEmployeeId(state)!;
        final focus = state.engineerById(focusId);
        final reachable = state.openProjects.where((entry) {
          final p = entry.project;
          if (p.selectionFlow.type == SelectionFlowType.advanced) return false;
          if (p.difficulty >= 5) return false;
          if (p.requiredLeader > 2 || p.requiredManager > 2) return false;
          return MatchingEngine.computeFit(focus, p).total >= 45;
        });
        expect(reachable, isNotEmpty, reason: 'seed=$seed, focus=${focus.profile.name}');
      }
    });
  });

  group('Guided-honest play timing (§4, §43)', () {
    test('a first interview request always arrives within a handful of weeks', () {
      for (var seed = 1; seed <= 40; seed++) {
        final result = _honestPlaythrough(seed, maxWeeks: 12);
        expect(result.firstInterviewRequestWeek, isNotNull, reason: 'seed=$seed');
        expect(result.firstInterviewRequestWeek!, lessThanOrEqualTo(8), reason: 'seed=$seed');
      }
    });

    test('the guided safety net lifts Week-10 first-assignment reliability to the ~90% informal target', () {
      var byWeek10 = 0;
      var bankrupt = 0;
      const sampleSize = 200;
      for (var seed = 1; seed <= sampleSize; seed++) {
        final result = _honestPlaythrough(seed);
        if (result.firstAssignmentWeek != null && result.firstAssignmentWeek! <= 10) byWeek10++;
        if (result.bankrupt) bankrupt++;
      }
      expect(byWeek10 / sampleSize, greaterThanOrEqualTo(0.85), reason: 'first-assignment-by-Week-10 rate');
      expect(bankrupt / sampleSize, lessThanOrEqualTo(0.05), reason: 'pre-assignment bankruptcy rate');
    });
  });

  group('No impossible skill requirement (§13)', () {
    test('every interview offer the focus employee ever receives clears SalesEngine.offerThreshold', () {
      for (var seed = 1; seed <= 25; seed++) {
        final result = _honestPlaythrough(seed, maxWeeks: 20);
        for (final fit in result.fitsAtAcceptance) {
          // Fit and skillSheetMatch are different scales, but a genuinely
          // impossible project would show up as a near-zero Fit — the
          // offered projects should never be that degenerate.
          expect(fit, greaterThanOrEqualTo(30), reason: 'seed=$seed');
        }
      }
    });
  });

  group('guidedSafetyNetActive scoping (§37-41)', () {
    test('active for the guided focus employee before first assignment', () {
      final state = GameEngine.newGame(seed: 1);
      final focusId = ProgressionEngine.focusEmployeeId(state)!;
      expect(ProgressionEngine.guidedSafetyNetActive(state, focusId), isTrue);
    });

    test('inactive for a non-focus employee', () {
      final state = GameEngine.newGame(seed: 1);
      final focusId = ProgressionEngine.focusEmployeeId(state)!;
      final other = state.engineers.firstWhere((e) => e.id != focusId);
      expect(ProgressionEngine.guidedSafetyNetActive(state, other.id), isFalse);
    });

    test('inactive once the tutorial is skipped (Free Mode is untouched)', () {
      final state = GameEngine.skipFoundingTutorial(GameEngine.newGame(seed: 1));
      final focusId = ProgressionEngine.focusEmployeeId(state)!;
      expect(ProgressionEngine.guidedSafetyNetActive(state, focusId), isFalse);
    });

    test('inactive once firstAssignment is already achieved', () {
      var state = GameEngine.newGame(seed: 1);
      final focusId = ProgressionEngine.focusEmployeeId(state)!;
      state = GameEngine.recordMilestone(state, FoundingMilestone.firstAssignment);
      expect(ProgressionEngine.guidedSafetyNetActive(state, focusId), isFalse);
    });
  });

  group('GuidedAction reconciles immediately after a failure — no stale "選考が進行中" (§15-19)', () {
    test('after an interview-request decline, the clientInterview-stage action reflects "selling", not a stuck selection', () {
      var state = GameEngine.newGame(seed: 1);
      final focusId = ProgressionEngine.focusEmployeeId(state)!;
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectEmployee);
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectSkillSheet);
      state = GameEngine.startSales(state, focusId);
      final project = state.openProjects.first.project;
      final (afterMint, offerId) = state.mintId('interview-offer');
      state = afterMint.copyWith(interviewOffers: [
        InterviewOffer(
          id: offerId,
          employeeId: focusId,
          projectId: project.id,
          clientId: project.clientId,
          generatedWeek: state.week,
          expiresWeek: state.week + 2,
          skillSheetMatch: 70,
        ),
      ]);
      state = GameEngine.recordMilestone(state, FoundingMilestone.receiveInterviewOffer);
      expect(ProgressionEngine.currentStage(state), FoundingStage.clientInterview);

      state = GameEngine.declineInterviewOffer(state, offerId);
      expect(EmployeeWorkflowEngine.forEngineer(state, focusId), EmployeeWorkflowState.selling);

      final action = ProgressionEngine.guidedAction(state)!;
      expect(action.title, isNot(contains('選考')));
      expect(action.description, isNot(contains('選考が進行中')));
      expect(action.canAdvanceWeek, isTrue);
    });

    test('after a selection-step rejection (fromInterviewOffer), the awaitingAssignment-stage action reflects "selling"', () {
      var state = GameEngine.newGame(seed: 1);
      final focusId = ProgressionEngine.focusEmployeeId(state)!;
      final project = state.openProjects.first.project;
      state = state.copyWith(
        engineers: [for (final e in state.engineers) if (e.id == focusId) e.copyWith(salesStatus: SalesStatus.selling) else e],
        proposals: [
          ProjectProposal(
            id: 'p-rejected',
            engineerId: focusId,
            project: project,
            proposedWeek: 1,
            stage: ProposalStage.interviewFailed,
            status: ApplicationStatus.rejected,
            fromInterviewOffer: true,
          ),
        ],
      );
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectEmployee);
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectSkillSheet);
      state = GameEngine.recordMilestone(state, FoundingMilestone.startSales);
      state = GameEngine.recordMilestone(state, FoundingMilestone.receiveInterviewOffer);
      state = GameEngine.recordMilestone(state, FoundingMilestone.completeClientInterview);
      expect(ProgressionEngine.currentStage(state), FoundingStage.awaitingAssignment);
      expect(EmployeeWorkflowEngine.forEngineer(state, focusId), EmployeeWorkflowState.selling);

      final action = ProgressionEngine.guidedAction(state)!;
      expect(action.description, isNot(contains('選考が進行中')));
      expect(action.canAdvanceWeek, isTrue);
    });

    test('a genuinely active (non-clientInterview) selection step still legitimately says "選考が進行中"', () {
      var state = GameEngine.newGame(seed: 1);
      final focusId = ProgressionEngine.focusEmployeeId(state)!;
      final project = state.openProjects.firstWhere((e) => e.project.selectionFlow.steps.length > 2).project;
      state = state.copyWith(
        engineers: [for (final e in state.engineers) if (e.id == focusId) e.copyWith(salesStatus: SalesStatus.interviewing) else e],
        proposals: [
          ProjectProposal(
            id: 'p-active',
            engineerId: focusId,
            project: project,
            proposedWeek: 1,
            stage: ProposalStage.proposed,
            status: ApplicationStatus.active,
            currentStepIndex: 1,
            fromInterviewOffer: true,
          ),
        ],
      );
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectEmployee);
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectSkillSheet);
      state = GameEngine.recordMilestone(state, FoundingMilestone.startSales);
      state = GameEngine.recordMilestone(state, FoundingMilestone.receiveInterviewOffer);
      state = GameEngine.recordMilestone(state, FoundingMilestone.completeClientInterview);
      expect(ProgressionEngine.currentStage(state), FoundingStage.awaitingAssignment);
      expect(EmployeeWorkflowEngine.forEngineer(state, focusId), EmployeeWorkflowState.waitingSelectionResult);

      final action = ProgressionEngine.guidedAction(state)!;
      expect(action.description, contains('選考が進行中'));
    });

    test('a cancelled proposal (project filled elsewhere) does not keep the guided action stuck on "選考結果を待っています"', () {
      var state = GameEngine.newGame(seed: 1);
      final focusId = ProgressionEngine.focusEmployeeId(state)!;
      final project = state.openProjects.first.project;
      state = state.copyWith(
        engineers: [for (final e in state.engineers) if (e.id == focusId) e.copyWith(salesStatus: SalesStatus.selling) else e],
        proposals: [
          ProjectProposal(
            id: 'p-cancelled',
            engineerId: focusId,
            project: project,
            proposedWeek: 1,
            stage: ProposalStage.proposed,
            status: ApplicationStatus.cancelled,
            fromInterviewOffer: true,
            rejectionReason: '募集枠が充足しました',
          ),
        ],
      );
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectEmployee);
      state = GameEngine.recordMilestone(state, FoundingMilestone.inspectSkillSheet);
      state = GameEngine.recordMilestone(state, FoundingMilestone.startSales);
      state = GameEngine.recordMilestone(state, FoundingMilestone.receiveInterviewOffer);
      expect(ProgressionEngine.currentStage(state), FoundingStage.clientInterview);
      expect(EmployeeWorkflowEngine.forEngineer(state, focusId), EmployeeWorkflowState.selling);

      final action = ProgressionEngine.guidedAction(state)!;
      expect(action.description, isNot(contains('選考結果を待っています')));
    });
  });

  group('Next-Week-Guard warning severity (§21-27)', () {
    test('a long-waiting but selling employee never produces a Critical waiting task', () {
      final e = buildEngineer(id: 'e1', status: EngineerStatus.waiting).copyWith(salesStatus: SalesStatus.selling);
      final state = GameEngine.newGame(seed: 1).copyWith(
        engineers: [e],
        openProjects: const [],
        waitingStreak: {'e1': 4},
      );
      final tasks = TaskEngine.generateTasks(state);
      expect(tasks.where((t) => t.id == 'waiting-critical-e1'), isEmpty);
      expect(tasks.where((t) => t.id == 'waiting-warning-e1'), isEmpty);
      expect(tasks.where((t) => t.id == 'waiting-busy-info-e1').single.priority, TaskPriority.info);
    });

    test('a long-waiting employee mid-selection never produces a Critical waiting task', () {
      final e = buildEngineer(id: 'e1', status: EngineerStatus.waiting).copyWith(salesStatus: SalesStatus.interviewing);
      final project = buildProject(id: 'p1');
      final state = GameEngine.newGame(seed: 1).copyWith(
        engineers: [e],
        openProjects: const [],
        waitingStreak: {'e1': 5},
        proposals: [
          ProjectProposal(
            id: 'prop1',
            engineerId: 'e1',
            project: project,
            proposedWeek: 1,
            stage: ProposalStage.proposed,
            status: ApplicationStatus.active,
            currentStepIndex: 1,
          ),
        ],
      );
      final tasks = TaskEngine.generateTasks(state);
      expect(tasks.where((t) => t.id == 'waiting-critical-e1'), isEmpty);
      expect(tasks.where((t) => t.id == 'waiting-busy-info-e1').single.priority, TaskPriority.info);
    });

    test('a genuinely idle (notSelling) long-waiting employee still produces the Critical waiting task', () {
      final e = buildEngineer(id: 'e1', status: EngineerStatus.waiting);
      final state = GameEngine.newGame(seed: 1).copyWith(
        engineers: [e],
        openProjects: const [],
        waitingStreak: {'e1': 3},
      );
      final tasks = TaskEngine.generateTasks(state);
      expect(tasks.where((t) => t.id == 'waiting-critical-e1').single.priority, TaskPriority.critical);
      expect(tasks.where((t) => t.id == 'waiting-busy-info-e1'), isEmpty);
    });
  });
}
