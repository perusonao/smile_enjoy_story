/// Cumulative statistics tracked across the whole playthrough, used by the
/// year-end result screen, the bankruptcy screen and the playtest JSON log.
class GameStats {
  /// 累計売上 (accrual-basis, recognized at month-end — Playable 0.3A §9).
  final int cumulativeRevenue;

  /// 累計入金 (actual cash collected against accounts receivable, §13-15).
  final int cumulativeCashCollected;

  final int cumulativeSalary;
  final int cumulativeRent;

  /// otherMonthlyFixedCost only — rent is tracked separately in
  /// [cumulativeRent] so the result/closing screens can show both (§8).
  final int cumulativeFixedCost;
  final int cumulativeRecruitmentCost;
  final int hires;
  final int proposalCount;
  final int projectInterviewCount;
  final int projectInterviewSuccess;
  final int assignmentsStarted;

  /// Sum, over every simulated week, of the number of engineers who were
  /// `waiting` that week (待機延べ週).
  final int waitingWeeks;

  /// Running sum/count of month-end 資金余命 (cash runway, in months)
  /// samples, for the playtest log's `averageCashRunway` (§29). An
  /// unbounded/"safe" runway is capped at [runwaySampleCap] before being
  /// folded in, both so the average stays finite and so it can round-trip
  /// through JSON (which has no `Infinity` literal).
  final double cashRunwaySampleSum;
  final int cashRunwaySampleCount;

  static const double runwaySampleCap = 999.0;

  const GameStats({
    required this.cumulativeRevenue,
    required this.cumulativeCashCollected,
    required this.cumulativeSalary,
    required this.cumulativeRent,
    required this.cumulativeFixedCost,
    required this.cumulativeRecruitmentCost,
    required this.hires,
    required this.proposalCount,
    required this.projectInterviewCount,
    required this.projectInterviewSuccess,
    required this.assignmentsStarted,
    required this.waitingWeeks,
    this.cashRunwaySampleSum = 0,
    this.cashRunwaySampleCount = 0,
  });

  const GameStats.zero()
    : cumulativeRevenue = 0,
      cumulativeCashCollected = 0,
      cumulativeSalary = 0,
      cumulativeRent = 0,
      cumulativeFixedCost = 0,
      cumulativeRecruitmentCost = 0,
      hires = 0,
      proposalCount = 0,
      projectInterviewCount = 0,
      projectInterviewSuccess = 0,
      assignmentsStarted = 0,
      waitingWeeks = 0,
      cashRunwaySampleSum = 0,
      cashRunwaySampleCount = 0;

  /// Mean of every sampled month-end cash-runway reading, or `null` before
  /// the first month has closed.
  double? get averageCashRunwayMonths =>
      cashRunwaySampleCount == 0 ? null : cashRunwaySampleSum / cashRunwaySampleCount;

  /// Returns a copy with one more runway sample folded in (§29).
  GameStats withRunwaySample(double months) {
    final capped = months.isFinite ? months.clamp(0, runwaySampleCap) : runwaySampleCap;
    return copyWith(
      cashRunwaySampleSum: cashRunwaySampleSum + capped,
      cashRunwaySampleCount: cashRunwaySampleCount + 1,
    );
  }

  int get cumulativeExpense =>
      cumulativeSalary +
      cumulativeRent +
      cumulativeFixedCost +
      cumulativeRecruitmentCost;

  /// 営業利益 (accounting profit): recognized revenue minus recognized
  /// expense — deliberately independent of actual cash movement (§20).
  int get cumulativeProfit => cumulativeRevenue - cumulativeExpense;

  GameStats copyWith({
    int? cumulativeRevenue,
    int? cumulativeCashCollected,
    int? cumulativeSalary,
    int? cumulativeRent,
    int? cumulativeFixedCost,
    int? cumulativeRecruitmentCost,
    int? hires,
    int? proposalCount,
    int? projectInterviewCount,
    int? projectInterviewSuccess,
    int? assignmentsStarted,
    int? waitingWeeks,
    double? cashRunwaySampleSum,
    int? cashRunwaySampleCount,
  }) {
    return GameStats(
      cumulativeRevenue: cumulativeRevenue ?? this.cumulativeRevenue,
      cumulativeCashCollected:
          cumulativeCashCollected ?? this.cumulativeCashCollected,
      cumulativeSalary: cumulativeSalary ?? this.cumulativeSalary,
      cumulativeRent: cumulativeRent ?? this.cumulativeRent,
      cumulativeFixedCost: cumulativeFixedCost ?? this.cumulativeFixedCost,
      cumulativeRecruitmentCost:
          cumulativeRecruitmentCost ?? this.cumulativeRecruitmentCost,
      hires: hires ?? this.hires,
      proposalCount: proposalCount ?? this.proposalCount,
      projectInterviewCount:
          projectInterviewCount ?? this.projectInterviewCount,
      projectInterviewSuccess:
          projectInterviewSuccess ?? this.projectInterviewSuccess,
      assignmentsStarted: assignmentsStarted ?? this.assignmentsStarted,
      waitingWeeks: waitingWeeks ?? this.waitingWeeks,
      cashRunwaySampleSum: cashRunwaySampleSum ?? this.cashRunwaySampleSum,
      cashRunwaySampleCount:
          cashRunwaySampleCount ?? this.cashRunwaySampleCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'cumulativeRevenue': cumulativeRevenue,
    'cumulativeCashCollected': cumulativeCashCollected,
    'cumulativeSalary': cumulativeSalary,
    'cumulativeRent': cumulativeRent,
    'cumulativeFixedCost': cumulativeFixedCost,
    'cumulativeRecruitmentCost': cumulativeRecruitmentCost,
    'hires': hires,
    'proposalCount': proposalCount,
    'projectInterviewCount': projectInterviewCount,
    'projectInterviewSuccess': projectInterviewSuccess,
    'assignmentsStarted': assignmentsStarted,
    'waitingWeeks': waitingWeeks,
    'cashRunwaySampleSum': cashRunwaySampleSum,
    'cashRunwaySampleCount': cashRunwaySampleCount,
  };

  factory GameStats.fromJson(Map<String, dynamic> json) => GameStats(
    cumulativeRevenue: json['cumulativeRevenue'] as int,
    cumulativeCashCollected: json['cumulativeCashCollected'] as int? ?? 0,
    cumulativeSalary: json['cumulativeSalary'] as int,
    cumulativeRent: json['cumulativeRent'] as int? ?? 0,
    cumulativeFixedCost: json['cumulativeFixedCost'] as int,
    cumulativeRecruitmentCost: json['cumulativeRecruitmentCost'] as int,
    hires: json['hires'] as int,
    proposalCount: json['proposalCount'] as int,
    projectInterviewCount: json['projectInterviewCount'] as int,
    projectInterviewSuccess: json['projectInterviewSuccess'] as int,
    assignmentsStarted: json['assignmentsStarted'] as int,
    waitingWeeks: json['waitingWeeks'] as int,
    cashRunwaySampleSum: (json['cashRunwaySampleSum'] as num?)?.toDouble() ?? 0,
    cashRunwaySampleCount: json['cashRunwaySampleCount'] as int? ?? 0,
  );
}
