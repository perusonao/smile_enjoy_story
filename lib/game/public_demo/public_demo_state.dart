import 'public_demo_engineer_runtime.dart';
import 'public_demo_financial_status.dart';
import 'public_demo_growth_engine.dart';
import 'public_demo_monthly_cash_flow.dart';
import 'public_demo_monthly_growth.dart';
import 'public_demo_recruitment.dart';
import 'public_demo_summer_bonus_plan.dart';
import 'public_demo_summer_bonus_payment.dart';

/// Authoritative, unforgeable proof that
/// [PublicDemoState.useSalesSlotForInterview] actually consumed one sales
/// slot on this exact call (WORKFLOW-STATE-1AB FIX3 P1-1) — not merely that
/// the method was invoked (it is a no-op, minting nothing, once
/// `salesRemaining` is exhausted or the fiscal year is already completed).
///
/// Constructor private to this file: the only place that can construct one
/// is [PublicDemoState.useSalesSlotForInterview] itself. This is what closes
/// WORKFLOW-STATE-1AB FIX2's residual P1-1 gap — `PublicDemoApplicant`
/// alone can never validate its own interview prerequisite (an available
/// sales slot lives on the finance side of the aggregate, not on the
/// applicant) — by making that cross-aggregate fact a locally-checkable,
/// unforgeable parameter instead:
/// [PublicDemoApplicant.completeInterview] (public_demo_recruitment.dart)
/// requires one, so interview authority can never be minted without a real,
/// same-transaction sales-slot consumption. Only the TYPE (not the private
/// constructor) needs to cross that file boundary, which Dart's ordinary
/// cross-file type references allow — `completeInterview` never constructs
/// one itself, only accepts a genuine instance as a parameter.
/// [PublicDemoAggregate.completeInterview] (public_demo_aggregate.dart) is
/// the only production caller of either method.
class PublicDemoSalesSlotConsumptionProof {
  const PublicDemoSalesSlotConsumptionProof._();
}

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
    bool summerBonusDecisionConfirmed = false,
    bool summerBonusPaid = false,
    int? summerBonusPaidMonth,
    int? summerBonusPaidAmount,
    int? recruitmentMediumUsedMonth,
    int pendingRevenue = 0,
    bool fiscalYearCompleted = false,
    PublicDemoFinancialStatus financialStatus =
        PublicDemoFinancialStatus.normal,
    int? monthOpeningCash,
    int monthTrainingSpent = 0,
    int monthRecruitmentSpent = 0,
    PublicDemoMonthlyCashFlow? latestMonthlyCashFlow,
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
    summerBonusDecisionConfirmed: summerBonusDecisionConfirmed,
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
    pendingRevenue: _normalizedPendingRevenue(pendingRevenue),
    fiscalYearCompleted: fiscalYearCompleted,
    financialStatus: financialStatus,
    monthOpeningCash: monthOpeningCash ?? cash,
    monthTrainingSpent: monthTrainingSpent < 0 ? 0 : monthTrainingSpent,
    monthRecruitmentSpent: monthRecruitmentSpent < 0
        ? 0
        : monthRecruitmentSpent,
    latestMonthlyCashFlow: latestMonthlyCashFlow,
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
    required this.summerBonusDecisionConfirmed,
    required this.summerBonusPaid,
    required this.summerBonusPaidMonth,
    required this.summerBonusPaidAmount,
    required this.recruitmentMediumUsedMonth,
    required this.pendingRevenue,
    required this.fiscalYearCompleted,
    required this.financialStatus,
    required this.monthOpeningCash,
    required this.monthTrainingSpent,
    required this.monthRecruitmentSpent,
    required this.latestMonthlyCashFlow,
  });

  factory PublicDemoState.aprilStart() => PublicDemoState(
    month: 4,
    cash: 4000000,
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

  /// A DERIVED PROJECTION (WORKFLOW-STATE-1 §24), kept here only for the
  /// finance/monthly-close callers already reading it as a plain
  /// `List<String>`. SOURCE OF TRUTH: [PublicDemoWorkflowState.applicants]
  /// (specifically each applicant's `hasJoined`), surfaced as
  /// `PublicDemoWorkflowState.joinedApplicantIds`. This field is only ever
  /// written by passing that already-computed projection in at month-close
  /// time (see `PublicDemoMonthlyClose.closeMay`'s `joinedApplicantIds`
  /// parameter) — nothing here writes back through to the workflow.
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

  /// Whether the player has explicitly completed the July bonus decision.
  /// This is distinct from [summerBonusSelection] because `none` is both a
  /// valid confirmed decision and the fresh-state default.
  final bool summerBonusDecisionConfirmed;

  final bool summerBonusPaid;
  final int? summerBonusPaidMonth;
  final int? summerBonusPaidAmount;

  /// The one month in which the company used a recruitment medium.
  ///
  /// Public Demo 0.1 only needs the latest use because a medium may be used
  /// once per company per month. JOB-2 owns the transaction that calls this.
  final int? recruitmentMediumUsedMonth;

  /// Revenue already recognized but not yet collected: it becomes cash at a
  /// future month-end close under the fixed 30-day payment term (REVENUE-0
  /// §15-17). REVENUE-1 only carries this balance; REVENUE-2 generates it
  /// and REVENUE-4 wires it into cash at month-end.
  final int pendingRevenue;

  /// Whether the fiscal year (April through March, internal months 4-15)
  /// has been closed out. This is the minimal signal Public Demo 0.1 needs
  /// to show a year-end state instead of a 16th month; it carries no score,
  /// rank, or other year-end detail (12MONTH-3 scope).
  final bool fiscalYearCompleted;

  /// The single authoritative financial-health status (FINANCE-FAILURE-1A+
  /// 1B) — see [PublicDemoFinancialStatus]'s own class doc for the full
  /// shortage/recovery/bankruptcy/March-failure contract. Never inferred
  /// from [cash]'s sign or from [fiscalYearCompleted] by any caller; this
  /// field is the sole source of truth.
  final PublicDemoFinancialStatus financialStatus;

  /// Whether either terminal financial outcome has been reached —
  /// [PublicDemoFinancialStatus.bankruptcy] or
  /// [PublicDemoFinancialStatus.marchCashShortageFailure]. Terminal once
  /// true: it can never be cleared by any later close.
  bool get isFinanciallyTerminal => financialStatus.isTerminal;

  /// The single authoritative guard every monthly-close command checks
  /// before mutating anything (WORKFLOW-STATE-1AB's pre-AR-idempotency
  /// contract, extended to the financial-terminal case): once the fiscal
  /// year is completed OR a terminal financial status has been reached, no
  /// further monthly close may collect AR, apply Growth, pay salary/fixed
  /// costs/bonus, move cash, or record a cash-flow fact. A retried close
  /// against a [isCloseBlocked] state is a no-op, not a partial mutation.
  bool get isCloseBlocked => fiscalYearCompleted || isFinanciallyTerminal;

  /// Whether an optional, obligation-creating action must be rejected by
  /// domain authority: recruitment media (including free media), accepting
  /// a new salary offer, internal paid training, and selecting a summer
  /// bonus above [PublicDemoSummerBonusPlan.none] (FINANCE-FAILURE-1A+1B
  /// §13-16). True during the [PublicDemoFinancialStatus.cashShortage]
  /// grace period and for either terminal status — sales, interviews,
  /// assignment/order progression, existing payroll, and AR settlement
  /// remain unaffected.
  bool get isFinanciallyRestricted =>
      financialStatus == PublicDemoFinancialStatus.cashShortage ||
      isFinanciallyTerminal;

  /// The cash balance at the moment the current [month] began (FINANCE-UX-1)
  /// — a snapshot taken by the last month-advancing transition, not a
  /// recomputation. Mid-month transactions (training, recruitment media)
  /// change [cash] without touching this, so it stays the true opening
  /// balance for whichever month is currently in progress.
  final int monthOpeningCash;

  /// Actual internal-training charges paid so far this month, accumulated
  /// from each transaction's own already-computed amount. Resets to 0 every
  /// time the month advances.
  final int monthTrainingSpent;

  /// Actual recruitment-media charges paid so far this month, accumulated
  /// the same way as [monthTrainingSpent].
  final int monthRecruitmentSpent;

  /// The cash-flow explanation for the most recently closed month
  /// (FINANCE-UX-1). Historical fact recorded by [PublicDemoMonthlyClose],
  /// not a value the UI recomputes — mirrors [latestGrowthResults]'s role
  /// for growth.
  final PublicDemoMonthlyCashFlow? latestMonthlyCashFlow;

  static int _normalizedPendingRevenue(int value) => value < 0 ? 0 : value;

  static bool _hasValidSummerBonusPayment({
    required bool paid,
    required int? month,
    required int? amount,
  }) => paid && month == 7 && amount != null && amount >= 0;

  /// Recruitment media is only usable through August (8): no month past 5
  /// has a UI flow that can process a generated applicant, and 12MONTH-3
  /// briefly widened this to 4-15 without one, creating a paid dead end for
  /// September-March (12MONTH-3-FIX1 P1-2). Kept at the pre-12MONTH-3 4-8
  /// range rather than narrowed further, since month 7's identical
  /// pre-existing gap is an intentional follow-up, not something this fix
  /// changes (see SES_12MONTH-3_P1_Fixes_Result.md).
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

  /// POST-12MONTH-1: once the fiscal year is closed out, no further
  /// training selection or cancellation may mutate state — Public Demo 0.1
  /// is a read-only terminal state from that point on. This is the single
  /// SSOT guard for both [selectInternalTraining] and
  /// [selectExternalTraining] (which both delegate here).
  PublicDemoState _selectTraining(
    String engineerId,
    PublicDemoGrowthSource source,
  ) {
    if (fiscalYearCompleted) return this;
    return copyWith(
      trainingSelections: {...trainingSelections, engineerId: source},
    );
  }

  PublicDemoState cancelTraining(String engineerId) {
    if (fiscalYearCompleted) return this;
    return copyWith(
      trainingSelections: {
        for (final entry in trainingSelections.entries)
          if (entry.key != engineerId) entry.key: entry.value,
      },
    );
  }

  /// Updates the intended bonus without changing cash, salary, or growth.
  /// Once paid, the historical decision is immutable. Once the fiscal year
  /// is completed, this is a no-op as well (POST-12MONTH-1). A plan above
  /// [PublicDemoSummerBonusPlan.none] is also rejected while
  /// [isFinanciallyRestricted] (FINANCE-FAILURE-1A+1B §13/16) — selecting
  /// [PublicDemoSummerBonusPlan.none] itself always remains available.
  PublicDemoState selectSummerBonus(PublicDemoSummerBonusPlan plan) {
    if (fiscalYearCompleted ||
        summerBonusPaid ||
        plan == summerBonusSelection) {
      return this;
    }
    if (plan != PublicDemoSummerBonusPlan.none && isFinanciallyRestricted) {
      return this;
    }
    return copyWith(summerBonusSelection: plan);
  }

  /// Records an explicit July bonus decision, including a confirmed `none`.
  /// The selected plan remains editable until payment, but the completed
  /// decision fact is preserved for the July-close gate and persistence.
  PublicDemoState confirmSummerBonusDecision(PublicDemoSummerBonusPlan plan) {
    if (month != 7 || fiscalYearCompleted || summerBonusPaid) return this;
    if (plan != PublicDemoSummerBonusPlan.none && isFinanciallyRestricted) {
      return this;
    }
    return copyWith(
      summerBonusSelection: plan,
      summerBonusDecisionConfirmed: true,
    );
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

  /// A no-op once the fiscal year is completed (POST-12MONTH-1): sales
  /// activity is a game-progression action, not read-only navigation.
  PublicDemoState useSalesSlot() {
    if (fiscalYearCompleted || salesRemaining <= 0) return this;
    return copyWith(salesUsed: salesUsed + 1);
  }

  /// Same slot-budget rule as [useSalesSlot], but also returns unforgeable
  /// proof of genuine consumption when it actually happens
  /// (WORKFLOW-STATE-1AB FIX3 P1-1). [PublicDemoAggregate.completeInterview]
  /// is the only production caller: it passes the proof to
  /// [PublicDemoApplicant.completeInterview], the sole way to mint an
  /// interview record, so that authority can never be minted without a real,
  /// same-transaction sales-slot consumption.
  PublicDemoSalesSlotConsumptionResult useSalesSlotForInterview() {
    if (fiscalYearCompleted || salesRemaining <= 0) {
      return PublicDemoSalesSlotConsumptionResult._(state: this, proof: null);
    }
    return PublicDemoSalesSlotConsumptionResult._(
      state: copyWith(salesUsed: salesUsed + 1),
      proof: const PublicDemoSalesSlotConsumptionProof._(),
    );
  }

  PublicDemoState advanceToMay({
    required int monthlyExpenses,
    required int orderedEngineers,
  }) {
    if (month != 4 || isCloseBlocked) return this;
    final assigned = orderedEngineers.clamp(0, engineerCount);
    final nextCash = cash - monthlyExpenses;
    return copyWith(
      month: 5,
      cash: nextCash,
      salesUsed: 0,
      engineersAssigned: assigned,
      engineersWaiting: engineerCount - assigned,
      financialStatus: PublicDemoFinancialStatus.afterClose(
        previous: financialStatus,
        isMarch: false,
        closingCash: nextCash,
      ),
      monthOpeningCash: nextCash,
      monthTrainingSpent: 0,
      monthRecruitmentSpent: 0,
    );
  }

  /// FIX3 P1-4: [joinedApplicants] is no longer a parameter any outward
  /// caller controls — [PublicDemoMonthlyClose.closeMay] is now the only
  /// production caller, and it always passes the complete, authoritative
  /// `PublicDemoWorkflowState.joinedApplicants` for the workflow it was
  /// given, never a caller-chosen subset. This method's own contract
  /// (below) is unchanged: it still trusts nothing beyond each applicant's
  /// own [PublicDemoApplicant.hasJoined] fact.
  ///
  /// WORKFLOW-STATE-1AB FIX1 P1-4: [joinedApplicants] carries the
  /// authoritative applicant records themselves (the same ones
  /// [PublicDemoWorkflowState.joinAndKeepOnly] just joined), not a
  /// caller-supplied id list — [joinedApplicantIds] is derived here from
  /// each applicant's own [PublicDemoApplicant.hasJoined] fact, so a caller
  /// cannot make this projection diverge from actual join state by passing
  /// an id with no correspondingly-joined applicant behind it.
  ///
  /// FIX2 P1-4: [PublicDemoApplicant.hasJoined] itself is now backed by an
  /// unforgeable, identity-bound [PublicDemoJoinRecord] that only
  /// [PublicDemoApplicant.join] can mint — a caller can no longer fabricate
  /// a "joined" applicant by constructing one (or calling `copyWith`) with
  /// `employeeMorale`/`employeeCompanyTrust` set directly, so this method
  /// never has to trust a caller-provided applicant's join status on faith.
  /// Duplicate ids within a single [joinedApplicants] batch are also
  /// deduped before being appended, so passing the same joined applicant
  /// twice cannot duplicate their payroll membership.
  PublicDemoState advanceToJune({
    required int monthlyExpenses,
    required int acceptedHires,
    required int hiredWithOrders,
    Iterable<PublicDemoApplicant> joinedApplicants = const [],
  }) {
    if (month != 5 || isCloseBlocked) return this;
    final hires = acceptedHires < 0 ? 0 : acceptedHires;
    final ordered = hiredWithOrders.clamp(0, hires);
    final nextCash = cash - monthlyExpenses;
    // WORKFLOW-STATE-1AB FIX2 P1-4: dedupe within this batch itself, not
    // just against the already-accumulated `joinedApplicantIds` — passing
    // the same genuinely-joined applicant twice in [joinedApplicants] must
    // not add their id to the payroll projection twice.
    final newlyJoinedIds = <String>{
      for (final applicant in joinedApplicants)
        if (applicant.hasJoined) applicant.id,
    };
    return _copyWith(
      month: 6,
      cash: nextCash,
      salesUsed: 0,
      engineerCount: engineerCount + hires,
      engineersAssigned: engineersAssigned + ordered,
      engineersWaiting: engineersWaiting + (hires - ordered),
      joinedApplicantIds: [
        ...joinedApplicantIds,
        ...newlyJoinedIds.where((id) => !joinedApplicantIds.contains(id)),
      ],
      financialStatus: PublicDemoFinancialStatus.afterClose(
        previous: financialStatus,
        isMarch: false,
        closingCash: nextCash,
      ),
      monthOpeningCash: nextCash,
      monthTrainingSpent: 0,
      monthRecruitmentSpent: 0,
    );
  }

  PublicDemoState advanceToJuly({
    required int monthlyExpenses,
    required int assignedInJuly,
  }) {
    if (month != 6 || isCloseBlocked) return this;
    final assigned = assignedInJuly.clamp(0, engineerCount);
    final nextCash = cash - monthlyExpenses;
    return copyWith(
      month: 7,
      cash: nextCash,
      salesUsed: 0,
      engineersAssigned: assigned,
      engineersWaiting: engineerCount - assigned,
      financialStatus: PublicDemoFinancialStatus.afterClose(
        previous: financialStatus,
        isMarch: false,
        closingCash: nextCash,
      ),
      monthOpeningCash: nextCash,
      monthTrainingSpent: 0,
      monthRecruitmentSpent: 0,
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

  /// Closes any ordinary month from August (8) through February (14) into
  /// the next month.
  ///
  /// September onward introduces no month-specific rule the way July's
  /// bonus does, so this single method serves the rest of the fiscal year
  /// instead of a dedicated `advanceToSeptember`/`advanceToOctober`/...
  /// method per month (12MONTH-3). Only ordinary monthly expenses settle
  /// and sales slots reset; [engineersAssigned]/[engineersWaiting] carry
  /// forward unchanged because Public Demo 0.1 has no per-month
  /// assignment-renewal UI beyond June's.
  PublicDemoState advanceToNextOrdinaryMonth({required int monthlyExpenses}) {
    if (month < 8 || month > 14 || isCloseBlocked) return this;
    final nextCash = cash - monthlyExpenses;
    return copyWith(
      month: month + 1,
      cash: nextCash,
      salesUsed: 0,
      financialStatus: PublicDemoFinancialStatus.afterClose(
        previous: financialStatus,
        isMarch: false,
        closingCash: nextCash,
      ),
      monthOpeningCash: nextCash,
      monthTrainingSpent: 0,
      monthRecruitmentSpent: 0,
    );
  }

  /// Closes March (internal month 15), the last month of the fiscal year.
  ///
  /// Ordinary monthly expenses still settle exactly as in
  /// [advanceToNextOrdinaryMonth], but the month does not advance to a 16th
  /// value. [fiscalYearCompleted] becomes true only when this close's
  /// resulting [financialStatus] is NOT terminal (FINANCE-FAILURE-1A+1B
  /// §12): a March close that ends in
  /// [PublicDemoFinancialStatus.bankruptcy] or
  /// [PublicDemoFinancialStatus.marchCashShortageFailure] is a real,
  /// committed close (cash/AR/expenses all settle) but is never annual
  /// success — [isCloseBlocked] (via [isFinanciallyTerminal]) then keeps
  /// every later call a no-op exactly the way completed success already
  /// did. Calling this again once already completed (by either outcome) is
  /// a no-op, matching every other idempotent close guard in this class.
  PublicDemoState completeFiscalYear({required int monthlyExpenses}) {
    if (month != 15 || isCloseBlocked) return this;
    final nextCash = cash - monthlyExpenses;
    final nextStatus = PublicDemoFinancialStatus.afterClose(
      previous: financialStatus,
      isMarch: true,
      closingCash: nextCash,
    );
    return copyWith(
      cash: nextCash,
      salesUsed: 0,
      fiscalYearCompleted: !nextStatus.isTerminal,
      financialStatus: nextStatus,
      monthOpeningCash: nextCash,
      monthTrainingSpent: 0,
      monthRecruitmentSpent: 0,
    );
  }

  /// Records an internal-training charge already computed and applied by
  /// [PublicDemoInternalTrainingTransaction] against [monthTrainingSpent]
  /// (FINANCE-UX-1). This does not itself move cash — the transaction's own
  /// `copyWith(cash: ...)` does that; this only remembers the actual amount
  /// for the closing month's cash-flow summary.
  PublicDemoState recordTrainingSpend(int amount) =>
      copyWith(monthTrainingSpent: monthTrainingSpent + amount);

  /// Records a recruitment-media charge already computed and applied by
  /// PublicDemoRecruitmentWorkflowTransaction, mirroring
  /// [recordTrainingSpend].
  PublicDemoState recordRecruitmentSpend(int amount) =>
      copyWith(monthRecruitmentSpent: monthRecruitmentSpent + amount);

  /// Attaches the cash-flow explanation [PublicDemoMonthlyClose] computed
  /// for the month it just closed. Historical record only — never mutates
  /// [cash] or any other field.
  PublicDemoState recordMonthlyCashFlow(PublicDemoMonthlyCashFlow flow) =>
      copyWith(latestMonthlyCashFlow: flow);

  PublicDemoEngineerRuntime? runtimeForOrNull(String engineerId) {
    for (final runtime in engineerRuntimes) {
      if (runtime.engineerId == engineerId) return runtime;
    }
    return null;
  }

  PublicDemoEngineerRuntime runtimeFor(String engineerId) =>
      runtimeForOrNull(engineerId) ??
      (throw ArgumentError.value(engineerId, 'engineerId', 'Unknown runtime'));

  /// Closes growth for the current month exactly once, before its state is
  /// advanced. Assignment IDs and morale are supplied by the live Public Demo
  /// workflow because those transient workflow objects own that information.
  ///
  /// The current demo assignment model has no reliable industry field, so this
  /// method intentionally does not invent one; industry experience remains 0.
  ///
  /// Also a no-op once [fiscalYearCompleted] is true (POST-12MONTH-1): the
  /// live UI always closes growth before completion is set, so this guard is
  /// defense in depth for any other caller, or a restored state whose
  /// [growthAppliedMonths] doesn't yet include month 15.
  PublicDemoState applyMonthlyGrowth({
    required Set<String> assignedEngineerIds,
    required Map<String, int> moraleByEngineerId,
  }) {
    if (fiscalYearCompleted || growthAppliedMonths.contains(month)) {
      return this;
    }
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

  /// Safe production copyWith (WORKFLOW-STATE-1AB FIX4 P1-4): deliberately
  /// has no `joinedApplicantIds` parameter — that field is a DERIVED
  /// PROJECTION (see its own doc comment above) and must never be settable
  /// to an arbitrary caller-chosen list directly. [_copyWith] (below) is the
  /// full-field internal version [advanceToJune] uses instead, the sole
  /// place that ever writes this field, always from its own derivation of
  /// genuinely-joined applicants.
  PublicDemoState copyWith({
    int? month,
    int? cash,
    int? engineerCount,
    int? adminCount,
    int? salesCapacity,
    int? salesUsed,
    int? engineersWaiting,
    int? engineersAssigned,
    List<PublicDemoEngineerRuntime>? engineerRuntimes,
    List<PublicDemoMonthlyGrowth>? latestGrowthResults,
    List<int>? growthAppliedMonths,
    Map<String, PublicDemoGrowthSource>? trainingSelections,
    PublicDemoSummerBonusPlan? summerBonusSelection,
    bool? summerBonusDecisionConfirmed,
    bool? summerBonusPaid,
    Object? summerBonusPaidMonth = _unset,
    Object? summerBonusPaidAmount = _unset,
    Object? recruitmentMediumUsedMonth = _unset,
    int? pendingRevenue,
    bool? fiscalYearCompleted,
    PublicDemoFinancialStatus? financialStatus,
    int? monthOpeningCash,
    int? monthTrainingSpent,
    int? monthRecruitmentSpent,
    PublicDemoMonthlyCashFlow? latestMonthlyCashFlow,
  }) => _copyWith(
    month: month,
    cash: cash,
    engineerCount: engineerCount,
    adminCount: adminCount,
    salesCapacity: salesCapacity,
    salesUsed: salesUsed,
    engineersWaiting: engineersWaiting,
    engineersAssigned: engineersAssigned,
    engineerRuntimes: engineerRuntimes,
    latestGrowthResults: latestGrowthResults,
    growthAppliedMonths: growthAppliedMonths,
    trainingSelections: trainingSelections,
    summerBonusSelection: summerBonusSelection,
    summerBonusDecisionConfirmed: summerBonusDecisionConfirmed,
    summerBonusPaid: summerBonusPaid,
    summerBonusPaidMonth: summerBonusPaidMonth,
    summerBonusPaidAmount: summerBonusPaidAmount,
    recruitmentMediumUsedMonth: recruitmentMediumUsedMonth,
    pendingRevenue: pendingRevenue,
    fiscalYearCompleted: fiscalYearCompleted,
    financialStatus: financialStatus,
    monthOpeningCash: monthOpeningCash,
    monthTrainingSpent: monthTrainingSpent,
    monthRecruitmentSpent: monthRecruitmentSpent,
    latestMonthlyCashFlow: latestMonthlyCashFlow,
  );

  PublicDemoState _copyWith({
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
    bool? summerBonusDecisionConfirmed,
    bool? summerBonusPaid,
    Object? summerBonusPaidMonth = _unset,
    Object? summerBonusPaidAmount = _unset,
    Object? recruitmentMediumUsedMonth = _unset,
    int? pendingRevenue,
    bool? fiscalYearCompleted,
    PublicDemoFinancialStatus? financialStatus,
    int? monthOpeningCash,
    int? monthTrainingSpent,
    int? monthRecruitmentSpent,
    PublicDemoMonthlyCashFlow? latestMonthlyCashFlow,
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
    summerBonusDecisionConfirmed:
        summerBonusDecisionConfirmed ?? this.summerBonusDecisionConfirmed,
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
    pendingRevenue: pendingRevenue ?? this.pendingRevenue,
    fiscalYearCompleted: fiscalYearCompleted ?? this.fiscalYearCompleted,
    financialStatus: financialStatus ?? this.financialStatus,
    monthOpeningCash: monthOpeningCash ?? this.monthOpeningCash,
    monthTrainingSpent: monthTrainingSpent ?? this.monthTrainingSpent,
    monthRecruitmentSpent: monthRecruitmentSpent ?? this.monthRecruitmentSpent,
    latestMonthlyCashFlow: latestMonthlyCashFlow ?? this.latestMonthlyCashFlow,
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
    'summerBonusDecisionConfirmed': summerBonusDecisionConfirmed,
    'summerBonusPaid': summerBonusPaid,
    'summerBonusPaidMonth': summerBonusPaidMonth,
    'summerBonusPaidAmount': summerBonusPaidAmount,
    'recruitmentMediumUsedMonth': recruitmentMediumUsedMonth,
    'pendingRevenue': pendingRevenue,
    'fiscalYearCompleted': fiscalYearCompleted,
    'financialStatus': financialStatus.name,
    'monthOpeningCash': monthOpeningCash,
    'monthTrainingSpent': monthTrainingSpent,
    'monthRecruitmentSpent': monthRecruitmentSpent,
    'latestMonthlyCashFlow': latestMonthlyCashFlow?.toJson(),
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
    summerBonusDecisionConfirmed: json['summerBonusDecisionConfirmed'] is bool
        ? json['summerBonusDecisionConfirmed'] as bool
        : false,
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
    pendingRevenue: json['pendingRevenue'] is int
        ? json['pendingRevenue'] as int
        : 0,
    fiscalYearCompleted: json['fiscalYearCompleted'] is bool
        ? json['fiscalYearCompleted'] as bool
        : false,
    financialStatus: PublicDemoFinancialStatus.fromJson(
      json['financialStatus'],
    ),
    monthOpeningCash: json['monthOpeningCash'] is int
        ? json['monthOpeningCash'] as int
        : json['cash'] as int,
    monthTrainingSpent: json['monthTrainingSpent'] is int
        ? json['monthTrainingSpent'] as int
        : 0,
    monthRecruitmentSpent: json['monthRecruitmentSpent'] is int
        ? json['monthRecruitmentSpent'] as int
        : 0,
    latestMonthlyCashFlow: json['latestMonthlyCashFlow'] is Map
        ? PublicDemoMonthlyCashFlow.fromJson(
            (json['latestMonthlyCashFlow'] as Map).cast<String, dynamic>(),
          )
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

/// Result of [PublicDemoState.useSalesSlotForInterview]: the resulting
/// [state] always reflects whatever actually happened (unchanged when no
/// slot was consumed), and [proof] is non-null exactly when a slot really
/// was consumed on this call (WORKFLOW-STATE-1AB FIX3 P1-1).
class PublicDemoSalesSlotConsumptionResult {
  const PublicDemoSalesSlotConsumptionResult._({
    required this.state,
    required this.proof,
  });

  final PublicDemoState state;
  final PublicDemoSalesSlotConsumptionProof? proof;

  bool get consumed => proof != null;
}
