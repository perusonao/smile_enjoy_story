import '../../domain/domain.dart';
import '../models/models.dart';
import 'payroll_engine.dart';

/// A qualitative read on [FinanceEngine.cashRunwayMonths], driving the
/// 資金余命 indicator's color (Playable 0.3A §12).
enum RunwayLevel { safe, caution, danger }

/// A fallback client used when a project references a client id that isn't
/// in [sampleClients] (only happens in hand-built test fixtures) so payment
/// term lookups never throw mid-game.
const Client _fallbackClient = Client(
  id: 'client-unknown',
  name: '(unknown)',
  specialty: ClientSpecialty.general,
  projectGenerationWeight: 1,
  paymentTermDays: 30,
);

/// Pure, testable money math for Playable 0.3A: payment-term/AR bookkeeping,
/// monthly burn/income projection, and the cash-runway estimate. Nothing
/// here mutates [GameState] — [GameEngine] calls these during the month-end
/// close and the UI calls them directly for live "今月の見込み" displays.
class FinanceEngine {
  const FinanceEngine._();

  static const int runwaySafeMonths = 6;
  static const int runwayCautionMonths = 3;

  static Client clientById(String clientId) {
    for (final c in sampleClients) {
      if (c.id == clientId) return c;
    }
    return _fallbackClient;
  }

  /// Full monthly salary for every current engineer, regardless of
  /// status — waiting engineers draw 100% salary too (§7) — *except* the
  /// one engineer the Founding Prologue can materialize before they've
  /// actually joined. Includes the 総務 employee's salary when Beginner Mode
  /// has seeded one (Playable 0.5A §8) — general affairs draws salary from
  /// day one, same as any other employee.
  static int monthlySalaryTotal(GameState state) {
    /// [PrologueEngine.decideCandidate] materializes a real [Engineer] the
    /// moment a March candidate accepts their offer (Playable 0.5A §27) —
    /// well before they actually join in April. Nothing is deducted for them
    /// until [PrologueEngine.enterAprilWeek1]'s one lump March close, which
    /// deliberately excludes this hire's own salary from that lump sum (see
    /// its doc comment). `state.activeAssignments` gains its first entry in
    /// the exact same transaction that flips this engineer's status to
    /// `assigned`, so "still empty" is the precise engine-owned signal for
    /// "hasn't joined yet" (Codex review, PR #10 P2).
    final input = PayrollInput(
      engineers: state.engineers,
      generalAffairsStaff: state.generalAffairsStaff,
      isPrologueActive: state.prologueState.active,
      hasStartedPrologueAssignment: state.activeAssignments.isNotEmpty,
    );
    return PayrollEngine.calculateMonthly(input).totalSalary;
  }

  static int monthlyRent(GameState state) =>
      officeConfigs[state.officeType]!.monthlyRent;

  /// Projected total monthly cash outflow if nothing changes: full
  /// salaries + rent + the flat other-fixed-cost line (§8).
  static int projectedMonthlyBurn(GameState state) =>
      monthlySalaryTotal(state) + monthlyRent(state) + otherMonthlyFixedCost;

  /// Recurring monthly revenue from every currently active assignment.
  static int projectedMonthlyIncome(GameState state) =>
      state.activeAssignments.fold<int>(
        0,
        (sum, a) => sum + a.project.monthlyRate,
      );

  static int totalPendingAr(GameState state) => state.accountsReceivable
      .where((ar) => ar.status == ArStatus.pending)
      .fold<int>(0, (sum, ar) => sum + ar.amount);

  /// 今月入金予定: pending AR whose [AccountsReceivable.dueMonth] is the
  /// current month, i.e. what's expected to be collected at this month's
  /// close.
  static int expectedInflowThisMonth(GameState state) {
    final currentMonth = GameCalendar.absoluteMonth(state.week);
    return state.accountsReceivable
        .where((ar) => ar.status == ArStatus.pending && ar.dueMonth == currentMonth)
        .fold<int>(0, (sum, ar) => sum + ar.amount);
  }

  /// 今月支払予定: this month's remaining salary + rent + fixed cost, i.e.
  /// what month-end will still pay out if the week ended right now.
  ///
  /// Deliberately excludes [GameState.pendingMiscExpense] (recruitment
  /// spend accrued so far this month, Playable 0.4C.2 §2 fix):
  /// [GameEngine.postRecruitmentMedia] already deducts that cost from
  /// [Company.cash] the instant a listing is posted, so it's baked into
  /// `state.company.cash` by the time this runs. Adding it again here would
  /// double-count it against [projectedMonthEndCash] — this must stay in
  /// sync with the real month-end close ([GameEngine.advanceWeek]'s
  /// `cashDelta`), which has the identical exclusion for the identical
  /// reason.
  static int expectedOutflowThisMonth(GameState state) =>
      monthlySalaryTotal(state) +
      monthlyRent(state) +
      otherMonthlyFixedCost;

  /// 月末予想現金: today's cash, plus what's expected in, minus what's
  /// expected out, by this month's close.
  static int projectedMonthEndCash(GameState state) =>
      state.company.cash +
      expectedInflowThisMonth(state) -
      expectedOutflowThisMonth(state);

  /// 資金余命 (§12): a deliberately simple, pure estimate of how many
  /// months of runway remain — not a strict cash-flow forecast.
  ///
  /// `netBurn` = projected monthly burn − projected recurring monthly
  /// income. When income already covers burn, runway is unbounded
  /// ([double.infinity]). Otherwise runway is `(cash + all pending AR) /
  /// netBurn` — pending AR is included on purpose (§12 explicitly warns
  /// against ignoring it and being overly pessimistic), since 0.3A has no
  /// bad-debt mechanic and every pending AR record is guaranteed to convert
  /// to cash eventually.
  static double cashRunwayMonths(GameState state) {
    final netBurn = projectedMonthlyBurn(state) - projectedMonthlyIncome(state);
    if (netBurn <= 0) return double.infinity;
    final available = state.company.cash + totalPendingAr(state);
    if (available <= 0) return 0;
    return available / netBurn;
  }

  static RunwayLevel classifyRunway(double months) {
    if (months >= runwaySafeMonths) return RunwayLevel.safe;
    if (months >= runwayCautionMonths) return RunwayLevel.caution;
    return RunwayLevel.danger;
  }

  /// Office capacity guard (§6): blocks hiring beyond the current office's
  /// employee capacity. Counts current engineers plus already-accepted
  /// pending hires, since both occupy a seat.
  static bool hasOfficeCapacity(GameState state, {int additional = 1}) {
    final projected = state.engineers.length + state.pendingHires.length + additional;
    return projected <= officeConfigs[state.officeType]!.employeeCapacity;
  }
}
