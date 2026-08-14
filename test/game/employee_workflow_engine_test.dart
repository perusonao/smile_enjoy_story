// EmployeeWorkflowState derivation + priority tests (Playable 0.4C.3 §12-17,
// §62-63): the single source of truth every screen (Home, employee list,
// employee detail) renders from. Each test builds a hand-crafted GameState
// via GameEngine.newGame().copyWith(...) so the derivation can be checked
// in isolation, without needing a full playthrough.

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/domain/domain.dart';
import 'package:smile_enjoy_story/game/game.dart';

void main() {
  late GameState base;
  late Engineer employee;
  late Project project;

  setUp(() {
    base = GameEngine.newGame(seed: 1);
    employee = base.engineers.first;
    project = base.openProjects.first.project;
  });

  EmployeeWorkflowState stateFor(GameState s) => EmployeeWorkflowEngine.forEngineer(s, employee.id);

  group('single-fact derivation (§13, §16)', () {
    test('a fresh engineer is waiting', () {
      expect(stateFor(base), EmployeeWorkflowState.waiting);
    });

    test('salesStatus.selling maps to selling', () {
      final s = base.copyWith(engineers: [
        employee.copyWith(salesStatus: SalesStatus.selling),
        ...base.engineers.skip(1),
      ]);
      expect(stateFor(s), EmployeeWorkflowState.selling);
    });

    test('a pending InterviewOffer maps to interviewRequestPending', () {
      final s = base.copyWith(interviewOffers: [
        InterviewOffer(
          id: 'io-1',
          employeeId: employee.id,
          projectId: project.id,
          clientId: project.clientId,
          generatedWeek: 1,
          expiresWeek: 4,
          skillSheetMatch: 70,
        ),
      ]);
      expect(stateFor(s), EmployeeWorkflowState.interviewRequestPending);
    });

    test('an active proposal not at clientInterview maps to waitingSelectionResult', () {
      final s = base.copyWith(proposals: [
        ProjectProposal(
          id: 'p-1',
          engineerId: employee.id,
          project: project,
          proposedWeek: 1,
          stage: ProposalStage.proposed,
          status: ApplicationStatus.active,
          currentStepIndex: 1, // technicalInterview or similar, not clientInterview
        ),
      ]);
      // Guard: only meaningful if this project's flow step 1 isn't clientInterview.
      expect(project.selectionFlow.steps[1], isNot(SelectionStep.clientInterview));
      expect(stateFor(s), EmployeeWorkflowState.waitingSelectionResult);
    });

    test('an active proposal at clientInterview with no completed session maps to clientInterviewActionRequired', () {
      final clientInterviewIndex = project.selectionFlow.steps.indexOf(SelectionStep.clientInterview);
      final s = base.copyWith(proposals: [
        ProjectProposal(
          id: 'p-1',
          engineerId: employee.id,
          project: project,
          proposedWeek: 1,
          stage: ProposalStage.proposed,
          status: ApplicationStatus.active,
          currentStepIndex: clientInterviewIndex,
        ),
      ]);
      expect(stateFor(s), EmployeeWorkflowState.clientInterviewActionRequired);
    });

    test('a pending final Offer maps to finalOfferPending', () {
      final s = base.copyWith(
        proposals: [
          ProjectProposal(
            id: 'p-1',
            engineerId: employee.id,
            project: project,
            proposedWeek: 1,
            stage: ProposalStage.proposed,
            status: ApplicationStatus.offered,
          ),
        ],
        offers: [
          Offer(
            id: 'o-1',
            applicationId: 'p-1',
            projectId: project.id,
            employeeId: employee.id,
            monthlyRate: project.monthlyRate,
            startWeek: 5,
            responseDeadlineWeek: 4,
          ),
        ],
      );
      expect(stateFor(s), EmployeeWorkflowState.finalOfferPending);
    });

    test('an accepted proposal (Offer accepted, assignment not yet started) maps to assignmentScheduled', () {
      final s = base.copyWith(proposals: [
        ProjectProposal(
          id: 'p-1',
          engineerId: employee.id,
          project: project,
          proposedWeek: 1,
          stage: ProposalStage.interviewPassed,
          status: ApplicationStatus.accepted,
          assignWeek: 6,
        ),
      ]);
      expect(stateFor(s), EmployeeWorkflowState.assignmentScheduled);
    });

    test('an ActiveAssignment maps to assigned', () {
      final s = base.copyWith(activeAssignments: [
        ActiveAssignment(engineerId: employee.id, project: project, remainingWeeks: 10, assignedWeek: 1),
      ]);
      expect(stateFor(s), EmployeeWorkflowState.assigned);
    });
  });

  group('priority when multiple facts coexist (§15)', () {
    test('assigned wins even with a pending Offer for a follow-on contract', () {
      final s = base.copyWith(
        activeAssignments: [
          ActiveAssignment(engineerId: employee.id, project: project, remainingWeeks: 2, assignedWeek: 1),
        ],
        proposals: [
          ProjectProposal(
            id: 'p-2',
            engineerId: employee.id,
            project: project,
            proposedWeek: 1,
            stage: ProposalStage.proposed,
            status: ApplicationStatus.offered,
          ),
        ],
        offers: [
          Offer(
            id: 'o-2',
            applicationId: 'p-2',
            projectId: project.id,
            employeeId: employee.id,
            monthlyRate: project.monthlyRate,
            startWeek: 5,
            responseDeadlineWeek: 4,
          ),
        ],
      );
      expect(stateFor(s), EmployeeWorkflowState.assigned);
    });

    test('finalOfferPending wins over a stale pending InterviewOffer for another project', () {
      final s = base.copyWith(
        interviewOffers: [
          InterviewOffer(
            id: 'io-1',
            employeeId: employee.id,
            projectId: 'some-other-project',
            clientId: project.clientId,
            generatedWeek: 1,
            expiresWeek: 10,
            skillSheetMatch: 60,
          ),
        ],
        proposals: [
          ProjectProposal(
            id: 'p-1',
            engineerId: employee.id,
            project: project,
            proposedWeek: 1,
            stage: ProposalStage.proposed,
            status: ApplicationStatus.offered,
          ),
        ],
        offers: [
          Offer(
            id: 'o-1',
            applicationId: 'p-1',
            projectId: project.id,
            employeeId: employee.id,
            monthlyRate: project.monthlyRate,
            startWeek: 5,
            responseDeadlineWeek: 4,
          ),
        ],
      );
      expect(stateFor(s), EmployeeWorkflowState.finalOfferPending);
    });
  });

  group('labels are unique and non-empty (§16)', () {
    test('every state has a label, and no two states share a label', () {
      for (final state in EmployeeWorkflowState.values) {
        expect(EmployeeWorkflowEngine.labels[state], isNotNull);
        expect(EmployeeWorkflowEngine.labels[state], isNotEmpty);
      }
      expect(EmployeeWorkflowEngine.labels.values.toSet().length, EmployeeWorkflowState.values.length);
    });
  });

  group('requiresAction (§18, §21)', () {
    test('clientInterviewActionRequired, finalOfferPending and interviewRequestPending all require action', () {
      expect(EmployeeWorkflowEngine.requiresAction(EmployeeWorkflowState.clientInterviewActionRequired), isTrue);
      expect(EmployeeWorkflowEngine.requiresAction(EmployeeWorkflowState.finalOfferPending), isTrue);
      expect(EmployeeWorkflowEngine.requiresAction(EmployeeWorkflowState.interviewRequestPending), isTrue);
    });

    test('waiting, selling, waitingSelectionResult, assignmentScheduled and assigned never require action', () {
      for (final state in [
        EmployeeWorkflowState.waiting,
        EmployeeWorkflowState.selling,
        EmployeeWorkflowState.waitingSelectionResult,
        EmployeeWorkflowState.assignmentScheduled,
        EmployeeWorkflowState.assigned,
      ]) {
        expect(EmployeeWorkflowEngine.requiresAction(state), isFalse, reason: '$state should not require action');
      }
    });
  });
}
