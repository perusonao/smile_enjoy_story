import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_transaction.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

void main() {
  const transaction = PublicDemoRecruitmentTransaction();

  group('PublicDemoRecruitmentTransaction', () {
    test('free succeeds without charging cash and records one applicant', () {
      final before = PublicDemoState.aprilStart();
      final result = transaction.execute(
        state: before,
        medium: PublicDemoRecruitmentMedium.free,
      );

      expect(result.isSuccess, isTrue);
      expect(result.chargedAmount, 0);
      expect(result.state.cash, before.cash);
      expect(result.state.recruitmentMediumUsedMonth, 4);
      expect(result.generatedApplicants, hasLength(1));
    });

    test('engineer succeeds atomically with two applicants and its cost', () {
      final before = PublicDemoState.aprilStart();
      final result = transaction.execute(
        state: before,
        medium: PublicDemoRecruitmentMedium.engineer,
      );

      expect(result.isSuccess, isTrue);
      expect(result.chargedAmount, 100000);
      expect(result.state.cash, before.cash - 100000);
      expect(result.state.recruitmentMediumUsedMonth, 4);
      expect(result.generatedApplicants, hasLength(2));
    });

    test('insufficient cash is an atomic no-op', () {
      final before = PublicDemoState.aprilStart().copyWith(cash: 99999);
      final result = transaction.execute(
        state: before,
        medium: PublicDemoRecruitmentMedium.engineer,
      );

      expect(
        result.status,
        PublicDemoRecruitmentTransactionStatus.insufficientCash,
      );
      expect(result.state, same(before));
      expect(result.generatedApplicants, isEmpty);
      expect(result.chargedAmount, 0);
    });

    test(
      'same-month second use is an atomic no-op and next month is usable',
      () {
        final first = transaction.execute(
          state: PublicDemoState.aprilStart(),
          medium: PublicDemoRecruitmentMedium.free,
        );
        final second = transaction.execute(
          state: first.state,
          medium: PublicDemoRecruitmentMedium.engineer,
        );
        final nextMonth = transaction.execute(
          state: first.state.copyWith(month: 5),
          medium: PublicDemoRecruitmentMedium.engineer,
        );

        expect(
          second.status,
          PublicDemoRecruitmentTransactionStatus.alreadyUsedThisMonth,
        );
        expect(second.state, same(first.state));
        expect(nextMonth.isSuccess, isTrue);
      },
    );

    test('generation is deterministic, exact, and IDs do not collide', () {
      final first = transaction.execute(
        state: PublicDemoState.aprilStart(),
        medium: PublicDemoRecruitmentMedium.engineer,
      );
      final second = transaction.execute(
        state: PublicDemoState.aprilStart(),
        medium: PublicDemoRecruitmentMedium.engineer,
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
      final result = transaction.execute(
        state: PublicDemoState.aprilStart(),
        medium: PublicDemoRecruitmentMedium.engineer,
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
        final inexperienced = transaction.execute(
          state: PublicDemoState.aprilStart(),
          medium: PublicDemoRecruitmentMedium.free,
        );
        final experienced = transaction.execute(
          state: PublicDemoState.aprilStart().copyWith(month: 5),
          medium: PublicDemoRecruitmentMedium.free,
        );

        final junior = inexperienced.generatedApplicants.single;
        expect(junior.isInexperienced, isTrue);
        expect(junior.experienceMonths, 0);
        expect(junior.requestedMonthlySalary, 220000);
        expect(junior.salesSkillFit, inInclusiveRange(20, 30));
        expect(junior.interviewScore, greaterThanOrEqualTo(60));
        expect(junior.acceptanceScore, inInclusiveRange(70, 80));
        expect(experienced.generatedApplicants.single.isInexperienced, isFalse);

        final repeated = transaction.execute(
          state: PublicDemoState.aprilStart(),
          medium: PublicDemoRecruitmentMedium.free,
        );
        expect(repeated.generatedApplicants.single.id, junior.id);
        expect(repeated.generatedApplicants.single.name, junior.name);
      },
    );

    test('generation failure is an atomic no-op', () {
      final transaction = PublicDemoRecruitmentTransaction(
        candidateGenerator:
            ({required month, required medium, required count}) => const [],
      );
      final before = PublicDemoState.aprilStart();
      final result = transaction.execute(
        state: before,
        medium: PublicDemoRecruitmentMedium.free,
      );

      expect(
        result.status,
        PublicDemoRecruitmentTransactionStatus.generationFailed,
      );
      expect(result.state, same(before));
    });

    test('preserves bonus, training, growth state and JSON compatibility', () {
      final before = PublicDemoState.aprilStart()
          .selectInternalTraining('eng-01')
          .copyWith(growthAppliedMonths: [4]);
      final result = transaction.execute(
        state: before,
        medium: PublicDemoRecruitmentMedium.free,
      );

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
        final purchased = transaction.execute(
          state: july,
          medium: PublicDemoRecruitmentMedium.engineer,
        );
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
}
