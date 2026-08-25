import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

/// WORKFLOW-STATE-1 §14/§15/§27, WORKFLOW-STATE-1AB FIX1 P1-2, FIX2 P1-2,
/// FIX3 P1-2, FIX4 P1-2: recruitment must commit cash (finance side) and
/// generated applicants (workflow side) atomically — "cash spent,
/// applicants missing" and "applicants created, cash not spent" must both
/// be impossible outcomes. [PublicDemoAggregate.recruit] is the only
/// production entry point that ever commits either.
///
/// FIX4 P1-2: FIX3's `PublicDemoAggregate.restore(state:, workflow:)` was
/// itself still a public, production-reachable API — this file used it to
/// build custom `PublicDemoState` fixtures (specific months, specific cash
/// balances) for tests that only actually care about the pure month/cash/
/// generation calculation, never about aggregate atomicity. Since that
/// calculation ([PublicDemoRecruitmentCalculation]) is itself public and
/// state-only — INTERNAL HELPER tier, same reasoning as
/// [PublicDemoMonthlyClose]/[PublicDemoState.advanceToJune] remaining
/// public — those tests now call it directly instead of assembling a whole
/// aggregate via a reconstruction shortcut that no longer exists. The
/// aggregate-atomicity tests (this file's first group) instead reach their
/// fixture states by chaining real [PublicDemoAggregate] commands from
/// [PublicDemoAggregate.initial], exactly as production code does.
void main() {
  group('PublicDemoAggregate.recruit atomicity', () {
    PublicDemoRecruitmentTransactionResult run(
      PublicDemoAggregate aggregate,
      PublicDemoRecruitmentMedium medium,
    ) => aggregate.recruit(medium);

    test('successful recruitment commits cash and applicants together', () {
      final aggregate = PublicDemoAggregate.initial();
      final applicantsBefore = aggregate.workflow.applicants.length;

      final result = run(aggregate, PublicDemoRecruitmentMedium.engineer);

      expect(result.isSuccess, isTrue);
      expect(result.aggregate!.state.cash, aggregate.state.cash - 100000);
      expect(
        result.aggregate!.workflow.applicants.length,
        applicantsBefore + 2,
      );
      // Every generated applicant actually landed in the committed workflow.
      final generatedIds = result.generatedApplicants
          .map((applicant) => applicant.id)
          .toSet();
      final committedIds = result.aggregate!.workflow.applicants
          .map((applicant) => applicant.id)
          .toSet();
      expect(committedIds.containsAll(generatedIds), isTrue);
    });

    test('failed recruitment (insufficient cash) commits nothing: cash and '
        'applicants are structurally unreachable, not merely unchanged', () {
      // Reaches a genuinely poor aggregate through a real command chain
      // (PublicDemoAggregate.initial's April cash minus almost all of it
      // via closeApril's own monthlyExpenses parameter) rather than
      // constructing one directly — there is no production API that
      // accepts a caller-supplied PublicDemoState any more.
      final poor = PublicDemoAggregate.initial().closeApril(
        monthlyExpenses: 2999999,
      );
      expect(poor.state.cash, 1);

      final result = run(poor, PublicDemoRecruitmentMedium.engineer);

      expect(result.isSuccess, isFalse);
      expect(
        result.status,
        PublicDemoRecruitmentTransactionStatus.insufficientCash,
      );
      expect(result.aggregate, isNull);
    });

    test(
      'failed recruitment (already used this month) is also an atomic no-op',
      () {
        final aggregate = PublicDemoAggregate.initial();
        final first = run(aggregate, PublicDemoRecruitmentMedium.free);
        expect(first.isSuccess, isTrue);

        final second = run(
          first.aggregate!,
          PublicDemoRecruitmentMedium.engineer,
        );

        expect(
          second.status,
          PublicDemoRecruitmentTransactionStatus.alreadyUsedThisMonth,
        );
        expect(second.aggregate, isNull);
      },
    );

    test(
      'cash-without-applicants and applicants-without-cash are both structurally '
      'impossible: the committed aggregate always moves cash and applicants '
      'together, or nothing commits at all',
      () {
        final aggregate = PublicDemoAggregate.initial();

        for (final medium in PublicDemoRecruitmentMedium.values) {
          final result = run(aggregate, medium);
          if (result.isSuccess) {
            expect(result.aggregate, isNotNull);
            expect(
              result.aggregate!.state.cash,
              aggregate.state.cash - medium.cost,
            );
            expect(
              result.aggregate!.workflow.applicants.length,
              aggregate.workflow.applicants.length + medium.applicantCount,
            );
          } else {
            expect(result.aggregate, isNull);
          }
        }
      },
    );

    test(
      'generated applicants are never appended when the underlying transaction fails',
      () {
        final aggregate = PublicDemoAggregate.initial();

        final result = aggregate.recruit(
          PublicDemoRecruitmentMedium.free,
          candidateGenerator:
              ({required month, required medium, required count}) => const [],
        );

        expect(
          result.status,
          PublicDemoRecruitmentTransactionStatus.generationFailed,
        );
        expect(result.aggregate, isNull);
      },
    );

    group('public caller cannot retain only charged cash authority (P1-2)', () {
      test('the read-only PublicDemoRecruitmentTransactionResult exposes no '
          'separately-committable PublicDemoState/PublicDemoWorkflowState: '
          'the only reference to the committed outcome is one `aggregate` '
          'field', () {
        final aggregate = PublicDemoAggregate.initial();

        final result = run(aggregate, PublicDemoRecruitmentMedium.engineer);
        expect(result.isSuccess, isTrue);
        expect(result.generatedApplicants, hasLength(2));
        expect(result.chargedAmount, 100000);
        expect(result.aggregate!.state.cash, aggregate.state.cash - 100000);
        expect(
          result.aggregate!.workflow.applicants.length,
          aggregate.workflow.applicants.length + 2,
        );
      });
    });
  });

  group('PublicDemoRecruitmentCalculation: pure month/cash/generation logic '
      '(INTERNAL HELPER tier — see class doc)', () {
    PublicDemoRecruitmentCalculationResult runFrom(
      PublicDemoState state,
      PublicDemoRecruitmentMedium medium,
    ) => const PublicDemoRecruitmentCalculation().execute(
      state: state,
      medium: medium,
    );

    test('free succeeds without charging cash and records one applicant', () {
      final before = PublicDemoState.aprilStart();
      final result = runFrom(before, PublicDemoRecruitmentMedium.free);

      expect(result.isSuccess, isTrue);
      expect(result.chargedAmount, 0);
      expect(result.state.cash, before.cash);
      expect(result.state.recruitmentMediumUsedMonth, 4);
      expect(result.generatedApplicants, hasLength(1));
    });

    test('engineer succeeds atomically with two applicants and its cost', () {
      final before = PublicDemoState.aprilStart();
      final result = runFrom(before, PublicDemoRecruitmentMedium.engineer);

      expect(result.isSuccess, isTrue);
      expect(result.chargedAmount, 100000);
      expect(result.state.cash, before.cash - 100000);
      expect(result.state.recruitmentMediumUsedMonth, 4);
      expect(result.generatedApplicants, hasLength(2));
    });

    test('generation is deterministic, exact, and IDs do not collide', () {
      final first = runFrom(
        PublicDemoState.aprilStart(),
        PublicDemoRecruitmentMedium.engineer,
      );
      final second = runFrom(
        PublicDemoState.aprilStart(),
        PublicDemoRecruitmentMedium.engineer,
      );

      expect(
        first.generatedApplicants.map((applicant) => applicant.id),
        equals(second.generatedApplicants.map((applicant) => applicant.id)),
      );
      expect(first.generatedApplicants, hasLength(2));
      expect(
        first.generatedApplicants.map((applicant) => applicant.id),
        isNot(contains(anyOf('app-01', 'app-02'))),
      );
    });

    test('engineer keeps the established experienced 高橋・田中 pool', () {
      final result = runFrom(
        PublicDemoState.aprilStart(),
        PublicDemoRecruitmentMedium.engineer,
      );

      expect(
        result.generatedApplicants.map((applicant) => applicant.name),
        unorderedEquals(
          publicDemoMayApplicants.map((applicant) => applicant.name),
        ),
      );
      expect(
        result.generatedApplicants,
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
        final inexperienced = runFrom(
          PublicDemoState.aprilStart(),
          PublicDemoRecruitmentMedium.free,
        );
        final experienced = runFrom(
          PublicDemoState.aprilStart().copyWith(month: 5),
          PublicDemoRecruitmentMedium.free,
        );

        final junior = inexperienced.generatedApplicants.single;
        expect(junior.isInexperienced, isTrue);
        expect(junior.experienceMonths, 0);
        expect(junior.requestedMonthlySalary, 220000);
        expect(junior.salesSkillFit, inInclusiveRange(20, 30));
        expect(junior.interviewScore, greaterThanOrEqualTo(60));
        expect(junior.acceptanceScore, inInclusiveRange(70, 80));
        expect(experienced.generatedApplicants.single.isInexperienced, isFalse);

        final repeated = runFrom(
          PublicDemoState.aprilStart(),
          PublicDemoRecruitmentMedium.free,
        );
        expect(repeated.generatedApplicants.single.id, junior.id);
        expect(repeated.generatedApplicants.single.name, junior.name);
      },
    );

    test('preserves bonus, training, growth state and JSON compatibility', () {
      final before = PublicDemoState.aprilStart()
          .selectInternalTraining('eng-01')
          .copyWith(growthAppliedMonths: [4]);
      final result = runFrom(before, PublicDemoRecruitmentMedium.free);

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
        final purchased = runFrom(july, PublicDemoRecruitmentMedium.engineer);
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
    // pure calculation layer, the actual point where cash would otherwise
    // have been spent for nothing.
    PublicDemoRecruitmentCalculationResult runFrom(
      PublicDemoState state,
      PublicDemoRecruitmentMedium medium,
    ) => const PublicDemoRecruitmentCalculation().execute(
      state: state,
      medium: medium,
    );

    test('A: paid recruitment is rejected for every month 9 through 15', () {
      for (var month = 9; month <= 15; month++) {
        final before = PublicDemoState.aprilStart().copyWith(month: month);
        final result = runFrom(before, PublicDemoRecruitmentMedium.engineer);
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
        final result = runFrom(before, PublicDemoRecruitmentMedium.engineer);
        expect(
          result.state.cash,
          before.cash,
          reason: 'month $month must not commit any cash change',
        );
        expect(result.chargedAmount, 0, reason: 'month $month');
      }
    });

    test('C: no applicant is generated for a rejected month-9-15 attempt', () {
      for (var month = 9; month <= 15; month++) {
        final before = PublicDemoState.aprilStart().copyWith(month: month);
        final result = runFrom(before, PublicDemoRecruitmentMedium.engineer);
        expect(
          result.generatedApplicants,
          isEmpty,
          reason: 'month $month must not generate applicants',
        );
      }
    });

    test('C (free medium too): no applicant is generated for month 9-15', () {
      for (final month in [9, 12, 15]) {
        final before = PublicDemoState.aprilStart().copyWith(month: month);
        final result = runFrom(before, PublicDemoRecruitmentMedium.free);
        expect(result.isSuccess, isFalse, reason: 'month $month');
        expect(result.generatedApplicants, isEmpty, reason: 'month $month');
      }
    });

    test('D: months 4 through 8 are unaffected (no regression)', () {
      for (var month = 4; month <= 8; month++) {
        final before = PublicDemoState.aprilStart().copyWith(month: month);
        final result = runFrom(before, PublicDemoRecruitmentMedium.free);
        expect(
          result.isSuccess,
          isTrue,
          reason: 'month $month must still allow recruitment media',
        );
        expect(
          result.generatedApplicants,
          hasLength(1),
          reason: 'month $month',
        );
      }
    });
  });
}
