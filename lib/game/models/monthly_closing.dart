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
  /// recruitmentCost. Deliberately independent of [cashDelta]/
  /// [monthCashMovement].
  final int accountingProfit;

  /// Cash movement *at this month-end settlement step only*: cashCollected -
  /// salaryPaid - rentPaid - otherFixedCost. Deliberately excludes
  /// [recruitmentCost] (Playable 0.4C.2 §2 fix) — recruitment-listing cash
  /// already left the company the moment the listing was posted
  /// ([GameEngine.postRecruitmentMedia] deducts it immediately, well before
  /// month-end), so subtracting it again here would double-charge the same
  /// yen.
  ///
  /// This is an internal/reporting breakdown value, not a player-facing
  /// "this month's cash change" figure — a UI that wants to show 現金増減
  /// (the whole month's actual cash movement, including recruitment spend
  /// paid earlier in the month) must use [monthCashMovement] instead
  /// (Issue #12 P2: [cashDelta] alone was being shown under a 現金増減 label
  /// in two places even though it silently excluded recruitment spend that
  /// had already left the bank that same month).
  final int cashDelta;

  /// The actual whole-month change in cash: [cashAfter] - [cashBefore],
  /// which equals `cashDelta - recruitmentCost` (recruitment spend already
  /// left the bank earlier in the month, so it still counts once against
  /// the month's total even though [cashDelta] excludes it). This is the
  /// value a 現金増減 label should show (Issue #12 P2).
  final int monthCashMovement;

  /// Cash at the start of this month, *before* any of this month's
  /// recruitment-media spend or month-end settlement — i.e. [cashAfter] -
  /// [monthCashMovement]. Not simply "cash right before this settlement
  /// step ran", which would already have this month's recruitment spend
  /// baked in and silently start the story mid-month (Issue #12 P2).
  final int cashBefore;

  /// Actual cash right after this month-end settlement — the real,
  /// unambiguous ending balance for the month.
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
    required this.monthCashMovement,
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
    'monthCashMovement': monthCashMovement,
    'cashBefore': cashBefore,
    'cashAfter': cashAfter,
  };

  factory MonthlyClosing.fromJson(Map<String, dynamic> json) {
    final cashDelta = json['cashDelta'] as int;
    final recruitmentCost = json['recruitmentCost'] as int;
    return MonthlyClosing(
      month: json['month'] as int,
      week: json['week'] as int,
      label: json['label'] as String,
      projectRevenue: json['projectRevenue'] as int,
      accountsReceivableGenerated: json['accountsReceivableGenerated'] as int,
      cashCollected: json['cashCollected'] as int,
      salaryPaid: json['salaryPaid'] as int,
      rentPaid: json['rentPaid'] as int,
      otherFixedCost: json['otherFixedCost'] as int,
      recruitmentCost: recruitmentCost,
      accountingProfit: json['accountingProfit'] as int,
      cashDelta: cashDelta,
      // Older saves predate this field (Issue #12 P2) — derive it from the
      // same relationship [GameEngine.advanceWeek] uses when computing it.
      monthCashMovement:
          json['monthCashMovement'] as int? ?? (cashDelta - recruitmentCost),
      cashBefore: json['cashBefore'] as int,
      cashAfter: json['cashAfter'] as int,
    );
  }
}
