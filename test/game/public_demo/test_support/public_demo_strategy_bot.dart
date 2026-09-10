import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_assignment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_engineer_runtime.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_interview.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recovery.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_finance.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_sales.dart';

/// Issue #223 (FIRST-FUN-YEAR Seeded Balance Fix) Fresh Audit harness: a
/// generalization of [PublicDemoSeededPlaythroughBot]
/// (`public_demo_seeded_playthrough_bot.dart`, Issue #217/#218) that plays
/// one of four named, seed-independent DECISION POLICIES
/// ([PublicDemoStrategyKind]) instead of that bot's single fixed "recruit
/// once in May, train the moment anyone dips under threshold, accept every
/// applicant the evaluator would" policy.
///
/// Every policy still drives [PublicDemoAggregate] through ONLY real,
/// production commands — the exact same generic sales pipeline
/// (`startSkillSheetReview` -> `beginSelling` -> `introduceProject` ->
/// partner interview -> client interview -> `recordOrder`), the same
/// recruitment/pre-entry/join pipeline, and the same July-continuation /
/// month-7-14 Recovery mechanics [PublicDemoSeededPlaythroughBot] already
/// exercises. Only the DECISIONS a policy makes at each choice point differ:
/// whether/when to buy recruitment media, whether to be selective about
/// which interviewed applicant actually gets an offer, whether to keep
/// training a below-threshold waiting engineer, how large a cash buffer to
/// insist on before discretionary spending, and whether to release a
/// declined July continuation back to Sales so it can pursue a new order.
///
/// Recruitment media stays legal every month 4-8
/// ([PublicDemoState.canUseRecruitmentMediaInMonth]) and — since Issue #221/
/// #222 generalized the join step to every month-end close, not just
/// May's — a June/July/August hire now genuinely joins and gets staffed,
/// so a policy MAY recruit repeatedly across that whole window, unlike
/// [PublicDemoSeededPlaythroughBot]'s single May-only purchase (documented
/// there as a now-STALE "known limitation": see this class's own Growth
/// policy, which deliberately exploits the fixed window).
class PublicDemoStrategyBot {
  const PublicDemoStrategyBot._();

  static const int firstMonth = 4;
  static const int lastMonth = 15;

  static PublicDemoStrategyPlaythroughResult run(
    int seed,
    PublicDemoStrategyPolicy policy,
  ) {
    var aggregate = PublicDemoAggregate.initial(runSeed: seed);
    final cashByMonth = <int, int>{};
    final engagementByEngineerMonth = <String, Map<int, bool>>{};
    final hiresByMonth = <int, int>{};
    final recruitmentSpendByMonth = <int, int>{};
    var totalTrainingSpend = 0;
    int? terminalMonth;
    PublicDemoFinancialStatus? terminalStatus;
    final joinedIdsSoFar = <String>{};

    void recordEngagement(int month, Iterable<String> engagedIds, Iterable<String> rosterIds) {
      for (final id in rosterIds) {
        final byMonth = engagementByEngineerMonth.putIfAbsent(id, () => {});
        byMonth[month] = engagedIds.contains(id);
      }
    }

    void recordNewJoins(int month) {
      final joinedNow = aggregate.workflow.joinedApplicantIds
          .where((id) => !joinedIdsSoFar.contains(id))
          .toList();
      if (joinedNow.isNotEmpty) {
        hiresByMonth[month] = (hiresByMonth[month] ?? 0) + joinedNow.length;
        joinedIdsSoFar.addAll(joinedNow);
      }
    }

    for (var month = firstMonth; month <= lastMonth; month++) {
      if (aggregate.state.isCloseBlocked) break;

      if (policy.recruitMonths.contains(month)) {
        final cashBefore = aggregate.state.cash;
        aggregate = _maybeRecruit(aggregate, policy);
        final spent = cashBefore - aggregate.state.cash;
        if (spent > 0) recruitmentSpendByMonth[month] = spent;
      }

      switch (month) {
        case 4:
          aggregate = _trainThenAdvance(aggregate, policy, onTrainingSpend: (c) => totalTrainingSpend += c);
          final orderedNow = aggregate.workflow.engineers
              .where((e) => e.stage == PublicDemoSalesStage.ordered)
              .map((e) => e.id)
              .toSet();
          recordEngagement(4, orderedNow, aggregate.workflow.engineers.map((e) => e.id));
          aggregate = aggregate.closeApril(monthlyExpenses: _monthlyExpensesFor(aggregate));

        case 5:
          aggregate = _trainThenAdvance(aggregate, policy, onTrainingSpend: (c) => totalTrainingSpend += c);
          aggregate = aggregate.closeMay(week: 9, monthlyExpenses: _monthlyExpensesFor(aggregate));
          recordNewJoins(5);
          final assignedIds5 = aggregate.workflow.assignedEngineerIds(month: 5);
          recordEngagement(5, assignedIds5, aggregate.workflow.engineers.map((e) => e.id));

        case 6:
          aggregate = _trainThenAdvance(aggregate, policy, onTrainingSpend: (c) => totalTrainingSpend += c);
          aggregate = _decideJulyContinuation(aggregate);
          final assignedInJuly = aggregate.workflow.assignments
              .where(
                (a) =>
                    a.nextOrderStatus == PublicDemoNextOrderStatus.accepted ||
                    a.replacementStage == PublicDemoReplacementStage.ordered,
              )
              .length;
          aggregate = aggregate.closeJune(
            assignedInJuly: assignedInJuly,
            monthlyExpenses: _monthlyExpensesFor(aggregate),
          );
          recordNewJoins(6);
          final assignedIds6 = aggregate.workflow.assignedEngineerIds(month: 6);
          recordEngagement(6, assignedIds6, aggregate.workflow.engineers.map((e) => e.id));
          if (policy.releaseDeclinedAssignments) {
            for (final a in aggregate.workflow.assignments.toList()) {
              if (a.nextOrderStatus == PublicDemoNextOrderStatus.notOffered) {
                aggregate = aggregate.endAssignment(a.engineerId);
              }
            }
          }

        case 7:
          aggregate = _trainThenAdvance(aggregate, policy, onTrainingSpend: (c) => totalTrainingSpend += c);
          aggregate = _recoverEligibleOrders(aggregate);
          final assignedIds7 = aggregate.workflow.assignedEngineerIds(month: 7);
          recordEngagement(7, assignedIds7, aggregate.workflow.engineers.map((e) => e.id));
          aggregate = aggregate.closeJuly(monthlyExpenses: _monthlyExpensesFor(aggregate));
          recordNewJoins(7);

        default:
          aggregate = _trainThenAdvance(aggregate, policy, onTrainingSpend: (c) => totalTrainingSpend += c);
          if (PublicDemoRecoveryEligibility.isMonthEligible(month)) {
            aggregate = _recoverEligibleOrders(aggregate);
          }
          final assignedIdsN = aggregate.workflow.assignedEngineerIds(month: month);
          recordEngagement(month, assignedIdsN, aggregate.workflow.engineers.map((e) => e.id));
          aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: _monthlyExpensesFor(aggregate));
          recordNewJoins(month);
      }

      cashByMonth[month] = aggregate.state.cash;
      if (terminalMonth == null && aggregate.state.financialStatus.isTerminal) {
        terminalMonth = month;
        terminalStatus = aggregate.state.financialStatus;
      }
    }

    return PublicDemoStrategyPlaythroughResult(
      seed: seed,
      policy: policy,
      finalAggregate: aggregate,
      cashByMonth: cashByMonth,
      engagementByEngineerMonth: engagementByEngineerMonth,
      hiresByMonth: hiresByMonth,
      recruitmentSpendByMonth: recruitmentSpendByMonth,
      totalTrainingSpend: totalTrainingSpend,
      terminalMonth: terminalMonth,
      terminalStatus: terminalStatus,
      reachedMarch: aggregate.state.fiscalYearCompleted,
    );
  }

  static int _capabilityFor(PublicDemoAggregate aggregate, String engineerId) =>
      aggregate.state.runtimeForOrNull(engineerId)?.actualCapability ?? 0;

  static int _monthlyExpensesFor(PublicDemoAggregate aggregate) =>
      PublicDemoSalaryFinance.monthlyExpenses(
        baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
        hires: aggregate.workflow.joinedApplicants,
        month: aggregate.state.month,
      );

  static PublicDemoAggregate _advanceAllPossible(
    PublicDemoAggregate aggregate,
    PublicDemoStrategyPolicy policy,
  ) {
    var current = aggregate;
    final exhaustedThisMonth = <String>{};
    while (true) {
      final afterFree = _advanceFreeSteps(current, policy, exhaustedThisMonth);
      final progressedFree = !identical(afterFree, current);
      current = afterFree;
      if (current.state.salesRemaining <= 0 || current.state.fiscalYearCompleted) {
        if (!progressedFree) break;
        continue;
      }
      final afterSlot = _spendOneSlot(current, exhaustedThisMonth);
      if (identical(afterSlot, current) && !progressedFree) break;
      current = afterSlot;
    }
    return current;
  }

  static PublicDemoAggregate _advanceFreeSteps(
    PublicDemoAggregate aggregate,
    PublicDemoStrategyPolicy policy,
    Set<String> exhaustedThisMonth,
  ) {
    var current = aggregate;
    var changed = true;
    while (changed) {
      changed = false;
      for (final engineer in current.workflow.engineers) {
        final before = current;
        switch (engineer.stage) {
          case PublicDemoSalesStage.waiting:
            current = current.startSkillSheetReview(engineer.id);
          case PublicDemoSalesStage.skillSheet:
          case PublicDemoSalesStage.partnerInterviewFailed:
          case PublicDemoSalesStage.clientInterviewFailed:
            current = current.beginSelling(engineer.id);
          case PublicDemoSalesStage.selling:
            current = current.introduceProject(engineer.id);
          case PublicDemoSalesStage.partnerInterviewPassed:
            current = current.recordEngineerInterviewResult(
              engineerId: engineer.id,
              type: PublicDemoInterviewType.client,
            );
            final resultStage = current.workflow.engineers
                .firstWhere((candidate) => candidate.id == engineer.id)
                .stage;
            if (resultStage == PublicDemoSalesStage.clientInterviewFailed) {
              exhaustedThisMonth.add(engineer.id);
            }
          case PublicDemoSalesStage.clientInterviewPassed:
            current = current.recordOrder(engineer.id);
          case PublicDemoSalesStage.introduced:
          case PublicDemoSalesStage.ordered:
            break;
        }
        if (!identical(current, before)) changed = true;
      }
      for (final applicant in current.workflow.applicants) {
        final before = current;
        switch (applicant.stage) {
          case PublicDemoApplicantStage.interviewed:
            // Hire decision: a selective policy only extends the offer to
            // an applicant whose visible résumé signals clear its own bar
            // (real player judgement — never a hidden-field/omniscient
            // shortcut, only [PublicDemoApplicant.salesSkillFit]/
            // [requestedMonthlySalary], both already résumé-visible fields
            // this same generic path already reads). A non-selective policy
            // (Growth/Poor decisions) makes an offer to everyone the real
            // [PublicDemoSalaryOfferEvaluator] says would accept, exactly
            // like the original [PublicDemoSeededPlaythroughBot].
            final passesSelection = !policy.selectiveHiring ||
                (applicant.salesSkillFit >= policy.minQualityForHire &&
                    applicant.requestedMonthlySalary <= policy.maxSalaryForHire);
            if (passesSelection) {
              final offer = PublicDemoSalaryOfferEvaluator.evaluate(
                applicant: applicant,
                offeredMonthlySalary: applicant.requestedMonthlySalary,
              );
              if (offer.accepted) {
                current = current.acceptOffer(
                  applicantId: applicant.id,
                  offer: offer,
                  fiscalCloseId: PublicDemoFiscalCloseId.forMonth(current.state.month),
                );
              }
            }
          case PublicDemoApplicantStage.offerAccepted:
            current = current.beginPreEntrySkillSheet(applicant.id);
          case PublicDemoApplicantStage.preEntrySkillSheet:
            current = current.beginPreEntrySelling(applicant.id);
          case PublicDemoApplicantStage.preEntrySelling:
            current = current.introducePreEntryProject(applicant.id);
          case PublicDemoApplicantStage.preEntryPartnerPassed:
            current = current.recordPreEntryClientInterviewResult(applicant.id);
          case PublicDemoApplicantStage.preEntryClientPassed:
            current = current.recordJuneOrder(applicant.id);
          case PublicDemoApplicantStage.preEntryPartnerFailed:
          case PublicDemoApplicantStage.preEntryClientFailed:
            break;
          case PublicDemoApplicantStage.applied:
          case PublicDemoApplicantStage.resumeReviewed:
          case PublicDemoApplicantStage.rejected:
          case PublicDemoApplicantStage.offerDeclined:
          case PublicDemoApplicantStage.preEntryIntroduced:
          case PublicDemoApplicantStage.juneOrdered:
            break;
        }
        if (!identical(current, before)) changed = true;
      }
    }
    return current;
  }

  static PublicDemoAggregate _spendOneSlot(
    PublicDemoAggregate aggregate,
    Set<String> exhaustedThisMonth,
  ) {
    for (final engineer in aggregate.workflow.engineers) {
      if (engineer.stage == PublicDemoSalesStage.introduced &&
          !exhaustedThisMonth.contains(engineer.id)) {
        final next = aggregate.recordEngineerInterviewResult(
          engineerId: engineer.id,
          type: PublicDemoInterviewType.partner,
        );
        final resultStage = next.workflow.engineers
            .firstWhere((candidate) => candidate.id == engineer.id)
            .stage;
        if (resultStage == PublicDemoSalesStage.partnerInterviewFailed) {
          exhaustedThisMonth.add(engineer.id);
        }
        return next;
      }
    }
    for (final applicant in aggregate.workflow.applicants) {
      if (applicant.stage == PublicDemoApplicantStage.applied) {
        final result = aggregate.completeInterview(applicant.id);
        return result.aggregate;
      }
    }
    for (final applicant in aggregate.workflow.applicants) {
      if (applicant.stage == PublicDemoApplicantStage.preEntryIntroduced) {
        return aggregate.recordPreEntryPartnerInterviewResult(applicant.id);
      }
    }
    return aggregate;
  }

  static PublicDemoAggregate _maybeRecruit(
    PublicDemoAggregate aggregate,
    PublicDemoStrategyPolicy policy,
  ) {
    if (aggregate.state.isFinanciallyRestricted) return aggregate;
    if (!aggregate.state.canUseRecruitmentMediaInMonth(aggregate.state.month)) {
      return aggregate;
    }
    const medium = PublicDemoRecruitmentMedium.engineer;
    if (!policy.ignoreCashBufferForRecruitment &&
        aggregate.state.cash - medium.cost < policy.cashBufferForDiscretionarySpend) {
      return aggregate;
    }
    if (aggregate.state.cash < medium.cost) return aggregate;
    final result = aggregate.recruit(medium);
    return result.aggregate ?? aggregate;
  }

  static PublicDemoAggregate _trainThenAdvance(
    PublicDemoAggregate aggregate,
    PublicDemoStrategyPolicy policy, {
    required void Function(int cost) onTrainingSpend,
  }) {
    var current = aggregate;
    if (policy.trainWaitingEngineers) {
      final assignedIds = current.workflow.assignedEngineerIds(month: current.state.month);
      for (final engineer in current.workflow.engineers) {
        if (assignedIds.contains(engineer.id)) continue;
        if (current.state.trainingSelections.containsKey(engineer.id)) continue;
        if (_capabilityFor(current, engineer.id) >=
            PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement) {
          continue;
        }
        if (current.state.isFinanciallyRestricted) continue;
        if (!policy.ignoreCashBufferForRecruitment &&
            current.state.cash - 30000 < policy.cashBufferForDiscretionarySpend) {
          continue;
        }
        if (current.state.cash < 30000) continue;
        final before = current.state.cash;
        current = current.selectInternalTraining(engineer.id);
        onTrainingSpend(before - current.state.cash);
      }
    }
    return _advanceAllPossible(current, policy);
  }

  static PublicDemoAggregate _decideJulyContinuation(PublicDemoAggregate aggregate) {
    var current = aggregate;
    for (final assignment in current.workflow.assignments) {
      if (assignment.nextOrderStatus != PublicDemoNextOrderStatus.undecided) {
        continue;
      }
      final willOffer = assignment.willOfferNextMonthFor(
        _capabilityFor(current, assignment.engineerId),
      );
      current = current.withAssignmentUpdate(
        assignment.engineerId,
        nextOrderStatus: willOffer
            ? PublicDemoNextOrderStatus.offered
            : PublicDemoNextOrderStatus.notOffered,
      );
      if (willOffer) {
        current = current.withAssignmentUpdate(
          assignment.engineerId,
          nextOrderStatus: PublicDemoNextOrderStatus.accepted,
        );
      }
    }
    return current;
  }

  static PublicDemoAggregate _recoverEligibleOrders(PublicDemoAggregate aggregate) {
    var current = aggregate;
    for (final engineer in current.workflow.engineers) {
      if (engineer.stage != PublicDemoSalesStage.ordered) continue;
      current = current.recoverAssignment(engineer.id);
    }
    return current;
  }
}

/// Names the four Fresh-Audit decision policies Issue #223 requires
/// ("A. Conservative", "B. Balanced", "C. Growth", "D. Poor decisions") —
/// every field is a real decision a player makes with the same
/// résumé-visible information a human player has, never a hidden-field or
/// omniscient shortcut.
enum PublicDemoStrategyKind { conservative, balanced, growth, poorDecisions }

class PublicDemoStrategyPolicy {
  const PublicDemoStrategyPolicy({
    required this.kind,
    required this.recruitMonths,
    required this.selectiveHiring,
    required this.minQualityForHire,
    required this.maxSalaryForHire,
    required this.cashBufferForDiscretionarySpend,
    required this.trainWaitingEngineers,
    required this.releaseDeclinedAssignments,
    this.ignoreCashBufferForRecruitment = false,
  });

  final PublicDemoStrategyKind kind;

  /// Internal months (4-8, the real [PublicDemoState
  /// .canUseRecruitmentMediaInMonth] window) this policy attempts an
  /// engineer-medium purchase in — empty for Conservative.
  final Set<int> recruitMonths;

  /// Whether this policy only extends an offer to an interviewed applicant
  /// clearing [minQualityForHire]/[maxSalaryForHire], instead of offering to
  /// every applicant the real [PublicDemoSalaryOfferEvaluator] says would
  /// accept.
  final bool selectiveHiring;
  final int minQualityForHire;
  final int maxSalaryForHire;

  /// Cash buffer this policy insists on keeping before a discretionary
  /// (recruitment/training) spend — mirrors [PublicDemoSeededPlaythroughBot
  /// ._minimumCashBufferForDiscretionarySpend], but tunable per policy so
  /// "Poor decisions" can model a player with no such discipline.
  final int cashBufferForDiscretionarySpend;

  /// Whether this policy keeps training any waiting, below-threshold
  /// engineer back into field-sales eligibility. "Poor decisions" leaves a
  /// below-threshold hire (e.g. Suzuki) untrained — a real, understandable
  /// failure mode (待機放置), not a synthetic penalty.
  final bool trainWaitingEngineers;

  /// Whether this policy releases a declined July continuation back to
  /// Sales ([PublicDemoAggregate.endAssignment]) so it can pursue a new
  /// order. "Poor decisions" leaves it parked instead.
  final bool releaseDeclinedAssignments;

  /// "Poor decisions" only: spends on recruitment even when doing so would
  /// leave cash below [cashBufferForDiscretionarySpend] (still refuses an
  /// outright-unaffordable purchase — the real
  /// [PublicDemoRecruitmentCalculation] cash guard is never bypassed).
  final bool ignoreCashBufferForRecruitment;

  static const conservative = PublicDemoStrategyPolicy(
    kind: PublicDemoStrategyKind.conservative,
    recruitMonths: {},
    selectiveHiring: false,
    minQualityForHire: 0,
    maxSalaryForHire: 0,
    cashBufferForDiscretionarySpend: 300000,
    trainWaitingEngineers: true,
    releaseDeclinedAssignments: true,
  );

  static const balanced = PublicDemoStrategyPolicy(
    kind: PublicDemoStrategyKind.balanced,
    recruitMonths: {5},
    selectiveHiring: true,
    minQualityForHire: 45,
    maxSalaryForHire: 380000,
    cashBufferForDiscretionarySpend: 300000,
    trainWaitingEngineers: true,
    releaseDeclinedAssignments: true,
  );

  static const growth = PublicDemoStrategyPolicy(
    kind: PublicDemoStrategyKind.growth,
    recruitMonths: {4, 5, 6, 7, 8},
    selectiveHiring: false,
    minQualityForHire: 0,
    maxSalaryForHire: 1000000,
    cashBufferForDiscretionarySpend: 150000,
    trainWaitingEngineers: true,
    releaseDeclinedAssignments: true,
  );

  static const poorDecisions = PublicDemoStrategyPolicy(
    kind: PublicDemoStrategyKind.poorDecisions,
    recruitMonths: {4, 5, 6, 7, 8},
    selectiveHiring: false,
    minQualityForHire: 0,
    maxSalaryForHire: 1000000,
    cashBufferForDiscretionarySpend: 0,
    trainWaitingEngineers: false,
    releaseDeclinedAssignments: false,
    ignoreCashBufferForRecruitment: true,
  );

  static const all = [conservative, balanced, growth, poorDecisions];
}

class PublicDemoStrategyPlaythroughResult {
  const PublicDemoStrategyPlaythroughResult({
    required this.seed,
    required this.policy,
    required this.finalAggregate,
    required this.cashByMonth,
    required this.engagementByEngineerMonth,
    required this.hiresByMonth,
    required this.recruitmentSpendByMonth,
    required this.totalTrainingSpend,
    required this.terminalMonth,
    required this.terminalStatus,
    required this.reachedMarch,
  });

  final int seed;
  final PublicDemoStrategyPolicy policy;
  final PublicDemoAggregate finalAggregate;
  final Map<int, int> cashByMonth;
  final Map<String, Map<int, bool>> engagementByEngineerMonth;
  final Map<int, int> hiresByMonth;
  final Map<int, int> recruitmentSpendByMonth;
  final int totalTrainingSpend;
  final int? terminalMonth;
  final PublicDemoFinancialStatus? terminalStatus;
  final bool reachedMarch;

  bool get wentBankrupt => terminalStatus == PublicDemoFinancialStatus.bankruptcy;
  bool get failedMarchCashShortage =>
      terminalStatus == PublicDemoFinancialStatus.marchCashShortageFailure;

  int get totalHires => hiresByMonth.values.fold(0, (a, b) => a + b);
  int get totalRecruitmentSpend =>
      recruitmentSpendByMonth.values.fold(0, (a, b) => a + b);

  int get minCash =>
      cashByMonth.values.isEmpty ? 0 : cashByMonth.values.reduce((a, b) => a < b ? a : b);

  /// The first internal month any hire actually joined, or null if nobody
  /// besides the founding pair ever joined.
  int? get firstHireMonth {
    if (hiresByMonth.isEmpty) return null;
    return hiresByMonth.keys.reduce((a, b) => a < b ? a : b);
  }

  int longestNoOrderStreak(String engineerId) {
    final byMonth = engagementByEngineerMonth[engineerId];
    if (byMonth == null || byMonth.isEmpty) return 0;
    final months = byMonth.keys.toList()..sort();
    var longest = 0;
    var current = 0;
    for (final month in months) {
      if (byMonth[month] == false) {
        current += 1;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }
    return longest;
  }
}
