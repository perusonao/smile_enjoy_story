import 'public_demo_engineer_runtime.dart';
import 'public_demo_growth_engine.dart';
import 'public_demo_monthly_growth.dart';
import 'public_demo_recruitment.dart';
import 'public_demo_summer_bonus_plan.dart';
import 'public_demo_summer_bonus_payment.dart';

/// Minimal state for Public Demo 0.1 MVP-A.
class PublicDemoState {
  factory PublicDemoState({
    required int month,
    required int cash,
    required int engineerCount,
    required int adminCount,
    required int salesCapacity,
    required int salesUsed,
    required int engineersWaiting,
    required int engineersAssigned,
    List<String> joinedApplicantIds = const [],
    List<PublicDemoEngineerRuntime> engineerRuntimes =
        publicDemoInitialEngineerRuntimes,
    List<PublicDemoMonthlyGrowth> latestGrowthResults = const [],
    List<int> growthAppliedMonths = const [],
    Map<String, PublicDemoGrowthSource> trainingSelections = const {},
    PublicDemoSummerBonusPlan summerBonusSelection =
        PublicDemoSummerBonusPlan.none,
    bool summerBonusPaid = false,
    int? summerBonusPaidMonth,
    int? summerBonusPaidAmount,
    int? recruitmentMediumUsedMonth,
  }) => PublicDemoState._(
    month: month,
    cash: cash,
    engineerCount: engineerCount,
    adminCount: adminCount,
    salesCapacity: salesCapacity,
    salesUsed: salesUsed,
    engineersWaiting: engineersWaiting,
    engineersAssigned: engineersAssigned,
    joinedApplicantIds: joinedApplicantIds,
    engineerRuntimes: engineerRuntimes,
    latestGrowthResults: latestGrowthResults,
    growthAppliedMonths: growthAppliedMonths,
    trainingSelections: _trainingSelectionsOnly(trainingSelections),
    summerBonusSelection: summerBonusSelection,
    summerBonusPaid: _hasValidSummerBonusPayment(
      paid: summerBonusPaid,
      month: summerBonusPaidMonth,
      amount: summerBonusPaidAmount,
    ),
    summerBonusPaidMonth:
        _hasValidSummerBonusPayment(
          paid: summerBonusPaid,
          month: summerBonusPaidMonth,
          amount: summerBonusPaidAmount,
        )
        ? summerBonusPaidMonth
        : null,
    summerBonusPaidAmount:
        _hasValidSummerBonusPayment(
          paid: summerBonusPaid,
          month: summerBonusPaidMonth,
          amount: summerBonusPaidAmount,
        )
        ? summerBonusPaidAmount
        : null,
    recruitmentMediumUsedMonth: _normalizedRecruitmentMediaMonth(
      recruitmentMediumUsedMonth,
    ),
  );

  const PublicDemoState._({
    required this.month,
    required this.cash,
    required this.engineerCount,
    required this.adminCount,
    required this.salesCapacity,
    required this.salesUsed,
    required this.engineersWaiting,
    required this.engineersAssigned,
    required this.joinedApplicantIds,
    required this.engineerRuntimes,
    required this.latestGrowthResults,
    required this.growthAppliedMonths,
    required this.trainingSelections,
    required this.summerBonusSelection,
    required this.summerBonusPaid,
    required this.summerBonusPaidMonth,
    required this.summerBonusPaidAmount,
    required this.recruitmentMediumUsedMonth,
  });

  factory PublicDemoState.aprilStart() => PublicDemoState(
    month: 4,
    cash: 3000000,
    engineerCount: 2,
    adminCount: 1,
    salesCapacity: 4,
    salesUsed: 0,
    engineersWaiting: 2,
    engineersAssigned: 0,
  );
  final int month,
      cash,
      engineerCount,
      adminCount,
      salesCapacity,
      salesUsed,
      engineersWaiting,
      engineersAssigned;
  final List<String> joinedApplicantIds;

  /// Actual employee capabilities. Assignments only own project conditions.
  final List<PublicDemoEngineerRuntime> engineerRuntimes;

  /// Most recently closed month's results for EG-4.  Results are historical
  /// facts, not UI text or a prompt to recalculate growth.
  final List<PublicDemoMonthlyGrowth> latestGrowthResults;

  /// Month numbers whose growth has already been applied.  This makes a
  /// repeated month-end command a no-op even outside the normal UI flow.
  final List<int> growthAppliedMonths;

  /// Selected training for each engineer. Values are always training sources,
  /// never assignment or waiting states.
  final Map<String, PublicDemoGrowthSource> trainingSelections;

  /// The player's intended July summer bonus. Selection and payment are
  /// deliberately separate: BONUS-2A will calculate and deduct the payment.
  final PublicDemoSummerBonusPlan summerBonusSelection;
  final bool summerBonusPaid;
  final int? summerBonusPaidMonth;
  final int? summerBonusPaidAmount;

  /// The one month in which the company used a recruitment medium.
  ///
  /// Public Demo 0.1 only needs the latest use because a medium may be used
  /// once per company per month. JOB-2 owns the transaction that calls this.
  final int? recruitmentMediumUsedMonth;

  static bool _hasValidSummerBonusPayment({
    required bool paid,
    required int? month,
    required int? amount,
  }) => paid && month == 7 && amount != null && amount >= 0;

  static int? _normalizedRecruitmentMediaMonth(int? month) =>
      month != null && month >= 4 && month <= 8 ? month : null;

  static Map<String, PublicDemoGrowthSource> _trainingSelectionsOnly(
    Map<String, PublicDemoGrowthSource> selections,
  ) => Map.unmodifiable({
    for (final entry in selections.entries)
      if (_isTrainingSource(entry.value)) entry.key: entry.value,
  });

  static bool _isTrainingSource(PublicDemoGrowthSource source) =>
      source == PublicDemoGrowthSource.internalTraining ||
      source == PublicDemoGrowthSource.externalTraining;

  int get salesRemaining => salesCapacity - salesUsed;

  bool canUseRecruitmentMediaInMonth(int month) =>
      _normalizedRecruitmentMediaMonth(month) != null &&
      recruitmentMediumUsedMonth != month;

  /// Records only the company-wide monthly usage guard. It deliberately does
  /// not select a medium, charge cash, or generate applicants.
  PublicDemoState markRecruitmentMediaUsed(int month) {
    if (!canUseRecruitmentMediaInMonth(month)) return this;
    return copyWith(recruitmentMediumUsedMonth: month);
  }

  PublicDemoState selectInternalTraining(String engineerId) =>
      _selectTraining(engineerId, PublicDemoGrowthSource.internalTraining);

  PublicDemoState selectExternalTraining(String engineerId) =>
      _selectTraining(engineerId, PublicDemoGrowthSource.externalTraining);

  PublicDemoState _selectTraining(
    String engineerId,
    PublicDemoGrowthSource source,
  ) =>
      copyWith(trainingSelections: {...trainingSelections, engineerId: source});

  PublicDemoState cancelTraining(String engineerId) => copyWith(
    trainingSelections: {
      for (final entry in trainingSelections.entries)
        if (entry.key != engineerId) entry.key: entry.value,
    },
  );

  /// Updates the intended bonus without changing cash, salary, or growth.
  /// Once paid, the historical decision is immutable.
  PublicDemoState selectSummerBonus(PublicDemoSummerBonusPlan plan) {
    if (summerBonusPaid || plan == summerBonusSelection) return this;
    return copyWith(summerBonusSelection: plan);
  }

  /// Records a completed July payment without applying any cash movement.
  /// BONUS-2A must compose this with its accounting transaction.
  PublicDemoState markSummerBonusPaid({
    required int month,
    required int amount,
  }) {
    if (summerBonusPaid || month != 7 || amount < 0) return this;
    return copyWith(
      summerBonusPaid: true,
      summerBonusPaidMonth: month,
      summerBonusPaidAmount: amount,
    );
  }

  PublicDemoState useSalesSlot() {
    if (salesRemaining <= 0) return this;
    return copyWith(salesUsed: salesUsed + 1);
  }

  PublicDemoState advanceToMay({
    required int monthlyExpenses,
    required int orderedEngineers,
  }) {
    if (month != 4) return this;
    final assigned = orderedEngineers.clamp(0, engineerCount);
    return copyWith(
      month: 5,
      cash: cash - monthlyExpenses,
      salesUsed: 0,
      engineersAssigned: assigned,
      engineersWaiting: engineerCount - assigned,
    );
  }

  PublicDemoState advanceToJune({
    required int monthlyExpenses,
    required int acceptedHires,
    required int hiredWithOrders,
    List<String> joinedApplicantIds = const [],
  }) {
    if (month != 5) return this;
    final hires = acceptedHires < 0 ? 0 : acceptedHires;
    final ordered = hiredWithOrders.clamp(0, hires);
    return copyWith(
      month: 6,
      cash: cash - monthlyExpenses,
      salesUsed: 0,
      engineerCount: engineerCount + hires,
      engineersAssigned: engineersAssigned + ordered,
      engineersWaiting: engineersWaiting + (hires - ordered),
      joinedApplicantIds: [
        ...this.joinedApplicantIds,
        ...joinedApplicantIds.where(
          (id) => !this.joinedApplicantIds.contains(id),
        ),
      ],
    );
  }

  PublicDemoState advanceToJuly({
    required int monthlyExpenses,
    required int assignedInJuly,
  }) {
    if (month != 6) return this;
    final assigned = assignedInJuly.clamp(0, engineerCount);
    return copyWith(
      month: 7,
      cash: cash - monthlyExpenses,
      salesUsed: 0,
      engineersAssigned: assigned,
      engineersWaiting: engineerCount - assigned,
    );
  }

  /// Closes July atomically: ordinary monthly expenses and the selected summer
  /// bonus either both settle, or neither state nor cash changes.
  PublicDemoSummerBonusPaymentResult advanceToAugust({
    required int monthlyExpenses,
    required Iterable<PublicDemoApplicant> applicants,
  }) => PublicDemoSummerBonusPayment.closeJuly(
    state: this,
    monthlyExpenses: monthlyExpenses,
    applicants: applicants,
  );

  PublicDemoEngineerRuntime runtimeFor(String engineerId) => engineerRuntimes
      .firstWhere((runtime) => runtime.engineerId == engineerId);

  /// Closes growth for the current month exactly once, before its state is
  /// advanced. Assignment IDs and morale are supplied by the live Public Demo
  /// workflow because those transient workflow objects own that information.
  ///
  /// The current demo assignment model has no reliable industry field, so this
  /// method intentionally does not invent one; industry experience remains 0.
  PublicDemoState applyMonthlyGrowth({
    required Set<String> assignedEngineerIds,
    required Map<String, int> moraleByEngineerId,
  }) {
    if (growthAppliedMonths.contains(month)) return this;
    final results = <PublicDemoMonthlyGrowth>[];
    final runtimes = [
      for (final runtime in engineerRuntimes)
        () {
          final source = assignedEngineerIds.contains(runtime.engineerId)
              ? PublicDemoGrowthSource.assignment
              : trainingSelections[runtime.engineerId] ??
                    PublicDemoGrowthSource.waiting;
          final result = PublicDemoGrowthEngine.calculate(
            runtime,
            PublicDemoGrowthRequest(
              source: source,
              morale: moraleByEngineerId[runtime.engineerId] ?? 50,
            ),
          );
          results.add(
            PublicDemoMonthlyGrowth(
              engineerId: runtime.engineerId,
              source: source,
              primaryLanguage: runtime.primaryLanguage,
              capabilityBefore: result.capabilityChange.before,
              capabilityAfter: result.capabilityChange.after,
              actualExperienceMonthsDelta: result.actualExperienceMonthsDelta,
              industryExperienceMonthsDelta:
                  result.industryExperienceMonthsDelta,
            ),
          );
          return result.after;
        }(),
    ];
    return copyWith(
      engineerRuntimes: runtimes,
      latestGrowthResults: results,
      growthAppliedMonths: [...growthAppliedMonths, month],
      trainingSelections: const {},
    );
  }

  PublicDemoState copyWith({
    int? month,
    int? cash,
    int? engineerCount,
    int? adminCount,
    int? salesCapacity,
    int? salesUsed,
    int? engineersWaiting,
    int? engineersAssigned,
    List<String>? joinedApplicantIds,
    List<PublicDemoEngineerRuntime>? engineerRuntimes,
    List<PublicDemoMonthlyGrowth>? latestGrowthResults,
    List<int>? growthAppliedMonths,
    Map<String, PublicDemoGrowthSource>? trainingSelections,
    PublicDemoSummerBonusPlan? summerBonusSelection,
    bool? summerBonusPaid,
    Object? summerBonusPaidMonth = _unset,
    Object? summerBonusPaidAmount = _unset,
    Object? recruitmentMediumUsedMonth = _unset,
  }) => PublicDemoState(
    month: month ?? this.month,
    cash: cash ?? this.cash,
    engineerCount: engineerCount ?? this.engineerCount,
    adminCount: adminCount ?? this.adminCount,
    salesCapacity: salesCapacity ?? this.salesCapacity,
    salesUsed: salesUsed ?? this.salesUsed,
    engineersWaiting: engineersWaiting ?? this.engineersWaiting,
    engineersAssigned: engineersAssigned ?? this.engineersAssigned,
    joinedApplicantIds: joinedApplicantIds ?? this.joinedApplicantIds,
    engineerRuntimes: engineerRuntimes ?? this.engineerRuntimes,
    latestGrowthResults: latestGrowthResults ?? this.latestGrowthResults,
    growthAppliedMonths: growthAppliedMonths ?? this.growthAppliedMonths,
    trainingSelections: trainingSelections ?? this.trainingSelections,
    summerBonusSelection: summerBonusSelection ?? this.summerBonusSelection,
    summerBonusPaid: summerBonusPaid ?? this.summerBonusPaid,
    summerBonusPaidMonth: identical(summerBonusPaidMonth, _unset)
        ? this.summerBonusPaidMonth
        : summerBonusPaidMonth as int?,
    summerBonusPaidAmount: identical(summerBonusPaidAmount, _unset)
        ? this.summerBonusPaidAmount
        : summerBonusPaidAmount as int?,
    recruitmentMediumUsedMonth: identical(recruitmentMediumUsedMonth, _unset)
        ? this.recruitmentMediumUsedMonth
        : recruitmentMediumUsedMonth as int?,
  );
  static const Object _unset = Object();
  Map<String, dynamic> toJson() => {
    'month': month,
    'cash': cash,
    'engineerCount': engineerCount,
    'adminCount': adminCount,
    'salesCapacity': salesCapacity,
    'salesUsed': salesUsed,
    'engineersWaiting': engineersWaiting,
    'engineersAssigned': engineersAssigned,
    'joinedApplicantIds': joinedApplicantIds,
    'engineerRuntimes': engineerRuntimes
        .map((runtime) => runtime.toJson())
        .toList(),
    'latestGrowthResults': latestGrowthResults
        .map((result) => result.toJson())
        .toList(),
    'growthAppliedMonths': growthAppliedMonths,
    'trainingSelections': trainingSelections.map(
      (engineerId, source) => MapEntry(engineerId, source.name),
    ),
    'summerBonusSelection': summerBonusSelection.name,
    'summerBonusPaid': summerBonusPaid,
    'summerBonusPaidMonth': summerBonusPaidMonth,
    'summerBonusPaidAmount': summerBonusPaidAmount,
    'recruitmentMediumUsedMonth': recruitmentMediumUsedMonth,
  };
  factory PublicDemoState.fromJson(
    Map<String, dynamic> json,
  ) => PublicDemoState(
    month: json['month'] as int,
    cash: json['cash'] as int,
    engineerCount: json['engineerCount'] as int,
    adminCount: json['adminCount'] as int,
    salesCapacity: json['salesCapacity'] as int,
    salesUsed: json['salesUsed'] as int,
    engineersWaiting: json['engineersWaiting'] as int,
    engineersAssigned: json['engineersAssigned'] as int,
    joinedApplicantIds: (json['joinedApplicantIds'] as List? ?? const [])
        .cast<String>(),
    engineerRuntimes:
        (json['engineerRuntimes'] as List? ?? publicDemoInitialEngineerRuntimes)
            .map(
              (runtime) => runtime is PublicDemoEngineerRuntime
                  ? runtime
                  : PublicDemoEngineerRuntime.fromJson(
                      runtime as Map<String, dynamic>,
                    ),
            )
            .toList(),
    latestGrowthResults: (json['latestGrowthResults'] as List? ?? const [])
        .map(
          (result) =>
              PublicDemoMonthlyGrowth.fromJson(result as Map<String, dynamic>),
        )
        .toList(),
    growthAppliedMonths: (json['growthAppliedMonths'] as List? ?? const [])
        .cast<int>(),
    trainingSelections: _trainingSelectionsFromJson(json['trainingSelections']),
    summerBonusSelection: _summerBonusPlanFromJson(
      json['summerBonusSelection'],
    ),
    summerBonusPaid: json['summerBonusPaid'] is bool
        ? json['summerBonusPaid'] as bool
        : false,
    summerBonusPaidMonth: json['summerBonusPaidMonth'] is int
        ? json['summerBonusPaidMonth'] as int
        : null,
    summerBonusPaidAmount: json['summerBonusPaidAmount'] is int
        ? json['summerBonusPaidAmount'] as int
        : null,
    recruitmentMediumUsedMonth: json['recruitmentMediumUsedMonth'] is int
        ? json['recruitmentMediumUsedMonth'] as int
        : null,
  );

  static PublicDemoSummerBonusPlan _summerBonusPlanFromJson(Object? raw) {
    if (raw is! String) return PublicDemoSummerBonusPlan.none;
    return PublicDemoSummerBonusPlan.values
            .where((plan) => plan.name == raw)
            .firstOrNull ??
        PublicDemoSummerBonusPlan.none;
  }

  static Map<String, PublicDemoGrowthSource> _trainingSelectionsFromJson(
    Object? raw,
  ) {
    if (raw is! Map) return const {};
    final selections = <String, PublicDemoGrowthSource>{};
    for (final entry in raw.entries) {
      if (entry.key is! String || entry.value is! String) continue;
      final source = PublicDemoGrowthSource.values
          .where((candidate) => candidate.name == entry.value)
          .firstOrNull;
      if (source != null && _isTrainingSource(source)) {
        selections[entry.key] = source;
      }
    }
    return selections;
  }
}
