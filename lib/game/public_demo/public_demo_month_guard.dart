/// Domain-owned Month Guard (Issue #119).
///
/// This is a *decision-acknowledgement + outstanding-work* guard, never a
/// success guard: it only asks (a) whether the player has acknowledged a
/// required decision before a month closes, and (b) which already-legal,
/// already-on-screen actions the caller's own recommended-action authority
/// still considers outstanding. It never asks whether an unrelated outcome
/// (recruiting, sales, assignment, cash) succeeded. It must never convert an
/// existing failure/recovery route (no-hire, waiting-employee, sales
/// failure, no-bonus, red/poor company) into a blocked route, and it must
/// not gate [PublicDemoAggregate.closeJuly]/`closeOrdinaryMonth` itself —
/// callers enforce it above that boundary (UI month-close entry points),
/// exactly as the pre-existing `summerBonusDecisionConfirmed` check already
/// did for July.
///
/// PR1 had exactly one rule (July's required summer-bonus decision) and one
/// level ([PublicDemoMonthGuardLevel.required]). Issue #119's remaining
/// scope adds a second level, [PublicDemoMonthGuardLevel.recommended], for
/// month-close attempts that leave *other* already-legal, already-on-screen
/// actions untouched:
///
///  * `required` — cannot be bypassed; the only rule remains July's summer
///    bonus decision. No new required rule should be added here without a
///    corresponding issue (still true after this change).
///  * `recommended` — a truthful, named warning that still allows the
///    player to proceed. This file mints no opinion of its own about which
///    actions qualify: the caller (`PublicDemo01PlaceholderScreen`) hands in
///    [outstandingRecommendedActions], computed from the SAME
///    `_recommendedActionCandidates` authority HOME's one recommended-action
///    slot already uses (minus anything purely informational — see
///    `HomeRecommendedActionKind.isInformational`'s own doc for why that
///    exclusion belongs there, not here) — this file just wraps each one in
///    a `recommended`-level item. It genuinely cannot invent, drop, or
///    reorder a candidate: there is no game-state parameter here for it to
///    derive one from.
///  * `informational` items (e.g. the cash-shortage explanation) are never
///    constructed by this file at all: the caller filters them out of
///    [outstandingRecommendedActions] before calling [evaluate], so the
///    "informational never blocks or warns" contract holds structurally,
///    not by a runtime check here.
library;

enum PublicDemoMonthGuardLevel { required, recommended }

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

/// One outstanding, already-legal action the caller's own recommended-action
/// authority already knows about, reduced to the two primitives this file
/// needs. Carrying only `id`/`actionName` (never a HOME type, never a
/// domain/game type) is what keeps this file free of any dependency on
/// either layer — see the class doc.
class PublicDemoMonthGuardCandidate {
  const PublicDemoMonthGuardCandidate({
    required this.id,
    required this.actionName,
  });

  /// A stable identifier for this outstanding action (e.g.
  /// `employeeSkillSheetReview:eng-02`) — unique enough that two different
  /// outstanding actions never collide, never shown to the player.
  final String id;

  /// The truthful, specific action name to name in the warning (e.g.
  /// `佐藤 健のSkillSheetを確認`) — the caller's own headline text, verbatim.
  final String actionName;
}

abstract final class PublicDemoMonthGuard {
  static const summerBonusDecisionItemId = 'summer-bonus-decision';

  /// Returns the guard items outstanding for the given month-close attempt.
  /// An empty list means month close may proceed with no outstanding
  /// decision acknowledgement and no outstanding recommended action.
  ///
  /// [outstandingRecommendedActions] defaults to empty so every existing
  /// caller/test of the PR1 required-only rule is unaffected.
  static List<PublicDemoMonthGuardItem> evaluate({
    required int month,
    required bool monthCloseApplicable,
    required bool summerBonusDecisionConfirmed,
    List<PublicDemoMonthGuardCandidate> outstandingRecommendedActions = const [],
  }) {
    if (!monthCloseApplicable) return const [];
    final items = <PublicDemoMonthGuardItem>[];
    if (month == 7 && !summerBonusDecisionConfirmed) {
      items.add(
        const PublicDemoMonthGuardItem(
          id: summerBonusDecisionItemId,
          level: PublicDemoMonthGuardLevel.required,
          message: '7月終了前に夏季賞与の支給内容を決めてください。',
        ),
      );
    }
    for (final candidate in outstandingRecommendedActions) {
      items.add(
        PublicDemoMonthGuardItem(
          id: candidate.id,
          level: PublicDemoMonthGuardLevel.recommended,
          message: '${candidate.actionName} が未対応です。',
        ),
      );
    }
    return items;
  }
}
