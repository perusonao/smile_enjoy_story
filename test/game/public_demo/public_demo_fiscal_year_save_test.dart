import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';

/// 12MONTH-3: month's valid range extends from 4-8 to 4-15, and a new
/// [PublicDemoState.fiscalYearCompleted] field is added. Neither change may
/// break loading a save created before this change, and both new-range
/// values must round trip.
void main() {
  group('month JSON round trip across the extended range', () {
    test('months 13, 14, and 15 round trip', () {
      for (final month in [13, 14, 15]) {
        final state = PublicDemoState.aprilStart().copyWith(month: month);
        final loaded = PublicDemoState.fromJson(state.toJson());
        expect(loaded.month, month);
      }
    });

    test('old-save months 4 through 8 still round trip (regression)', () {
      for (var month = 4; month <= 8; month++) {
        final state = PublicDemoState.aprilStart().copyWith(month: month);
        final loaded = PublicDemoState.fromJson(state.toJson());
        expect(loaded.month, month);
      }
    });
  });

  group('fiscalYearCompleted JSON round trip', () {
    test('true round trips', () {
      final state = PublicDemoState.aprilStart().copyWith(
        month: 15,
        fiscalYearCompleted: true,
      );
      expect(
        PublicDemoState.fromJson(state.toJson()).fiscalYearCompleted,
        isTrue,
      );
    });

    test('false round trips', () {
      final state = PublicDemoState.aprilStart();
      expect(
        PublicDemoState.fromJson(state.toJson()).fiscalYearCompleted,
        isFalse,
      );
    });

    test('an old save with no fiscalYearCompleted key normalizes to false', () {
      final old = PublicDemoState.aprilStart().toJson()
        ..remove('fiscalYearCompleted');
      expect(PublicDemoState.fromJson(old).fiscalYearCompleted, isFalse);
    });

    test('a malformed fiscalYearCompleted value normalizes to false', () {
      final malformed = PublicDemoState.aprilStart().toJson()
        ..['fiscalYearCompleted'] = 'yes';
      expect(PublicDemoState.fromJson(malformed).fiscalYearCompleted, isFalse);
    });
  });

  group('recruitment media stays scoped to 4-8 (12MONTH-3-FIX1 P1-2)', () {
    // 12MONTH-3 briefly widened this to 4-15, but no UI past month 5 can
    // process a generated applicant, so a widened *domain* range let a
    // player pay for a medium in September-March with no way to ever act
    // on the result — a paid dead end (Codex P1-2). Reverted to the
    // pre-12MONTH-3 4-8 range; see SES_12MONTH-3_P1_Fixes_Result.md.
    test('months 9 through 15 are rejected again (dead-end fix)', () {
      final state = PublicDemoState.aprilStart();
      for (var month = 9; month <= 15; month++) {
        expect(
          state.canUseRecruitmentMediaInMonth(month),
          isFalse,
          reason: 'month $month',
        );
      }
    });

    test('month 16 is still rejected (fiscal year ends at 15)', () {
      final state = PublicDemoState.aprilStart();
      expect(state.canUseRecruitmentMediaInMonth(16), isFalse);
    });

    test('month 8 (the pre-12MONTH-3 upper bound) is still valid', () {
      final state = PublicDemoState.aprilStart();
      expect(state.canUseRecruitmentMediaInMonth(8), isTrue);
    });

    test('markRecruitmentMediaUsed for a 9-15 value is a no-op (matches the '
        'reverted 4-8 range)', () {
      final start = PublicDemoState.aprilStart();
      final used = start.markRecruitmentMediaUsed(13);
      expect(used, same(start));
      expect(used.recruitmentMediumUsedMonth, isNull);
    });
  });
}
