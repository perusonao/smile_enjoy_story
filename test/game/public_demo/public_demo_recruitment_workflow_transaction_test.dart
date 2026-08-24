import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_workflow_transaction.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

/// WORKFLOW-STATE-1 §14/§15/§27, WORKFLOW-STATE-1AB FIX1 P1-2: recruitment
/// must commit cash (PublicDemoState) and generated applicants
/// (PublicDemoWorkflowState) atomically — "cash spent, applicants missing"
/// and "applicants created, cash not spent" must both be impossible
/// outcomes. The pure cash/applicant calculation this wrapper commits is
/// private to production code (`_PublicDemoRecruitmentTransaction`), so
/// [PublicDemoRecruitmentWorkflowTransaction] below is the only entry point
/// — including for tests — meaning every assertion here, including the ones
/// that used to exercise the legacy calculation directly, doubles as proof
/// that a cash-only bypass is unavailable: there is no other way to reach
/// this behavior at all.
void main() {
  final transaction = PublicDemoRecruitmentWorkflowTransaction();

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
        candidateGenerator:
            ({required month, required medium, required count}) => const [],
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

  group('pure cash/applicant calculation (via the sole sanctioned entry)', () {
    PublicDemoRecruitmentWorkflowResult run(
      PublicDemoState state,
      PublicDemoRecruitmentMedium medium,
    ) => transaction.execute(
      state: state,
      workflow: PublicDemoWorkflowState.initial(),
      medium: medium,
    );

    test('free succeeds without charging cash and records one applicant', () {
      final before = PublicDemoState.aprilStart();
      final result = run(before, PublicDemoRecruitmentMedium.free);

      expect(result.isSuccess, isTrue);
      expect(result.transactionResult.chargedAmount, 0);
      expect(result.state.cash, before.cash);
      expect(result.state.recruitmentMediumUsedMonth, 4);
      expect(result.transactionResult.generatedApplicants, hasLength(1));
    });

    test('engineer succeeds atomically with two applicants and its cost', () {
      final before = PublicDemoState.aprilStart();
      final result = run(before, PublicDemoRecruitmentMedium.engineer);

      expect(result.isSuccess, isTrue);
      expect(result.transactionResult.chargedAmount, 100000);
      expect(result.state.cash, before.cash - 100000);
      expect(result.state.recruitmentMediumUsedMonth, 4);
      expect(result.transactionResult.generatedApplicants, hasLength(2));
    });

    test('generation is deterministic, exact, and IDs do not collide', () {
      final first = run(
        PublicDemoState.aprilStart(),
        PublicDemoRecruitmentMedium.engineer,
      );
      final second = run(
        PublicDemoState.aprilStart(),
        PublicDemoRecruitmentMedium.engineer,
      );

      expect(
        first.transactionResult.generatedApplicants.map(
          (applicant) => applicant.id,
        ),
        equals(
          second.transactionResult.generatedApplicants.map(
            (applicant) => applicant.id,
          ),
        ),
      );
      expect(first.transactionResult.generatedApplicants, hasLength(2));
      expect(
        first.transactionResult.generatedApplicants.map(
          (applicant) => applicant.id,
        ),
        isNot(contains(anyOf('app-01', 'app-02'))),
      );
    });

    test('engineer keeps the established experienced 高橋・田中 pool', () {
      final result = run(
        PublicDemoState.aprilStart(),
        PublicDemoRecruitmentMedium.engineer,
      );

      expect(
        result.transactionResult.generatedApplicants.map(
          (applicant) => applicant.name,
        ),
        unorderedEquals(
          publicDemoMayApplicants.map((applicant) => applicant.name),
        ),
      );
      expect(
        result.transactionResult.generatedApplicants,
        everyElement(
          isNot(
            predicate(
              (PublicDemoApplicant applicant) => applicant.isInexperienced,
            ),
          ),
        ),
      );
    });

    test(
      'free media deterministically alternates experienced and inexperienced candidates',
      () {
        final inexperienced = run(
          PublicDemoState.aprilStart(),
          PublicDemoRecruitmentMedium.free,
        );
        final experienced = run(
          PublicDemoState.aprilStart().copyWith(month: 5),
          PublicDemoRecruitmentMedium.free,
        );

        final junior =
            inexperienced.transactionResult.generatedApplicants.single;
        expect(junior.isInexperienced, isTrue);
        expect(junior.experienceMonths, 0);
        expect(junior.requestedMonthlySalary, 220000);
        expect(junior.salesSkillFit, inInclusiveRange(20, 30));
        expect(junior.interviewScore, greaterThanOrEqualTo(60));
        expect(junior.acceptanceScore, inInclusiveRange(70, 80));
        expect(
          experienced
              .transactionResult
              .generatedApplicants
              .single
              .isInexperienced,
          isFalse,
        );

        final repeated = run(
          PublicDemoState.aprilStart(),
          PublicDemoRecruitmentMedium.free,
        );
        expect(
          repeated.transactionResult.generatedApplicants.single.id,
          junior.id,
        );
        expect(
          repeated.transactionResult.generatedApplicants.single.name,
          junior.name,
        );
      },
    );

    test('preserves bonus, training, growth state and JSON compatibility', () {
      final before = PublicDemoState.aprilStart()
          .selectInternalTraining('eng-01')
          .copyWith(growthAppliedMonths: [4]);
      final result = run(before, PublicDemoRecruitmentMedium.free);

      expect(result.state.trainingSelections, before.trainingSelections);
      expect(result.state.growthAppliedMonths, before.growthAppliedMonths);
      expect(result.state.summerBonusSelection, before.summerBonusSelection);
      expect(
        PublicDemoState.fromJson(
          result.state.toJson(),
        ).recruitmentMediumUsedMonth,
        4,
      );
    });

    test(
      'July paid media is charged before bonus closing without double charge',
      () {
        final july = PublicDemoState.aprilStart().copyWith(
          month: 7,
          cash: 200000,
        );
        final purchased = run(july, PublicDemoRecruitmentMedium.engineer);
        final closed = purchased.state.advanceToAugust(
          monthlyExpenses: 100000,
          applicants: const [],
        );

        expect(purchased.state.cash, 100000);
        expect(closed.isPaid, isTrue);
        expect(closed.state.cash, 0);
      },
    );
  });

  group('recruitment media in months without a processing UI (P1-2)', () {
    // 12MONTH-3-FIX1 P1-2: 12MONTH-3 widened recruitment media's valid
    // month range to 4-15, but no UI past month 5 can ever process a
    // generated applicant — so a September-March medium purchase was a paid
    // dead end (Codex finding). The domain range was reverted to the
    // pre-12MONTH-3 4-8 (see public_demo_state.dart's
    // `_normalizedRecruitmentMediaMonth`); these tests pin that fix at the
    // transaction layer, the actual point where cash would otherwise have
    // been spent for nothing.
    test('A: paid recruitment is rejected for every month 9 through 15', () {
      for (var month = 9; month <= 15; month++) {
        final before = PublicDemoState.aprilStart().copyWith(month: month);
        final result = transaction.execute(
          state: before,
          workflow: PublicDemoWorkflowState.initial(),
          medium: PublicDemoRecruitmentMedium.engineer,
        );
        expect(
          result.isSuccess,
          isFalse,
          reason: 'month $month should reject paid recruitment',
        );
      }
    });

    test('B: cash never decreases for a rejected month-9-15 attempt', () {
      for (var month = 9; month <= 15; month++) {
        final before = PublicDemoState.aprilStart().copyWith(
          month: month,
          cash: 5000000,
        );
        final result = transaction.execute(
          state: before,
          workflow: PublicDemoWorkflowState.initial(),
          medium: PublicDemoRecruitmentMedium.engineer,
        );
        expect(
          result.state.cash,
          before.cash,
          reason: 'month $month must not spend cash',
        );
        expect(
          result.transactionResult.chargedAmount,
          0,
          reason: 'month $month',
        );
      }
    });

    test('C: no applicant is generated for a rejected month-9-15 attempt', () {
      for (var month = 9; month <= 15; month++) {
        final before = PublicDemoState.aprilStart().copyWith(month: month);
        final workflow = PublicDemoWorkflowState.initial();
        final result = transaction.execute(
          state: before,
          workflow: workflow,
          medium: PublicDemoRecruitmentMedium.engineer,
        );
        expect(
          result.transactionResult.generatedApplicants,
          isEmpty,
          reason: 'month $month must not generate applicants',
        );
        expect(
          result.workflow.applicants,
          workflow.applicants,
          reason: 'month $month must not append to the workflow roster',
        );
      }
    });

    test('C (free medium too): no applicant is generated for month 9-15', () {
      for (final month in [9, 12, 15]) {
        final before = PublicDemoState.aprilStart().copyWith(month: month);
        final result = transaction.execute(
          state: before,
          workflow: PublicDemoWorkflowState.initial(),
          medium: PublicDemoRecruitmentMedium.free,
        );
        expect(result.isSuccess, isFalse, reason: 'month $month');
        expect(
          result.transactionResult.generatedApplicants,
          isEmpty,
          reason: 'month $month',
        );
      }
    });

    test('D: months 4 through 8 are unaffected (no regression)', () {
      for (var month = 4; month <= 8; month++) {
        final before = PublicDemoState.aprilStart().copyWith(month: month);
        final result = transaction.execute(
          state: before,
          workflow: PublicDemoWorkflowState.initial(),
          medium: PublicDemoRecruitmentMedium.free,
        );
        expect(
          result.isSuccess,
          isTrue,
          reason: 'month $month must still allow recruitment media',
        );
        expect(
          result.transactionResult.generatedApplicants,
          hasLength(1),
          reason: 'month $month',
        );
      }
    });
  });
}
