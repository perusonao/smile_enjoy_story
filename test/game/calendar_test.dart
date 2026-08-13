import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/game.dart';

void main() {
  group('GameCalendar', () {
    test('4 weeks make a month, 48 weeks make a year', () {
      expect(GameCalendar.weeksPerMonth, 4);
      expect(GameCalendar.weeksPerYear, 48);
    });

    test('weekOfMonth cycles 1-4', () {
      expect(GameCalendar.weekOfMonth(1), 1);
      expect(GameCalendar.weekOfMonth(2), 2);
      expect(GameCalendar.weekOfMonth(3), 3);
      expect(GameCalendar.weekOfMonth(4), 4);
      expect(GameCalendar.weekOfMonth(5), 1);
      expect(GameCalendar.weekOfMonth(48), 4);
    });

    test('isMonthEnd is only true on the 4th week of each month', () {
      expect(GameCalendar.isMonthEnd(3), isFalse);
      expect(GameCalendar.isMonthEnd(4), isTrue);
      expect(GameCalendar.isMonthEnd(7), isFalse);
      expect(GameCalendar.isMonthEnd(8), isTrue);
      expect(GameCalendar.isMonthEnd(48), isTrue);
    });

    test('absoluteMonth counts 1-based months since game start, uncapped by year', () {
      expect(GameCalendar.absoluteMonth(1), 1);
      expect(GameCalendar.absoluteMonth(4), 1);
      expect(GameCalendar.absoluteMonth(5), 2);
      expect(GameCalendar.absoluteMonth(48), 12);
      expect(GameCalendar.absoluteMonth(49), 13); // into year 2
    });

    test('fiscalYear rolls over exactly at week 49', () {
      expect(GameCalendar.fiscalYear(1), 1);
      expect(GameCalendar.fiscalYear(48), 1);
      expect(GameCalendar.fiscalYear(49), 2);
    });

    test('the fiscal year starts in April (§4)', () {
      expect(GameCalendar.monthName(1), '4月');
      expect(GameCalendar.monthName(4), '4月');
      expect(GameCalendar.monthName(5), '5月');
      // Weeks 45-48 land on March, the last month of the fiscal year.
      expect(GameCalendar.monthName(45), '3月');
      expect(GameCalendar.monthName(48), '3月');
    });

    test('displayLabel matches the spec\'s own example: week 7 → "2026年 5月 第3週" (§4)', () {
      expect(GameCalendar.displayLabel(7), '2026年 5月 第3週');
    });

    test('calendarYear advances past December', () {
      expect(GameCalendar.calendarYear(1), 2026); // April 2026
      expect(GameCalendar.calendarYear(36), 2026); // December 2026
      expect(GameCalendar.calendarYear(40), 2027); // January 2027
    });

    test('monthEndLabel names the month an accounts-receivable record is due (§16)', () {
      // Month 2 → weeks 5-8 → May.
      expect(GameCalendar.monthEndLabel(2), '5月末');
    });
  });
}
