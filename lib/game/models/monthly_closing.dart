/// A snapshot of one month-end accounting run, for the Monthly Closing UI
/// (Playable 0.3A §20) and the playtest log/save history.
class MonthlyClosing {
  /// Absolute month number (see [GameCalendar.absoluteMonth]).
  final int month;

  /// The week number the closing ran on (always a month-end week).
  final int week;

  /// Cosmetic calendar label, e.g. "2026年 4月".
  final String label;

  final int projectRevenue;
  final int accountsReceivableGenerated;
  final int cashCollected;
  final int salaryPaid;
  final int rentPaid;
  final int otherFixedCost;
  final int recruitmentCost;

  /// 会計上利益 = projectRevenue - salaryPaid - rentPaid - otherFixedCost -
  /// recruitmentCost. Deliberately independent of [cashDelta].
  final int accountingProfit;

  /// Actual change in cash this month: cashCollected - salaryPaid - rentPaid
  /// - otherFixedCost - recruitmentCost.
  final int cashDelta;

  final int cashBefore;
  final int cashAfter;

  const MonthlyClosing({
    required this.month,
    required this.week,
    required this.label,
    required this.projectRevenue,
    required this.accountsReceivableGenerated,
    required this.cashCollected,
    required this.salaryPaid,
    required this.rentPaid,
    required this.otherFixedCost,
    required this.recruitmentCost,
    required this.accountingProfit,
    required this.cashDelta,
    required this.cashBefore,
    required this.cashAfter,
  });

  Map<String, dynamic> toJson() => {
    'month': month,
    'week': week,
    'label': label,
    'projectRevenue': projectRevenue,
    'accountsReceivableGenerated': accountsReceivableGenerated,
    'cashCollected': cashCollected,
    'salaryPaid': salaryPaid,
    'rentPaid': rentPaid,
    'otherFixedCost': otherFixedCost,
    'recruitmentCost': recruitmentCost,
    'accountingProfit': accountingProfit,
    'cashDelta': cashDelta,
    'cashBefore': cashBefore,
    'cashAfter': cashAfter,
  };

  factory MonthlyClosing.fromJson(Map<String, dynamic> json) =>
      MonthlyClosing(
        month: json['month'] as int,
        week: json['week'] as int,
        label: json['label'] as String,
        projectRevenue: json['projectRevenue'] as int,
        accountsReceivableGenerated: json['accountsReceivableGenerated'] as int,
        cashCollected: json['cashCollected'] as int,
        salaryPaid: json['salaryPaid'] as int,
        rentPaid: json['rentPaid'] as int,
        otherFixedCost: json['otherFixedCost'] as int,
        recruitmentCost: json['recruitmentCost'] as int,
        accountingProfit: json['accountingProfit'] as int,
        cashDelta: json['cashDelta'] as int,
        cashBefore: json['cashBefore'] as int,
        cashAfter: json['cashAfter'] as int,
      );
}
