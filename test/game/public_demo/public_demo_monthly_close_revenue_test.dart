import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_monthly_close.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_summer_bonus_plan.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

/// REVENUE-4 (12MONTH-2): proves the 30-day-site Revenue transaction
/// (REVENUE-1~3) is correctly wired into [PublicDemoMonthlyClose] — the
/// single connection point between Revenue and the common month-end close.
/// These tests exercise Revenue *through* the close facade; the Revenue
/// transaction's own math is already covered by
/// public_demo_revenue_payment_test.dart and is not re-derived here.
void main() {
  /// Minimal, fully-controlled fixture: lets each test set exactly the
  /// pre-close cash/pendingRevenue/engineersAssigned it needs without
  /// depending on how a real playthrough would reach that state.
  PublicDemoState fixture({
    int month = 4,
    required int cash,
    required int pendingRevenue,
    required int engineersAssigned,
    PublicDemoSummerBonusPlan summerBonusSelection =
        PublicDemoSummerBonusPlan.none,
  }) => PublicDemoState(
    month: month,
    cash: cash,
    engineerCount: engineersAssigned + 2,
    adminCount: 1,
    salesCapacity: 4,
    salesUsed: 0,
    engineersWaiting: 0,
    engineersAssigned: engineersAssigned,
    pendingRevenue: pendingRevenue,
    summerBonusSelection: summerBonusSelection,
  );

  group('Revenue core, via Common Close (closeApril)', () {
    test('1. pending 0, assigned 0 -> cash +0, new pending 0', () {
      final start = fixture(
        cash: 1000000,
        pendingRevenue: 0,
        engineersAssigned: 0,
      );
      final result = PublicDemoMonthlyClose.closeApril(
        state: start,
        monthlyExpenses: 0,
        orderedEngineers: 0,
      );
      expect(result.cashAfter, 1000000);
      expect(result.state.pendingRevenue, 0);
    });

    test('2. pending 0, assigned 1 -> cash +0, new pending 500,000', () {
      final start = fixture(
        cash: 1000000,
        pendingRevenue: 0,
        engineersAssigned: 1,
      );
      final result = PublicDemoMonthlyClose.closeApril(
        state: start,
        monthlyExpenses: 0,
        orderedEngineers: 0,
      );
      expect(result.cashAfter, 1000000);
      expect(result.state.pendingRevenue, 500000);
    });

    test(
      '3. pending 500,000, assigned 1 -> cash +500,000, new pending 500,000',
      () {
        final start = fixture(
          cash: 1000000,
          pendingRevenue: 500000,
          engineersAssigned: 1,
        );
        final result = PublicDemoMonthlyClose.closeApril(
          state: start,
          monthlyExpenses: 0,
          orderedEngineers: 0,
        );
        expect(result.cashAfter, 1500000);
        expect(result.state.pendingRevenue, 500000);
      },
    );

    test(
      '4. pending 500,000, assigned 2 -> cash +500,000, new pending 1,000,000',
      () {
        final start = fixture(
          cash: 1000000,
          pendingRevenue: 500000,
          engineersAssigned: 2,
        );
        final result = PublicDemoMonthlyClose.closeApril(
          state: start,
          monthlyExpenses: 0,
          orderedEngineers: 0,
        );
        expect(result.cashAfter, 1500000);
        expect(result.state.pendingRevenue, 1000000);
      },
    );

    test('5. this month\'s newly recognized revenue never enters this '
        'month\'s cash (30-day site)', () {
      final start = fixture(
        cash: 1000000,
        pendingRevenue: 0,
        engineersAssigned: 3,
      );
      final result = PublicDemoMonthlyClose.closeApril(
        state: start,
        monthlyExpenses: 0,
        orderedEngineers: 0,
      );
      expect(result.state.pendingRevenue, 1500000);
      expect(result.cashAfter, 1000000);
    });

    test('6. old pendingRevenue is collected exactly once (not doubled)', () {
      final start = fixture(
        cash: 1000000,
        pendingRevenue: 500000,
        engineersAssigned: 0,
      );
      final result = PublicDemoMonthlyClose.closeApril(
        state: start,
        monthlyExpenses: 0,
        orderedEngineers: 0,
      );
      expect(result.cashAfter - result.cashBefore, 500000);
    });

    test('7. one Common Close call runs the Revenue transaction exactly '
        'once; a repeated call on the already-closed month is a no-op', () {
      final start = fixture(
        cash: 1000000,
        pendingRevenue: 500000,
        engineersAssigned: 1,
      );
      final firstClose = PublicDemoMonthlyClose.closeApril(
        state: start,
        monthlyExpenses: 0,
        orderedEngineers: 0,
      );
      expect(firstClose.cashAfter, 1500000);
      expect(firstClose.state.pendingRevenue, 500000);

      // Second call targets May (month already advanced past April), so the
      // underlying transition's own guard makes it a no-op — and therefore
      // the Revenue transaction must not run a second time either.
      final secondClose = PublicDemoMonthlyClose.closeApril(
        state: firstClose.state,
        monthlyExpenses: 0,
        orderedEngineers: 0,
      );
      expect(secondClose.status, PublicDemoMonthlyCloseStatus.notApplicable);
      expect(secondClose.state, same(firstClose.state));
      expect(secondClose.state.cash, 1500000);
      expect(secondClose.state.pendingRevenue, 500000);
    });
  });

  group('30-day flow across real months (4->5->6)', () {
    test('April assigned=1 books May pending; May assigned=2 collects it '
        'and books June pending, per the fixed example', () {
      // 4月: cash = X, assigned = 1, pending = 0
      final april = fixture(
        month: 4,
        cash: 3000000,
        pendingRevenue: 0,
        engineersAssigned: 1,
      );

      // 4->5 close: no cash Revenue increase (pending was 0); assigned=1
      // books 500,000 as May's pending. Post-close engineersAssigned is
      // driven to 2 via orderedEngineers, matching "5月: assigned=2".
      final afterApril = PublicDemoMonthlyClose.closeApril(
        state: april,
        monthlyExpenses: 800000,
        orderedEngineers: 2,
      );
      expect(afterApril.cashAfter, 3000000 - 800000);
      expect(afterApril.state.pendingRevenue, 500000);
      expect(afterApril.state.engineersAssigned, 2);

      // 5->6 close: April's 500,000 pending settles into cash; May's
      // assigned=2 books 1,000,000 as June's pending.
      final afterMay = PublicDemoMonthlyClose.closeMay(
        state: afterApril.state,
        workflow: PublicDemoWorkflowState.initial(),
        monthlyExpenses: 800000,
        acceptedHires: 0,
        hiredWithOrders: 0,
      );
      expect(afterMay.cashAfter, afterApril.cashAfter + 500000 - 800000);
      expect(afterMay.state.pendingRevenue, 1000000);
    });
  });

  group('Revenue snapshot (pre-close engineersAssigned, not post-close)', () {
    test('closeMay books revenue on the assigned count that existed before '
        'this same close changes it for June', () {
      final start = fixture(
        month: 5,
        cash: 1000000,
        pendingRevenue: 0,
        engineersAssigned: 2,
      );
      final result = PublicDemoMonthlyClose.closeMay(
        state: start,
        workflow: PublicDemoWorkflowState.initial(),
        monthlyExpenses: 0,
        acceptedHires: 5,
        hiredWithOrders: 5,
      );
      // Post-close engineersAssigned differs sharply from the pre-close
      // value (2 -> 7): the close itself adds 5 newly-ordered hires.
      expect(result.state.engineersAssigned, 7);
      // Revenue must still reflect the pre-close snapshot (2), not 7.
      expect(result.state.pendingRevenue, 1000000);
    });
  });

  group('FINANCE-FAILURE-1A+1B: Revenue and the underlying close always settle '
      'together — bonus affordability only ever gates the optional bonus '
      'itself, never a rollback of the mandatory close (no more July '
      'insufficient-cash rollback)', () {
    test('insufficient cash even after Revenue settles: the mandatory close '
        'still commits (AR collected, salary/fixed costs paid), the bonus '
        'pays zero instead', () {
      // totalOutflow for plan=one, no extra hires = 800,000 + 550,000 =
      // 1,350,000 (see public_demo_monthly_close_test.dart for the same
      // constants). cash(800,000) + pendingRevenue(500,000) = 1,300,000,
      // still short of paying the bonus too.
      final start = fixture(
        month: 7,
        cash: 800000,
        pendingRevenue: 500000,
        engineersAssigned: 1,
        summerBonusSelection: PublicDemoSummerBonusPlan.one,
      );
      final result = PublicDemoMonthlyClose.closeJuly(
        state: start,
        monthlyExpenses: 800000,
        applicants: const [],
      );
      expect(result.isClosed, isTrue);
      expect(result.state.summerBonusPaid, isTrue);
      expect(result.state.summerBonusPaidAmount, 0);
      expect(result.state.month, 8);
      // AR collected (500,000) + cash(800,000) - monthlyExpenses
      // (800,000) - bonus(0) = 500,000.
      expect(result.state.cash, 500000);
      expect(result.state.financialStatus, PublicDemoFinancialStatus.normal);
    });

    test('Revenue settling is what makes the bonus payable: bonus is zeroed '
        'without it, paid in full with it — the mandatory close commits '
        'either way', () {
      final start = fixture(
        month: 7,
        cash: 1000000,
        pendingRevenue: 500000,
        engineersAssigned: 1,
        summerBonusSelection: PublicDemoSummerBonusPlan.one,
      );

      // Without Revenue connected, raw cash (1,000,000) alone cannot
      // cover totalOutflow (1,350,000) — but the mandatory close still
      // commits, with the bonus reduced to zero.
      final withoutRevenue = start.advanceToAugust(
        monthlyExpenses: 800000,
        applicants: const [],
      );
      expect(withoutRevenue.isPaid, isTrue);
      expect(withoutRevenue.bonusAmount, 0);
      expect(withoutRevenue.state.cash, 1000000 - 800000);

      // With Revenue connected, the old pendingRevenue (500,000) settles
      // into cash first, making 1,500,000 available -- enough to pay.
      final result = PublicDemoMonthlyClose.closeJuly(
        state: start,
        monthlyExpenses: 800000,
        applicants: const [],
      );
      expect(result.isClosed, isTrue);
      expect(result.state.summerBonusPaid, isTrue);
      expect(result.state.summerBonusPaidAmount, 550000);
      expect(result.cashAfter, 1500000 - 1350000);
      // July's assigned=1 books 500,000 as August's pending.
      expect(result.state.pendingRevenue, 500000);
    });
  });
}
