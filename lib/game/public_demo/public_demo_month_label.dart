/// Converts a Public Demo internal month number into its Japanese calendar
/// label.
///
/// Internal months run 4-15: April (4) through December (12) map to
/// themselves, and January-March of the following year are represented as
/// 13-15 so every domain comparison (`month <= 14`, `month == 15`, ...) stays
/// simple `int` arithmetic. This function is the single place that converts
/// back to a calendar month for display — callers must never show the raw
/// 13/14/15 value directly.
String publicDemoMonthLabel(int month) {
  final calendarMonth = month > 12 ? month - 12 : month;
  return '$calendarMonth月';
}
