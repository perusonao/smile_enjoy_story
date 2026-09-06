import 'public_demo_sales.dart';

/// Issue #167 FIRST-FUN-YEAR-LATE-GAME-1 Phase 1: a small, state-driven
/// management decision for a founding engineer who has been continuously
/// participating in a client project for months without any company
/// follow-up.
///
/// The full-year playtest audit merged in PR #164 found that August through
/// February (7 months) had no meaningful decisions for participating
/// employees. This is deliberately narrow, per the design-audit comment on
/// Issue #167 (`READY WITH CONDITIONS`): only the two founding engineers
/// (`publicDemoInitialEngineers`), only while genuinely still assigned
/// (`PublicDemoWorkflowState.assignedEngineerIds`, the same SSOT Revenue/
/// Growth/training eligibility already agree on), only once per fiscal
/// year, and only during the August-February stretch the audit named. It
/// reuses [PublicDemoEngineerSales.mental]/[PublicDemoEngineerSales.trust]
/// — authoritative fields that already exist but, before this, were never
/// written by any gameplay action.
enum PublicDemoFounderFollowUpDecision {
  /// Leave the engineer to the field as-is. No cash cost; the lack of any
  /// company attention over a long assignment costs a little morale/trust.
  holdBack,

  /// Check in personally. No cash cost; a modest, genuine improvement.
  checkIn,

  /// Invest company money in support/environment for this engineer. Costs
  /// [PublicDemoFounderFollowUp.investSupportCost]; the largest
  /// improvement, trading cash for the relationship.
  investSupport,
}

/// Founding-engineer ids eligible for this decision — exactly the engineers
/// [publicDemoInitialEngineers] establishes at company founding, never a
/// later recruitment hire. Read from that existing roster instead of
/// duplicating the id list, so a future change to the founding roster
/// cannot silently drift out of sync with this eligibility check.
final Set<String> publicDemoFounderEngineerIds = publicDemoInitialEngineers
    .map((engineer) => engineer.id)
    .toSet();

/// First internal month of the August-February stretch this decision
/// targets. Internal month numbering follows [PublicDemoState] (April = 4
/// ... January-March of the following year = 13-15), so August = 8.
const publicDemoFounderFollowUpWindowStart = 8;

/// Last internal month of that stretch — February = 14.
const publicDemoFounderFollowUpWindowEnd = 14;

/// Pure calculator + eligibility check for the founder follow-up decision.
/// No cash/finance guard lives here — [PublicDemoAggregate
/// .applyFounderFollowUpDecision] owns [PublicDemoState.cash] and checks
/// affordability/`isFinanciallyRestricted` itself before ever calling into
/// this, exactly like every other cash-spending Public Demo command.
class PublicDemoFounderFollowUp {
  const PublicDemoFounderFollowUp._();

  /// One-time optional cash cost for
  /// [PublicDemoFounderFollowUpDecision.investSupport]. Never a recurring
  /// salary change — this stays out of monthly payroll/Finance truth
  /// entirely, unlike the existing raise decision.
  static const investSupportCost = 50000;

  static int mentalDeltaFor(PublicDemoFounderFollowUpDecision decision) =>
      switch (decision) {
        PublicDemoFounderFollowUpDecision.holdBack => -2,
        PublicDemoFounderFollowUpDecision.checkIn => 3,
        PublicDemoFounderFollowUpDecision.investSupport => 6,
      };

  static int trustDeltaFor(PublicDemoFounderFollowUpDecision decision) =>
      switch (decision) {
        PublicDemoFounderFollowUpDecision.holdBack => -2,
        PublicDemoFounderFollowUpDecision.checkIn => 2,
        PublicDemoFounderFollowUpDecision.investSupport => 5,
      };

  static int costFor(PublicDemoFounderFollowUpDecision decision) =>
      decision == PublicDemoFounderFollowUpDecision.investSupport
      ? investSupportCost
      : 0;

  static String reasonFor(PublicDemoFounderFollowUpDecision decision) =>
      switch (decision) {
        PublicDemoFounderFollowUpDecision.holdBack => '今回は現場に任せ、フォローを見送った',
        PublicDemoFounderFollowUpDecision.checkIn => '声をかけ、現場の状況を確認した',
        PublicDemoFounderFollowUpDecision.investSupport =>
          '費用をかけて環境整備・ねぎらいを行った',
      };

  /// Whether [engineer] is currently eligible for this decision at [month],
  /// given the workflow's own [assignedEngineerIds] for that month — real
  /// state, never a calendar-only check:
  ///
  ///  * a founding engineer ([publicDemoFounderEngineerIds]), never a later
  ///    recruitment hire;
  ///  * genuinely currently participating in a project this month
  ///    ([assignedEngineerIds]);
  ///  * inside the August-February stretch the full-year playtest audit
  ///    found became passive;
  ///  * not already decided this fiscal year
  ///    ([PublicDemoEngineerSales.founderFollowUpMonth] still `null`).
  static bool isEligible({
    required PublicDemoEngineerSales engineer,
    required int month,
    required Set<String> assignedEngineerIds,
  }) =>
      publicDemoFounderEngineerIds.contains(engineer.id) &&
      month >= publicDemoFounderFollowUpWindowStart &&
      month <= publicDemoFounderFollowUpWindowEnd &&
      assignedEngineerIds.contains(engineer.id) &&
      engineer.founderFollowUpMonth == null;
}
