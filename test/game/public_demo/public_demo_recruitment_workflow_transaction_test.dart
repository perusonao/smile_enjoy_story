import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_transaction.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_workflow_transaction.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

/// WORKFLOW-STATE-1 §14/§15/§27: recruitment must commit cash
/// (PublicDemoState) and generated applicants (PublicDemoWorkflowState)
/// atomically — "cash spent, applicants missing" and "applicants created,
/// cash not spent" must both be impossible outcomes.
void main() {
  const transaction = PublicDemoRecruitmentWorkflowTransaction();

  test('successful recruitment commits cash and applicants together', () {
    final state = PublicDemoState.aprilStart();
    final workflow = PublicDemoWorkflowState.initial();
    final applicantsBefore = workflow.applicants.length;

    final result = transaction.execute(
      state: state,
      workflow: workflow,
      medium: PublicDemoRecruitmentMedium.engineer,
    );

    expect(result.isSuccess, isTrue);
    expect(result.state.cash, state.cash - 100000);
    expect(result.workflow.applicants.length, applicantsBefore + 2);
    // Every generated applicant actually landed in the committed workflow.
    final generatedIds = result.transactionResult.generatedApplicants
        .map((applicant) => applicant.id)
        .toSet();
    final committedIds = result.workflow.applicants
        .map((applicant) => applicant.id)
        .toSet();
    expect(committedIds.containsAll(generatedIds), isTrue);
  });

  test(
    'failed recruitment (insufficient cash) leaves both cash and applicants unchanged',
    () {
      final state = PublicDemoState.aprilStart().copyWith(cash: 99999);
      final workflow = PublicDemoWorkflowState.initial();

      final result = transaction.execute(
        state: state,
        workflow: workflow,
        medium: PublicDemoRecruitmentMedium.engineer,
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.status,
        PublicDemoRecruitmentTransactionStatus.insufficientCash,
      );
      expect(result.state, same(state));
      expect(result.workflow, same(workflow));
      expect(result.workflow.applicants, workflow.applicants);
    },
  );

  test(
    'failed recruitment (already used this month) is also an atomic no-op',
    () {
      final state = PublicDemoState.aprilStart();
      final workflow = PublicDemoWorkflowState.initial();
      final first = transaction.execute(
        state: state,
        workflow: workflow,
        medium: PublicDemoRecruitmentMedium.free,
      );

      final second = transaction.execute(
        state: first.state,
        workflow: first.workflow,
        medium: PublicDemoRecruitmentMedium.engineer,
      );

      expect(
        second.status,
        PublicDemoRecruitmentTransactionStatus.alreadyUsedThisMonth,
      );
      expect(second.state, same(first.state));
      expect(second.workflow, same(first.workflow));
    },
  );

  test(
    'cash-without-applicants and applicants-without-cash are both structurally impossible: '
    'the result always pairs cash movement with applicant growth, or neither',
    () {
      final state = PublicDemoState.aprilStart();
      final workflow = PublicDemoWorkflowState.initial();

      for (final medium in PublicDemoRecruitmentMedium.values) {
        final result = transaction.execute(
          state: state,
          workflow: workflow,
          medium: medium,
        );
        final cashChanged = result.state.cash != state.cash;
        final applicantsChanged =
            result.workflow.applicants.length != workflow.applicants.length;
        // Free media legitimately charges 0 cash while still adding an
        // applicant, so cash movement alone isn't the right invariant to
        // check symmetrically — instead assert the actual pairing this
        // transaction guarantees: success implies applicants grew by
        // exactly the medium's applicantCount and cash dropped by exactly
        // its cost; failure implies neither changed at all.
        if (result.isSuccess) {
          expect(cashChanged, medium.cost > 0);
          expect(applicantsChanged, isTrue);
          expect(result.state.cash, state.cash - medium.cost);
          expect(
            result.workflow.applicants.length,
            workflow.applicants.length + medium.applicantCount,
          );
        } else {
          expect(cashChanged, isFalse);
          expect(applicantsChanged, isFalse);
        }
      }
    },
  );

  test(
    'generated applicants are never appended when the underlying transaction fails',
    () {
      final failingTransaction = PublicDemoRecruitmentWorkflowTransaction(
        transaction: PublicDemoRecruitmentTransaction(
          candidateGenerator:
              ({required month, required medium, required count}) => const [],
        ),
      );
      final state = PublicDemoState.aprilStart();
      final workflow = PublicDemoWorkflowState.initial();

      final result = failingTransaction.execute(
        state: state,
        workflow: workflow,
        medium: PublicDemoRecruitmentMedium.free,
      );

      expect(
        result.status,
        PublicDemoRecruitmentTransactionStatus.generationFailed,
      );
      expect(result.state.cash, state.cash);
      expect(result.workflow.applicants, workflow.applicants);
    },
  );
}
