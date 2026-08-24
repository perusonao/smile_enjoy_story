import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_monthly_close.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_recruitment.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';

/// 12MONTH-1: proves the common Monthly Close facade produces state that is
/// identical, field for field, to the pre-existing advanceToX/closeJuly
/// path it wraps. This is an equivalence check, not a behavior test — the
/// underlying rules are already covered by the per-domain test suites.
void main() {
  const hire = PublicDemoApplicant(
    id: 'close-hire-01',
    name: 'Close Hire',
    resumeSummary: 'Java 3年',
    interviewScore: 70,
    acceptanceScore: 70,
    salesSkillFit: 70,
    requestedMonthlySalary: 320000,
  );

  // WORKFLOW-STATE-1AB FIX1 P1-4: advanceToJune/closeMay now derive
  // joinedApplicantIds from real applicant records (via `hasJoined`), not a
  // caller-supplied id list — this fixture stands in for the authoritative,
  // already-joined applicant [PublicDemoWorkflowState.joinAndKeepOnly] would
  // hand these entry points in production.
  final joinedHire = hire.copyWith(
    employeeMorale: 70,
    employeeCompanyTrust: 70,
  );

  /// [checkMoney] gates `cash`/`pendingRevenue` equivalence: REVENUE-4 makes
  /// the common close intentionally diverge from the legacy per-month path
  /// on those two fields whenever Revenue actually settles (see the 5->6 and
  /// 6->7 groups below, which pass `checkMoney: false` and assert the
  /// Revenue-adjusted values explicitly instead). Every other field must
  /// still match exactly in every case: Revenue touches only cash and
  /// pendingRevenue.
  void expectStateEquivalent(
    PublicDemoState legacy,
    PublicDemoState viaClose, {
    bool checkMoney = true,
  }) {
    expect(viaClose.month, legacy.month);
    expect(viaClose.salesUsed, legacy.salesUsed);
    expect(viaClose.engineerCount, legacy.engineerCount);
    expect(viaClose.engineersAssigned, legacy.engineersAssigned);
    expect(viaClose.engineersWaiting, legacy.engineersWaiting);
    expect(viaClose.joinedApplicantIds, legacy.joinedApplicantIds);
    expect(viaClose.summerBonusSelection, legacy.summerBonusSelection);
    expect(viaClose.summerBonusPaid, legacy.summerBonusPaid);
    expect(viaClose.summerBonusPaidMonth, legacy.summerBonusPaidMonth);
    expect(viaClose.summerBonusPaidAmount, legacy.summerBonusPaidAmount);
    expect(viaClose.trainingSelections, legacy.trainingSelections);
    expect(viaClose.growthAppliedMonths, legacy.growthAppliedMonths);
    expect(
      viaClose.engineerRuntimes.map((r) => r.toJson()).toList(),
      legacy.engineerRuntimes.map((r) => r.toJson()).toList(),
    );
    if (checkMoney) {
      expect(viaClose.cash, legacy.cash);
      expect(viaClose.pendingRevenue, legacy.pendingRevenue);
    }
  }

  group('4->5 equivalence (April close)', () {
    test('ordered engineers win a May assignment', () {
      final start = PublicDemoState.aprilStart();
      final legacy = start.advanceToMay(
        monthlyExpenses: 800000,
        orderedEngineers: 1,
      );
      final result = PublicDemoMonthlyClose.closeApril(
        state: start,
        monthlyExpenses: 800000,
        orderedEngineers: 1,
      );
      expect(result.isClosed, isTrue);
      expect(result.closedMonth, 4);
      expect(result.cashBefore, start.cash);
      expect(result.cashAfter, legacy.cash);
      expectStateEquivalent(legacy, result.state);
      // pendingRevenue must stay untouched: Revenue is not connected yet.
      expect(result.state.pendingRevenue, 0);
    });

    test('no orders leaves everyone waiting', () {
      final start = PublicDemoState.aprilStart();
      final legacy = start.advanceToMay(
        monthlyExpenses: 800000,
        orderedEngineers: 0,
      );
      final result = PublicDemoMonthlyClose.closeApril(
        state: start,
        monthlyExpenses: 800000,
        orderedEngineers: 0,
      );
      expectStateEquivalent(legacy, result.state);
    });

    test('wrong month is a no-op on both paths', () {
      final start = PublicDemoState.aprilStart().copyWith(month: 5);
      final legacy = start.advanceToMay(
        monthlyExpenses: 800000,
        orderedEngineers: 1,
      );
      final result = PublicDemoMonthlyClose.closeApril(
        state: start,
        monthlyExpenses: 800000,
        orderedEngineers: 1,
      );
      expect(result.status, PublicDemoMonthlyCloseStatus.notApplicable);
      expect(result.state, same(start));
      expectStateEquivalent(legacy, result.state);
    });
  });

  group('5->6 equivalence (May close)', () {
    PublicDemoState mayState() => PublicDemoState.aprilStart().advanceToMay(
      monthlyExpenses: 800000,
      orderedEngineers: 1,
    );

    test('accepted hire joins in June assigned with an order', () {
      final start = mayState();
      final legacy = start.advanceToJune(
        monthlyExpenses: 800000,
        acceptedHires: 1,
        hiredWithOrders: 1,
        joinedApplicants: [joinedHire],
      );
      final result = PublicDemoMonthlyClose.closeMay(
        state: start,
        monthlyExpenses: 800000,
        acceptedHires: 1,
        hiredWithOrders: 1,
        joinedApplicants: [joinedHire],
      );
      expect(result.isClosed, isTrue);
      expect(result.closedMonth, 5);
      expectStateEquivalent(legacy, result.state, checkMoney: false);
      // REVENUE-4: mayState() carries engineersAssigned=1 from April's order
      // into May, so this close's pre-transition snapshot books May's
      // revenue (1 * 500,000) as the new pending balance. start.pendingRevenue
      // was 0, so nothing is collectible into cash yet (30-day site).
      expect(result.cashAfter, legacy.cash);
      expect(result.state.pendingRevenue, 500000);
    });

    test('wrong month is a no-op on both paths', () {
      final start = mayState().copyWith(month: 6);
      final legacy = start.advanceToJune(
        monthlyExpenses: 800000,
        acceptedHires: 1,
        hiredWithOrders: 1,
      );
      final result = PublicDemoMonthlyClose.closeMay(
        state: start,
        monthlyExpenses: 800000,
        acceptedHires: 1,
        hiredWithOrders: 1,
      );
      expect(result.status, PublicDemoMonthlyCloseStatus.notApplicable);
      expect(result.state, same(start));
      expectStateEquivalent(legacy, result.state);
    });
  });

  group(
    'joinedApplicantIds is a derived projection, not caller authority (P1-4)',
    () {
      PublicDemoState mayState() => PublicDemoState.aprilStart().advanceToMay(
        monthlyExpenses: 800000,
        orderedEngineers: 1,
      );

      test('an id with no correspondingly-joined applicant behind it never '
          'appears: only applicants whose hasJoined is actually true '
          'contribute an id', () {
        final notActuallyJoined =
            hire; // hasJoined is false: no morale/trust set.
        final start = mayState();

        final result = start.advanceToJune(
          monthlyExpenses: 800000,
          acceptedHires: 1,
          hiredWithOrders: 1,
          joinedApplicants: [notActuallyJoined],
        );

        expect(result.joinedApplicantIds, isEmpty);
      });

      test(
        'the June/payroll path derives joined ids from the authoritative '
        'applicant records passed in, not any separately maintained list',
        () {
          final start = mayState();

          final result = PublicDemoMonthlyClose.closeMay(
            state: start,
            monthlyExpenses: 800000,
            acceptedHires: 1,
            hiredWithOrders: 1,
            joinedApplicants: [joinedHire],
          );

          expect(result.state.joinedApplicantIds, ['close-hire-01']);
        },
      );

      test('joinedApplicantIds cannot diverge from the workflow: passing '
          'multiple applicants only the truly-joined ones are reflected', () {
        const secondHire = PublicDemoApplicant(
          id: 'close-hire-02',
          name: 'Second Hire',
          resumeSummary: 'Java 2年',
          interviewScore: 65,
          acceptanceScore: 65,
          salesSkillFit: 65,
          requestedMonthlySalary: 300000,
        );
        final start = mayState();

        final result = start.advanceToJune(
          monthlyExpenses: 800000,
          acceptedHires: 2,
          hiredWithOrders: 1,
          joinedApplicants: [joinedHire, secondHire],
        );

        expect(result.joinedApplicantIds, ['close-hire-01']);
      });
    },
  );

  group('6->7 equivalence (June close)', () {
    PublicDemoState juneState() => PublicDemoState.aprilStart()
        .advanceToMay(monthlyExpenses: 800000, orderedEngineers: 1)
        .advanceToJune(
          monthlyExpenses: 800000,
          acceptedHires: 1,
          hiredWithOrders: 1,
          joinedApplicants: [joinedHire],
        );

    test('only one engineer keeps a July assignment', () {
      final start = juneState();
      final legacy = start.advanceToJuly(
        monthlyExpenses: 800000,
        assignedInJuly: 1,
      );
      final result = PublicDemoMonthlyClose.closeJune(
        state: start,
        monthlyExpenses: 800000,
        assignedInJuly: 1,
      );
      expect(result.isClosed, isTrue);
      expect(result.closedMonth, 6);
      expectStateEquivalent(legacy, result.state, checkMoney: false);
      // REVENUE-4 snapshot: juneState() carries engineersAssigned=2 into
      // June (1 from April's order + 1 hired-with-order in May), so June's
      // revenue books at 2 * 500,000 even though this same close overwrites
      // engineersAssigned down to 1 for July via assignedInJuly. juneState()
      // was built through the raw advanceToX chain (no Revenue involved),
      // so start.pendingRevenue is still 0 here — nothing collectible into
      // cash yet, matching the 30-day site.
      expect(result.state.engineersAssigned, 1);
      expect(start.engineersAssigned, 2);
      expect(start.pendingRevenue, 0);
      expect(result.cashAfter, legacy.cash);
      expect(result.state.pendingRevenue, 1000000);
    });

    test('wrong month is a no-op on both paths', () {
      final start = juneState().copyWith(month: 7);
      final legacy = start.advanceToJuly(
        monthlyExpenses: 800000,
        assignedInJuly: 1,
      );
      final result = PublicDemoMonthlyClose.closeJune(
        state: start,
        monthlyExpenses: 800000,
        assignedInJuly: 1,
      );
      expect(result.status, PublicDemoMonthlyCloseStatus.notApplicable);
      expect(result.state, same(start));
      expectStateEquivalent(legacy, result.state);
    });
  });

  group('7->8 equivalence (July close)', () {
    PublicDemoState julyState({
      int cash = 3000000,
      PublicDemoSummerBonusPlan plan = PublicDemoSummerBonusPlan.one,
    }) => PublicDemoState.aprilStart()
        .copyWith(month: 7, cash: cash)
        .selectSummerBonus(plan);

    test('bonus and monthly expenses settle atomically', () {
      final start = julyState();
      final joined = [hire.join(week: 9)];
      final legacy = start.advanceToAugust(
        monthlyExpenses: 800000,
        applicants: joined,
      );
      final result = PublicDemoMonthlyClose.closeJuly(
        state: start,
        monthlyExpenses: 800000,
        applicants: joined,
      );
      expect(result.isClosed, isTrue);
      expect(result.closedMonth, 7);
      expect(result.cashAfter, legacy.state.cash);
      expect(result.cashMovement, legacy.cashMovement);
      expectStateEquivalent(legacy.state, result.state);
      expect(result.state.pendingRevenue, 0);
    });

    test('insufficient cash leaves state unchanged on both paths', () {
      final start = julyState(cash: 1349999);
      final legacy = start.advanceToAugust(
        monthlyExpenses: 800000,
        applicants: const [],
      );
      final result = PublicDemoMonthlyClose.closeJuly(
        state: start,
        monthlyExpenses: 800000,
        applicants: const [],
      );
      expect(result.isInsufficientCash, isTrue);
      expect(result.state, same(start));
      expectStateEquivalent(legacy.state, result.state);
    });

    test('wrong month is a no-op on both paths', () {
      final start = julyState().copyWith(month: 6);
      final legacy = start.advanceToAugust(
        monthlyExpenses: 800000,
        applicants: const [],
      );
      final result = PublicDemoMonthlyClose.closeJuly(
        state: start,
        monthlyExpenses: 800000,
        applicants: const [],
      );
      expect(result.status, PublicDemoMonthlyCloseStatus.notApplicable);
      expect(result.state, same(start));
      expectStateEquivalent(legacy.state, result.state);
    });
  });
}
