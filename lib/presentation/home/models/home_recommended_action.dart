/// HOME-RUNTIME-2C — the typed vocabulary of "the one thing to do next".
///
/// The whole point of this file is that it contains **no eligibility rule
/// and no game rule at all**. It is a presentation vocabulary plus a
/// deterministic presentation ordering, and nothing else:
///
///  * *Which* actions exist right now is decided exclusively by the
///    authoritative owner (`PublicDemo01PlaceholderScreen`), which emits a
///    candidate from the *same* `if (s.month == N)` branch and the *same*
///    predicate that already render and enable the corresponding button.
///    HOME never reconstructs availability from predicates of its own — see
///    [HomeRecommendedActionCandidate].
///  * *How* the emitted candidates are ordered is decided here, by
///    [HomeRecommendedActionKind.presentationPriority]. That is a
///    presentation concern only: it is never persisted (SAVE AUTHORITY),
///    never consulted by the domain, and changing it can only change which
///    already-legal action is shown first — never which actions are legal.
///
/// Deliberately imports nothing from `game/` or `domain/`: this layer
/// cannot see `PublicDemoState`, `PublicDemoAggregate`,
/// `PublicDemoFinancialStatus` or a workflow stage even if it wanted to.
library;

import 'package:flutter/foundation.dart' show VoidCallback, immutable;

/// The kinds of action HOME can recommend, and their presentation rank.
///
/// One enum value per *already existing* production button. Dispatch is
/// therefore typed end to end — there is no string anywhere on the path
/// from "which action is this" to "which handler runs" (the handler is a
/// callback the owner already bound; see [HomeRecommendedActionCandidate]).
///
/// ## Presentation priority
///
/// [presentationPriority] is a total order over the kinds: **lower wins**.
/// Its bands are the integration design's RECOMMENDED ACTION PLAN table
/// (P0/P1/P2/P3), kept verbatim:
///
/// | Band | Design row | Kind |
/// |---|---|---|
/// | P0 (0-9)   | `financialStatus == cashShortage`        | [cashShortageResponse] |
/// | P1 (10-19) | `month == 7 && !bonusConfirmed`          | [summerBonusDecision] |
/// | P1 (10-19) | `canRequestRaiseIn(month)`               | [raiseRequest] |
/// | P2 (20-49) | `stage == clientInterviewPassed`         | [employeeAcceptOrder] |
/// | P2 (20-49) | `stage == introduced && salesRemaining`  | [employeePartnerInterview] |
/// | P2 (20-49) | `stage == skillSheet && ready`           | [employeeBeginSelling] |
/// | P2 (20-49) | `stage == waiting && ready`              | [employeeSkillSheetReview] |
/// | P3 (50-59) | `nextOrderStatus == undecided`           | [assignmentConfirmNextOrder] |
/// | P3 (50-59) | `canUseRecruitmentMediaInMonth(month)`   | [recruitmentMedia] |
///
/// The supplied design authority (`SES_HOME-RUNTIME-2_Integration_Design.md`)
/// is the *only* 2C design available — the standalone
/// `SES_HOME-RUNTIME-2C_Recommended_Action_Design.md` was not supplied and
/// no newer 2C authority exists in this repository. Its table above is a
/// partial inventory: it names the four engineer field-sales stages that
/// matter most but is silent on the intermediate stages of the same
/// pipeline (`selling`, `partnerInterviewPassed`, the two failure stages),
/// on the whole month-5 applicant pipeline, and on the month-6 replacement
/// pipeline — all of which have production buttons of their own.
///
/// The kinds below therefore *extend* that table without contradicting it:
/// every design-named row keeps its design band, and each additional kind
/// is placed inside the band its design-named neighbours already occupy,
/// ordered by the brief's stated rule — **finish an already-started
/// pipeline before starting a new one**, i.e. within a band the step
/// closest to completing that pipeline ranks first. Nothing here promotes
/// an action across a design band boundary, and nothing here makes an
/// action eligible that was not already eligible.
///
/// Four deliberate absences:
///
///  * **Month close is never recommended.** MONTH END CTA PLAN keeps it at
///    the bottom of the scroll on purpose ("finish this month's work
///    first"), and it is HOME-RUNTIME-2D's scope. When no action is
///    eligible the slot falls back to the month goal instead.
///  * **Internal training is never recommended**, even though its card is
///    rendered and enabled from month 6 on. Extending the design's table
///    through the intermediate steps of a pipeline it already names is
///    presentation; promoting an optional ¥30,000 spend the table never
///    mentions into "the next thing to do" would be a balance nudge, i.e.
///    a game decision this layer has no authority to make. It stays a
///    secondary action on the employee's own card, exactly as 2A left it.
///  * **July's 求人媒体 is never recommended**, though its card is rendered
///    and enabled there. May renders the recruitment card and the applicant
///    pipeline together; July renders the card alone, and no month after it
///    renders the pipeline at all, so a July hire can never be advanced.
///    Design row P3 assumes the action leads somewhere; where it does not,
///    recommending it would spend the player's cash on structurally
///    unusable candidates. The owner's emit site carries the reasoning.
///  * **Nothing disabled is ever recommended.** A candidate is emitted only
///    where the production button is both rendered *and* enabled, so the
///    slot never offers a dead CTA. Being *enabled* is necessary, not
///    sufficient: the July case above is enabled and still excluded.
enum HomeRecommendedActionKind {
  // ---- P(-1): the one deliberate exception to "P0 outranks everything"--
  /// RECOVERY-LOOP-1 + Issue #119: a genuine, mutating Recovery step
  /// (`PublicDemoRecoveryEligibility.isEligible` already holds; this is the
  /// exact same `案件へ復帰` button, never a reconstructed predicate) for an
  /// engineer who has walked the real sales pipeline back to `ordered`
  /// while economically waiting (July–February).
  ///
  /// This is the one kind ranked ABOVE [cashShortageResponse] — see
  /// [isInformational]'s doc for why: [cashShortageResponse] never changes
  /// any authoritative state (PLAYTEST-BLOCKER-1B), so it must never be the
  /// only thing the recommended-action slot shows forever while a real,
  /// mutating recovery step is sitting right there, reachable, and legal.
  /// Every other kind's relative order versus [cashShortageResponse] is
  /// unchanged — this is a single, narrow, documented exception, not a
  /// general "actionable beats informational" rule.
  recoveryAssignment(
    presentationPriority: -1,
    ctaLabel: '案件へ復帰',
    headline: '{name}を案件へ復帰させる',
  ),

  // ---- P0: terminal / critical -----------------------------------------
  /// Design row P0. The FINANCE-FAILURE-1C shortage card is the action.
  cashShortageResponse(
    presentationPriority: 0,
    ctaLabel: '資金不足を確認',
    headline: '資金不足の対応を確認',
    informational: true,
  ),

  // ---- P1: a deadline or an answer somebody is waiting for -------------
  /// Design row P1. July's bonus must be decided before July can close.
  summerBonusDecision(
    presentationPriority: 10,
    ctaLabel: '夏季賞与を決定',
    headline: '夏季賞与の支給内容を決める',
  ),

  /// Design row P1. An employee is waiting on a raise answer.
  raiseRequest(
    presentationPriority: 11,
    ctaLabel: '昇給要求を確認する',
    headline: '{name}の昇給要求を確認',
  ),

  // ---- P2: the next step of an already-started pipeline ----------------
  // Engineer field sales (months 4 and 6), closest-to-done first.
  /// Design row P2 (`stage == clientInterviewPassed`).
  employeeAcceptOrder(
    presentationPriority: 20,
    ctaLabel: '案件を受注',
    headline: '{name}の案件を受注',
  ),
  employeeClientInterview(
    presentationPriority: 21,
    ctaLabel: '客先面談へ',
    headline: '{name}の客先面談',
  ),

  /// Design row P2 (`stage == introduced && salesRemaining > 0`).
  employeePartnerInterview(
    presentationPriority: 22,
    ctaLabel: '上位会社面談へ',
    headline: '{name}の上位会社面談',
  ),
  employeeIntroduceProject(
    presentationPriority: 23,
    ctaLabel: '案件を紹介',
    headline: '{name}に案件を紹介',
  ),
  employeeResumeSelling(
    presentationPriority: 24,
    ctaLabel: '再営業する',
    headline: '{name}を別案件へ再営業',
  ),

  /// Design row P2 (`stage == skillSheet && readyForFieldSales`).
  employeeBeginSelling(
    presentationPriority: 25,
    ctaLabel: '営業を開始',
    headline: '{name}の営業を開始',
  ),

  /// Design row P2 (`stage == waiting && readyForFieldSales`).
  employeeSkillSheetReview(
    presentationPriority: 26,
    ctaLabel: 'SkillSheetを確認',
    headline: '{name}のSkillSheetを確認',
  ),

  // Month-6 assignment: an offer already on the table, then the
  // replacement pipeline, closest-to-done first.
  assignmentAcceptNextOrder(
    presentationPriority: 27,
    ctaLabel: '発注を受注する',
    headline: '{name}の翌月分を受注',
  ),
  assignmentAcceptReplacementOrder(
    presentationPriority: 30,
    ctaLabel: '次案件を受注',
    headline: '{name}の次案件を受注',
  ),
  assignmentReplacementClientInterview(
    presentationPriority: 31,
    ctaLabel: '客先面談へ',
    headline: '{name}の客先面談（次案件）',
  ),
  assignmentReplacementPartnerInterview(
    presentationPriority: 32,
    ctaLabel: '上位会社面談へ',
    headline: '{name}の上位会社面談（次案件）',
  ),
  assignmentIntroduceReplacementProject(
    presentationPriority: 33,
    ctaLabel: '次案件を紹介',
    headline: '{name}に次案件を紹介',
  ),
  assignmentResumeReplacementSelling(
    presentationPriority: 34,
    ctaLabel: '別案件を探す',
    headline: '{name}を別案件へ営業',
  ),
  assignmentBeginReplacementSelling(
    presentationPriority: 35,
    ctaLabel: '次案件の営業へ',
    headline: '{name}の次案件の営業を開始',
  ),

  // Month-5 recruitment / pre-entry sales, closest-to-done first.
  applicantJuneOrder(
    presentationPriority: 40,
    ctaLabel: '6月分を受注',
    headline: '{name}の6月案件を受注',
  ),
  applicantClientInterview(
    presentationPriority: 41,
    ctaLabel: '客先面談へ',
    headline: '{name}の客先面談',
  ),
  applicantPartnerInterview(
    presentationPriority: 42,
    ctaLabel: '上位会社面談へ',
    headline: '{name}の上位会社面談',
  ),
  applicantIntroduceProject(
    presentationPriority: 43,
    ctaLabel: '案件を紹介',
    headline: '{name}に案件を紹介',
  ),
  applicantBeginPreEntrySelling(
    presentationPriority: 44,
    ctaLabel: '入社前営業を開始',
    headline: '{name}の入社前営業を開始',
  ),
  applicantBeginPreEntrySkillSheet(
    presentationPriority: 45,
    ctaLabel: '入社前SkillSheetへ',
    headline: '{name}の入社前SkillSheetを確認',
  ),
  applicantSalaryOffer(
    presentationPriority: 46,
    ctaLabel: '給与提示へ',
    headline: '{name}に給与を提示',
  ),
  applicantInterview(
    presentationPriority: 47,
    ctaLabel: '採用面談へ',
    headline: '{name}の採用面談',
  ),
  applicantReviewResume(
    presentationPriority: 48,
    ctaLabel: '経歴書を確認',
    headline: '{name}の経歴書を確認',
  ),

  // ---- P3: supporting work, when no pipeline needs advancing -----------
  /// Design row P3 (`nextOrderStatus == undecided`).
  assignmentConfirmNextOrder(
    presentationPriority: 50,
    ctaLabel: '発注を確認する',
    headline: '{name}の翌月分の発注を確認',
  ),

  /// Design row P3 (`canUseRecruitmentMediaInMonth(month)`).
  recruitmentMedia(
    presentationPriority: 51,
    ctaLabel: '求人媒体を開く',
    headline: '求人媒体で候補者を追加',
  );

  const HomeRecommendedActionKind({
    required this.presentationPriority,
    required this.ctaLabel,
    required String headline,
    this.informational = false,
  }) : _headline = headline;

  /// Total presentation order, **lower wins**. See the class doc for the
  /// bands and why this is presentation-only.
  final int presentationPriority;

  /// Issue #119 PLAYTHROUGH-BLOCKER-2: whether this kind only lets the
  /// player *check* something (never mutates authoritative state) rather
  /// than *do* something. `true` for exactly [cashShortageResponse] today.
  ///
  /// This is the single central classification the owner screen consults
  /// before handing outstanding actions to the Domain-owned Month Guard
  /// (`PublicDemoMonthGuard`): an informational candidate is filtered out
  /// there, so it can never produce a "recommended" month-close warning —
  /// matching the guard's own contract that an informational item never
  /// warns. [selectHomeRecommendedAction] needs no separate consult of this
  /// flag: [recoveryAssignment]'s own negative [presentationPriority]
  /// already keeps it from ever losing the recommended-action slot to
  /// [cashShortageResponse], so the ranking itself stays the single,
  /// numeric, total order it always was — see [recoveryAssignment]'s doc.
  ///
  /// A `bool` getter, not a third [PublicDemoMonthGuardLevel]-shaped enum,
  /// because this file must stay free of any dependency on `game/`/
  /// `domain/` types (see the class doc) — the Month Guard never sees a
  /// [HomeRecommendedActionKind] at all, only the plain id/name pairs the
  /// owner already filtered with this flag.
  final bool informational;

  /// Alias kept for call-site readability at consult sites outside this
  /// file (`kind.isInformational` reads better than `kind.informational`
  /// at a distance from this declaration).
  bool get isInformational => informational;

  /// The CTA button's label — the verb, kept short so the button reads at a
  /// glance.
  ///
  /// Deliberately never byte-identical to any other Public Demo label —
  /// not to the legacy button it triggers (`SkillSheetを確認` vs the employee
  /// card's `SkillSheet確認`), and not to a dialog title it opens
  /// (`給与提示へ` vs the salary dialog's `給与を提示`). The HOME shortcut and
  /// the thing it leads to are on screen together, so a player — like a
  /// test's `find.text` — must be able to tell them apart.
  final String ctaLabel;

  /// Headline template. `{name}` is substituted by [headlineFor]; kinds
  /// that address the company rather than a person carry no placeholder.
  final String _headline;

  /// Whether this kind's headline names a person.
  bool get isSubjectSpecific => _headline.contains('{name}');

  /// The player-facing "what is this about" line, e.g.
  /// `佐藤 健のSkillSheetを確認`.
  String headlineFor(String? subjectName) =>
      _headline.replaceAll('{name}', subjectName ?? '');
}

/// One recommendable action, as a pure value: what it is, and who it is
/// about. Carries no callback, so it can be compared, sorted and asserted
/// on without any of the owner's wiring.
@immutable
class HomeRecommendedAction {
  const HomeRecommendedAction({
    required this.kind,
    this.subjectName,
    this.targetId,
  });

  /// Which action this is. Typed — never a string tag.
  final HomeRecommendedActionKind kind;

  /// The person this action is about (`佐藤 健`), or `null` for the
  /// company-level kinds.
  final String? subjectName;

  /// The engineer/applicant id this action targets, or `null`. Carried for
  /// identification and testing only: the owner's handler was already bound
  /// to its own target when the candidate was emitted, so nothing
  /// downstream ever resolves an id back into a domain object.
  final String? targetId;

  /// The "what is this about" line, e.g. `佐藤 健のSkillSheetを確認`.
  String get headline => kind.headlineFor(subjectName);

  /// The CTA button's label.
  String get ctaLabel => kind.ctaLabel;

  @override
  bool operator ==(Object other) =>
      other is HomeRecommendedAction &&
      other.kind == kind &&
      other.subjectName == subjectName &&
      other.targetId == targetId;

  @override
  int get hashCode => Object.hash(kind, subjectName, targetId);

  @override
  String toString() =>
      'HomeRecommendedAction(${kind.name}, subject: $subjectName, '
      'target: $targetId)';
}

/// An eligible action **plus the owner handler that performs it**.
///
/// This is the whole dispatch mechanism, and it is deliberately not a
/// callback injection table: HOME is handed neither a map of handlers nor a
/// switch to resolve, only the one already-bound closure the corresponding
/// production button would have run. Emitting a candidate and rendering the
/// legacy button are therefore the same decision made once, at the same
/// site, over the same predicate — a candidate cannot exist for a button
/// that is not on screen, and the CTA cannot run a command the button would
/// not have run.
///
/// Every domain-side guard still runs regardless: [invoke] enters
/// `PublicDemoAggregate` through exactly the same command, so
/// `salesRemaining`, `isCloseBlocked` and `isFinanciallyRestricted` are
/// enforced by the domain exactly as before (WORKFLOW-STATE-1's "never rely
/// on UI alone").
@immutable
class HomeRecommendedActionCandidate {
  const HomeRecommendedActionCandidate({
    required this.action,
    required this.invoke,
  });

  /// What this candidate is — the pure, comparable descriptor.
  final HomeRecommendedAction action;

  /// The owner's already-bound handler. Running it is the *only* thing HOME
  /// can do with a candidate.
  final VoidCallback invoke;
}

/// What the HOME recommended-action slot must render on this build.
///
/// The owner composes this, because only the owner can see the facts that
/// distinguish the three cases. In particular
/// [HomeRecommendedActionSuppressed] names an *outcome* ("there is no next
/// action") and never its reason: `financialStatus` and
/// `fiscalYearCompleted` stay unprojected, so HOME still structurally
/// cannot render a financial verdict (FINANCE FAILURE PLAN's boundary, and
/// `public_demo_01_home_runtime_read_test.dart` test 17).
sealed class HomeRecommendedActionSlot {
  const HomeRecommendedActionSlot();
}

/// One action is eligible and should be offered with a working CTA.
final class HomeRecommendedActionAvailable extends HomeRecommendedActionSlot {
  const HomeRecommendedActionAvailable(this.candidate);

  final HomeRecommendedActionCandidate candidate;
}

/// Nothing is eligible right now: the slot falls back to the month goal,
/// exactly as the design's table specifies for its "none of the above" row.
final class HomeRecommendedActionNone extends HomeRecommendedActionSlot {
  const HomeRecommendedActionNone();
}

/// There is no next action at all (a terminal financial status, or the
/// fiscal year is over). TERMINAL PLAN: the slot is suppressed entirely
/// rather than showing a goal that can no longer be pursued.
final class HomeRecommendedActionSuppressed extends HomeRecommendedActionSlot {
  const HomeRecommendedActionSuppressed();
}

/// Picks the single action to show, from the candidates the owner emitted.
///
/// Pure and total: given the same candidate list it always returns the same
/// element, so the slot cannot flicker between two equally-good actions
/// across rebuilds. The order is
/// [HomeRecommendedActionKind.presentationPriority] first (lower wins),
/// then **emission order** — which is the owner's own
/// `workflow.engineers` / `workflow.applicants` / `workflow.assignments`
/// order, as the design requires.
///
/// Implemented as a single stable scan rather than a sort precisely so the
/// tie-break is emission order by construction and cannot be perturbed by
/// an unstable comparator.
HomeRecommendedActionCandidate? selectHomeRecommendedAction(
  Iterable<HomeRecommendedActionCandidate> candidates,
) {
  HomeRecommendedActionCandidate? best;
  for (final candidate in candidates) {
    if (best == null ||
        candidate.action.kind.presentationPriority <
            best.action.kind.presentationPriority) {
      best = candidate;
    }
  }
  return best;
}
