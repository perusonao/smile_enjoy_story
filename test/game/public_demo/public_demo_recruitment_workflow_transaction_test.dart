import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_workflow_transaction.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

/// WORKFLOW-STATE-1 §14/§15/§27, WORKFLOW-STATE-1AB FIX1 P1-2, FIX2 P1-2:
/// recruitment must commit cash (PublicDemoState) and generated applicants
/// (PublicDemoWorkflowState) atomically — "cash spent, applicants missing"
/// and "applicants created, cash not spent" must both be impossible
/// outcomes. The pure cash/applicant calculation this wrapper commits is
/// private to production code (`_PublicDemoRecruitmentTransaction`), so
/// [PublicDemoRecruitmentWorkflowTransaction] below is the only entry point
/// — including for tests.
///
/// FIX2 P1-2: [PublicDemoRecruitmentWorkflowTransaction.execute] no longer
/// returns the committed [PublicDemoState]/[PublicDemoWorkflowState] as
/// separate public fields a caller could apply selectively — the only way
/// to obtain either is the required `onCommitted` callback, invoked exactly
/// once with both together, only on success. [_Committed]/[_run] below is
/// this test file's helper for capturing that callback's arguments.
class _Committed {
  _Committed(this.result, this.state, this.workflow);
  final PublicDemoRecruitmentTransactionResult result;
  final PublicDemoState? state;
  final PublicDemoWorkflowState? workflow;
  bool get isSuccess => result.isSuccess;
  PublicDemoRecruitmentTransactionStatus get status => result.status;
}

_Committed _run(
  PublicDemoRecruitmentWorkflowTransaction transaction, {
  required PublicDemoState state,
  required PublicDemoWorkflowState workflow,
  required PublicDemoRecruitmentMedium medium,
}) {
  PublicDemoState? committedState;
  PublicDemoWorkflowState? committedWorkflow;
  final result = transaction.execute(
    state: state,
    workflow: workflow,
    medium: medium,
    onCommitted: (nextState, nextWorkflow) {
      committedState = nextState;
      committedWorkflow = nextWorkflow;
    },
  );
  return _Committed(result, committedState, committedWorkflow);
}

void main() {
  final transaction = PublicDemoRecruitmentWorkflowTransaction();

  test('successful recruitment commits cash and applicants together', () {
    final state = PublicDemoState.aprilStart();
    final workflow = PublicDemoWorkflowState.initial();
    final applicantsBefore = workflow.applicants.length;

    final result = _run(
      transaction,
      state: state,
      workflow: workflow,
      medium: PublicDemoRecruitmentMedium.engineer,
    );

    expect(result.isSuccess, isTrue);
    expect(result.state!.cash, state.cash - 100000);
    expect(result.workflow!.applicants.length, applicantsBefore + 2);
    // Every generated applicant actually landed in the committed workflow.
    final generatedIds = result.result.generatedApplicants
        .map((applicant) => applicant.id)
        .toSet();
    final committedIds = result.workflow!.applicants
        .map((applicant) => applicant.id)
        .toSet();
    expect(committedIds.containsAll(generatedIds), isTrue);
  });

  test('failed recruitment (insufficient cash) never invokes onCommitted: cash '
      'and applicants are structurally unreachable, not merely unchanged', () {
    final state = PublicDemoState.aprilStart().copyWith(cash: 99999);
    final workflow = PublicDemoWorkflowState.initial();

    final result = _run(
      transaction,
      state: state,
      workflow: workflow,
      medium: PublicDemoRecruitmentMedium.engineer,
    );

    expect(result.isSuccess, isFalse);
    expect(
      result.status,
      PublicDemoRecruitmentTransactionStatus.insufficientCash,
    );
    expect(result.state, isNull);
    expect(result.workflow, isNull);
  });

  test(
    'failed recruitment (already used this month) is also an atomic no-op',
    () {
      final state = PublicDemoState.aprilStart();
      final workflow = PublicDemoWorkflowState.initial();
      final first = _run(
        transaction,
        state: state,
        workflow: workflow,
        medium: PublicDemoRecruitmentMedium.free,
      );
      expect(first.isSuccess, isTrue);

      final second = _run(
        transaction,
        state: first.state!,
        workflow: first.workflow!,
        medium: PublicDemoRecruitmentMedium.engineer,
      );

      expect(
        second.status,
        PublicDemoRecruitmentTransactionStatus.alreadyUsedThisMonth,
      );
      expect(second.state, isNull);
      expect(second.workflow, isNull);
    },
  );

  test(
    'cash-without-applicants and applicants-without-cash are both structurally '
    'impossible: the committed pair always moves cash and applicants '
    'together, or onCommitted never fires at all',
    () {
      final state = PublicDemoState.aprilStart();
      final workflow = PublicDemoWorkflowState.initial();

      for (final medium in PublicDemoRecruitmentMedium.values) {
        final result = _run(
          transaction,
          state: state,
          workflow: workflow,
          medium: medium,
        );
        if (result.isSuccess) {
          expect(result.state, isNotNull);
          expect(result.workflow, isNotNull);
          expect(result.state!.cash, state.cash - medium.cost);
          expect(
            result.workflow!.applicants.length,
            workflow.applicants.length + medium.applicantCount,
          );
        } else {
          expect(result.state, isNull);
          expect(result.workflow, isNull);
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

      final result = _run(
        failingTransaction,
        state: state,
        workflow: workflow,
        medium: PublicDemoRecruitmentMedium.free,
      );

      expect(
        result.status,
        PublicDemoRecruitmentTransactionStatus.generationFailed,
      );
      expect(result.state, isNull);
      expect(result.workflow, isNull);
    },
  );

  group('public caller cannot retain only charged cash authority (P1-2)', () {
    test('execute() itself carries no committed PublicDemoState field: the '
        'read-only PublicDemoRecruitmentTransactionResult it always returns '
        'has no way to read the cash-charged state without onCommitted', () {
      final state = PublicDemoState.aprilStart();
      final workflow = PublicDemoWorkflowState.initial();

      // The bare, non-callback call still succeeds and still charges
      // cash/generates applicants internally — but nothing in what it
      // returns exposes either as an independently retrievable field.
      // (This is a structural/API-shape guarantee: `.state` and
      // `.workflow` are simply not members of
      // PublicDemoRecruitmentTransactionResult — see the class doc on
      // PublicDemoRecruitmentWorkflowTransaction.)
      final result = transaction.execute(
        state: state,
        workflow: workflow,
        medium: PublicDemoRecruitmentMedium.engineer,
      );
      expect(result.isSuccess, isTrue);
      expect(result.generatedApplicants, hasLength(2));
      expect(result.chargedAmount, 100000);
    });

    test('onCommitted always receives cash and applicants paired: there is no '
        'call shape that yields the charged state without the generated '
        'applicants alongside it', () {
      final state = PublicDemoState.aprilStart();
      final workflow = PublicDemoWorkflowState.initial();
      var commits = 0;

      transaction.execute(
        state: state,
        workflow: workflow,
        medium: PublicDemoRecruitmentMedium.engineer,
        onCommitted: (committedState, committedWorkflow) {
          commits++;
          expect(committedState.cash, state.cash - 100000);
          expect(
            committedWorkflow.applicants.length,
            workflow.applicants.length + 2,
          );
        },
      );
      expect(commits, 1);
    });
  });

  group('pure cash/applicant calculation (via the sole sanctioned entry)', () {
    _Committed run(PublicDemoState state, PublicDemoRecruitmentMedium medium) =>
        _run(
          transaction,
          state: state,
          workflow: PublicDemoWorkflowState.initial(),
          medium: medium,
        );

    test('free succeeds without charging cash and records one applicant', () {
      final before = PublicDemoState.aprilStart();
      final result = run(before, PublicDemoRecruitmentMedium.free);

      expect(result.isSuccess, isTrue);
      expect(result.result.chargedAmount, 0);
      expect(result.state!.cash, before.cash);
      expect(result.state!.recruitmentMediumUsedMonth, 4);
      expect(result.result.generatedApplicants, hasLength(1));
    });

    test('engineer succeeds atomically with two applicants and its cost', () {
      final before = PublicDemoState.aprilStart();
      final result = run(before, PublicDemoRecruitmentMedium.engineer);

      expect(result.isSuccess, isTrue);
      expect(result.result.chargedAmount, 100000);
      expect(result.state!.cash, before.cash - 100000);
      expect(result.state!.recruitmentMediumUsedMonth, 4);
      expect(result.result.generatedApplicants, hasLength(2));
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
        first.result.generatedApplicants.map((applicant) => applicant.id),
        equals(
          second.result.generatedApplicants.map((applicant) => applicant.id),
        ),
      );
      expect(first.result.generatedApplicants, hasLength(2));
      expect(
        first.result.generatedApplicants.map((applicant) => applicant.id),
        isNot(contains(anyOf('app-01', 'app-02'))),
      );
    });

    test('engineer keeps the established experienced 高橋・田中 pool', () {
      final result = run(
        PublicDemoState.aprilStart(),
        PublicDemoRecruitmentMedium.engineer,
      );

      expect(
        result.result.generatedApplicants.map((applicant) => applicant.name),
        unorderedEquals(
          publicDemoMayApplicants.map((applicant) => applicant.name),
        ),
      );
      expect(
        result.result.generatedApplicants,
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

        final junior = inexperienced.result.generatedApplicants.single;
        expect(junior.isInexperienced, isTrue);
        expect(junior.experienceMonths, 0);
        expect(junior.requestedMonthlySalary, 220000);
        expect(junior.salesSkillFit, inInclusiveRange(20, 30));
        expect(junior.interviewScore, greaterThanOrEqualTo(60));
        expect(junior.acceptanceScore, inInclusiveRange(70, 80));
        expect(
          experienced.result.generatedApplicants.single.isInexperienced,
          isFalse,
        );

        final repeated = run(
          PublicDemoState.aprilStart(),
          PublicDemoRecruitmentMedium.free,
        );
        expect(repeated.result.generatedApplicants.single.id, junior.id);
        expect(repeated.result.generatedApplicants.single.name, junior.name);
      },
    );

    test('preserves bonus, training, growth state and JSON compatibility', () {
      final before = PublicDemoState.aprilStart()
          .selectInternalTraining('eng-01')
          .copyWith(growthAppliedMonths: [4]);
      final result = run(before, PublicDemoRecruitmentMedium.free);

      expect(result.state!.trainingSelections, before.trainingSelections);
      expect(result.state!.growthAppliedMonths, before.growthAppliedMonths);
      expect(result.state!.summerBonusSelection, before.summerBonusSelection);
      expect(
        PublicDemoState.fromJson(
          result.state!.toJson(),
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
        final closed = purchased.state!.advanceToAugust(
          monthlyExpenses: 100000,
          applicants: const [],
        );

        expect(purchased.state!.cash, 100000);
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
        final result = _run(
          transaction,
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
        final result = _run(
          transaction,
          state: before,
          workflow: PublicDemoWorkflowState.initial(),
          medium: PublicDemoRecruitmentMedium.engineer,
        );
        expect(
          result.state,
          isNull,
          reason: 'month $month must not commit any cash change',
        );
        expect(result.result.chargedAmount, 0, reason: 'month $month');
      }
    });

    test('C: no applicant is generated for a rejected month-9-15 attempt', () {
      for (var month = 9; month <= 15; month++) {
        final before = PublicDemoState.aprilStart().copyWith(month: month);
        final workflow = PublicDemoWorkflowState.initial();
        final result = _run(
          transaction,
          state: before,
          workflow: workflow,
          medium: PublicDemoRecruitmentMedium.engineer,
        );
        expect(
          result.result.generatedApplicants,
          isEmpty,
          reason: 'month $month must not generate applicants',
        );
        expect(
          result.workflow,
          isNull,
          reason: 'month $month must not append to the workflow roster',
        );
      }
    });

    test('C (free medium too): no applicant is generated for month 9-15', () {
      for (final month in [9, 12, 15]) {
        final before = PublicDemoState.aprilStart().copyWith(month: month);
        final result = _run(
          transaction,
          state: before,
          workflow: PublicDemoWorkflowState.initial(),
          medium: PublicDemoRecruitmentMedium.free,
        );
        expect(result.isSuccess, isFalse, reason: 'month $month');
        expect(
          result.result.generatedApplicants,
          isEmpty,
          reason: 'month $month',
        );
      }
    });

    test('D: months 4 through 8 are unaffected (no regression)', () {
      for (var month = 4; month <= 8; month++) {
        final before = PublicDemoState.aprilStart().copyWith(month: month);
        final result = _run(
          transaction,
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
          result.result.generatedApplicants,
          hasLength(1),
          reason: 'month $month',
        );
      }
    });
  });
}
