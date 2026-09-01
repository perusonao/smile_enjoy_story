/// Domain-owned Month Guard (Issue #119 PR1).
///
/// This is a *decision-acknowledgement* guard, not a success guard: it only
/// asks whether the player has acknowledged a required decision before a
/// month closes, never whether an unrelated outcome (recruiting, sales,
/// assignment, cash) succeeded. It must never convert an existing
/// failure/recovery route (no-hire, waiting-employee, sales failure,
/// no-bonus, red/poor company) into a blocked route, and it must not gate
/// [PublicDemoAggregate.closeJuly] itself — callers enforce it above that
/// boundary (UI month-close entry points), exactly as the pre-existing
/// `summerBonusDecisionConfirmed` check already did.
///
/// PR1 has exactly one rule: July requires an acknowledged summer-bonus
/// decision. Do not add further rules here without a corresponding issue.
library;

enum PublicDemoMonthGuardLevel { required }

class PublicDemoMonthGuardItem {
  const PublicDemoMonthGuardItem({
    required this.id,
    required this.level,
    required this.message,
  });

  final String id;
  final PublicDemoMonthGuardLevel level;
  final String message;
}

abstract final class PublicDemoMonthGuard {
  static const summerBonusDecisionItemId = 'summer-bonus-decision';

  /// Returns the guard items outstanding for the given month-close attempt.
  /// An empty list means month close may proceed with no outstanding
  /// decision acknowledgement.
  static List<PublicDemoMonthGuardItem> evaluate({
    required int month,
    required bool monthCloseApplicable,
    required bool summerBonusDecisionConfirmed,
  }) {
    if (!monthCloseApplicable) return const [];
    if (month != 7) return const [];
    if (summerBonusDecisionConfirmed) return const [];
    return const [
      PublicDemoMonthGuardItem(
        id: summerBonusDecisionItemId,
        level: PublicDemoMonthGuardLevel.required,
        message: '7月終了前に夏季賞与の支給内容を決めてください。',
      ),
    ];
  }
}
