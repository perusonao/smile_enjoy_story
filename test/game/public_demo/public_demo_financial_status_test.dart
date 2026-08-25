import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_aggregate.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_fiscal_close_id.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_internal_training_transaction.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_monthly_close.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment_medium.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary_offer.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_snapshot.dart';

/// FINANCE-FAILURE-1A+1B: the approved Candidate B'.1 contract — atomic
/// monthly-close shortage/recovery/bankruptcy, March's terminal priority,
/// July's no-rollback fix, and the recruitment/offer/training shortage
/// gates. This file covers the required test matrix
/// (SES_FINANCE-FAILURE-1AB task §23 A-Y); existing regression suites
/// (public_demo_monthly_close_test.dart, _revenue_test.dart,
/// _ordinary_month_test.dart, public_demo_summer_bonus_payment_test.dart,
/// public_demo_fiscal_year_save_test.dart, ...) already cover Revenue,
/// 30-day AR, Growth, salary, fixed costs, and cash-flow reconciliation on
/// their own and are not re-derived here.
///
/// A/B/C/D/E-H/I-M use a pure [PublicDemoState] fixture, matching the style
/// already established by public_demo_monthly_close_ordinary_month_test
/// .dart. N onward need a real, authoritative [PublicDemoAggregate] (the
/// financial-action gates live on it) — [PublicDemoAggregate] deliberately
/// exposes no way to inject an arbitrary [PublicDemoState]/
/// [PublicDemoWorkflowState] (see its own class doc), so
/// [_reachShortageAggregate] below builds a genuine shortage the same way
/// production code would: closing April through July with zero orders,
/// which is exactly enough real deficit (Revenue never exceeds the
/// founding team's fixed payroll+overhead when nobody is assigned) to
/// reach CASH SHORTAGE by August with no fixture shortcut.
void main() {
  PublicDemoState fixture({
    required int month,
    required int cash,
    int pendingRevenue = 0,
    int engineersAssigned = 0,
    PublicDemoFinancialStatus financialStatus =
        PublicDemoFinancialStatus.normal,
    PublicDemoSummerBonusPlan summerBonusSelection =
        PublicDemoSummerBonusPlan.none,
  }) => PublicDemoState(
    month: month,
    cash: cash,
    engineerCount: engineersAssigned + 1,
    adminCount: 1,
    salesCapacity: 4,
    salesUsed: 0,
    engineersWaiting: 1,
    engineersAssigned: engineersAssigned,
    pendingRevenue: pendingRevenue,
    financialStatus: financialStatus,
  ).copyWith(summerBonusSelection: summerBonusSelection);

  group('A/B/C. Non-March shortage -> recovery -> bankruptcy contract', () {
    test('A: first non-March negative close commits negative cash as '
        'CASH SHORTAGE, not a rollback', () {
      final start = fixture(month: 9, cash: 100000);
      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: start,
        monthlyExpenses: 800000,
      );
      expect(result.isClosed, isTrue, reason: 'the close still commits');
      expect(result.state.cash, -700000);
      expect(
        result.state.financialStatus,
        PublicDemoFinancialStatus.cashShortage,
      );
      expect(result.state.month, 10);
      expect(result.state.isFinanciallyTerminal, isFalse);
      expect(result.state.isCloseBlocked, isFalse, reason: 'not terminal');
    });

    test('B: shortage + next close non-negative -> RECOVERED / NORMAL, '
        'gameplay continues (prior AR settles normally)', () {
      final shortage = fixture(
        month: 10,
        cash: -700000,
        pendingRevenue: 1600000,
        financialStatus: PublicDemoFinancialStatus.cashShortage,
      );
      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: shortage,
        monthlyExpenses: 800000,
      );
      expect(result.isClosed, isTrue);
      expect(result.state.cash, -700000 + 1600000 - 800000);
      expect(result.state.cash, greaterThanOrEqualTo(0));
      expect(result.state.financialStatus, PublicDemoFinancialStatus.normal);
      expect(result.state.isCloseBlocked, isFalse);
    });

    test('C: shortage + next close still negative -> BANKRUPTCY, the '
        'close itself still commits exactly once (no rollback of AR/'
        'expenses/cash)', () {
      final shortage = fixture(
        month: 10,
        cash: -700000,
        pendingRevenue: 200000,
        financialStatus: PublicDemoFinancialStatus.cashShortage,
      );
      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: shortage,
        monthlyExpenses: 800000,
      );
      expect(
        result.isClosed,
        isTrue,
        reason: 'bankruptcy is a committed close, not a rollback',
      );
      expect(result.state.cash, -700000 + 200000 - 800000);
      expect(
        result.state.financialStatus,
        PublicDemoFinancialStatus.bankruptcy,
      );
      expect(result.state.isFinanciallyTerminal, isTrue);
      expect(result.state.month, 11, reason: 'month still advances');
    });
  });

  group('D/X. Pre-AR idempotency and terminal-retry no-op', () {
    test('D: retrying the same monthly close (aggregate no longer at the '
        'required month) is a complete no-op — no duplicate AR, salary, '
        'Growth, or cash-flow record', () {
      final game = PublicDemoAggregate.initial().closeApril(
        monthlyExpenses: 800000,
      );
      final onceClosed = game.closeMay(week: 9, monthlyExpenses: 800000);
      final retried = onceClosed.closeMay(week: 9, monthlyExpenses: 800000);
      expect(retried.state.cash, onceClosed.state.cash);
      expect(
        retried.state.growthAppliedMonths,
        onceClosed.state.growthAppliedMonths,
      );
      expect(
        retried.state.latestMonthlyCashFlow?.toJson(),
        onceClosed.state.latestMonthlyCashFlow?.toJson(),
      );
      expect(retried.workflow.assignments, onceClosed.workflow.assignments);
    });

    test('X: once terminal (bankruptcy), retrying the monthly close is a '
        'structural no-op at the pre-AR guard — no cash movement, no '
        'Growth, no cash-flow record, terminal status stays stable', () {
      final bankruptState = fixture(
        month: 10,
        cash: -700000,
        financialStatus: PublicDemoFinancialStatus.bankruptcy,
      );
      final retry = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: bankruptState,
        monthlyExpenses: 800000,
      );
      expect(retry.isClosed, isFalse);
      expect(retry.state.cash, bankruptState.cash);
      expect(retry.state.month, bankruptState.month);
      expect(retry.state.latestMonthlyCashFlow, isNull);
      expect(retry.state.financialStatus, PublicDemoFinancialStatus.bankruptcy);

      // The same guard on the real aggregate command surface: driven to a
      // genuine bankruptcy via real closes, closeOrdinaryMonth is then a
      // complete no-op no matter how many times it is retried.
      final bankrupt = _reachBankruptAggregate();
      final again = bankrupt.closeOrdinaryMonth(monthlyExpenses: 800000);
      expect(again.state.cash, bankrupt.state.cash);
      expect(again.state.month, bankrupt.state.month);
      expect(again.state.financialStatus, PublicDemoFinancialStatus.bankruptcy);
    });
  });

  group('E/F/G/H. July — critical P0 area (no legacy rollback)', () {
    test('E: July NONE with enough cash closes normally', () {
      final start = fixture(month: 7, cash: 3000000);
      final result = PublicDemoMonthlyClose.closeJuly(
        state: start,
        monthlyExpenses: 800000,
        applicants: const [],
      );
      expect(result.isClosed, isTrue);
      expect(result.state.cash, 3000000 - 800000);
      expect(result.state.financialStatus, PublicDemoFinancialStatus.normal);
    });

    test('E2: July NONE always permits the close even when the resulting '
        'cash is negative — first shortage', () {
      final start = fixture(month: 7, cash: 500000);
      final result = PublicDemoMonthlyClose.closeJuly(
        state: start,
        monthlyExpenses: 800000,
        applicants: const [],
      );
      expect(
        result.isClosed,
        isTrue,
        reason:
            'no insufficient-cash rollback for the mandatory close '
            'any more',
      );
      expect(result.state.cash, -300000);
      expect(
        result.state.financialStatus,
        PublicDemoFinancialStatus.cashShortage,
      );
      expect(result.state.month, 8);
      // W: reconciliation holds for a negative closing cash too.
      final flow = result.state.latestMonthlyCashFlow!;
      expect(
        flow.openingCash +
            flow.cashReceived -
            flow.salaryPaid -
            flow.fixedCostsPaid -
            flow.bonusPaid -
            flow.trainingCost -
            flow.recruitmentCost,
        flow.closingCash,
      );
      expect(flow.closingCash, result.state.cash);
    });

    test('F: July NONE while already in shortage causes BANKRUPTCY, the '
        'close still commits', () {
      final start = fixture(
        month: 7,
        cash: -100000,
        financialStatus: PublicDemoFinancialStatus.cashShortage,
      );
      final result = PublicDemoMonthlyClose.closeJuly(
        state: start,
        monthlyExpenses: 800000,
        applicants: const [],
      );
      expect(result.isClosed, isTrue);
      expect(result.state.cash, -900000);
      expect(
        result.state.financialStatus,
        PublicDemoFinancialStatus.bankruptcy,
      );
    });

    test('G: July prior AR settles exactly once', () {
      final start = fixture(month: 7, cash: 500000, pendingRevenue: 300000);
      final result = PublicDemoMonthlyClose.closeJuly(
        state: start,
        monthlyExpenses: 800000,
        applicants: const [],
      );
      expect(result.isClosed, isTrue);
      expect(result.state.cash, 0);
      final retry = PublicDemoMonthlyClose.closeJuly(
        state: result.state,
        monthlyExpenses: 800000,
        applicants: const [],
      );
      expect(retry.isClosed, isFalse);
      expect(retry.state.cash, result.state.cash);
    });

    test('H: paid bonus affordability behavior is unchanged — an '
        'unaffordable bonus pays zero, never rolling back the mandatory '
        'close (regression; see public_demo_summer_bonus_payment_test'
        '.dart for the full contract)', () {
      final start = fixture(
        month: 7,
        cash: 1000000,
        summerBonusSelection: PublicDemoSummerBonusPlan.one,
      );
      final result = PublicDemoMonthlyClose.closeJuly(
        state: start,
        monthlyExpenses: 800000,
        applicants: const [],
      );
      expect(result.isClosed, isTrue);
      // Bonus for plan=one with no hires is the initial engineer total
      // (550,000); 1,000,000 - 800,000 = 200,000 < 550,000, unaffordable.
      expect(result.state.summerBonusPaidAmount, 0);
      expect(result.state.cash, 1000000 - 800000);
    });
  });

  group('I/J/K/L/M. March terminal priority', () {
    test('I: March NORMAL entering, closing cash >= 0 -> fiscal success', () {
      final start = fixture(month: 15, cash: 900000);
      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: start,
        monthlyExpenses: 800000,
      );
      expect(result.isClosed, isTrue);
      expect(result.state.cash, 100000);
      expect(result.state.fiscalYearCompleted, isTrue);
      expect(result.state.financialStatus, PublicDemoFinancialStatus.normal);
    });

    test('J: March NORMAL entering, closing cash < 0 -> terminal MARCH '
        'CASH-SHORTAGE FAILURE, NOT annual success', () {
      final start = fixture(month: 15, cash: 500000);
      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: start,
        monthlyExpenses: 800000,
      );
      expect(result.isClosed, isTrue, reason: 'still a committed close');
      expect(result.state.cash, -300000);
      expect(result.state.fiscalYearCompleted, isFalse);
      expect(
        result.state.financialStatus,
        PublicDemoFinancialStatus.marchCashShortageFailure,
      );
      expect(result.state.isFinanciallyTerminal, isTrue);
    });

    test('K: March CASH SHORTAGE entering, closing cash < 0 -> '
        'BANKRUPTCY (priority over March failure)', () {
      final start = fixture(
        month: 15,
        cash: 100000,
        financialStatus: PublicDemoFinancialStatus.cashShortage,
      );
      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: start,
        monthlyExpenses: 800000,
      );
      expect(result.state.cash, -700000);
      expect(result.state.fiscalYearCompleted, isFalse);
      expect(
        result.state.financialStatus,
        PublicDemoFinancialStatus.bankruptcy,
      );
    });

    test('L: March CASH SHORTAGE entering, closing cash >= 0 -> '
        'recovered, fiscal completion may succeed', () {
      final start = fixture(
        month: 15,
        cash: 900000,
        financialStatus: PublicDemoFinancialStatus.cashShortage,
      );
      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: start,
        monthlyExpenses: 800000,
      );
      expect(result.state.cash, 100000);
      expect(result.state.fiscalYearCompleted, isTrue);
      expect(result.state.financialStatus, PublicDemoFinancialStatus.normal);
    });

    test('M: March current-month revenue remains pending, never swept '
        'into cash the same close (30-day AR rule, unchanged by '
        'FINANCE-FAILURE) — holds under a shortage-entering March too', () {
      final start = fixture(
        month: 15,
        cash: 900000,
        engineersAssigned: 2,
        financialStatus: PublicDemoFinancialStatus.cashShortage,
      );
      final result = PublicDemoMonthlyClose.closeOrdinaryMonth(
        state: start,
        monthlyExpenses: 800000,
      );
      expect(result.state.fiscalYearCompleted, isTrue);
      expect(result.state.pendingRevenue, 1000000);
      expect(result.state.cash, 900000 - 800000);
    });
  });

  group('N-U. Recruitment/offer/training shortage gates (real aggregate '
      'trajectory, no state injection)', () {
    test('N: shortage blocks paid recruitment media atomically — no '
        'cash mutation, no usage mutation, no applicants generated', () {
      final shortage = _reachShortageAggregate();
      final cashBefore = shortage.state.cash;
      final applicantsBefore = shortage.workflow.applicants;
      final result = shortage.recruit(PublicDemoRecruitmentMedium.engineer);
      expect(result.isSuccess, isFalse);
      expect(
        result.status,
        PublicDemoRecruitmentTransactionStatus.blockedByFinancialShortage,
      );
      expect(result.aggregate, isNull);
      expect(result.chargedAmount, 0);
      expect(result.generatedApplicants, isEmpty);
      expect(shortage.state.cash, cashBefore);
      expect(shortage.workflow.applicants, applicantsBefore);
    });

    test('O: shortage blocks free recruitment media too — B\'.1 finalized '
        'that zero cost does not exempt it', () {
      final shortage = _reachShortageAggregate();
      final result = shortage.recruit(PublicDemoRecruitmentMedium.free);
      expect(result.isSuccess, isFalse);
      expect(
        result.status,
        PublicDemoRecruitmentTransactionStatus.blockedByFinancialShortage,
      );
      expect(result.generatedApplicants, isEmpty);
    });

    test('P: shortage blocks new offer acceptance (the salary-'
        'obligation boundary)', () {
      final shortage = _reachShortageAggregate();
      final applicant = shortage.workflow.applicants.first;
      final completed = shortage.completeInterview(applicant.id);
      expect(
        completed.isCompleted,
        isTrue,
        reason:
            'S: interviews '
            'themselves remain available during shortage',
      );
      final interviewed = completed.aggregate;
      final interviewedApplicant = interviewed.workflow.applicants.firstWhere(
        (a) => a.id == applicant.id,
      );
      final offer = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: interviewedApplicant,
        offeredMonthlySalary: interviewedApplicant.requestedMonthlySalary,
      );
      expect(
        offer.accepted,
        isTrue,
        reason:
            'a genuine, would-be-'
            'accepted offer is the meaningful case to block',
      );
      final afterOfferAttempt = interviewed.acceptOffer(
        applicantId: applicant.id,
        offer: offer,
        fiscalCloseId: PublicDemoFiscalCloseId.forMonth(
          interviewed.state.month,
        ),
      );
      expect(
        afterOfferAttempt,
        same(interviewed),
        reason:
            'rejected by domain authority: no BindingOffer minted, '
            'no workflow mutation at all',
      );
      expect(
        afterOfferAttempt.workflow.applicants
            .firstWhere((a) => a.id == applicant.id)
            .hasBindingOffer,
        isFalse,
      );
    });

    test('Q: shortage blocks paid internal training atomically', () {
      final shortage = _reachShortageAggregate();
      final engineerId = shortage.workflow.engineers.first.id;
      final directResult = const PublicDemoInternalTrainingTransaction()
          .execute(
            state: shortage.state,
            engineerId: engineerId,
            assignedEngineerIds: shortage.workflow.assignedEngineerIds(
              month: shortage.state.month,
            ),
          );
      expect(
        directResult.status,
        PublicDemoInternalTrainingStatus.blockedByFinancialShortage,
      );
      expect(directResult.chargedAmount, 0);
      expect(directResult.state.cash, shortage.state.cash);

      final aggregateResult = shortage.selectInternalTraining(engineerId);
      expect(
        aggregateResult,
        same(shortage),
        reason: 'aggregate-level command is a complete no-op too',
      );
    });

    test('R: a valid pre-shortage BindingOffer remains coherent once '
        'shortage begins — existing obligations are not cancelled', () {
      // Accept a genuine offer while still NORMAL.
      var game = PublicDemoAggregate.initial();
      final applicant = game.workflow.applicants.first;
      final completed = game.completeInterview(applicant.id);
      expect(completed.isCompleted, isTrue);
      game = completed.aggregate;
      final normalApplicant = game.workflow.applicants.firstWhere(
        (a) => a.id == applicant.id,
      );
      final offer = PublicDemoSalaryOfferEvaluator.evaluate(
        applicant: normalApplicant,
        offeredMonthlySalary: normalApplicant.requestedMonthlySalary,
      );
      expect(offer.accepted, isTrue);
      game = game.acceptOffer(
        applicantId: applicant.id,
        offer: offer,
        fiscalCloseId: PublicDemoFiscalCloseId.forMonth(game.state.month),
      );
      final bindingOfferBefore = game.workflow.applicants
          .firstWhere((a) => a.id == applicant.id)
          .bindingOffer;
      expect(bindingOfferBefore, isNotNull);

      // Drive into shortage via real closes (April has no orders here
      // either, so the same zero-order deficit as _reachShortageAggregate
      // applies) — nothing about entering shortage may touch this
      // applicant's already-authoritative offer.
      game = game
          .closeApril(monthlyExpenses: 800000)
          .closeMay(week: 9, monthlyExpenses: 800000)
          .closeJune(assignedInJuly: 0, monthlyExpenses: 800000)
          .closeJuly(monthlyExpenses: 800000);
      expect(
        game.state.financialStatus,
        PublicDemoFinancialStatus.cashShortage,
      );
      final applicantAfter = game.workflow.applicants.firstWhere(
        (a) => a.id == applicant.id,
      );
      expect(applicantAfter.bindingOffer, same(bindingOfferBefore));
      expect(applicantAfter.hasBindingOffer, isTrue);
    });

    test('S: sales/interview/zero-cost progression remains available '
        'during shortage', () {
      final shortage = _reachShortageAggregate();
      final engineerId = shortage.workflow.engineers.first.id;
      final afterSkillSheet = shortage.startSkillSheetReview(engineerId);
      expect(
        afterSkillSheet.workflow.engineers
            .firstWhere((e) => e.id == engineerId)
            .stage,
        isNot(
          shortage.workflow.engineers
              .firstWhere((e) => e.id == engineerId)
              .stage,
        ),
        reason: 'a zero-cost sales-pipeline transition still progresses',
      );
    });

    test('U: a direct call to the sole commit path (PublicDemoAggregate'
        '.acceptOffer) cannot create a new salary obligation during '
        'shortage, even for a second, independently-eligible applicant — '
        'there is no bypass because there is no alternate way to commit '
        'a workflow change on this class (see its own class doc)', () {
      final shortage = _reachShortageAggregate();
      for (final applicant in shortage.workflow.applicants) {
        final completed = shortage.completeInterview(applicant.id);
        if (!completed.isCompleted) continue;
        final interviewedApplicant = completed.aggregate.workflow.applicants
            .firstWhere((a) => a.id == applicant.id);
        final offer = PublicDemoSalaryOfferEvaluator.evaluate(
          applicant: interviewedApplicant,
          offeredMonthlySalary: interviewedApplicant.requestedMonthlySalary,
        );
        if (!offer.accepted) continue;
        final blocked = completed.aggregate.acceptOffer(
          applicantId: applicant.id,
          offer: offer,
          fiscalCloseId: PublicDemoFiscalCloseId.forMonth(
            completed.aggregate.state.month,
          ),
        );
        expect(
          blocked.workflow.applicants
              .firstWhere((a) => a.id == applicant.id)
              .hasBindingOffer,
          isFalse,
          reason: 'applicant ${applicant.id}',
        );
      }
    });
  });

  group('V. Workflow snapshot equivalence', () {
    test('the finance-relevant facts PublicDemoWorkflowSnapshot captures '
        'agree with what the live close path actually used — the '
        'aggregate close derives payroll/assignment facts from this same '
        'atomic workflow, never an independent widget-local list', () {
      final game = PublicDemoAggregate.initial().closeApril(
        monthlyExpenses: 800000,
      );
      final snapshot = PublicDemoWorkflowSnapshot.capture(
        game.workflow,
        month: game.state.month,
      );
      expect(
        snapshot.assignedEngineerIds,
        game.workflow.assignedEngineerIds(month: game.state.month),
      );
      expect(snapshot.joinedPayrollIds, game.workflow.joinedApplicantIds);
    });
  });

  group('Y. Save/JSON backward compatibility', () {
    test('every financialStatus value round trips through JSON', () {
      for (final status in PublicDemoFinancialStatus.values) {
        final state = PublicDemoState.aprilStart().copyWith(
          financialStatus: status,
        );
        expect(
          PublicDemoState.fromJson(state.toJson()).financialStatus,
          status,
        );
      }
    });

    test('an old save with no financialStatus key normalizes to normal', () {
      final old = PublicDemoState.aprilStart().toJson()
        ..remove('financialStatus');
      expect(
        PublicDemoState.fromJson(old).financialStatus,
        PublicDemoFinancialStatus.normal,
      );
    });

    test('a malformed financialStatus value normalizes to normal', () {
      final malformed = PublicDemoState.aprilStart().toJson()
        ..['financialStatus'] = 'not-a-real-status';
      expect(
        PublicDemoState.fromJson(malformed).financialStatus,
        PublicDemoFinancialStatus.normal,
      );
    });
  });
}

/// Reaches a genuine CASH SHORTAGE the same way a real, order-free
/// playthrough would: April through July all close with zero engineer
/// orders, so Revenue never covers the founding team's fixed
/// 800,000/month payroll+overhead. No fixture shortcut — every field on
/// the returned aggregate is exactly what production code would produce.
///
/// [PublicDemoWorkflowState.joinAndKeepOnly] (May's close) drops every
/// applicant who never had an accepted offer by then — the initial two
/// May applicants are gone by month 6. A free-medium recruitment right
/// after May's close (cost 0, so the cash trajectory above is unaffected)
/// seeds one applicant who survives for the rest of the game, giving P/S/U
/// below a genuine, still-present applicant to interview/offer against
/// once this aggregate reaches shortage.
PublicDemoAggregate _reachShortageAggregate() {
  var game = PublicDemoAggregate.initial()
      .closeApril(monthlyExpenses: 800000)
      .closeMay(week: 9, monthlyExpenses: 800000);
  final recruited = game.recruit(PublicDemoRecruitmentMedium.free);
  assert(recruited.isSuccess);
  game = recruited.aggregate!
      .closeJune(assignedInJuly: 0, monthlyExpenses: 800000)
      .closeJuly(monthlyExpenses: 800000);
  assert(game.state.financialStatus == PublicDemoFinancialStatus.cashShortage);
  assert(game.workflow.applicants.isNotEmpty);
  return game;
}

/// Reaches a genuine BANKRUPTCY the same way: one more zero-order ordinary
/// close on top of [_reachShortageAggregate]'s shortage.
PublicDemoAggregate _reachBankruptAggregate() {
  final game = _reachShortageAggregate().closeOrdinaryMonth(
    monthlyExpenses: 800000,
  );
  assert(game.state.financialStatus == PublicDemoFinancialStatus.bankruptcy);
  return game;
}
