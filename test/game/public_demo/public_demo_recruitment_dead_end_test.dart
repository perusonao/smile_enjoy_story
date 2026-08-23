import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_transaction.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

/// 12MONTH-3-FIX1 P1-2: 12MONTH-3 widened recruitment media's valid month
/// range to 4-15, but no UI past month 5 can ever process a generated
/// applicant — so a September-March medium purchase was a paid dead end
/// (Codex finding). Reverted the domain range to the pre-12MONTH-3 4-8
/// (see public_demo_state.dart's `_normalizedRecruitmentMediaMonth`); these
/// tests pin that fix at the transaction layer, the actual point where cash
/// would otherwise have been spent for nothing.
void main() {
  const transaction = PublicDemoRecruitmentTransaction();

  group('recruitment media in months without a processing UI (P1-2)', () {
    test('A: paid recruitment is rejected for every month 9 through 15', () {
      for (var month = 9; month <= 15; month++) {
        final before = PublicDemoState.aprilStart().copyWith(month: month);
        final result = transaction.execute(
          state: before,
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
          medium: PublicDemoRecruitmentMedium.engineer,
        );
        expect(
          result.state.cash,
          before.cash,
          reason: 'month $month must not spend cash',
        );
        expect(result.chargedAmount, 0, reason: 'month $month');
      }
    });

    test('C: no applicant is generated for a rejected month-9-15 attempt', () {
      for (var month = 9; month <= 15; month++) {
        final before = PublicDemoState.aprilStart().copyWith(month: month);
        final result = transaction.execute(
          state: before,
          medium: PublicDemoRecruitmentMedium.engineer,
        );
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
        final result = transaction.execute(
          state: before,
          medium: PublicDemoRecruitmentMedium.free,
        );
        expect(result.isSuccess, isFalse, reason: 'month $month');
        expect(result.generatedApplicants, isEmpty, reason: 'month $month');
      }
    });

    test('D: months 4 through 8 are unaffected (no regression)', () {
      for (var month = 4; month <= 8; month++) {
        final before = PublicDemoState.aprilStart().copyWith(month: month);
        final result = transaction.execute(
          state: before,
          medium: PublicDemoRecruitmentMedium.free,
        );
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
