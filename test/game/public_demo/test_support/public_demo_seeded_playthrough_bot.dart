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

/// CORE-GAMEPLAY Phase 8 (Seeded Balance Verification, Issue #217): a
/// deterministic, non-UI "rational player" bot that drives
/// [PublicDemoAggregate] through a complete April->March First Fun Year
/// using only real, production [PublicDemoAggregate] commands — never a
/// reconstruction shortcut or a fabricated intermediate state, exactly like
/// every other Public Demo test fixture in this suite (see
/// `public_demo_recovery_test_helpers.dart`'s own class doc for the same
/// convention).
///
/// SCOPE / WHAT THIS POLICY DOES:
/// - Every founding/joined engineer works the existing, unchanged generic
///   sales pipeline (`startSkillSheetReview` -> `beginSelling` ->
///   `introduceProject` -> partner interview -> client interview ->
///   `recordOrder`) — the SAME path `public_demo_balance_regression_test
///   .dart` and the UI success-playthrough test already exercise, and a
///   real production path (not a test-only shortcut).
/// - Recruits exactly once, in May, via [PublicDemoRecruitmentMedium
///   .engineer] — see the class-level "KNOWN LIMITATION" note below for
///   why recruiting again after May is deliberately NOT modeled.
/// - Uses internal training (`selectInternalTraining`) on any waiting,
///   unassigned engineer below [PublicDemoEngineerRuntime
///   .fieldSalesCapabilityRequirement] (60) — the real, cheap (¥30,000)
///   production path back into field-sales eligibility for an
///   under-threshold engineer (e.g. Suzuki's initial 52) who is not
///   currently earning assignment-sourced Growth.
/// - Decides July continuation for every June-era assignment via the real,
///   pure [PublicDemoAssignment.willOfferNextMonthFor]/`decideOrder`/
///   `acceptOrder` sequence (WORKFLOW-STATE-1's own June decision), then
///   releases any declined assignment back to Sales via `endAssignment` so
///   that engineer can pursue an entirely new, real order.
/// - Uses [PublicDemoRecoveryEligibility]'s real month-7-14 window
///   (`recoverAssignment`) for a waiting engineer who lands a fresh order
///   after May.
///
/// KNOWN LIMITATION (documented, not silently assumed): this bot never
/// calls `proposeMatch`/`startProjectInterview`/`concludeProjectInterview`
/// (the Phase 5/6 Matching + Project Interview flow) — it always uses the
/// pre-existing generic interview path. Both paths are real production
/// paths; the generic path is the one every pre-existing Public Demo
/// balance fixture already uses. See the Phase 8 result report for the
/// reasoning and for a direct (non-simulated) check of the Matching/
/// project-generator data this bot's own path does not exercise.
///
/// KNOWN LIMITATION (a real, confirmed finding, not a simulation gap): a
/// [PublicDemoRecruitmentMedium] purchase after May (the domain allows one
/// every month through August) generates real applicants that can be
/// walked through the ENTIRE hire/pre-entry/order pipeline to
/// `juneOrdered`, but [PublicDemoWorkflowState.joinAndKeepOnly] /
/// [PublicDemoWorkflowState.withJoinedEngineers] /
/// [PublicDemoWorkflowState.assignOrderedForMay] are only ever invoked from
/// [PublicDemoAggregate.closeMay] — there is no production code path that
/// ever joins a June/July/August-recruited applicant as an engineer. This
/// bot therefore never recruits after May: doing so would only spend real
/// cash/sales-slot budget for zero possible return, which is not
/// "rational player" behavior once this is known. See the Phase 8 result
/// report §"Post-May recruitment dead end" for the direct reproduction.
class PublicDemoSeededPlaythroughBot {
  const PublicDemoSeededPlaythroughBot._();

  static const int firstMonth = 4;
  static const int lastMonth = 15;

  /// A cash buffer this bot insists on keeping before spending on
  /// recruitment/training — a real player would not spend the company into
  /// [PublicDemoState.isFinanciallyRestricted] purely to buy training a
  /// month earlier.
  static const int _minimumCashBufferForDiscretionarySpend = 200000;

  static PublicDemoSeededPlaythroughResult run(int seed) {
    var aggregate = PublicDemoAggregate.initial(runSeed: seed);
    final cashByMonth = <int, int>{};
    final engagementByEngineerMonth = <String, Map<int, bool>>{};
    final log = <String>[];
    int? terminalMonth;
    PublicDemoFinancialStatus? terminalStatus;
    int engineersJoinedInMay = 0;
    int monthlyExpenses = PublicDemoSalary.baselineMonthlyExpenses;

    void recordEngagement(int month, Iterable<String> engagedIds, Iterable<String> rosterIds) {
      for (final id in rosterIds) {
        final byMonth = engagementByEngineerMonth.putIfAbsent(id, () => {});
        byMonth[month] = engagedIds.contains(id);
      }
    }

    for (var month = firstMonth; month <= lastMonth; month++) {
      if (aggregate.state.isCloseBlocked) {
        // A terminal financial status freezes the month; every further
        // close is a real, unchanged no-op. Stop driving actions too —
        // there is nothing left a rational player could do.
        break;
      }

      switch (month) {
        case 4:
          aggregate = _trainThenAdvance(aggregate);
          final orderedNow = aggregate.workflow.engineers
              .where((e) => e.stage == PublicDemoSalesStage.ordered)
              .map((e) => e.id)
              .toSet();
          recordEngagement(
            4,
            orderedNow,
            aggregate.workflow.engineers.map((e) => e.id),
          );
          aggregate = aggregate.closeApril(monthlyExpenses: monthlyExpenses);

        case 5:
          aggregate = _maybeRecruit(aggregate, log);
          aggregate = _trainThenAdvance(aggregate);
          final hires = aggregate.workflow.applicants
              .where(
                (applicant) => const {
                  PublicDemoApplicantStage.offerAccepted,
                  PublicDemoApplicantStage.preEntrySkillSheet,
                  PublicDemoApplicantStage.preEntrySelling,
                  PublicDemoApplicantStage.preEntryIntroduced,
                  PublicDemoApplicantStage.preEntryPartnerPassed,
                  PublicDemoApplicantStage.preEntryPartnerFailed,
                  PublicDemoApplicantStage.preEntryClientPassed,
                  PublicDemoApplicantStage.preEntryClientFailed,
                  PublicDemoApplicantStage.juneOrdered,
                }.contains(applicant.stage),
              )
              .toList();
          monthlyExpenses = PublicDemoSalaryFinance.monthlyExpenses(
            baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses,
            hires: hires,
          );
          aggregate = aggregate.closeMay(week: 9, monthlyExpenses: monthlyExpenses);
          engineersJoinedInMay = aggregate.workflow.joinedApplicantIds.length;
          final assignedIds5 = aggregate.workflow.assignedEngineerIds(month: 5);
          recordEngagement(
            5,
            assignedIds5,
            aggregate.workflow.engineers.map((e) => e.id),
          );

        case 6:
          aggregate = _trainThenAdvance(aggregate);
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
            monthlyExpenses: monthlyExpenses,
          );
          final assignedIds6 = aggregate.workflow.assignedEngineerIds(month: 6);
          recordEngagement(
            6,
            assignedIds6,
            aggregate.workflow.engineers.map((e) => e.id),
          );
          // Release every declined continuation back to Sales immediately
          // (Phase 7A's real end->available->re-entry lifecycle) so it can
          // pursue an entirely new real order from July onward.
          for (final a in aggregate.workflow.assignments.toList()) {
            if (a.nextOrderStatus == PublicDemoNextOrderStatus.notOffered) {
              aggregate = aggregate.endAssignment(a.engineerId);
            }
          }

        case 7:
          aggregate = _trainThenAdvance(aggregate);
          aggregate = _recoverEligibleOrders(aggregate);
          final assignedIds7 = aggregate.workflow.assignedEngineerIds(month: 7);
          recordEngagement(
            7,
            assignedIds7,
            aggregate.workflow.engineers.map((e) => e.id),
          );
          aggregate = aggregate.closeJuly(monthlyExpenses: monthlyExpenses);

        default:
          aggregate = _trainThenAdvance(aggregate);
          if (PublicDemoRecoveryEligibility.isMonthEligible(month)) {
            aggregate = _recoverEligibleOrders(aggregate);
          }
          final assignedIdsN = aggregate.workflow.assignedEngineerIds(month: month);
          recordEngagement(
            month,
            assignedIdsN,
            aggregate.workflow.engineers.map((e) => e.id),
          );
          aggregate = aggregate.closeOrdinaryMonth(monthlyExpenses: monthlyExpenses);
      }

      cashByMonth[month] = aggregate.state.cash;
      if (terminalMonth == null && aggregate.state.financialStatus.isTerminal) {
        terminalMonth = month;
        terminalStatus = aggregate.state.financialStatus;
      }
    }

    return PublicDemoSeededPlaythroughResult(
      seed: seed,
      finalAggregate: aggregate,
      cashByMonth: cashByMonth,
      engagementByEngineerMonth: engagementByEngineerMonth,
      terminalMonth: terminalMonth,
      terminalStatus: terminalStatus,
      reachedMarch: aggregate.state.fiscalYearCompleted,
      engineersJoinedInMay: engineersJoinedInMay,
      log: log,
    );
  }

  static int _capabilityFor(PublicDemoAggregate aggregate, String engineerId) =>
      aggregate.state.runtimeForOrNull(engineerId)?.actualCapability ?? 0;

  /// Runs every currently-free (no sales-slot cost) stage advance to a
  /// fixed point, then spends the month's remaining real sales-slot budget
  /// ([PublicDemoState.salesRemaining]) on the highest-priority
  /// slot-costing action (an engineer's partner interview, an applicant's
  /// paperwork interview, or an applicant's pre-entry partner interview),
  /// re-running the free-advance pass after each spend — exactly mirroring
  /// how a player would work through a month's queue.
  ///
  /// [PublicDemoInterviewEvaluator.evaluate] (the real partner/client
  /// interview scoring) is a pure function of the engineer/applicant's own
  /// fixed [PublicDemoInterviewProfile] plus their CURRENT
  /// [PublicDemoEngineerRuntime.actualCapability] — nothing about it
  /// changes within a single month once training/Growth has already been
  /// applied for that month. So a partner interview that fails once is
  /// GUARANTEED to fail again if retried immediately (the free
  /// `beginSelling`/`introduceProject` re-cycle back to `introduced` costs
  /// nothing and would otherwise let this bot burn the ENTIRE month's real
  /// sales-slot budget re-attempting the exact same guaranteed failure,
  /// starving every other candidate). [partnerAttemptFailedThisMonth]
  /// tracks every id whose partner interview has already failed once this
  /// month — and, symmetrically, whose PASSED partner interview was then
  /// followed by a FAILED client interview this month (the free
  /// `beginSelling`/`introduceProject` re-cycle from `clientInterviewFailed`
  /// would otherwise send them straight back to `introduced`, where
  /// [_spendOneSlot] would spend another slot re-passing the exact same
  /// guaranteed partner interview only to hit the exact same guaranteed
  /// client-interview failure again — a real, confirmed bug this bot's
  /// first version had: see the Phase 8 result report for the
  /// reproduction) — so [_spendOneSlot] moves on to the next candidate
  /// instead. A real retry only ever makes sense in a LATER month, after
  /// training/Growth has actually changed `actualCapability`.
  static PublicDemoAggregate _advanceAllPossible(PublicDemoAggregate aggregate) {
    var current = aggregate;
    final exhaustedThisMonth = <String>{};
    while (true) {
      final afterFree = _advanceFreeSteps(current, exhaustedThisMonth);
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
            // Hire decision: accept at the requested salary whenever the
            // real PublicDemoSalaryOfferEvaluator says the applicant would
            // accept it — never a caller-invented acceptance rule.
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
            // No free retry defined for pre-entry failures in this Public
            // Demo build (unlike engineers' beginSelling retry) — left as a
            // genuine, real dead-end-for-this-candidate fact, not one this
            // bot papers over.
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

  /// Spends exactly one real sales slot on the single highest-priority
  /// slot-costing action available this month, or returns [aggregate]
  /// unchanged if none is available. [exhaustedThisMonth] is mutated in
  /// place: an engineer whose partner interview fails here is added to it
  /// so this same guaranteed-to-fail-again attempt is never repeated later
  /// in the same month (see [_advanceAllPossible]'s own doc for why
  /// retrying is pointless within one month, and for the symmetric client-
  /// interview-failure case [_advanceFreeSteps] adds to this same set).
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
    List<String> log,
  ) {
    if (aggregate.state.isFinanciallyRestricted) return aggregate;
    if (!aggregate.state.canUseRecruitmentMediaInMonth(aggregate.state.month)) {
      return aggregate;
    }
    const medium = PublicDemoRecruitmentMedium.engineer;
    if (aggregate.state.cash - medium.cost < _minimumCashBufferForDiscretionarySpend) {
      log.add('month ${aggregate.state.month}: skipped recruiting (cash buffer)');
      return aggregate;
    }
    final result = aggregate.recruit(medium);
    if (result.aggregate == null) {
      log.add('month ${aggregate.state.month}: recruit() failed: ${result.status}');
      return aggregate;
    }
    return result.aggregate!;
  }

  /// Trains any waiting, unassigned, still-under-threshold engineer
  /// (real, cheap production path back to field-sales eligibility) before
  /// running this month's free/paid sales-pipeline advance.
  static PublicDemoAggregate _trainThenAdvance(PublicDemoAggregate aggregate) {
    var current = aggregate;
    final assignedIds = current.workflow.assignedEngineerIds(month: current.state.month);
    for (final engineer in current.workflow.engineers) {
      if (assignedIds.contains(engineer.id)) continue;
      if (current.state.trainingSelections.containsKey(engineer.id)) continue;
      if (_capabilityFor(current, engineer.id) >=
          PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement) {
        continue;
      }
      if (current.state.isFinanciallyRestricted) continue;
      if (current.state.cash - 30000 < _minimumCashBufferForDiscretionarySpend) continue;
      current = current.selectInternalTraining(engineer.id);
    }
    return _advanceAllPossible(current);
  }

  /// Applies the real, pure July-continuation decision
  /// ([PublicDemoAssignment.willOfferNextMonthFor]) to every June-era
  /// assignment, then immediately accepts every genuine offer — the same
  /// two-step `decideOrder`/`acceptOrder` sequence
  /// `public_demo_01_placeholder_screen.dart`'s own `decideOrder`/
  /// `acceptOrder` handlers perform, reached here directly through
  /// [PublicDemoAggregate.withAssignmentUpdate] rather than a widget tap.
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

  /// The month-7-14 Recovery pickup (RECOVERY-LOOP-1): any waiting engineer
  /// who has genuinely reached `ordered` is committed into a real
  /// assignment via [PublicDemoAggregate.recoverAssignment] — a no-op for
  /// anyone [PublicDemoRecoveryEligibility.isEligible] does not (yet, or
  /// ever, this month) allow, most commonly because
  /// [PublicDemoEngineerRuntime.isReadyForFieldSales] is still false.
  static PublicDemoAggregate _recoverEligibleOrders(PublicDemoAggregate aggregate) {
    var current = aggregate;
    for (final engineer in current.workflow.engineers) {
      if (engineer.stage != PublicDemoSalesStage.ordered) continue;
      current = current.recoverAssignment(engineer.id);
    }
    return current;
  }
}

class PublicDemoSeededPlaythroughResult {
  const PublicDemoSeededPlaythroughResult({
    required this.seed,
    required this.finalAggregate,
    required this.cashByMonth,
    required this.engagementByEngineerMonth,
    required this.terminalMonth,
    required this.terminalStatus,
    required this.reachedMarch,
    required this.engineersJoinedInMay,
    required this.log,
  });

  final int seed;
  final PublicDemoAggregate finalAggregate;

  /// Cash immediately after each internal month's close, keyed by that
  /// internal month (4-15). Stops advancing (map simply has no further
  /// entries) once [terminalMonth] freezes the fiscal year.
  final Map<int, int> cashByMonth;

  /// For every engineer id that ever appeared on the roster: per internal
  /// month, whether that engineer had a real order/assignment that month.
  /// Month 4 measures `stage == ordered` (April's own order is the
  /// predictor for May's assignment roster, since assignments do not exist
  /// until `closeMay`); month 5 onward measures
  /// `PublicDemoWorkflowState.assignedEngineerIds(month:)`.
  final Map<String, Map<int, bool>> engagementByEngineerMonth;

  /// The first internal month whose close left [PublicDemoFinancialStatus
  /// .isTerminal] true, or `null` if the fiscal year completed without
  /// ever reaching a terminal status.
  final int? terminalMonth;
  final PublicDemoFinancialStatus? terminalStatus;

  /// Whether [PublicDemoState.fiscalYearCompleted] was reached (March
  /// closed without a terminal financial status).
  final bool reachedMarch;

  final int engineersJoinedInMay;

  final List<String> log;

  bool get wentBankrupt => terminalStatus == PublicDemoFinancialStatus.bankruptcy;
  bool get failedMarchCashShortage =>
      terminalStatus == PublicDemoFinancialStatus.marchCashShortageFailure;

  /// The longest run of consecutive no-order months for [engineerId], only
  /// counting months from the first month that engineer actually appears
  /// on the roster (so a May hire's April absence is never counted as a
  /// "no-order" month for them) through the last month this playthrough
  /// actually reached.
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

  Map<String, int> get longestNoOrderStreakByEngineer => {
    for (final id in engagementByEngineerMonth.keys) id: longestNoOrderStreak(id),
  };
}
