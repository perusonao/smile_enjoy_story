/// Pure calendar math for Playable 0.3A's "4週=1か月" time system (§3-4).
///
/// The game's fiscal year starts in April; week 1 is April, week-of-month 1.
/// A year is 12 months × 4 weeks = 48 weeks. Everything here is a stateless
/// function of the raw week number so it needs no [GameState] and is easy
/// to unit test.
class GameCalendar {
  const GameCalendar._();

  static const int weeksPerMonth = 4;
  static const int monthsPerYear = 12;
  static const int weeksPerYear = weeksPerMonth * monthsPerYear;

  /// The fiscal year's first calendar month (index into [monthNames]).
  static const int fiscalStartMonthIndex = 3; // 0-based: April

  static const List<String> monthNames = [
    '1月',
    '2月',
    '3月',
    '4月',
    '5月',
    '6月',
    '7月',
    '8月',
    '9月',
    '10月',
    '11月',
    '12月',
  ];

  /// 1-based month-of-year within the fiscal year (1 = April, ..., 12 =
  /// March), for a given (1-based) [week].
  static int monthOfYear(int week) => (((week - 1) ~/ weeksPerMonth) % monthsPerYear) + 1;

  /// 1-based absolute month count since game start (never wraps — used for
  /// AR generatedMonth/dueMonth bookkeeping across multiple years).
  static int absoluteMonth(int week) => ((week - 1) ~/ weeksPerMonth) + 1;

  /// 1-4: which week of its month [week] falls on.
  static int weekOfMonth(int week) => ((week - 1) % weeksPerMonth) + 1;

  /// True on the 4th week of a month — when monthly accounting runs.
  static bool isMonthEnd(int week) => weekOfMonth(week) == weeksPerMonth;

  /// 1-based fiscal year number (year 1 = weeks 1-48).
  static int fiscalYear(int week) => ((week - 1) ~/ weeksPerYear) + 1;

  /// The real-world-style calendar month name for [week] (April-start
  /// fiscal year), e.g. week 1-4 → "4月".
  static String monthName(int week) {
    final calendarMonthIndex = (fiscalStartMonthIndex + monthOfYear(week) - 1) % 12;
    return monthNames[calendarMonthIndex];
  }

  /// A flavor calendar year label for [week] — purely cosmetic, anchored so
  /// the game's first month reads as [startYear] (default 2026).
  static int calendarYear(int week, {int startYear = 2026}) {
    final monthsElapsed = absoluteMonth(week) - 1;
    final calendarMonthIndex = fiscalStartMonthIndex + monthsElapsed;
    return startYear + (calendarMonthIndex ~/ 12);
  }

  /// e.g. "2026年 5月 第3週" (§4).
  static String displayLabel(int week, {int startYear = 2026}) {
    final year = calendarYear(week, startYear: startYear);
    final month = monthName(week);
    final wom = weekOfMonth(week);
    return '$year年 $month 第$wom週';
  }

  /// e.g. "5月末" for a given absolute month number (see [absoluteMonth]) —
  /// used by the Payment Schedule list (§16) to show when an accounts
  /// receivable record is due, without needing exact date math.
  static String monthEndLabel(int absoluteMonth) => '${monthName(absoluteMonth * weeksPerMonth)}末';
}
