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

  group('recruitment media usage extends to the new months', () {
    test('months 9 through 15 are now valid for recruitment media', () {
      final state = PublicDemoState.aprilStart();
      for (var month = 9; month <= 15; month++) {
        expect(
          state.canUseRecruitmentMediaInMonth(month),
          isTrue,
          reason: 'month $month',
        );
      }
    });

    test('month 16 is still rejected (fiscal year ends at 15)', () {
      final state = PublicDemoState.aprilStart();
      expect(state.canUseRecruitmentMediaInMonth(16), isFalse);
    });

    test('recruitmentMediumUsedMonth round trips for a month 9-15 value', () {
      final used = PublicDemoState.aprilStart().markRecruitmentMediaUsed(13);
      expect(used.recruitmentMediumUsedMonth, 13);
      expect(
        PublicDemoState.fromJson(used.toJson()).recruitmentMediumUsedMonth,
        13,
      );
    });
  });
}
