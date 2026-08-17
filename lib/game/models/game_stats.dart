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

  /// Cumulative count of [GameEngine.postRecruitmentMedia] calls across the
  /// whole playthrough (the March founding listing included) — deliberately
  /// *not* `state.listings.length`, which only ever holds *currently active*
  /// listings (`GameEngine.advanceWeek` replaces it with the active-only
  /// filtered set every week, §3 求人掲載終了の検出). A milestone gated on
  /// "posted a second listing" that read `state.listings.length` directly
  /// would silently un-satisfy itself the moment the March listing's 4-week
  /// duration expired, well before Beginner Mode's own recruitment unlock —
  /// found via a real-UI Playwright run (Phase 3A UX review follow-up),
  /// which no unit test caught because unit tests construct `listings`
  /// directly instead of going through the engine's weekly pruning.
  final int recruitmentListingsPosted;

  final int hires;
  final int proposalCount;
  final int projectInterviewCount;
  final int projectInterviewSuccess;
  final int assignmentsStarted;
  final int parallelProposalPeak;
  final int screeningPassed;
  final int upperCompanyInterviewPassed;
  final int technicalInterviewPassed;
  final int clientInterviewPassed;
  final int finalInterviewPassed;
  final int offersReceived;
  final int offersAccepted;
  final int offersDeclined;
  final int offersExpired;
  final int proposalCancelledByOtherAssignment;
  final int selectionWeeksTotal;
  final int completedSelections;

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
    this.recruitmentListingsPosted = 0,
    required this.hires,
    required this.proposalCount,
    required this.projectInterviewCount,
    required this.projectInterviewSuccess,
    required this.assignmentsStarted,
    this.parallelProposalPeak = 0,
    this.screeningPassed = 0,
    this.upperCompanyInterviewPassed = 0,
    this.technicalInterviewPassed = 0,
    this.clientInterviewPassed = 0,
    this.finalInterviewPassed = 0,
    this.offersReceived = 0,
    this.offersAccepted = 0,
    this.offersDeclined = 0,
    this.offersExpired = 0,
    this.proposalCancelledByOtherAssignment = 0,
    this.selectionWeeksTotal = 0,
    this.completedSelections = 0,
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
      recruitmentListingsPosted = 0,
      hires = 0,
      proposalCount = 0,
      projectInterviewCount = 0,
      projectInterviewSuccess = 0,
      assignmentsStarted = 0,
      parallelProposalPeak = 0,
      screeningPassed = 0,
      upperCompanyInterviewPassed = 0,
      technicalInterviewPassed = 0,
      clientInterviewPassed = 0,
      finalInterviewPassed = 0,
      offersReceived = 0,
      offersAccepted = 0,
      offersDeclined = 0,
      offersExpired = 0,
      proposalCancelledByOtherAssignment = 0,
      selectionWeeksTotal = 0,
      completedSelections = 0,
      waitingWeeks = 0,
      cashRunwaySampleSum = 0,
      cashRunwaySampleCount = 0;

  /// Mean of every sampled month-end cash-runway reading, or `null` before
  /// the first month has closed.
  double? get averageCashRunwayMonths => cashRunwaySampleCount == 0
      ? null
      : cashRunwaySampleSum / cashRunwaySampleCount;

  /// Returns a copy with one more runway sample folded in (§29).
  GameStats withRunwaySample(double months) {
    final capped = months.isFinite
        ? months.clamp(0, runwaySampleCap)
        : runwaySampleCap;
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
  double get averageSelectionWeeks =>
      completedSelections == 0 ? 0 : selectionWeeksTotal / completedSelections;

  GameStats copyWith({
    int? cumulativeRevenue,
    int? cumulativeCashCollected,
    int? cumulativeSalary,
    int? cumulativeRent,
    int? cumulativeFixedCost,
    int? cumulativeRecruitmentCost,
    int? recruitmentListingsPosted,
    int? hires,
    int? proposalCount,
    int? projectInterviewCount,
    int? projectInterviewSuccess,
    int? assignmentsStarted,
    int? parallelProposalPeak,
    int? screeningPassed,
    int? upperCompanyInterviewPassed,
    int? technicalInterviewPassed,
    int? clientInterviewPassed,
    int? finalInterviewPassed,
    int? offersReceived,
    int? offersAccepted,
    int? offersDeclined,
    int? offersExpired,
    int? proposalCancelledByOtherAssignment,
    int? selectionWeeksTotal,
    int? completedSelections,
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
      recruitmentListingsPosted:
          recruitmentListingsPosted ?? this.recruitmentListingsPosted,
      hires: hires ?? this.hires,
      proposalCount: proposalCount ?? this.proposalCount,
      projectInterviewCount:
          projectInterviewCount ?? this.projectInterviewCount,
      projectInterviewSuccess:
          projectInterviewSuccess ?? this.projectInterviewSuccess,
      assignmentsStarted: assignmentsStarted ?? this.assignmentsStarted,
      parallelProposalPeak: parallelProposalPeak ?? this.parallelProposalPeak,
      screeningPassed: screeningPassed ?? this.screeningPassed,
      upperCompanyInterviewPassed:
          upperCompanyInterviewPassed ?? this.upperCompanyInterviewPassed,
      technicalInterviewPassed:
          technicalInterviewPassed ?? this.technicalInterviewPassed,
      clientInterviewPassed:
          clientInterviewPassed ?? this.clientInterviewPassed,
      finalInterviewPassed: finalInterviewPassed ?? this.finalInterviewPassed,
      offersReceived: offersReceived ?? this.offersReceived,
      offersAccepted: offersAccepted ?? this.offersAccepted,
      offersDeclined: offersDeclined ?? this.offersDeclined,
      offersExpired: offersExpired ?? this.offersExpired,
      proposalCancelledByOtherAssignment:
          proposalCancelledByOtherAssignment ??
          this.proposalCancelledByOtherAssignment,
      selectionWeeksTotal: selectionWeeksTotal ?? this.selectionWeeksTotal,
      completedSelections: completedSelections ?? this.completedSelections,
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
    'recruitmentListingsPosted': recruitmentListingsPosted,
    'hires': hires,
    'proposalCount': proposalCount,
    'projectInterviewCount': projectInterviewCount,
    'projectInterviewSuccess': projectInterviewSuccess,
    'assignmentsStarted': assignmentsStarted,
    'parallelProposalPeak': parallelProposalPeak,
    'screeningPassed': screeningPassed,
    'upperCompanyInterviewPassed': upperCompanyInterviewPassed,
    'technicalInterviewPassed': technicalInterviewPassed,
    'clientInterviewPassed': clientInterviewPassed,
    'finalInterviewPassed': finalInterviewPassed,
    'offersReceived': offersReceived,
    'offersAccepted': offersAccepted,
    'offersDeclined': offersDeclined,
    'offersExpired': offersExpired,
    'proposalCancelledByOtherAssignment': proposalCancelledByOtherAssignment,
    'selectionWeeksTotal': selectionWeeksTotal,
    'completedSelections': completedSelections,
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
    recruitmentListingsPosted: json['recruitmentListingsPosted'] as int? ?? 0,
    hires: json['hires'] as int,
    proposalCount: json['proposalCount'] as int,
    projectInterviewCount: json['projectInterviewCount'] as int,
    projectInterviewSuccess: json['projectInterviewSuccess'] as int,
    assignmentsStarted: json['assignmentsStarted'] as int,
    parallelProposalPeak: json['parallelProposalPeak'] as int? ?? 0,
    screeningPassed: json['screeningPassed'] as int? ?? 0,
    upperCompanyInterviewPassed:
        json['upperCompanyInterviewPassed'] as int? ?? 0,
    technicalInterviewPassed: json['technicalInterviewPassed'] as int? ?? 0,
    clientInterviewPassed: json['clientInterviewPassed'] as int? ?? 0,
    finalInterviewPassed: json['finalInterviewPassed'] as int? ?? 0,
    offersReceived: json['offersReceived'] as int? ?? 0,
    offersAccepted: json['offersAccepted'] as int? ?? 0,
    offersDeclined: json['offersDeclined'] as int? ?? 0,
    offersExpired: json['offersExpired'] as int? ?? 0,
    proposalCancelledByOtherAssignment:
        json['proposalCancelledByOtherAssignment'] as int? ?? 0,
    selectionWeeksTotal: json['selectionWeeksTotal'] as int? ?? 0,
    completedSelections: json['completedSelections'] as int? ?? 0,
    waitingWeeks: json['waitingWeeks'] as int,
    cashRunwaySampleSum: (json['cashRunwaySampleSum'] as num?)?.toDouble() ?? 0,
    cashRunwaySampleCount: json['cashRunwaySampleCount'] as int? ?? 0,
  );
}
